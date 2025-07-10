source modules/logging.sh

check_op_vault_access() {
    local vault="$1"
    if ! op vault get "$vault" --format json > /dev/null 2>&1; then
        log_error "[1Password] Cannot access vault '$vault'. Please check your OP_SERVICE_ACCOUNT_TOKEN and vault permissions."
        exit 1
    else
        log_info "[1Password] Access to vault '$vault' confirmed."
    fi
}