#!/usr/bin/env bash

# Create required directories
mkdir -p logs state


# Export core vars (if needed, move to YAML)
export BOOTSTRAP_VERSION="1.0.0"

# Validate shell
[ -z "${BASH_VERSION:-}" ] && { log_bootstrap "[ERROR] Must run with Bash"; exit 1; }

log_success "[INIT] Bootstrap environment ready"

