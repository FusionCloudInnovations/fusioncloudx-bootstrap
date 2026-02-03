#!/usr/bin/env bash
set -euo pipefail

PHASE_NAME="04-cert-authority-bootstrap"
PHASE_DESC="Root CA and SSL generation"

source modules/logging.sh
source modules/platform.sh
source modules/notify.sh
source modules/state.sh
source modules/1password.sh

log_phase "$PHASE_NAME" "start" "🔑" "$PHASE_DESC"
log_info "[CERT] Platform: $PLATFORM_OS ($PLATFORM_ARCH)"

if ! command -v op &> /dev/null; then
    log_error "[CERT] 1Password CLI (op) is not installed. Please install it before running this phase."
    exit 1
fi

# Check if the 1Password CLI is authenticated with Service Account
check_op_vault_access "FusionCloudX"

VAULT_NAME="FusionCloudX"
ORGANIZATION="FusionCloudX"
CA_PASS_NAME="${ORGANIZATION} Root CA Passphrase"
CA_ITEM_NAME="${ORGANIZATION} Root CA Bundle"
INT_CA_ITEM_NAME="${ORGANIZATION} Intermediate CA Bundle"
KEY_ITEM_NAME="${CA_ITEM_NAME} Key"

# ─────────────────────────────────────────────────────────────
# Define directories for storing certificates and keys
# Platform-aware: macOS uses temp dir, Linux uses system dir
# ─────────────────────────────────────────────────────────────
CERT_ROOT="$(get_cert_base_path)"
CA_DIR="$CERT_ROOT/ca"
INT_DIR="$CERT_ROOT/intermediate"
CERTS_DIR="$CERT_ROOT/issued"
PRIVATE_DIR="$CERT_ROOT/private"
EXTFILE="$CERT_ROOT/extfile.cnf"
EXTFILE_ROOT_CA="$CERT_ROOT/extfile-root-ca.cnf"
EXTFILE_INT_CA="$CERT_ROOT/extfile-int-ca.cnf"
EXTFILE_SERVER="$CERT_ROOT/extfile-server.cnf"

log_info "[CERT] Certificate root directory: $CERT_ROOT"

# File paths for CA and server certificates
ROOT_CA_CERT="$PRIVATE_DIR/root-ca.pem"
ROOT_CA_KEY="$CA_DIR/root-ca-key.pem"
INT_CA_CERT="$INT_DIR/intermediate-ca.pem"
INT_CA_KEY="$INT_DIR/intermediate-ca-key.pem"
CERT_KEY="$PRIVATE_DIR/cert-key.pem"
CERT_CSR="$CERTS_DIR/cert.csr"
CERT_PEM="$CERTS_DIR/cert.pem"
FULLCHAIN_PEM="$CERTS_DIR/fullchain.pem"

# Subject DN components (shared across certificates)
SUBJ_BASE="/C=US/ST=State/L=City/O=FusionCloudX/OU=DevOps"

# Distinct CN for each certificate type (PKI best practice)
ROOT_CA_SUBJ="${SUBJ_BASE}/CN=FusionCloudX Root CA"
INT_CA_SUBJ="${SUBJ_BASE}/CN=FusionCloudX Intermediate CA"
SERVER_SUBJ="${SUBJ_BASE}/CN=*.fusioncloudx.home"

# SAN for server certificate (wildcard + specific hostnames)
SAN_DNS="DNS:fusioncloudx.home,DNS:*.fusioncloudx.home"
SAN_IP="IP:192.168.10.1,IP:192.168.40.49,IP:192.168.40.50,IP:192.168.40.137,IP:192.168.40.93,IP:192.168.40.206"

# ─────────────────────────────────────────────────────────────
# Helper function for generating random passphrase
# Uses apg on Linux, openssl on macOS (apg not in Homebrew)
# ─────────────────────────────────────────────────────────────
generate_passphrase() {
    if command -v apg &>/dev/null; then
        apg -n 1 -m 32 -x 32 -M CLSN -c 1
    else
        # Fallback: openssl rand (available on all platforms)
        openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32
    fi
}

# ─────────────────────────────────────────────────────────────
# Create required directories
# macOS: temp dir owned by user, no sudo needed
# Linux: system dir, sudo required
# ─────────────────────────────────────────────────────────────
create_cert_dir() {
    local dir="$1"
    if [[ ! -d "$dir" ]]; then
        log_info "[CERT] Creating directory: $dir"
        if is_macos; then
            mkdir -p "$dir"
        else
            sudo mkdir -p "$dir"
        fi
    fi
}

for dir in "$CA_DIR" "$INT_DIR" "$CERTS_DIR" "$PRIVATE_DIR"; do
    create_cert_dir "$dir"
done

