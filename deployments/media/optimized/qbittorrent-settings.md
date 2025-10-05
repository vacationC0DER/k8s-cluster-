# qBittorrent Optimization Settings

Apply these settings via the qBittorrent Web UI: http://10.69.1.158:8080

## Connection Settings

**Settings → Connection:**

- **Peer connection protocol:** TCP and μTP
- **Listening Port:** 6881 (already exposed in LoadBalancer)
- **Use UPnP / NAT-PMP:** Disabled (using LoadBalancer)
- **Connections Limits:**
  - Global maximum connections: 500
  - Maximum connections per torrent: 100
  - Global maximum upload slots: 20
  - Maximum upload slots per torrent: 4

## Speed Settings

**Settings → Speed:**

- **Global Rate Limits:**
  - Upload: 10000 KB/s (10 MB/s) - adjust based on your upload speed
  - Download: 0 (unlimited) - you have plenty of bandwidth

- **Alternative Rate Limits (for peak hours):**
  - Upload: 5000 KB/s
  - Download: 0
  - Schedule: Enable if you want to limit during certain hours

## BitTorrent Settings

**Settings → BitTorrent:**

- **Privacy:**
  - Enable DHT: Yes
  - Enable PeX: Yes
  - Enable Local Peer Discovery: Yes
  - Encryption mode: Prefer encryption
  - Enable anonymous mode: No (breaks DHT/PeX)

- **Seeding Limits:**
  - When ratio reaches: 2.0 (then pause)
  - When seeding time reaches: 10080 minutes (1 week)
  - Action: Pause torrent

- **Automatically add torrents from:** (optional for *arr integration)
  - Leave blank - *arr services handle this via API

## Advanced Settings

**Settings → Advanced:**

- **Network Interface:** eth0
- **Disk Cache:**
  - Size: 256 MB (good balance for your RAM allocation)
  - Disk cache expiry: 60 seconds

- **File Pool Size:** 100
- **Outstanding memory:** 512 MiB
- **Send buffer:** 5 MiB (default)
- **Receive buffer:** 5 MiB (default)

- **Asynchronous I/O threads:** 10
- **File pool size:** 5000
- **Checking memory usage:** 32 MiB

## Downloads Settings

**Settings → Downloads:**

- **Default Save Path:** /downloads
- **Keep incomplete torrents in:** /downloads/incomplete (optional)
- **Copy .torrent files to:** (leave blank)
- **Copy .torrent files for finished downloads to:** (leave blank)

- **Pre-allocate disk space:** Yes (prevents fragmentation)
- **Append .!qB extension:** Yes (marks incomplete files)

- **When adding a torrent:**
  - Create subfolder: No (Radarr/Sonarr handle folder structure)
  - Start torrent: Yes

## Categories (Already Configured)

**Settings → Downloads → Category:**

- movies → /downloads/movies
- tv → /downloads/tv
- music → /downloads/music

These should already be set up from *arr integration.

## Web UI Settings

**Settings → Web UI:**

- **Authentication:**
  - Username: admin
  - Password: (your current password)

- **Bypass authentication for clients on localhost:** No
- **Bypass authentication for clients in whitelisted IP subnets:** No
- **Enable clickjacking protection:** Yes
- **Enable CSRF protection:** Yes
- **Enable Host header validation:** Yes

- **Server domains:** (leave default or add: 10.69.1.158)

## Recommended Performance Settings Summary

```
Global Connections: 500
Connections per torrent: 100
Upload slots: 20 global, 4 per torrent
Disk cache: 256 MB
Pre-allocate disk space: Yes
Seed ratio limit: 2.0
Seed time limit: 1 week
```

These settings balance:
- Good download/upload performance
- Reasonable seeding (2.0 ratio or 1 week)
- Efficient disk usage
- Memory usage within 1-2GB allocation

## Apply Changes

After configuring, click **Save** at the bottom of each settings page.

Monitor resource usage:
```bash
kubectl top pod -n media | grep qbittorrent
```

Adjust limits if needed based on actual usage.
