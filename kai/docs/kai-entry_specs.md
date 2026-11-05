# Bestandsaufnahme der Einstiegs-Instanz `webui1`

Erhoben am 2026-11-05 über SSM-Sitzung und EC2-API mit der Rolle `ssm-session-access-axel`. Zweck: Grundlage für
[01 Architektur](01_architektur.md), [02 Anforderungen](02_anforderungen-infrastruktur.md) und den Plan ab Phase 2.
Uwe: „die kleine Maschine für das Webui, sicher noch zu klein, größer machen ist kein Problem“.

## 1. Instanz (EC2-API)

| | |
|---|---|
| Instanz-ID | `i-0b4b02f3d9373eed5`, Tag `Name=webui1`, Tag `SSMAccess=true` |
| Typ | `t3.micro`: 2 vCPU (1 Kern, Hyperthreading, Xeon Platinum 8259CL), 913 MB RAM, kein Swap |
| AMI | `ami-01376afa3e7def694`, Amazon Linux 2023 (`describe-images` ist der Rolle verwehrt) |
| Zone | `eu-central-1a`, x86_64 |
| Platte | ein EBS-Volume `vol-0d3d79fcba95ca6e4` als NVMe, 20 GB, GPT, XFS auf `/` (1,6 GB belegt), 10 MB EFI (`describe-volumes` verwehrt, Typ/IOPS unbekannt) |
| Netz | privates Subnetz `/20`, keine öffentliche IP, Security Group `webui1`, DHCP über `systemd-networkd`, DNS `10.0.0.2` (VPC-Resolver) |
| Egress | **kein Internet**: `curl https://deb.debian.org` und das AL2023-Paket-Repo (S3) sind unerreichbar, `dnf` hängt bis zum Timeout |
| Instanzprofil | `terraform/webui1` (Rechte nicht einsehbar) |
| Zeiten | Start bis `running` 17 s, SSM-Agent online nach 18 s, Stop 17 bis 32 s |

## 2. Betriebssystem

| | |
|---|---|
| OS | Amazon Linux 2023.12.20261102 (`ID_LIKE=fedora`), Support bis 2029-06-30 |
| Kernel | 6.18.56-125.164.amzn2023.x86_64, `PREEMPT_DYNAMIC`, Boot über UEFI, Konsole `ttyS0` |
| Init | systemd, cgroup v2, `systemd-networkd` + `systemd-resolved`, `chronyd` |
| SELinux | installiert, Modus **Permissive** |
| Pakete | 494 RPMs, `dnf`/`yum` 4.14, Repos `amazonlinux.repo` und `kernel-livepatch.repo` (ohne Egress nutzlos) |
| cloud-init | 22.2.2, Status `done` |
| SSM-Agent | `amazon-ssm-agent` 3.3.5700.0 als RPM, aktiv |
| Dienste | `sshd` aktiv (Konfiguration für `ssm-user` nicht lesbar), `auditd`, `acpid`, `atd`, `irqbalance`, `libstoragemgmt`, `gssproxy`, `systemd-homed` |
| Timer | `fstrim`, `logrotate`, `sysstat`, `update-motd`, `systemd-tmpfiles-clean`, `refresh-policy-routes@ens5` |
| Limits | `ulimit -n` 65535, `ip_forward` 0 |
| Grafik | nur der virtuelle Amazon-VGA-Adapter, kein `/dev/nvidia*` |

## 3. Benutzer und Zugang

| | |
|---|---|
| SSM-Shell | `ssm-user` (uid 1001), `sudo` ohne Passwort, Shell `bash` |
| Weitere Konten | `ec2-user` (uid 1000, AMI-Standard); kein `~/.ssh` bei beiden, also kein SSH-Schlüssel hinterlegt |
| user-data | ein Bash-Skript für **Ubuntu** (`apt-get`, `snapd`, `snap install amazon-ssm-agent`, `adduser`), das auf Amazon Linux nicht laufen kann; der SSM-Agent kommt hier aus der AMI. Es enthält zudem ein Klartext-Passwort für einen Benutzer `uwe`, den es auf der Maschine nicht gibt. Zu klären mit Uwe: user-data für die Ziel-AMI neu schreiben und das Passwort aus dem Terraform-Code entfernen |

## 4. Werkzeuge

| vorhanden | Version | fehlt |
|---|---|---|
| `bash`, `sh` (= bash) | 5.2.15 | `git`, `docker`, `podman`, `containerd` |
| `python3` | 3.9.25 | `nvidia-smi`, `nvidia-ctk`, GPU-Treiber |
| `curl` / `wget` | 8.21.0 / 1.21.3 | `tmux`, `htop` |
| `jq`, `rsync`, `tar`, `gzip` | 1.8.1, 3.5.1, 1.34, 1.12 | `make`, `gcc`, `cmake` |
| `screen`, `vim`, `nano` | 4.08, 9.2, 8.3 | `node`, `npm`, `ansible` |
| `dnf`, `yum` | 4.14.0 | `apt` |

Overlay-Dateisystem für Docker ist im Kernel nicht als Modul geladen (nur `xfs` sichtbar), lädt aber bei Bedarf nach.

## 5. Folgerungen für das Konzept

1. **Amazon Linux 2023 ist gesetzt.** `webui1` wird `kai-entry`; Rollen und Compose-Stack richten sich nach diesem
   System (`dnf`, Docker aus dem AL2023-Repo, Entscheidung E10 in [01](01_architektur.md)), und `kai-entry-pre` bildet genau
   dieses Release nach (Plan 2.0).
2. **Egress klären.** Ohne ausgehendes Internet gibt es weder `apt`/`dnf`-Updates noch `docker pull`, Modell-Download
   oder die Brave-API. Es braucht ein NAT-Gateway oder VPC-Endpunkte (S3, ECR) plus eine Allowlist, siehe 02 §3.
   SSM selbst funktioniert, also sind die SSM-Endpunkte bereits erreichbar.
3. **Ansible-Bootstrap.** Ohne SSH-Schlüssel auf der Maschine und ohne Recht auf `AWS-StartSSHSession` in der
   Session-Rolle geht Plan 2.10 (SSH über SSM-ProxyCommand) nicht; Rolle erweitern und Schlüssel per user-data oder
   erstem SSM-Login hinterlegen. Bootstrap-Benutzer ist `ec2-user`.
4. **Rolle `ssm-session-access-axel`** erlaubt heute: `ec2:DescribeInstances`, `Start`/`StopInstances`,
   `ssm:DescribeInstanceInformation`, `ssm:StartSession` nur mit dem Standard-Shell-Dokument. Verwehrt:
   `ssm:SendCommand`, `AWS-StartNonInteractiveCommand`, `ec2:DescribeVolumes`, `ec2:DescribeImages`.
5. **Größe.** 913 MB RAM und 20 GB Platte reichen nicht einmal für Open WebUI plus Image-Cache; die Zielgröße steht in
   [02 §1](02_anforderungen-infrastruktur.md) und [03 Modellvorschlag](03_modellvorschlag.md).
6. SELinux Permissive und `ip_forward=0` sind auf Amazon Linux Standard; Docker setzt `ip_forward` selbst, SELinux
   bleibt Permissive.
