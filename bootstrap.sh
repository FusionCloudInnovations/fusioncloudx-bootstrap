#!/usr/bin/env bash
set -euo pipefail

# Trap errors and notify completion
trap 'PHASE_STATUS=$?; ./phases/99-notify-done/run.sh failure; exit $PHASE_STATUS' ERR

# Load logging and other modules
source modules/logging.sh
source modules/state.sh
source modules/platform.sh

# Always run 00-precheck first, before any config/yq logic
PHASES_DIR="phases"
if [[ -x "$PHASES_DIR/00-precheck/run.sh" ]]; then
  bash "$PHASES_DIR/00-precheck/run.sh"
  source modules/bootstrap_env.sh
else
  echo "[BOOTSTRAP] 00-precheck phase script not found or not executable: $PHASES_DIR/00-precheck/run.sh" >&2
  exit 1
fi



# ─────────────────────────────────────────────────────────────
# Platform-specific phase filtering
# ─────────────────────────────────────────────────────────────
# Returns 0 (true) if phase should run on current platform
should_run_phase() {
  local phase="$1"
  case "$phase" in
    01-wsl-init)
      # WSL init only runs on WSL
      [[ "$PLATFORM_OS" == "wsl" ]]
      ;;
    *)
      # All other phases run on all platforms
      return 0
      ;;
  esac
}

# Load phase order from env vars if present, else fallback to default (excluding 00-precheck)
if [[ -n "${PHASES[*]:-}" ]]; then
  # PHASES env var is a space-separated list from YAML
  read -ra PHASE_ORDER <<< "${PHASES}"
  # Remove 00-precheck if present
  PHASE_ORDER=( "${PHASE_ORDER[@]//00-precheck}" )
else
  PHASE_ORDER=(
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
fi

PHASES_DIR="phases"
BOOTSTRAP_SUCCESS=1


main() {
  log_phase "Bootstrap" "start" "🧱" "FusionCloudX Bootstrap: Starting Phase..."
  log_success "[INIT] Bootstrap environment ready"

  log_info "[STATE] Initialized runtime state at $STATE_FILE"
  log_info "[BOOTSTRAP] Modules loaded, beginning bootstrap sequence..."
  echo


  if [[ "${WSL_CLEAN_RUN,,}" == "true" ]]; then
    log_info "[STATE] Clean run mode enabled. Removing previous phase history..."
    rm -f "$STATE_FILE"
    log_success "[STATE] Previous state cleared for clean run."
  fi

  for PHASE_NAME in "${PHASE_ORDER[@]}"; do
    if [[ -f "state/stop_bootstrap" ]]; then
      log_warn "[BOOTSTRAP] Stop marker detected. Halting further phase execution."
      break
    fi
    # Check if phase should run on this platform
    if ! should_run_phase "$PHASE_NAME"; then
      log_info "[BOOTSTRAP] Skipping phase $PHASE_NAME (not applicable for $PLATFORM_OS)"
      mark_phase_as_run "$PHASE_NAME"  # Mark as run so it won't be retried
      continue
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
    log_info "[CLEANUP] Running log rotation for logs directory..."
    bash utils/log_rotate.sh --max-logs=10 --age-limit=30 || log_warn "[CLEANUP] Log rotation failed or skipped."
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
