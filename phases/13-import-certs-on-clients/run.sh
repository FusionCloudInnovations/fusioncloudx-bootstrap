#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Phase 13: Bootstrap Certificate Deployment
# Purpose: Deploy certificates to bare metal (Mac Mini + Proxmox hosts)
# Scope: Only devices required for Terraform/Ansible to function
#==============================================================================

PHASE_NAME="13-import-certs-on-clients"
PHASE_DESC="Deploy certificates to bootstrap-critical devices"

source modules/logging.sh
source modules/platform.sh
source modules/1password.sh
source modules/state.sh

log_phase "$PHASE_NAME" "start" "🔐" "$PHASE_DESC"
log_debug "[PHASE 13] Platform: $PLATFORM_OS ($PLATFORM_ARCH)"

# Configuration
VAULT_NAME="FusionCloudX"
DEVICES_CONFIG="config/bootstrap-devices.yaml"

#==============================================================================
# Helper Functions
#==============================================================================

# Deploy CA certificates to macOS workstation
deploy_ca_to_macos_workstation() {
    log_info "[PHASE 13] Deploying CA certificates to Mac Mini workstation..."

    # Create temporary working directory
    local work_dir
    work_dir=$(mktemp -d -t fusioncloudx-ca-XXXXXX)
    trap "rm -rf '$work_dir'" RETURN

    # Get certificate filenames from config
    local root_ca_file
    local int_ca_file
    root_ca_file=$(yq eval '.bootstrap_devices.workstation.certs_needed[0]' "$DEVICES_CONFIG")
    int_ca_file=$(yq eval '.bootstrap_devices.workstation.certs_needed[1]' "$DEVICES_CONFIG")

    # Download Root CA from 1Password
    log_info "[PHASE 13] Retrieving Root CA from 1Password..."
    if ! op document get "$root_ca_file" \
        --vault "$VAULT_NAME" \
        --output "$work_dir/root-ca.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to retrieve root-ca.pem from 1Password"
        log_error "Ensure Phase 04 (cert-authority-bootstrap) completed successfully"
        return 1
    fi

    # Download Intermediate CA from 1Password
    log_info "[PHASE 13] Retrieving Intermediate CA from 1Password..."
    if ! op document get "$int_ca_file" \
        --vault "$VAULT_NAME" \
        --output "$work_dir/intermediate-ca.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to retrieve intermediate-ca.pem from 1Password"
        return 1
    fi

    # Import Root CA to macOS System Keychain
    log_info "[PHASE 13] Importing Root CA to System Keychain..."
    if ! sudo security add-trusted-cert \
        -d \
        -r trustRoot \
        -k /Library/Keychains/System.keychain \
        "$work_dir/root-ca.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to import Root CA to System Keychain"
        log_error "This may require administrator privileges"
        return 1
    fi

    # Import Intermediate CA to macOS System Keychain
    log_info "[PHASE 13] Importing Intermediate CA to System Keychain..."
    if ! sudo security add-trusted-cert \
        -d \
        -r trustAsRoot \
        -k /Library/Keychains/System.keychain \
        "$work_dir/intermediate-ca.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to import Intermediate CA to System Keychain"
        return 1
    fi

    log_success "[PHASE 13] ✓ CA certificates deployed to Mac Mini workstation"
    return 0
}

