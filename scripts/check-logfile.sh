#!/bin/bash
set -euo pipefail

# Service-Name als Parameter
SERVICE_NAME="$1"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG="${SCRIPT_DIR}/../config/kuma.conf"

# Fehlersuchwörter
ERROR_KEYWORDS=(
    "error"
    "failed"
    "failure"
    "exception"
    "critical"
    "fatal"
    "panic"
    "alert"
)

# Zeitfenster in Minuten
MINUTES=25

# Prüfen, ob Service angegeben wurde
if [ -z "$SERVICE_NAME" ]; then
    echo "ERROR: Kein Service angegeben"
    echo "Verwendung: $0 <service-name>"
    exit 1
fi

# Config-Datei prüfen
if [[ ! -f "$CONFIG" ]]; then
    echo "ERROR: Config file $CONFIG not found"
    exit 1
fi

# KUMA_URL extrahieren
KUMA_URL=$(grep '^KUMA_URL=' "$CONFIG" | cut -d= -f2 | tr -d '"')

# Token für diesen Service aus Config holen
# Suche nach TOKEN_<SERVICENAME>_LOGS=
TOKEN_KEY=$(echo "${SERVICE_NAME}" | tr '[:lower:].-' '[:upper:]__' | sed 's/\.SERVICE$//')
TOKEN_VAR="TOKEN_${TOKEN_KEY}_LOGS"
TOKEN=$(grep "^${TOKEN_VAR}=" "$CONFIG" 2>/dev/null | cut -d= -f2 | tr -d '"' || echo "")

if [ -z "$TOKEN" ]; then
    echo "ERROR: Kein Token gefunden für $TOKEN_VAR in $CONFIG"
    exit 1
fi

echo "Checking logs for: $SERVICE_NAME"
echo "Token variable: $TOKEN_VAR"

# Regex-Pattern aus Array erstellen
PATTERN=$(IFS='|'; echo "${ERROR_KEYWORDS[*]}")

# Versuche Logfile zu finden, sonst verwende journalctl
LOGFILE=""

# Typische Logfile-Pfade für bekannte Services
case "$SERVICE_NAME" in
    ccu-jack.service|ccu-jack)
        for path in "/var/log/ccu-jack.log" "/opt/ccu-jack/ccu-jack.log"; do
            [ -f "$path" ] && LOGFILE="$path" && break
        done
        ;;
    debmatic*.service|debmatic*)
        SERVICE_BASE=$(echo "$SERVICE_NAME" | sed 's/debmatic-//;s/.service$//')
        for path in "/var/log/debmatic/${SERVICE_BASE}.log" "/var/log/${SERVICE_NAME}.log"; do
            [ -f "$path" ] && LOGFILE="$path" && break
        done
        ;;
    nodered.service|nodered)
        for path in "/var/log/nodered.log" "/home/nodered/.node-red/nodered.log"; do
            [ -f "$path" ] && LOGFILE="$path" && break
        done
        ;;
    mariadb.service|mariadb)
        for path in "/var/log/mysql/error.log" "/var/log/mariadb/mariadb.log"; do
            [ -f "$path" ] && LOGFILE="$path" && break
        done
        ;;
    dovecot.service|dovecot)
        LOGFILE="/var/log/mail.log"
        ;;
    postfix*|postfix)
        LOGFILE="/var/log/mail.log"
        ;;
esac

# Fehlersuche durchführen
if [ -n "$LOGFILE" ] && [ -f "$LOGFILE" ]; then
    echo "Using logfile: $LOGFILE"
    THRESHOLD=$(date -d "$MINUTES minutes ago" "+%Y-%m-%d %H:%M:%S")
    
    ERRORS=$(awk -v threshold="$THRESHOLD" '
        $0 ~ /^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2}/ {
            timestamp = $1 " " $2
            if (timestamp >= threshold) print $0
        }
        $0 !~ /^[0-9]{4}-[0-9]{2}-[0-9]{2}/ {
            print $0
        }
    ' "$LOGFILE" 2>/dev/null | grep -iE "$PATTERN" || echo "")
else
    echo "No logfile found, using journalctl"
    ERRORS=$(journalctl -u "$SERVICE_NAME" --since "$MINUTES minutes ago" --no-pager 2>/dev/null | \
             grep -iE "$PATTERN" || echo "")
fi

# Ergebnis auswerten und an Kuma melden
if [ -z "$ERRORS" ]; then
    STATUS="up"
    MSG="OK: No errors in ${SERVICE_NAME} logs (last ${MINUTES} min)"
    echo "$MSG"
else
    STATUS="down"
    ERROR_COUNT=$(echo "$ERRORS" | wc -l)
    MSG="CRITICAL: ${ERROR_COUNT} error(s) found in ${SERVICE_NAME} logs"
    echo "$MSG"
    echo "First error:"
    echo "$ERRORS" | head -1
fi

# An Kuma Push Monitor senden
URL="${KUMA_URL}/api/push/${TOKEN}?status=${STATUS}&msg=$(echo "$MSG" | jq -sRr @uri)"
curl -fsS "$URL" || echo "WARNING: Failed to send to Kuma"

# Exit-Code setzen
if [ "$STATUS" = "up" ]; then
    exit 0
else
    exit 1
fi