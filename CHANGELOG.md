# Changelog

All notable changes to this project are documented here. Versions follow
[Semantic Versioning](https://semver.org/).

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
