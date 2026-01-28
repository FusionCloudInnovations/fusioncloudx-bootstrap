#!/usr/bin/env bash
# Test script to verify RFC 5280 certificate compliance
# This script validates that all generated certificates have proper X.509v3 extensions

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}RFC 5280 Certificate Compliance Validator${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Function to check certificate extensions
check_cert_extensions() {
    local cert_path="$1"
    local cert_type="$2"
    local required_extensions=()
    
    echo -e "\n${BLUE}Validating $cert_type: $cert_path${NC}"
    
    if [[ ! -f "$cert_path" ]]; then
        echo -e "${RED}✗ Certificate file not found: $cert_path${NC}"
        return 1
    fi
    
    # Extract and display all X509v3 extensions
    local cert_text
    cert_text=$(openssl x509 -in "$cert_path" -text -noout)
    
    echo -e "${YELLOW}Extensions found:${NC}"
    echo "$cert_text" | grep -A 20 "X509v3 extensions" || {
        echo -e "${RED}✗ No X509v3 extensions found!${NC}"
        return 1
    }
    
    # Check for specific extensions based on certificate type
    case "$cert_type" in
        "Root CA")
            required_extensions=(
                "Basic Constraints: critical"
                "CA:TRUE"
                "Key Usage: critical"
                "Subject Key Identifier"
            )
            ;;
        "Intermediate CA")
            required_extensions=(
                "Basic Constraints: critical"
                "CA:TRUE"
                "pathLenConstraint=0"
                "Key Usage: critical"
                "Subject Key Identifier"
                "Authority Key Identifier"
            )
            ;;
        "Server Certificate")
            required_extensions=(
                "Basic Constraints"
                "CA:FALSE"
                "Key Usage: critical"
                "Extended Key Usage"
                "serverAuth"
                "Subject Alternative Name"
                "Subject Key Identifier"
                "Authority Key Identifier"
            )
            ;;
    esac
    
    # Verify required extensions
    local missing_extensions=0
    for ext in "${required_extensions[@]}"; do
        if echo "$cert_text" | grep -q "$ext"; then
            echo -e "${GREEN}✓ Found: $ext${NC}"
        else
            echo -e "${RED}✗ Missing: $ext${NC}"
            missing_extensions=$((missing_extensions + 1))
        fi
    done
    
    if [[ $missing_extensions -eq 0 ]]; then
        echo -e "${GREEN}✓ All required extensions present for $cert_type${NC}"
        return 0
    else
        echo -e "${RED}✗ Missing $missing_extensions required extensions for $cert_type${NC}"
        return 1
    fi
}

# Get certificate paths
CERT_ROOT="${CERT_ROOT:-$(mktemp -d -t certificates)}"
if [[ ! -d "$CERT_ROOT" ]]; then
    echo -e "${RED}Error: Certificate directory not found at $CERT_ROOT${NC}"
    exit 1
fi

PRIVATE_DIR="$CERT_ROOT/private"
INT_DIR="$CERT_ROOT/intermediate"
CERTS_DIR="$CERT_ROOT/issued"

ROOT_CA_CERT="$PRIVATE_DIR/root-ca.pem"
INT_CA_CERT="$INT_DIR/intermediate-ca.pem"
CERT_PEM="$CERTS_DIR/cert.pem"
FULLCHAIN_PEM="$CERTS_DIR/fullchain.pem"

echo -e "\n${BLUE}Certificate Root Directory:${NC} $CERT_ROOT"
echo -e "${BLUE}Looking for certificates:${NC}"
echo "  - Root CA: $ROOT_CA_CERT"
echo "  - Intermediate CA: $INT_CA_CERT"
echo "  - Server Cert: $CERT_PEM"
echo "  - Full Chain: $FULLCHAIN_PEM"

# Counters for summary
total_checks=0
passed_checks=0
failed_checks=0

# Check each certificate
for cert_info in \
    "$ROOT_CA_CERT:Root CA" \
    "$INT_CA_CERT:Intermediate CA" \
    "$CERT_PEM:Server Certificate"; do
    
    cert_path="${cert_info%:*}"
    cert_type="${cert_info#*:}"
    
    total_checks=$((total_checks + 1))
    if check_cert_extensions "$cert_path" "$cert_type"; then
        passed_checks=$((passed_checks + 1))
    else
        failed_checks=$((failed_checks + 1))
    fi
done

# Summary
echo -e "\n${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}VALIDATION SUMMARY${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "Total checks: ${total_checks}"
echo -e "Passed: ${GREEN}${passed_checks}${NC}"
echo -e "Failed: ${RED}${failed_checks}${NC}"

if [[ $failed_checks -eq 0 ]]; then
    echo -e "\n${GREEN}✓ All certificates are RFC 5280 compliant!${NC}"
    echo -e "${GREEN}Your macOS browser should now trust these certificates.${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some certificates are not RFC 5280 compliant.${NC}"
    echo -e "${RED}Certificate regeneration may be required.${NC}"
    exit 1
fi
