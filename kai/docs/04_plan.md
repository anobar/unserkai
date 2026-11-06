# Kai — Plan: Phasen, Aufgaben, Prüfungen

Stand: 2026-11-05 · Status: Vorschlag · Bezug: Sprint 01 in ClickUp (S1-xx), [01 Architektur](01_architektur.md)

## Phase 1 — Design, Architektur, Plan (dieser Branch `kai-design`)

| Ergebnis | Datei | Zustand |
|---|---|---|
| Architektur mit zwei Maschinen, Austauschbarkeit, Entscheidungen | [01_architektur.md](01_architektur.md) | Entwurf |
| Anforderungen an Instanzen, Platten, Netz, Zugang (für Uwe) | [02_anforderungen-infrastruktur.md](02_anforderungen-infrastruktur.md) | Entwurf |
| Modellvorschlag + Alternativen für Tests | [03_modellvorschlag.md](03_modellvorschlag.md) | Entwurf |
| Bestandsaufnahme der Einstiegs-Instanz `webui1` | [kai-entry_specs.md](kai-entry_specs.md) | erhoben 05.11. |
| Platzhalter für Geheimnisse | [../compose/entry/.env.example](../compose/entry/.env.example) | Phase 2 |
| Bilder für Laien (SVG + PNG für ClickUp) | [bilder/](bilder/) | Entwurf |
| Dieser Plan | 04_plan.md | Entwurf |

Abnahme Phase 1: Uwe und Axel haben 01–03 gelesen; offene Punkte aus 02 (Zugangsweg, Größe, Egress, Session-Rolle, DNS) sind als ClickUp-Aufgaben erfasst; PR gemergt.

## Phase 2.0 — Entwicklungsumgebung `kai-dev` und Test-VMs `kai-entry-pre`, `kai-gpu-pre`

Drei VMs in Axels Heimnetz, alle aus, wenn nicht gebraucht; ihre Einrichtung ist außerhalb dieses Repos dokumentiert, weil sie Interna des Heimnetzes enthält. Je AWS-Maschine eine Test-VM mit dem Image ihres Vorbilds. Keine GPU: alles mit `nvidia-smi`, echten Modellen und Antwortzeiten bleibt Phase 3.

| VM | Zweck | Bauweise |
|---|---|---|
| `kai-dev` | Entwicklungsumgebung: Clone dieses Repos, Claude Code, Prüf-Gate, Ansible-Steuerknoten, ab Phase 3 AWS-Zugang über SSM | Debian 13, abgeschottete Agenten-VM mit eigenem Netz und Egress-Allowlist. Werkzeuge aus Debian-Paketen: `ansible`, `ansible-lint`, `yamllint`, `shellcheck`, `shfmt`, `gitleaks`, `gh`, `docker-cli` mit Compose (nur `config`), `awscli`, `session-manager-plugin`; Claude Code mit GitHub-MCP (Token nur für den Fork) und ClickUp-MCP. Code geht als Branch in Axels Fork und von dort als Pull Request an dieses Repo |
| `kai-entry-pre` | Test-Ziel für den Entry-Stack, Abbild von `webui1` | Amazons Amazon-Linux-2023-Image für KVM (qcow2, dasselbe Release wie `webui1` aus der [Bestandsaufnahme §2](kai-entry_specs.md)), dazu Kernel 6.18 wie auf `webui1`, weil das KVM-Image nur 6.1 mitbringt; Maßstab ist, was Uwe in AWS bereitstellt, sonst AWS Best Practice, cloud-init über NoCloud-`seed.iso`: Benutzer `ec2-user` mit sudo und dem Key von `kai-dev`; wie `webui1` ohne Docker, damit die Rolle `docker` den Installationsweg zeigt; eine zusätzliche virtuelle Platte als Ersatz für das EBS-Volume `kai-data`. Versiegeltes Basis-Image, pro Testlauf ein frisches Overlay |
| `kai-gpu-pre` | Test-Ziel für den GPU-Stack, Abbild der GPU-AMI aus [02 §1.4](02_anforderungen-infrastruktur.md) | Image nach Uwes AMI-Wahl (beim AL2023-Vorschlag dasselbe KVM-Image wie `kai-entry-pre`, sonst das Cloud-Image des gewählten Systems), cloud-init mit dem Standardbenutzer der AMI; Docker und `nvidia-container-toolkit` vorinstalliert wie auf der AMI, mit `nvidia-ctk runtime configure --runtime=docker` (damit `daemon.json` den `nvidia`-Eintrag hat, den 2.9 nicht zerstören darf); eine zusätzliche virtuelle Platte als Ersatz für `kai-models`; `kai_gpu_enabled: false`, Modellliste mit dem kleinen CPU-Testmodell aus [03](03_modellvorschlag.md). Versiegeltes Basis-Image, pro Testlauf ein frisches Overlay |