# Deploy server certificate to Proxmox host via SSH
deploy_cert_to_proxmox_host() {
    local host_name="$1"
    local host_ip="$2"
    local ssh_user="$3"

    log_info "[PHASE 13] Deploying server certificate to $host_name ($host_ip)..."

    # Create temporary working directory
    local work_dir
    work_dir=$(mktemp -d -t fusioncloudx-proxmox-XXXXXX)
    trap "rm -rf '$work_dir'" RETURN

    # Download server certificate from 1Password
    log_info "[PHASE 13] Retrieving server certificate from 1Password..."
    if ! op document get "server-cert.pem" \
        --vault "$VAULT_NAME" \
        --output "$work_dir/server-cert.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to retrieve server-cert.pem from 1Password"
        return 1
    fi

    # Download server private key from 1Password
    log_info "[PHASE 13] Retrieving server private key from 1Password..."
    if ! op document get "server-key.pem" \
        --vault "$VAULT_NAME" \
        --output "$work_dir/server-key.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to retrieve server-key.pem from 1Password"
        return 1
    fi

    # Validate certificate format before deployment
    log_info "[PHASE 13] Validating certificate format..."
    if ! openssl x509 -in "$work_dir/server-cert.pem" -text -noout >/dev/null 2>&1; then
        log_error "[PHASE 13] Invalid certificate format in server-cert.pem"
        return 1
    fi
    if ! openssl rsa -in "$work_dir/server-key.pem" -check >/dev/null 2>&1; then
        log_error "[PHASE 13] Invalid private key format in server-key.pem"
        return 1
    fi
    log_debug "[PHASE 13] Certificate validation passed"

    # Test SSH connectivity
    log_info "[PHASE 13] Testing SSH connectivity to $host_name..."
    if ! ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no \
        "$ssh_user@$host_ip" "echo 'SSH connection successful'" >/dev/null 2>&1; then
        log_error "[PHASE 13] Cannot connect to $host_name via SSH"
        log_error "Ensure SSH keys are configured and $host_ip is reachable"
        return 1
    fi

    # Copy certificate files to Proxmox host
    log_info "[PHASE 13] Copying certificate files to $host_name..."
    if ! scp -q -o StrictHostKeyChecking=no \
        "$work_dir/server-cert.pem" \
        "$work_dir/server-key.pem" \
        "$ssh_user@$host_ip:/tmp/" 2>/dev/null; then
        log_error "[PHASE 13] Failed to copy certificate files to $host_name"
        return 1
    fi

    # Apply certificates using pvenode command
    log_info "[PHASE 13] Applying certificates on $host_name..."
    if ! ssh -o StrictHostKeyChecking=no "$ssh_user@$host_ip" \
        "pvenode cert set /tmp/server-cert.pem /tmp/server-key.pem" 2>/dev/null; then
        log_error "[PHASE 13] Failed to set certificates on $host_name"
        return 1
    fi

    # Restart pveproxy service to load new certificates
    log_info "[PHASE 13] Restarting pveproxy service on $host_name..."
    if ! ssh -o StrictHostKeyChecking=no "$ssh_user@$host_ip" \
        "systemctl restart pveproxy" 2>/dev/null; then
        log_error "[PHASE 13] Failed to restart pveproxy on $host_name"
        return 1
    fi

    # Wait for pveproxy to fully restart before verification
    log_debug "[PHASE 13] Waiting for pveproxy to fully restart..."
    sleep 3

    # Clean up temporary files on remote host
    ssh -o StrictHostKeyChecking=no "$ssh_user@$host_ip" \
        "rm -f /tmp/server-cert.pem /tmp/server-key.pem" 2>/dev/null || true

    log_success "[PHASE 13] ✓ Server certificate deployed to $host_name"
    return 0
}

# Verify deployment
verify_bootstrap_deployment() {
    log_info "[PHASE 13] Verifying certificate deployment..."

    # Verify Mac Mini keychain
    if is_macos; then
        log_info "[PHASE 13] Checking System Keychain for CA certificates..."
        if security find-certificate -c "FusionCloudX" \
            /Library/Keychains/System.keychain >/dev/null 2>&1; then
            log_success "[PHASE 13] ✓ CA certificates found in System Keychain"
        else
            log_warn "[PHASE 13] ⚠ CA certificates not found in System Keychain"
        fi
    fi

    # Verify Proxmox hosts HTTPS access
    local proxmox_count
    proxmox_count=$(yq eval '.bootstrap_devices.proxmox_hosts | length' "$DEVICES_CONFIG")

    for (( i=0; i<proxmox_count; i++ )); do
        local host_name
        local host_ip
        host_name=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].name" "$DEVICES_CONFIG")
        host_ip=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].ip" "$DEVICES_CONFIG")

        log_info "[PHASE 13] Verifying HTTPS access to $host_name..."
        if curl -s -o /dev/null -w "%{http_code}" --max-time 5 \
            "https://$host_ip:8006" | grep -q "200\|401\|302"; then
            log_success "[PHASE 13] ✓ $host_name HTTPS accessible"
        else
            log_warn "[PHASE 13] ⚠ $host_name HTTPS verification failed (may need time to restart)"
        fi
    done

    log_success "[PHASE 13] Verification complete"
}

#==============================================================================
# Main Execution
#==============================================================================

#==============================================================================
# 1. Validate Prerequisites
#==============================================================================
log_info "[PHASE 13] Validating prerequisites..."

# Check yq for YAML parsing
if ! command -v yq &> /dev/null; then
    log_error "[PHASE 13] yq not found - required for YAML parsing"
    log_error "Ensure Phase 00-precheck has run successfully"
    exit 1
fi

# Check 1Password CLI
if ! command -v op &> /dev/null; then
    log_error "[PHASE 13] 1Password CLI (op) not found"
    log_error "Install from: https://developer.1password.com/docs/cli"
    exit 1
fi

# Check 1Password authentication
check_op_vault_access "$VAULT_NAME"

# Check bootstrap devices configuration
if [[ ! -f "$DEVICES_CONFIG" ]]; then
    log_error "[PHASE 13] Bootstrap device configuration not found: $DEVICES_CONFIG"
    log_error "Expected: config/bootstrap-devices.yaml"
    exit 1
fi

# Validate bootstrap_devices structure
if ! yq eval 'has("bootstrap_devices")' "$DEVICES_CONFIG" | grep -q "true"; then
    log_error "[PHASE 13] Configuration missing 'bootstrap_devices' key"
    log_error "Expected structure: bootstrap_devices.workstation and bootstrap_devices.proxmox_hosts"
    exit 1
fi

# Platform-specific checks
if is_macos; then
    # Check for security command (macOS keychain management)
    if ! command -v security &> /dev/null; then
        log_error "[PHASE 13] security command not found (required for macOS keychain)"
        exit 1
    fi
