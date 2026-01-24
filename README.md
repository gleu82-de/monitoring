# Monitoring Setup for PROD

Uptime Kuma Monitoring-Konfiguration für HomeMatic/Debmatic Infrastruktur.

## Architektur

- **DEV** (192.168.3.47): Entwicklungsumgebung
- **PROD** (192.168.2.1): Produktionsserver mit Services
- **Uptime Kuma**: Port 3001 (localhost), verwaltet via PM2

## Monitored Services

### Kuma Native Monitors (ohne Scripts)
- **Ping**: ETH-Antenne (192.168.2.2), Wired Gateway (192.168.2.3)
- **HTTP**: ccu-jack (2058), Node-Red (1880)
- **systemd**: debmatic-*, nodered.service

### Custom Script Monitors
Jedes Script = ein Kuma Monitor (Script-Type)

| Script | Monitor | Beschreibung |
|--------|---------|--------------|
| check-debmatic-logs.sh | Debmatic Logs | Analysiert journald-Logs auf Fehler |
| check-ccu-jack-logs.sh | ccu-jack Logs | Prüft /var/log/ccu-jack/ccu-jack.log |
| check-nodered-logs.sh | Node-Red Logs | Analysiert journald-Logs |
| check-nodered-flows.sh | Flow Errors | Fehlerhafte Flows (mit Blacklist) |
| check-eth-antenna-comm.sh | ETH-Antenne Comm | Kommunikationsprüfung |
| check-wired-gateway-comm.sh | Wired Gateway Comm | Kommunikationsprüfung |
| check-duty-cycle.sh | Duty Cycle | Schwellwert-Alarm |

## Deployment

```bash
# Von DEV nach PROD deployen
./bin/deploy.sh
```

## Kuma Konfiguration

TODO: Detaillierte Anleitung zur Konfiguration der einzelnen Monitore in Uptime Kuma
