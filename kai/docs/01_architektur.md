# Kai — Architektur und Design (Stufe 1 und Ausblick)

Stand: 2026-11-04 · Status: Entwurf zur Abstimmung · Autor: Axel (mit Claude Code)

Dieses Dokument beschreibt, **was** auf der gemeinsamen KI-Maschine läuft, **warum** es so gebaut wird und **wie** die Teile zusammenhängen. Es ist die Grundlage für die Skripte (Phase 2) und die Umsetzung (Phase 3). Für Nicht-Techniker gibt es die Bilder in [bilder/](bilder/) und die Kurzfassung in der [README](../README.md).

Verwandt: [02 Anforderungen an die Infrastruktur](02_anforderungen-infrastruktur.md) · [03 Modellvorschlag](03_modellvorschlag.md) · [04 Plan](04_plan.md)

---

## 1. Ziel und Rahmen

- **Ziel Stufe 1:** Ein Chat für vier Personen (Uwe, Axel, Nic, Martin) mit einem lokal laufenden Sprachmodell auf einer gemieteten GPU-Maschine in AWS. Erster Durchstich, nutzbar vom PC und Telefon. Dazu Websuche als erstes Werkzeug (Brave).
- **Nicht-Ziele Stufe 1:** Messenger-Anbindung, mehrere Modell-Endpunkte, Dauerbetrieb, Hochverfügbarkeit, Nutzung privater Hardware.
- **Vorbild:** Axels Heim-Setup (`lezki` = GPU-Rechenknoten mit llama.cpp hinter llama-swap, `mcps` = Open WebUI als Frontend). Abweichungen hier:
  - keine VM mit GPU-Passthrough, sondern AWS-Instanz mit dedizierter GPU;
  - alles in **Docker-Containern** statt nativer Installation (reproduzierbar, austauschbar, Snapshot-freundlich);
  - Verteilung über **Ansible** (Konvention dieses Repos), eine Rolle `kai_stack` rollt den Compose-Stack aus.

## 2. Zielbild Stufe 1: alles auf einer Maschine

```
Internet ──VPN/Zugangsregel (Uwe)──▶ ┌──────────────── EC2 g4dn.xlarge (NVIDIA T4, 16 GB) ────────────────┐
                                    │                                                                    │
  Browser (PC, Telefon)  ─────────▶ │  [open-webui]  :3000  ── OpenAI-API ──▶ [llama-swap] :8080         │
                                    │       │                                     │ startet/stoppt        │
                                    │       │ MCP (Streamable HTTP)               ▼                       │
                                    │       └──────────────────────────▶ [llama-server] (GPU, Modell X)   │
                                    │                                                                    │
                                    │  [brave-mcp]  :8000  ── HTTPS ──▶ api.search.brave.com (extern)     │
                                    │                                                                    │
                                    │  Volumes: open-webui-data · models (GGUF) · llama-swap-config       │
                                    └────────────────────────────────────────────────────────────────────┘
```

### Komponenten

| Container | Image (Vorschlag, in Phase 2 gepinnt) | Aufgabe | Port (nur intern) |
|---|---|---|---|
| `open-webui` | `ghcr.io/open-webui/open-webui:<version ≥ 0.6.31>` | Chat-Oberfläche, Benutzerkonten, Chat-Verlauf, Dokumente, Werkzeug-Anbindung | 3000 |
| `llama-swap` | `ghcr.io/mostlygeek/llama-swap:unified-cuda13` (enthält `llama-server`) | OpenAI-kompatibler Endpunkt; lädt das angefragte Modell bei Bedarf, entlädt bei Wechsel | 8080 |
| `brave-mcp` | `docker.io/mcp/brave-search` (oder `brave/brave-search-mcp-server`), Transport `http` | Websuche als MCP-Werkzeug für Open WebUI | 8000 |

Begründungen:

