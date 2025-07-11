#!/usr/bin/env bash
set -euo pipefail

# Trap errors and notify completion
# trap 'PHASE_STATUS=$?; ./phases/99-notify-done/run.sh failure; exit $PHASE_STATUS' ERR

# Load logging and other modules
source modules/logging.sh
source modules/state.sh
# Add other modules here if needed

CLEAN_RUN="${CLEAN_RUN:-false}"  # Default to false if not set
EPHEMERAL_MODE="${EPHEMERAL_MODE:-false}"  # Default to false if not set

if [[ "$CLEAN_RUN" == "true" ]]; then
  log_info "[STATE] Clean run mode enabled. Removing previous phase history..."
  rm -f "$STATE_FILE"
  log_success "[STATE] Previous state cleared for clean run."
fi

BOOTSTRAP_SUCCESS=1
PHASES_DIR="phases"
PHASE_ORDER=(
  "00-precheck"
  "01-wsl-init"
  "02-tools"
  "03-network-checks"
  "04-cert-authority-bootstrap"
  # "05-ssh-key-bootstrap"
  # "06-image-restore"
  # "07-ipxe-netboot"
  # "08-terraform-init"
  # "09-terraform-apply"
  # "10-inventory-generate"
  # "11-ansible-provision"
  # "12-verify-nodes"
  # "13-import-certs-on-clients"
  # "14-app-bootstrap"
  # "15-backup-restore"
  # "99-notify"
)


main() {
  log_phase "Bootstrap" "start" "🧱" "FusionCloudX Bootstrap: Starting Phase..."
  log_success "[INIT] Bootstrap environment ready"

  log_info "[STATE] Initialized runtime state at $STATE_FILE"
  log_info "[BOOTSTRAP] Modules loaded, beginning bootstrap sequence..."
  echo

  for PHASE_NAME in "${PHASE_ORDER[@]}"; do
    if [[ -f "state/stop_bootstrap" ]]; then
      log_warn "[BOOTSTRAP] Stop marker detected. Halting further phase execution."
      break
    fi
    
    if phase_already_run "$PHASE_NAME"; then
      log_info "[BOOTSTRAP] Skipping already completed phase: $PHASE_NAME"
      continue
    fi
    
    PHASE_PATH="$PHASES_DIR/$PHASE_NAME/run.sh"
    log_info "[BOOTSTRAP] Starting phase: $PHASE_NAME"

    if [[ ! -x "$PHASE_PATH" ]]; then
      log_error "[BOOTSTRAP] Phase script not found or not executable: $PHASE_PATH"
      BOOTSTRAP_SUCCESS=0
      break
    fi

    if bash "$PHASE_PATH"; then
      mark_phase_as_run "$PHASE_NAME"
    else
      log_error "[BOOTSTRAP] $PHASE_NAME failed"
      BOOTSTRAP_SUCCESS=0
      break
    fi
  done

  echo


  if [[ $BOOTSTRAP_SUCCESS -eq 1 ]]; then
    log_success "[FINAL] ✅ FusionCloudX Bootstrapping complete"
    # send_notification "✅ FusionCloudX Bootstrapping complete" "success"
    exit 0
  else
    log_error "[FINAL] ❌ FusionCloudX Bootstrapping did not complete successfully."
    # send_notification "❌ FusionCloudX Bootstrapping failed" "error"
    exit 1
  fi
}

main "$@"
