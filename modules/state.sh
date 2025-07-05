#!/usr/bin/env bash
set -euo pipefail

export RAN_FILE="state/ran_phases.txt"
mkdir -p "$(dirname "$RAN_FILE")"
touch "$RAN_FILE"
echo "[STATE] Initialized runtime state at $RAN_FILE"

function mark_phase_as_run() {
    local phase_name="$1"
    
    if [[ -z "$phase_name" ]]; then
        echo "[ERROR] Phase name cannot be empty"
        return 1
    fi

    echo "$phase_name" >> "$RAN_FILE"
    echo "[STATE] Marked phase '$phase_name' as run"
}

trap_handler() {
    local exit_code=$?
    if [[ $exit_code -ne 0 ]]; then
        echo "[FATAL] An unexpected error occurred. Exiting with code $exit_code" >&2
    fi
    exit $exit_code
}

on_sigint() {
    echo "[INTERRUPT] Caught SIGINT (Ctrl+C). Exiting gracefully."
    exit 130
}

on_error() {
    local exit_code=$?
    echo "[ERROR] An error occurred on line $LINENO. Exit code: $exit_code"
    exit $exit_code
}

on_exit() {
    echo "[EXIT] Script execution completed."
}

trap trap_handler EXIT
trap on_sigint INT
trap on_error ERR
trap on_exit EXIT