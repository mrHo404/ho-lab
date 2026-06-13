# OS Options

You indicated Linux but haven't chosen a distribution. This document compares the three realistic paths for ho-lab.

## Comparison

| | Debian 12 | Ubuntu 24.04 LTS | Proxmox VE |
|---|-----------|------------------|------------|
| **Stability** | Excellent | Excellent | Good (Debian-based) |
| **Overhead** | Lowest | Low | Medium (hypervisor) |
| **Docker support** | Native | Native | In VM or LXC |
| **ZFS** | Manual install | Manual install | Built-in (for VMs) |
| **Learning curve** | Low | Lowest | Medium–High |
| **Best for** | Set-and-forget NAS | Familiar Ubuntu users | Multiple VMs later |
| **Recommendation** | ⭐ **Default** | Good alternative | Overkill initially |

## Recommended: Debian 12 (Bookworm)

**Why:** Minimal base install, excellent Docker and ZFS support, long support window (2028+), matches most homelab Ansible examples.

### Install notes

```bash
# Minimal install — no desktop environment
# Partition: separate SSD for OS, leave 4×8 TB untouched

# Post-install
sudo apt update && sudo apt upgrade -y
sudo apt install -y curl git vim htop smartmontools zfsutils-linux
```

### Enable ZFS

```bash
# Debian includes zfsutils-linux in contrib; ensure non-free-firmware repo enabled
sudo apt install -y zfs-dkms zfsutils-linux
```

## Alternative: Ubuntu 24.04 LTS

Choose if you're already comfortable with Ubuntu. Functionally equivalent for this project.

```bash
sudo apt install -y zfsutils-linux docker.io docker-compose-v2
# Prefer Docker's official repo over docker.io — bootstrap.yml handles this
```

## Alternative: Proxmox VE

Choose if you plan to run **multiple isolated environments** (e.g., separate VM for torrents, LXC for Pi-hole).

### Pros

- Snapshot VMs before upgrades
- Run Pi-hole in LXC with minimal overhead
- Isolate torrent VM from media stack

### Cons

- Extra complexity for a single-purpose NAS
- ZFS on Proxmox consumes the 4×8 TB for VM storage — different mental model
- Immich + Jellyfin in one LXC/VM still needs the same Docker Compose work

### When to revisit Proxmox

- You add a second server
- You want a dedicated "lab" VM for experiments
- You need Windows VM for something

## Not recommended

| OS | Why |
|----|-----|
| TrueNAS SCALE | Great NAS OS but fights Ansible-first workflow; ZFS management is GUI-driven |
| Unraid | Proprietary, license cost, less Ansible-friendly |
| OpenMediaVault | Fine NAS, but you'll fight it to run Gluetun sidecar pattern |

## Decision

Set your choice in `ansible/inventory/group_vars/homelab/main.yml`:

```yaml
# Options: debian, ubuntu, proxmox
ho_lab_os: debian
```

The `common` role adjusts package names accordingly. Default playbooks target **Debian 12**.

## Post-OS install checklist

- [ ] Static IP or DHCP reservation on router
- [ ] SSH key auth enabled, password auth disabled
- [ ] Hostname set (e.g., `holab`)
- [ ] Time sync: `systemd-timesyncd` or `chrony`
- [ ] Firewall: `ufw allow OpenSSH` only until services deployed
