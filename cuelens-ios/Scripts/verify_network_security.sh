#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
NETWORK_DIR="$PROJECT_ROOT/CueLens/Infrastructure/Network"

rg -q 'URLSessionConfiguration\.ephemeral' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'httpCookieStorage = nil' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'urlCredentialStorage = nil' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'urlCache = nil' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'waitsForConnectivity = false' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'Accept-Encoding' "$NETWORK_DIR/HTTPClient.swift"
rg -q '"identity"' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'CueLens/\\\(appVersion\)' "$NETWORK_DIR/HTTPClient.swift"
rg -q 'completionHandler\(nil\)' "$NETWORK_DIR/HTTPClient.swift"

if rg -n 'http://|NSAllowsArbitraryLoads|serverTrust|SecTrust|URLCredential' \
  "$NETWORK_DIR" "$PROJECT_ROOT/Config/Release.xcconfig"; then
  echo 'Unsichere Transportkonfiguration im Produktionscode gefunden.' >&2
  exit 1
fi

if rg -n '\b(app_token|identifier|craving|compensation_code|comment|source|body|payload)\b' \
  "$NETWORK_DIR/NetworkLogging.swift"; then
  echo 'Sensible oder fachliche Daten im Netzwerklogger gefunden.' >&2
  exit 1
fi

if rg -n 'User-Agent.*(iOS|iPhone|iPad|OSVersion|device)' "$NETWORK_DIR"; then
  echo 'Plattforminformation im User-Agent gefunden.' >&2
  exit 1
fi

echo 'Netzwerk-Sicherheitsinvarianten erfolgreich geprüft.'
