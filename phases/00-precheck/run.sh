#!/usr/bin/env bash
set -euo pipefail

# Source shared modules
source "$(dirname "$0")/../../modules/logging.sh"
source "$(dirname "$0")/../../modules/platform.sh"

log_phase "[PRECHECK]" "start" "🧪" "Running pre-checks for FusionCloudX bootstrap..."

log_info "[PRECHECK] Detected OS: $(uname -s) | $(get_os_info)"
log_info "[PRECHECK] Platform: $PLATFORM_OS | Architecture: $PLATFORM_ARCH"

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
# Clock Skew Check (platform-aware)
# ─────────────────────────────────────────────────────────────
ntp_server="time.google.com"
ntp_diff=$(get_ntp_offset "$ntp_server")

# Handle empty or non-numeric offset
if [[ -z "$ntp_diff" || "$ntp_diff" == "0" ]]; then
    log_warn "[PRECHECK] Could not determine clock offset; skipping clock skew check"
elif [[ $(echo "${ntp_diff#-} > 2" | bc 2>/dev/null || echo 0) -eq 1 ]]; then
    log_warn "[PRECHECK] Clock skew detected. Offset: ${ntp_diff}s vs $ntp_server"
else
    log_success "[PRECHECK] Clock skew within acceptable range: ${ntp_diff}s"
fi

# ─────────────────────────────────────────────────────────────
# Platform Detection and Environment Check
# ─────────────────────────────────────────────────────────────
case "$PLATFORM_OS" in
    darwin)
        log_success "[PRECHECK] Running on macOS"
        # Check for Rosetta on Apple Silicon if needed
        if [[ "$PLATFORM_ARCH" == "arm64" ]]; then
            if /usr/bin/pgrep -q oahd 2>/dev/null; then
                log_info "[PRECHECK] Rosetta 2 is available"
            else
                log_info "[PRECHECK] Rosetta 2 not detected (may not be needed)"
            fi
        fi
        ;;
    wsl)
        if grep -qEi "microsoft.*WSL2" /proc/version 2>/dev/null; then
            log_success "[PRECHECK] Running under WSL2"
        else
            log_warn "[PRECHECK] Detected WSL1. Compatibility may be limited."
        fi
        ;;
    linux)
        log_info "[PRECHECK] Running on native Linux"
        ;;
    *)
        log_warn "[PRECHECK] Unknown platform: $PLATFORM_OS"
        ;;
esac

# ─────────────────────────────────────────────────────────────
# Check for required commands (platform-specific)
# ─────────────────────────────────────────────────────────────
COMMON_COMMANDS=(bash curl git openssl sed unzip wget)

case "$PLATFORM_OS" in
    darwin)
        REQUIRED_COMMANDS=("${COMMON_COMMANDS[@]}" brew)
        ;;
    linux|wsl)
        REQUIRED_COMMANDS=("${COMMON_COMMANDS[@]}" apt apt-get)
        ;;
    *)
        REQUIRED_COMMANDS=("${COMMON_COMMANDS[@]}")
        ;;
esac

# Note: 'yq' is handled separately because the distro/apt package is often
# a different implementation (not mikefarah yq v4) which is incompatible
# with the YAML expressions used by this project. We install the official
# mikefarah yq binary below if missing or incompatible.

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
    log_info "[PRECHECK] Attempting to install missing commands: ${missing[*]}"

    case "$PLATFORM_OS" in
        darwin)
            # On macOS, ensure Homebrew first
            if [[ " ${missing[*]} " =~ " brew " ]]; then
                ensure_homebrew
                # Remove brew from missing list
                missing=("${missing[@]/brew}")
            fi
            # Install remaining packages via brew
            if (( ${#missing[@]} > 0 )); then
                brew install "${missing[@]}" 2>/dev/null || true
            fi
            ;;
        linux|wsl)
            sudo apt-get update -qq
            sudo apt-get install -y -qq "${missing[@]}"
            ;;
    esac
    log_success "[PRECHECK] All required commands installed (auto mode)."
fi

# ─────────────────────────────────────────────────────────────
# Ensure mikefarah yq v4 is available
# ─────────────────────────────────────────────────────────────
INSTALL_YQ=false
if command -v yq >/dev/null 2>&1; then
    # Check for mikefarah yq v4 signature in version output
    if yq --version 2>&1 | grep -Eiq 'mikefarah|version 4'; then
        log_success "[PRECHECK] Found compatible yq: $(yq --version 2>&1 | head -n1)"
    else
        log_warn "[PRECHECK] Found yq but it is not the expected mikefarah v4; will install official yq v4"
        INSTALL_YQ=true
    fi
else
    log_warn "[PRECHECK] yq not found; will install official mikefarah yq v4"
    INSTALL_YQ=true
fi

if [[ "${INSTALL_YQ:-false}" == "true" ]]; then
    case "$PLATFORM_OS" in
        darwin)
            # On macOS, prefer Homebrew for yq
            log_info "[PRECHECK] Installing yq via Homebrew..."
            brew install yq
            log_success "[PRECHECK] Installed yq via Homebrew: $(yq --version 2>&1 | head -n1)"
            ;;
        linux|wsl)
            # On Linux/WSL, download binary
            VERSION="v4.2.0"
            YQ_URL=$(get_yq_download_url "$VERSION")
            YQ_TMPDIR="$(mktemp -d)"
            log_info "[PRECHECK] Downloading yq from: $YQ_URL"
            if wget -q -O - "$YQ_URL" | tar -xz -C "$YQ_TMPDIR"; then
                # Find the extracted binary
                YQ_BINARY=$(find "$YQ_TMPDIR" -name 'yq_*' -type f | head -1)
                if [[ -n "$YQ_BINARY" && -f "$YQ_BINARY" ]]; then
                    sudo mv -f "$YQ_BINARY" /usr/local/bin/yq
                    sudo chmod +x /usr/local/bin/yq
                    log_success "[PRECHECK] Installed official yq to /usr/local/bin/yq: $(/usr/local/bin/yq --version 2>&1 | head -n1)"
                else
                    log_error "[PRECHECK] Download succeeded but expected binary not found in archive"
                fi
            else
                log_error "[PRECHECK] Failed to download or extract official yq binary"
            fi
            rm -rf "$YQ_TMPDIR"
            ;;
    esac
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

log_phase "00-precheck" "complete" "🧪" "Pre-checks complete"
exit 0
