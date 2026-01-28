#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh
source modules/platform.sh

PHASE_NAME="01-wsl-init"

# ─────────────────────────────────────────────────────────────
# WSL-only phase - skip on other platforms (fallback for standalone execution)
# Note: bootstrap.sh orchestrator handles this skip, but this provides
# a fallback when running the phase directly
# ─────────────────────────────────────────────────────────────
if [[ "$PLATFORM_OS" != "wsl" ]]; then
    log_info "[WSL INIT] Skipping: this phase only runs in WSL environment (current: $PLATFORM_OS)"
    exit 0
fi

# ─────────────────────────────────────────────────────────────
# WSL Initialization
# ─────────────────────────────────────────────────────────────
log_phase "[WSL INIT]" "start" "🐧" "Initializing WSL"

if ! sudo -n true 2>/dev/null; then
    log_error "[WSL INIT] sudo is not available without password. Please configure passwordless sudo."
    exit 1
fi

# Create working directories
mkdir -p "$HOME/fusioncloud" "$HOME/bootstrap"
sudo mkdir -p /opt/fusioncloud

log_success "[WSL INIT] Created working directories."

# Sync shared assets from Windows (if applicable)
if [[ -d /mnt/c/bootstrap-assets ]]; then
    cp -r /mnt/c/bootstrap-assets/* ~/bootstrap/
    log_success "[WSL INIT] Copied bootstrap assets from Windows."
else
    log_warn "[WSL INIT] No /mnt/c/bootstrap-assets directory found — skipping Windows asset sync."
fi

log_phase "$PHASE_NAME" "complete" "🐧" "WSL Init complete"
