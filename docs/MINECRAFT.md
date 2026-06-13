# Minecraft Servers

ho-lab uses [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server) — one Docker image that auto-installs Minecraft versions, mod loaders, Modrinth mods, and CurseForge modpacks at container start.

## Why this image?

| Requirement | itzg/docker-minecraft-server |
|-------------|------------------------------|
| Vanilla | `TYPE=VANILLA` |
| Plugins (no mods) | `TYPE=PAPER` or `PURPUR` |
| Fabric mods | `TYPE=FABRIC` + `MODRINTH_PROJECTS` |
| NeoForge mods (modern Forge) | `TYPE=NEOFORGE` |
| Legacy Forge | `TYPE=FORGE` |
| Full modpack | CurseForge / Modrinth modpack env vars |
| Ansible-friendly | Single compose template, config in Git |

Alternatives considered:

| Tool | Verdict |
|------|---------|
| Pterodactyl | Full game panel — heavy for one homelab box |
| MineOS / Crafty | Web UI — extra moving parts; itzg is simpler |
| Manual Forge/Fabric install | Fragile updates; avoid |

## Mod loader cheat sheet (2026)

| Loader | Use when | Minecraft versions |
|--------|----------|-------------------|
| **Vanilla** | Pure survival, no mods | Latest |
| **Paper** | Plugins (EssentialsX, LuckPerms) — **not** mods | Latest |
| **Fabric** | Lightweight performance mods (Lithium, Sodium server-side) | 1.20.x – 1.21.x |
| **NeoForge** | Modern modded (most new modpacks) | 1.20.2+ |
| **Forge** | Older modpacks only | ≤ 1.20.1 mostly |

For new modded servers in 2026, default to **NeoForge** or **Fabric**. Use Forge only for legacy packs.

## RAM budget (32 GB homelab)

Your box also runs Jellyfin, Immich, and monitoring. Don't over-allocate.

| Server type | Suggested heap | Notes |
|-------------|----------------|-------|
| Vanilla / Paper (≤10 players) | 4 GB | `USE_AIKAR_FLAGS=true` |
| Fabric (light mods) | 6 GB | Lithium + Ferrite Core help |
| NeoForge (moderate modpack) | 8–10 GB | One modded server at a time |
| Heavy modpack (100+ mods) | 12 GB+ | Consider dedicated host |

Set `memory` per server in `group_vars/homelab/main.yml`. JVM heap ≠ total RAM — add ~1 GB overhead.

## Quick start

### 1. Enable a server in group_vars

Edit `ansible/inventory/group_vars/homelab/main.yml`:

```yaml
services:
  minecraft: true

minecraft_servers:
  - name: survival
    enabled: true
    port: 25565
    type: PAPER          # vanilla: VANILLA, plugins: PAPER, mods: FABRIC or NEOFORGE
    version: LATEST
    memory: 4G
    max_players: 10
```

### 2. Deploy

```bash
cd ansible
ansible-playbook -i inventory/hosts.yml playbooks/stack-gaming.yml
```

First start downloads the server jar and mod loader — can take 5–15 minutes.

### 3. Connect

Minecraft Java Edition → Multiplayer → Add Server → `<server-ip>:25565`

## Server presets (copy into group_vars)

### Vanilla survival

```yaml
- name: vanilla
  enabled: true
  port: 25565
  type: VANILLA
  version: LATEST
  memory: 4G
  max_players: 8
  difficulty: normal
  gamemode: survival
  motd: "ho-lab vanilla"
```

### Paper + plugins (plugin server, not modded)

```yaml
- name: paper
  enabled: true
  port: 25566
  type: PAPER
  version: LATEST
  memory: 4G
  max_players: 20
  modrinth_projects: []   # use spigot plugins via /plugins mount instead
```

Drop plugin JARs in `/tank/minecraft/paper/plugins/` on the host.

### Fabric with performance mods

```yaml
- name: fabric
  enabled: true
  port: 25567
  type: FABRIC
  version: "1.21.1"
  memory: 6G
  version_from_modrinth: true
  modrinth_projects:
    - fabric-api
    - lithium
    - ferrite-core
    - fabric-language-kotlin
```

Clients need **Fabric Loader + same mods** installed to join.

### NeoForge modded

```yaml
- name: modded
  enabled: true
  port: 25568
  type: NEOFORGE
  version: "1.21.1"
  memory: 10G
  modrinth_projects:
    - create
    - jei
```

### CurseForge modpack (auto-install)

Requires a CurseForge API key in vault ([get one here](https://console.curseforge.com/)):

```yaml
- name: all-the-mods
  enabled: false
  port: 25569
  type: AUTO_CURSEFORGE
  memory: 12G
  curseforge_modpack: "all-the-mods-10"   # slug from CurseForge URL
```

Set `vault_curseforge_api_key` in `vault.yml`.

## Managing mods

### Modrinth (recommended)

Add slugs to `modrinth_projects` in group_vars, redeploy:

```bash
ansible-playbook -i inventory/hosts.yml playbooks/stack-gaming.yml
```

The container downloads missing mods on start and removes ones no longer listed (`REMOVE_OLD_MODS=true`).

Modrinth slug format supports version pins: `sodium:mc1.21.1-0.6.0-fabric`

### Manual mods

Copy JARs into the server's `mods/` directory on the host:

```
/tank/minecraft/<server-name>/mods/
```

Then restart: `docker restart mc-<server-name>`

## Whitelist and ops

```yaml
- name: survival
  whitelist: "player1,player2"
  ops: "your_minecraft_username"
  enforce_whitelist: true
  online_mode: true   # set false only for cracked clients (not recommended)
```

## RCON (remote console)

```yaml
- name: survival
  enable_rcon: true
  rcon_port: 25575
```

Set `vault_minecraft_rcon_password` in vault.yml.

```bash
docker exec -i mc-survival rcon-cli say Hello from ho-lab
```

## Backups

World data lives at `/tank/minecraft/<server-name>/`. Back up with ZFS snapshots:

```bash
sudo zfs snapshot tank/minecraft@pre-update-$(date +%Y%m%d)
```

Optional: enable container backups via `BACKUP_INTERVAL=24h` in server config (see itzg docs).

## Port forwarding (play from outside LAN)

1. Forward UDP/TCP `25565` on your router to the server IP
2. Prefer **Tailscale** or **Playit.gg** instead of exposing ports
3. Set `online_mode: true` to prevent impersonation

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| Container restart loop | Check logs: `docker logs mc-<name>` — usually EULA or Java version |
| Java version error | Use `java21` image tag (default in ho-lab) or `java17` for old Forge packs |
| Mod version mismatch | Pin `version: "1.21.1"` and match client mod versions |
| Out of memory | Reduce `memory` on other services or disable unused MC servers |
| Slow first start | Normal — downloading MC jar + mods |

## Sources

- [itzg/docker-minecraft-server](https://github.com/itzg/docker-minecraft-server)
- [Modrinth mod support](https://github.com/itzg/docker-minecraft-server/blob/master/docs/mods-and-plugins/modrinth.md)
- [Java version tags](https://itzg-docker-minecraft-server.mintlify.app/versions/java)
- [NeoForge + Fabric via Sinytra Connector](https://github.com/Sinytra/Connector)
