# Media Stack Configuration Guide

## Overview

This guide provides complete step-by-step configuration for the media automation stack after initial deployment.

**Status:** Fresh installation detected - all services need configuration
**Created:** 2025-10-06

---

## 🔍 **Current Status**

```bash
✅ All pods running (1/1 Ready)
✅ LoadBalancer IPs assigned
✅ Network connectivity working
❌ Prowlarr: 0 indexers configured
❌ Prowlarr: 0 applications (Radarr/Sonarr) connected
❌ Radarr: 0 indexers, 0 download clients
❌ Sonarr: 0 indexers, 0 download clients
❌ No API integration between services
```

---

## 📋 **Service Information**

### **URLs:**
```
Prowlarr:     http://10.69.1.155:9696
Radarr:       http://10.69.1.156:7878
Sonarr:       http://10.69.1.157:8989
Lidarr:       http://10.69.1.159:8686
qBittorrent:  http://10.69.1.158:8080
SABnzbd:      http://10.69.1.161:8080
Overseerr:    http://10.69.1.160:5055
Plex:         http://10.69.1.165:32400
```

### **API Keys:**
```
Prowlarr:  a3d5b85bde3840e593a77d3956e20dba
Radarr:    bfb36ca57d2b46fbb6bd3a4d7b0f979f
Sonarr:    80bf1996b11e47cd8a60d5d148fed38d
```

### **Internal DNS (for service-to-service):**
```
prowlarr.media.svc.cluster.local:9696
radarr.media.svc.cluster.local:7878
sonarr.media.svc.cluster.local:8989
lidarr.media.svc.cluster.local:8686
qbittorrent.media.svc.cluster.local:8080
sabnzbd.media.svc.cluster.local:8080
plex.media.svc.cluster.local:32400
```

---

## 📖 **Configuration Order**

**CRITICAL: Follow this exact order to avoid connection issues**

1. ✅ qBittorrent (Download Client)
2. ✅ Prowlarr (Indexer Manager)
   - Add indexers (public + private)
3. ✅ Radarr (Movies)
   - Connect to Prowlarr
   - Connect to qBittorrent
4. ✅ Sonarr (TV Shows)
   - Connect to Prowlarr
   - Connect to qBittorrent
5. ✅ Lidarr (Music) - Optional
6. ✅ Overseerr (Request Management) - Optional
7. ✅ Plex (Media Server)

---

## 🔧 **Step-by-Step Configuration**

### **Step 1: Configure qBittorrent**

**URL:** http://10.69.1.158:8080

1. **Initial Login**
   - Default username: `admin`
   - Default password: `adminadmin`
   - **IMPORTANT:** Change password immediately

2. **Settings → Web UI**
   - Enable "Bypass authentication for clients on localhost"
   - Enable "Bypass authentication for clients in whitelisted IP subnets"
   - Whitelist: `10.244.0.0/16` (Kubernetes pod network)
   - Save

3. **Settings → Downloads**
   - Default Save Path: `/downloads/complete/`
   - Keep incomplete torrents in: `/downloads/incomplete/`
   - Category defaults:
     - `radarr` → `/downloads/complete/radarr/`
     - `sonarr` → `/downloads/complete/sonarr/`
     - `lidarr` → `/downloads/complete/lidarr/`
   - Save

4. **Test Connectivity**
   ```bash
   curl -u admin:YOUR_PASSWORD http://10.69.1.158:8080/api/v2/app/version
   ```

---

### **Step 2: Configure Prowlarr**

**URL:** http://10.69.1.155:9696

#### **A. Add Indexers**

1. **Indexers → Add Indexer**

**Public Indexers (No Account Required):**
- Search for: `1337x`, `RARBG`, `ThePirateBay`, `YTS`, `EZTV`, `Torrentz2`
- Click each → Add
- Test → Save

