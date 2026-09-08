# ib-gateway-helpers

Drop-in scripts for running **Interactive Brokers Gateway** headlessly on Linux
with [IBC](https://github.com/IbcAlpha/IBC).

Solves three problems you hit the moment you try to automate IB Gateway:

1. **2FA entry from a script.** `inject_sms.py` types a 6-digit SMS code into
   the X11 dialog using `xdotool`. No VNC round-trip needed.
2. **Post-auth verification that actually works.** `verify_after_auth.py`
   uses the official `ibapi` package — `ib_insync` (the popular wrapper)
   has a known incompatibility with IB Gateway where no events fire after
   `connect()`. See [`docs/IBAPI_VS_IBINSYNC.md`](docs/IBAPI_VS_IBINSYNC.md).
3. **Notification when the gateway is stuck at the 2FA prompt.**
   `notify_2fa_watch.sh` tails the IBC log and pings you on Telegram the
   moment the SMS dialog opens.

Also includes:

- A patched `commandsend.sh` (the upstream one uses `telnet`, which isn't
  installed on most modern Linux distros; this one uses `nc` and accepts a
  second argument for `SECURITY_CODE`).
- Sample `systemd` units that survive Gateway crashes and re-prompt for 2FA.
- Working examples of `IBC config.ini` and `IB Gateway jts.ini`.

## What's NOT in here

- The IB Gateway binary itself (proprietary; download from IBKR).
- IBC (fetch from the upstream repo).
- Xvfb, x11vnc, xdotool — install via your distro's package manager.
- Any credentials. The examples use placeholders.

## Install (5 minutes)

```bash
# 1. Install dependencies (Debian/Ubuntu; adapt for your distro)
sudo apt install -y xdotool x11vnc jq netcat-openbsd

# 2. Python client library
pip3 install --user ibapi

# 3. Copy scripts
sudo cp scripts/* /usr/local/bin/
sudo chmod +x /usr/local/bin/{inject_sms.py,verify_after_auth.py,probe_handshake.py,diag_api.py,enable_api.sh,notify_2fa_watch.sh,notify_2fa_needed.sh,commandsend.sh}

# 4. (Optional) Install systemd units
mkdir -p ~/.config/systemd/user
cp systemd/*.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ibgateway.service ibc-2fa-notify.service
```

See [`docs/`](docs/) for the full setup including the IBC `config.ini` knobs
that matter (notably `SecondFactorAuthenticationExitInterval` — the upstream
default of 60s is too tight for human-in-the-loop 2FA entry).

## Quick start after install

```bash
# Start the gateway
systemctl --user start ibgateway.service

# When the SMS dialog opens (you'll get a Telegram ping), inject a code:
inject_sms.py 123456

# Verify the API came up:
verify_after_auth.py
# PASS [1/4]: port 4001 listening
# PASS [2/4]: TCP connected, reader thread alive
# PASS [3/4]: nextValidId=1 (session live)
# PASS [4/4]: 1 account(s): ['U…']
# ✅ ALL CHECKS PASSED — IB Gateway API is live and serving
```

## Files

| File | Purpose |
|---|---|
| `scripts/inject_sms.py` | xdotool-based 2FA SMS code injector |
| `scripts/verify_after_auth.py` | post-auth verification (uses `ibapi`) |
| `scripts/probe_handshake.py` | single-shot handshake probe |
| `scripts/diag_api.py` | verbose event-listener diagnostic |
| `scripts/enable_api.sh` | drives IBC's ENABLEAPI task (TWS only) |
| `scripts/notify_2fa_watch.sh` | tails IBC log, fires on SMS dialog |
| `scripts/notify_2fa_needed.sh` | sends the Telegram ping |
| `scripts/commandsend.sh` | patched IBC command sender (nc + SECURITY_CODE) |
| `systemd/ibgateway.service` | Gateway unit (auto-restart, journal logs) |
| `systemd/ibc-2fa-notify.service` | 2FA watcher unit |
| `examples/config.ini` | IBC config (no creds) |
| `examples/jts.ini.example` | IB Gateway jts.ini (no creds) |
| `docs/IBGATEWAY_PORT_REDIRECT.md` | the `cdc1.ibllc.com` redirect |
| `docs/IBC_CONFIG_KNOBS.md` | the IBC knobs that matter |
| `docs/IBAPI_VS_IBINSYNC.md` | upstream bug we found |

## Security note on `inject_sms.py`

This script types a 2FA code into the X11 dialog **without confirmation**.
Don't run it with arbitrary input. Always require a 6-digit numeric code
(validated), and gate usage on the actual presence of the SMS dialog
(also validated). The script refuses to do anything if the dialog isn't
found.

## License

MIT — see [`LICENSE`](LICENSE).
