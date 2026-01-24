#!/bin/bash
set -euo pipefail

# Uptime Kuma Monitor: HomeMatic Duty Cycle Threshold
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

THRESHOLD=80  # Prozent

# TODO: Ermittle Duty Cycle über HomeMatic API
# Mögliche Quellen:
# - CCU ReGa Script über ccu-jack
# - debmatic-rfd Statistik
# - Node-Red Endpoint

# Placeholder Implementation
duty_cycle=0

# Beispiel: Hole Wert von einem Node-Red Endpoint (wenn implementiert)
# duty_cycle=$(curl -s http://localhost:1880/api/duty-cycle || echo 0)

if [[ $duty_cycle -ge $THRESHOLD ]]; then
    msg="CRITICAL: Duty Cycle at ${duty_cycle}% (threshold: ${THRESHOLD}%)"
    curl -fsS "${KUMA_URL}/api/push/${TOKEN_DUTY_CYCLE}?status=down&msg=$(echo "$msg" | jq -sRr @uri)" || true
    echo "$msg"
    exit 1
fi

msg="OK: Duty Cycle at ${duty_cycle}% (threshold: ${THRESHOLD}%)"
curl -fsS "${KUMA_URL}/api/push/${TOKEN_DUTY_CYCLE}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true
echo "$msg"
exit 0
