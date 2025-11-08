# Find a better way to track state. Maybe DB? But this is meant for
# Disaster Recovery, I want to keep it slim so a DB doesn't have to
# be installed since a VM may not be available after total failure
# since this is the first script that runs to rebuild the entire
# infrastructure and environments. And maybe txt file is just fine for
# this application. Notes may fail in this file though.

#!/usr/bin/env bash
set -euo pipefail

# Load logging if not already sourced
source modules/logging.sh
source modules/notify.sh

STATE_FILE="state/ran_phases.txt"
mkdir -p "$(dirname "$STATE_FILE")"
touch "$STATE_FILE"
log_info "[STATE] Initialized runtime state at $STATE_FILE"

mark_phase_as_run() {
    local phase_name="$1"

    if [[ -z "$phase_name" ]]; then
        log_error "[STATE] Phase name cannot be empty"
        return 1
    fi

    if phase_already_run "$phase_name"; then
        log_info "[STATE] Phase '$phase_name' already marked as run"
        return 0
    fi

    echo "$phase_name" >> "$STATE_FILE"
    log_success "[STATE] Marked phase '$phase_name' as run"
}

phase_already_run() {
    local phase_name="$1"
    grep -Fxq "$phase_name" "$STATE_FILE"
}

on_exit() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        log_error "[FATAL] An unexpected error occurred. Exiting with code $exit_code"
    else
        log_info "[EXIT] Script execution completed."
    fi
    exit $exit_code
}

on_sigint() {
    log_warn "[INTERRUPT] Caught SIGINT (Ctrl+C). Exiting gracefully."
    exit 130
}

on_error() {
    local exit_code=$?
    log_error "[ERROR] An error occurred on line $LINENO. Exit code: $exit_code"
    exit $exit_code
}

finalize_bootstrap_status() {
    if [[ $BOOTSTRAP_SUCCESS -eq 1 ]]; then
        log_success "[NOTIFY] ✅ FusionCloudX Bootstrapping complete"
        send_notification "✅ FusionCloudX Bootstrapping complete"
    else
        log_error "[NOTIFY] ❌ FusionCloudX Bootstrapping did not complete successfully."
    fi
}


trap on_exit EXIT
trap on_sigint INT
trap on_error ERR
