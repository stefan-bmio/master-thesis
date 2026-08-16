#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA=$(mktemp -d /private/tmp/cuelens-quality-gate.XXXXXX)
RESULTS_DIR=$(mktemp -d /private/tmp/cuelens-test-results.XXXXXX)

cleanup() {
  rm -rf -- "$DERIVED_DATA" "$RESULTS_DIR"
}
trap cleanup EXIT HUP INT TERM

cd "$PROJECT_ROOT"

$SCRIPT_DIR/verify_domain_boundaries.sh
$SCRIPT_DIR/verify_persistence_security.sh

EXPECTED_XCODE='Xcode 26.6'
EXPECTED_BUILD='Build version 17F113'
XCODE_VERSION=$(xcodebuild -version)
printf '%s\n' "$XCODE_VERSION" | grep -q "^$EXPECTED_XCODE$"
printf '%s\n' "$XCODE_VERSION" | grep -q "^$EXPECTED_BUILD$"

IPHONE_ID=$($SCRIPT_DIR/select_ci_simulator.sh iphone)
IPAD_ID=$($SCRIPT_DIR/select_ci_simulator.sh ipad)
IOS_RUNTIME=$(xcrun simctl list runtimes | awk '/^iOS .* - com\.apple\.CoreSimulator\.SimRuntime\.iOS-/{line=$0} END {print line}')

echo "Quality-Gate: Xcode 26.6 (17F113), iPhone $IPHONE_ID, iPad $IPAD_ID"
echo "Simulator-Runtime: $IOS_RUNTIME"

for device_id in "$IPHONE_ID" "$IPAD_ID"; do
  xcrun simctl boot "$device_id" >/dev/null 2>&1 || true
  if ! xcrun simctl bootstatus "$device_id" -b >/dev/null; then
    echo "Simulator-Erstmigration noch nicht vollständig; Status wird erneut geprüft: $device_id" >&2
    xcrun simctl bootstatus "$device_id" -b >/dev/null
  fi
done

xcodebuild -quiet -project CueLens.xcodeproj -scheme CueLens -configuration Debug -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project CueLens.xcodeproj -scheme 'CueLens Staging' -configuration Staging -destination 'generic/platform=iOS Simulator' -derivedDataPath "$DERIVED_DATA" CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project CueLens.xcodeproj -scheme CueLens -destination "platform=iOS Simulator,id=$IPHONE_ID" -derivedDataPath "$DERIVED_DATA" -resultBundlePath "$RESULTS_DIR/unit.xcresult" -only-testing:CueLensTests test

run_ui_smoke_test() {
  device_id=$1
  result_name=$2
  if ! xcodebuild -quiet -project CueLens.xcodeproj -scheme CueLens -destination "platform=iOS Simulator,id=$device_id" -derivedDataPath "$DERIVED_DATA" -resultBundlePath "$RESULTS_DIR/$result_name-attempt-1.xcresult" -only-testing:CueLensUITests/CueLensUITests/testLaunchesOnSupportedDevice test; then
    echo "UI-Smoke-Test wird nach abgeschlossener Simulator-Erstinitialisierung einmal wiederholt: $device_id" >&2
    xcodebuild -quiet -project CueLens.xcodeproj -scheme CueLens -destination "platform=iOS Simulator,id=$device_id" -derivedDataPath "$DERIVED_DATA" -resultBundlePath "$RESULTS_DIR/$result_name-attempt-2.xcresult" -only-testing:CueLensUITests/CueLensUITests/testLaunchesOnSupportedDevice test
  fi
}

run_ui_smoke_test "$IPHONE_ID" iphone
run_ui_smoke_test "$IPAD_ID" ipad
$SCRIPT_DIR/verify_release_configuration.sh "$DERIVED_DATA"

echo 'Lokales CueLens-Quality-Gate erfolgreich.'
