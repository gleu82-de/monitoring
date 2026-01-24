#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: ccu-jack Log Analysis
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

LOGFILE="/var/log/ccu-jack/ccu-jack.log"
TIMEFRAME_MIN=5
ERROR_PATTERNS="ERROR|FATAL|Exception"

if [[ ! -f "$LOGFILE" ]]; then
    msg="ERROR: Logfile $LOGFILE not found"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_CCU_JACK_LOGS}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

# Prüfe Log-Einträge der letzten X Minuten
cutoff_time=$(date -d "$TIMEFRAME_MIN minutes ago" '+%Y-%m-%d %H:%M:%S')
errors=$(awk -v cutoff="$cutoff_time" '$0 >= cutoff' "$LOGFILE" | grep -iE "$ERROR_PATTERNS" || true)

if [[ -n "$errors" ]]; then
    count=$(echo "$errors" | wc -l)
    msg="CRITICAL: $count errors in last ${TIMEFRAME_MIN}min"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_CCU_JACK_LOGS}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: No errors in last ${TIMEFRAME_MIN}min"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_CCU_JACK_LOGS}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
