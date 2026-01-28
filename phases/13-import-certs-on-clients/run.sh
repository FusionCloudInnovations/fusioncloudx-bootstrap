#!/usr/bin/env bash
set -euo pipefail

#==============================================================================
# Phase 13: Import Certificates on Clients
# Purpose: Convert Phase 04 server certificates to PFX and store in 1Password
#==============================================================================

PHASE_NAME="13-import-certs-on-clients"
PHASE_DESC="Convert server certificates to PFX for device deployment"

source modules/logging.sh
source modules/platform.sh
source modules/1password.sh
source modules/state.sh

log_phase "$PHASE_NAME" "start" "🔐" "$PHASE_DESC"
log_info "[PHASE 13] Platform: $PLATFORM_OS ($PLATFORM_ARCH)"

# Configuration
VAULT_NAME="FusionCloudX"
INT_CA_ITEM_NAME="FusionCloudX Intermediate CA Bundle"
DEVICES_CONFIG="config/devices.yaml"

#==============================================================================
# Helper: Create default devices.yaml if missing
#==============================================================================
create_default_devices_config() {
    cat > "$DEVICES_CONFIG" <<'EOF'
# Device Certificate Deployment Configuration
# Defines devices that need PFX certificate deployment

devices:
  # HP OfficeJet Pro 9015e printer
  - name: "HP OfficeJet Pro 9015e"
    hostname: "printer"
    ip: "192.168.40.226"
    type: "network-printer"
    pfx_password: ""  # Blank password for printer import
    onepassword_item: "HP OfficeJet Pro 9015e Certificate"
    deployment_method: "manual"
    notes: "Import via EWS → Network → Security → Certificates → Import Certificate and Private Key"
EOF

    log_info "[PHASE 13] Created default device configuration: $DEVICES_CONFIG"
}

#==============================================================================
# 1. Validate Prerequisites
#==============================================================================
log_info "[PHASE 13] Validating prerequisites..."

# Check OpenSSL
if ! command -v openssl &> /dev/null; then
    log_error "[PHASE 13] OpenSSL not found - required for PFX conversion"
    log_error "Install with: brew install openssl (macOS) or apt install openssl (Linux)"
    exit 1
fi

# Check yq (installed by Phase 00-precheck)
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

# Check device configuration exists
if [[ ! -f "$DEVICES_CONFIG" ]]; then
    log_warn "[PHASE 13] Device configuration not found: $DEVICES_CONFIG"
    log_warn "Creating default configuration with HP printer only"
    create_default_devices_config
fi

log_success "[PHASE 13] Prerequisites validated"

#==============================================================================
# 2. Load Device Configuration
#==============================================================================
log_info "[PHASE 13] Loading device configuration from $DEVICES_CONFIG..."

# Count devices using yq
DEVICE_COUNT=$(yq eval '.devices | length' "$DEVICES_CONFIG")

if [[ "$DEVICE_COUNT" -eq 0 ]]; then
    log_warn "[PHASE 13] No devices configured in $DEVICES_CONFIG"
    log_info "[PHASE 13] Skipping certificate conversion (no target devices)"
    mark_phase_as_run "$PHASE_NAME"
    exit 0
fi

log_info "[PHASE 13] Found $DEVICE_COUNT device(s) configured"

#==============================================================================
# 3. Create Temporary Working Directory
#==============================================================================
WORK_DIR=$(mktemp -d -t fusioncloudx-pfx-XXXXXX)
trap "rm -rf '$WORK_DIR'" EXIT

log_info "[PHASE 13] Working directory: $WORK_DIR"

#==============================================================================
# 4. Retrieve Server Certificate from 1Password
#==============================================================================
log_info "[PHASE 13] Retrieving server certificate from 1Password..."

# Download server-cert.pem
if ! op document get "server-cert.pem" \
    --vault "$VAULT_NAME" \
    --output "$WORK_DIR/server-cert.pem" 2>/dev/null; then
    log_error "[PHASE 13] Failed to retrieve server-cert.pem from 1Password"
    log_error "Ensure Phase 04 (cert-authority-bootstrap) completed successfully"
    exit 1
fi

# Download server-key.pem
if ! op document get "server-key.pem" \
    --vault "$VAULT_NAME" \
    --output "$WORK_DIR/server-key.pem" 2>/dev/null; then
    log_error "[PHASE 13] Failed to retrieve server-key.pem from 1Password"
    exit 1
fi

log_success "[PHASE 13] Server certificate retrieved from 1Password"

#==============================================================================
# 5. Generate PFX for Each Device
#==============================================================================
log_info "[PHASE 13] Converting certificates to PFX format..."

