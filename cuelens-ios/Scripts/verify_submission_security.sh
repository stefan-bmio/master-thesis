#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
cd "$PROJECT_ROOT"

COORDINATOR='CueLens/Infrastructure/Study/ProductiveStudyCoordinator.swift'
SERVICE='CueLens/Infrastructure/Network/StudySubmissionService.swift'
MODEL='CueLens/App/CueLensAppModel.swift'
VIEW='CueLens/App/ContentView.swift'
STATE='CueLens/Domain/Study/StudyState.swift'

for file in "$COORDINATOR" "$SERVICE" "$MODEL" "$VIEW" "$STATE"; do
  test -f "$file"
done

if rg -n '\b(URLSession|URLRequest|FileManager|UserDefaults|SecItem|Keychain|UIPasteboard)\b' "$VIEW"; then
  echo 'Die Abschluss-View greift direkt auf Infrastruktur zu.' >&2
  exit 1
fi

if rg -n 'platform|situation_index|condition_code|selected|device|os_version|timestamp' \
    "$SERVICE"; then
  echo 'Der Submission-Request enthält ein unzulässiges fachliches Feld.' >&2
  exit 1
fi

rg -F -q 'case appToken = "app_token"' "$SERVICE"
rg -F -q 'case appVersion = "app_version"' "$SERVICE"
rg -F -q 'statusExpectation: .exact(204)' "$SERVICE"
rg -F -q 'pendingState = try replacing' "$COORDINATOR"
rg -F -q 'try await stateStore.writeState(pendingState)' "$COORDINATOR"
rg -F -q 'submission.submitSelfReport(' "$COORDINATOR"
rg -F -q 'completion: .directPendingConfirmation(code: code)' "$COORDINATOR"
rg -F -q 'try await submission.confirmCompensation(code: code)' "$COORDINATOR"
rg -F -q 'completion: .prolificCompleted' "$COORDINATOR"
rg -F -q 'environment.compensationCodeCopier.copy(code)' "$MODEL"
rg -F -q '.localOnly: true' "$COORDINATOR"
rg -F -q '.expirationDate: Date().addingTimeInterval(600)' "$COORDINATOR"

pending_write_line=$(rg -n -F 'try await stateStore.writeState(pendingState)' "$COORDINATOR" \
  | head -1 | cut -d: -f1)
submission_line=$(rg -n -F 'submission.submitSelfReport(' "$COORDINATOR" \
  | head -1 | cut -d: -f1)
code_write_line=$(rg -n -F 'try await stateStore.writeState(confirmationPending)' "$COORDINATOR" \
  | head -1 | cut -d: -f1)
confirmation_line=$(rg -n -F 'try await submission.confirmCompensation(code: code)' "$COORDINATOR" \
  | head -1 | cut -d: -f1)
test "$pending_write_line" -lt "$submission_line"
test "$code_write_line" -lt "$confirmation_line"

echo 'Submission-, Recovery- und Abschlussinvarianten erfolgreich geprüft.'
