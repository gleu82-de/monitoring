#!/bin/bash
set -euo pipefail

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

# Jetzt NUR die Services aus der Config verarbeiten
while IFS='=' read -r svc token; do
    # Token bereinigen
    token="${token%\"}"
    token="${token#\"}"

    echo "Checking: $svc"

    # Service-Status holen
    result=$(systemctl is-active "$svc" 2>/dev/null || echo "unknown")
    echo "Result: $result"
    
    case "$result" in
        active)        msg="OK: ${svc} is active" ;;
        inactive)      msg="CRITICAL: ${svc} is inactive" ;;
        failed)        msg="CRITICAL: ${svc} failed" ;;
        activating)    msg="CRITICAL: ${svc} is activating" ;;
        deactivating)  msg="CRITICAL: ${svc} is deactivating" ;;
        unknown)       msg="CRITICAL: ${svc} is unknown" ;;
        *)             msg="CRITICAL: ${svc} unknown state: $result" ;;
    esac

    url="${KUMA_URL}/api/push/${token}?status=up&msg=$(echo "$msg" | jq -sRr @uri)"
    echo "$url"
    curl -fsS "$url" || true

    echo "$msg"
done < <(grep 'service=' "$CONFIG")