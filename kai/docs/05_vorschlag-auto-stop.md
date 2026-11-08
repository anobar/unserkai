# Kai — Vorschlag an Uwe: `kai1` stoppt sich nach Leerlauf

Stand: vorbereitet, nicht umgesetzt. Entscheidung und AWS-Seite liegen bei Uwe; die Rolle `kai_gpu` baut erst danach.

## Anlass

- Beim Testdeployment am 07./08.11.2026 lief die AWS-Sitzung zweimal ab, während `kai1` lief; gestoppt werden konnte die Maschine erst, als Axel eine neue Sitzung hatte.
- `kai1` kostet im Betrieb ≈ 0,66 $/h ([02 §7.2](02_anforderungen-infrastruktur.md)); eine vergessene Nacht kostet mehr als ein Monat Root-Volume.
- Heute hängt das Stoppen an einem Menschen mit gültiger Sitzung ([01 §4](01_architektur.md)).

## Vorschlag

Zwei Stufen, die einander nicht brauchen:

| Stufe | Wer | Was | Wirkung |
|---|---|---|---|
| A | Rolle `kai_gpu` | systemd-Timer prüft alle 5 min, ob llama-swap ein Modell geladen hat; ist zweimal hintereinander keins geladen und läuft die Maschine länger als 20 min, fährt sie mit `systemctl poweroff` herunter | Stopp nach etwa 30 min ohne Anfrage |
| B | Uwe (Terraform) | EventBridge-Scheduler stoppt `kai1` jede Nacht um 02:00 Europe/Zurich | Netz unter Stufe A, falls der Timer hängt |

### Stufe A im Detail

- **Leerlauf-Signal:** llama-swap entlädt ein Modell nach `ttl` Sekunden ohne Anfrage; `GET http://127.0.0.1:8080/running` listet die geladenen Modelle (`{"running": [...]}`). Heute steht `ttl` auf 0 (nie entladen), also setzt `kai_gpu_models` dafür `ttl: 1800`.
- **Skript `kai-gpu-idle-stop`** (Rolle legt es unter `/usr/local/sbin` ab): fragt `/running`, zählt leere Antworten in `/run/kai-gpu-idle`, fährt beim zweiten leeren Ergebnis herunter; eine fehlende Antwort von llama-swap zählt nicht als Leerlauf, damit ein hängender Container die Maschine nicht stoppt.
- **Schalter:** `kai_gpu_idle_stop: false` als Vorgabe, `kai_gpu_idle_stop_minutes: 30`; auf `kai-gpu-pre` bleibt es aus, sonst stoppt die Test-VM mitten im Test.
- **Warum `poweroff` statt AWS-API:** Die Instanz braucht dann keine IAM-Rechte für `ec2:StopInstances`; bei EBS-gestützten Instanzen heißt Herunterfahren „stopped“, solange `instance_initiated_shutdown_behavior` auf `stop` steht (AWS-Vorgabe).
- **Wecken bleibt von Hand** (`kai/bin/kai-gpu start`); automatisches Wecken bei Anfrage aus `webui1` ist eine eigene Aufgabe ([01 §5](01_architektur.md)).

## Was Uwe entscheidet

1. Stufe A einschalten: ja oder nein, und nach wie vielen Minuten.
2. `instance_initiated_shutdown_behavior = "stop"` ausdrücklich in Terraform setzen (heute nicht gesetzt, also AWS-Vorgabe `stop`).
3. Stufe B (nächtlicher Stopp) und die Uhrzeit.

## Nebenbefund: Kaltstart

Die erste Antwort nach dem Start dauerte 98 s statt der in [04 §3.4](04_plan.md) verlangten < 60 s (S1-06). Das passt zu 13 GB Modell bei der gp3-Grundrate von 125 MB/s. Möglichkeiten:

- Umgesetzt: llama-swap lädt das erste Modell gleich beim Start (`kai_gpu_preload` in `group_vars/kai_gpu.yml`, `hooks.on_startup.preload`), dann ist es meist fertig, bevor jemand fragt; auf `kai1` noch nicht ausgerollt.
- Uwe hebt den Durchsatz von `kai-models` an (gp3 bis 1000 MB/s, kostenpflichtig über 125 MB/s).
