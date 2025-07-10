#!/usr/bin/env bash
set -euo pipefail

PHASE_NAME="04-cert-authority-bootstrap"
PHASE_DESC="Starting Root CA and SSL generation"

source modules/logging.sh
source modules/notify.sh
source modules/state.sh
source modules/bootstrap_env.sh

log_phase "$PHASE_NAME" "start" "🔑" "$PHASE_DESC"
if ! command -v op &> /dev/null; then
    log_error "[CERT] 1Password CLI (op) is not installed. Please install it before running this phase."
    exit 1
fi

# Ensure 1Password CLI is logged in
if ! op vault list --format json > /dev/null 2>&1; then
    log_success "[CERT][1Password] Successfully logged in to 1Password CLI."
else
    log_info "[CERT][1Password] Already logged in to 1Password CLI."
fi

# Define directories for storing certificates and keys
CERT_ROOT="/etc/fusioncloudx/certs"
CA_DIR="$CERT_ROOT/ca"
CERTS_DIR="$CERT_ROOT/issued"
PRIVATE_DIR="$CERT_ROOT/private"
EXTFILE="$CERT_ROOT/extfile.cnf"

Check for existing certificates in 1Password vault
Attempt login to 1Password if not already signed in
if ! op account get --vault Services > /dev/null 2>&1; then
    log_info "[CERT][1Password] Not signed in. Attempting login..."

    # if [[ -z "${OP_EMAIL:-}" || -z "${OP_SECRET_KEY:-}" || -z "${OP_PASSWORD:-}" ]]; then
    #     log_error "[CERT][1Password] Missing OP_EMAIL, OP_SECRET_KEY, or OP_PASSWORD env variables for headless signin."
    #     exit 1
    # fi

    eval $(echo "$OP_PASSWORD" | op account add --email "$OP_EMAIL" --address "my.1password.com" --raw)

    if [[ $? -ne 0 ]]; then
        log_error "[CERT][1Password] Failed to sign in to 1Password CLI. Please check credentials or token."
        exit 1
    fi

    log_success "[CERT][1Password] Successfully signed in to 1Password CLI (headless mode)."
else
    log_info "[CERT][1Password] Already signed in to 1Password."
fi

VAULT_NAME="Services"
CA_PASS_NAME="FusionCloudX Root CA Passphrase"
KEY_ITEM_NAME="FusionCloudX Root CA Key"
CERT_ITEM_NAME="FusionCloudX Root CA"
# CA_EXISTING=$(op document get --vault "$VAULT_NAME" --title "$CERT_ITEM_NAME"2>/dev/null || true)
# KEY_EXISTING=$(op document get --vault "$VAULT_NAME" --title "${KEY_ITEM_NAME} Key" 2>/dev/null || true)
# CA_PASS_EXISTING=$(op item get "$CA_PASS_NAME" --vault "$VAULT_NAME" --format json | jq -r '.fields[] | select(.id=="password") | .value' 2>/dev/null || true)


log_info "[CERT][1Password] Target vault for CA: $VAULT_NAME"

