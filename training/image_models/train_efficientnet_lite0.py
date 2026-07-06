#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

import tensorflow as tf
import tensorflow_hub as hub
import tf_keras as keras

ROOT = Path(__file__).resolve().parents[2]
SPLIT_FILE = ROOT / "training" / "image_models" / "dataset_split.json"
EXPORT_DIR = ROOT / "training" / "image_models" / "artifacts" / "efficientnet_lite0"
TFHUB_FEATURE_VECTOR = "https://tfhub.dev/tensorflow/efficientnet/lite0/feature-vector/2"
LABELS = ["ashtray", "cigarette", "cigarette pack", "people smoking", "smoke", "negative"]
IMAGE_SIZE = 224
BATCH_SIZE = 32
EPOCHS_HEAD = 20


def load_split() -> dict:
    return json.loads(SPLIT_FILE.read_text(encoding="utf-8"))


def make_dataset(split: dict, split_name: str, shuffle: bool) -> tf.data.Dataset:
    dataset_dir = ROOT / split["dataset_dir"]
    label_to_index = {label: index for index, label in enumerate(LABELS)}
    paths = [str(dataset_dir / entry["file"]) for entry in split[split_name]]
    labels = [label_to_index[entry["label"]] for entry in split[split_name]]

    ds = tf.data.Dataset.from_tensor_slices((paths, labels))
    if shuffle:
        ds = ds.shuffle(len(paths), seed=split["split_seed"], reshuffle_each_iteration=True)

    def load_image(path: tf.Tensor, label: tf.Tensor) -> tuple[tf.Tensor, tf.Tensor]:
        image = tf.io.decode_image(tf.io.read_file(path), channels=3, expand_animations=False)
        image = tf.image.resize(image, (IMAGE_SIZE, IMAGE_SIZE))
        image = tf.cast(image, tf.float32)
        return image, tf.one_hot(label, len(LABELS))

    return ds.map(load_image, num_parallel_calls=tf.data.AUTOTUNE).batch(BATCH_SIZE).prefetch(tf.data.AUTOTUNE)


def build_model(trainable_backbone: bool) -> keras.Model:
    augmentation = keras.Sequential(
        [
            keras.layers.RandomFlip("horizontal"),
            keras.layers.RandomRotation(0.04),
            keras.layers.RandomZoom(0.08),
            keras.layers.RandomContrast(0.10),
        ],
        name="augmentation",
    )

    inputs = keras.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, 3), name="rgb_0_255")
    x = augmentation(inputs)
    x = keras.layers.Rescaling(1.0 / 255.0, name="efficientnet_lite_rescale")(x)
    x = hub.KerasLayer(
        TFHUB_FEATURE_VECTOR,
        trainable=trainable_backbone,
        name="efficientnet_lite0_feature_vector",
    )(x)
    x = keras.layers.Dropout(0.2, name="dropout")(x)
    outputs = keras.layers.Dense(len(LABELS), activation="softmax", name="cuelens_labels")(x)
    return keras.Model(inputs, outputs, name="efficientnet_lite0_cuelens")


def representative_dataset(split: dict):
    dataset_dir = ROOT / split["dataset_dir"]
    for entry in split["train"][:200]:
        image = tf.io.decode_image(tf.io.read_file(str(dataset_dir / entry["file"])), channels=3, expand_animations=False)
        image = tf.image.resize(image, (IMAGE_SIZE, IMAGE_SIZE))
        image = tf.cast(image, tf.float32)
        yield [tf.expand_dims(image, axis=0)]


def export_tflite(model: keras.Model, split: dict, filename: str, quantize_int8: bool) -> None:
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    if quantize_int8:
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        converter.representative_dataset = lambda: representative_dataset(split)
        converter.target_spec.supported_ops = [tf.lite.OpsSet.TFLITE_BUILTINS_INT8]
        converter.inference_input_type = tf.int8
        converter.inference_output_type = tf.int8
    tflite_model = converter.convert()
    (EXPORT_DIR / filename).write_bytes(tflite_model)


def main() -> None:
    split = load_split()
    EXPORT_DIR.mkdir(parents=True, exist_ok=True)
    train_ds = make_dataset(split, "train", shuffle=True)
    val_ds = make_dataset(split, "validation", shuffle=False)
    test_ds = make_dataset(split, "test", shuffle=False)

    model = build_model(trainable_backbone=False)
    model.compile(
        optimizer=keras.optimizers.Adam(learning_rate=1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy", keras.metrics.Precision(name="precision"), keras.metrics.Recall(name="recall")],
    )
    callbacks = [
        keras.callbacks.EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True),
        keras.callbacks.ModelCheckpoint(str(EXPORT_DIR / "best.keras"), monitor="val_loss", save_best_only=True),
    ]
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD, callbacks=callbacks, verbose=2)

    test_metrics = model.evaluate(test_ds, return_dict=True)
    export_tflite(model, split, "efficientnet_lite0_cuelens_float32.tflite", quantize_int8=False)
    export_tflite(model, split, "efficientnet_lite0_cuelens_int8.tflite", quantize_int8=True)
    (EXPORT_DIR / "labels.txt").write_text("\n".join(LABELS) + "\n", encoding="utf-8")
    report = {
        "model_id": "efficientnet_lite0_transfer_int8",
        "labels": LABELS,
        "input_size": [IMAGE_SIZE, IMAGE_SIZE, 3],
        "source": TFHUB_FEATURE_VECTOR,
        "input_value_range": "raw RGB 0..255; model graph rescales to 0..1",
        "split_seed": split["split_seed"],
        "train_count": len(split["train"]),
        "validation_count": len(split["validation"]),
        "test_count": len(split["test"]),
        "keras_test_metrics": {key: float(value) for key, value in test_metrics.items()},
        "notes": "TF Hub EfficientNet-Lite0 feature-vector/2 is loaded in TF1 Hub format and cannot be made trainable via hub.KerasLayer; only the CueLens classification head is trained. Evaluate exported TFLite models separately before Android benchmark interpretation.",
    }
    (EXPORT_DIR / "training_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
