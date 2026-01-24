# Uptime Kuma Setup Guide

## 1. Push Monitors in Kuma erstellen

Für jedes Script muss ein **Push Monitor** in Kuma angelegt werden:

1. Öffne Kuma: http://PROD:3001
2. Klicke auf "Add New Monitor"
3. Wähle "Monitor Type": **Push**
4. Konfiguriere jeden Monitor:

### Monitor 1: Debmatic Logs
- **Friendly Name**: `Debmatic Logs`
- **Monitor Type**: Push
- **Heartbeat Interval**: 300 (5 Minuten)
- **Retries**: 1
- Nach dem Speichern: **Push URL kopieren** → Token extrahieren

### Monitor 2: ccu-jack Logs
- **Friendly Name**: `ccu-jack Logs`
- **Monitor Type**: Push
- **Heartbeat Interval**: 300
- **Retries**: 1

### Monitor 3: Node-Red Logs
- **Friendly Name**: `Node-Red Logs`
- **Monitor Type**: Push
- **Heartbeat Interval**: 300
- **Retries**: 1

### Monitor 4: Node-Red Flow Errors
- **Friendly Name**: `Node-Red Flow Errors`
- **Monitor Type**: Push
- **Heartbeat Interval**: 300
- **Retries**: 1

### Monitor 5: ETH-Antenne Communication
- **Friendly Name**: `ETH-Antenne Communication`
- **Monitor Type**: Push
- **Heartbeat Interval**: 600 (10 Minuten)
- **Retries**: 1

### Monitor 6: Wired Gateway Communication
- **Friendly Name**: `Wired Gateway Communication`
- **Monitor Type**: Push
- **Heartbeat Interval**: 600
- **Retries**: 1

### Monitor 7: Duty Cycle
- **Friendly Name**: `HomeMatic Duty Cycle`
- **Monitor Type**: Push
- **Heartbeat Interval**: 300
- **Retries**: 1

## 2. Tokens extrahieren

Nach dem Erstellen jedes Monitors zeigt Kuma eine Push URL:
```
http://localhost:3001/api/push/ABC123XYZ?status=up&msg=OK
```

Der Token ist der Teil zwischen `/push/` und `?`:
```
ABC123XYZ
```

## 3. Konfigurationsdatei anpassen

Trage die Tokens in `/opt/monitoring/config/kuma.conf` ein:

```bash
# Auf PROD
sudo nano /opt/monitoring/config/kuma.conf
```

Ersetze alle `REPLACE_WITH_TOKEN` mit den tatsächlichen Tokens:
```bash
TOKEN_DEBMATIC_LOGS="ABC123XYZ"
TOKEN_CCU_JACK_LOGS="DEF456UVW"
# usw...
```

## 4. Cron Jobs einrichten

Füge auf PROD die Monitoring-Scripts zu cron hinzu:

```bash
sudo crontab -e
```

Trage ein:
```cron
# Monitoring Scripts (alle 5 Minuten)
*/5 * * * * /opt/monitoring/scripts/check-debmatic-logs.sh >> /var/log/monitoring/debmatic-logs.log 2>&1
*/5 * * * * /opt/monitoring/scripts/check-ccu-jack-logs.sh >> /var/log/monitoring/ccu-jack-logs.log 2>&1
*/5 * * * * /opt/monitoring/scripts/check-nodered-logs.sh >> /var/log/monitoring/nodered-logs.log 2>&1
*/5 * * * * /opt/monitoring/scripts/check-nodered-flows.sh >> /var/log/monitoring/nodered-flows.log 2>&1
*/10 * * * * /opt/monitoring/scripts/check-eth-antenna-comm.sh >> /var/log/monitoring/eth-antenna.log 2>&1
*/10 * * * * /opt/monitoring/scripts/check-wired-gateway-comm.sh >> /var/log/monitoring/wired-gateway.log 2>&1
*/5 * * * * /opt/monitoring/scripts/check-duty-cycle.sh >> /var/log/monitoring/duty-cycle.log 2>&1
```

Log-Verzeichnis erstellen:
```bash
sudo mkdir -p /var/log/monitoring
```

## 5. Manuelles Testen

Nach dem Deployment kannst du jedes Script einzeln testen:

```bash
# Auf PROD
sudo /opt/monitoring/scripts/check-debmatic-logs.sh
```

Das Script gibt aus:
- Die Statusmeldung
- Pusht das Ergebnis an Kuma
- Kuma sollte den Monitor sofort aktualisieren

## 6. Kuma-API Format

Die Scripts nutzen die Kuma Push API:
```bash
curl "http://localhost:3001/api/push/{TOKEN}?status={up|down}&msg={message}"
```

- `status=up`: Monitor grün (OK)
- `status=down`: Monitor rot (Fehler)
- `msg=...`: Nachricht (URL-encoded)
