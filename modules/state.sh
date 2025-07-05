#!/usr/bin/env bash

# ───────────────────────────────────────────────
# State Management Module
# Tracks phase executions and runtime state
# ───────────────────────────────────────────────

mkdir -p state

# Create file to track which phases have run
RAN_FILE="state/ran_phases.txt"
touch "$RAN_FILE"

echo "[STATE] Initialized runtime state at $RAN_FILE"

function mark_phase_as_run() {
    local phase_name="$1"

    if [[ -z "$phase_name" ]]; then
        echo "[ERROR] Phase name cannot be empty"
        return 1
    fi

    grep -qxF "$phase_name" "RAN_FILE" || echo "$phase_name" >> "$RAN_FILE"
    echo "[STATE] Marked phase '$phase_name' as run"
}