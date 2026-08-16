#!/usr/bin/env python3
"""Validate CueLens study resources, schemas, cross-references, and provenance."""

from __future__ import annotations

import json
import shutil
import subprocess
import sys
from pathlib import Path
from typing import Any

from generate_study_resources import (
    ASSET_MANIFEST_PATH,
    ASSET_ROOT,
    CONTENT_PATH,
    EXPECTED_INDICES,
    IOS_ROOT,
    PREFIXES,
    ResourceError,
    build_asset_manifest,
    build_content,
    source_assets,
    verify_expected_state,
)


CONTENT_SCHEMA = IOS_ROOT / "Schemas/study-content-v1.schema.json"
ASSET_SCHEMA = IOS_ROOT / "Schemas/study-assets-manifest-v1.schema.json"
PROHIBITED_SUFFIXES = {
    ".tflite",
    ".lite",
    ".mlmodel",
    ".mlpackage",
    ".onnx",
    ".pt",
    ".pth",
}


def load_json(path: Path) -> dict[str, Any]:
    with path.open(encoding="utf-8") as handle:
        value = json.load(handle)
    if not isinstance(value, dict):
        raise ResourceError(f"JSON-Wurzel ist kein Objekt: {path}")
    return value


def schema_validator() -> str:
    local = IOS_ROOT / ".venv/bin/check-jsonschema"
    if local.is_file():
        return str(local)
    executable = shutil.which("check-jsonschema")
    if executable:
        return executable
    raise ResourceError(
        "check-jsonschema fehlt. Installation: "
        "python3 -m venv .venv && .venv/bin/python -m pip install "
        "-r Tools/requirements-dev.txt"
    )


def validate_schema(schema: Path, instance: Path) -> None:
    subprocess.run(
        [schema_validator(), "--schemafile", str(schema), str(instance)],
        cwd=IOS_ROOT,
        check=True,
    )


def ensure_unique(values: list[Any], description: str) -> None:
    if len(values) != len(set(values)):
        raise ResourceError(f"Nicht eindeutige Werte: {description}")


def validate_semantics(content: dict[str, Any], manifest: dict[str, Any]) -> None:
    matching = content["matching"]
    labeling = content["labeling"]
    expected_indices = list(EXPECTED_INDICES)
    if [item["index"] for item in matching] != expected_indices:
        raise ResourceError("Matching-Indizes sind nicht lückenlos und sortiert 0...49")
    if [item["index"] for item in labeling] != expected_indices:
        raise ResourceError("Labeling-Indizes sind nicht lückenlos und sortiert 0...49")

    ensure_unique([item["cue"] for item in matching], "Matching-Cues")
    ensure_unique([item["cue"] for item in labeling], "Labeling-Cues")
    for index, item in enumerate(matching):
        expected = {
            "cue": f"cue_{index:03d}",
            "match_a": f"match_a_{index:03d}",
            "match_b": f"match_b_{index:03d}",
        }
        if any(item[key] != value for key, value in expected.items()):
            raise ResourceError(f"Inkonsistente Matching-Zuordnung bei Index {index}")
    for index, item in enumerate(labeling):
        if item["cue"] != f"cue_{index:03d}":
            raise ResourceError(f"Inkonsistente Labeling-Zuordnung bei Index {index}")

    assets = manifest["assets"]
    ids = [item["id"] for item in assets]
    filenames = [item["filename"] for item in assets]
    ensure_unique(ids, "Asset-IDs")
    ensure_unique(filenames, "Asset-Dateinamen")
    expected_ids = {
        f"{prefix}_{index:03d}" for prefix in PREFIXES for index in EXPECTED_INDICES
    }
    if set(ids) != expected_ids:
        raise ResourceError("Assetmanifest enthält nicht exakt die erwarteten 150 IDs")
    referenced_ids = {
        value
        for item in matching
        for key, value in item.items()
        if key in {"cue", "match_a", "match_b"}
    }
    referenced_ids.update(item["cue"] for item in labeling)
    if not referenced_ids.issubset(set(ids)):
        raise ResourceError("Contentmanifest referenziert ein fehlendes Asset")


def validate_no_models() -> None:
    prohibited = [
        path
        for path in (IOS_ROOT / "Resources").rglob("*")
        if path.is_file() and path.suffix.lower() in PROHIBITED_SUFFIXES
    ]
    if prohibited:
        raise ResourceError(f"Unzulässige KI-/Modelldateien gefunden: {prohibited}")


def main() -> int:
    try:
        assets = source_assets()
        expected_content = build_content()
        expected_manifest = build_asset_manifest(assets)
        verify_expected_state(assets, expected_content, expected_manifest)
        validate_schema(CONTENT_SCHEMA, CONTENT_PATH)
        validate_schema(ASSET_SCHEMA, ASSET_MANIFEST_PATH)
        content = load_json(CONTENT_PATH)
        manifest = load_json(ASSET_MANIFEST_PATH)
        validate_semantics(content, manifest)
        validate_no_models()
    except subprocess.CalledProcessError as error:
        print(f"FEHLER: JSON-Schema-Validierung fehlgeschlagen ({error}).", file=sys.stderr)
        return 1
    except (KeyError, OSError, ResourceError, UnicodeError, json.JSONDecodeError) as error:
        print(f"FEHLER: {error}", file=sys.stderr)
        return 1

    print("Validierung erfolgreich:")
    print("- 50 Cue-, 50 Match-A- und 50 Match-B-Assets")
    print("- 50 Matching- und 50 Labeling-Zuordnungen")
    print("- Byteidentität, SHA-256 und 512-x-512-Abmessungen bestätigt")
    print("- JSON-Schemata und semantische Querverweise gültig")
    print("- keine KI-/Modelldateien in den Studienressourcen")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())