Im Inventory steht `kai-entry-pre` in der Gruppe `kai_entry` und `kai-gpu-pre` in `kai_gpu`, beide mit normalem SSH statt SSM und sonst den Variablen ihrer Gruppe; `kai_gpu_endpoint` hat auf `kai-entry-pre` denselben Wert wie in AWS (`http://gpu.kai.internal:8080`): das Testnetz hat keinen DNS, die Test-VMs lösen `entry.kai.internal` und `gpu.kai.internal` über `/etc/hosts` auf, und für die Container trägt die Rolle die Namen über die Variable `kai_extra_hosts` als `extra_hosts` ein (in AWS leer, dort antwortet Route 53). Damit läuft die ganze Kette Open WebUI → LiteLLM → llama-swap → llama-server über zwei Maschinen ohne GPU durch, wie später in AWS. Die Adressen der Test-VMs stehen nur in `~/.ssh/config` von `kai-dev` und in einem gitignorierten Inventory-Overlay `ansible/inventory/local/` im Clone (Proxy, `kai_extra_hosts`), nicht im Repo.

Steuerung: `kai-dev` und die Test-VMs liegen im selben abgeschotteten Netz; der Agent in `kai-dev` verbindet sich selbst per SSH mit den Test-VMs und arbeitet dort mit sudo. Starten und Stoppen laufen über eine Anfrage-Datei, die der Hypervisor auswertet; `kai-dev` hat kein Konto auf dem Hypervisor.

| # | Aufgabe | Prüfung |
|---|---|---|
| 2.0.1 | `kai-dev` aufsetzen (Briefing außerhalb des Repos); erledigt 2026-11-04 | `gh auth status`, `ansible --version`, `aws --version`; `make -C ansible syntax lint` grün |
| 2.0.2 | AMI-Daten von Uwe für `kai-gpu`: AMI-Name, System und Release, Docker-Version, Toolkit-Version, NVIDIA-Treiber, Kernel (aus der laufenden oder geplanten Instanz: `cat /etc/os-release`, `docker version`, `nvidia-ctk --version`, `nvidia-smi`); für `kai-entry` stehen sie in der [Bestandsaufnahme](kai-entry_specs.md) | Werte in [02 §1](02_anforderungen-infrastruktur.md) eingetragen |
| 2.0.3 | `kai-entry-pre`: cloud-init-Definition, Basis-Image, Start/Stopp mit frischem Overlay | Start → SSH als `ec2-user` in < 30 s; `/etc/os-release` und `uname -r` wie auf `webui1`; kein Docker; leere Platte sichtbar; Stopp lässt das Basis-Image unverändert |
| 2.0.4 | `kai-gpu-pre`: dasselbe nach den AMI-Daten aus 2.0.2; beginnt, sobald Uwe die AMI gewählt hat | Start → SSH in < 30 s; `docker info` zeigt die Runtime `nvidia`; Docker-Version wie die AMI; leere Platte sichtbar |

