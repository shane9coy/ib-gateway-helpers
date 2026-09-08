# `ibapi` vs `ib_insync` against IB Gateway

If you've ever written `IB().connect('127.0.0.1', 4001)` and then stared
at a `nextValidId` that never arrives — this is why.

## The symptom

`ib_insync` connects to IB Gateway on `127.0.0.1:4001`. `isConnected()`
returns `True`. But:

- `nextValidId` never fires
- `managedAccounts()` returns nothing
- `reqMktData()` times out
- The diagnostic shows **zero events received** in 30 seconds

Meanwhile, IB Gateway's own UI shows:
- `Interactive Brokers API Server: connected` ✅
- `API Client: disconnected` ❌
- Launcher logs include `Error 321: The API interface is currently in Read-Only mode` for `reqManagedAccts`-like system requests

TWS works fine. Paper accounts work fine. **Only IB Gateway + ib_insync
has the issue.**

## Why

We don't have a confirmed root cause, but the symptom is consistent with
a protocol-version or framing mismatch. IB Gateway implements a stricter
subset of the API protocol than TWS does, and `ib_insync`'s connection
handshake (or its event-loop wakeup) doesn't fully match what Gateway
expects.

## The fix: use the official `ibapi`

```bash
pip install ibapi
```

Then:

```python
from ibapi.client import EClient
from ibapi.wrapper import EWrapper

class App(EWrapper, EClient):
    def __init__(self):
        EClient.__init__(self, self)
    def nextValidId(self, orderId):
        print(f"nextValidId: {orderId}")
        self.disconnect()

app = App()
app.connect("127.0.0.1", 4001, clientId=1)
import threading
threading.Thread(target=app.run, daemon=True).start()
```

Within 5 seconds you'll see `nextValidId: 1`. Market data, account
queries, order placement — all work.

## Recommendation

- **For headless IB Gateway setups:** use `ibapi`. Don't bother with
  `ib_insync`.
- **For TWS or interactive use:** `ib_insync` is fine — its Jupyter
  notebook integration and async API are genuinely nicer.
- **If you're maintaining `ib_insync`:** please file an issue. We can
  reproduce this against `10.45.1j` on IB Gateway.

## Affected versions

- `ib_insync` 0.9.86 (the latest as of writing)
- IB Gateway `10.45.1j` (latest stable as of writing)
- Python 3.11

We have not tested other combinations.
