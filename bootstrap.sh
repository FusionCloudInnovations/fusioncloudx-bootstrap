#!/usr/bin/env bash

# ───────────────────────────────────────────────────────────────
# FusionCloudX Ephemeral Bootstrap Script
# This script sets up the local environment, validates components,
# then orchestrates provisioning, config, and teardown.
# ───────────────────────────────────────────────────────────────

source modules/init.sh
source modules/logging.sh
source modules/state.sh

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
    echo "[BOOTSTRAP] Running Phase: $phase"
    bash "phases/$phase/run.sh" || { echo "[ERROR] Phase $phase failed"; exit 1; }
done

source modules/notify.sh
send_notification "Bootstrapping complete"