#!/usr/bin/env bash
set -euo pipefail

# Source shared logging
source "$(dirname "$0")/../../modules/logging.sh"


log_phase "[PRECHECK] Running pre-checks for FusionCloudX bootstrap..."