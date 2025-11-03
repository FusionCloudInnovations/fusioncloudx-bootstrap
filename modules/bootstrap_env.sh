
#!/usr/bin/env bash
# ------------------------------------------------------------------------------
# FusionCloudX Bootstrap Environment Loader
#
# Loads all config from YAML (config/bootstrap.yaml) and secrets from .env.secrets.
# Exports as [CATEGORY]_[VAR] (uppercase). Handles booleans, quoting, arrays.
# Source this ONCE at the top of bootstrap.sh after precheck.
# ------------------------------------------------------------------------------

set -euo pipefail
source modules/logging.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && cd .. && pwd)"
YAML_CONFIG="$PROJECT_ROOT/config/bootstrap.yaml"
log_info "[BOOTSTRAP_ENV] Script Dir: $SCRIPT_DIR"
log_info "[BOOTSTRAP_ENV] Project Root: $PROJECT_ROOT"
log_info "[BOOTSTRAP_ENV] YAML Config: $YAML_CONFIG"

# Load all top-level map keys as [CATEGORY]_[VAR] env vars
log_info "[BOOTSTRAP_ENV] Loading bootstrap environment from $YAML_CONFIG"

if [[ -f "$YAML_CONFIG" ]]; then
    log_info "[BOOTSTRAP_ENV] Generating environment file from YAML"

    # Use the Python generator to create a shell fragment with export statements.
    # The generator prints to stdout; we atomically install to /etc/profile.d/fusioncloudx.sh
    TMPFILE="$(mktemp)"
    if command -v python3 &>/dev/null; then
        if python3 -c 'import yaml' 2>/dev/null; then
            python3 "${SCRIPT_DIR}/generate_env_sh.py" "$YAML_CONFIG" > "$TMPFILE"
        else
            log_info "[BOOTSTRAP_ENV] python3-yaml not found; attempting to install via apt"
            if command -v apt-get &>/dev/null; then
                sudo apt-get update -qq && sudo apt-get install -y -qq python3-yaml
                python3 "${SCRIPT_DIR}/generate_env_sh.py" "$YAML_CONFIG" > "$TMPFILE"
            else
                log_error "[BOOTSTRAP_ENV] Cannot install python3-yaml; apt-get not available"
                rm -f "$TMPFILE"
                exit 1
            fi
        fi
    else
        log_error "[BOOTSTRAP_ENV] python3 is required to generate env file from YAML"
        rm -f "$TMPFILE"
        exit 1
    fi

    # Install the generated file to /etc/profile.d; use sudo if necessary
    DEST="/etc/profile.d/fusioncloudx.sh"
    if mv "$TMPFILE" "$DEST" 2>/dev/null; then
        sudo chmod 644 "$DEST" 2>/dev/null || true
        log_info "[BOOTSTRAP_ENV] Written environment exports to $DEST"
    else
        # Try with sudo move
        sudo mv -f "$TMPFILE" "$DEST"
        sudo chmod 644 "$DEST"
        log_info "[BOOTSTRAP_ENV] Written environment exports to $DEST (via sudo)"
    fi

    # Source the generated file into the current shell so variables are immediately available
    if [[ -f "$DEST" ]]; then
        # shellcheck disable=SC1090
        source "$DEST"
        log_info "[BOOTSTRAP_ENV] Sourced $DEST into current shell"
    fi
else
    log_error "[BOOTSTRAP_ENV] YAML config missing; cannot load bootstrap environment"
    exit 1
fi

# Load .env.secrets if present (for secrets only, auto-export)
SECRETS_FILE="$PROJECT_ROOT/.env.secrets"
if [[ -f "$SECRETS_FILE" ]]; then
    set -a
    source "$SECRETS_FILE"
    set +a
fi

