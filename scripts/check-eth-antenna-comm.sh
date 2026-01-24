#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: ETH-Antenne Communication Check
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

ANTENNA_IP="192.168.2.2"
TIMEFRAME="10min"

# Prüfe ob debmatic-monitor-hb-rf-eth Service läuft
if ! systemctl is-active --quiet debmatic-monitor-hb-rf-eth; then
    msg="ERROR: debmatic-monitor-hb-rf-eth service not running"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_ETH_ANTENNA}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

# Prüfe Ping
if ! ping -c 1 -W 2 "$ANTENNA_IP" &>/dev/null; then
    msg="ERROR: ETH-Antenne not reachable at $ANTENNA_IP"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_ETH_ANTENNA}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

# Prüfe Logs auf Connection-Probleme
conn_errors=$(journalctl -u debmatic-monitor-hb-rf-eth --since "$TIMEFRAME" --no-pager | grep -iE "connection.*failed|timeout|unreachable" || true)

if [[ -n "$conn_errors" ]]; then
    msg="WARNING: Connection issues detected in last $TIMEFRAME"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_ETH_ANTENNA}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: ETH-Antenne communication healthy"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_ETH_ANTENNA}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
