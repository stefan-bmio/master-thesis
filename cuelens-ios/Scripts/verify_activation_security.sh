#!/bin/sh
set -eu

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "$0")" && pwd)
PROJECT_ROOT=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
COORDINATOR="$PROJECT_ROOT/CueLens/Infrastructure/Activation/ActivationCoordinator.swift"
RECOVERY="$PROJECT_ROOT/CueLens/Infrastructure/Persistence/ProtectedActivationRecoveryStore.swift"
MODEL="$PROJECT_ROOT/CueLens/App/CueLensAppModel.swift"
VIEW="$PROJECT_ROOT/CueLens/App/ContentView.swift"
SETTINGS="$PROJECT_ROOT/CueLens/Infrastructure/Preferences/AppSettingsStore.swift"

rg -q 'markConfirmationUncertain' "$COORDINATOR"
rg -q 'confirmToken' "$COORDINATOR"
rg -q 'saveToken' "$COORDINATOR"
rg -q 'catch NetworkError\.timedOut' "$COORDINATOR"
rg -q 'activation-confirmation-uncertain-v1' \
  "$PROJECT_ROOT/CueLens/Infrastructure/Persistence/PersistencePaths.swift"
rg -q 'writeProtectedAtomically' "$RECOVERY"
rg -q 'secureExistingResource' "$RECOVERY"
rg -q 'activationRequiresSupport' "$MODEL"
rg -q 'ParticipantIdentifier\.parse' "$MODEL"

confirm_line=$(rg -n 'try await service\.confirmToken' "$COORDINATOR" | cut -d: -f1)
save_line=$(rg -n 'try await tokenStore\.saveToken' "$COORDINATOR" | cut -d: -f1)
test "$save_line" -gt "$confirm_line"

if rg -n '\b(ActivationService|KeychainAppTokenStore|ProtectedActivationRecoveryStore)\b' "$VIEW"; then
  echo 'Direkter Infrastrukturzugriff aus der Aktivierungsview gefunden.' >&2
  exit 1
fi

if rg -ni 'email|e-mail|prolific|participant|identifier|app.token' "$SETTINGS"; then
  echo 'Teilnehmendenkennung oder Token im UserDefaults-Store gefunden.' >&2
  exit 1
fi

if rg -n '\b(print|debugPrint|dump|Logger|os_log)\b' \
  "$PROJECT_ROOT/CueLens/Infrastructure/Activation" "$RECOVERY"; then
  echo 'Unzulässiges Aktivierungslogging gefunden.' >&2
  exit 1
fi

echo 'Aktivierungs-Sicherheitsinvarianten erfolgreich geprüft.'
