#!/usr/bin/env bash

# ───────────────────────────────────────────────────────────────
# FusionCloudX Ephemeral Bootstrap Script
# This script sets up the local environment, validates components,
# then orchestrates provisioning, config, and teardown.
# ───────────────────────────────────────────────────────────────
╰─ PHASE_INCLUDE="06-fail-phase,09-after-fail" bash bootstrap.sh                                                                                                                               ─╯ 
[INIT] Bootstrap environment ready
╭───────────────────────────────────────────────╮
│  🧱 FusionCloudX Bootstrap: Getting Started... │
╰───────────────────────────────────────────────╯

[STATE] Initialized runtime state at state/ran_phases.txt
[BOOTSTRAP] Modules loaded, beginning bootstrap sequence...
[BOOTSTRAP] Phase 00-precheck not in inclusion list, skipping.
[BOOTSTRAP] Phase 01-wsl-init not in inclusion list, skipping.
[BOOTSTRAP] Phase 02-tools not in inclusion list, skipping.
[BOOTSTRAP] Phase 03-network-checks not in inclusion list, skipping.
[BOOTSTRAP] Phase 04-netboot not in inclusion list, skipping.
[BOOTSTRAP] Phase 05-configure-hosts not in inclusion list, skipping.
[BOOTSTRAP] Executing phase: 06-fail-phase
[BOOTSTRAP] Phase 06-fail-phase failed, aborting bootstrap.
[EXIT] Script execution completed.
BOOTSTRAP_SUCCESS=1

# Load modules
source modules/init.sh
source modules/logging.sh
source modules/state.sh
source modules/notify.sh

echo "[BOOTSTRAP] Modules loaded, beginning bootstrap sequence..."
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
            echo "[BOOTSTRAP] Phase $phase not in inclusion list, skipping."
            continue
        fi
    fi
    PHASE_PATH="phases/$phase/run.sh"
    echo "[BOOTSTRAP] Executing phase: $phase"

    if [[ -f "$PHASE_PATH" ]]; then
        start_time=$(date +%s)
        if grep -qx "$phase" "$RAN_FILE"; then
            echo "[BOOTSTRAP] Phase $phase already completed, skipping."
            phase_status="skipped"
        else
            if bash "$PHASE_PATH"; then
                echo "[BOOTSTRAP] Phase $phase completed successfully."
                mark_phase_as_run "$phase"
                phase_status="completed"
            else
                echo "[BOOTSTRAP] Phase $phase failed, aborting bootstrap."
                BOOTSTRAP_SUCCESS=0
                exit 1
            fi
        fi
        end_time=$(date +%s)
        elapsed_time=$((end_time - start_time))
        echo "[BOOTSTRAP] Phase $phase took $elapsed_time seconds. Status: ${phase_status:-completed}"
        # Check for stop marker
        if [[ -f state/stop_bootstrap ]]; then
            echo "[BOOTSTRAP] Stop marker detected. Exiting bootstrap early."
            rm -f state/stop_bootstrap
            BOOTSTRAP_SUCCESS=0
            exit 0
        fi
    else
        echo "[BOOTSTRAP] Phase script $PHASE_PATH not found, skipping."
    fi
done

# Send notification at the end only if all phases succeeded
if [[ $BOOTSTRAP_SUCCESS -eq 1 ]]; then
    send_notification "✅ FusionCloudX Bootstrapping complete"
else
    echo "[NOTIFY] ❌ FusionCloudX Bootstrapping did not complete successfully."
fi