- **llama-swap statt nacktem llama-server:** mit 16 GB VRAM passt genau ein Modell. llama-swap erlaubt trotzdem mehrere Modelle in der Auswahl von Open WebUI und wechselt beim ersten Aufruf (gleiches Muster wie auf lezki). Spätere Modelltests (S1-02, [03](03_modellvorschlag.md)) brauchen dann keine Umkonfiguration. Das `unified-cuda13`-Image bringt `llama-server` mit, also ein Container weniger.
- **Open WebUI mit nativem MCP:** seit 0.6.31 spricht Open WebUI MCP über Streamable HTTP direkt. Der Brave-Server unterstützt `http`-Transport, also entfällt der Umweg über `mcpo`. Werkzeuge werden vom Admin registriert (Admin → Settings → External Tools → Typ „MCP (Streamable HTTP)“) und für alle Benutzer freigegeben.
- **Kein eigener Reverse-Proxy in Stufe 1:** Zugang und TLS legt Uwe fest (VPN oder Load Balancer). Der Stack lauscht nur auf `127.0.0.1` bzw. im Docker-Netz; was von außen erreichbar ist, entscheidet die Infrastruktur, nicht der Stack. Siehe [02](02_anforderungen-infrastruktur.md) Punkt 4.

### Netz und Ports

- Alle Container hängen in einem Compose-Netz `kai`. Nur `open-webui` veröffentlicht einen Host-Port, und zwar auf `127.0.0.1:3000`. Öffnung nach außen (VPN, Proxy, Security Group) ist Aufgabe der Infrastruktur.
- `llama-swap` und `brave-mcp` sind nur aus dem Docker-Netz erreichbar. Die Verwaltungsendpunkte von llama-swap (`/running`, `/unload`, `/logs`, Web-UI) bleiben damit intern. Für Admin-Blicke: `ssh`/SSM-Portweiterleitung oder `docker compose exec`.
- Ausgehend: Hugging Face (Modell-Download), ghcr.io/Docker Hub (Images), api.search.brave.com (Suche), Ubuntu-Spiegel (Updates). Alles andere darf die Security Group blocken.

### Daten und Persistenz

| Daten | Ort | Wächst? | Sicherung |
|---|---|---|---|
| Benutzerkonten, Chat-Verlauf, hochgeladene Dokumente, Einstellungen | Volume `open-webui-data` (`/app/backend/data`, SQLite + Dateien) | ja, langsam | EBS-Snapshot der Instanz (S1-11) |
| Modelldateien (GGUF) | Bind-Mount `/opt/kai/models` | pro Modell 5–15 GB | **nicht** nötig: wiederbeschaffbar; Snapshot nimmt sie trotzdem mit |
| llama-swap-Konfiguration, Compose, `.env` | `/opt/kai/` (von Ansible verwaltet) | nein | im Git (außer `.env`) |

Ein Sprachmodell **speichert nichts**. Was gespeichert wird (Chats, Uploads), liegt in `open-webui-data` auf der EBS-Platte in Frankfurt; Zugriff darauf hat, wer Admin in Open WebUI ist oder Root auf der Maschine. Das ist die Antwort auf die Datenschutz-Frage aus dem Meeting vom 02.11.; sie ist bei S1-04 festzuhalten.

### Secrets

- Nur ein echtes Geheimnis in Stufe 1: der **Brave-API-Key**. Dazu Open WebUIs `WEBUI_SECRET_KEY` (signiert Sitzungen; zufällig erzeugt).
- Ablage: `/opt/kai/.env` auf der Maschine, Rechte `0600 root`, **nicht** im Git. Im Repo liegt nur [`compose/.env.example`](../compose/.env.example) mit Platzhaltern. Compose liest `.env` automatisch; der Brave-Container bekommt den Key per `env_file`, nicht auf der Kommandozeile (sonst steht er in `docker inspect` und der Shell-History).
- Ansible kopiert `.env` **nicht**; die Rolle prüft nur, dass die Datei existiert, und bricht sonst mit Hinweis ab. So bleibt das Repo frei von Geheimnissen und die sops/KeePass-Konvention des Repos unberührt.

### Ressourcen auf g4dn.xlarge

| Ressource | Vorhanden | Verbraucher |
|---|---|---|
| GPU-Speicher | 16 GB (T4) | Modell ~11 GB + KV-Cache für Kontext; siehe [03](03_modellvorschlag.md) |
| RAM | 16 GB | Open WebUI ~1 GB, llama-swap/llama-server ~1–2 GB (mmap des Modells zählt als Page-Cache), Docker, OS |
| vCPU | 4 | Prompt-Vorverarbeitung läuft auf der GPU; CPU ist unkritisch |
| Platte | Root-EBS der AMI (klein) + **eigenes Volume für `/opt/kai`** | Images ~8 GB, 2–3 Modelle ~30 GB, Daten |

## 3. Betrieb Stufe 1

