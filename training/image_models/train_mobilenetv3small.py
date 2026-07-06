#!/usr/bin/env python3
from __future__ import annotations

import json
from pathlib import Path

import numpy as np
import tensorflow as tf

ROOT = Path(__file__).resolve().parents[2]
SPLIT_FILE = ROOT / "training" / "image_models" / "dataset_split.json"
EXPORT_DIR = ROOT / "training" / "image_models" / "artifacts" / "mobilenetv3small"
LABELS = ["ashtray", "cigarette", "cigarette pack", "people smoking", "smoke", "negative"]
IMAGE_SIZE = 224
BATCH_SIZE = 32
EPOCHS_HEAD = 20
EPOCHS_FINE_TUNE = 15


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


def build_model() -> tf.keras.Model:
    augmentation = tf.keras.Sequential(
        [
            tf.keras.layers.RandomFlip("horizontal"),
            tf.keras.layers.RandomRotation(0.04),
            tf.keras.layers.RandomZoom(0.08),
            tf.keras.layers.RandomContrast(0.10),
        ],
        name="augmentation",
    )

    inputs = tf.keras.Input(shape=(IMAGE_SIZE, IMAGE_SIZE, 3), name="rgb_0_255")
    x = augmentation(inputs)
    x = tf.keras.layers.Rescaling(1.0 / 127.5, offset=-1.0, name="mobilenetv3_rescale")(x)
    backbone = tf.keras.applications.MobileNetV3Small(
        input_shape=(IMAGE_SIZE, IMAGE_SIZE, 3),
        include_top=False,
        include_preprocessing=False,
        weights="imagenet",
    )
    backbone.trainable = False
    x = backbone(x, training=False)
    x = tf.keras.layers.GlobalAveragePooling2D(name="avg_pool")(x)
    x = tf.keras.layers.Dropout(0.2, name="dropout")(x)
    outputs = tf.keras.layers.Dense(len(LABELS), activation="softmax", name="cuelens_labels")(x)
    return tf.keras.Model(inputs, outputs, name="mobilenetv3small_cuelens")


def representative_dataset(split: dict):
    dataset_dir = ROOT / split["dataset_dir"]
    for entry in split["train"][:200]:
        image = tf.io.decode_image(tf.io.read_file(str(dataset_dir / entry["file"])), channels=3, expand_animations=False)
        image = tf.image.resize(image, (IMAGE_SIZE, IMAGE_SIZE))
        image = tf.cast(image, tf.float32)
        yield [tf.expand_dims(image, axis=0)]


def export_tflite(model: tf.keras.Model, split: dict, filename: str, quantize_int8: bool) -> None:
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

    model = build_model()
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-3),
        loss="categorical_crossentropy",
        metrics=["accuracy", tf.keras.metrics.Precision(name="precision"), tf.keras.metrics.Recall(name="recall")],
    )
    callbacks = [
        tf.keras.callbacks.EarlyStopping(monitor="val_loss", patience=5, restore_best_weights=True),
        tf.keras.callbacks.ModelCheckpoint(EXPORT_DIR / "best.keras", monitor="val_loss", save_best_only=True),
    ]
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_HEAD, callbacks=callbacks, verbose=2)

    backbone = next(
        (
            layer
            for layer in model.layers
            if isinstance(layer, tf.keras.Model) and "mobilenet" in layer.name.lower()
        ),
        None,
    )
    if backbone is None:
        raise RuntimeError(f"Could not find MobileNet backbone in {[layer.name for layer in model.layers]}")
    backbone.trainable = True
    for layer in backbone.layers[:-25]:
        layer.trainable = False
    model.compile(
        optimizer=tf.keras.optimizers.Adam(learning_rate=1e-5),
        loss="categorical_crossentropy",
        metrics=["accuracy", tf.keras.metrics.Precision(name="precision"), tf.keras.metrics.Recall(name="recall")],
    )
    model.fit(train_ds, validation_data=val_ds, epochs=EPOCHS_FINE_TUNE, callbacks=callbacks, verbose=2)

    test_metrics = model.evaluate(test_ds, return_dict=True)
    export_tflite(model, split, "mobilenetv3small_cuelens_float32.tflite", quantize_int8=False)
    export_tflite(model, split, "mobilenetv3small_cuelens_int8.tflite", quantize_int8=True)
    (EXPORT_DIR / "labels.txt").write_text("\n".join(LABELS) + "\n", encoding="utf-8")
    report = {
        "model_id": "mobilenetv3small_transfer_int8",
        "labels": LABELS,
        "input_size": [IMAGE_SIZE, IMAGE_SIZE, 3],
        "input_value_range": "raw RGB 0..255; model graph rescales to -1..1",
        "split_seed": split["split_seed"],
        "train_count": len(split["train"]),
        "validation_count": len(split["validation"]),
        "test_count": len(split["test"]),
        "keras_test_metrics": {key: float(value) for key, value in test_metrics.items()},
        "notes": "Evaluate exported TFLite models separately before Android benchmark interpretation.",
    }
    (EXPORT_DIR / "training_report.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
