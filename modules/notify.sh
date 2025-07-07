#!/usr/bin/env bash

# send_notification "Bootstrap completed successfully"
send_notification() {
  local message="$1"
  log_bootstrap "[NOTIFY] $message"  # Replace with real logic later
}
