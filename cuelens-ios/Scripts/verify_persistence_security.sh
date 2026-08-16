#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
KEYCHAIN_DIR="$PROJECT_ROOT/CueLens/Infrastructure/Keychain"
PERSISTENCE_DIR="$PROJECT_ROOT/CueLens/Infrastructure/Persistence"
PRIVACY_MANIFEST="$PROJECT_ROOT/CueLens/Resources/PrivacyInfo.xcprivacy"

rg -q 'de\.eachandevery\.cuelens' "$KEYCHAIN_DIR/KeychainClient.swift"
rg -q 'app-token-v1' "$KEYCHAIN_DIR/KeychainClient.swift"
rg -q 'kSecAttrAccessibleWhenUnlockedThisDeviceOnly' "$KEYCHAIN_DIR/KeychainClient.swift"
rg -q 'kSecAttrSynchronizable' "$KEYCHAIN_DIR/KeychainClient.swift"
rg -q '\.completeFileProtection' "$PERSISTENCE_DIR/ProtectedFileClient.swift"
rg -q 'FileProtectionType\.complete' "$PERSISTENCE_DIR/ProtectedFileClient.swift"
rg -q 'isExcludedFromBackup' "$PERSISTENCE_DIR/ProtectedFileClient.swift"
test "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPIType' "$PRIVACY_MANIFEST")" = \
  'NSPrivacyAccessedAPICategoryFileTimestamp'
test "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:0:NSPrivacyAccessedAPITypeReasons:0' "$PRIVACY_MANIFEST")" = \
  'C617.1'
test "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPIType' "$PRIVACY_MANIFEST")" = \
  'NSPrivacyAccessedAPICategoryUserDefaults'
test "$(/usr/libexec/PlistBuddy -c 'Print :NSPrivacyAccessedAPITypes:1:NSPrivacyAccessedAPITypeReasons:0' "$PRIVACY_MANIFEST")" = \
  'CA92.1'

forbidden=$(rg -n '\b(UserDefaults|NSUbiquitous|CloudKit|CKContainer|Logger|os_log|print)\b' \
  "$KEYCHAIN_DIR" "$PERSISTENCE_DIR" || true)
if [ -n "$forbidden" ]; then
  echo 'Unzulässige Persistenz-, Cloud- oder Logging-Nutzung gefunden:' >&2
  echo "$forbidden" >&2
  exit 1
fi

echo 'Persistenz-Sicherheitsinvarianten erfolgreich geprüft.'