- **Start/Stop manuell** (Uwe). Beim Start kommen die Container mit `restart: unless-stopped` von selbst hoch; das erste Modell lädt beim ersten Chat (Dauer: 10–40 s von der EBS-Platte).
- **Updates:** Images sind auf Versionen gepinnt; ein Update ist eine Änderung im Git + `ansible-playbook` (Phase 2 regelt `make deploy`). Keine `latest`-Tags.
- **Snapshots:** vor der Erstinstallation und an Meilensteinen (S1-11). Weil alles in `/opt/kai` und den Volumes liegt, reicht ein EBS-Snapshot der Platte; eine Wiederherstellung ist „Volume aus Snapshot + `docker compose up`“.
- **Logs:** `docker compose logs`; llama-swap zeigt Modellwechsel und Lade-Dauer. Keine zentrale Log-Sammlung in Stufe 1.
- **Administration über Claude Code:** Node.js und `claude` werden nativ auf der Maschine installiert (nicht im Container), Login mit Axels Abo. Steuerung aus VSCode: Remote-SSH über SSM-ProxyCommand (`aws ssm start-session --document-name AWS-StartSSHSession`), darin die Claude-Code-Extension. Voraussetzungen stehen in [02](02_anforderungen-infrastruktur.md) Punkt 5.

## 4. Ausblick Stufe 2: Oberfläche und Rechenknoten trennen

Das Muster von lezki/mcps, übertragen auf AWS:

```
                 ┌── kleine Dauer-VM (t4g/t3.small) ───────────┐
Nutzer ──VPN──▶  │ [open-webui] [brave-mcp] [weitere MCP]      │
                 └──────────────┬───────────┬──────────────────┘
                                │           │ OpenAI-API
                   ┌────────────▼───┐  ┌────▼───────────────┐  ┌──────────────────────┐
                   │ GPU-VM A (T4)  │  │ GPU-VM B (größer,  │  │ optional: externe    │
                   │ llama-swap     │  │ nur bei Bedarf an) │  │ API mit Pseudonymis. │
                   └────────────────┘  └────────────────────┘  └──────────────────────┘
```

- Die kleine VM läuft durch (Kosten gering), hält Konten und Verlauf. GPU-VMs werden an- und abgeschaltet; Open WebUI zeigt dann ehrlich „Modell antwortet nicht“ statt dass alles weg ist.
- Open WebUI kann mehrere OpenAI-Verbindungen; jede GPU-VM ist eine. Modellwahl bleibt für Nutzer ein Dropdown.
- **Was Stufe 1 dafür schon richtig macht:** Open WebUI spricht den Modellserver ausschließlich über die OpenAI-API an einer konfigurierbaren URL an (`OPENAI_API_BASE_URLS`). Der Umzug ist später ein Umbiegen dieser URL plus Verschieben des Volumes, kein Umbau.
- Nicht Teil dieses Dokuments: Kostenmodell, Umschaltlogik, Pseudonymisierung externer Dienste (offene Punkte aus dem Meeting).

## 5. Entscheidungen (Kurzliste)

| # | Entscheidung | Alternative, verworfen weil |
|---|---|---|
| E1 | Docker Compose für alle Dienste | native Installation wie auf lezki: schwerer reproduzierbar, Snapshot/Umzug aufwändiger |
| E2 | llama-swap + llama.cpp (ein Image) | Ollama (im Repo-Verlauf): weniger Kontrolle über Quantisierung/Kontext, kein Harmony/Jinja-Feintuning; vLLM: braucht mehr VRAM für gleiche Modelle |
| E3 | Natives MCP in Open WebUI | mcpo-Proxy: ein Container mehr, nur nötig für stdio-Server |
| E4 | Ein Volume `/opt/kai` für Modelle + Daten + Config | alles auf Root-EBS: AMI-Root ist klein, Snapshot vermischt OS und Daten |
| E5 | Stack lauscht nur lokal, Zugang regelt Infrastruktur | Caddy/Traefik im Stack: doppelt, solange VPN/Zugangsweg nicht feststeht |
| E6 | `.env` nur auf der Maschine, `.env.example` im Git | sops-verschlüsselt im Git: möglich, aber zweiter Geheimnis-Pfad neben KeePass; später bei Bedarf |
| E7 | Ansible-Rolle `kai_stack` rollt Compose aus | reines Compose-Verzeichnis ohne Ansible: bricht die Repo-Konvention; Doku-Installation von Hand: wurde im Meeting als Zwischenstand akzeptiert, Ansible soll aber folgen (S1-15) |
