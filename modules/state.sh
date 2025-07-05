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