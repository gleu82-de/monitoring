#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: Debmatic Log Analysis
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

TIMEFRAME="5 minutes ago"
ERROR_THRESHOLD=5

# Alle Debmatic Services prüfen
SERVICES=(
    "debmatic-rfd"
    "debmatic-rega"
    "debmatic-hmserver"
    "debmatic-hs485d"
    "debmatic-hssled"
    "debmatic-lighttpd"
    "debmatic-monitor-hb-rf-eth"
    "debmatic-multimacd"
    "debmatic-eq3configd"
    "debmatic-ssdpd"
)

error_count=0
errors=""

for service in "${SERVICES[@]}"; do
    count=$(journalctl -u "$service" --since "$TIMEFRAME" --no-pager -p err --quiet | wc -l)
    if [[ $count -gt 0 ]]; then
        error_count=$((error_count + count))
        errors+="$service: $count errors\n"
    fi
done

# Push to Kuma
if [[ $error_count -ge $ERROR_THRESHOLD ]]; then
    msg="CRITICAL: $error_count errors in last $TIMEFRAME"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_DEBMATIC_LOGS}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: $error_count errors in last $TIMEFRAME"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_DEBMATIC_LOGS}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
