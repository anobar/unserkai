# Kai — Zugang zu Open WebUI (bis das VPN steht)

Open WebUI lauscht auf `webui1` nur auf `127.0.0.1:3000`. Bis Uwe das VPN einrichtet ([02 §5](02_anforderungen-infrastruktur.md)), kommt man über einen SSH-Tunnel durch AWS SSM dran. Der Tunnel ist spürbar zäh; `webui1` selbst antwortet in wenigen Millisekunden.

## Einmalig

1. Werkzeuge auf dem eigenen Rechner: AWS-CLI v2, das Session-Manager-Plugin und `ssh` (macOS: `brew install awscli` und `brew install --cask session-manager-plugin`).
2. Ein eigenes AWS-Profil mit einer Rolle, die `ssm:StartSession` mit dem Dokument `AWS-StartSSHSession` auf `webui1` darf; das Profil richtet Uwe ein.
3. Ein eigener Benutzer auf `webui1` mit dem eigenen öffentlichen SSH-Schlüssel (Rolle `users`, Liste in `ansible/inventory/group_vars/all.yml`).
4. Ein Konto in Open WebUI; das Startpasswort kommt vom Admin und wird nach der ersten Anmeldung unter **Settings → Account** geändert.

## Jedes Mal

```bash
kai/bin/kai-gpu --profile PROFILNAME --instance-id i-0f896ee21e1ae8c72 start   # kai1 starten (kostet im Betrieb)
kai/bin/kai-tunnel --profile PROFILNAME                                         # Tunnel öffnen
```

- `PROFILNAME` ist der Name des eigenen AWS-Profils, nicht wörtlich abschreiben.
- `kai-tunnel` fragt erst die AWS-Sitzung ab (dabei kommt gegebenenfalls die MFA-Abfrage), danach die Passphrase des SSH-Schlüssels; beides gleichzeitig scheitert.
- Es nimmt den ersten freien Port ab 3000 und schreibt die Adresse hin, etwa `http://localhost:3000`; diese Adresse im Browser **auf demselben Rechner** öffnen.
- Das Terminal bleibt offen und zeigt nichts weiter; Strg+C beendet den Tunnel.
- Danach `kai/bin/kai-gpu --profile PROFILNAME --instance-id i-0f896ee21e1ae8c72 stop`.

Die erste Antwort nach dem Start von `kai1` kann noch etwa 1,5 Minuten dauern, solange das Modell von der Platte lädt; llama-swap lädt es inzwischen schon beim Start vor.

## Ohne Skript

```bash
aws sts get-caller-identity --profile PROFILNAME
ssh -N -L 3000:127.0.0.1:3000 \
  -o ProxyCommand="aws ssm start-session --profile PROFILNAME --region eu-central-1 --target %h --document-name AWS-StartSSHSession --parameters portNumber=%p" \
  BENUTZER@i-0f6dc684ea90b09cf
```

Ist Port 3000 auf dem eigenen Rechner belegt, `-L 3001:127.0.0.1:3000` und `http://localhost:3001`. Darf die eigene Rolle zusätzlich `AWS-StartPortForwardingSession`, geht es ohne SSH-Schlüssel mit `aws ssm start-session … --document-name AWS-StartPortForwardingSession --parameters '{"portNumber":["3000"],"localPortNumber":["3000"]}'`.
