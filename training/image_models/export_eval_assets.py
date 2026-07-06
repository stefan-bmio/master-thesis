#!/usr/bin/env python3
from __future__ import annotations

import json
import shutil
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SPLIT_FILE = ROOT / "training" / "image_models" / "dataset_split.json"
ASSET_ROOT = ROOT / "AI_PoC" / "app" / "src" / "benchmark" / "assets"
EVALSET_DIR = ASSET_ROOT / "evalset"
MANIFEST_FILE = ASSET_ROOT / "eval_manifest.json"


def main() -> None:
    split = json.loads(SPLIT_FILE.read_text(encoding="utf-8"))
    dataset_dir = ROOT / split["dataset_dir"]

    EVALSET_DIR.mkdir(parents=True, exist_ok=True)
    manifest = []

    for entry in split["test"]:
        source = dataset_dir / entry["file"]
        technical_label = entry["technical_label"]
        destination_dir = EVALSET_DIR / technical_label
        destination_dir.mkdir(parents=True, exist_ok=True)
        destination = destination_dir / Path(entry["file"]).name
        shutil.copy2(source, destination)
        manifest.append(
            {
                "asset_path": str(destination.relative_to(ASSET_ROOT)),
                "label": entry["label"],
                "technical_label": technical_label,
                "sha256": entry["sha256"],
            }
        )

    MANIFEST_FILE.write_text(json.dumps(manifest, indent=2, ensure_ascii=False) + "\n", encoding="utf-8")
    print(f"Wrote {MANIFEST_FILE.relative_to(ROOT)} with {len(manifest)} images")


if __name__ == "__main__":
    main()
