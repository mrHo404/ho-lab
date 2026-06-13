# Architecture

## Design principles

1. **Single bare-metal host** — Docker Compose for all services (no Kubernetes overhead)
2. **Ansible as source of truth** — compose files are templated, never edited on the server
3. **Network isolation** — torrent traffic only through Gluetun; Pi-hole on dedicated IP
4. **Data on ZFS** — containers are disposable; datasets hold media, photos, downloads
5. **Pinned versions** — all container images tagged explicitly in group_vars

## Service matrix

| Service | Image (pinned in vars) | Port(s) | Network | Storage mount |
|---------|------------------------|---------|---------|---------------|
| Jellyfin | `jellyfin/jellyfin:10.10.7` | 8096 | bridge | `/tank/media` (ro) |
| Immich server | `ghcr.io/immich-app/immich-server:release` | 2283 | immich-net | `/tank/photos` |
| Immich ML | `ghcr.io/immich-app/immich-machine-learning:release` | — | immich-net | — |
| PostgreSQL | `tensorchord/pgvecto-rs:pg16-v0.3.0` | — | immich-net | `/opt/ho-lab/immich/db` |
| Redis | `redis:7.4-alpine` | — | immich-net | — |
| Pi-hole | `pihole/pihole:2025.03.0` | 53, 80 | host or macvlan | `/opt/ho-lab/pihole` |
| Gluetun | `qmcgaw/gluetun:v3.39.0` | 8080, 6881 | bridge | config volume |
| qBittorrent | `lscr.io/linuxserver/qbittorrent:5.0.4` | via gluetun | `service:gluetun` | `/tank/downloads` |
| Uptime Kuma | `louislam/uptime-kuma:1.23.16` | 3001 | monitoring-net | `/opt/ho-lab/uptime-kuma` |
| Prometheus | `prom/prometheus:v3.2.1` | 9090 | monitoring-net | `/opt/ho-lab/prometheus` |
| Grafana | `grafana/grafana:11.5.2` | 3000 | monitoring-net | `/opt/ho-lab/grafana` |
| node_exporter | `prom/node-exporter:v1.9.0` | 9100 | host | — |
| cAdvisor | `gcr.io/cadvisor/cadvisor:v0.51.0` | 8081 | host | — |
| Minecraft | `itzg/minecraft-server:java21` | 25565+ | bridge | `/tank/minecraft/<name>` |

## Docker networks

```
bridge (default)     → Jellyfin
immich-net           → Immich stack (isolated DB)
monitoring-net       → Prometheus, Grafana, Uptime Kuma
host / macvlan       → Pi-hole (needs port 53)
gluetun (implicit)   → qBittorrent shares Gluetun network namespace
```

## Ansible role dependency graph

```
bootstrap (common + docker)
    │
    ├── storage (ZFS — manual confirmation gate)
    │
    └── site.yml
            ├── pihole
            ├── jellyfin
            ├── immich
            ├── gluetun_qbittorrent
            ├── monitoring
            └── minecraft
```

## Directory layout on server

```
/opt/ho-lab/                    # Ansible-managed root
├── compose/
│   ├── jellyfin/
│   ├── immich/
│   ├── pihole/
│   ├── gluetun-qbittorrent/
│   ├── monitoring/
│   └── minecraft/
├── pihole/                     # Pi-hole config persistence
├── immich/db/                  # PostgreSQL data
├── prometheus/
├── grafana/
└── uptime-kuma/

/tank/                          # ZFS pool (after storage.yml)
├── media/
│   ├── movies/
│   └── tv/
├── photos/                     # Immich library
├── downloads/                  # qBittorrent
├── minecraft/                  # Minecraft worlds + mods
└── backups/
```

## DNS cutover plan

1. Deploy Pi-hole with router still using upstream DNS
2. Test: `dig @<server-ip> ads.google.com` → should return 0.0.0.0
3. Set Pi-hole conditional forwarding for local domain (optional)
4. Change router DNS to server IP (or DHCP option 6)
5. Keep router's secondary DNS blank — Pi-hole handles upstream failover

## Security notes

- qBittorrent WebUI must not be exposed to WAN
- Immich and Jellyfin: use reverse proxy (Traefik/Caddy) + TLS if exposing beyond LAN
- Ansible Vault for all secrets; never commit `.env` with real credentials
- Pi-hole admin password rotated from default immediately
- Gluetun `FIREWALL_OUTBOUND_SUBNETS` includes your LAN CIDR for local service access

## Future extensions (not in initial scaffold)

- [ ] Traefik reverse proxy with internal TLS
- [ ] Tailscale for remote Immich/Jellyfin access
- [ ] Restic → B2/S3 offsite backup of `/tank/photos` and configs
- [ ] Tdarr/Unmanic for overnight CPU transcodes (until GPU added)
- [ ] Homepage dashboard aggregating all service links
