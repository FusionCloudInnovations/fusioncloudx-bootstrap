#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh

log_phase "[NETWORK CHECKS] Starting network checks" "start"

# Check if the internet is reachable
if wget -q --spider https://www.google.com/generate_204; then
    log_success "[NETWORK CHECKS] Internet access + DNS resolution confirmed (Google)"
else
    log_error "[NETWORK CHECKS] Internet check failed. Please ensure you have a working internet connection."
    exit 1
fi


# Internal network resource check
if ping -c 1 192.168.10.1 > /dev/null 2>&1; then
    log_success "[NETWORK CHECKS] Gateway 192.168.10.1 is reachable"
else
    log_error "[NETWORK CHECKS] Gateway not reachable. Please check your network connection."
    exit 1
fi

log_phase "[NETWORK CHECKS] All network checks passed successfully" "complete"