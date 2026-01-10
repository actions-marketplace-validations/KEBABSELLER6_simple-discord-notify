#!/bin/bash
set -e

# Escape special characters for JSON
escape_json() {
  echo "$1" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g' | awk '{printf "%s\\n", $0}' | sed 's/\\n$//'
}

# Resolve color: explicit color takes priority, otherwise derive from status
if [ -z "$COLOR" ]; then
  case "$STATUS" in
    success) COLOR=3066993 ;;   # Green
    failure) COLOR=15158332 ;;  # Red
    cancelled) COLOR=9807270 ;; # Grey
    *) COLOR=3447003 ;;         # Blue (default/info)
  esac
fi

TITLE_ESCAPED=$(escape_json "$TITLE")
MESSAGE_ESCAPED=$(escape_json "$MESSAGE")

# Build payload based on layout
case "$LAYOUT" in
  minimal)
    PAYLOAD=$(cat <<EOF
{
  "username": "$USERNAME",
  "avatar_url": "$AVATAR_URL",
  "embeds": [{
    "title": "$TITLE_ESCAPED",
    "color": $COLOR
  }]
}
EOF
)
    ;;

  standard)
    PAYLOAD=$(cat <<EOF
{
  "username": "$USERNAME",
  "avatar_url": "$AVATAR_URL",
  "embeds": [{
    "title": "$TITLE_ESCAPED",
    "description": "$MESSAGE_ESCAPED",
    "color": $COLOR,
    "footer": {
      "text": "$GITHUB_REPOSITORY | $GITHUB_WORKFLOW"
    },
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }]
}
EOF
)
    ;;

  detailed)
    PAYLOAD=$(cat <<EOF
{
  "username": "$USERNAME",
  "avatar_url": "$AVATAR_URL",
  "embeds": [{
    "title": "$TITLE_ESCAPED",
    "description": "$MESSAGE_ESCAPED",
    "color": $COLOR,
    "fields": [
      {
        "name": "Repository",
        "value": "[$GITHUB_REPOSITORY]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY)",
        "inline": true
      },
      {
        "name": "Branch",
        "value": "\`$GITHUB_REF_NAME\`",
        "inline": true
      },
      {
        "name": "Triggered by",
        "value": "$GITHUB_ACTOR",
        "inline": true
      },
      {
        "name": "Workflow",
        "value": "$GITHUB_WORKFLOW",
        "inline": true
      },
      {
        "name": "Run",
        "value": "[#$GITHUB_RUN_NUMBER]($GITHUB_SERVER_URL/$GITHUB_REPOSITORY/actions/runs/$GITHUB_RUN_ID)",
        "inline": true
      },
      {
        "name": "Event",
        "value": "\`$GITHUB_EVENT_NAME\`",
        "inline": true
      }
    ],
    "footer": {
      "text": "Commit: $GITHUB_SHA"
    },
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }]
}
EOF
)
    ;;

  *)
    echo "::error::Unknown layout: $LAYOUT"
    exit 1
    ;;
esac

# Send to Discord
curl -X POST "$WEBHOOK_URL" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  --fail --silent --show-error

echo "::notice::Discord notification sent successfully!"
