#!/usr/bin/env bash
set -euo pipefail

: "${SILENT:=0}"   # default to not silent
: "${DEBUG:=0}"    # default to not verbose


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
  [[ "$SILENT" -eq 0 ]] && printf "%s${BLUE}[INFO]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_success() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  [[ "$SILENT" -eq 0 ]] && printf "%s${GREEN}[SUCCESS]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_warn() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  [[ "$SILENT" -eq 0 ]] && printf "%s${YELLOW}[WARN]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE"
}

log_error() {
  local message="$1"
  local timestamp="[$(date '+%Y-%m-%d %H:%M:%S')]"
  printf "%s${RED}[ERROR]${NC} %s\n" "$timestamp" "$message" | tee -a "$LOG_FILE" >&2
}

log_debug()   { [[ "$DEBUG" -eq 1 ]] && echo -e "${YELLOW}[DEBUG]${NC}   $1"; }

log_phase() {
  local phase="$1"
  local status="$2"

  if [[ "DEBUG" -eq 1 && -z "$status" ]]; then
    log_error "[DEBUG] log_phase called without status argument for phase: $phase"
    return 1
  fi
  
  case "$status" in
    start)    log_info    "[BOOTSTRAP] Starting phase: $phase";;
    skip)     log_warn    "[BOOTSTRAP] Skipping already-run phase: $phase";;
    complete) log_success "[BOOTSTRAP] $phase completed successfully.";;
    fail)     log_error   "[BOOTSTRAP] $phase failed:";;
    *)        log_error   "[BOOTSTRAP] Phase $phase: status = $status";
  esac
}
