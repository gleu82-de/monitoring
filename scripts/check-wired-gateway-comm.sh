#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: Wired Gateway Communication Check
# Pushes results directly to Kuma Push Monitor

# Load Kuma config (relative to script directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/kuma.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    source "$CONFIG_FILE"
else
    echo "ERROR: Config file $CONFIG_FILE not found"
    exit 1
fi

GATEWAY_IP="192.168.2.3"
TIMEFRAME="10min"

# Prüfe ob HS485 Daemon läuft
if ! systemctl is-active --quiet debmatic-hs485d; then
    msg="ERROR: debmatic-hs485d service not running"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_WIRED_GATEWAY}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

# Prüfe Ping
if ! ping -c 1 -W 2 "$GATEWAY_IP" &>/dev/null; then
    msg="ERROR: Wired Gateway not reachable at $GATEWAY_IP"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_WIRED_GATEWAY}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

# Prüfe Logs auf Bus-Probleme
bus_errors=$(journalctl -u debmatic-hs485d --since "$TIMEFRAME" --no-pager | grep -iE "bus.*error|timeout|unreachable" || true)

if [[ -n "$bus_errors" ]]; then
    msg="WARNING: Bus communication issues detected in last $TIMEFRAME"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_WIRED_GATEWAY}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: Wired Gateway communication healthy"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_WIRED_GATEWAY}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
