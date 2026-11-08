# Kai — Vorschlag an Uwe: `kai1` stoppt nach Leerlauf und startet bei Bedarf

Stand: 08.11.2026, vorbereitet, nicht umgesetzt. Entscheidung und AWS-Seite liegen bei Uwe; die Rollen bauen erst danach.

## Anlass

- Beim Testdeployment am 07./08.11.2026 lief die AWS-Sitzung zweimal ab, während `kai1` lief; gestoppt werden konnte die Maschine erst, als Axel eine neue Sitzung hatte.
- `kai1` kostet im Betrieb ≈ 0,66 $/h ([02 §7.2](02_anforderungen-infrastruktur.md)); eine vergessene Nacht kostet mehr als ein Monat Root-Volume.
- Heute hängen Starten und Stoppen an einem Menschen mit gültiger Sitzung ([01 §4](01_architektur.md)).

## Ausgangslage: Kaltstart

| Phase | Dauer | Quelle |
|---|---|---|
| `start-instances` bis Kernel läuft | ≈ 45 s | SSM-Agent ≈ 1 min nach Start online, abzüglich Boot ([Bestandsaufnahme §1](instance_specs.md)) |
| Boot bis `graphical.target` | 12 s | gemessen 07.11. |
| Docker, llama-swap, GPU-Init | wenige s | geschätzt |
| Modell laden (12–13 GB bei ≈ 125 MB/s) | ≈ 100 s | gemessen 08.11.: 98 s (S1-06) |
| **Summe bis zum ersten Token** | **≈ 2,5–3 min** | nicht als Ganzes gemessen |

- Nach Stop/Start bootet das OS immer kalt, meist auf einem anderen Host; RAM, VRAM und Instance Storage sind leer, EBS-Volumes und private IP bleiben, `kai1.unserkai.de` stimmt also weiter.
- **EC2-Hibernation scheidet aus:** AWS unterstützt sie für keine G-Familie und nicht für Debian ([Voraussetzungen](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/hibernating-prerequisites.html)); sie sichert ohnehin nur RAM, nicht VRAM, und das Zurücklesen liefe über dieselbe EBS-Bandbreite wie das Modell.
- Warm Pools bringen für eine einzelne Maschine nichts (Zustand „Stopped“ ist unser Stop/Start, „Hibernated“ braucht Hibernation); das Instance Storage ist nach jedem Stopp leer.
- Engpass ist die EBS-Bandbreite: die g4dn.xlarge schafft 118,75 MB/s dauerhaft und 437,5 MB/s als Burst (30 min je 24 h), gp3 liefert ohne Aufpreis 125 MB/s.

## Vorschlag

### 1. Stoppen nach Leerlauf

| Stufe | Wer | Was | Wirkung |
|---|---|---|---|
| A | Rolle `kai_gpu` | systemd-Timer prüft alle 5 min die letzte Anfrage und fährt nach 30 min ohne Anfrage mit `systemctl poweroff` herunter | Stopp nach etwa 30 min Leerlauf |
| C | Uwe (Terraform) | CloudWatch-Alarm mit EC2-Aktion „Stop“: CPU-Maximum < 5 % in 6 Perioden à 5 min | Netz außerhalb der Maschine, fängt auch einen hängenden Timer oder eine hängende Maschine; ≈ 0,10 $/Monat |
| B | Uwe (Terraform), nur falls C nicht gewünscht | EventBridge-Scheduler stoppt `kai1` jede Nacht um 02:00 Europe/Zurich | grobes Netz, greift erst nachts |

Stufe A im Detail:

- **Leerlauf-Signal, bevorzugt:** Zeitstempel der letzten Anfrage aus `GET http://127.0.0.1:8080/api/metrics/activity` von llama-swap; `ttl` bleibt 0, das Modell bleibt bis zum Stopp geladen. Ob das gepinnte Image den Endpunkt hat, prüft ein `curl` auf `kai1`.
- **Rückfall, falls der Endpunkt fehlt:** `ttl: 1800` in `kai_gpu_models`, `GET /running` (`{"running": [...]}`) zweimal hintereinander leer heißt Leerlauf; Nachteil: eine Anfrage kurz vor dem Stopp lädt das Modell neu (≈ 100 s).
- **Skript `kai-gpu-idle-stop`** unter `/usr/local/sbin`; keine Antwort von llama-swap zählt nicht als Leerlauf, damit ein hängender Container die Maschine nicht stoppt; nicht vor 20 min Laufzeit, damit ein Start ohne Anfrage nicht sofort endet.
- **Schalter:** `kai_gpu_idle_stop: false` als Vorgabe, `kai_gpu_idle_stop_minutes: 30`; auf `kai-gpu-pre` bleibt es aus.
- **Warum `poweroff` statt AWS-API:** keine IAM-Rechte für `ec2:StopInstances` nötig; bei EBS-gestützten Instanzen heißt Herunterfahren „stopped“, solange `instance_initiated_shutdown_behavior` auf `stop` steht (AWS-Vorgabe).
- Der CloudWatch-Alarm nutzt, dass llama-server beim Generieren einen Kern belegt und im Leerlauf fast nichts; die Schwelle wird nach dem ersten Betrieb einmal geprüft.

