#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo 'Verwendung: Scripts/verify_release_candidate.sh <distribution-signiertes-CueLens.xcarchive>' >&2
  exit 64
fi

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
ARCHIVE=$1

cd "$PROJECT_ROOT"

if ! git diff --quiet -- . || ! git diff --cached --quiet -- .; then
  echo 'Release-Verifikation erfordert einen unveränderten getrackten Arbeitsbaum.' >&2
  exit 1
fi

"$SCRIPT_DIR/verify_release_documentation.sh"
"$SCRIPT_DIR/quality_gate.sh"

ANALYZE_DATA=$(mktemp -d /private/tmp/cuelens-release-analyze.XXXXXX)
cleanup() { rm -rf -- "$ANALYZE_DATA"; }
trap cleanup EXIT HUP INT TERM

xcodebuild -quiet \
  -project CueLens.xcodeproj \
  -scheme CueLens \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath "$ANALYZE_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  analyze

"$SCRIPT_DIR/verify_release_archive.sh" "$ARCHIVE"

echo 'Technischer CueLens-Release-Candidate vollständig verifiziert.'
