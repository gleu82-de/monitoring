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

key='TOKEN_ETH_ANTENNA'
token=$(grep "^${key}=" "$CONFIG" | cut -d= -f2 | tr -d '"')
token="${token%\"}"
token="${token#\"}"
echo "$token"

ANTENNA_IP="192.168.2.2"
TIMEFRAME="10 minutes ago"

# Prüfe Logs auf Connection-Probleme
conn_errors=$(journalctl -u debmatic-monitor-hb-rf-eth --since "$TIMEFRAME" --no-pager | grep -iE "connection.*failed|timeout|unreachable" || true)

if [[ -n "$conn_errors" ]]; then
    msg="WARNING: Connection issues detected in last $TIMEFRAME"
    curl -fsS "${KUMA_URL}/api/push/${token}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

# Prüfung, ob tatsächlich bidirektionale Kommunikation stattfindet
set -euo pipefail

ANTENNA_IP="192.168.2.2"
INTERFACE="enp0s31f6"
DURATION=10
TMPFILE="/tmp/ethantenne-tcpdump-output.txt"

echo "Prüfe Kommunikation mit ETH-Antenne ($ANTENNA_IP) für $DURATION Sekunden..."

# tcpdump ausführen
set +e
sudo timeout "$DURATION" tcpdump -l -n -q -i "$INTERFACE" host "$ANTENNA_IP" and udp > "$TMPFILE" 2>&1
rc=${PIPESTATUS[0]}
set -e

if [[ $rc -ne 0 && $rc -ne 124 ]]; then
    echo "FEHLER: tcpdump fehlgeschlagen (Exit-Code $rc)"
    rm -f "$TMPFILE"
    exit 1
fi

# Pakete zählen
TOTAL=$(grep "packets captured" "$TMPFILE" | head -1 | awk '{print $1}' || echo "0")

# Pakete von Antenne zum Server zählen
FROM_ANTENNA=$(grep -c "$ANTENNA_IP\.[0-9]* > " "$TMPFILE" 2>/dev/null || echo "0")

# Pakete vom Server zur Antenne zählen
TO_ANTENNA=$(grep -c " > $ANTENNA_IP\.[0-9]*:" "$TMPFILE" 2>/dev/null || echo "0")

rm -f "$TMPFILE"
# Auswertung
if [[ "$TOTAL" -eq 0 ]] || [[ "$FROM_ANTENNA" -eq 0 ]] || [[ "$TO_ANTENNA" -eq 0 ]]; then
    msg="CRITICAL: ETH-Antenne communication failure"
else
    msg="OK: ETH-Antenne communication healthy"
fi
curl -fsS "${KUMA_URL}/api/push/${token}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0