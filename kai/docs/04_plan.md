# Kai — Plan: Phasen, Aufgaben, Prüfungen

Stand: 2026-11-04 · Status: Vorschlag · Bezug: Sprint 01 in ClickUp (S1-xx), [01 Architektur](01_architektur.md)

## Phase 1 — Design, Architektur, Plan (dieser Branch `kai-design`)

| Ergebnis | Datei | Zustand |
|---|---|---|
| Architektur Stufe 1 + Ausblick Stufe 2, Entscheidungen | [01_architektur.md](01_architektur.md) | Entwurf |
| Anforderungen an Instanz, Platte, Netz, Zugang (für Uwe) | [02_anforderungen-infrastruktur.md](02_anforderungen-infrastruktur.md) | Entwurf |
| Modellvorschlag + Alternativen für Tests | [03_modellvorschlag.md](03_modellvorschlag.md) | Entwurf |
| Platzhalter für Geheimnisse | [../compose/.env.example](../compose/.env.example) | fertig |
| Bilder für Laien (SVG + PNG für ClickUp) | [bilder/](bilder/) | Entwurf |
| Dieser Plan | 04_plan.md | Entwurf |

Abnahme Phase 1: Uwe und Axel haben 01–03 gelesen; offene Punkte aus 02 (Zugangsweg, Volume, IAM) sind als ClickUp-Aufgaben erfasst; PR gemergt.

## Phase 2 — Skript-Entwicklung (Branch `kai-stack`)

Alles wird lokal bei Axel entwickelt und geprüft, ohne Maschine. Reihenfolge nach Abhängigkeit:

| # | Aufgabe | Prüfung ohne Maschine |
|---|---|---|
| 2.1 | **Prüf-Gate `check`** im Repo-Wurzelverzeichnis: `ansible-lint` (Profil `basic` wie bisher, später `production`), `yamllint`, `shellcheck` für Hilfsskripte, `docker compose config` gegen `.env.example`, `gitleaks` (Geheimnis-Scan). Ein Befehl, grün oder rot. Nach Vorbild `Software/agentic-ai-coding` (Lifecycle, `.githooks/pre-commit` ruft `check`) | läuft lokal |
| 2.2 | **Compose-Stack** `kai/compose/compose.yaml`: Dienste `open-webui`, `llama-swap`, `brave-mcp`; Netz `kai`; Volumes; `deploy.resources.reservations.devices` für die GPU; Images **gepinnt** (Tag + Digest); Healthchecks; `restart: unless-stopped`; `env_file: .env` | `docker compose config`; lokal ohne GPU `docker compose up open-webui brave-mcp` zum Rauchtest |
| 2.3 | **llama-swap-Konfiguration** `kai/compose/llama-swap.yaml`: Modell `gpt-oss-20b` aus [03](03_modellvorschlag.md), Platz für Alternativen, `healthCheckTimeout` groß genug für EBS-Ladezeit | YAML-Lint; Flag-Namen gegen llama.cpp-Doku (context7) |
| 2.4 | **Modell-Download-Skript** `kai/bin/kai-models-pull` (bash): lädt GGUFs aus einer Liste mit `curl -C -`, prüft sha256, legt sie nach `${KAI_MODELS_DIR}`; idempotent | `shellcheck`, Trockenlauf mit `--dry-run` |
| 2.5 | **Ansible-Rolle `kai_stack`**: `/opt/kai` anlegen (Volume-Mount prüfen oder einrichten), Compose-Dateien + llama-swap.yaml ausrollen (Templates mit `kai_webui_bind` etc.), `.env` **nur prüfen** (Abbruch mit Hinweis, wenn fehlt), Modelle über 2.4 holen, `docker compose up -d`, Healthcheck abwarten. `meta/main.yml` hängt an `docker`. Variablen in `defaults/main.yml` dokumentiert | `ansible-lint`, `make syntax`, Molecule/Container-Test optional |
| 2.6 | **Rollen `common`/`docker` an die AMI anpassen**: Docker ist vorinstalliert → Rolle darf nicht die NVIDIA-Toolkit-Integration kaputtmachen (`daemon.json` mit `nvidia`-Runtime zusammenführen statt überschreiben). Rolle `cmake` für `unserkai` abwählen | `ansible-lint`, Review |
| 2.7 | **Inventory**: `host_vars/unserkai.yml` auf SSM-Zugang umstellen (`ansible_ssh_common_args` mit `ProxyCommand aws ssm start-session …`), Benutzer `ubuntu` als Bootstrap; `site.yml` bekommt `kai_stack` für Gruppe `kai_hosts` | `make syntax`, `make ping` erst in Phase 3 |
| 2.8 | **Claude Code auf der Maschine**: kleine Rolle oder Task-Datei `claude_code`: Node.js LTS (NodeSource), `npm i -g @anthropic-ai/claude-code`, kein Key; Anleitung für Login und VSCode Remote-SSH über SSM in `kai/docs/05_admin-zugang.md` | Review |
| 2.9 | **Doku**: `ansible/README.md` um Kai erweitern; `kai/README.md` Kurzanleitung für Nutzer (S1-12) | Review |

