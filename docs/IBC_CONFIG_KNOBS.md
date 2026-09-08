# IBC `config.ini` knobs that actually matter

The full IBC docs are at
<https://github.com/IbcAlpha/IBC/blob/master/userguide.md>. This is the
short list of knobs that meaningfully affect headless operation.

## `[IB]`

| Key | Why it matters |
|---|---|
| `TradingMode` | `live` or `paper`. Required. |
| `IbLoginId` / `IbPassword` | Login credentials. Prefer `credentials.env` over inlining. |
| `AutoRestartTime` | Daily restart time (`hh:mm` AM/PM — note the **12-hour format**). With auto-restart set, IB Gateway restarts daily and IBC re-runs the login without 2FA prompts (as long as the IBKR session is still valid in the same week). |
| `ReloginAfterSecondFactorAuthenticationTimeout` | `yes` — re-attempt login automatically if 2FA times out. Without this, every restart with a stale 2FA prompt will sit idle forever. |
| `SecondFactorAuthenticationExitInterval` | **Default 60s — too short.** Bump to 300s (5 min) so a human has time to type the SMS code. |
| `ReadOnlyApi` | `no` — explicitly disable IB Gateway's "Read-Only API" mode so API clients can place orders. The IBC `ConfigureReadOnlyApiTask` will uncheck the relevant checkbox in the Gateway's API settings dialog at startup. |

## `[Other]`

| Key | Why it matters |
|---|---|
| `ShowAllDialogs` | `yes` is fine for headless; we capture them via xdotool anyway. |
| `ForceTWSApiClientRedirect` | Leave empty unless you have a specific need. |

## `[TWS]`

| Key | Why it matters |
|---|---|
| `CommandServerPort` | **Set to 7462.** Without this, IBC's CommandServer doesn't start and you can't drive the gateway programmatically (e.g., `commandsend.sh RECONNECTDATA`). |

## What's NOT documented in IBC but matters

- **`TrustedIPs` in `jts.ini`** must include `127.0.0.1` or no API client
  on the same machine can connect.
- **`ApiOnly=true` in `jts.ini`** — IB Gateway runs without the trading
  UI; only the API server is exposed. Recommended for headless.
- The IBC `ENABLEAPI` command is **TWS-only**. IB Gateway ignores it.
  For IB Gateway, set `ReadOnlyApi=no` in `config.ini` instead, which
  triggers IBC's `ConfigureReadOnlyApiTask` to drive the GUI checkbox.

## Example

See [`examples/config.ini`](../examples/config.ini).
