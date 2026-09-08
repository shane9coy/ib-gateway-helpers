#!/usr/bin/env python3
"""diag_api.py — verbose diagnostic for IB Gateway API session."""
import sys
import time
from ib_insync import IB, util

ib = IB()
ib.connect(host="127.0.0.1", port=4001, clientId=997, timeout=5)
print(f"connected: {ib.isConnected()}")

# Wait up to 30s, log every event we see
print("listening for events (30s)...")
end = time.time() + 30
events_seen = []
while time.time() < end:
    try:
        # Check all known event types via getattr
        for evt_name in ['nextValidId', 'error', 'managedAccounts',
                          'position', 'accountSummary', 'orderStatus',
                          'execDetails', 'tickPrice', 'commissionReport',
                          'connectionClosed', 'disconnected', 'openOrder',
                          'updateAccountValue']:
            evt = getattr(ib, evt_name + 'Event', None)
            if evt is None:
                continue
            try:
                val = util.run(ib.waitForEvent(evt, timeout=0.1))
                events_seen.append((time.time(), evt_name, val))
                print(f"  [{time.time():.1f}] {evt_name}: {val}")
            except Exception:
                pass
    except Exception as e:
        print(f"err: {e}")

print(f"\ntotal events: {len(events_seen)}")
ib.disconnect()
