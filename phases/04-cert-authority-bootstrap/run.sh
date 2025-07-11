#!/usr/bin/env bash
set -euo pipefail

PHASE_NAME="04-cert-authority-bootstrap"
PHASE_DESC="Root CA and SSL generation"

source modules/logging.sh
source modules/notify.sh
source modules/state.sh
source modules/1password.sh
source modules/bootstrap_env.sh

log_phase "$PHASE_NAME" "start" "🔑" "$PHASE_DESC"
if ! command -v op &> /dev/null; then
    log_error "[CERT] 1Password CLI (op) is not installed. Please install it before running this phase."
    exit 1
fi

# Check if the 1Password CLI is authenticated with Service Account
check_op_vault_access "Services"

VAULT_NAME="Services"
ORGANIZATION="FusionCloudX"
CA_PASS_NAME="${ORGANIZATION} Root CA Passphrase"
CA_ITEM_NAME="${ORGANIZATION} Root CA Bundle"
INT_CA_ITEM_NAME="${ORGANIZATION} Intermediate CA Bundle"
KEY_ITEM_NAME="${CA_ITEM_NAME} Key"

# Define directories for storing certificates and keys
CERT_ROOT="/etc/fusioncloudx/certs"
CA_DIR="$CERT_ROOT/ca"
INT_DIR="$CERT_ROOT/intermediate"
CERTS_DIR="$CERT_ROOT/issued"
PRIVATE_DIR="$CERT_ROOT/private"
EXTFILE="$CERT_ROOT/extfile.cnf"

# File paths for CA and server certificates
ROOT_CA_CERT="$PRIVATE_DIR/root-ca.pem"
ROOT_CA_KEY="$CA_DIR/root-ca-key.pem"
INT_CA_CERT="$INT_DIR/intermediate-ca.pem"
INT_CA_KEY="$INT_DIR/intermediate-ca-key.pem"
CERT_KEY="$PRIVATE_DIR/cert-key.pem"
CERT_CSR="$CERTS_DIR/cert.csr"
CERT_PEM="$CERTS_DIR/cert.pem"
FULLCHAIN_PEM="$CERTS_DIR/fullchain.pem"

# Subject and SAN for the Root CA and server certificate
SUBJ="/C=US/ST=State/L=City/O=FusionCloudX/OU=DevOps/CN=*.fusioncloudx.home"
SAN_DNS="DNS:fusioncloudx.home,DNS:*.fusioncloudx.home"
SAN_IP="IP:192.168.40.49,IP:192.168.40.50"

# Create required directories if they don't exist
for dir in "$CA_DIR" "$INT_DIR" "$CERTS_DIR" "$PRIVATE_DIR"; do
    sudo rm -rf "$dir"
    if [[ ! -d "$dir" ]]; then
        log_info "[CERT] Creating directory: $dir"
        sudo mkdir -p "$dir"
    fi
done

# Check for existing certificates in 1Password vault
if CA_JSON=$(op item get "$CA_ITEM_NAME" --vault "$VAULT_NAME" --format json 2>/dev/null); then
    log_info "[CERT][1Password] Found existing Root CA in 1Password vault: $CA_ITEM_NAME"