# ─────────────────────────────────────────────────────────────
# Helper for running openssl commands (with/without sudo)
# ─────────────────────────────────────────────────────────────
run_openssl() {
    if is_macos; then
        openssl "$@"
    else
        sudo openssl "$@"
    fi
}

# Helper for writing files
write_file() {
    local content="$1"
    local dest="$2"
    if is_macos; then
        echo "$content" > "$dest"
    else
        echo "$content" | sudo tee "$dest" > /dev/null
    fi
}

append_file() {
    local content="$1"
    local dest="$2"
    if is_macos; then
        echo "$content" >> "$dest"
    else
        echo "$content" | sudo tee -a "$dest" > /dev/null
    fi
}

# Helper to generate Root CA config file (RFC 5280 compliant)
# Note: OpenSSL req -x509 requires config file with [v3_ca] section, not -extfile
generate_root_ca_config() {
    local dest="$1"
    log_info "[CERT] Generating Root CA config file: $dest"
    cat > "$dest" <<'EOF'
[req]
default_bits = 4096
distinguished_name = req_distinguished_name
x509_extensions = v3_ca

[req_distinguished_name]

[v3_ca]
basicConstraints = critical, CA:TRUE
keyUsage = critical, keyCertSign, cRLSign
subjectKeyIdentifier = hash
EOF
}

# Helper to generate Intermediate CA extensions file (RFC 5280 compliant)
generate_int_ca_extfile() {
    local dest="$1"
    log_info "[CERT] Generating Intermediate CA extensions file: $dest"
    write_file "basicConstraints = critical, CA:TRUE" "$dest"
    append_file "keyUsage = critical, keyCertSign, cRLSign" "$dest"
    append_file "subjectKeyIdentifier = hash" "$dest"
    append_file "authorityKeyIdentifier = keyid:always, issuer:always" "$dest"
}

# Helper to generate Server certificate extensions file (RFC 5280 compliant)
generate_server_cert_extfile() {
    local dest="$1"
    local san_dns="$2"
    local san_ip="$3"
    log_info "[CERT] Generating Server certificate extensions file: $dest"
    write_file "basicConstraints = CA:FALSE" "$dest"
    append_file "keyUsage = critical, digitalSignature, keyEncipherment" "$dest"
    append_file "extendedKeyUsage = serverAuth" "$dest"
    append_file "subjectAltName = $san_dns,$san_ip" "$dest"
    append_file "subjectKeyIdentifier = hash" "$dest"
    append_file "authorityKeyIdentifier = keyid:always, issuer:always" "$dest"
}

# TODO: Consider cert rotation if certs exist and are nearing expiry. or forced rotation via env var.

# Check for existing certificates in 1Password vault
if CA_JSON=$(op item get "$CA_ITEM_NAME" --vault "$VAULT_NAME" --format json 2>/dev/null); then
    log_info "[CERT][1Password] Found existing Root CA in 1Password vault: $CA_ITEM_NAME"
