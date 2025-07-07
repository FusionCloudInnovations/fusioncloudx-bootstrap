#!/usr/bin/env bash
set -euo pipefail

source modules/logging.sh
source modules/notify.sh

# Accepts optional status as first argument (default: success)
PIPELINE_STATUS="${1:-success}"
send_notification "FusionCloudX pipeline notification" "$PIPELINE_STATUS"