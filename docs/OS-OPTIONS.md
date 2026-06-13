# OS Options

You indicated Linux but haven't chosen a distribution. This document compares realistic paths for ho-lab.

## Short answer: Fedora vs Ubuntu

**Yes — Fedora Server accomplishes the same job as Ubuntu** for this project. All services run in Docker; the host OS mainly provides the kernel, ZFS, and Docker engine. Ansible playbooks in ho-lab now support **Debian, Ubuntu, and Fedora**.

The difference is **maintenance philosophy**, not capability:

| | Ubuntu 24.04 LTS | Fedora Server 41+ |
|---|------------------|-------------------|
| **Support window** | ~5 years, one upgrade every few years | ~13 months, upgrade annually |
| **Package freshness** | Stable/slightly older | Newer kernel, Java, drivers |
| **Homelab docs** | Most tutorials assume Ubuntu/Debian | Fewer copy-paste guides |
| **ZFS** | `zfsutils-linux` package | `zfs` package (OpenZFS) |
| **Docker** | Official Docker CE repo | Official Docker CE repo |
| **Best if you** | Want set-and-forget for years | Want latest hardware support, enjoy upgrading |

For a NAS that should run quietly for 3–5 years without OS upgrades: **Debian 12** or **Ubuntu LTS**.

For a lab box where you like staying current and already use Fedora elsewhere: **Fedora Server is a fine choice**.

## Full comparison

| | Debian 12 | Ubuntu 24.04 LTS | Fedora Server | Proxmox VE |
|---|-----------|------------------|---------------|------------|
| **Stability** | Excellent | Excellent | Good (fast releases) | Good |
| **Overhead** | Lowest | Low | Low | Medium |
| **Docker** | Native | Native | Native | In VM/LXC |
| **ZFS** | Manual install | Manual install | `dnf install zfs` | Built-in |
| **Support life** | ~2028 | ~2029 | ~13 months | Varies |
| **Recommendation** | ⭐ NAS default | Familiar users | ⭐ Capable alternative | Overkill initially |

## Recommended: Debian 12 (Bookworm)

**Why:** Minimal base install, long support window, lowest overhead, most homelab Ansible examples target Debian/Ubuntu.

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git vim htop smartmontools zfsutils-linux
```

## Ubuntu 24.04 LTS

Functionally identical to Debian for ho-lab. Choose if you're already comfortable with Ubuntu.

```bash
sudo apt install -y zfsutils-linux
# Docker installed by ansible playbooks/bootstrap.yml
```

## Fedora Server

**Same end result as Ubuntu** — Docker Compose stacks, ZFS pool, Ansible deploys. Set `ho_lab_os: fedora` in group_vars.

### Install notes

```bash
# Minimal Fedora Server install — separate SSD for OS
sudo dnf upgrade -y
sudo dnf install -y curl git vim htop smartmontools zfs
sudo systemctl enable --now docker  # or let Ansible bootstrap handle it
```

### Fedora-specific considerations

- **Upgrade yearly** — `dnf system-upgrade` or fresh install; plan downtime
- **SELinux** — Docker volumes generally work; if a container can't write to `/tank`, check `ls -Z` and adjust contexts
- **ZFS** — OpenZFS is well-supported; pool commands are identical to Linux/ZFS elsewhere
- **Minecraft/Java** — Fedora's newer kernel helps; Java runs inside the container anyway (`java21` tag)

### When Fedora makes sense

- You already run Fedora on your desktop and want consistency
- You want a newer kernel for recent NIC/storage drivers
- You treat the homelab as a learning environment and don't mind annual OS upgrades

### When to avoid Fedora

- You want a NAS that runs untouched for years
- You prefer maximum "it just works" copy-paste from homelab blogs (most assume Debian/Ubuntu)

## Proxmox VE

Choose if you plan multiple isolated VMs. Overkill for a single Docker host running ho-lab stacks.

## Not recommended

| OS | Why |
|----|-----|
| TrueNAS SCALE | GUI-driven ZFS fights Ansible-first workflow |
| Unraid | Proprietary, less Ansible-friendly |
| OpenMediaVault | Works, but Debian + Ansible is simpler |

## Decision

Set in `ansible/inventory/group_vars/homelab/main.yml`:

```yaml
# Options: debian | ubuntu | fedora
ho_lab_os: debian   # or ubuntu, or fedora
```

## Post-OS install checklist

- [ ] Static IP or DHCP reservation on router
- [ ] SSH key auth enabled, password auth disabled
- [ ] Hostname set (e.g., `holab`)
- [ ] Time sync enabled (`chrony` on Fedora, `systemd-timesyncd` on Debian/Ubuntu)
- [ ] Firewall: allow SSH only until services are deployed