Abnahme Phase 2.0: `make ping` aus `kai-dev` gegen beide Test-VMs grün.

## Phase 2 — Skript-Entwicklung (Branch `kai-stack`)

Alles wird in `kai-dev` entwickelt und geprüft, Rollen und Stacks laufen gegen `kai-entry-pre` und `kai-gpu-pre`. Reihenfolge nach Abhängigkeit:

| # | Aufgabe | Prüfung |
|---|---|---|
| 2.1 | **Prüf-Gate `check`** im Repo-Wurzelverzeichnis: `ansible-lint` (Profil `basic` wie bisher, später `production`), `yamllint`, `shellcheck` für Hilfsskripte, `docker compose config` für beide Stacks gegen ihre `.env.example`, `gitleaks` (Geheimnis-Scan), `git grep` auf private Adressbereiche nach RFC 1918, damit das Inventory-Overlay nie in einen Commit rutscht; `offline: true` in `ansible/.ansible-lint`, weil `kai-dev` Galaxy nicht erreicht. Ein Befehl, grün oder rot. Nach Vorbild `Software/agentic-ai-coding` (Lifecycle, `.githooks/pre-commit` ruft `check`) | läuft in `kai-dev` |
| 2.2 | **Entry-Stack** `kai/compose/entry/compose.yaml`: Dienste `open-webui`, `litellm`, `litellm-db`, `brave-mcp`; Netz `kai`; Daten unter `/opt/kai`; Open WebUI mit genau einer OpenAI-Verbindung auf `litellm`; Images **gepinnt** (Tag + Digest); Healthchecks; `restart: unless-stopped`; `env_file: .env`; `.env.example` mit allen Platzhaltern aus [01 Secrets](01_architektur.md) | `docker compose config`; auf `kai-entry-pre` `docker compose up` vollständig, alle Dienste `healthy` (keine GPU nötig) |
| 2.3 | **GPU-Stack** `kai/compose/gpu/compose.yaml`: Dienst `llama-swap` mit `deploy.resources.reservations.devices` (`driver: nvidia`, `count: all`), abschaltbar über `kai_gpu_enabled`; Port 8080 auf `kai_gpu_bind`; Bind-Mount `/opt/kai/models`; Image gepinnt; Healthcheck; `restart: unless-stopped` | `docker compose config`; auf `kai-gpu-pre` ohne GPU-Reservierung startet llama-swap, lädt das Testmodell auf der CPU |
| 2.4 | **llama-swap-Konfiguration** `kai/compose/gpu/llama-swap.yaml` als Template: Modelle aus der Liste in `group_vars`/`host_vars` (`gpt-oss-20b` aus [03](03_modellvorschlag.md), Testmodell für `kai-gpu-pre`), `healthCheckTimeout` groß genug für EBS-Ladezeit | YAML-Lint; Flag-Namen gegen llama.cpp-Doku (context7) |
| 2.5 | **LiteLLM-Konfiguration** `kai/compose/entry/litellm.yaml` als Template: `model_list` mit allen Modellen von `kai_gpu_endpoint` (Typ `openai/`), Master-Key und Datenbank aus `.env`, Platz für weitere Backends | `curl :4000/v1/models` listet die Modelle; von `kai-entry-pre` aus antwortet die ganze Kette Open WebUI → LiteLLM → llama-swap auf `kai-gpu-pre` mit dem Testmodell |
| 2.6 | **Modell-Download-Skript** `kai/bin/kai-models-pull` (bash): lädt GGUFs aus einer Liste mit `curl -C -`, prüft sha256, legt sie nach `${KAI_MODELS_DIR}`; idempotent | `shellcheck`, Trockenlauf mit `--dry-run`; echter Lauf auf `kai-gpu-pre` mit dem Testmodell |
| 2.7 | **Ansible-Rolle `kai_entry`**: Volume mit Label `kai-data` finden oder anlegen (Dateisystem + `fstab` per Label), `/opt/kai` einrichten, Compose + `litellm.yaml` ausrollen (Templates mit `kai_webui_bind`, `kai_litellm_bind`, `kai_gpu_endpoint`), `.env` **nur prüfen** (Abbruch mit Hinweis, wenn fehlt), `docker compose up -d`, Healthcheck abwarten. `meta/main.yml` hängt an `docker`. Variablen in `defaults/main.yml` dokumentiert | `ansible-lint`, `make syntax`; `make deploy TAGS=kai_entry` gegen frisches `kai-entry-pre`, zweiter Lauf `changed=0`; Abbruch ohne `.env` geprüft |
| 2.8 | **Ansible-Rolle `kai_gpu`**: Volume mit Label `kai-models` finden oder anlegen, `/opt/kai/models` einrichten, Compose + `llama-swap.yaml` ausrollen, Modelle über 2.6 holen, `docker compose up -d`, Healthcheck abwarten. `meta/main.yml` hängt an `docker` | `ansible-lint`, `make syntax`; `make deploy TAGS=kai_gpu` gegen frisches `kai-gpu-pre`, zweiter Lauf `changed=0`; `curl :8080/v1/models` listet das Testmodell |
| 2.9 | **Rollen `common`/`users`/`docker` an beide Systeme anpassen** (heute `apt`-basiert): `kai-entry` ist Amazon Linux 2023 ohne Docker → Pakete über `dnf` (`git`, `tmux`, `htop`), sudo über Gruppe `wheel`, Paket `docker` aus dem AL2023-Repo, Compose-Plugin als gepinnte Binärdatei von GitHub (Version + sha256) nach `/usr/libexec/docker/cli-plugins`, Dienst aktiv, Benutzer in Gruppe `docker`; `kai-gpu` folgt Uwes AMI (Docker und Toolkit vorinstalliert) → Rolle ersetzt Docker nicht und führt `daemon.json` mit der Runtime `nvidia` zusammen statt zu überschreiben; hat die GPU-AMI ein anderes System, bekommt die Rolle den zweiten Paketweg über `ansible_os_family`. Variable `kai_http_proxy` (Standard leer, in AWS leer): wenn gesetzt, schreibt die Rolle den Proxy für `dnf`, als Drop-in für `docker.service` (mit `NO_PROXY` für das Testnetz und `.kai.internal`) und in die Compose-`.env` für Container, die ins Internet gehen; so laufen die Test-VMs hinter dem Egress-Proxy des Heimnetzes mit denselben Rollen. Rolle `cmake` für Kai abwählen | `ansible-lint`; `kai-entry-pre`: nach `make deploy TAGS=common,users,docker` läuft `docker compose version`; `kai-gpu-pre`: `daemon.json` enthält weiterhin die Runtime `nvidia`, `docker version` unverändert |
| 2.10 | **Inventory nach Rolle**: Gruppen `kai_entry` (Hosts `kai-entry`, `kai-entry-pre`) und `kai_gpu` (Hosts `kai-gpu`, `kai-gpu-pre`); Benutzerliste nach `group_vars/all.yml`; Stack-Variablen in `group_vars/kai_entry.yml` und `kai_gpu.yml`; `host_vars/kai-entry.yml` und `kai-gpu.yml` nur mit Instanz-ID, `ansible_ssh_common_args` (`ProxyCommand aws ssm start-session … --document-name AWS-StartSSHSession`), Benutzer `ec2-user` und Maschinendaten (VRAM, Modellliste, Kontext); `host_vars/kai-entry-pre.yml` und `kai-gpu-pre.yml` nur mit `ansible_user` und `kai_gpu_enabled: false` (`kai_gpu_endpoint` bleibt der Gruppenwert); private Werte der Test-VMs (`kai_http_proxy`, `kai_extra_hosts`) in einem zweiten, gitignorierten Inventory `ansible/inventory/local/`, das das Makefile als weiteres `-i` anhängt, wenn es existiert; Host `unserkai` entfällt; `playbooks/site.yml` mit je einem Play pro Gruppe | `make syntax`; `make ping` gegen `kai-entry-pre` und `kai-gpu-pre` (SSH); SSM-Weg erst in Phase 3 |
| 2.11 | **Claude Code auf `kai-entry`**: kleine Rolle oder Task-Datei `claude_code`: Node.js LTS aus dem AL2023-Repo (`nodejs22`), `npm i -g @anthropic-ai/claude-code`, kein Key; Anleitung für Login und VSCode Remote-SSH über SSM in `kai/docs/05_admin-zugang.md` | Review |
| 2.12 | **Doku**: `ansible/README.md` um Kai erweitern; `kai/README.md` Kurzanleitung für Nutzer (S1-12) | Review |

