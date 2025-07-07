#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh

log_phase "[NETWORK CHECKS] Starting network checks" "start"
fallback=false

# Check if the internet is reachable
if wget -q --spider https://www.google.com/generate_204; then
    log_success "[NETWORK CHECKS] Internet access confirmed (Google)"
else
    log_error "[NETWORK CHECKS] Internet check failed. Please ensure you have a working internet connection."
    exit 1
fi

if command -v dig >/dev/null 2>&1; then
    # Check DNS resolution
    if dig +short google.com | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_success "[NETWORK CHECKS] DNS resolution is working via dig (Google)"
    else
        log_error "[NETWORK CHECKS] dig failed to resolve google.com — attempting nslookup..."
        fallback=true
    fi
else
    log_warn "[NETWORK CHECKS] dig not found — attempting nslookup..."
    fallback=true
fi

if [[ "${fallback:-false}" == true ]]; then
    if command -v nslookup >/dev/null 2>&1 && nslookup google.com >/dev/null 2>&1; then
        log_success "[NETWORK CHECKS] DNS resolution is working via nslookup (Google)"
    else
        log_error "[NETWORK CHECKS] DNS resolution failed using both dig and ns lookup. Check /etc/resolv.conf for valid nameservers."
        exit 1
    fi
fi

if curl -sf https://github.com > /dev/null; then
    log_success "[NETWORK CHECKS] GitHub is reachable over HTTPS"
else
    log_error "[NETWORK CHECKS] GitHub is not reachable. Possible firewall or DNS issue."
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