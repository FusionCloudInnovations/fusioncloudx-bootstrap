#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh
source modules/platform.sh
source modules/notify.sh
source modules/state.sh
source modules/1password.sh

log_phase "[TOOLS]" "start" "🔧" "Beginning essential tools installation..."
log_info "[TOOLS] Platform: $PLATFORM_OS ($PLATFORM_ARCH)"

# ─────────────────────────────────────────────────────────────
# Package Installation (platform-specific)
# ─────────────────────────────────────────────────────────────

case "$PLATFORM_OS" in
    darwin)
        # ─────────────────────────────────────────────────────
        # macOS: Use Homebrew
        # ─────────────────────────────────────────────────────
        log_info "[TOOLS] Updating Homebrew..."
        brew update

        # macOS essential packages (brew formula names)
        ESSENTIAL_PKGS=(
            curl
            bind        # provides dig/nslookup (like dnsutils)
            git
            unzip
            jq
            gnupg
        )
        # Note: apg not available in brew, will use openssl rand fallback
        # Note: software-properties-common and ca-certificates not needed on macOS

        for pkg in "${ESSENTIAL_PKGS[@]}"; do
            if ! brew list "$pkg" &>/dev/null; then
                log_info "[BREW] Installing $pkg..."
                brew install "$pkg"
            else
                log_info "[BREW] $pkg is already installed."
            fi
        done

        # yq (should already be installed by precheck, but ensure it's there)
        if ! command -v yq >/dev/null 2>&1; then
            log_info "[BREW] Installing yq..."
            brew install yq
        else
            log_info "[TOOLS] yq already installed."
        fi

        # Terraform CLI via HashiCorp tap
        if ! command -v terraform &>/dev/null; then
            log_info "[TOOLS] Installing Terraform via Homebrew..."
            brew tap hashicorp/tap
            brew install hashicorp/tap/terraform
        else
            log_info "[TOOLS] Terraform already installed."
        fi

        # Ansible CLI
        if ! command -v ansible &>/dev/null; then
            log_info "[TOOLS] Installing Ansible via Homebrew..."
            brew install ansible
        else
            log_info "[TOOLS] Ansible already installed."
        fi

        # 1Password CLI (cask)
        if ! command -v op &>/dev/null; then
            log_info "[TOOLS] Installing 1Password CLI via Homebrew..."
            brew install --cask 1password-cli
        else
            log_info "[TOOLS] 1Password CLI already installed."
        fi
        ;;

    linux|wsl)
        # ─────────────────────────────────────────────────────
        # Linux/WSL: Use apt
        # ─────────────────────────────────────────────────────
        log_info "[TOOLS] Updating apt package index..."
        sudo apt-get update -y

        # Linux essential packages
        ESSENTIAL_PKGS=(
            apg
            curl
            dnsutils
            git
            unzip
            jq
            software-properties-common
            gnupg
            ca-certificates
        )

        for pkg in "${ESSENTIAL_PKGS[@]}"; do
            if ! dpkg -s "$pkg" >/dev/null 2>&1; then
                log_info "[APT] Installing $pkg..."
                sudo apt-get install -y "$pkg"
            else
                log_info "[APT] $pkg is already installed."
            fi
        done

        # yq (should already be installed by precheck, but ensure it's there)
        if ! command -v yq >/dev/null 2>&1; then
            log_info "[TOOLS] Installing yq from GitHub..."
            YQ_URL=$(get_yq_download_url "v4.2.0")
            sudo curl -Lo /usr/local/bin/yq "$YQ_URL"
            sudo chmod +x /usr/local/bin/yq
        else
            log_info "[TOOLS] yq already installed."
        fi

        # Terraform CLI via HashiCorp apt repo
        if ! command -v terraform &>/dev/null; then
            log_info "[TOOLS] Installing Terraform..."
            curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/hashicorp.gpg
            echo "deb [arch=$(dpkg --print-architecture)] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
            sudo apt-get update -y
            sudo apt-get install -y terraform
        else
            log_info "[TOOLS] Terraform already installed."
        fi

        # Ansible CLI
        if ! command -v ansible &>/dev/null; then
            log_info "[TOOLS] Installing Ansible..."
            sudo apt-get install -y ansible
        else
            log_info "[TOOLS] Ansible already installed."
        fi

        # 1Password CLI via Debian repo
        if ! command -v op &>/dev/null; then
            log_info "[TOOLS] Installing 1Password CLI..."
            curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
                sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
                sudo tee /etc/apt/sources.list.d/1password.list
            sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
            curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
                sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
            sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
            curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
                sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
            sudo apt update && sudo apt install -y 1password-cli
        else
            log_info "[TOOLS] 1Password CLI already installed."
        fi
        ;;

    *)
        log_error "[TOOLS] Unsupported platform: $PLATFORM_OS"
        exit 1
        ;;
esac

# ─────────────────────────────────────────────────────────────
# 1Password Service Account Validation
# ─────────────────────────────────────────────────────────────

# Ensure OP_SERVICE_ACCOUNT_TOKEN is set
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    log_error "[TOOLS][1Password] OP_SERVICE_ACCOUNT_TOKEN is not set. Cannot authenticate service account."
    exit 1
fi

# Force op into service account mode by clearing any old session state
rm -rf ~/.op 2>/dev/null || true
unset OP_ACCOUNT 2>/dev/null || true  # sometimes exists and interferes

# Test 1Password connection
check_op_vault_access "FusionCloudX"

log_success "[TOOLS] All essential tools are ready."
log_phase "02-tools" "complete" "🔧" "Essential tools installation completed."
