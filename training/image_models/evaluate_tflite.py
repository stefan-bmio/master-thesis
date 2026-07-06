#!/usr/bin/env python3
from __future__ import annotations

import json
from collections import defaultdict
from pathlib import Path

import numpy as np
import tensorflow as tf
from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
SPLIT_FILE = ROOT / "training" / "image_models" / "dataset_split.json"
LABELS = ["ashtray", "cigarette", "cigarette pack", "people smoking", "smoke", "negative"]
MODEL_DIRS = {
    "mobilenetv3small": ROOT / "training" / "image_models" / "artifacts" / "mobilenetv3small",
    "efficientnet_lite0": ROOT / "training" / "image_models" / "artifacts" / "efficientnet_lite0",
}


def load_image(path: Path) -> np.ndarray:
    image = Image.open(path).convert("RGB")
    if image.size != (224, 224):
        image = image.resize((224, 224), Image.Resampling.BILINEAR)
    return np.asarray(image, dtype=np.float32)


def prepare_input(image: np.ndarray, input_detail: dict) -> np.ndarray:
    input_data = np.expand_dims(image, axis=0)
    dtype = input_detail["dtype"]
    if dtype == np.float32:
        return input_data.astype(np.float32)

    scale, zero_point = input_detail["quantization"]
    if scale == 0:
        scale = 1.0
    quantized = np.round(input_data / scale + zero_point)
    if dtype == np.int8:
        quantized = np.clip(quantized, -128, 127)
    elif dtype == np.uint8:
        quantized = np.clip(quantized, 0, 255)
    return quantized.astype(dtype)


def read_output(output_data: np.ndarray, output_detail: dict) -> np.ndarray:
    output = np.squeeze(output_data)
    if output_detail["dtype"] == np.float32:
        return output.astype(np.float32)
    scale, zero_point = output_detail["quantization"]
    if scale == 0:
        scale = 1.0
    return (output.astype(np.float32) - zero_point) * scale


def evaluate_model(model_path: Path, split: dict) -> dict:
    interpreter = tf.lite.Interpreter(
        model_path=str(model_path),
        num_threads=2,
        experimental_preserve_all_tensors=True,
    )
    interpreter.allocate_tensors()
    input_detail = interpreter.get_input_details()[0]
    output_detail = interpreter.get_output_details()[0]
    dataset_dir = ROOT / split["dataset_dir"]
    label_to_index = {label: index for index, label in enumerate(LABELS)}

    correct = 0
    confusion = defaultdict(lambda: defaultdict(int))

    for entry in split["test"]:
        image = load_image(dataset_dir / entry["file"])
        interpreter.set_tensor(input_detail["index"], prepare_input(image, input_detail))
        interpreter.invoke()
        scores = read_output(interpreter.get_tensor(output_detail["index"]), output_detail)
        predicted_label = LABELS[int(np.argmax(scores))]
        true_label = entry["label"]
        correct += int(predicted_label == true_label)
        confusion[true_label][predicted_label] += 1

    n = len(split["test"])
    return {
        "file": model_path.name,
        "input_dtype": str(input_detail["dtype"]),
        "output_dtype": str(output_detail["dtype"]),
        "accuracy": correct / n,
        "correct": correct,
        "n": n,
        "confusion": {
            true_label: {pred_label: confusion[true_label][pred_label] for pred_label in LABELS}
            for true_label in LABELS
        },
    }


def main() -> None:
    split = json.loads(SPLIT_FILE.read_text(encoding="utf-8"))
    for model_name, artifact_dir in MODEL_DIRS.items():
        results = []
        for model_path in sorted(artifact_dir.glob("*.tflite")):
            results.append(evaluate_model(model_path, split))

        eval_report = {
            "model_family": model_name,
            "labels": LABELS,
            "split_seed": split["split_seed"],
            "test_count": len(split["test"]),
            "results": results,
        }
        (artifact_dir / "tflite_eval_report.json").write_text(
            json.dumps(eval_report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )

        training_report_path = artifact_dir / "training_report.json"
        training_report = json.loads(training_report_path.read_text(encoding="utf-8"))
        training_report["tflite_test_metrics"] = {
            result["file"]: {
                "accuracy": result["accuracy"],
                "correct": result["correct"],
                "n": result["n"],
                "input_dtype": result["input_dtype"],
                "output_dtype": result["output_dtype"],
            }
            for result in results
        }
        training_report_path.write_text(
            json.dumps(training_report, indent=2, ensure_ascii=False) + "\n",
            encoding="utf-8",
        )
        print(f"Wrote {artifact_dir.relative_to(ROOT) / 'tflite_eval_report.json'}")


if __name__ == "__main__":
    main()
