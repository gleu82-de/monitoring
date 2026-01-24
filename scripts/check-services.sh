get_config() {
    local service="$1"
    local line token

    # Zeile aus Config holen
    line=$(grep -F "^$service=" "$CONFIG" || true)

    # Wenn nichts gefunden → leeres Token zurückgeben
    if [[ -z "$line" ]]; then
        echo ""
        return
    fi

    # Rechts vom = extrahieren
    token="${line#*=}"

    # Anführungszeichen entfernen
    token="${token%\"}"
    token="${token#\"}"

    echo "$token"
}




SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/kuma.conf"
if [[ -f "$CONFIG_FILE" ]]; then
    CONFIG="$CONFIG_FILE"
else
    echo "ERROR: Config file $CONFIG_FILE not found"
    exit 1
fi

KUMA_URL=$(get_config "KUMA_URL" || true)
echo "KUMA_URL: $KUMA_URL"


for svc in $(systemctl list-unit-files --type=service --no-legend --no-pager | awk '{print $1}'); do
    if [[ "$svc" == "postfix@-.service" ]]; then
        svc=postfix.service
    fi
    token=$(get_config "$svc" || true)
    # Services ohne Token überspringen
    if [[ -z "$token" ]]; then
        continue
    fi
    echo "$svc"

    # Service-Status holen
    result=$(systemctl is-active "$svc" || true)

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
    curl -fsS "${KUMA_URL}/api/push/${token}?status=up&msg=$(echo "$msg" | jq -sRr @uri)" || true

    echo "$msg"
done
