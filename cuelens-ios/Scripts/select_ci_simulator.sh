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

def model_priority(name: str) -> int:
    if kind == "iphone":
        if re.fullmatch(r"iPhone \d+ Pro", name):
            return 3
        if re.fullmatch(r"iPhone \d+", name):
            return 2
        return 1
    # The smallest current iPad gives the strongest adaptive-layout coverage.
    if name.startswith("iPad mini"):
        return 3
    if re.fullmatch(r"iPad Pro 11-inch.*", name):
        return 2
    return 1

candidates = []
for runtime, entries in devices.items():
    if "iOS" not in runtime:
        continue
    for entry in entries:
        if entry.get("isAvailable", True) and entry["name"].startswith(prefix):
            candidates.append(
                (version(runtime), model_priority(entry["name"]), entry["name"], entry["udid"])
            )

if not candidates:
    raise SystemExit(f"Kein verfügbarer {prefix}-Simulator gefunden.")

candidates.sort(reverse=True)
print(candidates[0][3])
PY
