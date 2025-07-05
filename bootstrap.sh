#!/usr/bin/env bash

# ───────────────────────────────────────────────────────────────
# FusionCloudX Ephemeral Bootstrap Script
# This script sets up the local environment, validates components,
# then orchestrates provisioning, config, and teardown.
# ───────────────────────────────────────────────────────────────

BOOTSTRAP_SUCCESS=1

# Load modules
source modules/logging.sh
source modules/init.sh
source modules/state.sh
source modules/notify.sh

log_info "[BOOTSTRAP] Modules loaded, beginning bootstrap sequence..."
PHASES=(
    "00-precheck"
    "01-wsl-init"
    "02-tools"
    "03-network-checks"
    "04-netboot"
    "05-configure-hosts"
    "06-fail-phase"
    "07-exit-phase"
    "08-sleep-phase"
    "09-after-fail"
)

# Parse PHASE_INCLUDE if set (from .env, config/variables.env, or environment)
if [[ -n "${PHASE_INCLUDE:-}" ]]; then
    IFS=',' read -ra INCLUDED <<< "$PHASE_INCLUDE"
    # Trim whitespace from each included phase
    for i in "${!INCLUDED[@]}"; do
        INCLUDED[$i]=$(echo "${INCLUDED[$i]}" | xargs)
    done
fi

for phase in "${PHASES[@]}"; do
    # Check inclusion
    if [[ -n "${PHASE_INCLUDE:-}" && ! " ${INCLUDED[@]} " =~ " $phase " ]]; then
        log_phase "$phase" "skip"
        continue
    fi

    PHASE_PATH="phases/$phase/run.sh"

    if [[ -f "$PHASE_PATH" ]]; then
        if grep -qx "$phase" "$RAN_FILE"; then
            log_phase "$phase" "skip"
            continue
        fi

        log_phase "$phase" "start"
        start_time=$(date +%s)

        if bash "$PHASE_PATH"; then
            end_time=$(date +%s)
            elapsed=$((end_time - start_time))
            mark_phase_as_run "$phase"
            log_phase "$phase" "success" "$elapsed"
        else
            log_phase "$phase" "fail"
            BOOTSTRAP_SUCCESS=0
            exit 1
        fi

        # Stop marker check
        if [[ -f state/stop_bootstrap ]]; then
            log_bootstrap "[BOOTSTRAP] Stop marker detected. Exiting early."
            rm -f state/stop_bootstrap
            BOOTSTRAP_SUCCESS=0
            exit 0
        fi
    else
        log_bootstrap "[BOOTSTRAP] Phase script $PHASE_PATH not found, skipping."
    fi
done

if [[ $BOOTSTRAP_SUCCESS -eq 1 ]]; then
    log_success "[NOTIFY] ✅ FusionCloudX Bootstrapping complete"
    send_notification "✅ FusionCloudX Bootstrapping complete"
else
    log_error "[NOTIFY] ❌ FusionCloudX Bootstrapping did not complete successfully."
fi
