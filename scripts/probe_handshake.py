#!/usr/bin/env python3
"""
probe_handshake.py — verify IB Gateway is accepting API client connections
on 127.0.0.1:4001 (or 4002). Connects via ib_insync, asserts nextValidId
fires within 5 seconds, then disconnects.

Exit codes:
  0  Handshake OK (port bound, accepts clients, session is live)
  1  Port not listening
  2  Port refused
  3  Connect attempted but no nextValidId within timeout (auth not complete)
  4  Other error

Usage:
    probe_handshake.py                    # probe 127.0.0.1:4001
    probe_handshake.py 4002               # probe different port
    probe_handshake.py 4001 127.0.0.1     # probe custom host:port
"""

import socket
import sys
import time

from ib_insync import IB, util


def port_listening(host: str, port: int, timeout: float = 2.0) -> bool:
    try:
        with socket.create_connection((host, port), timeout=timeout):
            return True
    except (ConnectionRefusedError, socket.timeout, OSError):
        return False


def main() -> int:
    args = sys.argv[1:]
    port = int(args[0]) if args else 4001
    host = args[1] if len(args) >= 2 else "127.0.0.1"
    client_id = 999

    if not port_listening(host, port):
        print(f"FAIL: {host}:{port} not listening (auth not complete yet?)")
        return 1

    print(f"OK: {host}:{port} accepting TCP connections — attempting API handshake")

    ib = IB()
    try:
        ib.connect(host=host, port=port, clientId=client_id, timeout=5)
    except Exception as e:
        print(f"FAIL: connect raised: {type(e).__name__}: {e}")
        return 2

    if not ib.isConnected():
        print("FAIL: ib.isConnected() is False after connect()")
        return 2

    # Wait briefly for nextValidId (the first event IBKR sends on a healthy session)
    deadline = time.time() + 5
    got_valid_id = False
    while time.time() < deadline:
        try:
            util.run(ib.waitForEvent(ib.nextValidIdEvent, timeout=1))
            got_valid_id = True
            break
        except Exception:
            pass

    # Collect session details
    accounts = ib.managedAccounts() if got_valid_id else []
    n = len(accounts)
    print(
        f"OK: handshake complete — nextValidId={ib.client.getNextReqId() if got_valid_id else 'NONE'} "
        f"accounts={n} ({accounts[:3]}{'...' if n > 3 else ''})"
    )

    ib.disconnect()
    return 0 if got_valid_id else 3


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(4)
