#!/usr/bin/env bash
set -euo pipefail

# Load logging and other modules
source modules/logging.sh
source modules/state.sh
# Add other modules here if needed

BOOTSTRAP_SUCCESS=1
PHASES_DIR="phases"
PHASE_ORDER=(
  "00-precheck"
  "01-wsl-init"
  "02-tools"
  "03-network-checks"
  "04-netboot"
  "05-configure-hosts"
  # "06-fail-phase" # Simulated fail phase for testing
)

log_phase() {
  log_info "╭───────────────────────────────────────────────╮"
  log_info "│  🧱 FusionCloudX Bootstrap: Starting Phase... │"
  log_info "╰───────────────────────────────────────────────╯"
}

main() {
  log_phase
  log_success "[INIT] Bootstrap environment ready"

  log_info "[STATE] Initialized runtime state at $STATE_FILE"
  log_info "[BOOTSTRAP] Modules loaded, beginning bootstrap sequence..."
  echo

  for PHASE_NAME in "${PHASE_ORDER[@]}"; do
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
    # send_notification "✅ FusionCloudX Bootstrapping complete"  # Optional
    exit 0
  else
    log_error "[FINAL] ❌ FusionCloudX Bootstrapping did not complete successfully."
    # send_notification "❌ FusionCloudX Bootstrapping failed"  # Optional
    exit 1
  fi
}

main "$@"
