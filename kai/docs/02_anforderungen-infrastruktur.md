# Kai — Anforderungen an die Infrastruktur (für Uwe)

Stand: 2026-11-05 · Status: zur Abstimmung · Bezug: [01 Architektur](01_architektur.md), [Bestandsaufnahme `webui1`](kai-entry_specs.md), Sprint-Aufgaben S1-05, S1-08, S1-11

Was die beiden Stacks von ihren Maschinen und dem Umfeld brauchen. „Muss“ blockiert die Installation, „Soll“ den sauberen Betrieb, „Kann“ ist Komfort. `webui1` ist von Uwe gesetzt; die Punkte zu `kai-entry` beschreiben, was dazu noch fehlt, nicht einen Umbau.

## 1. Instanzen

| | Anforderung | Stufe |
|---|---|---|
| 1.1 | **`kai-entry`** ist `webui1`, wie von Uwe angelegt (Region `eu-central-1`, Zone `eu-central-1a`, x86_64). Gewünschte Größe `t3.medium` (2 vCPU, 4 GB RAM): die heutigen 913 MB reichen nicht für Open WebUI, LiteLLM und Postgres; Uwe hat die Vergrößerung angeboten | Muss |
| 1.2 | **System `kai-entry`:** Amazon Linux 2023, so wie `webui1` läuft (Release 2023.12 vom 02.11.2026, [Bestandsaufnahme §2](kai-entry_specs.md)). Gesetzt; die Rollen werden darauf ausgelegt (`dnf`, Docker aus dem AL2023-Repo, Entscheidung E10 in [01 §6](01_architektur.md)). Bei einem Release-Wechsel bitte Bescheid, damit `kai-entry-pre` nachzieht | gesetzt |
| 1.3 | **`kai-gpu`:** `g4dn.xlarge` (1× T4 16 GB, 4 vCPU, 16 GB RAM), dieselbe Zone wie das Volume `kai-models` | Muss |
| 1.4 | **AMI `kai-gpu`:** Vorschlag „Deep Learning Base OSS Nvidia Driver GPU AMI (Amazon Linux 2023)“ von AWS: Treiber, Docker und NVIDIA Container Toolkit vorinstalliert, gleiche Systemfamilie wie `kai-entry`. Zu prüfen: die gewählte Ausgabe nennt `g4dn` als unterstützt (frühe Ausgaben taten das nicht) und der Treiberstand ist ≥ 580, damit das `cuda13`-Image von llama-swap läuft. Die Rollen `common`/`docker` ersetzen das vorhandene Docker nicht (Plan 2.9). AMI-Name, System, Docker-, Toolkit- und Treiberversion bitte melden (Plan 2.0.2), damit `kai-gpu-pre` die AMI nachbildet. Uwe entscheidet; eine Ubuntu-GPU-AMI wäre eine zweite Rollenvariante | Muss |
| 1.5 | Standard-Benutzer `ec2-user` mit sudo auf beiden Maschinen (AL2023-Standard, auf `webui1` vorhanden), erreichbar für Ansible (siehe §6) | Muss |
| 1.6 | Tags `Name=kai-entry` bzw. `Name=kai-gpu` und `kai:role=entry` bzw. `kai:role=gpu` (für ein späteres dynamisches Inventar) | Soll |
| 1.7 | Root-Volume `kai-entry` von 20 auf 30 GB (Images ~6 GB; AL2023 vergrößert das Dateisystem beim Start selbst), `kai-gpu` wie die AMI vorgibt (≥ 30 GB); Root enthält nur OS, Treiber und Images. Bleibt Root bei 20 GB, legt die Rolle Dockers `data-root` auf das Volume `kai-data` | Soll |

## 2. Platten

| | Anforderung | Stufe |
|---|---|---|
| 2.1 | **`kai-entry`:** zusätzliches EBS-Volume **gp3, 20 GB**, an die Instanz angehängt; Ansible legt bei Bedarf ein Dateisystem mit Label `kai-data` an und mountet es per Label als `/opt/kai` (Open-WebUI-Daten, Postgres, `.env`) | Muss |
| 2.2 | **`kai-gpu`:** zusätzliches EBS-Volume **gp3, 150 GB**, Label `kai-models`, gemountet als `/opt/kai/models` (2–3 Modelle à 10–15 GB, Luft für Modelltests). 100 GB wäre die Untergrenze | Muss |
| 2.3 | Beide Volumes überleben Stop/Start und werden beim Terminieren **nicht** gelöscht (`DeleteOnTermination=false`); sie sind das, was einen Maschinenwechsel überlebt ([01 §3](01_architektur.md)) | Muss |
| 2.4 | Terraform hängt nur an; der Gerätename ist egal, weil Ansible per Label mountet | Hinweis |
| 2.5 | Root-Volumes unverändert (OS, Treiber); kein Nutzdaten-Mix | Soll |
| 2.6 | Die lokale NVMe der g4dn (125 GB, flüchtig) wird **nicht** genutzt; sie ist nach jedem Stop leer | Hinweis |
| 2.7 | gp3-Durchsatz des Modell-Volumes: Standard 125 MB/s reicht (12 GB laden ≈ 100 s); 250–500 MB/s, falls der Modellwechsel stört ([03](03_modellvorschlag.md)) | Kann |

