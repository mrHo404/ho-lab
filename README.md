# ho-lab

Ansible-managed homelab (Ryzen 3700X / 32 GB / 4×8 TB). Layout and conventions follow the Pazz `configuration-ansible` project structure.

**Defaults:** Fedora Server · `vanilla-perf` Minecraft · Docker Compose stacks via Ansible.

## Documentation

| File | Purpose |
|------|---------|
| [ARCHITECTURE.md](ARCHITECTURE.md) | Network, services, on-disk layout |
| [README_CONVENTIONS.md](README_CONVENTIONS.md) | Playbook/role/tag conventions |
| [docs/](docs/) | Storage, hardware, Minecraft, OS guides |

## Setup

```bash
./project_setup.sh
cp inventory.ini.example inventory.ini
cp group_vars/homelab/vault.yml.example group_vars/homelab/vault.yml
# Edit inventory.ini and vault.yml
ansible-vault encrypt group_vars/homelab/vault.yml
echo 'your-passphrase' > vault_password.txt && chmod 600 vault_password.txt
```

## Running playbooks

Dry-run:

```bash
ansible-playbook holab_validate_playbook.yml --check
ansible-playbook holab_site_playbook.yml --check
```

Deploy:

```bash
ansible-playbook holab_validate_playbook.yml
ansible-playbook holab_bootstrap_playbook.yml
ansible-playbook holab_storage_playbook.yml   # optional — destructive
ansible-playbook holab_site_playbook.yml
```

Per-stack playbooks (same naming as configuration-ansible):

| Playbook | Stack |
|----------|-------|
| `holab_bootstrap_playbook.yml` | OS packages + Docker |
| `holab_storage_playbook.yml` | ZFS RAIDZ1 |
| `holab_pihole_playbook.yml` | Pi-hole |
| `holab_media_playbook.yml` | Jellyfin + Immich |
| `holab_downloads_playbook.yml` | Gluetun + qBittorrent |
| `holab_monitoring_playbook.yml` | Uptime Kuma + Prometheus + Grafana |
| `holab_minecraft_playbook.yml` | vanilla-perf Minecraft |
| `holab_site_playbook.yml` | All stacks |

Limit or tag (configuration-ansible style):

```bash
ansible-playbook holab_site_playbook.yml --limit holab --tags minecraft
ansible-playbook holab_minecraft_playbook.yml --tags holab,minecraft
```

## Repository layout

```
ho-lab/
├── ansible.cfg
├── inventory.ini              # local — copy from inventory.ini.example
├── vault_password.txt         # local — gitignored
├── holab_*_playbook.yml       # one playbook per stack
├── group_vars/
│   ├── all/utils.yml
│   └── homelab/vars.yml
├── host_vars/holab/vars.yml
├── roles/
├── docs/
└── project_setup.sh
```

## License

MIT
