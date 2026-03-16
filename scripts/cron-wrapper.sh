#!/usr/bin/env bash
# cron-wrapper.sh — wraps a cron command, sends Telegram alert on failure
# Usage: cron-wrapper.sh "script-name" command [args...]

set -o pipefail


SCRIPT_DIR_WOLF="$(cd "$(dirname "$0")" && pwd)"
source "$SCRIPT_DIR_WOLF/lib-wolf.sh" 2>/dev/null || true

SCRIPT_NAME="${1:?Usage: cron-wrapper.sh \"name\" command [args...]}"
shift

ENV_FILE="$HOME/.openclaw/.env"
BOT_TOKEN=$(grep '^TELEGRAM_BOT_TOKEN=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)
CHAT_ID=$(grep '^TELEGRAM_CHAT_ID=' "$ENV_FILE" 2>/dev/null | cut -d= -f2)

# Run the command, capture stderr separately
STDERR_FILE=$(mktemp)
"$@" 2> >(tee "$STDERR_FILE" >&2)
EXIT_CODE=$?

if [ "$EXIT_CODE" -ne 0 ] && [ -n "$BOT_TOKEN" ] && [ -n "$CHAT_ID" ]; then
  TAIL_ERR=$(tail -5 "$STDERR_FILE" 2>/dev/null)
  TIMESTAMP=$(date '+%Y-%m-%d %H:%M:%S')
  MSG=$(cat <<EOF
⚠️ *Cron Failed:* \`${SCRIPT_NAME}\`
*Exit code:* ${EXIT_CODE}
*Time:* ${TIMESTAMP}
\`\`\`
${TAIL_ERR:-no stderr}
\`\`\`
EOF
)
  curl -s -o /dev/null --max-time 10 \
    wolf_notify "$MSG"
fi

rm -f "$STDERR_FILE"
exit "$EXIT_CODE"
