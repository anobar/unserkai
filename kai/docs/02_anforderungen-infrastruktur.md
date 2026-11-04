# Kai — Anforderungen an die Infrastruktur (für Uwe)

Stand: 2026-11-04 · Status: zur Abstimmung · Bezug: [01 Architektur](01_architektur.md), Sprint-Aufgaben S1-05, S1-08, S1-11

Was der Stack von der Maschine und ihrem Umfeld braucht. „Muss“ blockiert die Installation, „Soll“ den sauberen Betrieb, „Kann“ ist Komfort.

## 1. Instanz

| | Anforderung | Stufe |
|---|---|---|
| 1.1 | `g4dn.xlarge` (1× T4 16 GB, 4 vCPU, 16 GB RAM), Region `eu-central-1` | Muss |
| 1.2 | AMI: NVIDIA GPU-Optimized AMI (Ubuntu, Treiber, Docker, NVIDIA Container Toolkit vorinstalliert). Ansible-Rollen `common`/`docker` müssen damit umgehen (Docker ist schon da — die Rolle darf es nicht durch eine andere Version ersetzen; Phase 2 prüft das) | Muss |
| 1.3 | Standard-Benutzer der AMI (`ubuntu`) mit sudo, erreichbar für Ansible (siehe 5) | Muss |
| 1.4 | Hostname/Inventory-Name `unserkai` wie im Repo | Soll |

## 2. Platte

| | Anforderung | Stufe |
|---|---|---|
| 2.1 | Zusätzliches EBS-Volume **gp3, 150 GB**, gemountet als `/opt/kai` (Images ~8 GB, 2–3 Modelle à 10–15 GB, Open-WebUI-Daten, Luft für Modelltests). 100 GB wäre die Untergrenze | Muss |
| 2.2 | Volume überlebt Stop/Start der Instanz (Standard bei EBS) und wird beim Terminieren **nicht** gelöscht (`DeleteOnTermination=false`) | Muss |
| 2.3 | Root-Volume der AMI unverändert (OS, Treiber); kein Nutzdaten-Mix | Soll |
| 2.4 | Die lokale NVMe der g4dn (125 GB, flüchtig) wird **nicht** genutzt — sie ist nach jedem Stop leer | Hinweis |

## 3. Netz, ausgehend

Die Maschine muss erreichen können:

| Ziel | Zweck |
|---|---|
| `huggingface.co`, `*.hf.co` (CDN) | Modell-Download (einmalig pro Modell, 10–15 GB) |
| `ghcr.io`, `pkg-containers.githubusercontent.com`, `registry-1.docker.io`, `auth.docker.io`, `production.cloudflare.docker.com` | Container-Images |
| `api.search.brave.com` | Websuche (MCP) |
| Ubuntu-Spiegel, NVIDIA-Repo | Updates |
| `api.anthropic.com`, `claude.ai`, `registry.npmjs.org`, `nodejs.org` | Claude Code auf der Maschine (Login, Install) |
| `github.com` | Repo-Checkout |

Alles andere kann ausgehend geblockt werden. Stufe 1 braucht keine Egress-Freigabe für etwas anderes.

## 4. Netz, eingehend — Zugang für Nutzer

| | Anforderung | Stufe |
|---|---|---|
| 4.1 | Open WebUI lauscht auf `127.0.0.1:3000`. Der Weg vom Nutzer dorthin ist **Infrastruktur**: VPN (bevorzugt), oder Reverse-Proxy/Load Balancer mit TLS | Muss (eine der beiden) |
| 4.2 | Falls VPN: Nutzer erreichen `http://<private-IP>:3000` oder einen internen DNS-Namen. Dann muss der Stack auf der VPN-Adresse lauschen statt auf `127.0.0.1` — ein Wert in der Ansible-Variable `kai_webui_bind` | — |
| 4.3 | Falls öffentlich: HTTPS zwingend (Passwörter, Chat-Inhalte). Zertifikat per ALB/ACM oder Caddy auf der Maschine; dann kommt ein Proxy-Container in den Stack (Stufe-1-Erweiterung, kein Umbau) | — |
| 4.4 | **Kein** öffentlich erreichbares SSH (Beschluss Meeting 02.11.) | Muss |
| 4.5 | Vier Nutzer, PC und Telefon (S1-09): Browser reicht, keine App | Hinweis |

