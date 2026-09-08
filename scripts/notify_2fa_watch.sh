#!/usr/bin/env bash
# Watch the IBC log for 2FA prompts and send a Telegram ping (dedup'd to once per prompt).
# Run as a background process; tail -F on the latest log file.

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

# load telegram creds (skip lines starting with * or #)
if [[ -f "$ENV_FILE" ]]; then
  while IFS= read -r line; do
    case "$line" in
      \#*|*"*"*) continue ;;
      *=*) export "$line" ;;
    esac
  done < "$ENV_FILE"
fi

# Find the most recent gateway log file
get_log() {
  ls -t "${LOG_DIR}"/${LOG_PATTERN} 2>/dev/null | head -1
}

last_notified=""
LOG="$(get_log)"
if [[ -z "$LOG" ]]; then
  echo "no log file yet, retrying in 30s"
  sleep 30
  LOG="$(get_log)"
fi

if [[ -n "$LOG" ]]; then
  echo "watching $LOG"
  tail -F -n 0 "$LOG" | while read -r line; do
    if [[ "$line" == *"Enter SMS Authentication Code; event=Opened"* ]]; then
      sig="${LOG}:$(date +%s | cut -c1-8)"
      if [[ "$sig" != "$last_notified" ]]; then
        last_notified="$sig"
        "$NOTIFY_BIN" &
      fi
    fi
  done
fi
