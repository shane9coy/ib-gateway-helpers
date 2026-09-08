#!/usr/bin/env python3
"""
verify_after_auth.py — full post-auth verification in one shot.

Uses the official `ibapi` package (not ib_insync — that one has a known
incompatibility with IB Gateway where events don't fire). Connects, waits
for nextValidId, requests managed accounts, prints result.

Exit codes:
  0  ALL CHECKS PASSED — IB Gateway API is live and serving
  1  Port not listening
  2  Connect refused / timeout
  3  nextValidId did not fire within 10s (auth incomplete)
  4  managedAccounts returned empty
  5  Other error
"""

import socket
import sys
import threading
import time
from pathlib import Path

from ibapi.client import EClient
from ibapi.wrapper import EWrapper


class VerifyApp(EWrapper, EClient):
    def __init__(self):
        EClient.__init__(self, self)
        self.next_valid_id = None
        self.managed_accounts = []
        self.errors = []
        self.connected_event = threading.Event()
        self.next_id_event = threading.Event()
        self.accts_event = threading.Event()

    def nextValidId(self, orderId: int):
        self.next_valid_id = orderId
        self.next_id_event.set()

    def managedAccounts(self, accountsList: str):
        self.managed_accounts = accountsList.split(",") if accountsList else []
        self.accts_event.set()

    def error(self, reqId, errorCode, errorString, advancedOrderRejectJson=""):
        self.errors.append((reqId, errorCode, errorString))

    def connectionClosed(self):
        self.connected_event.set()


def port_listening(host: str, port: int, timeout: float = 2.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except Exception:
        return False


def main() -> int:
    mode = sys.argv[1] if len(sys.argv) > 1 else "live"
    port = 4002 if mode == "paper" else 4001
    host = "127.0.0.1"

    print(f"==> Verifying IB Gateway [{mode}] @ {host}:{port}")

    # Check 1: port listening
    if not port_listening(host, port):
        print(f"FAIL [1/4]: {host}:{port} not listening")
        return 1
    print(f"PASS [1/4]: port {port} listening")

    # Connect + spin up reader thread
    app = VerifyApp()
    try:
        app.connect(host=host, port=port, clientId=998)
    except Exception as e:
        print(f"FAIL [2/4]: connect raised: {type(e).__name__}: {e}")
        return 2
    if not app.isConnected():
        print("FAIL [2/4]: EClient.isConnected() False after connect()")
        return 2

    t = threading.Thread(target=app.run, daemon=True)
    t.start()
    time.sleep(0.5)
    print(f"PASS [2/4]: TCP connected, reader thread alive")

    # Check 3: nextValidId within 10s
    if not app.next_id_event.wait(timeout=10):
        print(f"FAIL [3/4]: nextValidId did not fire within 10s")
        print(f"   errors so far: {app.errors[:5]}")
        app.disconnect()
        return 3
    print(f"PASS [3/4]: nextValidId={app.next_valid_id} (session live)")

    # Check 4: managedAccounts
    app.reqManagedAccts()
    if not app.accts_event.wait(timeout=5):
        print(f"FAIL [4/4]: managedAccounts did not fire within 5s")
        app.disconnect()
        return 4
    if not app.managed_accounts:
        print(f"FAIL [4/4]: managedAccounts returned empty list")
        app.disconnect()
        return 4
    print(f"PASS [4/4]: {len(app.managed_accounts)} account(s): {app.managed_accounts[:3]}")

    app.disconnect()
    print()
    print("✅ ALL CHECKS PASSED — IB Gateway API is live and serving")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(99)
