#!/usr/bin/env bash
# install.sh — end-to-end installer for ib-gateway-helpers.
#
# Interactive by default: asks for IBKR username, paper-or-live, and
# (optionally) Telegram bot credentials.
#
# Non-interactive mode: set env vars before invoking:
#   IBGW_USERNAME, IBGW_PASSWORD, IBGW_MODE (live|paper),
#   IBGW_TELEGRAM_BOT_TOKEN, IBGW_TELEGRAM_CHAT_ID, IBGW_NONINTERACTIVE=1
#
# Re-runs are safe: --resume skips already-completed steps.
# Each step prints [STEP n/total] and exits non-zero on failure with a
# DIAGNOSTIC line so an agent can debug.

set -uo pipefail

REPO_URL="https://github.com/REDACTED/ib-gateway-helpers.git"
INSTALL_DIR="${IBGW_INSTALL_DIR:-/opt/ib-gateway-helpers}"
USER_HOME="${HOME:-/root}"
USER_NAME="${USER:-$(id -un 2>/dev/null || echo root)}"
IBC_DIR="/opt/ibc"
IBGATEWAY_DIR="/opt/ibgateway"
JDK_DIR="/opt/bellsoft-jdk21"
IBC_HOME="$USER_HOME/ibc"
RESUME=0

# Color helpers
RED=$'\033[0;31m'; GRN=$'\033[0;32m'; YLW=$'\033[1;33m'; BLU=$'\033[0;34m'; NC=$'\033[0m'
log()  { echo "${BLU}[$(date +%H:%M:%S)]${NC} $*"; }
ok()   { echo "${GRN}[$(date +%H:%M:%S)] OK${NC}    $*"; }
warn() { echo "${YLW}[$(date +%H:%M:%S)] WARN${NC}  $*"; }
fail() { echo "${RED}[$(date +%H:%M:%S)] FAIL${NC}  $*" >&2; echo "${RED}DIAGNOSTIC:${NC} see output above" >&2; exit 1; }

# Parse flags
for arg in "$@"; do
  case "$arg" in
    --resume) RESUME=1 ;;
    --help|-h)
      sed -n '2,15p' "$0"
      exit 0
      ;;
  esac
done

# ── Step 1: Detect package manager ─────────────────────────────────────────
log "Step 1/9: detecting OS and package manager"
if command -v apt-get >/dev/null 2>&1; then
  PKG_MGR="apt"
  PKG_INSTALL="sudo apt-get install -y"
elif command -v dnf >/dev/null 2>&1; then
  PKG_MGR="dnf"
  PKG_INSTALL="sudo dnf install -y"
elif command -v yum >/dev/null 2>&1; then
  PKG_MGR="yum"
  PKG_INSTALL="sudo yum install -y"
elif command -v pacman >/dev/null 2>&1; then
  PKG_MGR="pacman"
  PKG_INSTALL="sudo pacman -S --noconfirm"
else
  fail "no supported package manager found (apt/dnf/yum/pacman)"
fi
ok "package manager: $PKG_MGR"

# ── Step 2: Install system deps ─────────────────────────────────────────────
log "Step 2/9: installing system dependencies"
if [[ "$RESUME" == "1" ]] && command -v xdotool >/dev/null 2>&1; then
  ok "skipping (already installed)"
else
  case "$PKG_MGR" in
    apt)
      $PKG_INSTALL xvfb x11vnc xdotool fluxbox jq netcat-openbsd python3-pip python3-venv unzip 2>&1 | tail -5 \
        || fail "apt install failed"
      ;;
    dnf|yum)
      $PKG_INSTALL xorg-x11-server-Xvfb x11vnc xdotool fluxbox jq nmap-ncat python3-pip unzip 2>&1 | tail -5 \
        || fail "$PKG_MGR install failed"
      ;;
    pacman)
      $PKG_INSTALL xorg-server-xvfb x11vnc xdotool fluxbox jq openbsd-netcat python-pip unzip 2>&1 | tail -5 \
        || fail "pacman install failed"
      ;;
  esac
  ok "system dependencies installed"
fi

# ── Step 3: Install Python ibapi ───────────────────────────────────────────
log "Step 3/9: installing ibapi (official IBKR Python client)"
if python3 -c "import ibapi" 2>/dev/null; then
  ok "ibapi already present"
else
  pip3 install --quiet --user ibapi 2>&1 | tail -3 \
    || pip3 install --quiet --user --break-system-packages ibapi 2>&1 | tail -3 \
    || fail "pip install ibapi failed"
  ok "ibapi installed"
