#!/bin/bash

# ───────────────────────────────────────────────────────────────
# FusionCloudX Ephemeral Bootstrap Script
# This script sets up the local environment, validates components,
# then orchestrates provisioning, config, and teardown.
# ───────────────────────────────────────────────────────────────

set -euo pipefail

# ─── Check Shell ────────────────────────────────────────────────
if [ -z "${BASH_VERSION:-}" ]; then
  echo "[ERROR] Please run this script using Bash (not sh or zsh)."
  exit 1
fi

# ─── Welcome ─────────────────────────────────────────────────────
echo "╭───────────────────────────────────────────────╮"
echo "│  🧱 FusionCloudX Bootstrap: Getting Started... │"
echo "╰───────────────────────────────────────────────╯"
echo

# ─── Logging Setup ──────────────────────────────────────────────
LOG_FILE="logs/bootstrap.log"
mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo "[INFO] Logging to $LOG_FILE"
echo "[INFO] Script PID: $$"
