#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh

log_phase "[WSL INIT]" "start" "🐧" "Initializing WSL"

if ! sudo -n true 2>/dev/null; then
    log_error "sudo is not available without password. Please configure passwordless sudo."
    exit 1
fi

# Create working directories
mkdir -p "$HOME/fusioncloud" "$HOME/bootstrap"
sudo mkdir -p /opt/fusioncloud

log_success "Created working directories."

# Sync shared assets from Windows (if applicable)
if [[ -d /mnt/c/bootstrap-assets ]]; then
    cp -r /mnt/c/bootstrap-assets/* ~/bootstrap/
    log_success "Copied bootstrap assets from Windows."
else
  log_warn "No /mnt/c/bootstrap-assets directory found — skipping Windows asset sync."
fi


# Write initial env config if not exists
ENV_FILE="$HOME/.fusion_env"
if [[ ! -f "$ENV_FILE" ]]; then
    echo "FUSION_STAGE=bootstrap" > "$ENV_FILE"
    echo "OS_CONTEXT=wsl2-ubuntu" >> "$ENV_FILE"
    log_success "Initialized fusion environment config at $ENV_FILE"
fi

source "$ENV_FILE"