fi

# ── Step 4: Install IBC ────────────────────────────────────────────────────
log "Step 4/9: installing IBC at $IBC_DIR"
if [[ -x "$IBC_DIR/scripts/ibcstart.sh" ]]; then
  ok "IBC already present"
else
  IBC_VERSION="${IBGW_IBC_VERSION:-3.24.2}"
  IBC_URL="https://github.com/IbcAlpha/IBC/releases/download/${IBC_VERSION}/IBCLinux-${IBC_VERSION}.zip"
  tmpdir="$(mktemp -d)"
  curl -fsSL "$IBC_URL" -o "$tmpdir/ibc.zip" || fail "failed to download IBC from $IBC_URL"
  sudo mkdir -p "$IBC_DIR"
  sudo unzip -q "$tmpdir/ibc.zip" -d "$IBC_DIR" || fail "failed to unzip IBC"
  rm -rf "$tmpdir"
  ok "IBC ${IBC_VERSION} installed at $IBC_DIR"
fi

# ── Step 5: Install IB Gateway ─────────────────────────────────────────────
log "Step 5/9: installing IB Gateway at $IBGATEWAY_DIR"
if [[ -d "$IBGATEWAY_DIR" ]] && [[ -f "$IBGATEWAY_DIR/jts.ini" ]]; then
  ok "IB Gateway already present"
else
  IBGW_VERSION="${IBGW_TWS_VERSION:-1045}"
  IBGW_URL="https://download2.interactivebrokers.com/installers/ibgateway/${IBGW_VERSION}/ibgateway-${IBGW_VERSION}-standalone-linux-x64.sh"
  tmpdir="$(mktemp -d)"
  curl -fsSL "$IBGW_URL" -o "$tmpdir/ibgw.sh" || fail "failed to download IB Gateway from $IBGW_URL"
  chmod +x "$tmpdir/ibgw.sh"
  sudo mkdir -p "$IBGATEWAY_DIR"
  # IB Gateway's installer is interactive; we extract silently.
  sudo "$tmpdir/ibgw.sh" -q -dir "$IBGATEWAY_DIR" || fail "IB Gateway installer failed"
  rm -rf "$tmpdir"
  ok "IB Gateway installed at $IBGATEWAY_DIR"
fi

# ── Step 6: Install JDK if missing ─────────────────────────────────────────
log "Step 6/9: ensuring JDK"
if [[ -x "$JDK_DIR/bin/java" ]]; then
  ok "JDK already present at $JDK_DIR"
else
  case "$PKG_MGR" in
    apt)  $PKG_INSTALL default-jdk-headless || fail "JDK install failed" ;;
    dnf|yum)  $PKG_INSTALL java-21-openjdk-headless || fail "JDK install failed" ;;
    pacman) $PKG_INSTALL jdk21-openjdk || fail "JDK install failed" ;;
  esac
  ok "JDK installed"
fi

# ── Step 7: Copy scripts from this repo ────────────────────────────────────
log "Step 7/9: installing scripts"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ ! -d "$SCRIPT_DIR/scripts" ]]; then
  fail "scripts/ dir not found at $SCRIPT_DIR — re-clone the repo"
fi
for s in "$SCRIPT_DIR/scripts/"*; do
  sudo cp "$s" /usr/local/bin/ && sudo chmod +x "/usr/local/bin/$(basename "$s")"
done
ok "scripts installed to /usr/local/bin/"

# ── Step 8: Stage ~/ibc/ ───────────────────────────────────────────────────
log "Step 8/9: staging ~/ibc/ with config and credentials"

# Get credentials (interactive or non-interactive)
if [[ "${IBGW_NONINTERACTIVE:-0}" == "1" ]]; then
  IBGW_USERNAME="${IBGW_USERNAME:?set IBGW_USERNAME for non-interactive install}"
  IBGW_PASSWORD="${IBGW_PASSWORD:?set IBGW_PASSWORD for non-interactive install}"
else
  if [[ -z "${IBGW_USERNAME:-}" ]]; then
    read -rp "IBKR username: " IBGW_USERNAME
  fi
  if [[ -z "${IBGW_PASSWORD:-}" ]]; then
    read -rsp "IBKR password: " IBGW_PASSWORD
    echo
  fi
fi
IBGW_MODE="${IBGW_MODE:-paper}"

mkdir -p "$IBC_HOME/logs"

