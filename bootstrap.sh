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
    # If PHASE_INCLUDE is set, skip phases not in the list
    if [[ -n "${PHASE_INCLUDE:-}" ]]; then
        if [[ ! " ${INCLUDED[@]} " =~ " $phase " ]]; then
            log_warn "[BOOTSTRAP] Phase $phase not in inclusion list, skipping."
            continue
        fi
    fi

    PHASE_PATH="phases/$phase/run.sh"
    log_info "[BOOTSTRAP] Executing phase: $phase"

    if [[ -f "$PHASE_PATH" ]]; then
        start_time=$(date +%s)
        if grep -qx "$phase" "$RAN_FILE"; then
            log_warn "[BOOTSTRAP] Phase $phase already completed, skipping."
            phase_status="skipped"
        else
            if bash "$PHASE_PATH"; then
                log_success "[BOOTSTRAP] Phase $phase completed successfully."
                mark_phase_as_run "$phase"
                phase_status="completed"
            else
                log_error "[BOOTSTRAP] Phase $phase failed, aborting bootstrap."
                BOOTSTRAP_SUCCESS=0
                exit 1
            fi
        fi
        end_time=$(date +%s)
        elapsed_time=$((end_time - start_time))
        log_info "[BOOTSTRAP] Phase $phase took $elapsed_time seconds. Status: ${phase_status:-completed}"

        if [[ -f state/stop_bootstrap ]]; then
            log_warn "[BOOTSTRAP] Stop marker detected. Exiting bootstrap early."
            rm -f state/stop_bootstrap
            BOOTSTRAP_SUCCESS=0
            exit 0
        fi
    else
        log_warn "[BOOTSTRAP] Phase script $PHASE_PATH not found, skipping."
    fi
done

if [[ $BOOTSTRAP_SUCCESS -eq 1 ]]; then
    send_notification "✅ FusionCloudX Bootstrapping complete"
else
    log_error "[NOTIFY] ❌ FusionCloudX Bootstrapping did not complete successfully."
fi
