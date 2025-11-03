#!/usr/bin/env bash
set -euo pipefail
source modules/logging.sh

# 🔁 Log Rotater - FusionCloud X
# Removes old bootstrap logs beyond the rentention policy

MAX_LOGS=10
AGE_LIMIT_DAYS=30
DRY_RUN=false
LOG_DIR="logs"

for arg in "$@"; do
    case "$arg" in
        --dry-run) DRY_RUN=true ;;
        --max-logs=*) MAX_LOGS="${arg#*=}" ;;
        --age-limit=*) AGE_LIMIT_DAYS="${arg#*=}" ;;
        *) echo "Unknown argument: $arg"; exit 1 ;;
    esac
done

cd "$LOG_DIR" || { echo "Log directory '$LOG_DIR' not found!"; exit 0; }
echo "[LOG ROTATE] 🔁 Cleaning up logs in $LOG_DIR"

# Remove logs older than the age limit
find . -type f -name 'bootstrap-*.log' -mtime +"$AGE_LIMIT_DAYS" -print0 | while IFS= read -r -d '' file; do
    if [[ "$DRY_RUN" == true ]]; then
        echo "[LOG ROTATE] [DRY RUN] Would remove: $file"
    else
        echo "[LOG ROTATE] Removing old log: $file"
        rm -f "$file"
    fi
done

# Remove excess logs beyond the max count
log_files=($(ls -1t bootstrap-*.log 2>/dev/null))
count=${#log_files[@]}

if (( count > MAX_LOGS )); then
    excess_count=$((count - MAX_LOGS))
    echo "[LOG ROTATE] Removing $excess_count excess logs (keeping latest $MAX_LOGS)"
    for (( i = MAX_LOGS; i < count; i++ )); do
        if [[ "$DRY_RUN" == true ]]; then
            echo "[LOG ROTATE] [DRY RUN] Would remove: ${log_files[i]}"
        else
            echo "[LOG ROTATE] Removing excess log: ${log_files[i]}"
            rm -f "${log_files[i]}"
        fi
    done
else
    echo "[LOG ROTATE] No excess logs to remove. Current count: $count"
fi

log_phase "Log Rotation" "complete" "🔁" "Log rotation completed successfully"
