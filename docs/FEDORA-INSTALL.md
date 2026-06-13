# Fedora Server install — ho-lab checklist

Step-by-step guide for installing Fedora Server on the **256 GB OS drive** (formerly Batocera), then handing off to Ansible.

**Do not** partition or format the four 8 TB drives during OS install — ZFS comes later via `holab_storage_playbook.yml`.

---

## Before you start

| Item | Detail |
|------|--------|
| OS drive | 256 GB SSD — wiped, empty GPT (prepared from Mac as `/dev/disk28`) |
| Install USB | **Separate** stick with [Fedora Server ISO](https://fedoraproject.org/server/download/) |
| Data drives | 4× 8 TB — leave untouched in installer |
| Target hostname | `holab` (`host_fqdn=holab.lan` in inventory) |
| Ansible user | Match `inventory.ini` — example uses `admin` |
| LAN | Default in `host_vars/holab/vars.yml` is `192.168.1.0/24` — adjust if yours differs |

---

## 1. Hardware setup

- [ ] Install the 256 GB drive as the **boot/OS** device (SATA or NVMe).
- [ ] Connect the four 8 TB drives (power + data) but **do not select them** in Anaconda.
- [ ] Plug in the Fedora Server USB installer.
- [ ] Connect Ethernet (recommended for first install; Wi‑Fi works but static IP is easier on wired).

### BIOS / UEFI

- [ ] Boot mode: **UEFI** (GPT disk expects this).
- [ ] Boot order: USB first for install, then the 256 GB drive.
- [ ] SATA mode: **AHCI** (default).
- [ ] Enable **IOMMU / AMD-V** only if you plan passthrough later (optional).

---

## 2. Boot the Fedora Server installer

1. Boot from the USB stick.
2. Choose **Install Fedora Server** (text or GUI installer — either works).

---

## 3. Anaconda — language & time

- [ ] Language: your preference
- [ ] Time zone: match `ho_lab_timezone` in `host_vars/holab/vars.yml` (default **Europe/Berlin**)

---

## 4. Anaconda — installation destination (critical)

**Goal:** Use **only** the 256 GB drive.

1. Open **Installation Destination**.
2. Select the **256 GB** disk (check size — not 8 TB / 7.3 TiB drives).
3. **Deselect all 8 TB drives** if they appear.
4. Storage configuration: **Automatic** (recommended) or custom below.

### Automatic (recommended)

- Choose **Use entire disk** on the 256 GB device.
- Fedora creates roughly:
  - `/boot/efi` (~600 MB)
  - `/boot` (~2 GB)
  - `/` on XFS (remainder)
  - swap via **zram** (Fedora default — fine for ho-lab)

### Custom (optional)

| Mount | Size | FS | Notes |
|-------|------|-----|-------|
| `/boot/efi` | 600 MB | EFI | Required for UEFI |
| `/boot` | 1–2 GB | ext4 | |
| `/` | rest (~240 GB) | xfs | OS + Docker images + data until ZFS |
| swap | 0 (use zram) | — | 32 GB RAM — zram is enough |

- [ ] Confirm **no** 8 TB drive has mount points or formatting applied.

---

## 5. Anaconda — network

- [ ] Set hostname: **`holab`**
- [ ] Configure network:

**Option A — DHCP reservation (easiest)**  
Reserve `192.168.1.10` (or your chosen IP) for the server MAC on your router. Note the IP after install.

**Option B — Static IP in installer**  
Example (adjust to your LAN):

| Field | Value |
|-------|-------|
| Address | `192.168.1.10` |
| Prefix | `24` |
| Gateway | `192.168.1.1` |
| DNS | `192.168.1.1` or `1.1.1.1` |

Update `inventory.ini` and `host_vars/holab/vars.yml` (`gluetun.lan_subnets`) to match your subnet.

---

## 6. Anaconda — user & root

- [ ] **Root account:** set a strong password (or lock root and use sudo only).
- [ ] **Create user:** `admin` (or whatever you put in `ansible_user` in `inventory.ini`).
- [ ] Make this user an **administrator** (wheel group / sudo).
- [ ] **SSH key:** paste your Mac public key (`~/.ssh/id_ed25519.pub` or `id_rsa.pub`) if the installer offers it.

If the installer has **Software selection**:

- [ ] Minimal / Server install is fine — Ansible installs Docker, ZFS, and packages.
- [ ] Ensure **OpenSSH server** is included (default on Fedora Server).

---

## 7. Begin installation

- [ ] Review summary: one 256 GB disk formatted, 8 TB disks untouched.
- [ ] **Begin installation** and wait for completion.
- [ ] Reboot, remove USB stick.

---

## 8. First boot — verify on the server

Log in locally or via SSH:

```bash
# Identity
hostnamectl
ip -br a
lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINT

# Expect: 256G disk with /boot/efi, /boot, / ; 8TB drives raw/unpartitioned
# Updates
sudo dnf upgrade -y

# Time sync (should already be active)
timedatectl status

# SSH (for Ansible)
sudo systemctl enable --now sshd
```

### SSH from your Mac

```bash
ssh admin@192.168.1.10   # use your actual IP
```

If password auth only, copy your key:

```bash
ssh-copy-id admin@192.168.1.10
```

- [ ] Passwordless SSH works (or you accept password for first Ansible run).
- [ ] `sudo` works without extra setup for `admin`.

---

## 9. Optional — before Ansible (manual)

Ansible bootstrap (`holab_bootstrap_playbook.yml`) installs Docker and base packages. You **can** skip this and let Ansible do it.

If you want ZFS tools ready before the storage playbook:

```bash
sudo dnf install -y zfs
```

**Do not** create a pool on the 8 TB drives manually unless you are intentionally bypassing Ansible — use `holab_storage_playbook.yml` with `storage_confirm_destroy: true`.

### Firewall (Fedora)

ho-lab playbooks do **not** configure `firewalld`. Docker usually publishes ports, but verify after deploy:

```bash
sudo firewall-cmd --state
# After holab_site_playbook.yml, if services are unreachable:
sudo firewall-cmd --permanent --add-service=ssh
sudo firewall-cmd --permanent --add-port=8096/tcp   # Jellyfin
sudo firewall-cmd --permanent --add-port=2283/tcp   # Immich
sudo firewall-cmd --permanent --add-port=8080/tcp   # Pi-hole / qBit WebUI
sudo firewall-cmd --permanent --add-port=53/tcp --add-port=53/udp  # Pi-hole DNS
sudo firewall-cmd --permanent --add-port=25565/tcp  # Minecraft
sudo firewall-cmd --reload
```

Or for a trusted LAN-only homelab, some operators use `--zone=trusted --add-interface=<nic>` — less secure, simpler.

### SELinux

Leave **Enforcing** (default). If a container cannot write a host path after ZFS is up, check contexts:

```bash
ls -Z /tank
```

---

## 10. Ansible — from your Mac

In the ho-lab repo:

```bash
cd ~/ho-lab
./project_setup.sh

cp inventory.ini.example inventory.ini
# Edit: ansible_host=<server IP>, ansible_user=admin

cp group_vars/homelab/vault.yml.example group_vars/homelab/vault.yml
# Fill secrets (Pi-hole, Grafana, Immich DB, ProtonVPN WireGuard key)
ansible-vault encrypt group_vars/homelab/vault.yml
echo 'your-passphrase' > vault_password.txt && chmod 600 vault_password.txt
```

Confirm `ho_lab_os: fedora` in `group_vars/homelab/vars.yml`.

```bash
ansible -m ping holab
ansible-playbook holab_validate_playbook.yml
ansible-playbook holab_bootstrap_playbook.yml
ansible-playbook holab_site_playbook.yml
```

**Order after OS install:**

| Step | Playbook | Notes |
|------|----------|-------|
| 1 | `holab_validate_playbook.yml` | Vault + config checks |
| 2 | `holab_bootstrap_playbook.yml` | Packages + Docker |
| 3 | `holab_storage_playbook.yml` | **Optional, destructive** — 4× 8 TB ZFS |
| 4 | `holab_site_playbook.yml` | All Docker stacks |

Until ZFS is configured, services use `/opt/ho-lab/data/*` on the 256 GB drive (`storage_enabled: false`).

---

## 11. Post-install router / DNS

- [ ] DHCP reservation matches `ansible_host` in `inventory.ini`.
- [ ] After Pi-hole deploy: point router DNS to `holab` IP, or use Pi-hole as DHCP server later.
- [ ] Test: `http://<ip>:8096` (Jellyfin), `http://<ip>:8080/admin` (Pi-hole).

---

## 12. When the 8 TB drives are ready

1. Read [STORAGE.md](STORAGE.md) fully.
2. On the server, identify drives **twice**:

   ```bash
   lsblk -o NAME,SIZE,MODEL,SERIAL,TYPE,MOUNTPOINT
   ```

3. Set in `group_vars/homelab/vars.yml`:

   ```yaml
   storage_enabled: true
   storage_confirm_destroy: true
   zfs_drives:
     - /dev/sdb
     - /dev/sdc
     - /dev/sdd
     - /dev/sde
   ```

   Use your actual paths — **never** include the 256 GB OS disk.

4. Run:

   ```bash
   ansible-playbook holab_storage_playbook.yml
   ansible-playbook holab_site_playbook.yml
   ```

---

## Quick reference — drive roles

| Drive | Size | Role |
|-------|------|------|
| 256 GB SSD | ~256 GB | Fedora OS, Docker, `/opt/ho-lab` until ZFS |
| 4× HDD | 8 TB each | ZFS `tank` RAIDZ1 (~24 TB) — media, photos, downloads, Minecraft |

---

## Troubleshooting

| Problem | Check |
|---------|--------|
| Installer shows wrong disk | Sort by size; 256 GB only |
| SSH refused | `sudo systemctl status sshd`, firewall, IP |
| Ansible ping fails | `inventory.ini` IP/user, key auth |
| Docker permission denied | Re-run bootstrap; user in `docker` group |
| Services up but browser can't connect | `firewalld`, `ss -tlnp` on server |
| Pi-hole port 53 conflict | systemd-resolved may bind 53 — stop/disable or reconfigure |
