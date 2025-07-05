#!/usr/bin/env bash

# Initialize logs
mkdir -p logs
LOG_FILE="logs/bootstrap-$(date +%Y%m%d_%H%M%S).log"
touch "$LOG_FILE"

# Detect if stdout is a terminal
if [[ -t 1 ]]; then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  BLUE='\033[0;34m'
  BOLD='\033[1m'
  NC='\033[0m' # No Color
else
  RED='' GREEN='' YELLOW='' BLUE='' BOLD='' NC=''
fi

log_bootstrap() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  printf "%s[INFO] %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_info() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  printf "%s${BLUE}[INFO]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_success() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  printf "%s${GREEN}[SUCCESS]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_warn() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  printf "%s${YELLOW}[WARN]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_error() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  printf "%s${RED}[ERROR]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE" >&2
}

# Print startup banner
log_bootstrap "╭───────────────────────────────────────────────╮"
log_bootstrap "│  🧱 FusionCloudX Bootstrap: Getting Started... │"
log_bootstrap "╰───────────────────────────────────────────────╯"
printf "\n"