else
    log_warn "[PHASE 13] Not running on macOS - skipping workstation CA deployment"
fi

# Check for SSH (required for Proxmox deployment)
if ! command -v ssh &> /dev/null; then
    log_error "[PHASE 13] ssh not found - required for Proxmox deployment"
    exit 1
fi

if ! command -v scp &> /dev/null; then
    log_error "[PHASE 13] scp not found - required for Proxmox deployment"
    exit 1
fi

log_success "[PHASE 13] Prerequisites validated"

#==============================================================================
# 2. Load Bootstrap Device Configuration
#==============================================================================
log_info "[PHASE 13] Loading bootstrap device configuration..."

PROXMOX_COUNT=$(yq eval '.bootstrap_devices.proxmox_hosts | length' "$DEVICES_CONFIG")
TOTAL_DEVICES=$((1 + PROXMOX_COUNT))  # 1 workstation + N proxmox hosts

log_info "[PHASE 13] Found $TOTAL_DEVICES bootstrap device(s):"
log_info "[PHASE 13]   - 1 workstation (Mac Mini M4 Pro)"
log_info "[PHASE 13]   - $PROXMOX_COUNT Proxmox host(s)"

if [[ "$PROXMOX_COUNT" -eq 0 ]]; then
    log_warn "[PHASE 13] No Proxmox hosts configured"
    log_warn "Terraform will not be able to connect to Proxmox API"
fi

#==============================================================================
# 3. Deploy CA Certificates to Workstation
#==============================================================================
if is_macos; then
    if deploy_ca_to_macos_workstation; then
        log_success "[PHASE 13] Workstation CA deployment successful"
    else
        log_error "[PHASE 13] Workstation CA deployment failed"
        exit 1
    fi
else
    log_info "[PHASE 13] Skipping workstation deployment (not macOS)"
fi

#==============================================================================
# 4. Deploy Server Certificates to Proxmox Hosts
#==============================================================================
log_info "[PHASE 13] Deploying certificates to Proxmox hosts..."

FAILED_HOSTS=()

for (( i=0; i<PROXMOX_COUNT; i++ )); do
    HOST_NAME=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].name" "$DEVICES_CONFIG")
    HOST_HOSTNAME=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].hostname" "$DEVICES_CONFIG")
    HOST_IP=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].ip" "$DEVICES_CONFIG")
    HOST_SSH_USER=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].ssh_user" "$DEVICES_CONFIG")

    log_info "[PHASE 13] Processing $HOST_NAME ($HOST_HOSTNAME - $HOST_IP)..."

    if deploy_cert_to_proxmox_host "$HOST_NAME" "$HOST_IP" "$HOST_SSH_USER"; then
        log_success "[PHASE 13] ✓ $HOST_NAME deployment successful"
    else
        log_error "[PHASE 13] ✗ $HOST_NAME deployment failed"
        FAILED_HOSTS+=("$HOST_NAME")
    fi

    echo ""
done

# Check for failures
if [[ ${#FAILED_HOSTS[@]} -gt 0 ]]; then
    log_error "[PHASE 13] Certificate deployment failed for ${#FAILED_HOSTS[@]} host(s):"
    for host in "${FAILED_HOSTS[@]}"; do
        log_error "[PHASE 13]   - $host"
    done
    exit 1
fi

log_success "[PHASE 13] All Proxmox hosts deployed successfully"

#==============================================================================
# 5. Verify Deployment
#==============================================================================
verify_bootstrap_deployment

#==============================================================================
# 6. Summary
#==============================================================================
log_info ""
log_info "[PHASE 13] =========================================="
log_info "[PHASE 13] Bootstrap Certificate Deployment Complete"
log_info "[PHASE 13] =========================================="
log_info "[PHASE 13]"
log_info "[PHASE 13] Deployed to:"
log_info "[PHASE 13]   ✓ Mac Mini M4 Pro (CA certificates)"
for (( i=0; i<PROXMOX_COUNT; i++ )); do
    HOST_NAME=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].name" "$DEVICES_CONFIG")
    log_info "[PHASE 13]   ✓ $HOST_NAME (server certificate)"
done
log_info "[PHASE 13]"
log_info "[PHASE 13] Next Steps:"
log_info "[PHASE 13]   1. Verify Proxmox web UI accessible at:"
for (( i=0; i<PROXMOX_COUNT; i++ )); do
    HOST_IP=$(yq eval ".bootstrap_devices.proxmox_hosts[$i].ip" "$DEVICES_CONFIG")
    log_info "[PHASE 13]      https://$HOST_IP:8006 (should show secure padlock)"
done
log_info "[PHASE 13]   2. Proceed to infrastructure deployment with Terraform/Ansible"
log_info "[PHASE 13]   3. Bootstrap is now complete - Terraform-ready state achieved"
log_info ""

# Mark phase as complete
log_phase "$PHASE_NAME" "complete" "🔐" "$PHASE_DESC"
mark_phase_as_run "$PHASE_NAME"