**Private Indexers (Requires Account):**
- Examples: `IPTorrents`, `TorrentLeech`, `PassThePopcorn`, etc.
- You'll need:
  - Username/Email
  - Password or API Key
  - RSS Key (from tracker's profile)

2. **Verify Indexers Added**
   ```bash
   curl -H "X-Api-Key: a3d5b85bde3840e593a77d3956e20dba" \
     http://10.69.1.155:9696/api/v1/indexer | python3 -c \
     "import sys,json; data=json.load(sys.stdin); print(f'Total: {len(data)}'); \
     [print(f'  - {x[\"name\"]} ({x[\"protocol\"]})') for x in data[:10]]"
   ```

#### **B. Add Applications (Radarr/Sonarr)**

1. **Settings → Apps → Add Application → Radarr**
   ```
   Name:          Radarr
   Sync Level:    Full Sync
   Tags:          (leave empty or add movies tag)

   Prowlarr Server:
     - URL: http://prowlarr.media.svc.cluster.local:9696

   Radarr Server:
     - URL: http://radarr.media.svc.cluster.local:7878
     - API Key: bfb36ca57d2b46fbb6bd3a4d7b0f979f
   ```
   - Click "Test" → Should succeed
   - Click "Save"

2. **Settings → Apps → Add Application → Sonarr**
   ```
   Name:          Sonarr
   Sync Level:    Full Sync
   Tags:          (leave empty or add tv tag)

   Prowlarr Server:
     - URL: http://prowlarr.media.svc.cluster.local:9696

   Sonarr Server:
     - URL: http://sonarr.media.svc.cluster.local:8989
     - API Key: 80bf1996b11e47cd8a60d5d148fed38d
   ```
   - Click "Test" → Should succeed
   - Click "Save"

3. **Verify Applications Added**
   ```bash
   curl -H "X-Api-Key: a3d5b85bde3840e593a77d3956e20dba" \
     http://10.69.1.155:9696/api/v1/applications | python3 -c \
     "import sys,json; data=json.load(sys.stdin); print(f'Total: {len(data)}'); \
     [print(f'  - {x[\"name\"]} (sync: {x[\"syncLevel\"]})') for x in data]"
   ```

4. **Trigger Sync**
   - Settings → Apps → Click "Sync App Indexers" button
   - Or wait for automatic sync (every 30 minutes)

---

### **Step 3: Configure Radarr**

**URL:** http://10.69.1.156:7878

#### **A. Add Root Folder**

1. **Settings → Media Management → Root Folders**
   - Add Root Folder: `/data/movies`
   - Save

#### **B. Add Download Client**

1. **Settings → Download Clients → Add → qBittorrent**
   ```
   Name:       qBittorrent
   Enable:     ✅

   Host:       qbittorrent.media.svc.cluster.local
   Port:       8080
   Username:   admin
   Password:   [YOUR_QBITTORRENT_PASSWORD]

   Category:   radarr
   Priority:   Normal

   Remove Completed:     ❌ (let Radarr manage)
   Remove Failed:        ✅
   ```
   - Click "Test" → Should succeed
   - Click "Save"

#### **C. Verify Indexers Synced from Prowlarr**

1. **Settings → Indexers**
   - Should automatically show indexers from Prowlarr
   - If empty, go back to Prowlarr and trigger sync

2. **Verify via API:**
   ```bash
   curl -H "X-Api-Key: bfb36ca57d2b46fbb6bd3a4d7b0f979f" \
     http://10.69.1.156:7878/api/v3/indexer | python3 -c \
     "import sys,json; data=json.load(sys.stdin); print(f'Total: {len(data)}'); \
     [print(f'  - {x[\"name\"]}') for x in data[:10]]"
   ```

#### **D. Quality Profiles (Optional)**

1. **Settings → Profiles**
   - Default profiles are usually fine
   - Customize if you want specific quality preferences

---

### **Step 4: Configure Sonarr**

**URL:** http://10.69.1.157:8989

#### **A. Add Root Folder**

1. **Settings → Media Management → Root Folders**
   - Add Root Folder: `/data/tv`
   - Save

#### **B. Add Download Client**

1. **Settings → Download Clients → Add → qBittorrent**
   ```
   Name:       qBittorrent
   Enable:     ✅

   Host:       qbittorrent.media.svc.cluster.local
   Port:       8080
   Username:   admin
   Password:   [YOUR_QBITTORRENT_PASSWORD]

   Category:   sonarr
   Priority:   Normal

   Remove Completed:     ❌ (let Sonarr manage)
   Remove Failed:        ✅
   ```
   - Click "Test" → Should succeed
   - Click "Save"

#### **C. Verify Indexers**

1. **Settings → Indexers**
   - Should automatically show indexers from Prowlarr

2. **Verify via API:**
   ```bash
   curl -H "X-Api-Key: 80bf1996b11e47cd8a60d5d148fed38d" \
     http://10.69.1.157:8989/api/v3/indexer | python3 -c \
     "import sys,json; data=json.load(sys.stdin); print(f'Total: {len(data)}'); \
     [print(f'  - {x[\"name\"]}') for x in data[:10]]"
   ```

---

### **Step 5: Configure Lidarr (Optional)**

**URL:** http://10.69.1.159:8686

Follow same steps as Radarr/Sonarr:
1. Add root folder: `/data/music`
2. Add qBittorrent download client
3. Verify indexers synced from Prowlarr
4. Add Lidarr to Prowlarr applications

---

### **Step 6: Configure Plex**

**URL:** http://10.69.1.165:32400

1. **Initial Setup**
   - Sign in with Plex account
   - Server should already be claimed

2. **Add Libraries**
   - **Movies:** `/data/movies`
   - **TV Shows:** `/data/tv`
   - **Music:** `/data/music` (if using Lidarr)

3. **Settings → Network**
   - Custom server access URLs: `http://10.69.1.165:32400`
   - Secure connections: Preferred

---

### **Step 7: Configure Overseerr (Optional)**

**URL:** http://10.69.1.160:5055

1. **Initial Setup**
   - Sign in with Plex account

2. **Settings → Plex**
   - Hostname: `plex.media.svc.cluster.local`
   - Port: `32400`
   - Use SSL: ❌
   - Test → Save

3. **Settings → Services → Radarr**
   - Server name: `Radarr`
   - Hostname: `radarr.media.svc.cluster.local`
   - Port: `7878`
   - API Key: `bfb36ca57d2b46fbb6bd3a4d7b0f979f`
   - Default Quality Profile: (select one)
   - Default Root Folder: `/data/movies`
   - Test → Save

4. **Settings → Services → Sonarr**
   - Server name: `Sonarr`
   - Hostname: `sonarr.media.svc.cluster.local`
   - Port: `8989`
   - API Key: `80bf1996b11e47cd8a60d5d148fed38d`
   - Default Quality Profile: (select one)
   - Default Root Folder: `/data/tv`
   - Test → Save

---

## ✅ **Verification Checklist**

### **1. Check Prowlarr**
```bash
# Indexers
curl -H "X-Api-Key: a3d5b85bde3840e593a77d3956e20dba" \
  http://10.69.1.155:9696/api/v1/indexer | \
  python3 -c "import sys,json; print(f'Indexers: {len(json.load(sys.stdin))}')"

# Applications
curl -H "X-Api-Key: a3d5b85bde3840e593a77d3956e20dba" \
  http://10.69.1.155:9696/api/v1/applications | \
  python3 -c "import sys,json; print(f'Apps: {len(json.load(sys.stdin))}')"
```
**Expected:** Indexers: 5+, Apps: 2+

### **2. Check Radarr**
```bash
# Indexers
curl -H "X-Api-Key: bfb36ca57d2b46fbb6bd3a4d7b0f979f" \
  http://10.69.1.156:7878/api/v3/indexer | \
  python3 -c "import sys,json; print(f'Indexers: {len(json.load(sys.stdin))}')"

# Download Clients
curl -H "X-Api-Key: bfb36ca57d2b46fbb6bd3a4d7b0f979f" \
  http://10.69.1.156:7878/api/v3/downloadclient | \
  python3 -c "import sys,json; print(f'Download Clients: {len(json.load(sys.stdin))}')"
```
**Expected:** Indexers: 5+, Download Clients: 1+

### **3. Check Sonarr**
```bash
# Indexers
curl -H "X-Api-Key: 80bf1996b11e47cd8a60d5d148fed38d" \
  http://10.69.1.157:8989/api/v3/indexer | \
  python3 -c "import sys,json; print(f'Indexers: {len(json.load(sys.stdin))}')"

# Download Clients
curl -H "X-Api-Key: 80bf1996b11e47cd8a60d5d148fed38d" \
  http://10.69.1.157:8989/api/v3/downloadclient | \
  python3 -c "import sys,json; print(f'Download Clients: {len(json.load(sys.stdin))}')"
```
**Expected:** Indexers: 5+, Download Clients: 1+

### **4. Test Search**
1. Go to Radarr → Movies → Add New Movie
2. Search for a movie (e.g., "The Matrix")
3. Click "Add" → Select quality profile → Add Movie
4. Click "Search" icon
5. Should show search results from multiple indexers

---

## 🚨 **Troubleshooting**

### **Prowlarr Indexers Not Syncing to Radarr/Sonarr**

**Symptoms:**
- Radarr/Sonarr show 0 indexers
- Search returns no results

**Solutions:**

1. **Check Prowlarr Applications**
   ```bash
   curl -H "X-Api-Key: a3d5b85bde3840e593a77d3956e20dba" \
     http://10.69.1.155:9696/api/v1/applications
   ```
   - Should show Radarr and Sonarr
   - If empty, add them in Prowlarr Settings → Apps

2. **Trigger Manual Sync**
   - Prowlarr → Settings → Apps
   - Click "Sync App Indexers" button

3. **Check Logs**
   ```bash
   kubectl logs -n media deployment/prowlarr --tail=50 | grep -i sync
   ```

4. **Verify API Keys Match**
   - Prowlarr should use internal DNS: `radarr.media.svc.cluster.local:7878`
   - API keys must match exactly

### **Download Client Connection Failed**

**Symptoms:**
- Test button fails in Radarr/Sonarr
- "Unable to connect to qBittorrent"

**Solutions:**

1. **Verify qBittorrent is running**
   ```bash
   curl http://10.69.1.158:8080
   ```

2. **Check qBittorrent authentication**
   - Make sure you set up IP whitelist in qBittorrent settings
   - Or disable authentication for internal network

3. **Use Internal DNS**
   - Use: `qbittorrent.media.svc.cluster.local`
   - Don't use: `10.69.1.158` (external IP)

### **Search Returns No Results**

**Possible Causes:**

1. **No indexers configured in Prowlarr**
   - Add indexers in Prowlarr first

2. **Indexers not synced**
   - Trigger manual sync in Prowlarr

3. **Download client not configured**
   - Radarr/Sonarr won't search without download client

4. **API connectivity issues**
   - Check logs for connection errors

---

## 📚 **Reference**

### **Default Ports**
```
Prowlarr:    9696
Radarr:      7878
Sonarr:      8989
Lidarr:      8686
qBittorrent: 8080
SABnzbd:     8080
Overseerr:   5055
Plex:        32400
```

### **Configuration Paths (Inside Containers)**
```
Prowlarr:    /config/config.xml
Radarr:      /config/config.xml
Sonarr:      /config/config.xml
qBittorrent: /config/qBittorrent/qBittorrent.conf
```

### **Media Paths**
```
Movies:      /data/movies
TV Shows:    /data/tv
Music:       /data/music
Downloads:   /downloads/complete/
             /downloads/incomplete/
```

---

## 📝 **Configuration Backup**

After completing configuration, back up the configs:

```bash
# Backup all media configs
kubectl exec -n media deployment/prowlarr -- tar czf /tmp/prowlarr-config.tar.gz -C /config .
kubectl cp media/$(kubectl get pod -n media -l app=prowlarr -o name | cut -d/ -f2):/tmp/prowlarr-config.tar.gz ./prowlarr-config-backup.tar.gz

# Repeat for Radarr, Sonarr, etc.
```

---

## ✅ **Configuration Complete**

Once all steps are complete, you should have:
- ✅ Prowlarr with 5+ indexers configured
- ✅ Prowlarr connected to Radarr and Sonarr
- ✅ Radarr with indexers and download client
- ✅ Sonarr with indexers and download client
- ✅ Plex with media libraries configured
- ✅ Ability to search and download content

**Next Steps:**
1. Add movies/TV shows to Radarr/Sonarr
2. Configure quality profiles to your preference
3. Set up notifications (Discord, Telegram, etc.)
4. Configure Overseerr for user requests
