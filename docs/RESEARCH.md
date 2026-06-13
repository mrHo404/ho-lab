# Homelab Research Summary

Research conducted June 2026 for a Ryzen 3700X / 32 GB / 4×8 TB homelab targeting Jellyfin, phone backup, Pi-hole, VPN-protected torrents, and Ansible-managed monitoring.

> **Note:** Deep research via `parallel-cli` was unavailable in the authoring environment. This document synthesizes web research with inline source links.

---

## Executive summary

| Area | Recommendation |
|------|----------------|
| Base OS | **Debian 12** (stable, low overhead) or Ubuntu 24.04 LTS — see [OS-OPTIONS.md](OS-OPTIONS.md) |
| Storage (4× identical 8 TB) | **ZFS RAIDZ1** (~24 TB usable) for mixed media + phone backup; MergerFS+SnapRAID if media-only |
| Phone backup | **Immich** — native iOS/Android auto-upload, Google Photos UX |
| Media server | **Jellyfin** in Docker with pinned image tags |
| Ad blocking | **Pi-hole v6** — point router DNS or use DHCP option 6 |
| Torrents | **Gluetun** + **qBittorrent** (`network_mode: service:gluetun`) |
| VPN | **ProtonVPN WireGuard** (port forwarding) or **NordVPN OpenVPN** |
| Monitoring | **Uptime Kuma** (availability) + **Prometheus/Grafana** (metrics) |
| Minecraft | **itzg/docker-minecraft-server** — Fabric, NeoForge, Paper, vanilla, modpacks |
| IaC | **Ansible** + `community.docker.docker_compose_v2` |

---

## Storage: ZFS vs MergerFS + SnapRAID

### MergerFS + SnapRAID