## 3. Netz, ausgehend

**Befund:** `webui1` hat heute keinen Weg ins Internet (`dnf` und `curl` laufen in den Timeout). Ohne Egress gibt es weder Updates noch `docker pull`, Modell-Download oder die Brave-API. SSM funktioniert, die SSM-Endpunkte sind also erreichbar.

| | Anforderung | Stufe |
|---|---|---|
| 3.1 | Egress ins Internet für beide Maschinen, eingeschränkt auf die Ziele unten. Wege: NAT-Gateway (≈ 38 $/Monat plus Verkehr) oder je Instanz eine öffentliche IPv4 mit Security Group ohne eingehende Regel (≈ 4 $/Monat je Adresse). Uwe entscheidet | Muss |

| Ziel | Zweck | Maschine |
|---|---|---|
| `ghcr.io`, `pkg-containers.githubusercontent.com`, `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` | Container-Images | beide |
| AL2023-Paketspiegel in S3 (`al2023-repos-eu-central-1-*.s3.dualstack.eu-central-1.amazonaws.com`; ohne NAT über einen S3-Gateway-Endpunkt erreichbar) | Updates, Paket `docker` | beide |
| `github.com`, `objects.githubusercontent.com` | Repo-Checkout, Compose-Plugin (Release-Download) | beide |
| `api.search.brave.com` | Websuche (MCP) | kai-entry |
| `api.anthropic.com`, `claude.ai`, `registry.npmjs.org`, `nodejs.org` | Claude Code auf der Maschine (Login, Install) | kai-entry |
| `api.openai.com`, `api.anthropic.com` | externe Modelle über LiteLLM, erst nach Beschluss des Teams | kai-entry, später |
| `huggingface.co`, `*.hf.co` (CDN) | Modell-Download (einmalig pro Modell, 10–15 GB) | kai-gpu |
| NVIDIA-Repo (`nvidia.github.io`, `developer.download.nvidia.com`) | Toolkit-Updates | kai-gpu |

Alles andere kann ausgehend geblockt werden.

## 4. Netz im VPC

| | Anforderung | Stufe |
|---|---|---|
| 4.1 | Private Route-53-Zone (Vorschlag `kai.internal`) mit dem Eintrag `gpu.kai.internal` auf die private Adresse von `kai-gpu`; Terraform pflegt ihn beim Ersetzen der Maschine nach. `kai-entry` kennt `kai-gpu` nur unter diesem Namen (`kai_gpu_endpoint`) | Muss |
| 4.2 | Security Group `kai-gpu`: eingehend nur TCP 8080 aus der Security Group `kai-entry` (per Gruppen-ID, nicht per IP). llama-swap hat keine Authentifizierung | Muss |
| 4.3 | Security Group `kai-entry`: eingehend TCP 3000 (Open WebUI) und TCP 4000 (LiteLLM für Harnesses) nur aus dem VPN-Bereich; sonst nichts | Muss |
| 4.4 | Eintrag `entry.kai.internal` für `kai-entry`, damit Nutzer-Links und Harness-Konfigurationen einen Namen statt einer IP tragen | Soll |

## 5. Netz, eingehend — Zugang für Nutzer

| | Anforderung | Stufe |
|---|---|---|
| 5.1 | Open WebUI lauscht auf `kai_webui_bind:3000`, LiteLLM auf `kai_litellm_bind:4000`. Der Weg vom Nutzer dorthin ist **Infrastruktur**: VPN (bevorzugt), oder Reverse-Proxy/Load Balancer mit TLS | Muss (eine der beiden) |
| 5.2 | Falls VPN: Nutzer erreichen `http://entry.kai.internal:3000`, Harnesses `http://entry.kai.internal:4000/v1`. Die beiden `bind`-Variablen zeigen dann auf die VPN-seitige Adresse statt auf `127.0.0.1` | — |
| 5.3 | Falls öffentlich: HTTPS zwingend (Passwörter, Chat-Inhalte, API-Keys). Zertifikat per ALB/ACM oder Caddy auf `kai-entry`; dann kommt ein Proxy-Container in den Entry-Stack (Erweiterung, kein Umbau) | — |
| 5.4 | **Kein** öffentlich erreichbares SSH (Beschluss Meeting 02.11.) | Muss |
| 5.5 | Vier Nutzer, PC und Telefon (S1-09): Browser reicht, keine App | Hinweis |

Offen (Uwe legt fest): VPN-Technik, Domain `unserkai.de` ja/nein, interner DNS-Name.

## 6. Admin-Zugang (Axel, Ansible, Claude Code)