# If existing CA and key are found in 1Password and --fresh not passed, skip generation
# if [[ -n "$CA_EXISTING" && -n "$KEY_EXISTING" && "$FRESH" == false ]]; then
#     log_info "[CERT][1Password] Existing Root CA and key found in 1Password. Skipping generation."
#     echo "$CA_EXISTING" | base64 --decode > "$ROOT_CA_CERT"
#     echo "$KEY_EXISTING" | base64 --decode > "$ROOT_CA_KEY"
#     log_success "[CERT][1Password] Root CA and key restored from 1Password."
# else
    # log_info "[CERT][1Password] No existing Root CA or key found in 1Password, or --fresh flag passed. Generating new Root CA and key."

    # # If CA passphrase exists in 1Password, use it; otherwise generate a new one
    # if [[ -n "$CA_PASS_EXISTING" && "$FRESH" == false ]]; then
    # CA_PASS=$(echo "$CA_PASS_EXISTING" | jq -r '.fields[] | select(.id=="password") | .value')
    # log_info "[1Password] Using existing Root CA passphrase from 1Password."
    # else
    
    # # Generate passphrase for Root CA key
    # log_info "[1Password] Generating new Root CA passphrase and storing in 1Password..."
    # CA_PASS=$(op item create --title "$CA_PASS_NAME" --vault "$VAULT_NAME" \
    #     password=$(op item generate-password --length 32 --symbols false) \
    #     type=login \
    #     --format json | jq -r '.fields[] | select(.id=="password") | .value')
    #     if [[ -z "$CA_PASS" ]]; then
    #     log_error "[CERT][1Password] Failed to generate or retrieve CA passphrase."
    #     exit 1
    # fi    

    # Generate new Root CA and key
    log_info "[CERT] Generating new Root CA and key..."
    # Create directory structure if it doesn't exist
    log_info "[CERT] Ensuring certificate directories exist..."
    sudo mkdir -p "$CA_DIR" "$CERTS_DIR" "$PRIVATE_DIR"

    # File paths for CA and server certificates
    ROOT_CA_CERT="$PRIVATE_DIR/root-ca.pem"
    ROOT_CA_KEY="$CA_DIR/root-ca-key.pem"
    CERT_KEY="$PRIVATE_DIR/cert-key.pem"
    CERT_CSR="$CERTS_DIR/cert.csr"
    CERT_PEM="$CERTS_DIR/cert.pem"

    # Configuration for OpenSSL
    log_info "[CERT] Writing OpenSSL configuration..."
    SUBJ="/C=US/ST=State/L=City/O=FusionCloudX/OU=DevOps/CN=*.fusioncloudx.home"
    SAN_DNS="DNS:fusioncloudx.home,DNS:*.fusioncloudx.home"
    SAN_IP="IP:192.168.40.49,IP:192.168.40.50"

    # Generate Root CA if it doesn't exist
    if [[ -f "$ROOT_CA_KEY" && -f "$ROOT_CA_CERT" ]]; then
        log_info "[CERT] Root CA aleready exists. Skipping generation."
        exit 0
    else
        log_info "[CERT] Generating Root CA..."
        # sudo openssl genrsa -passout="$CA_PASS" -out "$ROOT_CA_KEY" 4096
        sudo openssl genrsa -out "$ROOT_CA_KEY" 4096
        sudo openssl req -x509 -sha256 -days 3650 \
            -key "$ROOT_CA_KEY" \
            -subj "$SUBJ" \
            -out "$ROOT_CA_CERT"
        log_success "[CERT] Root CA generated successfully: $ROOT_CA_CERT"
    fi

    # Generate server certificate and CSR if it doesn't exist
    if [[ -f "$CERT_PEM" && -f "$CERT_KEY" ]]; then
        log_info "[CERT] Server certificate and key already exist. Skipping generation."
    else
        log_info "[CERT] Generating server certificate and CSR..."
        sudo openssl genrsa -out "$CERT_KEY" 4096
        sudo openssl req -new -sha256 -key "$CERT_KEY" -subj "$SUBJ" -out "$CERT_CSR"
    fi

    # Write extnensions file for SAN
    log_info "[CERT] Writing extensions file for SAN..."
    echo "subjectAltName=$SAN_DNS,$SAN_IP" | sudo tee "$EXTFILE" > /dev/null
    echo "extendedKeyUsage=serverAuth" | sudo tee -a "$EXTFILE" > /dev/null

    # Sign the server certificate with the Root CA
    log_info "[CERT] Signing server certificate with Root CA..."
    sudo openssl x509 -req -sha256 -days 3650 \
        -in "$CERT_CSR" \
        -CA "$ROOT_CA_CERT" \
        -CAkey "$ROOT_CA_KEY" \
        -CAcreateserial \
        -out "$CERT_PEM" \
        -extfile "$EXTFILE"

    # # Upload new files to 1Password vault
    # log_info "[CERT][1Password] Uploading new Root CA and key to 1Password vault..."
    # CA_ITEM_ID=$(op item get "$CERT_ITEM_NAME" --vault "$VAULT_NAME" --format json | jq -r '.id')
    # if [[ -z "$CA_ITEM_ID" ]]; then
    #     log_info "[CERT][1Password] Creating new item for Root CA in 1Password vault..."
    #     CA_ITEM_ID=$(op document create --title "$CERT_ITEM_NAME" --vault "$VAULT_NAME" --file "$ROOT_CA_CERT" --format json | jq -r '.id')
    #     CA_KEY_ITEM_ID=$(op document create --title "${CERT_ITEM_NAME} Key" --vault "$VAULT_NAME" --file "$ROOT_CA_KEY" --format json | jq -r '.id')
    # fi

    cat "$CERT_KEY" "$CERT_PEM" | sudo tee "$CERTS_DIR/fullchain.pem" > /dev/null

# fi


log_success "[CERT] Server certificate signed successfully: $CERT_PEM"

# TODO: Add logic for Intermediate CA, fullchain generation, and distribution to UDM Pro, UNAS Pro, etc.
# TODO: Export trusted certs to NFS for client installation (Windows/iOS/macOS)

log_phase "$PHASE_NAME" "complete" "🔑" "$PHASE_DESC"
