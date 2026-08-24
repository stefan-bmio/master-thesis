#!/bin/sh
set -eu

if [ "$#" -ne 1 ]; then
  echo 'Verwendung: Scripts/verify_release_archive.sh <CueLens.xcarchive>' >&2
  exit 64
fi

ARCHIVE=$1
APP="$ARCHIVE/Products/Applications/CueLens.app"
INFO="$APP/Info.plist"
PRIVACY="$APP/PrivacyInfo.xcprivacy"
ENTITLEMENTS=$(mktemp /private/tmp/cuelens-entitlements.XXXXXX)
cleanup() { rm -f -- "$ENTITLEMENTS"; }
trap cleanup EXIT HUP INT TERM

test -d "$ARCHIVE"
test -d "$APP"
test -f "$INFO"
test -f "$PRIVACY"
codesign --verify --deep --strict "$APP"
codesign -d --entitlements :- "$APP" >"$ENTITLEMENTS" 2>/dev/null
plutil -lint "$ENTITLEMENTS" >/dev/null

test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$INFO")" = 'de.eachandevery.cuelens'
test "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyTracking' "$PRIVACY")" = 'false'

for entitlement in \
  get-task-allow \
  com.apple.developer.icloud-container-identifiers \
  com.apple.developer.ubiquity-container-identifiers \
  com.apple.security.application-groups \
  com.apple.developer.healthkit \
  com.apple.developer.networking.networkextension \
  aps-environment; do
  if /usr/libexec/PlistBuddy -c "Print :$entitlement" "$ENTITLEMENTS" >/dev/null 2>&1; then
    if [ "$entitlement" = 'get-task-allow' ] && \
       [ "$(/usr/libexec/PlistBuddy -c 'Print :get-task-allow' "$ENTITLEMENTS")" = 'false' ]; then
      continue
    fi
    echo "Unzulässiges Release-Entitlement: $entitlement" >&2
    exit 1
  fi
done

if grep -R -a -q -E 'debug\.invalid|staging\.invalid|192\.168\.1\.243|--ui-test-|Synthetische Information' "$APP"; then
  echo 'Signiertes Archiv enthält Debug-, Staging- oder UI-Testdaten.' >&2
  exit 1
fi

echo 'Signiertes CueLens-Release-Archiv erfolgreich geprüft.'
