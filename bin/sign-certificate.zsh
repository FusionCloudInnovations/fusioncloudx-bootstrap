#!/bin/zsh
#
# Certificate Signing Script for Homelab Devices
# Signs CSR using FusionCloudX Intermediate CA from 1Password
#
# Prerequisites:
#   1. Download intermediate-ca.pem from 1Password → ~/Downloads/
#   2. Download intermediate-ca-key.pem from 1Password → ~/Downloads/
#   3. Have device CSR ready
#
# Usage: ./sign-certificate.zsh
#

set -e  # Exit on error

# ============================================================================
# CONFIGURATION - USER FILLS IN THESE VALUES
# ============================================================================

# CA Configuration (from 1Password)
CA_CERT_FILE="${HOME}/Downloads/intermediate-ca.pem"
CA_KEY_FILE="${HOME}/Downloads/intermediate-ca-key.pem"

# Future: Uncomment to use op CLI for automatic download
# OP_VAULT="FusionCloudX"
# OP_ITEM_NAME="FusionCloudX Intermediate CA Bundle"

# Certificate Request
CSR_FILE="${HOME}/Downloads/CertRequest.pem" 
DEVICE_NAME="HP5D765C"                          

# Output Configuration
OUTPUT_DIR="${HOME}/Documents/certificates"  
DEVICE_IP="192.168.40.226"                      
DEVICE_TYPE="HP OfficeJet Pro 9015e"            
CERT_VALIDITY_DAYS=365                          

# ============================================================================
# SCRIPT LOGIC - DO NOT EDIT BELOW THIS LINE
# ============================================================================

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "${GREEN}========================================${NC}"
echo "${GREEN}Certificate Signing Script${NC}"
echo "${GREEN}========================================${NC}"
echo ""

# Validate prerequisites
echo "${YELLOW}[1/7] Validating prerequisites...${NC}"

if ! command -v /opt/homebrew/opt/openssl@1.1/bin/openssl &> /dev/null; then
    echo "${RED}Error: /opt/homebrew/opt/openssl@1.1/bin/openssl not found. Install with: brew install /opt/homebrew/opt/openssl@1.1/bin/openssl${NC}"
    exit 1
fi

if [[ ! -f "$CA_CERT_FILE" ]]; then
    echo "${RED}Error: Intermediate CA certificate not found: $CA_CERT_FILE${NC}"
    echo "${YELLOW}Please download intermediate-ca.pem from 1Password:${NC}"
    echo "  1. Open 1Password"
    echo "  2. Navigate to: FusionCloudX vault"
    echo "  3. Open: 'FusionCloudX Intermediate CA Bundle'"
    echo "  4. Download: intermediate-ca.pem to ~/Downloads/"
    exit 1
fi

if [[ ! -f "$CA_KEY_FILE" ]]; then
    echo "${RED}Error: Intermediate CA private key not found: $CA_KEY_FILE${NC}"
    echo "${YELLOW}Please download intermediate-ca-key.pem from 1Password:${NC}"
    echo "  1. Open 1Password"
    echo "  2. Navigate to: FusionCloudX vault"
    echo "  3. Open: 'FusionCloudX Intermediate CA Bundle'"
    echo "  4. Download: intermediate-ca-key.pem to ~/Downloads/"
    exit 1
fi

if [[ ! -f "$CSR_FILE" ]]; then
    echo "${RED}Error: CSR file not found: $CSR_FILE${NC}"
    exit 1
fi

echo "${GREEN}✓ Prerequisites validated${NC}"
echo ""

# Create output directory
echo "${YELLOW}[2/7] Creating output directory...${NC}"
mkdir -p "$OUTPUT_DIR"
echo "${GREEN}✓ Output directory: $OUTPUT_DIR${NC}"
echo ""

# Copy CA materials to output directory
echo "${YELLOW}[3/7] Copying CA materials from 1Password download location...${NC}"
echo "CA Certificate: $CA_CERT_FILE"
echo "CA Private Key: $CA_KEY_FILE"

cp "$CA_CERT_FILE" "$OUTPUT_DIR/ca-cert.pem" || {
    echo "${RED}Error: Failed to copy CA certificate${NC}"
    exit 1
}

cp "$CA_KEY_FILE" "$OUTPUT_DIR/ca-key.pem" || {
    echo "${RED}Error: Failed to copy CA private key${NC}"
    exit 1
}

chmod 600 "$OUTPUT_DIR/ca-key.pem"
echo "${GREEN}✓ CA materials copied to output directory${NC}"
echo ""

# Future: Uncomment to use op CLI for automatic download
# echo "${YELLOW}[3/7] Downloading CA materials from 1Password...${NC}"
# op read "op://FusionCloudX/FusionCloudX Intermediate CA Bundle/intermediate-ca.pem" > "$OUTPUT_DIR/ca-cert.pem" || {
#     echo "${RED}Error: Failed to download CA certificate from 1Password${NC}"
#     echo "Run: op signin to authenticate"
#     exit 1
# }
# op read "op://FusionCloudX/FusionCloudX Intermediate CA Bundle/intermediate-ca-key.pem" > "$OUTPUT_DIR/ca-key.pem" || {
#     echo "${RED}Error: Failed to download CA private key from 1Password${NC}"
#     exit 1
# }
# chmod 600 "$OUTPUT_DIR/ca-key.pem"
# echo "${GREEN}✓ CA materials downloaded from 1Password${NC}"
# echo ""

