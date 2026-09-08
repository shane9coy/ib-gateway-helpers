# ib-gateway-helpers

Drop-in scripts for running **Interactive Brokers Gateway** headlessly on
Linux with [IBC](https://github.com/IbcAlpha/IBC).

> **One-liner for an AI agent:**
> ```bash
> git clone https://github.com/shane9coy/ib-gateway-helpers.git /tmp/ibgw && bash /tmp/ibgw/install.sh
> ```
> That's it. The install script is interactive (asks for IBKR username,
> paper-or-live, where to put files) and produces a running IB Gateway
> with systemd supervision and a Telegram 2FA notifier. See
> [Agent install](#agent-install-one-shot) below.

## What this repo is for

If you've ever tried to automate IB Gateway, you've hit three problems
within the first hour:

1. **2FA entry from a script.** `inject_sms.py` types a 6-digit SMS code
   into the X11 dialog using `xdotool`. No VNC round-trip needed.
2. **Post-auth verification that actually works.** `verify_after_auth.py`
   uses the official `ibapi` package — `ib_insync` (the popular wrapper)
   has a known incompatibility with IB Gateway where no events fire after
   `connect()`. See [`docs/IBAPI_VS_IBINSYNC.md`](docs/IBAPI_VS_IBINSYNC.md).
3. **Notification when the gateway is stuck at the 2FA prompt.**
   `notify_2fa_watch.sh` tails the IBC log and pings you on Telegram the
   moment the SMS dialog opens.

Also included:

- A patched `commandsend.sh` (the upstream one uses `telnet`, which
  isn't installed on most modern Linux distros).
- Sample `systemd` units that survive Gateway crashes and re-prompt for 2FA.
- Working examples of `IBC config.ini` and `IB Gateway jts.ini`.

What's **not** included: the IB Gateway binary (proprietary; download
from IBKR), IBC (fetch from upstream), Xvfb/x11vnc/xdotool (install via
your distro's package manager), or any credentials.

## Agent install (one shot)

For an AI agent or a human following along: paste this single line and
the gateway comes up end-to-end. The script is interactive and asks for
the IBKR username, paper-or-live, Telegram bot token, and chat ID.

```bash
git clone https://github.com/shane9coy/ib-gateway-helpers.git /tmp/ibgw && bash /tmp/ibgw/install.sh
```

### Non-interactive agent install

If your agent needs to drive this without a human in front of it (CI,
sandbox, fresh container), set these env vars and the install script
will skip the interactive prompts:

```bash
export IBGW_USERNAME='shane9coy'
export IBGW_PASSWORD='...'
export IBGW_MODE='live'                  # or 'paper'
export IBGW_TELEGRAM_BOT_TOKEN='...'     # optional
export IBGW_TELEGRAM_CHAT_ID='...'       # optional
export IBGW_NONINTERACTIVE=1

git clone https://github.com/shane9coy/ib-gateway-helpers.git /tmp/ibgw && bash /tmp/ibgw/install.sh
```

The install script will:

1. Verify you're on Linux with `apt` or `dnf`.
2. Install system dependencies (`xvfb`, `x11vnc`, `xdotool`, `fluxbox`,
   `nc`, `jq`, `python3-pip`).
3. `pip install ibapi` (NOT `ib_insync` — see the docs for why).
4. Download IBC and IB Gateway into `/opt/ibc` and `/opt/ibgateway`
   (skipped if already present).
5. Copy scripts to `/usr/local/bin/`.
6. Stage `~/ibc/` with `config.ini`, `credentials.env`, and the
   `run_xvfb_gateway.sh` wrapper, **without** ever committing the
   password to git.
7. Patch `jts.ini` to point at `cdc1.ibllc.com` (the secondary CCp
   gateway, in case the default `ndc1` is firewalled on this network).
8. Install the two systemd units and start them.
9. Print the VNC address, the API port, and the verification command.

If anything goes wrong, the script exits non-zero at the failing step.
Re-run with `--resume` to skip already-completed steps.

## Manual install (5 minutes)

If you want to read each step before running it:

```bash
# 1. System packages (Debian/Ubuntu)
sudo apt install -y xvfb x11vnc xdotool fluxbox jq netcat-openbsd python3-pip

# 2. Python client library
pip3 install --user ibapi

# 3. Copy scripts
sudo cp scripts/* /usr/local/bin/
sudo chmod +x /usr/local/bin/{inject_sms.py,verify_after_auth.py,probe_handshake.py,diag_api.py,enable_api.sh,notify_2fa_watch.sh,notify_2fa_needed.sh,commandsend.sh}

# 4. (Optional) Install systemd units
mkdir -p ~/.config/systemd/user
sed -i "s|/home/USER|$HOME|g" systemd/*.service
cp systemd/*.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now ibgateway.service ibc-2fa-notify.service

# 5. (Optional, for 24/7) Enable lingering
sudo loginctl enable-linger $USER
```

See [`docs/IBC_CONFIG_KNOBS.md`](docs/IBC_CONFIG_KNOBS.md) for the IBC
`config.ini` settings that matter (notably
`SecondFactorAuthenticationExitInterval` — upstream's 60s default is
too tight for human-in-the-loop 2FA entry, bump to 300s).

## Quick start after install

```bash
# Start the gateway
systemctl --user start ibgateway.service

# When the SMS dialog opens (you'll get a Telegram ping), inject a code:
inject_sms.py --confirm 123456

# Verify the API came up:
verify_after_auth.py
# ==> Verifying IB Gateway [live] @ 127.0.0.1:4001
# PASS [1/4]: port 4001 listening
# PASS [2/4]: TCP connected, reader thread alive
# PASS [3/4]: nextValidId=1 (session live)
# PASS [4/4]: 1 account(s): ['U…']
# ✅ ALL CHECKS PASSED — IB Gateway API is live and serving
```

## Files

| Path | Purpose |
|---|---|
| `install.sh` | One-shot installer (interactive or non-interactive) |
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

## For an agent

If you're an AI agent reading this repo and your user just asked you to
"install IB Gateway headlessly" or "set up IBKR automation", do this:

1. Run the one-shot installer with `IBGW_NONINTERACTIVE=1` and the
   user's credentials in env vars. **Never** inline credentials in any
   committed file.
2. After install completes, verify with
   `verify_after_auth.py`. If it returns 0, the API is live.
3. The user's Telegram chat will get pinged the moment a 2FA prompt
   opens. The user pastes the 6-digit code back; you (the agent) run
   `inject_sms.py --confirm <code>` to type it into the dialog.
4. Re-run `verify_after_auth.py` after injection. If it returns 0,
   the user is authenticated and the API is accepting clients.

If install fails at any step, the script prints a `DIAGNOSTIC:` line
with the failing command's output. The most common failure modes:

- `apt install` permission denied → not running as root or no sudo.
- `pip install ibapi` fails on externally-managed-environment →
  use `pip install --user --break-system-packages ibapi` or a venv.
- Telegram ping doesn't arrive → bot token or chat ID wrong; the
  script still completes; the notifier is optional.
- Port 4001 not listening after auth → the network blocks outbound
  to IBKR's CCp gateway. See `docs/IBGATEWAY_PORT_REDIRECT.md`.

## Security

- `inject_sms.py` requires an explicit `--confirm` flag and refuses to
  run if the SMS dialog isn't actually present on DISPLAY=:99.
- Never commit `credentials.env` or any file containing the IBKR
  password. The `.gitignore` covers this; the install script stages
  it outside the repo.
- The Telegram bot token and chat ID should also not be committed.
  The install script reads them from env vars, not files.

## License

MIT — see [`LICENSE`](LICENSE).