# Process each device
for (( i=0; i<DEVICE_COUNT; i++ )); do
    # Extract device properties using yq
    DEVICE_NAME=$(yq eval ".devices[$i].name" "$DEVICES_CONFIG")
    DEVICE_HOSTNAME=$(yq eval ".devices[$i].hostname" "$DEVICES_CONFIG")
    DEVICE_IP=$(yq eval ".devices[$i].ip" "$DEVICES_CONFIG")
    DEVICE_TYPE=$(yq eval ".devices[$i].type" "$DEVICES_CONFIG")
    DEVICE_PFX_PASSWORD=$(yq eval ".devices[$i].pfx_password" "$DEVICES_CONFIG")
    DEVICE_OP_ITEM=$(yq eval ".devices[$i].onepassword_item" "$DEVICES_CONFIG")
    DEVICE_DEPLOYMENT=$(yq eval ".devices[$i].deployment_method" "$DEVICES_CONFIG")
    DEVICE_NOTES=$(yq eval ".devices[$i].notes" "$DEVICES_CONFIG")

    log_info "[PHASE 13] Processing device: $DEVICE_NAME"

    # Generate PFX filename
    PFX_FILENAME="${DEVICE_HOSTNAME}.pfx"
    PFX_PATH="$WORK_DIR/$PFX_FILENAME"

    # Convert PEM to PFX using OpenSSL
    if ! openssl pkcs12 -export \
        -in "$WORK_DIR/server-cert.pem" \
        -inkey "$WORK_DIR/server-key.pem" \
        -out "$PFX_PATH" \
        -name "FusionCloudX Server Certificate - $DEVICE_NAME" \
        -passout "pass:$DEVICE_PFX_PASSWORD" 2>/dev/null; then
        log_error "[PHASE 13] Failed to convert PFX for $DEVICE_NAME"
        exit 1
    fi

    log_success "[PHASE 13] ✓ PFX created: $PFX_FILENAME"

    # Store PFX in 1Password
    CURRENT_TIME=$(date '+%Y-%m-%d %H:%M:%S')

    # Check if item already exists
    if op item get "$DEVICE_OP_ITEM" --vault "$VAULT_NAME" --format json &>/dev/null; then
        # Item exists - delete and recreate for clean state
        log_info "[PHASE 13] Updating existing 1Password item: $DEVICE_OP_ITEM"
        op item delete "$DEVICE_OP_ITEM" --vault "$VAULT_NAME" &>/dev/null || true
    else
        log_info "[PHASE 13] Creating new 1Password item: $DEVICE_OP_ITEM"
    fi

    # Create 1Password item with metadata
    op item create \
        --category SERVER \
        --title "$DEVICE_OP_ITEM" \
        --vault "$VAULT_NAME" \
        "Device Name=$DEVICE_NAME" \
        "Device IP=$DEVICE_IP" \
        "Device Type=$DEVICE_TYPE" \
        "Hostname=$DEVICE_HOSTNAME" \
        "Deployment Method=$DEVICE_DEPLOYMENT" \
        "Updated=$CURRENT_TIME" \
        "Notes[multiline]=$DEVICE_NOTES" \
        >/dev/null 2>&1

    # Attach PFX file to item (escape dots in filename)
    ESCAPED_FILENAME="${PFX_FILENAME//./\\.}"
    op item edit "$DEVICE_OP_ITEM" \
        --vault "$VAULT_NAME" \
        "Files.${ESCAPED_FILENAME}[file]=$PFX_PATH" \
        >/dev/null 2>&1

    log_success "[PHASE 13] ✓ PFX stored in 1Password: $DEVICE_OP_ITEM"
    echo ""
done

log_success "[PHASE 13] All device certificates converted and stored in 1Password"

#==============================================================================
# 6. Display Deployment Instructions
#==============================================================================
log_info ""
log_info "[PHASE 13] =========================================="
log_info "[PHASE 13] Certificate Deployment Instructions"
log_info "[PHASE 13] =========================================="
log_info ""

# Display instructions for each device
for (( i=0; i<DEVICE_COUNT; i++ )); do
    DEVICE_NAME=$(yq eval ".devices[$i].name" "$DEVICES_CONFIG")
    DEVICE_HOSTNAME=$(yq eval ".devices[$i].hostname" "$DEVICES_CONFIG")
    DEVICE_IP=$(yq eval ".devices[$i].ip" "$DEVICES_CONFIG")
    DEVICE_OP_ITEM=$(yq eval ".devices[$i].onepassword_item" "$DEVICES_CONFIG")
    DEVICE_NOTES=$(yq eval ".devices[$i].notes" "$DEVICES_CONFIG")

    log_info "[PHASE 13] Device $((i+1)): $DEVICE_NAME"
    log_info "[PHASE 13]   1. Open 1Password → FusionCloudX vault"
    log_info "[PHASE 13]   2. Open item: '$DEVICE_OP_ITEM'"
    log_info "[PHASE 13]   3. Download: ${DEVICE_HOSTNAME}.pfx"
    log_info "[PHASE 13]   4. Navigate to: https://$DEVICE_IP"
    log_info "[PHASE 13]   5. $DEVICE_NOTES"
    log_info "[PHASE 13]   6. Delete downloaded PFX file after import"
    log_info "[PHASE 13]"
done

#==============================================================================
# 7. Summary
#==============================================================================
log_info "[PHASE 13] =========================================="
log_info "[PHASE 13] Phase Summary"
log_info "[PHASE 13] =========================================="
log_info "[PHASE 13]   ✓ Retrieved server certificate from 1Password"
log_info "[PHASE 13]   ✓ Converted $DEVICE_COUNT device(s) to PFX format"
log_info "[PHASE 13]   ✓ Stored PFX files in 1Password"
log_info "[PHASE 13]"
log_info "[PHASE 13] Next Steps:"
log_info "[PHASE 13]   1. Download PFX from 1Password (device-specific item)"
log_info "[PHASE 13]   2. Import PFX to device via web UI"
log_info "[PHASE 13]   3. Verify HTTPS access shows secure padlock"
log_info "[PHASE 13]   4. Delete downloaded PFX file from local disk"
log_info ""

# Mark phase as complete
log_phase "$PHASE_NAME" "complete" "🔐" "$PHASE_DESC"
