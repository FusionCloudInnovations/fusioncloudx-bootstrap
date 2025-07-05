#!/usr/bin/env bash
# This phase will signal the main script to exit cleanly
touch state/stop_bootstrap
echo "[EXIT-PHASE] Created stop marker to exit bootstrap."
exit 0
