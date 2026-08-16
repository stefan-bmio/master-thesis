#!/bin/sh
set -eu

KIND=${1:-}
if [ "$KIND" != "iphone" ] && [ "$KIND" != "ipad" ]; then
  echo "Verwendung: $0 iphone|ipad" >&2
  exit 64
fi

python3 - "$KIND" <<'PY'
import json
import re
import subprocess
import sys

kind = sys.argv[1]
payload = subprocess.run(
    ["xcrun", "simctl", "list", "devices", "available", "--json"],
    check=True,
    capture_output=True,
    text=True,
)
devices = json.loads(payload.stdout)["devices"]

def version(runtime: str) -> tuple[int, ...]:
    match = re.search(r"iOS-(\d+(?:-\d+)*)$", runtime)
    return tuple(int(part) for part in match.group(1).split("-")) if match else ()

prefix = "iPhone" if kind == "iphone" else "iPad"
candidates = []
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    for entry in entries:
        if entry.get("isAvailable", True) and entry["name"].startswith(prefix):
            candidates.append((version(runtime), entry["name"], entry["udid"]))

if not candidates:
    raise SystemExit(f"Kein verfügbarer {prefix}-Simulator gefunden.")

candidates.sort(reverse=True)
print(candidates[0][2])
PY
