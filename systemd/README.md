# systemd units

User-level systemd units for IB Gateway on a Linux box running as a
non-root user. Drop them into `~/.config/systemd/user/` and enable.

## Install

```bash
# Edit the unit files and replace /home/USER with your actual home directory.
sed -i "s|/home/USER|$HOME|g" *.service *.timer

mkdir -p ~/.config/systemd/user
cp *.service *.timer ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ibgateway.service ibc-2fa-notify.service \
  ibc-weekly-reauth.timer ibgw-stop.timer
```

The units reference scripts by absolute path in `~/ibc/`, so stage
`notify_2fa_watch.sh`, `notify_2fa_needed.sh`, `notify_gateway_down.sh` and
`notify_weekly_reauth.sh` there (the repo's `install.sh` does this for you).

## What they do

### `ibgateway.service`

- Starts Xvfb on `:99`, fluxbox window manager, then IBC-driven IB Gateway.
- Only runs while `~/ibc/.trading-week` exists — see the trading week below.
- Restarts always, 30 s delay, max 4 starts per hour (`StartLimitBurst` /
  `StartLimitIntervalSec`, which must live in `[Unit]` for systemd >= 230).
- `OnFailure=ibc-gateway-down-notify.service` alerts when it gives up.
- 5-minute startup timeout (Gateway can be slow to login).
- Logs to `~/ibc/logs/ibc.log` via the unit's `StandardOutput` directives.

### `ibc-2fa-notify.service`

- Watches `~/ibc/logs/ibc-*_GATEWAY-*.txt` for either prompt:
  `Second Factor Authentication initiated` (app-auth push) or
  `Enter SMS Authentication Code; event=Opened` (SMS dialog).
- Sends a Telegram ping via `notify_2fa_needed.sh` (Telegram creds from
  `~/.config/ib-gateway-helpers/telegram.env`, falling back to a Hermes
  profile `.env`). Notifications are rate-limited by
  `IBGW_NOTIFY_COOLDOWN` (default 120 s).
- `RuntimeMaxSec=15min`: IBC rolls its log daily, and the watcher resolves
  the path once at startup, so it is recycled to pick up the current day's
  file.
- Restarts every 10 seconds if it dies.

### `ibc-gateway-down-notify.service`

- Oneshot, triggered by `OnFailure=` on `ibgateway.service`. Sends the
  "gateway gave up after repeated failed starts" Telegram alert; silent if
  no Telegram creds are configured.

### `ibc-weekly-reauth.service` + `ibc-weekly-reauth.timer`

- Timer fires Sunday 12:00 (`Persistent=true`, so a box that was off at noon
  catches up on the next boot).
- The service creates `~/ibc/.trading-week`, starts the gateway, waits for
  the JVM to raise the second-factor prompt, and sends a Telegram status.

### `ibgw-stop.service` + `ibgw-stop.timer`

- Timer fires Friday 20:00 (`Persistent=false`, deliberately: a box that was
  off at 20:00 has no gateway to stop).
- The service stops `ibgateway.service` and then removes
  `~/ibc/.trading-week`, so nothing brings the gateway back up over the
  weekend.

## Trading week

`ibgateway.service` carries `ConditionPathExists=~/ibc/.trading-week` so a
weekend reboot cannot restart a gateway whose login nobody can approve. The
flag is created by `ibc-weekly-reauth` on Sunday and removed by `ibgw-stop`
on Friday. To start the gateway outside that window, create the flag first:

```bash
touch ~/ibc/.trading-week
systemctl --user start ibgateway.service
```

## Required env file

The notifier scripts read Telegram credentials at runtime from a `.env` file,
tried in this order:

1. `~/.config/ib-gateway-helpers/telegram.env`
2. `~/.hermes/profiles/<active_profile>/.env` (Hermes harness users;
   otherwise edit the script to point at your own `.env`)

The `.env` must contain:

```bash
TELEGRAM_BOT_TOKEN=123456:ABCDEF...
TELEGRAM_HOME_CHANNEL=-1001234567890
```

Secrets are never inlined in any unit or script.

## Lingering

User services die when the user logs out. For a true 24/7 setup, enable
lingering:

```bash
sudo loginctl enable-linger $USER
```
