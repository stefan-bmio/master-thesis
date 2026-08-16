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
test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_ALLOWS_LOCAL_HTTP' "$INFO_PLIST")" = 'NO'

test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_ACTIVATION_URL' "$INFO_PLIST")" = \
  'https://cuelens.each-and-every.de/activate.php'
test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_MESSAGES_URL' "$INFO_PLIST")" = \
  'https://cuelens.each-and-every.de/messages.php'
test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_FEEDBACK_URL' "$INFO_PLIST")" = \
  'https://cuelens.each-and-every.de/feedback.php'
test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_FEATURES_URL' "$INFO_PLIST")" = \
  'https://cuelens.each-and-every.de/features.php'
test "$(/usr/libexec/PlistBuddy -c 'Print :CUELENS_SUBMIT_URL' "$INFO_PLIST")" = \
  'https://cuelens.each-and-every.de/submit.php'

FORBIDDEN_KEYS='NSCameraUsageDescription NSPhotoLibraryUsageDescription NSPhotoLibraryAddUsageDescription NSMicrophoneUsageDescription NSLocationWhenInUseUsageDescription NSLocationAlwaysUsageDescription NSLocationAlwaysAndWhenInUseUsageDescription NSContactsUsageDescription NSCalendarsUsageDescription NSBluetoothAlwaysUsageDescription NSBluetoothPeripheralUsageDescription NSUserTrackingUsageDescription NSLocalNetworkUsageDescription NSAppTransportSecurity'
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
ACCESSED_API_TYPE=$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType' "$PRIVACY_MANIFEST")
ACCESSED_API_REASON=$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0' "$PRIVACY_MANIFEST")
test "$ACCESSED_API_TYPE" = 'NSPrivacyAccessedAPICategoryFileTimestamp'
test "$ACCESSED_API_REASON" = 'C617.1'
USER_DEFAULTS_API_TYPE=$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPIType' "$PRIVACY_MANIFEST")
USER_DEFAULTS_API_REASON=$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPITypeReasons:0' "$PRIVACY_MANIFEST")
test "$USER_DEFAULTS_API_TYPE" = 'NSPrivacyAccessedAPICategoryUserDefaults'
test "$USER_DEFAULTS_API_REASON" = 'CA92.1'

if grep -R -a -q -E 'debug\.invalid|staging\.invalid' "$APP_BUNDLE"; then
  echo 'Release-Artefakt enthält Debug-/Staging-Endpunkte.' >&2
  exit 1
fi
if grep -R -a -q '192\.168\.1\.243' "$APP_BUNDLE"; then
  echo 'Release-Artefakt enthält den lokalen Staging-Host.' >&2
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
require_build_setting() {
  case "$BUILD_SETTINGS" in
    *"$1"*) ;;
    *)
      echo "Erwartetes Release-Buildsetting fehlt: $1" >&2
      exit 1
      ;;
  esac
}
require_build_setting 'SWIFT_STRICT_CONCURRENCY = complete'
require_build_setting 'SWIFT_TREAT_WARNINGS_AS_ERRORS = YES'
require_build_setting 'GCC_TREAT_WARNINGS_AS_ERRORS = YES'
require_build_setting 'DEBUG_INFORMATION_FORMAT = dwarf-with-dsym'
require_build_setting 'PRODUCT_BUNDLE_IDENTIFIER = de.eachandevery.cuelens'

echo 'Release-Konfiguration erfolgreich verifiziert.'