else
    log_info "[CERT][1Password] No existing Root CA found in 1Password vault."

    # Generate a new Root CA passphrase and store it in 1Password
    PASSPHRASE=$(generate_passphrase)
    if CA_PASS_JSON=$(op item create "Certificate Authority.CA Passphrase[concealed]=$PASSPHRASE" --vault "$VAULT_NAME" --template "templates/1password/ca-bundle-template.json" --format json); then
        CA_PASS=$(echo "$CA_PASS_JSON" | jq -r '.fields[] | select(.id=="ca_passphrase") | .value')
        log_info "[CERT][1Password] New Root CA passphrase generated and stored in 1Password."
    else
        log_error "[CERT][1Password] Failed to create Root CA passphrase in 1Password."
        exit 1
    fi

    # Generate Root CA with RFC 5280 extensions
    if [[ ! -f "$ROOT_CA_KEY" || ! -f "$ROOT_CA_CERT" ]]; then
        log_info "[CERT] Generating Root CA..."
        run_openssl genrsa -aes256 -passout pass:"$(op read "op://$VAULT_NAME/$CA_ITEM_NAME/CA passphrase")" -out "$ROOT_CA_KEY" 4096
        generate_root_ca_config "$EXTFILE_ROOT_CA"
        run_openssl req -x509 -sha256 -days 365 -key "$ROOT_CA_KEY" -subj "$ROOT_CA_SUBJ" -out "$ROOT_CA_CERT" -config "$EXTFILE_ROOT_CA" -passin pass:"$(op read "op://$VAULT_NAME/$CA_ITEM_NAME/CA passphrase")"
        log_success "[CERT] Root CA generated successfully with RFC 5280 extensions: $ROOT_CA_CERT"
        sleep 2
    fi

    # Generate a new Intermediate CA passphrase and store it in 1Password
    INT_PASSPHRASE=$(generate_passphrase)
    if INT_CA_PASS_JSON=$(op item create --title="FusionCloudX Intermediate CA Bundle" "Certificate Authority.CA Passphrase[concealed]=$INT_PASSPHRASE" --vault "$VAULT_NAME" --template "templates/1password/ca-bundle-template.json" --format json); then
        INT_CA_PASS=$(echo "$INT_CA_PASS_JSON" | jq -r '.fields[] | select(.id=="ca_passphrase") | .value')
        log_info "[CERT][1Password] New Intermediate CA passphrase generated and stored in 1Password."
    else
        log_error "[CERT][1Password] Failed to create Intermediate CA passphrase in 1Password."
        exit 1
    fi

    # Generate Intermediate CA with RFC 5280 extensions
    if [[ ! -f "$INT_CA_KEY" || ! -f "$INT_CA_CERT" ]]; then
        log_info "[CERT] Generating Intermediate CA..."
        run_openssl genrsa -aes256 -passout pass:"$(op read "op://$VAULT_NAME/$INT_CA_ITEM_NAME/CA passphrase")" -out "$INT_CA_KEY" 4096
        log_info "[CERT] Generating Intermediate CA CSR..."
        run_openssl req -new -sha256 -key "$INT_CA_KEY" -subj "$INT_CA_SUBJ" -out "$INT_DIR/intermediate-ca.csr" -passin pass:"$(op read "op://$VAULT_NAME/$INT_CA_ITEM_NAME/CA passphrase")"
        generate_int_ca_extfile "$EXTFILE_INT_CA"
        log_info "[CERT] Signing Intermediate CA with Root CA..."
        run_openssl x509 -req -sha256 -days 365 -in "$INT_DIR/intermediate-ca.csr" -CA "$ROOT_CA_CERT" -CAkey "$ROOT_CA_KEY" -CAcreateserial -out "$INT_CA_CERT" -extfile "$EXTFILE_INT_CA" -passin pass:"$(op read "op://$VAULT_NAME/$CA_ITEM_NAME/CA passphrase")"
        log_info "[CERT] Intermediate CA signed successfully with RFC 5280 extensions: $INT_CA_CERT"
        log_success "[CERT] Intermediate CA generated successfully: $INT_CA_CERT"
    fi

    # Generate server key and CSR
    if [[ ! -f "$CERT_KEY" || ! -f "$CERT_CSR" ]]; then
        log_info "[CERT] Generating server key and CSR..."
        run_openssl genrsa -out "$CERT_KEY" 4096
        run_openssl req -new -sha256 -key "$CERT_KEY" -subj "$SERVER_SUBJ" -out "$CERT_CSR"
        log_success "[CERT] Server key and CSR generated successfully."
    fi

    # Generate server certificate extensions file with RFC 5280 compliance
    if [[ ! -f "$EXTFILE_SERVER" ]]; then
        generate_server_cert_extfile "$EXTFILE_SERVER" "$SAN_DNS" "$SAN_IP"
        log_success "[CERT] Server certificate extensions file written with RFC 5280 compliance: $EXTFILE_SERVER"
    fi

    # Sign server cert with Intermediate CA
    if [[ ! -f "$CERT_PEM" ]]; then
        log_info "[CERT] Signing server certificate with Intermediate CA..."
        run_openssl x509 -req -sha256 -days 365 -in "$CERT_CSR" -CA "$INT_CA_CERT" -CAkey "$INT_CA_KEY" -CAcreateserial -out "$CERT_PEM" -extfile "$EXTFILE_SERVER" -passin pass:"$(op read "op://$VAULT_NAME/$INT_CA_ITEM_NAME/CA passphrase")"
        log_success "[CERT] Server certificate signed successfully with RFC 5280 compliance: $CERT_PEM"
    fi

    # Build fullchain.pem (server cert + intermediate CA only, NOT root CA)
    # Root CA is handled separately via keychain/system trust store
    if [[ ! -f "$FULLCHAIN_PEM" ]]; then
        log_info "[CERT] Building fullchain.pem (server cert + intermediate CA)..."
        if is_macos; then
            cat "$CERT_PEM" "$INT_CA_CERT" > "$FULLCHAIN_PEM"
        else
            sudo cat "$CERT_PEM" "$INT_CA_CERT" | sudo tee "$FULLCHAIN_PEM" > /dev/null
        fi
        log_success "[CERT] Fullchain.pem created successfully: $FULLCHAIN_PEM"
    fi

    # Validate certificate extensions (RFC 5280 compliance check)
    log_info "[CERT] Validating certificate X.509v3 extensions..."
    validate_cert_extensions() {
        local cert_path="$1"
        local cert_type="$2"
        log_info "[CERT] Checking extensions in $cert_type: $cert_path"
        if is_macos; then
            openssl x509 -in "$cert_path" -text -noout | grep -A 10 "X509v3 extensions"
        else
            sudo openssl x509 -in "$cert_path" -text -noout | grep -A 10 "X509v3 extensions"
        fi
    }
    validate_cert_extensions "$ROOT_CA_CERT" "Root CA"
    validate_cert_extensions "$INT_CA_CERT" "Intermediate CA"
    validate_cert_extensions "$CERT_PEM" "Server Certificate"
    log_success "[CERT] Certificate validation complete. Check output above for X509v3 extensions."

    # Set file permissions
    log_info "[CERT] Setting file permissions..."
    if is_macos; then
        chmod 644 "$ROOT_CA_CERT" "$INT_CA_CERT" "$CERT_PEM" "$FULLCHAIN_PEM" "$ROOT_CA_KEY" "$INT_CA_KEY" "$CERT_KEY"
    else
        sudo chmod 644 "$ROOT_CA_CERT" "$INT_CA_CERT" "$CERT_PEM" "$FULLCHAIN_PEM" "$ROOT_CA_KEY" "$INT_CA_KEY" "$CERT_KEY"
    fi
    log_success "[CERT] File permissions set successfully."

    # Prepare common metadata right before using it to ensure variables are expanded
    # Use date_add_days() for cross-platform date arithmetic
    CERT_EXPIRY=$(date_add_days 365 "%Y-%m-%d")
    METADATA_ARGS=(
        "Metadata.Root CA CN=${ROOT_CA_SUBJ}"
        "Metadata.Intermediate CA CN=${INT_CA_SUBJ}"
        "Metadata.Server Cert CN=${SERVER_SUBJ}"
        "Metadata.SAN DNS=${SAN_DNS}"
        "Metadata.SAN IP=${SAN_IP}"
        "Metadata.Server Cert Expiry=${CERT_EXPIRY}"
        "Metadata.CA Cert Expiry=${CERT_EXPIRY}"
    )

    log_info "[CERT][1Password] Common metadata prepared for 1Password items: ${METADATA_ARGS[*]}"

    # Store CA and server certs in 1Password
    if ! op item edit "$CA_ITEM_NAME" --vault "$VAULT_NAME" \
        "Files.root-ca\\.pem[file]=$ROOT_CA_CERT" \
        "Files.root-ca-key\\.pem[file]=$ROOT_CA_KEY" \
        "${METADATA_ARGS[@]}"; then

        log_error "[CERT][1Password] Failed to update Root CA item in 1Password."
        exit 1
    fi

    if ! op item edit "$INT_CA_ITEM_NAME" --vault "$VAULT_NAME" \
        "Files.intermediate-ca\\.pem[file]=$INT_CA_CERT" \
        "Files.intermediate-ca-key\\.pem[file]=$INT_CA_KEY" \
        "Files.server-cert\\.pem[file]=$CERT_PEM" \
        "Files.server-key\\.pem[file]=$CERT_KEY" \
        "Files.fullchain\\.pem[file]=$FULLCHAIN_PEM" \
        "${METADATA_ARGS[@]}"; then

        log_error "[CERT][1Password] Failed to update Intermediate CA item in 1Password."
        exit 1
    fi

    # ─────────────────────────────────────────────────────────────
    # macOS Keychain Integration
    # Import Root CA and Intermediate CA to System Keychain for trust
    # Even though Intermediate is in fullchain.pem, having it in Keychain
    # ensures proper system-wide trust validation and certificate chain building
    # ─────────────────────────────────────────────────────────────
    if is_macos; then
        log_info "[CERT] Importing certificates to macOS System Keychain..."

        # Import Root CA (trustRoot = full trust as root CA)
        if import_ca_to_keychain "$ROOT_CA_CERT" "trustRoot"; then
            log_success "[CERT] Root CA imported to macOS Keychain"
        else
            log_warn "[CERT] Failed to import Root CA to Keychain (may require admin password)"
        fi

        # Import Intermediate CA (trustAsRoot = trust as intermediate CA)
        if import_ca_to_keychain "$INT_CA_CERT" "trustAsRoot"; then
            log_success "[CERT] Intermediate CA imported to macOS Keychain"
        else
            log_warn "[CERT] Failed to import Intermediate CA to Keychain (may require admin password)"
        fi

        log_info "[CERT] Certificates are now trusted system-wide on this Mac"
        log_info "[CERT] Temp certificate directory: $CERT_ROOT"
        log_info "[CERT] Run 'cleanup_macos_cert_temp_dir' to remove temp files after verification"
    fi
fi

# TODO: Add logic for Intermediate CA, fullchain generation, and distribution to UDM Pro, UNAS Pro, etc.
# TODO: Export trusted certs to NFS for client installation (Windows/iOS/macOS)
# TODO: Auto import into Windows Trusted Root CA store when we jump back to Windows. Let ansible handle this?
log_phase "$PHASE_NAME" "complete" "🔑" "$PHASE_DESC"
