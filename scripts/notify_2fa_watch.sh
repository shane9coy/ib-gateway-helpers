#!/usr/bin/env bash
# Watch the IBC log for 2FA prompts and send a Telegram ping (dedup'd to once per prompt).
# Run as a background process; tail -F on the latest log file.

set -uo pipefail

ENV_FILE="/home/qp/.hermes/profiles/bune/.env"
LOG_DIR="/home/qp/ibc/logs"
NOTIFY_BIN="/home/qp/ibc/notify_2fa_needed.sh"

# load telegram creds (skip lines starting with * or #)
while IFS= read -r line; do
    case "$line" in
        \#*|*"*"*) continue ;;
        *=*) export "$line" ;;
    esac
done < "$ENV_FILE"

# Find the most recent gateway log file
get_log() {
    ls -t "${LOG_DIR}"/ibc-3.24.2_GATEWAY-1045_*.txt 2>/dev/null | head -1
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
