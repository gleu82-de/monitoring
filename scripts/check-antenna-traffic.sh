#!/bin/bash
set -euo pipefail

# Parameter
ANTENNA_IP="192.168.2.2"
INTERFACE="enp0s31f6"  # ggf. anpassen!
DURATION=10

echo "Starte tcpdump für $DURATION Sekunden auf $INTERFACE für $ANTENNA_IP ..."

# Mitschnitt in temporäre Datei
PCAP_FILE=$(mktemp /tmp/ethantenne-tcpdump-XXXXXX.pcap)
sudo timeout "$DURATION" tcpdump -i "$INTERFACE" host "$ANTENNA_IP" and udp -w "$PCAP_FILE"

# Auswertung: Wurden Pakete aufgezeichnet?
COUNT=$(tcpdump -nn -r "$PCAP_FILE" 2>/dev/null | wc -l)

if [[ "$COUNT" -gt 0 ]]; then
    echo "OK: Es wurden $COUNT UDP-Pakete zwischen Host und ETH-Antenne ($ANTENNA_IP) aufgezeichnet."
    RESULT=0
else
    echo "WARNUNG: Keine UDP-Kommunikation mit ETH-Antenne ($ANTENNA_IP) in $DURATION Sekunden festgestellt!"
    RESULT=1
fi

# Aufräumen
rm -f "$PCAP_FILE"
exit $RESULT