# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

## [0.2.0] — 2026-09-10

Trading-week lifecycle, and a start-limit fix that was being silently
ignored by systemd.

### Added

- `systemd/ibc-weekly-reauth.service` + `systemd/ibc-weekly-reauth.timer` —
  Sunday 12:00 (`Persistent=true`) trading-week start: creates
  `~/ibc/.trading-week`, starts the gateway, and Telegram-prompts for the
  weekly IBKR re-auth.
- `systemd/ibgw-stop.service` + `systemd/ibgw-stop.timer` — Friday 20:00
  (`Persistent=false`) weekend shutdown: stops the gateway, then removes the
  flag so nothing restarts it until Sunday.
- `systemd/ibc-gateway-down-notify.service` — `OnFailure=` handler for
  `ibgateway.service`; alerts once when the unit exhausts its start budget
  and stops retrying.
- `scripts/notify_weekly_reauth.sh` — opens the trading week and reports
  whether the gateway is already authenticated, waiting on approval, or
  failed to start.
- `scripts/notify_gateway_down.sh` — sends the "gave up, needs a human"
  Telegram alert.

### Changed

- `systemd/ibgateway.service`: gated on
  `ConditionPathExists=~/ibc/.trading-week`; added
  `OnFailure=ibc-gateway-down-notify.service`; `Restart=always` with
  `RestartSec=30s` (was `on-failure` / 300 s).
- `systemd/ibc-2fa-notify.service`: `PartOf=ibgateway.service`, and
  `RuntimeMaxSec=15min` so the watcher periodically re-resolves IBC's
  daily log roll (`ibc-..._<DayOfWeek>.txt`) instead of tailing yesterday's
  file forever.
- `scripts/notify_2fa_watch.sh`: now matches the app-auth prompt
  (`Second Factor Authentication initiated`) as well as the SMS dialog,
  rate-limits notifications with a cooldown (a retrying gateway can raise a
  prompt every few seconds), and waits for the day's log to appear rather
  than exiting when the gateway has not started yet.
- `install.sh`: installs `*.timer` as well as `*.service`, stages the
  notifier scripts into `~/ibc/` (the units reference them by absolute
  path), and opens the trading week before the first start.

### Fixed

- `systemd/ibgateway.service` had `StartLimitIntervalSec`/`StartLimitBurst`
  in `[Service]`. systemd >= 230 ignores both keys there, so the intended
  4-starts-per-hour bound silently degraded to systemd's 10 s default.
  Moved them to `[Unit]`.

## [0.1.0] — 2026-09-08

Initial public release.

### Added

- `scripts/inject_sms.py` — xdotool-based 2FA SMS code injector with
  `--confirm` safety gate. Validates that the SMS dialog is actually
  present before typing.
- `scripts/verify_after_auth.py` — post-auth verification using the
  official `ibapi` package. Returns 0 only if all four checks (port
  listening, TCP handshake, `nextValidId` received, `managedAccounts`
  populated) pass.
- `scripts/probe_handshake.py` — single-shot handshake probe. Useful
  for monitoring or cron-driven health checks.
- `scripts/diag_api.py` — verbose event-listener diagnostic. Lists
  every API event received over 30 seconds.
- `scripts/commandsend.sh` — patched version of IBC's `commandsend.sh`
  that uses `nc` instead of `telnet` (most modern Linux distros don't
  ship `telnet` by default) and accepts a second argument for the
  `SECURITY_CODE` command.
- `scripts/notify_2fa_watch.sh` + `scripts/notify_2fa_needed.sh` —
  log-watching wrapper that fires a Telegram ping when IB Gateway
  hits the 2FA prompt.
- `systemd/ibgateway.service` — user-level service for IB Gateway,
  auto-restarts on failure, 5-minute startup timeout.
- `systemd/ibc-2fa-notify.service` — user-level watcher for the 2FA
  notifier.
- `examples/config.ini` — annotated IBC configuration example
  (no credentials).
- `examples/jts.ini.example` — annotated IB Gateway `jts.ini` example
  (no credentials).
- `docs/IBGATEWAY_PORT_REDIRECT.md` — explains the `ndc1` → `cdc1`
  redirect for networks that block the default IB Gateway ports.
- `docs/IBC_CONFIG_KNOBS.md` — short list of IBC `config.ini` knobs
  that meaningfully affect headless operation.
- `docs/IBAPI_VS_IBINSYNC.md` — documents the `ib_insync` bug against
  IB Gateway and recommends `ibapi` instead.