else
    log_info "[CERT][1Password] No existing Root CA found in 1Password vault."

    # Generate a new Root CA passphrase and store it in 1Password
    if CA_PASS_JSON=$(op item create "Certificate Authority.CA Passphrase[concealed]=$(apg -n 1 -m 32 -x 32 -M CLSN -c 1)" --vault "$VAULT_NAME" --template "templates/1password/ca-bundle-template.json" --format json); then
        CA_PASS=$(echo "$CA_PASS_JSON" | jq -r '.fields[] | select(.id=="password") | .value')
        log_info "[CERT][1Password] New Root CA passphrase generated and stored in 1Password."
    else
        log_error "[CERT][1Password] Failed to create Root CA passphrase in 1Password."
        exit 1
    fi

    # Generate Root CA
    if [[ ! -f "$ROOT_CA_KEY" || ! -f "$ROOT_CA_CERT" ]]; then
        log_info "[CERT] Generating Root CA..."
        sudo openssl genrsa -aes256 -passout pass:"$(op read "op://$VAULT_NAME/$CA_ITEM_NAME/CA passphrase")" -out "$ROOT_CA_KEY" 4096
        sudo openssl req -x509 -sha256 -days 3650 -key "$ROOT_CA_KEY" -subj "$SUBJ" -out "$ROOT_CA_CERT" -passin pass:"$(op read "op://$VAULT_NAME/$CA_ITEM_NAME/CA passphrase")"
        log_success "[CERT] Root CA generated successfully: $ROOT_CA_CERT"
        sleep 2
    fi

    # Generate a new Intermediate CA passphrase and store it in 1Password
    if INT_CA_PASS_JSON=$(op item create --title="FusionCloudX Intermediate CA Bundle" "Certificate Authority.CA Passphrase[concealed]=$(apg -n 1 -m 32 -x 32 -M CLSN -c 1)" --vault "$VAULT_NAME" --template "templates/1password/ca-bundle-template.json" --format json); then
        INT_CA_PASS=$(echo "$INT_CA_PASS_JSON" | jq -r '.fields[] | select(.id=="password") | .value')
        log_info "[CERT][1Password] New Intermediate CA passphrase generated and stored in 1Password."
    else
        log_error "[CERT][1Password] Failed to create Intermediate CA passphrase in 1Password."
        exit 1
    fi

    # Generate Intermediate CA
    if [[ ! -f "$INT_CA_KEY" || ! -f "$INT_CA_CERT" ]]; then
        log_info "[CERT] Generating Intermediate CA..."
        sudo openssl genrsa -aes256 -passout pass:"$(op read "op://$VAULT_NAME/$INT_CA_ITEM_NAME/CA passphrase")" -out "$INT_CA_KEY" 4096
        log_info "[CERT] Generating Intermediate CA CSR..."
        sudo openssl req -new -sha256 -key "$INT_CA_KEY" -subj "$SUBJ" -out "$INT_DIR/intermediate-ca.csr" -passin pass:"$(op read "op://$VAULT_NAME/$INT_CA_ITEM_NAME/CA passphrase")"
        log_info "[CERT] Signing Intermediate CA with Root CA..."
        sudo openssl x509 -req -sha256 -days 3650 -in "$INT_DIR/intermediate-ca.csr" -CA "$ROOT_CA_CERT" -CAkey "$ROOT_CA_KEY" -CAcreateserial -out "$INT_CA_CERT" --passin pass:"$(op read "op://$VAULT_NAME/$CA_ITEM_NAME/CA passphrase")"
        log_info "[CERT] Intermediate CA signed successfully: $INT_CA_CERT"
        log_success "[CERT] Intermediate CA generated successfully: $INT_CA_CERT"
    fi

    # Generate server key and CSR
    if [[ ! -f "$CERT_KEY" || ! -f "$CERT_CSR" ]]; then
        log_info "[CERT] Generating server key and CSR..."
        sudo openssl genrsa -out "$CERT_KEY" 4096
        sudo openssl req -new -sha256 -key "$CERT_KEY" -subj "$SUBJ" -out "$CERT_CSR"
        log_success "[CERT] Server key and CSR generated successfully."
    fi

    # Write extnensions file for SAN
    if [[ ! -f "$EXTFILE" ]]; then
        log_info "[CERT] Writing extensions file for SAN..."
        echo "subjectAltName=$SAN_DNS,$SAN_IP" | sudo tee "$EXTFILE" > /dev/null
        echo "extendedKeyUsage=serverAuth" | sudo tee -a "$EXTFILE" > /dev/null
        log_success "[CERT] Extensions file written successfully: $EXTFILE"
        sudo touch "$EXTFILE"
    fi
    
    # Sign server cert with Intermediate CA
    if [[ ! -f "$CERT_PEM" ]]; then
        log_info "[CERT] Signing server certificate with Intermediate CA..."
        sudo openssl x509 -req -sha256 -days 3650 -in "$CERT_CSR" -CA "$INT_CA_CERT" -CAkey "$INT_CA_KEY" -CAcreateserial -out "$CERT_PEM" -extfile "$EXTFILE" --passin pass:"$(op read "op://$VAULT_NAME/$INT_CA_ITEM_NAME/CA passphrase")"
        log_success "[CERT] Server certificate signed successfully: $CERT_PEM"
    fi

    # Build fullchain.pem
    if [[ ! -f "$FULLCHAIN_PEM" ]]; then
        log_info "[CERT] Building fullchain.pem..."
        sudo cat "$CERT_KEY" "$INT_CA_CERT" "$ROOT_CA_CERT" | sudo tee "$FULLCHAIN_PEM" > /dev/null
        log_success "[CERT] Fullchain.pem created successfully: $FULLCHAIN_PEM"
    fi
fi

#     # Upload new files to 1Password vault
#     log_info "[CERT][1Password] Uploading new Root CA and key to 1Password vault..."
#     CA_ITEM_ID=$(op item get "$CA_ITEM_NAME" --vault "$VAULT_NAME" --format json | jq -r '.id')
#     if [[ -z "$CA_ITEM_ID" ]]; then
#         log_info "[CERT][1Password] Creating new item for Root CA in 1Password vault..."
#         CA_ITEM_ID=$(op document create --title "$CA_ITEM_NAME" --vault "$VAULT_NAME" --file "$ROOT_CA_CERT" --format json | jq -r '.id')
#         CA_KEY_ITEM_ID=$(op document create --title "${CA_ITEM_NAME} Key" --vault "$VAULT_NAME" --file "$ROOT_CA_KEY" --format json | jq -r '.id')
#     fi

#     cat "$CERT_KEY" "$CERT_PEM" | sudo tee "$CERTS_DIR/fullchain.pem" > /dev/null

# fi


# log_success "[CERT] Server certificate signed successfully: $CERT_PEM"

# TODO: Add logic for Intermediate CA, fullchain generation, and distribution to UDM Pro, UNAS Pro, etc.
# TODO: Export trusted certs to NFS for client installation (Windows/iOS/macOS)

log_phase "$PHASE_NAME" "complete" "🔑" "$PHASE_DESC"
