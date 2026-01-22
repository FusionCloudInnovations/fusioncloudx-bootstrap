source modules/logging.sh
source modules/platform.sh

check_op_vault_access() {
    local vault="$1"
    # Quick sanity: is the token present in this shell?
    if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
        local profile_file
        profile_file="$(get_profile_file)"
        log_warn "[1Password] OP_SERVICE_ACCOUNT_TOKEN is not set in this shell. Attempting to source $profile_file (if present) and retry."
        if [[ -f "$profile_file" ]]; then
            # shellcheck disable=SC1090
            source "$profile_file" || true
            log_info "[1Password] Sourced $profile_file"
        fi
    fi

    if [[ -z "${OP_SERVICE_ACCOUNT_TOKEN:-}" ]]; then
        log_error "[1Password] OP_SERVICE_ACCOUNT_TOKEN is not set (user=$(id -un) uid=$(id -u))."
        log_error "[1Password] If running under sudo, sudo may be dropping environment variables. Use 'sudo -E' or add OP_SERVICE_ACCOUNT_TOKEN to sudoers env_keep."
        exit 1
    fi

    # Mask token length for diagnostics (do not print token value)
    log_info "[1Password] OP_SERVICE_ACCOUNT_TOKEN present (len=${#OP_SERVICE_ACCOUNT_TOKEN}). Attempting vault access..."

    # Run op and capture stderr for better diagnostics if it fails
    local errfile
    errfile="$(mktemp)"
    if ! op vault get "$vault" --format json > /dev/null 2> "$errfile"; then
        log_error "[1Password] Cannot access vault '$vault'. 'op' returned a non-zero exit status."
        log_error "[1Password] op version: $(op --version 2>/dev/null || echo 'op not found')"
        if [[ -s "$errfile" ]]; then
            log_error "[1Password] op stderr:\n$(sed -n '1,200p' "$errfile")"
        fi
        rm -f "$errfile"
        exit 1
    else
        rm -f "$errfile"
        log_info "[1Password] Access to vault '$vault' confirmed."
    fi
}