#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
APP_DIR="$PROJECT_ROOT/CueLens"
PRIVACY_MANIFEST="$APP_DIR/Resources/PrivacyInfo.xcprivacy"

plutil -lint "$PRIVACY_MANIFEST" >/dev/null
test -f "$PROJECT_ROOT/Documentation/APP_PRIVACY_DATA_FLOW_MATRIX.md"
test -f "$PROJECT_ROOT/Documentation/SECURITY_ACCESSIBILITY_REVIEW_CHECKLIST.md"

test "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' "$PRIVACY_MANIFEST")" = 'false'
if /usr/libexec/PlistBuddy -c 'Print :NSPrivacyTrackingDomains:0' "$PRIVACY_MANIFEST" >/dev/null 2>&1; then
  echo 'Trackingdomains sind nicht zulässig.' >&2
  exit 1
fi

for type in EmailAddress UserID Health OtherUserContent; do
  rg -q "NSPrivacyCollectedDataType$type" "$PRIVACY_MANIFEST"
done
test "$(rg -c '<key>NSPrivacyCollectedDataTypeTracking</key>' "$PRIVACY_MANIFEST")" -eq 4
test "$(rg -c '<false/>' "$PRIVACY_MANIFEST")" -ge 6

forbidden_code=$(rg -n \
  '\b(CloudKit|CKContainer|NSUbiquitousKeyValueStore|HKHealthStore|AdSupport|ASIdentifierManager|AppTrackingTransparency|ATTrackingManager)\b' \
  "$APP_DIR" || true)
if [ -n "$forbidden_code" ]; then
  echo 'Verbotene Cloud-, HealthKit-, Werbe- oder Tracking-API gefunden:' >&2
  echo "$forbidden_code" >&2
  exit 1
fi

unsafe_swift=$(rg -n 'try!|as!' "$APP_DIR" --glob '*.swift' || true)
if [ -n "$unsafe_swift" ]; then
  echo 'Unsicherer Swift-Zwangsoperator im Produktionscode gefunden:' >&2
  echo "$unsafe_swift" >&2
  exit 1
fi

logger_sites=$(rg -l '\b(Logger|os_log|NSLog|print|debugPrint)\b' "$APP_DIR" --glob '*.swift' || true)
expected_logger="$APP_DIR/Infrastructure/Network/NetworkLogging.swift"
if [ -n "$logger_sites" ] && [ "$logger_sites" != "$expected_logger" ]; then
  echo 'Unerwartete Loggingstelle im Produktionscode gefunden:' >&2
  echo "$logger_sites" >&2
  exit 1
fi
if rg -n '\b(app_token|identifier|craving|compensation_code|comment|source|payload|body)\b' "$expected_logger"; then
  echo 'Sensible Datenbezeichnung im einzigen erlaubten Logger gefunden.' >&2
  exit 1
fi

rg -Fq 'accessibilityHidden(true)' "$APP_DIR/App/ProductiveStudyView.swift"
rg -q 'study.imageOption.first' "$APP_DIR/App/ProductiveStudyView.swift"
rg -q 'study.imageOption.second' "$APP_DIR/App/ProductiveStudyView.swift"
rg -q 'accessibilityFocused' "$APP_DIR/App/ContentView.swift"
rg -q 'CueLensPalette.error' "$APP_DIR/App/ContentView.swift"

sh -n "$SCRIPT_DIR/verify_release_archive.sh"

echo 'Security-, Datenschutz- und Accessibility-Härtungsinvarianten erfolgreich geprüft.'
