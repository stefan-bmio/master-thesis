#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
NOTIFICATION_DIR="$PROJECT_ROOT/CueLens/Infrastructure/Notifications"

rg -q 'de\.eachandevery\.cuelens\.infofeed\.refresh' \
  "$NOTIFICATION_DIR/BackgroundRefreshCoordinator.swift"
rg -q 'de\.eachandevery\.cuelens\.study-reminder\.' \
  "$NOTIFICATION_DIR/NotificationCoordinator.swift"
rg -q 'requestAuthorization\(options: \[\.alert\]\)' \
  "$NOTIFICATION_DIR/NotificationCoordinator.swift"
rg -q 'hiddenPreviewsBodyPlaceholder' \
  "$NOTIFICATION_DIR/NotificationCoordinator.swift"
rg -q 'preferredColorScheme\(\.light\)' "$PROJECT_ROOT/CueLens/App/ContentView.swift"

if rg -n 'registerForRemoteNotifications|aps-environment|remote-notification|content\.(sound|badge|userInfo|interruptionLevel)' \
  "$PROJECT_ROOT/CueLens" "$PROJECT_ROOT/Config" "$PROJECT_ROOT/CueLens.xcodeproj/project.pbxproj"; then
  echo 'Unzulässige Push-, Sound-, Badge- oder Payload-Konfiguration gefunden.' >&2
  exit 1
fi

echo 'Notification- und Darstellungsinvarianten erfolgreich geprüft.'