Abnahme Phase 2: `./check` grün, beide Stacks auf frischen Test-VMs zweimal durchgelaufen (zweiter Lauf `changed=0`), Kette mit Testmodell antwortet, PR gemergt, Uwe hat die Rollen gelesen.

## Phase 3 — Umsetzung auf den Maschinen

Voraussetzung: Punkte aus [02 §8](02_anforderungen-infrastruktur.md) erfüllt, Snapshot „vor Installation“ von `kai-data` existiert (S1-11).

| # | Schritt | Nachweis |
|---|---|---|
| 3.1 | `make ping` über SSM gegen beide Maschinen, `make check` (Dry-Run) | Ausgabe im PR-Kommentar |
| 3.2 | **kai-entry:** `make deploy LIMIT=kai-entry TAGS=common,users,docker`; `.env` anlegen (Brave-Key, `WEBUI_SECRET_KEY`, LiteLLM-Keys, Postgres-Passwort); `make deploy LIMIT=kai-entry TAGS=kai_entry` | `docker compose ps` alles `healthy`; `curl localhost:4000/v1/models` antwortet (Modelle gelistet, Backend noch aus) |
| 3.3 | **kai-gpu:** Instanz starten, `make deploy LIMIT=kai-gpu` | `docker run --rm --gpus all nvidia/cuda:13.0.0-base-ubuntu24.04 nvidia-smi` zeigt die T4; `curl localhost:8080/v1/models` listet `gpt-oss-20b`; von `kai-entry` aus: `curl http://gpu.kai.internal:8080/v1/models` (DNS und Security Group) |
| 3.4 | Erster Chat über LiteLLM: `curl` an `localhost:4000/v1/chat/completions` mit Master-Key, dann Browser über SSM-Portweiterleitung auf 3000 | Antwort in < 60 s nach Kaltstart (S1-06) |
| 3.5 | Vier Konten anlegen, erstes Konto = Admin, Brave-MCP als Werkzeug registrieren, `ENABLE_SIGNUP=false`; in LiteLLM ein Key für Open WebUI, Keys für Harnesses erst bei Bedarf | Screenshot (S1-07) |
| 3.6 | Modell-Plausibilitätstest (10 deutsche Fragen + 2 Suchaufrufe), FP16-Risiko aus [03](03_modellvorschlag.md) | Tabelle in ClickUp |
| 3.7 | Snapshot „nach Installation“ von `kai-data`; Stop/Start-Test `kai-gpu`: bei gestoppter GPU-Maschine bleibt Open WebUI nutzbar und meldet das Modell als nicht erreichbar; nach dem Start antwortet der Chat ohne Eingriff auf `kai-entry` | Protokoll (S1-11) |
| 3.8 | Claude Code auf `kai-entry` installieren, Login, VSCode-Remote testen | Protokoll |
| 3.9 | Übergabe an Uwe: Zugangsweg für Nutzer freischalten, vier Personen testen PC + Telefon (S1-09), vier parallele Anfragen messen (S1-10) | Messwerte in ClickUp |
| 3.10 | Installationsprotokoll + Abweichungen zurück in die Rollen (S1-15), PR | gemergt |
| 3.11 | **Wechsel-Probe (Kann):** `kai-gpu` einmal durch eine neue Instanz aus derselben AMI ersetzen, Volume `kai-models` umhängen, DNS nachziehen, `make deploy LIMIT=kai-gpu` | Dauer gemessen gegen die Tabelle in [01 §3](01_architektur.md); Abweichungen in die Rollen |

