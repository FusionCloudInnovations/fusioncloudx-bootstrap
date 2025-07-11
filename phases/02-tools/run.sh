#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh
source modules/notify.sh
source modules/state.sh
source modules/1password.sh
source modules/bootstrap_env.sh

log_phase "[TOOLS]" "start" "🔧" "Beginning essential tools installation..."

# Refresh package index
sudo apt-get update -y

# Base packages
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

# Optional tools
if ! command -v yq >/dev/null 2>&1; then
    log_info "[INFO] Installing yq from GitHub..."
    sudo curl -Lo /usr/local/bin/yq https://github.com/mikefarah/yq/releases/latest/download/yq_linux_amd64
    sudo chmod +x /usr/local/bin/yq
else
    log_info "[TOOLS] yq already installed."
fi

# Terraform CLI
if ! command -v terraform &>/dev/null; then
  log_info "[TOOLS] Installing Terraform..."
  curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /etc/apt/trusted.gpg.d/hashicorp.gpg
  echo "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main" | sudo tee /etc/apt/sources.list.d/hashicorp.list
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

# Ensure OP_SERVICE_ACCOUNT_TOKEN is set
if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    log_error "[TOOLS][1Password] OP_SERVICE_ACCOUNT_TOKEN is not set. Cannot authenticate service account."
    exit 1
fi

# 1Password CLI
if ! command -v op &>/dev/null; then
    log_info "[TOOLS] Installing 1Password CLI..."
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/keyrings/1password-archive-keyring.gpg && \
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/1password-archive-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" | \
    sudo tee /etc/apt/sources.list.d/1password.list && \
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/ && \
    curl -sS https://downloads.1password.com/linux/debian/debsig/1password.pol | \
    sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol && \
    sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22 && \
    curl -sS https://downloads.1password.com/linux/keys/1password.asc | \
    sudo gpg --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg && \
    sudo apt update && sudo apt install 1password-cli
else
    log_info "[TOOLS] 1Password CLI already installed."
fi

# Force op into service account mode by clearing any old session state
rm -rf ~/.op
unset OP_ACCOUNT # sometimes exists and interferes

if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
    log_error "[1Password] OP_SERVICE_ACCOUNT_TOKEN not found in environment"
    exit 1
fi

# Test 1Password connection
check_op_vault_access "Services"

log_success "[TOOLS] All essential tools are ready."
log_phase "02-tools" "complete" "🔧" "Essential tools installation completed."