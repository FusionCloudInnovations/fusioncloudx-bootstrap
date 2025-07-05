#!/usr/bin/env bash

# Initialize logs
mkdir -p logs
LOG_FILE="logs/bootstrap-$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

log_bootstrap() {
    local message="$1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')][INFO] $message" | tee -a "$LOG_FILE"
}

# Print startup banner
log_bootstrap "╭───────────────────────────────────────────────╮"
log_bootstrap "│  🧱 FusionCloudX Bootstrap: Getting Started... │"
log_bootstrap "╰───────────────────────────────────────────────╯"
echo
