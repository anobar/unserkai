# Bestandsaufnahme der Einstiegs-Instanz `webui1`

Erhoben am 2026-11-05 über SSM-Sitzung und EC2-API mit der Rolle `ssm-session-access-axel`. Zweck: Grundlage für
[01 Architektur](01_architektur.md), [02 Anforderungen](02_anforderungen-infrastruktur.md) und den Plan ab Phase 2.
Uwe: „die kleine Maschine für das Webui, sicher noch zu klein, größer machen ist kein Problem“.

## 1. Instanz (EC2-API)

| | |
|---|---|
| Instanz-ID | `i-0b4b02f3d9373eed5`, Tag `Name=webui1`, Tag `SSMAccess=true` |
| Typ | `t3.micro`: 2 vCPU (1 Kern, Hyperthreading, Xeon Platinum 8259CL), 913 MB RAM, kein Swap |
| Zone | `eu-central-1a`, x86_64 |
| Platte | ein EBS-Volume `vol-0d3d79fcba95ca6e4` als NVMe, 20 GB (`describe-volumes` verwehrt, Typ/IOPS unbekannt) |
| Netz | privates Subnetz `/20`, keine öffentliche IP, Security Group `webui1`, DNS `10.0.0.2` (VPC-Resolver) |
| Egress | **kein Internet**: `curl https://deb.debian.org` und die Paketquellen sind unerreichbar |
| Instanzprofil | `terraform/webui1` (Rechte nicht einsehbar) |
| Zeiten | Start bis `running` 17 s, Stop 17 bis 32 s |

## 2. Zugang

| | |
|---|---|
| SSM-Shell | `ssm-user`, `sudo` ohne Passwort, Shell `bash` |
| SSH | kein SSH-Schlüssel hinterlegt |
| user-data | enthält ein Klartext-Passwort für einen Benutzer `uwe`, den es auf der Maschine nicht gibt; zu klären mit Uwe: user-data nach [02 §6.1, §6.3](02_anforderungen-infrastruktur.md) neu schreiben und das Passwort aus dem Terraform-Code entfernen |

## 3. Folgerungen für das Konzept

1. **Debian 13** (Uwe und Axel, 06.11.): `webui1` ist `kai-entry`, `kai-gpu` bekommt dasselbe Debian-Image; Rollen und
   Compose-Stack folgen dem Heim-Setup (`apt`, Entscheidung E10 in [01](01_architektur.md)), und `kai-entry-pre` und
   `kai-gpu-pre` tragen das Debian-Cloud-Image desselben Builds (Plan 2.0).
2. **Egress klären.** Ohne ausgehendes Internet gibt es weder Updates noch `docker pull`, Modell-Download oder die
   Brave-API. Es braucht ein NAT-Gateway oder VPC-Endpunkte (S3, ECR) plus eine Allowlist, siehe 02 §3.
   SSM selbst funktioniert, also sind die SSM-Endpunkte bereits erreichbar.
3. **Ansible-Bootstrap.** Ohne SSH-Schlüssel auf der Maschine und ohne Recht auf `AWS-StartSSHSession` in der
   Session-Rolle geht Plan 2.10 (SSH über SSM-ProxyCommand) nicht; Rolle erweitern und Schlüssel per user-data
   hinterlegen. Bootstrap-Benutzer ist `admin`; den SSM-Agent installiert die user-data (02 §6.1).
4. **Rolle `ssm-session-access-axel`** erlaubt heute: `ec2:DescribeInstances`, `Start`/`StopInstances`,
   `ssm:DescribeInstanceInformation`, `ssm:StartSession` nur mit dem Standard-Shell-Dokument. Verwehrt:
   `ssm:SendCommand`, `AWS-StartNonInteractiveCommand`, `ec2:DescribeVolumes`, `ec2:DescribeImages`.
5. **Größe.** 913 MB RAM und 20 GB Platte reichen nicht einmal für Open WebUI plus Image-Cache; die Zielgröße steht in
   [02 §1](02_anforderungen-infrastruktur.md) und [03 Modellvorschlag](03_modellvorschlag.md).
