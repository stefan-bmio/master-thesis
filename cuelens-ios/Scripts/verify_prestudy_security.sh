#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_ROOT"

VIEW='CueLens/App/PreStudyViews.swift'
MODEL='CueLens/App/CueLensAppModel.swift'
DEMO='CueLens/Domain/PreStudy/DemoSession.swift'
FEEDBACK='CueLens/Infrastructure/Feedback/FeedbackCoordinator.swift'
LINKS='CueLens/Infrastructure/Links/ExternalLinkCoordinator.swift'
PROJECT='CueLens.xcodeproj/project.pbxproj'

for file in "$VIEW" "$MODEL" "$DEMO" "$FEEDBACK" "$LINKS"; do
  test -f "$file"
done

if rg -n '\b(URLSession|URLRequest|FileManager|UserDefaults|SecItem|Keychain)\b' "$VIEW" "$DEMO"; then
  echo 'Demo oder Pre-Study-View greift direkt auf Infrastruktur zu.' >&2
  exit 1
fi

if rg -n '\b(app_token|identifier|platform|device|craving)\b' "$FEEDBACK"; then
  echo 'Feedbackkoordination enthält ein unzulässiges fachliches Feld.' >&2
  exit 1
fi

rg -q 'mailto:cuelens@each-and-every\.de' "$LINKS"
rg -F -q 'components.query == nil' "$LINKS"
rg -F -q 'components.fragment == nil' "$LINKS"
rg -F -q 'components.user == nil' "$LINKS"
rg -F -q 'components.scheme?.lowercased() == "https"' "$LINKS"

for asset in cue_000 cue_001 match_a_000 match_b_000; do
  source="Resources/Study/Assets/$asset.png"
  android="../cuelens/app/src/main/res/drawable/$asset.png"
  test -f "$source"
  cmp -s "$source" "$android"
done
rg -q 'Assets in Resources' "$PROJECT"

for key in CUELENS_PRIVACY_URL_DE CUELENS_PRIVACY_URL_EN; do
  rg -q "<key>$key</key>" CueLens/Resources/Info.plist
  rg -q "<key>$key</key>" CueLens/Resources/StagingInfo.plist
done

echo 'Demo-, Feedback- und Link-Sicherheitsinvarianten erfolgreich geprüft.'
