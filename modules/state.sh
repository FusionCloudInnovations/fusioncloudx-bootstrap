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
