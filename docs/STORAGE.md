# Storage Planning — 4×8 TB

**⚠️ Destructive operations.** Read this entire document before running `playbooks/storage.yml`.

## Raw capacity

| Layout | Usable | Redundancy | Best for |
|--------|--------|------------|----------|
| RAIDZ1 (recommended) | ~24 TB | 1 drive | Mixed media + phone backup |
| RAIDZ2 | ~16 TB | 2 drives | Maximum safety, less space |
| MergerFS 3+1 parity | ~24 TB | 1 drive (scheduled) | Media-only, infrequent writes |
| No redundancy (stripe) | ~32 TB | None | Not recommended |

## Recommended: ZFS RAIDZ1

With four **identical** 8 TB drives and a mixed workload (Jellyfin + Immich phone uploads), ZFS RAIDZ1 is the best default:

- Real-time parity — phone uploads are protected immediately
- Checksums detect silent bit rot
- Snapshots for Immich DB backups and config rollback
- 32 GB RAM is adequate for ~24 TB usable ([community guidance](https://news.ycombinator.com/item?id=46065034))

### Create pool (manual — not automated by default)

```bash
# Identify drives — VERIFY TWICE
lsblk -o NAME,SIZE,MODEL,SERIAL

# Example: /dev/sdb /dev/sdc /dev/sdd /dev/sde
# DO NOT include your OS drive

sudo zpool create -f -o ashift=12 \
  -O compression=lz4 \
  -O atime=off \
  -O xattr=sa \
  -O acltype=posixacl \
  tank raidz1 /dev/sdb /dev/sdc /dev/sdd /dev/sde

# Datasets
sudo zfs create -o recordsize=1M     tank/media
sudo zfs create -o recordsize=1M     tank/media/movies
sudo zfs create -o recordsize=1M     tank/media/tv
sudo zfs create -o recordsize=128K   tank/photos
sudo zfs create                      tank/downloads
sudo zfs create -o recordsize=128K   tank/backups
sudo zfs create -o recordsize=128K   tank/minecraft

# Optional: cap downloads so torrents can't fill the pool
sudo zfs set quota=2T tank/downloads

# Scrub schedule (monthly)
echo "0 3 1 * * root zpool scrub tank" | sudo tee /etc/cron.d/zfs-scrub
```

### Why not MergerFS + SnapRAID here?

SnapRAID parity syncs on a schedule (typically nightly). Phone photos uploaded at 3 PM are unprotected until the 2 AM sync. For irreplaceable family photos, real-time parity matters.

MergerFS remains a valid choice if you later add a **separate SSD pool** for Immich and keep HDDs for media-only with SnapRAID.

## OS drive

Keep the OS on a **separate device**:

- 256 GB+ NVMe SSD or SATA SSD
- Do not install the OS on the RAIDZ1 pool

## SMART monitoring

```bash
sudo apt install smartmontools
sudo smartctl -a /dev/sdb  # repeat per drive

# Add to cron or use Ansible role
sudo smartd -q showtests
```

## Backup strategy (3-2-1)

| Copy | Where | Tool |
|------|-------|------|
| 1 | ZFS pool (primary) | — |
| 2 | External USB or second machine | Syncthing / rsync |
| 3 | Offsite (cloud) | restic → Backblaze B2 |

Immich PostgreSQL: nightly `pg_dump` to `tank/backups/immich/` via ZFS snapshot.

## Pre-flight checklist

- [ ] OS is on a separate drive from the 4×8 TB drives
- [ ] Drive serial numbers documented
- [ ] UPS recommended (ZFS hates unclean shutdowns)
- [ ] `storage.yml` has `storage_confirm_destroy: true` set deliberately
- [ ] Test scrub scheduled
