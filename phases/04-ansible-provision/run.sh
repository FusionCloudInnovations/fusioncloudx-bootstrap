#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh

log_phase "[ANSIBLE] Starting Ansible provisioning" "start"

# Check if Ansible is installed
if ! command -v ansible &>/dev/null; then
    log_error "[ANSIBLE] Ansible is not installed. Please install Ansible before running this script."
    exit 1
fi

# Check if Ansible Galaxy is installed
if ! command -v ansible-galaxy &>/dev/null; then
    log_error "[ANSIBLE] ansible-galaxy command not found. Please ensure Ansible is installed correctly."
    exit 1
fi

# Check if Ansible inventory file exists
if [[ ! -f "ansible/inventory.ini" ]]; then
    log_error "[ANSIBLE] Ansible inventory file 'ansible/inventory.ini' not found. Please ensure it exists in the correct directory."
    exit 1
fi

# Check if Ansible configuration file exists
if [[ ! -f "ansible/ansible.cfg" ]]; then
    log_error "[ANSIBLE] Ansible configuration file 'ansible/ansible.cfg' not found. Please ensure it exists in the correct directory."
    exit 1
fi

# Check if Ansible roles directory exists
if [[ ! -d "ansible/roles" ]]; then
    log_error "[ANSIBLE] Ansible roles directory 'ansible/roles' not found. Please ensure it exists in the correct directory."
    exit 1
fi

# Check if Ansible collections directory exists
if [[ ! -d "ansible/collections" ]]; then
    log_error "[ANSIBLE] Ansible collections directory 'ansible/collections' not found. Please ensure it exists in the correct directory."
    exit 1
fi 

# Check if Ansible requirements file exists
if [[ ! -f "ansible/requirements.yml" ]]; then
    log_info "[ANSIBLE] No requirements.yml found, skipping role installation."
    exit 0
fi

# Install Ansible roles if requirements file exists
if ansible-galaxy install -r ansible/requirements.yml; then
    log_success "[ANSIBLE] Ansible roles installed successfully."
else
    log_error "[ANSIBLE] Failed to install Ansible roles. Please check the requirements.yml file for errors."
    exit 1
fi

# Check if Ansible playbook exists
if [[ ! -f "ansible/playbook.yml" ]]; then
    log_error "[ANSIBLE] Ansible playbook 'ansible/playbook.yml' not found. Please ensure it exists in the correct directory."
    exit 1
fi

# Run the Ansible playbook
log_info "[ANSIBLE] Running playbook..."
if ansible-playbook -i ansible/inventory.ini ansible/playbook.yml; then
    log_success "[ANSIBLE] Ansible provisioning completed successfully."
else
    log_error "[ANSIBLE] Ansible provisioning failed. Please check the output for errors."
    exit 1
fi

log_phase "[ANSIBLE] Ansible provisioning completed" "complete"