## Arbeitsweise

- **Branches:** `kai-design` (Phase 1) → `kai-stack` (Phase 2) → `kai-deploy` (Protokolle/Fixes Phase 3). Kleine PRs, Uwe mergt.
- **Fork:** Der Agent pusht nur in Axels Fork; Axel prüft dort und öffnet den Pull Request an dieses Repo. Direkte Commits hierher erst nach Absprache mit Uwe.
- **In `kai-dev`:** Clone dieses Repos, VSCode per Remote-SSH. Gate `check` vor jedem Commit; Claude Code, Ansible, yamllint, gitleaks und `gh` liegen in `kai-dev` (Phase 2.0). Das AWS-Profil kommt erst in Phase 3 dazu und liegt nur dort; Brave-Key, `WEBUI_SECRET_KEY` und LiteLLM-Keys nie in `kai-dev`.
- **Test-Ziele `kai-entry-pre` und `kai-gpu-pre`:** jeder Deployment-Test startet auf frischem Overlay; das Stoppen gehört zu jedem Test, auch nach einem Fehlschlag.
- **Maschinenwechsel:** nie auf einer Maschine von Hand reparieren, was die Rolle nicht auch auf einer frischen Maschine herstellt; jede Abweichung geht zurück in die Rolle. Das hält die Regel aus [01 §3](01_architektur.md) ein.
- **Später auf `kai-entry`:** dieselben Checks laufen dort (Node, Python-venv mit ansible-lint); die Werkzeugliste von `kai-dev` ist die Vorlage dafür.
- **Sprache:** Repo-Konvention Deutsch für Kai-Dokumente, Kommentare und Aufgaben-Namen; Variablennamen, Logausgaben und Dateinamen Englisch.
- **Geheimnisse:** nie im Git. `.env` nur auf `kai-entry`; Brave-Key, `WEBUI_SECRET_KEY` und LiteLLM-Master-Key zusätzlich in der Team-KeePass (`unserkai.kdbx`).

