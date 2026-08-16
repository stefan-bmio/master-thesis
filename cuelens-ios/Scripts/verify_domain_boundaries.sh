#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DOMAIN_DIR="$PROJECT_ROOT/CueLens/Domain"

unexpected_imports=$(rg -n '^import ' "$DOMAIN_DIR" | grep -v ':import Foundation$' || true)
if [ -n "$unexpected_imports" ]; then
  echo 'Unzulässige Imports im Domain-Modul:' >&2
  echo "$unexpected_imports" >&2
  exit 1
fi

forbidden_symbols=$(rg -n '\b(URLSession|URLRequest|FileManager|UserDefaults|SecItem|UNUserNotificationCenter|BGTaskScheduler|OSLog)\b' "$DOMAIN_DIR" || true)
if [ -n "$forbidden_symbols" ]; then
  echo 'Unzulässige Infrastrukturzugriffe im Domain-Modul:' >&2
  echo "$forbidden_symbols" >&2
  exit 1
fi

domain_sources=$(find "$DOMAIN_DIR" -type f -name '*.swift' -print | sort)
if [ -z "$domain_sources" ]; then
  echo 'Keine Swift-Quellen im Domain-Modul gefunden.' >&2
  exit 1
fi

# Die Pfade enthalten projektbedingt keine Leerzeichen. Eine absichtliche Wortaufteilung
# übergibt jede Quelldatei als separates Compilerargument.
# shellcheck disable=SC2086
xcrun swiftc \
  -swift-version 6 \
  -strict-concurrency=complete \
  -warnings-as-errors \
  -typecheck \
  $domain_sources

echo 'Domain-Grenzen und eigenständige Typprüfung erfolgreich.'
