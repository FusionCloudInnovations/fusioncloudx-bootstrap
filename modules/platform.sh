#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FusionCloudX Platform Abstraction Layer
#
# Provides cross-platform compatibility for macOS, Linux, and WSL environments.
# Source this module to get consistent interfaces across operating systems.
# ------------------------------------------------------------------------------

set -euo pipefail

# Platform detection variables (set by detect_platform)
export PLATFORM_OS=""
export PLATFORM_ARCH=""

# ------------------------------------------------------------------------------
# Core Platform Detection
# ------------------------------------------------------------------------------

detect_platform() {
    case "$(uname -s)" in
        Darwin)
            PLATFORM_OS="darwin"
            ;;
        Linux)
            if grep -qEi "microsoft" /proc/version 2>/dev/null; then
                PLATFORM_OS="wsl"
            else
                PLATFORM_OS="linux"
            fi
            ;;
        *)
            PLATFORM_OS="unknown"
            ;;
    esac

    case "$(uname -m)" in
        arm64|aarch64)
            PLATFORM_ARCH="arm64"
            ;;
        x86_64|amd64)
            PLATFORM_ARCH="amd64"
            ;;
        *)
            PLATFORM_ARCH="unknown"
            ;;
    esac

    export PLATFORM_OS PLATFORM_ARCH
}

# Boolean platform checks
is_macos() {
    [[ "$PLATFORM_OS" == "darwin" ]]
}

is_linux() {
    [[ "$PLATFORM_OS" == "linux" ]]
}

is_wsl() {
    [[ "$PLATFORM_OS" == "wsl" ]]
}

# Human-readable OS description
get_os_info() {
    case "$PLATFORM_OS" in
        darwin)
            sw_vers 2>/dev/null | awk -F':\t' '/ProductName|ProductVersion/ {printf "%s ", $2}' | sed 's/ $//'
            ;;
        wsl)
            local distro
            distro=$(lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "WSL Linux")
            echo "$distro (WSL)"
            ;;
        linux)
            lsb_release -d 2>/dev/null | cut -f2 || cat /etc/os-release 2>/dev/null | grep PRETTY_NAME | cut -d'"' -f2 || echo "Linux"
            ;;
        *)
            echo "Unknown OS"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Package Management
# ------------------------------------------------------------------------------

pkg_manager_name() {
    case "$PLATFORM_OS" in
        darwin)
            echo "brew"
            ;;
        linux|wsl)
            echo "apt"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

pkg_update() {
    case "$PLATFORM_OS" in
        darwin)
            brew update
            ;;
        linux|wsl)
            sudo apt-get update -qq
            ;;
    esac
}

pkg_install() {
    local packages=("$@")
    case "$PLATFORM_OS" in
        darwin)
            brew install "${packages[@]}"
            ;;
        linux|wsl)
            sudo apt-get install -y -qq "${packages[@]}"
            ;;
    esac
}

pkg_installed() {
    local pkg="$1"
    case "$PLATFORM_OS" in
        darwin)
            brew list "$pkg" &>/dev/null
            ;;
        linux|wsl)
            dpkg -s "$pkg" &>/dev/null
            ;;
    esac
}

# Ensure Homebrew is installed (macOS only)
ensure_homebrew() {
    if ! is_macos; then
        return 0
    fi

    if command -v brew &>/dev/null; then
        return 0
    fi

    echo "[PLATFORM] Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add brew to PATH for Apple Silicon
    if [[ -f "/opt/homebrew/bin/brew" ]]; then
        eval "$(/opt/homebrew/bin/brew shellenv)"
    elif [[ -f "/usr/local/bin/brew" ]]; then
        eval "$(/usr/local/bin/brew shellenv)"
    fi
}

# ------------------------------------------------------------------------------
# Clock/NTP Functions
# ------------------------------------------------------------------------------

get_ntp_offset() {
    local ntp_server="${1:-time.google.com}"

    case "$PLATFORM_OS" in
        darwin)
            # macOS uses sntp
            local output
            output=$(sntp "$ntp_server" 2>&1 || true)
            # Extract offset in seconds from sntp output
            # Format: "+0.123456 +/- 0.001234 ..." or similar
            echo "$output" | awk '{for(i=1;i<=NF;i++) if($i ~ /^[+-]?[0-9]+\.[0-9]+$/) {print $i; exit}}' | head -1 || echo "0"
            ;;
        linux|wsl)
            # Linux uses ntpdate
            ntpdate -q "$ntp_server" 2>/dev/null | awk '/offset/ {print $10}' || echo "0"
            ;;
        *)
            echo "0"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Profile/Environment Paths
# ------------------------------------------------------------------------------

get_profile_dir() {
    case "$PLATFORM_OS" in
        darwin)
            echo "$HOME/.config/fusioncloudx"
            ;;
        linux|wsl)
            echo "/etc/profile.d"
            ;;
        *)
            echo "/tmp"
            ;;
    esac
}

get_profile_file() {
    case "$PLATFORM_OS" in
        darwin)
            echo "$HOME/.config/fusioncloudx/env.sh"
            ;;
        linux|wsl)
            echo "/etc/profile.d/fusioncloudx.sh"
            ;;
        *)
            echo "/tmp/fusioncloudx.sh"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Certificate Paths
