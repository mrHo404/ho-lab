# ho-lab

Ansible-managed homelab for a Ryzen 3700X / 32 GB RAM / 4×8 TB NAS build.

Primary goals:

- **Jellyfin** media server on the LAN
- **Immich** phone photo/video backup (Google Photos replacement)
- **Pi-hole** DNS ad blocking for the household
- **qBittorrent** routed through **Gluetun** (ProtonVPN or NordVPN)
- **Monitoring** via Uptime Kuma + Prometheus + Grafana
- Everything declared in Git and applied with Ansible

## Hardware

| Component | Spec |
|-----------|------|
| CPU | AMD Ryzen 7 3700X (8C/16T) |
| RAM | 32 GB DDR4 |
| Storage | 4× 8 TB HDD (32 TB raw) |
| GPU | None built-in — see [docs/HARDWARE.md](docs/HARDWARE.md) |

## Documentation

| Doc | Contents |
|-----|----------|
| [docs/RESEARCH.md](docs/RESEARCH.md) | Deep research summary with sources |
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | Service layout, networking, ports |
| [docs/STORAGE.md](docs/STORAGE.md) | ZFS vs MergerFS+SnapRAID decision |
| [docs/HARDWARE.md](docs/HARDWARE.md) | Transcoding, GPU options, drive layout |
| [docs/OS-OPTIONS.md](docs/OS-OPTIONS.md) | Debian vs Ubuntu vs Proxmox |

## Quick start

### 1. Prerequisites

- Target host running Linux (Debian 12 or Ubuntu 24.04 recommended)
- SSH access with sudo
- Ansible 2.15+ on your control machine

```bash
pip install ansible
ansible-galaxy collection install -r ansible/requirements.yml
```

### 2. Configure inventory

```bash
cp ansible/inventory/group_vars/homelab.yml.example ansible/inventory/group_vars/homelab/vault.yml
# Edit ansible/inventory/hosts.yml with your server IP
# Fill in secrets (VPN creds, passwords) — encrypt with ansible-vault
```

### 3. Bootstrap the host

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/bootstrap.yml
```

### 4. Deploy stacks (in order)

```bash
ansible-playbook -i inventory/hosts.yml playbooks/storage.yml
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```

Or deploy individual stacks:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/stack-network.yml    # Pi-hole
ansible-playbook -i inventory/hosts.yml playbooks/stack-media.yml      # Jellyfin + Immich
ansible-playbook -i inventory/hosts.yml playbooks/stack-downloads.yml  # Gluetun + qBittorrent
ansible-playbook -i inventory/hosts.yml playbooks/stack-monitoring.yml # Uptime Kuma + Prometheus + Grafana
```

## Project layout

```
ho-lab/
├── docs/                  # Architecture & research
├── ansible/
│   ├── inventory/         # Hosts and group variables
│   ├── playbooks/         # Entry-point playbooks
│   ├── roles/             # Reusable Ansible roles
│   └── templates/         # Jinja2 compose & config templates
└── compose/examples/      # Reference docker-compose files
```

## Recommended reading order

1. [docs/OS-OPTIONS.md](docs/OS-OPTIONS.md) — pick your base OS
2. [docs/STORAGE.md](docs/STORAGE.md) — plan the 4×8 TB layout before formatting
3. [docs/HARDWARE.md](docs/HARDWARE.md) — budget for a GPU if you need transcoding
4. [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — understand networking before pointing DNS at Pi-hole

## Status

This is an **initial scaffold**. Storage layout, VPN credentials, and DNS cutover require manual decisions documented in `docs/`. Do not run `storage.yml` until you have read `docs/STORAGE.md` and chosen a layout.

## License

MIT