### 2. Starten bei Anfrage

- **Dienst `kai-wake` auf `webui1`** (Rolle `kai_entry`), als systemd-Dienst auf dem Host, nicht im Container: IMDS hat Hop-Limit 1, Container bekommen keine Rollen-Zugangsdaten.
- Er bietet auf der Docker-Bridge `POST /wake` (startet `kai1`, wenn gestoppt; wartet einen laufenden Stopp ab) und `GET /status` (EC2-Zustand und ob llama-swap das Modell bereit meldet).
- `InsufficientInstanceCapacity` ist möglich, weil das Volume `kai1` an `eu-central-1b` bindet; `kai-wake` meldet das und versucht es erneut.
- **Globaler Filter in Open WebUI:** `inlet()` ruft `/wake`, zeigt per `__event_emitter__` „kai1 startet, etwa 2 min …“ und lässt die Anfrage erst weiter, wenn `/status` bereit meldet; so läuft keine Anfrage in den LiteLLM-Timeout (180 s).
- **Frühstart bei Anmeldung:** `kai-wake` erkennt die Anmeldung im Log von Open WebUI und startet sofort; das spart die Zeit, in der jemand die Frage tippt (etwa 20–60 s).
- **Harnesses (LiteLLM, Port 4000):** später ein `async_pre_call_hook` in LiteLLM, der ebenfalls `/wake` ruft; der Filter in Open WebUI greift dort nicht.
- Optional `sendLoadingState: true` in llama-swap: zeigt den Ladefortschritt des Modells im Chat.

### 3. Schneller starten

| Maßnahme | Wirkung | Kosten |
|---|---|---|
| Preload ausrollen (`kai_gpu_preload`, `hooks.on_startup.preload`, im Repo fertig) | Modell lädt ab Boot statt ab erster Anfrage; Voraussetzung dafür, dass der Frühstart wirkt | keine |
| gp3-Durchsatz von `kai-models` auf ≈ 400 MiB/s (mehr kann die g4dn.xlarge nicht) | Modell ≈ 30 s statt ≈ 100 s | ≈ 15 $/Monat; 250 MiB/s: ≈ 50 s für ≈ 6 $/Monat; ohne Ausfall änderbar |
| `apt-daily` und `unattended-upgrades` nach dem Boot verzögern | wenige s; sie teilen die EBS-Bandbreite der Instanz mit dem Modell | keine |

Vor dem Anheben des Durchsatzes misst Axel, ob llama.cpp per mmap das Tempo erreicht (`dd` gegen die Ladezeit, sonst `--no-mmap`).

Erwartung mit allen drei Teilen: wer sich anmeldet und tippt, wartet ≈ 30–60 s, wer sofort fragt ≈ 1,5 min, statt heute ≈ 3 min.

## Was Uwe entscheidet

1. Stufe A einschalten: ja oder nein, und nach wie vielen Minuten.
2. `instance_initiated_shutdown_behavior = "stop"` ausdrücklich in Terraform setzen (heute nicht gesetzt, also AWS-Vorgabe `stop`).
3. Netz: CloudWatch-Alarm (C) oder nächtlicher Stopp (B).
4. Instanzrolle für `webui1` mit `ec2:StartInstances` nur auf `kai1` und `ec2:DescribeInstances`, für `kai-wake`.
5. gp3-Durchsatz von `kai-models`: 125 (heute), 250 oder 400 MiB/s.

## Nicht gewählt

- `kai1` dauernd laufen lassen: On-Demand ≈ 480 $/Monat, Spot ≈ 170–240 $/Monat (0,23–0,33 $/h in Frankfurt, 15–20 % Unterbrechungen); Spot senkt Kosten, nicht die Wartezeit.
- Ruhezustand im Gast (`systemctl hibernate`): von AWS nicht unterstützt, mit GPU auf neuem Host unberechenbar, und nicht schneller.
- Weck-Proxy zwischen LiteLLM und `kai1`: zusätzlicher Hop im Datenweg mit Streaming, wo der Filter dasselbe ohne Eingriff in den Weg leistet.
