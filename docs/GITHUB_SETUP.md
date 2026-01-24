# GitHub Setup Guide

## 1. GitHub Repository erstellen

Auf GitHub ein neues Repository erstellen:
- Name: `monitoring`
- Private/Public: nach Wahl
- Keine README/LICENSE hinzufügen (lokal bereits vorhanden)

## 2. Repository verknüpfen

```bash
cd /home/dgl/Projekte/monitoring
git remote add origin git@github.com:didiator/monitoring.git
git branch -M main
git push -u origin main
```

## 3. GitHub Secret einrichten

Im GitHub Repository:
1. Gehe zu: **Settings** → **Secrets and variables** → **Actions**
2. Klicke auf **New repository secret**
3. Name: `PROD_SSH_KEY`
4. Value: Privater SSH-Key für PROD-Zugriff

SSH-Key auf DEV generieren/anzeigen:
```bash
# Falls noch kein Key existiert:
ssh-keygen -t ed25519 -C "github-actions-monitoring"

# Key anzeigen und kopieren:
cat ~/.ssh/id_ed25519
```

Dann den Public Key auf PROD hinterlegen:
```bash
ssh dgl@PROD
mkdir -p ~/.ssh
nano ~/.ssh/authorized_keys
# Füge den Public Key hinzu (cat ~/.ssh/id_ed25519.pub auf DEV)
chmod 600 ~/.ssh/authorized_keys
```

## 4. Erstes Deployment

```bash
./bin/deploy.sh
```

Das Script wird:
1. Nach der Version fragen (Standard: v1.0.1)
2. Nach einem optionalen Kommentar fragen
3. Änderungen committen
4. Tag erstellen und pushen
5. GitHub Release erstellen
6. GitHub Actions überwachen
7. PROD-Version verifizieren

## 5. Workflow-Ablauf

**Bei jedem Deployment:**
1. Lokale Änderungen machen
2. `./bin/deploy.sh` ausführen
3. GitHub Actions deployt automatisch nach PROD
4. Root-Symlink `/root/monitoring` wird erstellt

**Ordnerstruktur auf PROD:**
```
/home/dgl/monitoring/          # Deployed via GitHub Actions
├── scripts/
├── config/
├── bin/
├── docs/
└── VERSION

/root/monitoring -> /home/dgl/monitoring/  # Symlink für Cron
```

## 6. Manuelle Verifikation

Nach dem Deployment auf PROD prüfen:
```bash
ssh dgl@PROD
cat ~/monitoring/VERSION
ls -la /root/monitoring
/root/monitoring/scripts/check-duty-cycle.sh
```