## Offene Punkte (Entscheidung Uwe / Team)

1. Zugangsweg Nutzer: VPN-Technik oder öffentlich mit TLS ([02 §5](02_anforderungen-infrastruktur.md))
2. `kai-entry`: `webui1` auf `t3.medium` und Root 30 GB vergrößern, Volume `kai-data` anhängen, Tag `kai:role=entry` ([02 §1, §2](02_anforderungen-infrastruktur.md))
3. Egress für beide Maschinen: NAT-Gateway oder öffentliche IPv4 ohne Inbound ([02 §3](02_anforderungen-infrastruktur.md))
4. Session-Rolle um `AWS-StartSSHSession` erweitern, Axels Key per user-data, Klartext-Passwort aus dem Terraform-Code ([02 §6](02_anforderungen-infrastruktur.md))
5. Private DNS-Zone `kai.internal` mit `entry` und `gpu`; Security Groups per Gruppenreferenz ([02 §4](02_anforderungen-infrastruktur.md))
6. `kai-gpu` anlegen (Vorschlag: Deep Learning Base GPU AMI für Amazon Linux 2023, `g4dn`-Unterstützung der Ausgabe prüfen), AMI-Daten melden (2.0.2), Volume `kai-models` 150 GB bestätigen
7. Budget-Grenze für Betriebsstunden von `kai-gpu` und den Dauerbetrieb von `kai-entry` (S1-03)
8. Datenschutz-Regeln für den Prototyp festhalten (S1-04): wer ist Admin in Open WebUI, Aufbewahrung von Chats, ob und wann externe Modelle über LiteLLM freigegeben werden
