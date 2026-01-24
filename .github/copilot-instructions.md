# Monitoring - Copilot Instructions

## Working Rules & Communication Protocol
This code is the developer's code. The code is not owned ba the Agent! The Agent needs to include the developer as much as reasonable. All decisions, file creations and changes need to be confirmed by the developer! The Agent ist instructed to include him. All upcoming questions need to be discussed first. The Agent should make reasonable suggestions. If one decision is made, the agent should follow it consistently without asking again until no other options are left.

**Core Principle**: This is the developer's codebase. You are a tool and apprentice. Always ask for permission before making changes, even when you have more knowledge. The developer makes all final decisions.

### Development & Deployment Workflow
1. **Environment Layout**:
   - **DEV** (192.168.3.47): Development machine - current workspace `/home/dgl/Projekte/monitoring`
   - **PROD** (192.168.2.1): Production server running HomeMatic/Debmatic infrastructure
   - **NAS** (192.168.2.10): QNAP backup destination (nur aktiv bei Backup)
   - **ETH-Antenne** (192.168.2.2): HomeMatic Ethernet-Funkantenne
   - **Wired Gateway** (192.168.2.3): HomeMatic Wired Gateway
   - All use `/etc/hosts` aliases: `DEV`, `PROD`, `NAS`

2. **DEV-PROD Separation**: Changes are developed on DEV, then deployed to PROD via `bin/deploy.sh`

3. **PROD is Read-Only**: Never modify PROD directly without explicit permission. Investigation is allowed, changes are not.

4. **Terminal Discipline**: 
   - Always open new terminals on DEV (recognizable by prompt: `DEV ~/Projekte/monitoring$`)
   - **When any action on PROD or NAS is needed**: First switch interactively (`ssh dgl@PROD` or `ssh dgl@NAS`), then execute commands there
   - **NEVER use**: `ssh dgl@PROD "command"` or `ssh dgl@NAS "command"` - no exceptions, not even for read-only operations
   - **Reason**: Terminal background color (green=DEV, red=PROD, blue=NAS) is the user's primary visual indicator. Commands execute quickly and can be complex/multi-line. The user needs the color-coded context to follow along and verify actions in real-time. Remote command execution from DEV removes this crucial visual orientation.

5. **Deployment Process**: Use only `bin/deploy.sh` script after consultation with the developer

### Code Conventions
5. **No Defensive Programming**: Never use fallback values or coalescing (`a = b || c || undefined`). If a value is wrong, let it fail.
6. **Concise Conditionals**: Use one-liners for simple statements: `if [[ $error ]]; then echo "Error"; fi`
7. **New Files Require Approval**: Always ask before creating new files
8. **File Organization**:
   - Instructions: `instructions/*.md`
   - Test files: `test/` (delete when no longer needed; keep if reusable)

### Communication Requirements
10. **Explain Before Acting**: Describe your intended changes and wait for approval before executing
11. **Always check the results of your commands before proceeding**: After running commands, summarize the output and confirm correctness before moving on
12. **Ask if Unsure**: If you are uncertain about any aspect, always ask the developer for clarification before proceeding.
13. **Do not interrupt your own commands with ^C unless this is not wanted**: Do not stop commands unless explicitly wated by the agent or developer.
14. **Do not fire additional commands if the previous one is still running**: Wait for commands to finish before issuing new ones.
15. **If you use sleep, wait for the sleep command before continuing**: Do not skip sleep durations; wait for them to complete.

### 2. Credential Management
All sensitive data (passwords, passphrases) comes from **KeePassXC** via `keepassxc-cli`.

**KRITISCH - KeePassXC-Zugriff:**
- Die IT.kdbx MUSS IMMER mit dem Master-Passwort UND der Keyfile geöffnet werden
- Das Master-Passwort liegt verschlüsselt in systemd-credentials: `/etc/keepass-it.password`
- NIEMALS `--no-password` verwenden - das funktioniert NICHT!
- Nutze IMMER das Wrapper-Script `/usr/local/bin/kp-show` (existiert auf PROD)

**Wrapper-Script Nutzung:**
```bash
# Alle Einträge listen
kp-show ls

# Passwort holen (default)
BORG_PASS=$(kp-show show NAS/borg-prod-passphrase)

# Username holen
PUSHOVER_USER=$(kp-show show Pushover/backup-app --username)

# Kompletten Eintrag anzeigen
kp-show show NAS/admin-dgl --full
```

**Manuelle Nutzung (nur wenn kp-show nicht verfügbar):**
```bash
KPPASS=$(sudo systemd-creds decrypt /etc/keepass-it.password)
export BORG_PASSPHRASE=$(keepassxc-cli show -k /etc/.keepassXC/it.key \
  -s /home/keepass/IT.kdbx NAS/borg-prod-passphrase <<< "$KPPASS" 2>/dev/null \
  | grep '^Password:' | cut -d' ' -f2)
```

**Never hardcode secrets. Always use KeePassXC via kp-show wrapper.**

## PROD Infrastructure

### Services Overview
All services run on PROD (192.168.2.1) via systemd, except where noted.

**Uptime Kuma (Monitoring)**
- Manager: PM2 (as root user)
- Command: `sudo pm2 list` to show status
- Port: 3001 (localhost)
- Version: 2.0.1
- Installation: `/opt/uptime-kuma/`
- PID: Check with `sudo pm2 show uptime-kuma`

**Node-Red (Automation)**
- Service: `nodered.service` (systemd)
- User: dgl
- Ports: 1880 (UI), 1881, 8980, 2058
- Config: `/home/dgl/.node-red/`
- Scripts: `/home/dgl/.node-red/bin/`
- Logs: journald (`journalctl -u nodered`)
- Service file: `/usr/lib/systemd/system/nodered.service`

**ccu-jack (HomeMatic Bridge)**
- Service: `ccu-jack.service` (systemd)
- Port: 2058 (JSON-RPC)
- Installation: `/opt/ccu-jack/addon/`
- Logs: `/var/log/ccu-jack/ccu-jack.log`
- Depends on: `debmatic-rega.service`
- Service file: `/etc/systemd/system/ccu-jack.service`

**Debmatic Services (HomeMatic)**
All systemd services, managed by system:
- `debmatic-rfd.service` - Radio Frequency Daemon (Funkmodul)
- `debmatic-rega.service` - Logic Engine (Skript-Engine)
- `debmatic-hmserver.service` - HomeMatic Server
- `debmatic-hs485d.service` - HS485 Daemon (Wired-Bus)
- `debmatic-hssled.service` - Status-LED Daemon
- `debmatic-lighttpd.service` - WebUI Server
- `debmatic-monitor-hb-rf-eth.service` - ETH-Antenne Monitor
- `debmatic-multimacd.service` - Multi-MAC Daemon
- `debmatic-eq3configd.service` - eQ-3 Config Daemon
- `debmatic-ssdpd.service` - SSDP Discovery Daemon

Logs: journald (`journalctl -u debmatic-<service>`)

### Monitoring Strategy
**Kuma Native Monitors (no custom scripts needed):**
- Ping: ETH-Antenne (192.168.2.2), Wired Gateway (192.168.2.3)
- HTTP: ccu-jack (port 2058), Node-Red (port 1880)
- systemd: all debmatic-services, nodered.service

**Custom Scripts Required (1 script = 1 monitor):**
- Log analysis: Debmatic, ccu-jack, Node-Red
- Node-Red flow errors (mit Blacklist)
- Communication check: ETH-Antenne, Wired Gateway (beyond ping)
- Duty Cycle threshold alerts