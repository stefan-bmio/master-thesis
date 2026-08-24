#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_ROOT"

VIEW='CueLens/App/ProductiveStudyView.swift'
SESSION='CueLens/Domain/Study/ProductiveStudySession.swift'
COORDINATOR='CueLens/Infrastructure/Study/ProductiveStudyCoordinator.swift'
REPOSITORY='CueLens/Infrastructure/Study/StudyContentRepository.swift'
STATE='CueLens/Domain/Study/StudyState.swift'

for file in "$VIEW" "$SESSION" "$COORDINATOR" "$REPOSITORY" "$STATE"; do
  test -f "$file"
done

python3 Tools/verify_study_resources.py
test "$(find Resources/Study/Assets -type f -name '*.png' | wc -l | tr -d ' ')" = '150'

if rg -n '\b(URLSession|URLRequest|FileManager|UserDefaults|SecItem|Keychain)\b' "$VIEW" "$SESSION"; then
  echo 'Produktive View oder In-Memory-Session greift direkt auf Infrastruktur zu.' >&2
  exit 1
fi

if rg -n 'selected(Matching|Label|Choice)|trialChoice|choiceHistory' "$STATE" "$COORDINATOR"; then
  echo 'Eine Trialauswahl würde entgegen der Spezifikation persistiert.' >&2
  exit 1
fi

rg -F -q 'static let matchingWaitSeconds = 4' "$SESSION"
rg -F -q 'pendingState = try replacing' "$COORDINATOR"
rg -F -q 'try await stateStore.writeState(pendingState)' "$COORDINATOR"
rg -F -q 'situation.value < StudySchedule.totalSituationCount' "$COORDINATOR"
rg -F -q '#if RELEASE' CueLens/App/AppEnvironment.swift
rg -F -q 'DisabledProductiveStudyManager' CueLens/App/AppEnvironment.swift
rg -F -q 'CUELENS_RUN_COOLDOWN_SECONDS = 3' Config/Debug.xcconfig
rg -F -q 'CUELENS_RUN_COOLDOWN_SECONDS = 3' Config/Staging.xcconfig
rg -F -q 'CUELENS_RUN_COOLDOWN_SECONDS = 10800' Config/Release.xcconfig
rg -F -q 'Assets in Resources' CueLens.xcodeproj/project.pbxproj
rg -F -q 'study-content-v1.json in Resources' CueLens.xcodeproj/project.pbxproj
rg -F -q 'study-assets-manifest-v1.json in Resources' CueLens.xcodeproj/project.pbxproj

echo 'Produktive Studien- und Ressourceninvarianten erfolgreich geprüft.'
