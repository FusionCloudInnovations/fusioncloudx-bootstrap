#!/usr/bin/env bash
set -euo pipefail

# Source shared logging
source "$(dirname "$0")/../../modules/logging.sh"

log_phase "[PRECHECK]" "start" "🧪" "Running pre-checks for FusionCloudX bootstrap..."

log_info "[PRECHECK] Detected OS: $(uname -s) | $(lsb_release -d 2>/dev/null || echo 'No lsb_release')"

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
# Clock Skew Check
# ─────────────────────────────────────────────────────────────
ntp_server="time.google.com"
ntp_diff=$(ntpdate -q "$ntp_server" 2>/dev/null | awk '/offset/ {print $10}' || echo 0)

if [[ $(echo "$ntp_diff > 2" | bc) -eq 1 ]]; then
    log_warn "[PRECHECK] Clock skew detected. Offset: ${ntp_diff}s vs $ntp_server"
else
    log_success "[PRECHECK] Clock skew within acceptable range: ${ntp_diff}s"
fi

# ─────────────────────────────────────────────────────────────
# Check if running inside WSL
# ─────────────────────────────────────────────────────────────
if grep -qEi "microsoft.*WSL2" /proc/version; then
    log_success "[PRECHECK] Running under WSL2"
elif grep -qEi "microsoft" /proc/version; then
    log_warn "[PRECHECK] Detected WSL1. Compatibility may be limited."
else
    log_info "[PRECHECK] Not running under WSL. Assuming native Linux or container."
fi

# ─────────────────────────────────────────────────────────────
# Check for required commands
# ─────────────────────────────────────────────────────────────
REQUIRED_COMMANDS=(apt apt-get bash curl git openssl sed unzip wget)

missing=()

for cmd in "${REQUIRED_COMMANDS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        log_warn "[PRECHECK] Required command '$cmd' is not installed."
        missing+=("$cmd")
    else
        log_success "[PRECHECK] Found required command: $cmd"
    fi
done

if (( ${#missing[@]} > 0 )); then
    log_warn "[PRECHECK] Missing commands: ${missing[*]}"
fi

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

# Simulate success
log_phase "00-precheck" "complete" "🧪" "Pre-checks complete"
exit 0
