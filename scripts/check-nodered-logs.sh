#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: Node-Red Log Analysis
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
ERROR_THRESHOLD=10

# Zähle ERROR-Level Logs (nicht DEBUG/INFO)
error_count=$(journalctl -u nodered --since "$TIMEFRAME" --no-pager | grep -E "\[ERROR\]" | wc -l || true)

if [[ $error_count -ge $ERROR_THRESHOLD ]]; then
    msg="CRITICAL: $error_count ERROR logs in last $TIMEFRAME"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_NODERED_LOGS}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: $error_count ERROR logs in last $TIMEFRAME"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_NODERED_LOGS}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
