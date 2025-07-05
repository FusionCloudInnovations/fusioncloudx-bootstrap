#!/bin/bash

# ───────────────────────────────────────────────────────────────
# FusionCloudX Ephemeral Bootstrap Script
# This script sets up the local environment, validates components,
# then orchestrates provisioning, config, and teardown.
# ───────────────────────────────────────────────────────────────

source modules/init.sh
source modules/logging.sh
source modules/state.sh

echo "[BOOTSTRAP] Modules loaded, beginning bootstrap sequence..."