# credentials.env (NOT committed to any repo)
cat > "$IBC_HOME/credentials.env" <<EOF
IBKR_USERNAME=$IBGW_USERNAME
IBKR_PASSWORD=$IBGW_PASSWORD
TRADING_MODE=$IBGW_MODE
EOF
chmod 600 "$IBC_HOME/credentials.env"

# config.ini (from example, with creds)
cp "$SCRIPT_DIR/examples/config.ini" "$IBC_HOME/config.ini"
sed -i "s|YOUR_USERNAME|$IBGW_USERNAME|" "$IBC_HOME/config.ini"
sed -i "s|YOUR_PASSWORD_HERE_OR_USE_ENV||" "$IBC_HOME/config.ini"
# Inject from env at runtime via run_xvfb_gateway.sh (already does this)

# run_xvfb_gateway.sh (the Xvfb + fluxbox + ibc launcher)
cat > "$IBC_HOME/run_xvfb_gateway.sh" <<'WRAPPER'
#!/usr/bin/env bash
# Wrapper: start Xvfb + fluxbox, then launch IBC-driven IB Gateway.
set -e
XVFB_DISPLAY=:99
mkdir -p "$HOME/ibc/logs"

# Xvfb
pgrep -f "Xvfb $XVFB_DISPLAY" >/dev/null || Xvfb $XVFB_DISPLAY -screen 0 1280x1024x24 -nolisten tcp -dpi 96 &
sleep 2

# fluxbox (required for AWT dialog detection)
pgrep -f "fluxbox -display $XVFB_DISPLAY" >/dev/null || fluxbox -display $XVFB_DISPLAY &
sleep 2

# Load creds
set -a; source "$HOME/ibc/credentials.env"; set +a
export TWSUSERID="$IBKR_USERNAME"
export TWSPASSWORD="$IBKR_PASSWORD"
export TRADING_MODE="${TRADING_MODE:-paper}"
export DISPLAY="$XVFB_DISPLAY"

exec /opt/ibc/scripts/displaybannerandlaunch.sh
WRAPPER
chmod +x "$IBC_HOME/run_xvfb_gateway.sh"

ok "~/ibc/ staged (credentials in credentials.env, mode 0600)"

# ── Step 9: Install + start systemd units ──────────────────────────────────
log "Step 9/9: installing systemd units"
mkdir -p "$USER_HOME/.config/systemd/user"
for s in "$SCRIPT_DIR/systemd/"*.service; do
  sed "s|/home/USER|$USER_HOME|g; s|User=qp|User=$USER_NAME|g" "$s" \
    > "$USER_HOME/.config/systemd/user/$(basename "$s")"
done

# Telegram .env (optional)
if [[ -n "${IBGW_TELEGRAM_BOT_TOKEN:-}" && -n "${IBGW_TELEGRAM_CHAT_ID:-}" ]]; then
  mkdir -p "$USER_HOME/.config/ib-gateway-helpers"
  cat > "$USER_HOME/.config/ib-gateway-helpers/telegram.env" <<EOF
TELEGRAM_BOT_TOKEN=$IBGW_TELEGRAM_BOT_TOKEN
TELEGRAM_HOME_CHANNEL=$IBGW_TELEGRAM_CHAT_ID
EOF
  chmod 600 "$USER_HOME/.config/ib-gateway-helpers/telegram.env"
  ok "Telegram credentials staged"
fi

# Reload systemd (use --user; fall back to system if user bus not available)
if systemctl --user daemon-reload 2>/dev/null; then
  systemctl --user enable --now ibgateway.service ibc-2fa-notify.service 2>&1 | tail -3
  ok "user services enabled and started"
else
  warn "user systemd bus unavailable — start manually with:"
  echo "  $IBC_HOME/run_xvfb_gateway.sh"
fi

# ── Final summary ──────────────────────────────────────────────────────────
echo
ok "INSTALL COMPLETE"
echo
echo "  IB Gateway:    systemctl --user status ibgateway.service"
echo "  API port:      127.0.0.1:4001 (live) or 4002 (paper)"
echo "  VNC:           localhost:5999 (run x11vnc -display :99 -rfbport 5999 if not auto-started)"
echo "  2FA injector:  inject_sms.py --confirm <6-digit-code>"
echo "  Verify:        verify_after_auth.py"
echo
echo "  When the SMS dialog opens (Telegram ping if configured),"
echo "  paste the 6-digit code and run:"
echo
echo "      inject_sms.py --confirm 123456   # your code here"
echo "      verify_after_auth.py"
echo
