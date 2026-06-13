# Hardware Notes

## Platform summary

| Component | Detail |
|-----------|--------|
| CPU | AMD Ryzen 7 3700X — 8 cores / 16 threads, 65W TDP, **no iGPU** |
| RAM | 32 GB DDR4 — sufficient for ZFS + Immich ML + Jellyfin |
| Storage | 4× 8 TB HDD — see [STORAGE.md](STORAGE.md) |
| Network | Gigabit minimum; 2.5GbE NIC optional for 4K remux direct play |

## Transcoding reality check

The 3700X has **no integrated graphics**. Jellyfin will fall back to **software transcoding** for unsupported client codecs.

### What works without a GPU

- **Direct play / direct stream** — no transcode needed; 3700X handles this easily
- **Audio transcode** — lightweight
- **1–2 simultaneous 1080p H.264 transcodes** — usually fine on CPU

### What struggles without a GPU

- 4K HEVC → 1080p H.264 (common for older clients)
- HDR → SDR tone mapping ([Jellyfin docs](https://jellyfin.org/docs/general/administration/hardware-selection/))
- Multiple simultaneous transcode streams

### GPU recommendations (if buying)

| GPU | TDP | Transcode | Price range | Notes |
|-----|-----|-----------|-------------|-------|
| Intel Arc A310 | 30W | Excellent | ~$100 | Best modern low-power choice; needs kernel 6.2+ |
| NVIDIA GTX 1060 6GB | 120W | Very good | ~$80 used | NVENC, HDR tone map; patch for >3 streams |
| NVIDIA GTX 1050 Ti | 75W | Good | ~$60 used | Low power, no AV1 |
| AMD RX 6400 | ~53W | Decode only | ~$100 | **No encode hardware** — avoid for Jellyfin |

If your TVs/phones mostly direct-play HEVC/H.264, you can defer GPU purchase and monitor Jellyfin Dashboard → Active Sessions for `(Transcode)` entries.

## RAM budget (approximate)

| Consumer | RAM |
|----------|-----|
| OS + Docker overhead | 2 GB |
| ZFS ARC (adjustable) | 4–8 GB |
| Immich stack (incl. ML) | 4–6 GB |
| Jellyfin | 1–2 GB |
| Pi-hole | 256 MB |
| Monitoring stack | 1 GB |
| Headroom | 8+ GB |

32 GB total is comfortable. If Immich ML causes pressure, set `MACHINE_LEARNING_CACHE_FOLDER` and limit concurrent ML jobs in Immich admin.

## Power and cooling

- 3700X + 4 spinning HDDs ≈ 80–120W under load
- Ensure case airflow over drives (HDDs run hot in RAID)
- UPS strongly recommended — unclean shutdown risks ZFS pool import issues

## Drive mounting

Prefer direct SATA attachment over USB multi-bay enclosures for ZFS:

- USB bridges can hide SMART data
- UAS instability causes pool degradation scares
- If using a HBA/SAS expander, ensure IT-mode flashing

## NIC upgrade (optional)

Direct play 4K remux (~80 Mbps) fits gigabit. Consider 2.5GbE if:

- Multiple simultaneous 4K streams from different clients
- Large Immich library scans over network
- 10GbE is overkill for this build unless you have a 10G switch

## Checklist before first boot

- [ ] OS SSD installed separately from 4×8 TB
- [ ] All SATA cables seated; confirm BIOS sees 4 drives
- [ ] Ethernet connected (avoid WiFi for NAS)
- [ ] BIOS: disable C-states issues if Docker timer drift observed (rare)
- [ ] Decide GPU strategy (defer / buy / direct-play only)
