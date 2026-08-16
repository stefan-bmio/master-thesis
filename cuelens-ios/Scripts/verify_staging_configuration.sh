#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA=${1:-}
CREATED_DERIVED_DATA=0
if [ -z "$DERIVED_DATA" ]; then
  DERIVED_DATA=$(mktemp -d /private/tmp/cuelens-staging-verify.XXXXXX)
  CREATED_DERIVED_DATA=1
fi
cleanup() {
  if [ "$CREATED_DERIVED_DATA" -eq 1 ]; then rm -rf -- "$DERIVED_DATA"; fi
}
trap cleanup EXIT HUP INT TERM

cd "$PROJECT_ROOT"
xcodebuild -quiet -project CueLens.xcodeproj -scheme 'CueLens Staging' \
  -configuration Staging -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build

INFO_PLIST="$DERIVED_DATA/Build/Products/Staging-iphonesimulator/CueLens.app/Info.plist"
test -f "$INFO_PLIST"
test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_ALLOWS_LOCAL_HTTP' "$INFO_PLIST")" = 'YES'
test "$(/usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsLocalNetworking' "$INFO_PLIST")" = 'true'
if /usr/libexec/PlistBuddy -c 'Print :NSAppTransportSecurity:NSAllowsArbitraryLoads' "$INFO_PLIST" >/dev/null 2>&1; then
  echo 'Staging darf keine globale ATS-Ausnahme enthalten.' >&2
  exit 1
fi
for key in ACTIVATION MESSAGES FEEDBACK FEATURES SUBMIT; do
  value=$(/usr/libexec/PlistBuddy -c "Print :CUELENS_${key}_URL" "$INFO_PLIST")
  case "$value" in
    http://192.168.1.243/cuelens/*.php) ;;
    *) echo "Unerwarteter Staging-Endpunkt: $value" >&2; exit 1 ;;
  esac
done
echo 'Lokale Staging-Transportkonfiguration erfolgreich verifiziert.'