Offen (Uwe legt fest): VPN-Technik, Domain `unserkai.de` ja/nein, interner DNS-Name.

## 5. Admin-Zugang (Axel, Ansible, Claude Code)

| | Anforderung | Stufe |
|---|---|---|
| 5.1 | **SSM Session Manager** auf der Instanz (Agent ist in Ubuntu-AMIs vorinstalliert; Instanzrolle mit `AmazonSSMManagedInstanceCore`) | Muss |
| 5.2 | IAM-Rechte für Axel: `ssm:StartSession` auf die Instanz **und** auf das Dokument `AWS-StartSSHSession`, `ssm:TerminateSession`, `ssm:DescribeSessions`, `ec2:DescribeInstances`. Damit funktionieren: Ansible (SSH über SSM-ProxyCommand), VSCode Remote-SSH, Claude Code auf der Maschine | Muss |
| 5.3 | Axels SSH-Public-Key (`ansible/files/ssh_keys/axel.pub`, schon im Repo) in `authorized_keys` des Benutzers `ubuntu` — das macht die Rolle `users` beim ersten Lauf; für den **ersten** Lauf braucht Ansible aber bereits einen Weg hinein: entweder `ec2-instance-connect` einmalig oder Uwe legt den Key per User-Data/Konsole ab | Muss (einmalig) |
| 5.4 | AWS-CLI-Profil für Axel mit den Rechten aus 5.2 (MFA-geschützt, wie bisher) | Muss |
| 5.5 | Snapshot-Recht für Axel: `ec2:CreateSnapshot`, `ec2:DescribeSnapshots` auf das `/opt/kai`-Volume (S1-11), oder Uwe macht Snapshots auf Zuruf | Kann |
| 5.6 | Instanz **starten/stoppen** durch Axel (`ec2:StartInstances`/`StopInstances` auf diese Instanz): spart Abstimmungsrunden bei Installation und Tests | Kann |

Was Axel dann auf der Maschine installiert (nativ, nicht Container): Node.js LTS, `claude` (Claude Code), `git`. Login mit Axels Anthropic-Abo; kein API-Key auf der Maschine nötig.

## 6. Betrieb und Kosten

| | Anforderung | Stufe |
|---|---|---|
| 6.1 | Stop/Start manuell durch Uwe (Beschluss). Kosten im Stop-Zustand: nur EBS (150 GB gp3 ≈ 14 $/Monat + Root-Volume). On-Demand-Laufzeit ≈ 0,66 $/h in Frankfurt → 100 Betriebsstunden ≈ 66 $ | Hinweis |
| 6.2 | Elastic IP oder stabiler privater DNS-Name, damit Nutzer-Links nach Stop/Start gleich bleiben | Soll |
| 6.3 | EBS-Snapshot des `/opt/kai`-Volumes vor der Erstinstallation und an Meilensteinen; Restore-Test einmal durchspielen (S1-11) | Soll |
| 6.4 | Budget-Alarm in AWS (Billing Alert) auf den im Team vereinbarten Betrag | Soll |

## 7. Was Axel von Uwe braucht, bevor es losgeht

1. Instanz-ID, Region, private IP (ggf. DNS-Name) der laufenden Maschine
2. Bestätigung: `/opt/kai`-Volume gemountet (oder: Blockdevice-Name, dann mountet die Ansible-Rolle)
3. AWS-Profil funktioniert: `aws ssm start-session --target <instance-id>` liefert eine Shell
4. Axels Key liegt bei `ubuntu` **oder** einmaliger Alternativzugang
5. Entscheidung zu Punkt 4 (VPN/öffentlich), damit `kai_webui_bind` gesetzt werden kann — kann auch nach der Installation geändert werden
