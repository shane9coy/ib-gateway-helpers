#!/usr/bin/env bash
# Fired by ibgateway.service OnFailure: the unit exhausted its start budget
# (StartLimitBurst within StartLimitIntervalSec) and gave up. In practice this
# means it could not authenticate and nobody approved before the budget ran
# out, so it has stopped retrying and is waiting for a human.
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

MSG="🔴 IB Gateway gave up after repeated failed starts and has STOPPED retrying.
Almost always means it needs second-factor approval. Restart it:
  systemctl --user reset-failed ibgateway.service
  systemctl --user start ibgateway.service
Then approve the push in IBKR Mobile. It will not retry on its own until the next scheduled Sunday start."
curl -fsS --max-time 10 \
  -X POST "https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}/sendMessage" \
  -d chat_id="${TELEGRAM_HOME_CHANNEL}" \
  -d text="${MSG}" \
  >/dev/null || echo "$(date -Is) telegram notify failed" >&2
exit 0
