#!/usr/bin/env bash
# Watch the IBC log for a live second-factor prompt and send a Telegram ping.
#
# IB Gateway uses one dialog for both factors:
#   app auth -> "Second Factor Authentication initiated"
#   SMS      -> "Enter SMS Authentication Code; event=Opened"
# Either line means IBKR is waiting on you right now.
#
# A gateway that is retrying can open a prompt every few seconds, so
# notifications are rate-limited by a cooldown rather than once-per-log.
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
LOG_DIR="${IBGW_LOG_DIR:-$HOME/ibc/logs}"
NOTIFY_BIN="${IBGW_NOTIFY_BIN:-$HOME/ibc/notify_2fa_needed.sh}"
LOG_PATTERN="${IBGW_LOG_PATTERN:-ibc-*_GATEWAY-*_*.txt}"
COOLDOWN="${IBGW_NOTIFY_COOLDOWN:-120}"
# load telegram creds (skip lines starting with * or #)
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line; do
    case "$line" in
      \#*|*"*"*) continue ;;
      *=*) export "$line" ;;
    esac
  done < "$ENV_FILE"
fi

# Path of the most recent gateway log, empty while the gateway has not started.
get_log() {
  ls -t "${LOG_DIR}"/${LOG_PATTERN} 2>/dev/null | head -1
}
LOG=""
while [[ -z "$LOG" ]]; do
  LOG="$(get_log)"
  [[ -n "$LOG" ]] && break
  echo "no gateway log in $LOG_DIR yet, retrying in 30s"
  sleep 30
done
echo "watching $LOG (cooldown ${COOLDOWN}s)"

last_notified=0
tail -F -n 0 "$LOG" | while read -r line; do
  case "$line" in
    *"Second Factor Authentication initiated"*|*"Enter SMS Authentication Code; event=Opened"*)
      now=$(date +%s)
      if (( now - last_notified >= COOLDOWN )); then
        last_notified=$now
        echo "$(date -Is) second-factor prompt open, notifying"
        "$NOTIFY_BIN" &
      fi
      ;;
  esac
done
