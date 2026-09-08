# systemd units

Two user-level systemd units for IB Gateway on a Linux box running as
a non-root user. Drop them into `~/.config/systemd/user/` and enable.

## Install

```bash
# Edit both files and replace /home/USER with your actual home directory.
sed -i "s|/home/USER|$HOME|g" ibgateway.service ibc-2fa-notify.service

mkdir -p ~/.config/systemd/user
cp ibgateway.service ibc-2fa-notify.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ibgateway.service ibc-2fa-notify.service
```

## What they do

### `ibgateway.service`

- Starts Xvfb on `:99`, fluxbox window manager, then IBC-driven IB Gateway.
- Restarts on failure (max 4 times per hour, 5-minute delay).
- 5-minute startup timeout (Gateway can be slow to login).
- Logs to `~/ibc/logs/ibc.log` via the unit's `StandardOutput` directives.

### `ibc-2fa-notify.service`

- Watches `~/ibc/logs/ibc-*.txt` for the line
  `Enter SMS Authentication Code; event=Opened`.
- Sends a Telegram ping via `notify_2fa_needed.sh` (Telegram creds from
  `~/.env`).
- Restarts every 10 seconds if it dies.

## Required env file

`ibc-2fa-notify.service` reads Telegram credentials from a `.env` file
at the path configured in `notify_2fa_watch.sh` (default
`~/.hermes/profiles/<profile>/.env` if you happen to use the Hermes
harness; otherwise edit `notify_2fa_watch.sh` to point at your own
`.env`). The `.env` must contain:

```bash
TELEGRAM_BOT_TOKEN=123456:ABCDEF...
TELEGRAM_HOME_CHANNEL=-1001234567890
```

## Lingering

User services die when the user logs out. For a true 24/7 setup, enable
lingering:

```bash
sudo loginctl enable-linger $USER
```
