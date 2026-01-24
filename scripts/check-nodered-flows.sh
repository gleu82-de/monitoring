#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: Node-Red Flow Errors (mit Blacklist)
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

TIMEFRAME="5min"
BLACKLIST="${SCRIPT_DIR}/../config/nodered-flow-blacklist.txt"

# Lade Blacklist (wenn vorhanden)
blacklist_pattern=""
if [[ -f "$BLACKLIST" ]]; then
    blacklist_pattern=$(grep -v '^#' "$BLACKLIST" | grep -v '^$' | tr '\n' '|' | sed 's/|$//')
fi

# Suche nach Flow-Fehlern in journald
flow_errors=$(journalctl -u nodered --since "$TIMEFRAME" --no-pager | grep -iE "flow.*error|flow.*failed" || true)

if [[ -n "$flow_errors" ]]; then
    # Filtere Blacklist
    if [[ -n "$blacklist_pattern" ]]; then
        flow_errors=$(echo "$flow_errors" | grep -vE "$blacklist_pattern" || true)
    fi
    
    if [[ -n "$flow_errors" ]]; then
        count=$(echo "$flow_errors" | wc -l)
        msg="CRITICAL: $count flow errors in last $TIMEFRAME"
        curl -fsS "${KUMA_URL}/api/push/${TOKEN_NODERED_FLOWS}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
        echo "$msg"
        exit 1
    fi
fi

msg="OK: No flow errors in last $TIMEFRAME"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_NODERED_FLOWS}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