Abnahme Phase 2: `./check` grün, PR gemergt, Uwe hat die Rollen gelesen.

## Phase 3 — Umsetzung auf der Maschine

Voraussetzung: Punkte aus [02 §7](02_anforderungen-infrastruktur.md) erfüllt, Snapshot „vor Installation“ existiert (S1-11).

| # | Schritt | Nachweis |
|---|---|---|
| 3.1 | `make ping` über SSM, `make check` (Dry-Run) | Ausgabe im PR-Kommentar |
| 3.2 | `make deploy TAGS=common,users,docker` | `nvidia-smi` im Container: `docker run --rm --gpus all nvidia/cuda:12.4.1-base-ubuntu22.04 nvidia-smi` |
| 3.3 | `.env` anlegen (Brave-Key, Secret), `make deploy TAGS=kai_stack` | `docker compose ps` alles `healthy`; `curl localhost:8080/v1/models` listet `gpt-oss-20b` |
| 3.4 | Erster Chat lokal: `curl` an `/v1/chat/completions`, dann Browser über SSM-Portweiterleitung | Antwort in < 60 s nach Kaltstart (S1-06) |
| 3.5 | Vier Konten anlegen, erstes Konto = Admin, Brave-MCP als Werkzeug registrieren, `ENABLE_SIGNUP=false` | Screenshot (S1-07) |
| 3.6 | Modell-Plausibilitätstest (10 deutsche Fragen + 2 Suchaufrufe), FP16-Risiko aus [03](03_modellvorschlag.md) | Tabelle in ClickUp |
| 3.7 | Snapshot „nach Installation“, Stop/Start-Test: kommt alles von selbst wieder? | Protokoll (S1-11) |
| 3.8 | Claude Code installieren, Login, VSCode-Remote testen | Protokoll |
| 3.9 | Übergabe an Uwe: Zugangsweg für Nutzer freischalten, vier Personen testen PC + Telefon (S1-09), vier parallele Anfragen messen (S1-10) | Messwerte in ClickUp |
| 3.10 | Installationsprotokoll + Abweichungen zurück in die Ansible-Rolle (S1-15), PR | gemergt |

## Arbeitsweise

- **Branches:** `kai-design` (Phase 1) → `kai-stack` (Phase 2) → `kai-deploy` (Protokolle/Fixes Phase 3). Kleine PRs, Uwe mergt.
- **Lokal bei Axel:** Repo unter `IT/Software/unserkai` (eigenes Git, vom IT-Repo ausgeschlossen). Gate `check` vor jedem Commit; Claude Code und it-check lokal. Ansible/yamllint/gitleaks lokal nachrüsten (Phase 2.1).
- **Später auf der Maschine:** dieselben Checks laufen dort (Node, Python-venv mit ansible-lint), damit Änderungen direkt auf der Maschine geprüft werden können.
- **Sprache:** Repo-Konvention Deutsch für Kai-Dokumente, Kommentare und Aufgaben-Namen; Variablennamen, Logausgaben und Dateinamen Englisch.
- **Geheimnisse:** nie im Git. `.env` nur auf der Maschine; Brave-Key und `WEBUI_SECRET_KEY` zusätzlich in der Team-KeePass (`unserkai.kdbx`).

## Offene Punkte (Entscheidung Uwe / Team)

1. Zugangsweg Nutzer: VPN-Technik oder öffentlich mit TLS ([02 §4](02_anforderungen-infrastruktur.md))
2. IAM-Rechte für Axel (SSM, Snapshot, Start/Stop) ([02 §5](02_anforderungen-infrastruktur.md))
3. Volume-Größe bestätigen (150 GB gp3) ([02 §2](02_anforderungen-infrastruktur.md))
4. Budget-Grenze für Betriebsstunden (S1-03)
5. Datenschutz-Regeln für den Prototyp festhalten (S1-04): wer ist Admin in Open WebUI, Aufbewahrung von Chats
