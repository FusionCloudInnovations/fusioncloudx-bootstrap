#!/usr/bin/env bash
set -euo pipefail

# Load logging if not already sourced
source modules/logging.sh

export RAN_FILE="state/ran_phases.txt"
mkdir -p "$(dirname "$RAN_FILE")"
touch "$RAN_FILE"
log_info "[STATE] Initialized runtime state at $RAN_FILE"

mark_phase_as_run() {
    local phase_name="$1"

    if [[ -z "$phase_name" ]]; then
        log_error "[STATE] Phase name cannot be empty"
        return 1
    fi

    echo "$phase_name" >> "$RAN_FILE"
    log_success "[STATE] Marked phase '$phase_name' as run"
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

trap on_exit EXIT
trap on_sigint INT
trap on_error ERR
