#!/usr/bin/env bash

# send_notification "Bootstrap completed successfully"
send_notification() {
    local message="${1:-}"
    local status="${2:-success}"
    local slack_webhook_url="${SLACK_WEBHOOK_URL:-}"
    local hostname=$(hostname)
    local project_name="${PROJECT_NAME:-FusionCloudX Provisioning}"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    # If no webhook, just log and return
    if [[ -z "$slack_webhook_url" ]]; then
        log_warn "[NOTIFY] SLACK_WEBHOOK_URL is not set. Unable to send notification."
        return 0
    fi

    # Prepare Slack payload
    local payload=$(cat <<EOF
{
  "text": "*$project_name* - Provisioning Status",
  "attachments": [
    {
      "fallback": "Provisioning status for $project_name",
      "color": "$status",
      "title": "Provisioning Status for $project_name",
      "fields": [
        {
          "title": "Status",
          "value": "${status^}",
          "short": true
        },
        {
          "title": "Hostname",
          "value": "$hostname",
          "short": true
        },
        {
          "title": "Timestamp",
          "value": "$timestamp",
          "short": true
        }
      ],
      "footer": "FusionCloudX Provisioning",
      "footer_icon": "https://example.com/icon.png"
    }
  ]
}
EOF
)

    # Send Slack notification
    local response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$slack_webhook_url" \
      -H "Content-Type: application/json" \
      -d "$payload")

    if [[ "$response" -eq 200 ]]; then
        log_bootstrap "[NOTIFY] Slack notification sent successfully"
    else
        log_bootstrap "[NOTIFY] Failed to send Slack notification. HTTP status code: $response"
        return 1
    fi
}
