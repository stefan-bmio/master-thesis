#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DERIVED_DATA=${1:-}
CREATED_DERIVED_DATA=0

if [ -z "$DERIVED_DATA" ]; then
  DERIVED_DATA=$(mktemp -d /private/tmp/cuelens-release-verify.XXXXXX)
  CREATED_DERIVED_DATA=1
fi

cleanup() {
  if [ "$CREATED_DERIVED_DATA" -eq 1 ]; then
    rm -rf -- "$DERIVED_DATA"
  fi
}
trap cleanup EXIT HUP INT TERM

cd "$PROJECT_ROOT"

xcodebuild -quiet \
  -project CueLens.xcodeproj \
  -scheme CueLens \
  -configuration Release \
  -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$DERIVED_DATA" \
  CODE_SIGNING_ALLOWED=NO \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release-iphonesimulator/CueLens.app"
INFO_PLIST="$APP_BUNDLE/Info.plist"
PRIVACY_MANIFEST="$APP_BUNDLE/PrivacyInfo.xcprivacy"

test -d "$APP_BUNDLE"
test -f "$INFO_PLIST"
test -f "$PRIVACY_MANIFEST"
plutil -lint "$INFO_PLIST" >/dev/null
plutil -lint "$PRIVACY_MANIFEST" >/dev/null

BUNDLE_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO_PLIST")
MINIMUM_OS=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$INFO_PLIST")
test "$BUNDLE_ID" = 'de.eachandevery.cuelens'
test "$MINIMUM_OS" = '17.0'

FORBIDDEN_KEYS='NSCameraUsageDescription NSPhotoLibraryUsageDescription NSPhotoLibraryAddUsageDescription NSMicrophoneUsageDescription NSLocationWhenInUseUsageDescription NSLocationAlwaysUsageDescription NSLocationAlwaysAndWhenInUseUsageDescription NSContactsUsageDescription NSCalendarsUsageDescription NSBluetoothAlwaysUsageDescription NSBluetoothPeripheralUsageDescription NSUserTrackingUsageDescription NSAppTransportSecurity'
for key in $FORBIDDEN_KEYS; do
  if /usr/libexec/PlistBuddy -c "Print :$key" "$INFO_PLIST" >/dev/null 2>&1; then
    echo "Unzulässiger Info.plist-Schlüssel: $key" >&2
    exit 1
  fi
done

IPHONE_ORIENTATIONS=$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~iphone' "$INFO_PLIST")
IPAD_ORIENTATIONS=$(/usr/libexec/PlistBuddy -c 'Print :UISupportedInterfaceOrientations~ipad' "$INFO_PLIST")
printf '%s\n' "$IPHONE_ORIENTATIONS" | grep -q 'UIInterfaceOrientationPortrait'
printf '%s\n' "$IPAD_ORIENTATIONS" | grep -q 'UIInterfaceOrientationPortrait'
if printf '%s\n' "$IPHONE_ORIENTATIONS" | grep -q 'Landscape'; then
  echo 'Die iPhone-Konfiguration enthält eine nicht erlaubte Landscape-Ausrichtung.' >&2
  exit 1
fi
for orientation in UIInterfaceOrientationPortraitUpsideDown UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight; do
  printf '%s\n' "$IPAD_ORIENTATIONS" | grep -q "$orientation"
done

TRACKING=$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' "$PRIVACY_MANIFEST")
test "$TRACKING" = 'false'

if grep -R -a -q -E 'debug\.invalid|staging\.invalid' "$APP_BUNDLE"; then
  echo 'Release-Artefakt enthält Debug-/Staging-Endpunkte.' >&2
  exit 1
fi
if grep -q 'cuelens\.each-and-every\.de' Config/Debug.xcconfig Config/Staging.xcconfig; then
  echo 'Produktivdomain außerhalb der Release-Konfiguration gefunden.' >&2
  exit 1
fi
if grep -q -E 'XCRemoteSwiftPackageReference|XCSwiftPackageProductDependency' CueLens.xcodeproj/project.pbxproj; then
  echo 'Unerlaubte Swift-Package-Abhängigkeit gefunden.' >&2
  exit 1
fi
if find CueLens -name '*.entitlements' -print -quit | grep -q .; then
  echo 'Unerwartete Entitlement-Datei gefunden.' >&2
  exit 1
fi

BUILD_SETTINGS=$(xcodebuild -project CueLens.xcodeproj -scheme CueLens -configuration Release -destination 'generic/platform=iOS Simulator' -showBuildSettings)
printf '%s\n' "$BUILD_SETTINGS" | grep -q 'SWIFT_STRICT_CONCURRENCY = complete'
printf '%s\n' "$BUILD_SETTINGS" | grep -q 'SWIFT_TREAT_WARNINGS_AS_ERRORS = YES'
printf '%s\n' "$BUILD_SETTINGS" | grep -q 'GCC_TREAT_WARNINGS_AS_ERRORS = YES'
printf '%s\n' "$BUILD_SETTINGS" | grep -q 'DEBUG_INFORMATION_FORMAT = dwarf-with-dsym'
printf '%s\n' "$BUILD_SETTINGS" | grep -q 'PRODUCT_BUNDLE_IDENTIFIER = de.eachandevery.cuelens'

echo 'Release-Konfiguration erfolgreich verifiziert.'
