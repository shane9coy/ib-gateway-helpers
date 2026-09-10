#!/usr/bin/env bash
# Sunday trading-week start.
#
# Opens the trading-week window, brings the gateway up, and prompts for the
# weekly IBKR re-auth. IBKR invalidates the session on the Saturday-night
# server reset, so this is the one approval the week needs; the gateway's own
# daily autorestart keeps the session alive from here until Friday.
set -uo pipefail

# ── Configuration ────────────────────────────────────────────────────────────
# Telegram creds: try ~/.config/ib-gateway-helpers/telegram.env first,
# then fall back to ~/.hermes/profiles/<profile>/.env (Hermes harness users).
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
FLAG="${IBGW_TRADING_WEEK_FLAG:-$HOME/ibc/.trading-week}"
API_PORT="${IBGW_API_PORT:-4001}"

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

# Open the window first, otherwise the unit's ConditionPathExists skips the start.
touch "$FLAG"
systemctl --user reset-failed ibgateway.service 2>/dev/null || true
systemctl --user start ibgateway.service
# Give the JVM time to boot and raise the second-factor prompt.
sleep 60
if ss -tln 2>/dev/null | grep -q ":${API_PORT}"; then
    MSG="✅ IBKR trading week is open and the gateway is ALREADY authenticated (port ${API_PORT} listening). No action needed."
elif systemctl --user is-active --quiet ibgateway.service; then
    MSG="🔑 Weekly IBKR re-auth. The gateway is up and waiting on second-factor approval.
Open IBKR Mobile and approve the login push now.
(Session then rides the daily autorestart until Friday 20:00.)"
else
    MSG="🔴 Weekly IBKR re-auth FAILED to start. The gateway is not running.
Run on this host:
  systemctl --user reset-failed ibgateway.service
  systemctl --user start ibgateway.service
Then approve the push in IBKR Mobile."
fi
curl -fsS --max-time 10 \
  -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_HOME_CHANNEL}" \
  -d text="${MSG}" \
  >/dev/null || echo "$(date -Is) telegram notify failed" >&2
exit 0