# ------------------------------------------------------------------------------

# Temp directory for macOS certificate generation (created in script execution directory)
# This avoids putting items in system-owned directories on macOS
MACOS_CERT_TEMP_DIR=""

# Initialize or get the macOS certificate temp directory
get_macos_cert_temp_dir() {
    if [[ -n "$MACOS_CERT_TEMP_DIR" && -d "$MACOS_CERT_TEMP_DIR" ]]; then
        echo "$MACOS_CERT_TEMP_DIR"
        return
    fi

    # Create temp directory in the current working directory
    MACOS_CERT_TEMP_DIR="$(pwd)/.fusioncloudx-certs-$(date +%Y%m%d%H%M%S)"
    mkdir -p "$MACOS_CERT_TEMP_DIR"
    export MACOS_CERT_TEMP_DIR
    echo "$MACOS_CERT_TEMP_DIR"
}

# Clean up macOS certificate temp directory
cleanup_macos_cert_temp_dir() {
    if [[ -n "$MACOS_CERT_TEMP_DIR" && -d "$MACOS_CERT_TEMP_DIR" ]]; then
        rm -rf "$MACOS_CERT_TEMP_DIR"
        MACOS_CERT_TEMP_DIR=""
    fi
}

get_cert_base_path() {
    case "$PLATFORM_OS" in
        darwin)
            # Use temp directory in script execution location for macOS
            # Certs will be imported to Keychain, so we don't need persistent storage
            get_macos_cert_temp_dir
            ;;
        linux|wsl)
            echo "/etc/fusioncloudx/certs"
            ;;
        *)
            echo "/tmp/fusioncloudx/certs"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# yq Download URL (architecture-aware)
# ------------------------------------------------------------------------------

get_yq_download_url() {
    local version="${1:-v4.2.0}"
    local platform_suffix

    case "$PLATFORM_OS" in
        darwin)
            platform_suffix="darwin_${PLATFORM_ARCH}"
            ;;
        linux|wsl)
            platform_suffix="linux_${PLATFORM_ARCH}"
            ;;
        *)
            platform_suffix="linux_amd64"
            ;;
    esac

    echo "https://github.com/mikefarah/yq/releases/download/${version}/yq_${platform_suffix}.tar.gz"
}

# ------------------------------------------------------------------------------
# Date Arithmetic (cross-platform)
# ------------------------------------------------------------------------------

date_add_days() {
    local days="$1"
    local format="${2:-%Y-%m-%d}"

    case "$PLATFORM_OS" in
        darwin)
            # BSD date syntax
            date -v+${days}d +"$format"
            ;;
        linux|wsl)
            # GNU date syntax
            date -d "+${days} days" +"$format"
            ;;
        *)
            date +"$format"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Network Functions
# ------------------------------------------------------------------------------

get_default_gateway() {
    case "$PLATFORM_OS" in
        darwin)
            route -n get default 2>/dev/null | awk '/gateway:/ {print $2}'
            ;;
        linux|wsl)
            ip route 2>/dev/null | awk '/default/ {print $3; exit}'
            ;;
        *)
            echo ""
            ;;
    esac
}

# ------------------------------------------------------------------------------
# macOS Keychain Integration
# ------------------------------------------------------------------------------

import_ca_to_keychain() {
    local cert_path="$1"
    local cert_type="${2:-trustRoot}"  # trustRoot for Root CA, trustAsRoot for Intermediate

    if ! is_macos; then
        return 0  # Skip on non-macOS
    fi

    if [[ ! -f "$cert_path" ]]; then
        echo "[PLATFORM] Certificate file not found: $cert_path" >&2
        return 1
    fi

    echo "[PLATFORM] Importing certificate to macOS System Keychain: $cert_path"
    sudo security add-trusted-cert -d -r "$cert_type" \
        -k /Library/Keychains/System.keychain "$cert_path"
    echo "[PLATFORM] Certificate trusted in macOS Keychain"
}

# ------------------------------------------------------------------------------
# Platform-specific required commands
# ------------------------------------------------------------------------------

get_required_commands() {
    local common_commands=(bash curl git openssl sed unzip wget)

    case "$PLATFORM_OS" in
        darwin)
            echo "${common_commands[*]} brew"
            ;;
        linux|wsl)
            echo "${common_commands[*]} apt apt-get"
            ;;
        *)
            echo "${common_commands[*]}"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Package name mapping (Linux apt -> macOS brew)
# ------------------------------------------------------------------------------

map_package_name() {
    local pkg="$1"

    if ! is_macos; then
        echo "$pkg"
        return
    fi

    # Map Linux package names to macOS equivalents
    case "$pkg" in
        dnsutils)
            echo "bind"
            ;;
        software-properties-common)
            echo ""  # Not needed on macOS
            ;;
        gnupg)
            echo "gnupg"  # Usually pre-installed, but available via brew
            ;;
        ca-certificates)
            echo ""  # macOS uses Keychain
            ;;
        python3-yaml)
            echo "pyyaml"  # pip install pyyaml
            ;;
        *)
            echo "$pkg"
            ;;
    esac
}

# ------------------------------------------------------------------------------
# Auto-detect platform on source
# ------------------------------------------------------------------------------

detect_platform
