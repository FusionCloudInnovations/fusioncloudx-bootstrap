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

for phase in "${PHASES[@]}"; do
    PHASE_PATH="phases/$phase/run.sh"
    echo "[BOOTSTRAP] Executing phase: $phase"

    if [[ -f "$PHASE_PATH" ]]; then
        if bash "$PHASE_PATH"; then
            echo "[BOOTSTRAP] Phase $phase completed successfully."
            mark_phase_as_run "$phase"
        else
            echo "[BOOTSTRAP] Phase $phase failed, aborting bootstrap."
            exit 1
        fi
    else
        echo "[BOOTSTRAP] Phase script $PHASE_PATH not found, skipping."
    fi
done

# Send notification at the end
send_notification "✅ FusionCloudX Bootstrapping complete"
