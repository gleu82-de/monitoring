#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: ETH-Antenne Communication Check
# Pushes results directly to Kuma Push Monitor

# Load Kuma config (relative to script directory)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../config/kuma.conf"
# Prüfen, ob wir auf dem richtigen Server sind
CURRENT_HOST=$(hostname)
TARGET_HOST="Home-Prod"

if [[ "$CURRENT_HOST" != "$TARGET_HOST" ]]; then
    echo "INFO: Script läuft auf $CURRENT_HOST, wechsle zu $TARGET_HOST..."
    
    # Script und Config auf PROD kopieren und dort ausführen
    ssh dgl@PROD "bash -s" < "$0"
    exit $?
fi

echo "INFO: Script läuft auf $TARGET_HOST"

if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Config file $CONFIG not found"
    exit 1
fi

# KUMA_URL extrahieren
KUMA_URL=$(grep '^KUMA_URL=' "$CONFIG" | cut -d= -f2 | tr -d '"')
echo "KUMA_URL: $KUMA_URL"

key = 'TOKEN_ETH_ANTENNA'
IFS='=' read -r $key token
token="${token%\"}"
token="${token#\"}"
echo '$token'

ANTENNA_IP="192.168.2.2"
TIMEFRAME="10 minutes ago"

# Prüfe Logs auf Connection-Probleme
conn_errors=$(journalctl -u debmatic-monitor-hb-rf-eth --since "$TIMEFRAME" --no-pager | grep -iE "connection.*failed|timeout|unreachable" || true)

if [[ -n "$conn_errors" ]]; then
    msg="WARNING: Connection issues detected in last $TIMEFRAME"
    curl -fsS "${KUMA_URL}/api/push/${key}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: ETH-Antenne communication healthy"
curl -fsS "${KUMA_URL}/api/push/${key}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
