# AGENTS.md

Gestalte die Datei `AGENTS.md` als prägnanten Gedächtnisstützpunkt für zukünftige Agenten-Sitzungen – eher eine Landkarte als ein Handbuch. Sie sollte enthalten: eine kurze Beschreibung der Anwendung, eine Übersicht der Befehle sowie – gegliedert nach Funktionsbereichen – Verweise auf die wichtigsten Dateien. Ergänzend dazu gehören nur jene Aspekte, bei denen ein Agent selbst nach Lektüre dieser Dateien noch Fehler machen könnte: tückische Fallstricke, dateiübergreifende Invarianten oder strikte Verbote. Informationen, die sich durch das Lesen der verlinkten Dateien ohnehin erschließen lassen, haben hier keinen Platz. Jeder Punkt sollte aus genau einem Satz bestehen. Schließe mit einer Wartungsregel für dich, den Agenten: Aktualisiere diese Datei stets im selben Änderungssatz (Change Set), sobald eine Änderung eine Zeile hinfällig macht oder eine kostspielige Lektion erteilt hat. Bevorzuge dabei das Löschen gegenüber dem Hinzufügen und Verweise gegenüber ausführlichen Erklärungen. Jeder Punkt umfasst einen Satz; abgebildet wird ausschließlich der aktuelle Stand, keine Historie.

## Was das ist

Gemeinsames Infrastruktur-Repo von Uwe, Axel, Nic und Martin: AWS-Grundlage mit Terraform/Terragrunt, Ansible für die Linux-Maschinen und Kai, ein privater KI-Chat auf zwei AWS-Instanzen: `kai-entry` (Open WebUI, LiteLLM, Brave-MCP; läuft durch) und `kai-gpu` (llama-swap mit llama.cpp; nur bei Bedarf an); Überblick in `kai/README.md`, Architektur in `kai/docs/01_architektur.md`, Vorgehen in `kai/docs/04_plan.md`.

## Befehle

- `make -C ansible syntax` — Syntaxcheck ohne Verbindung; `make -C ansible lint` — ansible-lint mit Profil `basic` aus `ansible/.ansible-lint`.
- `make -C ansible ping|check|deploy [TAGS=a,b] [LIMIT=host]` — Verbindungstest, Dry-Run mit Diff, Anwenden.
- `./check` im Wurzelverzeichnis wird das eine Prüf-Gate (ansible-lint, yamllint, shellcheck, `docker compose config`, gitleaks) und läuft dann vor jedem Commit über `.githooks/pre-commit`; solange es fehlt, gelten `syntax` und `lint` (Plan 2.1).

## Bereiche

- `bootstrap/`, `aws/` — Terraform/Terragrunt für Konto, IAM, VPC, Route 53; das ist Uwes Bereich, Agenten lesen dort nur.
- `ansible/` — Rollen `common`, `users`, `docker`, `cmake`, bald `kai_entry` und `kai_gpu`; Gruppen `kai_entry`/`kai_gpu` in `ansible/inventory/hosts.yml`, Variablen in `group_vars`, in `host_vars` nur Instanz-ID, Zugang und Maschinendaten (Plan 2.10).
- `kai/compose/` — zwei Stacks `entry/` und `gpu/` mit je einer `.env.example`; `kai/docs/` — Architektur, Anforderungen an die Instanzen, Modellwahl, Plan, Bestandsaufnahme `kai-entry_specs.md`.

## Stolperfallen

- Alle Kai-Maschinen tragen Debian 13 (offizielles Debian-Image, Benutzer `admin`, Kernel `cloud-amd64`), also sprechen die Rollen nur `apt` wie im Heim-Setup: Docker CE aus Dockers Repo, auf `kai-gpu` Treiber und Container Toolkit aus NVIDIAs CUDA-Repo mit gepinntem Zweig (`nvidia-driver-pinning-*`), und die Runtime `nvidia` kommt über `docker_daemon_config` in die `daemon.json` der Rolle `docker`, nie per `nvidia-ctk`, damit die Datei genau einen Schreiber hat (Plan 2.8, 2.9).
- `kai-entry` erreicht `kai-gpu` nur über den DNS-Namen in `kai_gpu_endpoint`; nie eine IP ins Repo, in `litellm.yaml` oder eine Compose-Datei (Architektur E11).
- Die Volumes `kai-data` (kai-entry) und `kai-models` (kai-gpu) werden per Dateisystem-Label gemountet, nie per Gerätenamen (Architektur E4).
- `.envrc` setzt `AWS_PROFILE=unserkai-terraform`, also läuft mit aktivem direnv jeder `aws`-Aufruf im Repo mit dem Terraform-Profil; Aufrufe für Kai (SSM) nennen ihr Profil ausdrücklich.
- Images im Compose-Stack sind mit Tag und Digest gepinnt; ein Update ändert beides im selben Commit.
- Deployment-Tests laufen gegen die Inventory-Hosts `kai-entry-pre` (Gruppe `kai_entry`) und `kai-gpu-pre` (Gruppe `kai_gpu`), zwei VMs ohne GPU im Heimnetz, die je das Image ihrer AWS-Maschine tragen (`kai_gpu_enabled: false`, kleines CPU-Testmodell); eine Änderung an Rollen gilt erst als fertig, wenn die frische Test-VM zweimal durchläuft und der zweite Lauf `changed=0` meldet; private Werte der Test-VMs (Proxy, Hosts-Einträge, Adressen) stehen nur im gitignorierten Inventory-Overlay `ansible/inventory/local/` und in `~/.ssh/config` von `kai-dev`, nie in `host_vars` (Plan 2.10).
- Maßstab für Rollen und Test-VMs ist das Debian-13-Image, das Uwe in AWS bereitstellt (Build laut `kai/docs/02_anforderungen-infrastruktur.md` §1.2), nie „das aktuellste Image“; wo das offen lässt, folgen die Rollen dem Muster des Heim-Setups und AWS-Eigenes (SSM, EBS, IAM) der AWS Best Practice.
