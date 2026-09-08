#!/usr/bin/env bash
# Send a Telegram notification when IB Gateway needs 2FA input.
# Triggered by IBC log line "Enter SMS Authentication Code; event=Opened".

set -euo pipefail

ENV_FILE_CANDIDATES=(
  "$HOME/.config/ib-gateway-helpers/telegram.env"
  "$HOME/.hermes/profiles/$(cat "$HOME/.hermes/active_profile" 2>/dev/null || echo default)/.env"
)
for f in "${ENV_FILE_CANDIDATES[@]}"; do
  if [[ -f "$f" ]]; then
    ENV_FILE="$f"
    break
  fi
done
ENV_FILE="${ENV_FILE:-${ENV_FILE_CANDIDATES[0]}}"

# load telegram creds (skip lines starting with * or #)
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line; do
    [[ "$line" =~ ^[*#] ]] && continue
    [[ -z "$line" ]] && continue
    [[ "$line" == *=* ]] && export "$line"
  done < "$ENV_FILE"
fi

# Skip if no creds
[[ -z "${TELEGRAM_BOT_TOKEN:-}" || -z "${TELEGRAM_HOME_CHANNEL:-}" ]] && exit 0

MSG="⚠️ IB Gateway needs 2FA on the Pi (port 4001). Approve on IBKR Mobile app, or send a fresh SMS code. Restart: systemctl --user restart ibgateway.service"

curl -fsS --max-time 10 \
  -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_HOME_CHANNEL}" \
  -d text="${MSG}" \
  -d parse_mode="HTML" \
  >/dev/null || echo "$(date -Is) telegram notify failed" >&2

exit 0
