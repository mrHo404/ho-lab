# Ansible conventions (configuration-ansible aligned)

ho-lab follows the same structural patterns as the Pazz `configuration-ansible` repository.

## Repository layout

| Path | Purpose |
|------|---------|
| `ansible.cfg` | Repo-root Ansible config |
| `inventory.ini` | Host inventory (local copy from `.example`) |
| `group_vars/all/` | Variables for all hosts |
| `group_vars/homelab/` | Group vars + encrypted `vault.yml` |
| `host_vars/<host>/vars.yml` | Per-host overrides (IP-adjacent, timezone, LAN CIDR) |
| `holab_*_playbook.yml` | One playbook per stack at repo root |
| `roles/` | Reusable roles |
| `vault_password.txt` | Local vault passphrase (gitignored) |
| `project_setup.sh` | venv + collections install |

## Playbook naming

Pattern: `{scope}_{purpose}_playbook.yml`

Examples in this repo:

- `holab_bootstrap_playbook.yml` — host bootstrap
- `holab_minecraft_playbook.yml` — Minecraft only
- `holab_site_playbook.yml` — full stack (imports other playbooks)

## Tags

- Every play tags core scope with `holab`
- Stack tags: `pihole`, `jellyfin`, `immich`, `minecraft`, `monitoring`, `gluetun`, etc.
- Use `--tags holab,minecraft` or `--limit holab` like configuration-ansible

## Variables

| Scope | Location | Example |
|-------|----------|---------|
| All hosts | `group_vars/all/utils.yml` | `ansible_managed_with_git_info` |
| Homelab group | `group_vars/homelab/vars.yml` | `services`, `images`, `minecraft_servers` |
| Single host | `host_vars/holab/vars.yml` | `ho_lab_timezone`, `gluetun.lan_subnets` |
| Secrets | `group_vars/homelab/vault.yml` | `vault_*` (encrypted) |

Nested service config uses dict keys (`jellyfin:`, `minecraft:`) matching configuration-ansible's `prometheus:`, `grafana:` pattern.

## Role conventions (target)

New roles should use configuration-ansible variable prefixes:

- Input: `role_name__variable` (double underscore)
- Internal facts: `role_name___variable` (triple underscore)

Existing ho-lab roles use legacy flat names (`ho_lab_root`, `services`) — migrate when touching a role.

## Role splitting

1. **Generic role** — e.g. `docker` installs Docker on any Fedora/Debian host
2. **Stack role** — e.g. `minecraft` templates compose and deploys servers
3. **Playbook** — combines roles; tagged for partial runs

## Vault

```bash
cp group_vars/homelab/vault.yml.example group_vars/homelab/vault.yml
ansible-vault encrypt group_vars/homelab/vault.yml
echo 'passphrase' > vault_password.txt && chmod 600 vault_password.txt
ansible-playbook holab_validate_playbook.yml
```

## Managed file headers

Templates may use `ansible_managed_with_git_info` from `group_vars/all/utils.yml` in shell scripts and configs.
