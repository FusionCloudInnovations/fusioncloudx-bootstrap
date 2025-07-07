#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh

log_phase "[TOOLS]" "start" "🔧" "Beginning essential tools installation..."

# Refresh package index
sudo apt-get update -y

# Base packages
ESSENTIAL_PKGS=(
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
    echo "[INFO] Installing yq from GitHub..."
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

log_success "[TOOLS] All essential tools are ready."
log_phase "02-tools" "complete" "🔧" "Essential tools installation completed."