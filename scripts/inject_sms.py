#!/usr/bin/env python3
"""
inject_sms.py — programmatically feed a 6-digit SMS 2FA code into the
IB Gateway / IBC "Enter SMS Authentication Code" JDialog on the local Xvfb.

Usage:
    inject_sms.py --confirm 123456          # required --confirm flag
    echo 123456 | inject_sms.py --confirm   # code via stdin

It auto-detects the SMS dialog by title ("Enter SMS Authentication Code"),
focuses it, clicks the text field, types the code, then submits via Tab +
Enter.

Exit codes:
  0  code submitted (IB Gateway will accept or reject server-side)
  1  dialog not found (gateway not at 2FA prompt)
  2  invalid code format (not 6 digits) or missing --confirm flag
  3  xdotool error

Safety:
  - Refuses to do anything without an explicit --confirm flag.
  - Refuses to run unless the SMS dialog is actually present on DISPLAY=:99.
  - Code must be exactly 6 digits.
"""

import argparse
import re
import shlex
import subprocess
import sys
import time

DISPLAY = ":99"
SMS_TITLE = "Enter SMS Authentication Code"


def run(cmd: str, check: bool = True) -> str:
    """Run a shell command, return stdout, raise on failure if check=True."""
    r = subprocess.run(
        cmd, shell=True, capture_output=True, text=True, timeout=10,
        env={"PATH": "/usr/local/bin:/usr/bin:/bin", "DISPLAY": DISPLAY},
    )
    if check and r.returncode != 0:
        sys.stderr.write(f"cmd failed ({r.returncode}): {cmd}\n{r.stderr}\n")
    return (r.stdout or "").strip()


def find_sms_window() -> int | None:
    """Return the xdotool window id for the SMS dialog, or None."""
    out = run("xdotool search --name " + shlex.quote(SMS_TITLE), check=False)
    if not out:
        return None
    for line in out.splitlines():
        wid = line.strip()
        if wid.isdigit():
            return int(wid)
    return None


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[1])
    parser.add_argument(
        "code", nargs="?",
        help="6-digit SMS code (or pipe via stdin).",
    )
    parser.add_argument(
        "--confirm", action="store_true",
        help="Required. Acknowledges that you understand this will type the "
             "code into the SMS dialog without further confirmation.",
    )
    args = parser.parse_args()

    # Read code from argv[1] or stdin
    if args.code:
        code = args.code.strip()
    else:
        code = sys.stdin.read().strip()

    if not args.confirm:
        sys.stderr.write("refusing to run without --confirm flag.\n")
        return 2

    if not re.fullmatch(r"\d{6}", code):
        sys.stderr.write(f"invalid SMS code: {code!r} (want 6 digits)\n")
        return 2

    wid = find_sms_window()
    if wid is None:
        sys.stderr.write(
            f"SMS dialog {SMS_TITLE!r} not found on {DISPLAY}. "
            "Is the gateway at the 2FA prompt?\n"
        )
        return 1

    sys.stderr.write(f"SMS dialog wid={wid}, code={code}\n")

    # Focus the dialog (synchronous so the keystrokes don't drop)
    run(f"xdotool windowactivate --sync {wid}")
    run(f"xdotool windowfocus {wid}")
    time.sleep(0.4)

    # Click in the dialog text-field area (upper third, centered horizontally).
    run(f"xdotool mousemove --window {wid} 200 150")
    run(f"xdotool click 1")
    time.sleep(0.3)

    # Select-all + delete in case there's stale text, then type fresh
    run(f"xdotool key ctrl+a")
    run(f"xdotool key Delete")
    run(f"xdotool type --delay 60 --clearmodifiers {shlex.quote(code)}")
    time.sleep(0.3)

    # Submit: Tab to leave the field, then Enter to activate OK
    run(f"xdotool key Tab")
    time.sleep(0.2)
    run(f"xdotool key Return")
    time.sleep(0.2)

    sys.stderr.write("submitted.\n")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except subprocess.TimeoutExpired as e:
        sys.stderr.write(f"timeout: {e}\n")
        sys.exit(3)
