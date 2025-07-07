#!/usr/bin/env bash

# Create required directories
mkdir -p logs state

# Export core vars
export BOOTSTRAP_VERSION="1.0.0"
export ENV_FILE=".env"

# Validate shell
[ -z "${BASH_VERSION:-}" ] && { log_bootstrap "[ERROR] Must run with Bash"; exit 1; }

# Load environment variables
[ -f "$ENV_FILE" ] && source "$ENV_FILE"
[ -f "config/variables.env" ] && source "config/variables.env"

log_success "[INIT] Bootstrap environment ready"

