#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh
source modules/platform.sh

log_phase "[NETWORK CHECKS]" "start" "🌐" "Starting network checks"
log_info "[NETWORK CHECKS] Platform: $PLATFORM_OS"

# ─────────────────────────────────────────────────────────────
# Internet Connectivity Check
# ─────────────────────────────────────────────────────────────
# Use curl (available on all platforms) instead of wget
if curl -sf --max-time 10 https://www.google.com/generate_204 > /dev/null 2>&1; then
    log_success "[NETWORK CHECKS] Internet access confirmed (Google)"
else
    log_error "[NETWORK CHECKS] Internet check failed. Please ensure you have a working internet connection."
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# DNS Resolution Check
# ─────────────────────────────────────────────────────────────
dns_fallback=false

if command -v dig >/dev/null 2>&1; then
    # Check DNS resolution via dig
    if dig +short google.com | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$'; then
        log_success "[NETWORK CHECKS] DNS resolution is working via dig (Google)"
    else
        log_warn "[NETWORK CHECKS] dig failed to resolve google.com — attempting nslookup..."
        dns_fallback=true
    fi
else
    log_warn "[NETWORK CHECKS] dig not found — attempting nslookup..."
    dns_fallback=true
fi

if [[ "$dns_fallback" == true ]]; then
    if command -v nslookup >/dev/null 2>&1 && nslookup google.com >/dev/null 2>&1; then
        log_success "[NETWORK CHECKS] DNS resolution is working via nslookup (Google)"
    else
        log_error "[NETWORK CHECKS] DNS resolution failed using both dig and nslookup."
        case "$PLATFORM_OS" in
            darwin)
                log_info "[NETWORK CHECKS] Check System Preferences > Network > DNS settings"
                ;;
            linux|wsl)
                log_info "[NETWORK CHECKS] Check /etc/resolv.conf for valid nameservers"
                ;;
        esac
        exit 1
    fi
fi

# ─────────────────────────────────────────────────────────────
# GitHub Connectivity Check
# ─────────────────────────────────────────────────────────────
if curl -sf --max-time 10 https://github.com > /dev/null; then
    log_success "[NETWORK CHECKS] GitHub is reachable over HTTPS"
else
    log_error "[NETWORK CHECKS] GitHub is not reachable. Possible firewall or DNS issue."
    exit 1
fi

# ─────────────────────────────────────────────────────────────
# Gateway Connectivity Check (non-fatal)
# ─────────────────────────────────────────────────────────────
# Auto-detect default gateway or use configured value
GATEWAY_IP="${NETWORK_GATEWAY:-}"

if [[ -z "$GATEWAY_IP" ]]; then
    GATEWAY_IP=$(get_default_gateway)
fi

if [[ -n "$GATEWAY_IP" ]]; then
    if ping -c 1 -W 2 "$GATEWAY_IP" > /dev/null 2>&1; then
        log_success "[NETWORK CHECKS] Gateway $GATEWAY_IP is reachable"
    else
        # Non-fatal warning - some networks may not have traditional gateways
        log_warn "[NETWORK CHECKS] Gateway $GATEWAY_IP is not reachable (may be expected on some networks)"
    fi
else
    log_warn "[NETWORK CHECKS] Could not determine default gateway - skipping gateway check"
fi

log_phase "03-network-checks" "complete" "🌐" "All network checks passed successfully"
