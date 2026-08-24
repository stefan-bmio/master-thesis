#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
MANIFEST="$PROJECT_ROOT/Documentation/RELEASE_MANIFEST.json"
TRACEABILITY="$PROJECT_ROOT/Documentation/IOS_FUN_TRACEABILITY_MATRIX.md"

for document in \
  RELEASE_MANIFEST.json \
  IOS_FUN_TRACEABILITY_MATRIX.md \
  DEFINITION_OF_DONE_AUDIT.md \
  KNOWN_ISSUES.md \
  IMPLEMENTED_ARCHITECTURE.md \
  LONG_TERM_TEST_PROTOCOL.md \
  TESTFLIGHT_AND_APP_REVIEW_RUNBOOK.md \
  ETHICS_AND_STUDY_EVIDENCE_REGISTER.md \
  FORMAL_RELEASE_CHECKLIST.md; do
  test -s "$PROJECT_ROOT/Documentation/$document"
done

python3 - "$PROJECT_ROOT" "$MANIFEST" <<'PY'
import hashlib
import json
import pathlib
import subprocess
import sys

root = pathlib.Path(sys.argv[1])
manifest = json.loads(pathlib.Path(sys.argv[2]).read_text(encoding="utf-8"))

assert manifest["schema_version"] == 1
assert manifest["release_status"] == "blocked"
assert manifest["application"] == {
    "name": "CueLens",
    "bundle_identifier": "de.eachandevery.cuelens",
    "marketing_version": "1.0.0",
    "build_number": "1",
    "minimum_ios_version": "17.0",
    "configuration": "Release",
    "cooldown_seconds": 10800,
}
assert manifest["toolchain"]["xcode"] == "26.6"
assert manifest["toolchain"]["xcode_build"] == "17F113"
assert len(manifest["blocking_gates"]) == 7

commit = manifest["source"]["commit"]
subprocess.run(
    ["git", "cat-file", "-e", f"{commit}^{{commit}}"],
    cwd=root,
    check=True,
)

def digest(path: pathlib.Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()

expected = {
    root / "PLATFORM_INDEPENDENT_SPECIFICATION.md": manifest["source"]["platform_specification_sha256"],
    root / "IOS_ARCHITECTURE_AND_IMPLEMENTATION_PLAN.md": manifest["source"]["architecture_plan_sha256"],
    root / "Resources/Study/study-content-v1.json": manifest["content"]["study_content_sha256"],
    root / "Resources/Study/study-assets-manifest-v1.json": manifest["content"]["study_assets_manifest_sha256"],
}
for path, expected_hash in expected.items():
    assert digest(path) == expected_hash, f"Hash mismatch: {path}"

verification = manifest["verification"]
assert verification["unit_tests_ios_26_5"] == 170
assert verification["unit_tests_ios_17_5"] == 170
assert verification["ui_tests_iphone_ios_26_5"] == 25
assert verification["ui_tests_ipad_ios_26_5"] == 25
assert verification["quality_gate"] == "passed"
assert verification["distribution_archive"] == "not-created"
assert verification["testflight"] == "not-uploaded"
PY

for number in $(jot -w '%03d' 35 1); do
  count=$(rg -c "^\\| IOS-FUN-$number \\|" "$TRACEABILITY" || true)
  if [ "$count" -ne 1 ]; then
    echo "IOS-FUN-$number muss genau einmal in der Rückverfolgbarkeitsmatrix stehen." >&2
    exit 1
  fi
done

rg -q 'RELEASE BLOCKED' "$PROJECT_ROOT/Documentation/DEFINITION_OF_DONE_AUDIT.md"
rg -q 'NICHT DURCHGEFÜHRT' "$PROJECT_ROOT/Documentation/LONG_TERM_TEST_PROTOCOL.md"
rg -q 'NICHT FREIGEGEBEN' "$PROJECT_ROOT/Documentation/FORMAL_RELEASE_CHECKLIST.md"
rg -q 'REL-007' "$PROJECT_ROOT/Documentation/KNOWN_ISSUES.md"

echo 'Release-Dokumentation und Rückverfolgbarkeit erfolgreich geprüft; formale Freigabe bleibt blockiert.'
