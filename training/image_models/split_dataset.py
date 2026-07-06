#!/usr/bin/env python3
from __future__ import annotations

import hashlib
import json
import random
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
DATASET_DIR = ROOT / "data" / "cuelens_images_224"
OUTPUT = ROOT / "training" / "image_models" / "dataset_split.json"
SPLIT_SEED = 20260705
TRAIN_RATIO = 0.70
VALIDATION_RATIO = 0.15
LABELS = [
    ("ashtray", "ashtray"),
    ("cigarette", "cigarette"),
    ("cigarette_pack", "cigarette pack"),
    ("people_smoking", "people smoking"),
    ("smoke", "smoke"),
    ("negative", "negative"),
]
IMAGE_SUFFIXES = {".jpg", ".jpeg", ".png", ".webp"}


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def image_entries(technical_label: str, label: str) -> list[dict[str, str]]:
    class_dir = DATASET_DIR / technical_label
    if not class_dir.is_dir():
        raise SystemExit(f"Missing dataset directory: {class_dir}")

    entries = []
    for path in sorted(class_dir.iterdir()):
        if path.is_file() and path.suffix.lower() in IMAGE_SUFFIXES:
            entries.append(
                {
                    "file": str(path.relative_to(DATASET_DIR)),
                    "technical_label": technical_label,
                    "label": label,
                    "sha256": sha256(path),
                }
            )
    if not entries:
        raise SystemExit(f"No images found for {technical_label}")
    return entries


def split_entries(entries: list[dict[str, str]]) -> tuple[list[dict[str, str]], list[dict[str, str]], list[dict[str, str]]]:
    items = list(entries)
    random.Random(SPLIT_SEED).shuffle(items)

    train_count = int(round(len(items) * TRAIN_RATIO))
    validation_count = int(round(len(items) * VALIDATION_RATIO))
    train = items[:train_count]
    validation = items[train_count : train_count + validation_count]
    test = items[train_count + validation_count :]
    return train, validation, test


def main() -> None:
    output = {
        "version": 1,
        "dataset_dir": str(DATASET_DIR.relative_to(ROOT)),
        "labels": [label for _, label in LABELS],
        "technical_labels": [technical for technical, _ in LABELS],
        "split_seed": SPLIT_SEED,
        "ratios": {
            "train": TRAIN_RATIO,
            "validation": VALIDATION_RATIO,
            "test": round(1.0 - TRAIN_RATIO - VALIDATION_RATIO, 2),
        },
        "train": [],
        "validation": [],
        "test": [],
    }

    for technical_label, label in LABELS:
        train, validation, test = split_entries(image_entries(technical_label, label))
        output["train"].extend(train)
        output["validation"].extend(validation)
        output["test"].extend(test)

    OUTPUT.parent.mkdir(parents=True, exist_ok=True)
    OUTPUT.write_text(json.dumps(output, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")

    print(f"Wrote {OUTPUT.relative_to(ROOT)}")
    for split_name in ("train", "validation", "test"):
        print(f"{split_name}: {len(output[split_name])}")


if __name__ == "__main__":
    main()
