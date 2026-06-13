# Reference compose files — production deploys use Ansible templates in roles/

These examples mirror the Jinja2 templates. Use them for local testing or as documentation.

See `ansible/roles/*/templates/docker-compose.yml.j2` for the authoritative versions.

## Stacks

| File | Services |
|------|----------|
| `jellyfin/docker-compose.yml` | Jellyfin media server |
| `immich/docker-compose.yml` | Immich photo backup |
| `pihole/docker-compose.yml` | Pi-hole DNS |
| `gluetun-qbittorrent/docker-compose.yml` | VPN + torrents |
| `monitoring/docker-compose.yml` | Uptime Kuma, Prometheus, Grafana |

Deploy via Ansible:

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/site.yml
```
