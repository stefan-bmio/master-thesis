#!/usr/bin/env python3
"""Generate the frozen CueLens iOS study-resource snapshot deterministically."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import shutil
import struct
import sys
from pathlib import Path
from typing import Any


IOS_ROOT = Path(__file__).resolve().parents[1]
REPOSITORY_ROOT = IOS_ROOT.parent
SPECIFICATION = IOS_ROOT / "PLATFORM_INDEPENDENT_SPECIFICATION.md"
ANDROID_DRAWABLE = REPOSITORY_ROOT / "cuelens/app/src/main/res/drawable"
ANDROID_MAIN_ACTIVITY = (
    REPOSITORY_ROOT
    / "cuelens/app/src/main/java/de/eachandevery/cuelens/MainActivity.kt"
)
STUDY_ROOT = IOS_ROOT / "Resources/Study"
ASSET_ROOT = STUDY_ROOT / "Assets"
CONTENT_PATH = STUDY_ROOT / "study-content-v1.json"
ASSET_MANIFEST_PATH = STUDY_ROOT / "study-assets-manifest-v1.json"
PREFIXES = ("cue", "match_a", "match_b")
EXPECTED_INDICES = tuple(range(50))
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


class ResourceError(RuntimeError):
    """Raised when a source or generated study resource violates an invariant."""


def canonical_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=False, indent=2) + "\n"


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def png_dimensions(path: Path) -> tuple[int, int]:
    with path.open("rb") as handle:
        header = handle.read(24)
    if len(header) != 24 or header[:8] != PNG_SIGNATURE or header[12:16] != b"IHDR":
        raise ResourceError(f"Keine gültige PNG-IHDR-Struktur: {path}")
    return struct.unpack(">II", header[16:24])


def source_assets() -> list[tuple[str, Path]]:
    expected_names = [
        f"{prefix}_{index:03d}.png"
        for prefix in PREFIXES
        for index in EXPECTED_INDICES
    ]
    actual_names = sorted(
        path.name
        for path in ANDROID_DRAWABLE.glob("*.png")
        if path.name.startswith(("cue_", "match_a_", "match_b_"))
    )
    if sorted(expected_names) != actual_names:
        missing = sorted(set(expected_names) - set(actual_names))
        unexpected = sorted(set(actual_names) - set(expected_names))
        raise ResourceError(
            f"Android-Assetmenge ungültig; fehlend={missing}, unerwartet={unexpected}"
        )
    return [(Path(name).stem, ANDROID_DRAWABLE / name) for name in expected_names]


def specification_labels() -> list[tuple[str, str, str, str, str]]:
    rows: list[tuple[str, str, str, str, str]] = []
    for line in SPECIFICATION.read_text(encoding="utf-8").splitlines():
        if not re.match(r"^\| `cue_\d{3}` \|", line):
            continue
        cells = [cell.strip() for cell in line.strip().strip("|").split("|")]
        if len(cells) != 5:
            raise ResourceError(f"Ungültige Labeltabellenzeile: {line}")
        cue = cells[0].strip("`")
        rows.append((cue, cells[1], cells[2], cells[3], cells[4]))
    validate_label_rows(rows, "Anhang A")
    return rows


def android_labels() -> list[tuple[str, str, str, str, str]]:
    source = ANDROID_MAIN_ACTIVITY.read_text(encoding="utf-8")
    pattern = re.compile(
        r'CueLabelMapping\("([^"]+)",\s*"([^"]*)",\s*"([^"]*)",'
        r'\s*"([^"]*)",\s*"([^"]*)"\)'
    )
    rows = [tuple(match) for match in pattern.findall(source)]
    validate_label_rows(rows, "Android CueLabelMapping")
    return rows


def validate_label_rows(
    rows: list[tuple[str, str, str, str, str]], source_name: str
) -> None:
    expected_cues = [f"cue_{index:03d}" for index in EXPECTED_INDICES]
    actual_cues = [row[0] for row in rows]
    if actual_cues != expected_cues:
        raise ResourceError(
            f"{source_name}: erwartet cue_000...cue_049, erhalten {actual_cues}"
        )
    if any(not value for row in rows for value in row[1:]):
        raise ResourceError(f"{source_name}: leeres Label gefunden")


def build_content() -> dict[str, Any]:
    spec_rows = specification_labels()
    android_rows = android_labels()
    if spec_rows != android_rows:
        differences = [
            {"index": index, "specification": spec, "android": android}
            for index, (spec, android) in enumerate(zip(spec_rows, android_rows))
            if spec != android
        ]
        raise ResourceError(
            "Labelzuordnungen weichen zwischen Spezifikation und Android ab: "
            + json.dumps(differences, ensure_ascii=False)
        )

    matching = [
        {
            "index": index,
            "cue": f"cue_{index:03d}",
            "match_a": f"match_a_{index:03d}",
            "match_b": f"match_b_{index:03d}",
        }
        for index in EXPECTED_INDICES
    ]
    labeling = [
        {
            "index": index,
            "cue": row[0],
            "de": {"fitting": row[1], "less_fitting": row[2]},
            "en": {"fitting": row[3], "less_fitting": row[4]},
        }
        for index, row in enumerate(spec_rows)
    ]
    return {
        "version": 1,
        "matching": matching,
        "labeling": labeling,
        "demo": {"matching_index": 0, "labeling_index": 1},
    }


def build_asset_manifest(assets: list[tuple[str, Path]]) -> dict[str, Any]:
    entries: list[dict[str, Any]] = []
    for logical_id, source in assets:
        width, height = png_dimensions(source)
        entries.append(
            {
                "id": logical_id,
                "filename": source.name,
                "sha256": sha256(source),
                "pixel_width": width,
                "pixel_height": height,
            }
        )
    return {"version": 1, "hash_algorithm": "sha256", "assets": entries}


def verify_expected_state(
    assets: list[tuple[str, Path]], content: dict[str, Any], manifest: dict[str, Any]
) -> None:
    expected_filenames = {source.name for _, source in assets}
    actual_filenames = {path.name for path in ASSET_ROOT.glob("*.png")}
    if actual_filenames != expected_filenames:
        raise ResourceError(
            "iOS-Assetmenge weicht ab; "
            f"fehlend={sorted(expected_filenames - actual_filenames)}, "
            f"unerwartet={sorted(actual_filenames - expected_filenames)}"
        )
    for _, source in assets:
        destination = ASSET_ROOT / source.name
        if sha256(source) != sha256(destination):
            raise ResourceError(f"Asset ist nicht bytegleich: {destination}")

    expected_documents = {
        CONTENT_PATH: canonical_json(content),
        ASSET_MANIFEST_PATH: canonical_json(manifest),
    }
    for path, expected in expected_documents.items():
        if not path.is_file() or path.read_text(encoding="utf-8") != expected:
            raise ResourceError(f"Generierte Datei ist nicht reproduzierbar: {path}")


def generate() -> None:
    assets = source_assets()
    content = build_content()
    manifest = build_asset_manifest(assets)
    ASSET_ROOT.mkdir(parents=True, exist_ok=True)
    for _, source in assets:
        destination = ASSET_ROOT / source.name
        if not destination.exists() or sha256(source) != sha256(destination):
            shutil.copyfile(source, destination)
    CONTENT_PATH.write_text(canonical_json(content), encoding="utf-8")
    ASSET_MANIFEST_PATH.write_text(canonical_json(manifest), encoding="utf-8")
    verify_expected_state(assets, content, manifest)


def check() -> None:
    assets = source_assets()
    content = build_content()
    manifest = build_asset_manifest(assets)
    verify_expected_state(assets, content, manifest)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument(
        "--check",
        action="store_true",
        help="Prüft den generierten Zustand, ohne Dateien zu verändern.",
    )
    arguments = parser.parse_args()
    try:
        check() if arguments.check else generate()
    except (OSError, ResourceError, UnicodeError, json.JSONDecodeError) as error:
        print(f"FEHLER: {error}", file=sys.stderr)
        return 1
    print("Studienressourcen sind vollständig und reproduzierbar.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