Best for **write-once, read-many** media libraries ([DiyMediaServer](https://diymediaserver.com/post/2026/mergerfs-media-servers-2026/), [DoTheEvo/NAS-MergerFS-SnapRAID](https://github.com/DoTheEvo/NAS-MergerFS-SnapRAID)):

- Pools mismatched drive sizes without rebuild
- Low RAM overhead
- SnapRAID parity is **scheduled** (typically nightly), not real-time
- Poor fit for frequently changing data (phone uploads between syncs)

With **4× identical 8 TB** drives, the flexibility advantage is minimal.

### ZFS RAIDZ1

Best for **mixed workloads** (media + phone backup):

- Real-time single-parity protection (~24 TB usable from 4×8 TB)
- Checksumming and self-healing on supported configurations
- 32 GB RAM is sufficient for this pool size ([HN discussion](https://news.ycombinator.com/item?id=46065034))
- Snapshots for backup/versioning of Immich database and config

**Trade-off:** Cannot expand by adding one drive — vdevs must be planned upfront. With four identical drives, RAIDZ1 is a natural fit.

### Recommended layout (ZFS RAIDZ1)

| Dataset | Purpose | Recordsize |
|---------|---------|------------|
| `tank/media/movies` | Jellyfin movies | 1M |
| `tank/media/tv` | Jellyfin TV | 1M |
| `tank/photos` | Immich library | 128K |
| `tank/downloads` | qBittorrent (VPN only) | default |
| `tank/backups` | Syncthing/restic targets | 128K |

---

## Jellyfin on Ryzen 3700X

The 3700X has **no integrated GPU** ([cpugate specs](https://cpugate.com/cpu-specs/amd_ryzen_7_3700x)). Jellyfin docs warn CPU-only transcoding is not recommended for HEVC/HDR content ([Jellyfin hardware selection](https://jellyfin.org/docs/general/administration/hardware-selection/)).

### Options

1. **Direct play only** — works if clients support the source codec (most 4K TVs handle HEVC; older devices may not)
2. **Add a GPU** — Intel Arc A310 (~30W, excellent transcode/$) or used GTX 1060/1050 Ti ([Jellyfin forum](https://forum.jellyfin.org/t-gpu-recommendation-for-transcoding))
3. **Pre-transcode** with `tdarr` or `unmanic` overnight on CPU

### If adding a GPU (Docker)

Pass through `/dev/dri`, add `render` and `video` groups ([Jellyfin VAAPI docs](https://jellyfin.org/docs/general/administration/hardware-acceleration/)):

```yaml
devices:
  - /dev/dri:/dev/dri
group_add:
  - "{{ render_gid }}"
  - "{{ video_gid }}"
```

Enable **VA-API** in Jellyfin Dashboard → Playback → Hardware acceleration.

---

## Phone backup: Immich vs alternatives

| Tool | Auto-upload | AI search | Complexity | RAM |
|------|-------------|-----------|------------|-----|
| **Immich** | ✅ Native apps | ✅ Faces, CLIP | High (6+ containers) | 4 GB+ |
| PhotoPrism | ❌ | ✅ | Medium | 2 GB |
| Syncthing | ❌ (sync only) | ❌ | Low | Minimal |

**Recommendation:** Immich for phone backup ([Budget Homelab guide](https://budgethomelab.com/guides/immich-setup-guide/), [selfhostedguides comparison](https://selfhostedguides.com/immich-vs-photoprism-comparison/)).

Optional: add **Syncthing** for generic folder sync (documents, secondary backup node).

Remote access without port forwarding: **Tailscale** or **WireGuard** on server + phones.

---

## Pi-hole

- Run as Docker container with static IP or host networking
- Point router DNS to Pi-hole IP (or DHCP option 6)
- Keep a secondary upstream (Cloudflare 1.1.1.1, Quad9) configured in Pi-hole
- **Do not** cut over household DNS until Pi-hole is tested with `dig @<pihole-ip> doubleclick.net`

Unbound as recursive resolver is optional but reduces DNS leak surface.

---

## qBittorrent + VPN (Gluetun)

Gluetun ([github.com/qdm12/gluetun](https://github.com/qdm12/gluetun)) supports 60+ providers including ProtonVPN and NordVPN.

### Pattern

```yaml
qbittorrent:
  network_mode: "service:gluetun"
```

All qBittorrent traffic uses Gluetun's network stack — killswitch by design ([selfhostsetup guide](https://selfhostsetup.com/posts/gluetun-vpn-docker-container/)).

### Provider notes

| Provider | Protocol | Port forwarding | Notes |
|----------|----------|-----------------|-------|
| ProtonVPN | WireGuard | ✅ (paid plans) | Use `VPN_PORT_FORWARDING=on`; sync port to qBittorrent via sidecar or `VPN_PORT_FORWARDING_UP_COMMAND` ([discussion #2686](https://github.com/qdm12/gluetun/discussions/2686)) |
| NordVPN | OpenVPN / WireGuard | ❌ (limited) | Works but seeding performance may suffer |

Expose qBittorrent WebUI ports on the **gluetun** service, not qbittorrent.

---

## Monitoring stack

Layered approach ([Budget Homelab](https://budgethomelab.com/guides/grafana-prometheus-homelab/), [usulnet observability guide](https://articles.usulnet.com/self-hosted-monitoring-stack.html)):

| Layer | Tool | Purpose |
|-------|------|---------|
| Availability | Uptime Kuma | HTTP/TCP/ping checks, status page, alerts |
| Metrics | Prometheus | Time-series collection |
| Visualization | Grafana | Dashboards (import community IDs 1860, 14282) |
| Host metrics | node_exporter | CPU, RAM, disk |
| Container metrics | cAdvisor | Per-container resource usage |

Uptime Kuma answers "is it up?"; Grafana answers "why is disk filling?" and "which container spiked CPU?".

---

## Ansible patterns

Reference implementations: [BenSuskins/homelab-ansible-plays](https://github.com/BenSuskins/homelab-ansible-plays), [n0one42/ansible-homelab](https://github.com/n0one42/ansible-homelab).

### Best practices

1. Template `docker-compose.yml` with Jinja2 — inject host paths, UIDs, image tags from inventory
2. Pin image tags — never `:latest` in production ([ansiblebyexample](https://www.ansiblebyexample.com/articles/ansible-docker-compose-deploy-multi-container-apps))
3. Secrets in **Ansible Vault** — deploy `.env` with `mode: 0600`
4. Use `community.docker.docker_compose_v2` for idempotent deploys
5. Health checks in compose + `uri` module post-deploy verification
6. `serial: 1` for rolling updates (single-host homelab: less critical)

---

## Minecraft servers

**Recommendation:** [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) with `TYPE` env var for mod loader selection.

| Goal | TYPE | Notes |
|------|------|-------|
| Pure survival | `VANILLA` | Simplest |
| Plugins (EssentialsX, etc.) | `PAPER` | Not for mods |
| Modern lightweight mods | `FABRIC` | + `MODRINTH_PROJECTS` |
| Modern heavy modded | `NEOFORGE` | Replaces Forge for 1.20.2+ |
| Full modpack | `AUTO_CURSEFORGE` | Needs CurseForge API key |

Mods auto-download from Modrinth at container start. See [docs/MINECRAFT.md](MINECRAFT.md).

**RAM on 32 GB box:** 4 GB vanilla/Paper, 6 GB Fabric, 8–10 GB NeoForge — only run one heavy modded server at a time alongside Jellyfin/Immich.

---

## Network diagram (logical)

```
                    ┌─────────────┐
   Internet ───────►│   Router    │
                    │  DHCP/DNS   │
                    └──────┬──────┘
                           │ LAN 192.168.x.0/24
              ┌────────────┼────────────┐
              │            │            │
         ┌────▼────┐  ┌────▼────┐  ┌────▼────┐
         │ Pi-hole │  │ Phones  │  │  TVs    │
         │  :53    │  │ Immich  │  │Jellyfin │
         └────┬────┘  │  app    │  │  :8096  │
              │       └─────────┘  └─────────┘
         ┌────▼──────────────────────────────┐
         │         ho-lab server             │
         │  ┌─────────┐  ┌───────────────┐   │
         │  │ Jellyfin│  │    Immich     │   │
         │  └─────────┘  └───────────────┘   │
         │  ┌─────────┐  ┌───────────────┐   │
         │  │ Gluetun │──│  qBittorrent  │   │
         │  │  (VPN)  │  │  (no direct   │   │
         │  └────┬────┘  │   internet)   │   │
         │       │       └───────────────┘   │
         │  ┌────▼────────────────────────┐  │
         │  │ Uptime Kuma / Grafana / ... │  │
         │  └─────────────────────────────┘  │
         │  ┌─────────────────────────────┐  │
         │  │ ZFS tank (RAIDZ1 ~24 TB)    │  │
         │  └─────────────────────────────┘  │
         └───────────────────────────────────┘
```

---

## Sources

- [Best NAS for Media Servers (2026)](https://diymediaserver.com/post/media-server-storage-2025/)
- [MergerFS Guide (2026)](https://diymediaserver.com/post/2026/mergerfs-media-servers-2026/)
- [NAS-MergerFS-SnapRAID](https://github.com/DoTheEvo/NAS-MergerFS-SnapRAID)
- [MergerFS + SnapRAID Budget Alternative](https://easyhtpc.com/posts/19-mergerfs-snapraid-guide/)
- [Jellyfin Hardware Selection](https://jellyfin.org/docs/general/administration/hardware-selection/)
- [Jellyfin Hardware Acceleration](https://jellyfin.org/docs/general/administration/hardware-acceleration/)
- [Gluetun](https://github.com/qdm12/gluetun)
- [Gluetun + ProtonVPN + qBittorrent](https://github.com/qdm12/gluetun/discussions/2686)
- [Gluetun Docker Guide](https://www.simplehomelab.com/gluetun-docker-guide/)
- [Immich Setup Guide](https://budgethomelab.com/guides/immich-setup-guide/)
- [Immich vs PhotoPrism](https://selfhostedguides.com/immich-vs-photoprism-comparison/)
- [Grafana + Prometheus Homelab](https://budgethomelab.com/guides/grafana-prometheus-homelab/)
- [Self-Hosted Monitoring Stack](https://articles.usulnet.com/self-hosted-monitoring-stack.html)
- [Ansible Docker Compose Deploy](https://www.ansiblebyexample.com/articles/ansible-docker-compose-deploy-multi-container-apps)
- [homelab-ansible-plays](https://github.com/BenSuskins/homelab-ansible-plays)
- [ansible-homelab](https://github.com/n0one42/ansible-homelab)
- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [Modrinth mod support (itzg docs)](https://github.com/itzg/docker-minecraft-server/blob/master/docs/mods-and-plugins/modrinth.md)
