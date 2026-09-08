#!/usr/bin/env bash
# Send a Telegram notification when IB Gateway needs 2FA input.
# Triggered by IBC log line "Enter SMS Authentication Code; event=Opened".

set -euo pipefail

ENV_FILE="/home/qp/.hermes/profiles/bune/.env"
LOG_FILE="/home/qp/ibc/logs/ibc-3.24.2_GATEWAY-1045_Sunday.txt"

# load telegram creds (skip lines starting with * or #)
while IFS= read -r line; do
    [[ "$line" =~ ^[*#] ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" == *=* ]] && export "$line"
done < "$ENV_FILE"

# Skip if no creds
[[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_HOME_CHANNEL:-}" ]] && exit 0

MSG="⚠️ IB Gateway needs 2FA on the Pi (port 4001). Approve on IBKR Mobile app, or send a fresh SMS code. Restart: systemctl --user restart ibgateway.service"

curl -fsS --max-time 10 \
  -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_HOME_CHANNEL}" \
  -d text="${MSG}" \
  -d parse_mode=Markdown \
  >/dev/null || echo "$(date -Is) telegram notify failed" >&2

exit 0
