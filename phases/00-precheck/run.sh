#!/usr/bin/env bash
set -euo pipefail

# Source shared logging
source "$(dirname "$0")/../../modules/logging.sh"

log_phase "[PRECHECK] Running pre-checks for FusionCloudX bootstrap..." "start"

# ─────────────────────────────────────────────────────────────
# Shell Validation (allow Bash or Zsh)
# ─────────────────────────────────────────────────────────────
current_shell="$(ps -p $$ -o comm= || echo unknown)"

if [[ "$current_shell" == "bash" || "$current_shell" == "zsh" ]]; then
    log_success "[PRECHECK] Running under supported shell: $current_shell"
else
    log_error "[PRECHECK] Unsupported shell: $current_shell. Please use bash or zsh."
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Check if running inside WSL
# ─────────────────────────────────────────────────────────────
if grep -qi microsoft /proc/version; then
    log_success "[PRECHECK] Running inside WSL"
else
    log_error "[PRECHECK] Not running inside WSL. Bootstrap requires WSL."
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Check for required commands
# ─────────────────────────────────────────────────────────────
REQUIRED_COMMANDS=(apt apt-get bash curl git openssl sed unzip wget)
for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        log_warn "[PRECHECK] Required command '$cmd' is not installed."
    else
        log_success "[PRECHECK] Found required command: $cmd"
    fi
done

# ─────────────────────────────────────────────────────────────
# Network connectivity check
# ─────────────────────────────────────────────────────────────
if ping -c 1 8.8.8.8 >/dev/null 2>&1; then
    log_success "[PRECHECK] Network connectivity is available."
else
    log_error "[PRECHECK] No network connectivity. Please check your internet connection."
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Check user permissions
# ─────────────────────────────────────────────────────────────
if [[ "$(id -u)" -ne 0 ]]; then
    log_warn "[PRECHECK] Running as non-root user. Some operations may require elevated permissions."
else
    log_success "[PRECHECK] Running with root permissions."
fi

# ─────────────────────────────────────────────────────────────
# Clock Skew Check
# ─────────────────────────────────────────────────────────────
if ! date -u >/dev/null 2>&1; then
    log_warn "[PRECHECK] Unable to verify system clock. This may affect SSL."
fi

# Simulate success
log_phase "00-precheck" complete
exit 0