**Befund vom 05.11.:** Die Rolle `ssm-session-access-axel` erlaubt heute `ec2:DescribeInstances`, `Start`/`StopInstances`, `ssm:DescribeInstanceInformation` und `ssm:StartSession` mit dem Standard-Shell-Dokument; das reicht für eine Shell, aber nicht für Ansible. Auf `webui1` liegt kein SSH-Schlüssel, und die user-data ist ein Ubuntu-Skript, das auf Amazon Linux nicht läuft und ein Klartext-Passwort enthält.

| | Anforderung | Stufe |
|---|---|---|
| 6.1 | **SSM Session Manager** auf beiden Instanzen (Agent ist in AL2023 vorinstalliert und auf `webui1` aktiv; Instanzrolle mit `AmazonSSMManagedInstanceCore`) | Muss |
| 6.2 | Session-Rolle für Axel zusätzlich: `ssm:StartSession` auf das Dokument `AWS-StartSSHSession` (für beide Instanzen), `ssm:TerminateSession`, `ssm:DescribeSessions`. Damit funktionieren Ansible (SSH über SSM-ProxyCommand), VSCode Remote-SSH und Claude Code auf `kai-entry` | Muss |
| 6.3 | Axels SSH-Public-Key (`ansible/files/ssh_keys/axel.pub`, schon im Repo) in `authorized_keys` des Benutzers `ec2-user`: für neue Instanzen per user-data als `#cloud-config` mit `ssh_authorized_keys` (läuft auf AL2023 beim ersten Start), auf der laufenden `webui1` einmalig über die SSM-Shell. Danach pflegt die Rolle `users` die Schlüssel. Das Ubuntu-Skript mit dem Klartext-Passwort kommt aus dem Terraform-Code | Muss (einmalig) |
| 6.4 | AWS-CLI-Profil für Axel mit den Rechten aus 6.2 (MFA-geschützt; eingerichtet und geprüft am 05.11.) | Muss |
| 6.5 | Start/Stop beider Instanzen durch Axel (heute für `webui1` vorhanden, für `kai-gpu` nachziehen): spart Abstimmungsrunden bei Installation, Tests und im Betrieb von `kai-gpu` | Muss |
| 6.6 | Snapshot-Recht für Axel: `ec2:CreateSnapshot`, `ec2:DescribeSnapshots`, `ec2:DescribeVolumes` auf die beiden Volumes (S1-11), oder Uwe macht Snapshots auf Zuruf | Kann |
| 6.7 | Lese-Rechte zum Prüfen der Umgebung: `ec2:DescribeImages`, `ec2:DescribeSecurityGroups`, `ec2:DescribeSubnets` | Kann |

Was Axel dann auf `kai-entry` installiert (nativ, nicht Container): Node.js LTS, `claude` (Claude Code), `git`. Login mit Axels Anthropic-Abo; kein API-Key auf der Maschine nötig.

## 7. Betrieb und Kosten

| | Anforderung | Stufe |
|---|---|---|
| 7.1 | `kai-entry` läuft durch: `t3.medium` ≈ 35 $/Monat in Frankfurt, dazu EBS (Root 30 GB + 20 GB gp3 ≈ 5 $/Monat). Alternative `t3a.medium` (AMD) etwa 10 % günstiger | Hinweis |
| 7.2 | `kai-gpu` nur bei Bedarf: On-Demand ≈ 0,66 $/h, 100 Betriebsstunden ≈ 66 $; im Stop-Zustand nur EBS (150 GB gp3 ≈ 14 $/Monat + Root). Start/Stop zunächst von Hand (Axel oder Uwe), Automatik später ([01 §5](01_architektur.md)) | Hinweis |
| 7.3 | Egress nach §3.1: NAT-Gateway ≈ 38 $/Monat oder zwei öffentliche IPv4 ≈ 8 $/Monat | Hinweis |
| 7.4 | Stabile Namen (`entry.kai.internal`, `gpu.kai.internal`), damit Nutzer-Links und Harness-Konfigurationen nach Stop/Start oder Maschinenwechsel gleich bleiben | Soll |
| 7.5 | EBS-Snapshot von `kai-data` vor der Erstinstallation und an Meilensteinen; Restore-Test einmal durchspielen (S1-11) | Soll |
| 7.6 | Budget-Alarm in AWS (Billing Alert) auf den im Team vereinbarten Betrag | Soll |

## 8. Was Axel von Uwe braucht, bevor es losgeht

1. `kai-entry`: `webui1` auf `t3.medium` vergrößert, Volume `kai-data` angehängt, Egress nach §3, Axels Key bei `ec2-user` (§6.3)
2. `kai-gpu`: Instanz nach §1.3/1.4 mit Volume `kai-models`, Egress, Key; AMI-Daten (System, Release, Docker, Toolkit, Treiber) für `kai-gpu-pre`
3. Instanz-IDs beider Maschinen, private DNS-Namen (§4.1, §4.4)
4. Session-Rolle mit `AWS-StartSSHSession` (§6.2); Prüfung: `ssh` über den SSM-ProxyCommand liefert eine Shell als `ec2-user`
5. Entscheidung zu §5 (VPN/öffentlich), damit `kai_webui_bind` und `kai_litellm_bind` gesetzt werden können; kann auch nach der Installation geändert werden
