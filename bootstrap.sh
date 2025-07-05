#!/usr/bin/env bash

# ───────────────────────────────────────────────────────────────
# FusionCloudX Ephemeral Bootstrap Script
# This script sets up the local environment, validates components,
# then orchestrates provisioning, config, and teardown.
# ───────────────────────────────────────────────────────────────
trap 'echo "[FATAL] An unexpected error occurred. Exiting." >&2; exit 1' ERR

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
                exit 1
            fi
        fi
        end_time=$(date +%s)
        elapsed_time=$((end_time - start_time))
        echo "[BOOTSTRAP] Phase $phase took $elapsed_time seconds. Status: ${phase_status:-completed}"
    else
        echo "[BOOTSTRAP] Phase script $PHASE_PATH not found, skipping."
    fi
done

# Send notification at the end
send_notification "✅ FusionCloudX Bootstrapping complete"