# Validate CSR
echo "${YELLOW}[4/7] Validating CSR...${NC}"

# Extract CN from CSR (if this succeeds, CSR is valid enough)
CSR_CN=$(openssl req -in "$CSR_FILE" -noout -subject 2>/dev/null | sed -n 's/^.*CN=\([^,]*\).*$/\1/p')

if [[ -z "$CSR_CN" ]]; then
    echo "${RED}Error: Could not extract Common Name from CSR${NC}"
    echo "CSR file may be corrupted or in wrong format"
    exit 1
fi

echo "CSR Common Name: $CSR_CN"
echo "${GREEN}✓ CSR validated${NC}"
echo ""

# Sign certificate
echo "${YELLOW}[5/7] Signing certificate...${NC}"

# Note: You will be prompted for the CA private key passphrase from 1Password
# Warning messages about CSR verification are normal and can be ignored
set +e  # Don't exit on error - we'll check output file instead
/opt/homebrew/opt/openssl@1.1/bin/openssl x509 -req \
    -in "$CSR_FILE" \
    -CA "$OUTPUT_DIR/ca-cert.pem" \
    -CAkey "$OUTPUT_DIR/ca-key.pem" \
    -CAcreateserial \
    -out "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" \
    -days $CERT_VALIDITY_DAYS \
    -sha256 > /dev/null 2>&1
set -e  # Re-enable exit on error

# Check if certificate was actually created (signing succeeded)
if [[ ! -f "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" ]] || [[ ! -s "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" ]]; then
    echo "${RED}Error: Certificate signing failed${NC}"
    echo "Possible causes:"
    echo "  - CA private key passphrase incorrect"
    echo "  - CA key file corrupted or wrong format"
    echo "  - Insufficient permissions"
    exit 1
fi

echo "${GREEN}✓ Certificate signed successfully${NC}"
echo ""

# Create certificate bundle
echo "${YELLOW}[6/7] Creating certificate bundle...${NC}"

cat "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" "$OUTPUT_DIR/ca-cert.pem" > "$OUTPUT_DIR/${DEVICE_NAME}-bundle.pem"

echo "${GREEN}✓ Certificate bundle created${NC}"
echo ""

# Validate signed certificate
echo "${YELLOW}[7/7] Validating signed certificate...${NC}"

/opt/homebrew/opt/openssl@1.1/bin/openssl verify -CAfile "$OUTPUT_DIR/ca-cert.pem" "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" || {
    echo "${RED}Warning: Certificate validation failed${NC}"
}

echo "${GREEN}✓ Certificate validation complete${NC}"
echo ""

# Display results
echo "${GREEN}========================================${NC}"
echo "${GREEN}Certificate Signing Complete!${NC}"
echo "${GREEN}========================================${NC}"
echo ""
echo "Output files:"
echo "  - ${GREEN}${DEVICE_NAME}-cert.pem${NC}       (Signed certificate)"
echo "  - ${GREEN}${DEVICE_NAME}-bundle.pem${NC}     (Certificate bundle - UPLOAD THIS)"
echo "  - ${GREEN}ca-cert.pem${NC}                   (CA certificate)"
echo "  - ${RED}ca-key.pem${NC}                    (CA private key - DELETE AFTER USE!)"
echo ""
echo "Certificate Details:"
/opt/homebrew/opt/openssl@1.1/bin/openssl x509 -in "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" -noout -subject -issuer -dates
echo ""
echo "${YELLOW}Next Steps:${NC}"
echo "1. Upload certificate bundle to device:"
echo "   - Navigate to: https://$DEVICE_IP"
echo "   - Go to: Settings → Security → Certificate Management"
echo "   - Import: $OUTPUT_DIR/${DEVICE_NAME}-bundle.pem"
echo ""
echo "2. Verify HTTPS access:"
echo "   - Open: https://$DEVICE_IP"
echo "   - Should show secure padlock (no warnings)"
echo ""
echo "3. Set calendar reminder:"
echo "   - Certificate expires: $(/opt/homebrew/opt/openssl@1.1/bin/openssl x509 -in "$OUTPUT_DIR/${DEVICE_NAME}-cert.pem" -noout -enddate | cut -d= -f2)"
echo "   - Reminder 30 days before expiration"
echo ""
echo "4. ${RED}SECURITY: Delete CA private key after use${NC}"
echo "   rm $OUTPUT_DIR/ca-key.pem"
echo ""
read "response?Delete CA private key now? (y/n): "
if [[ "$response" =~ ^[Yy]$ ]]; then
    rm -f "$OUTPUT_DIR/ca-key.pem"
    echo "${GREEN}✓ CA private key deleted${NC}"
else
    echo "${RED}WARNING: CA private key remains on disk!${NC}"
    echo "Delete manually when done: rm $OUTPUT_DIR/ca-key.pem"
fi
echo ""
echo "${GREEN}Certificate signing complete!${NC}"
