# Current Media Server Configuration

**Date:** 2025-10-03
**Purpose:** Document existing media server setup for migration to Kubernetes cluster

---

## Overview

This document captures the current media server configuration including all services, API keys, indexer configurations, and network settings. This information will be used during Phase 4 deployment to Kubernetes.

---

## Current Services

### Plex Media Server
- **Current Host:** (Docker/Bare Metal/VM?)
- **Version:**
- **Port:** 32400
- **Media Library Paths:**
  - Movies:
  - TV Shows:
  - Music:
  - Photos:
- **Plex Claim Token:** (for initial setup)
- **Plex Token:** (for API access)

### Radarr (Movie Management)
- **Current Host:**
- **Version:**
- **Port:** 7878
- **API Key:**
- **Root Folder:**
- **Quality Profiles:**

### Sonarr (TV Management)
- **Current Host:**
- **Version:**
- **Port:** 8989
- **API Key:**
- **Root Folder:**
- **Quality Profiles:**

### Prowlarr (Indexer Manager)
- **Current Host:**
- **Version:**
- **Port:** 9696
- **API Key:**
- **Configured Indexers:**
  - Indexer 1: (name, URL, API key if applicable)
  - Indexer 2:
  - Indexer 3:

### Lidarr (Music Management) - Optional
- **Current Host:**
- **Version:**
- **Port:** 8686
- **API Key:**
- **Root Folder:**

### Readarr (Book Management) - Optional
- **Current Host:**
- **Version:**
- **Port:** 8787
- **API Key:**
- **Root Folder:**

### Download Client (qBittorrent/Transmission/SABnzbd)
- **Type:**
- **Current Host:**
- **Port:**
- **Username:**
- **Password:**
- **Download Path:**

---

## Network Configuration

### Current IPs
- Plex:
- Radarr:
- Sonarr:
- Prowlarr:
- Lidarr:
- Readarr:
- Download Client:

### Kubernetes Target Strategy

**Option A: Single LoadBalancer IP with Ingress**
- All services behind one LoadBalancer IP
- Ingress routes based on hostname/path:
  - plex.k8s.home ’ Plex
  - radarr.k8s.home ’ Radarr
  - sonarr.k8s.home ’ Sonarr
  - prowlarr.k8s.home ’ Prowlarr

**Option B: Multiple LoadBalancer IPs (MetalLB pool)**
- Each service gets own IP from 10.69.1.150-160 pool
- UniFi DHCP won't interfere (static MetalLB assignment)
- Better for services that need specific ports

**Recommended:** Option A with Ingress for web UIs, Option B for Plex (port 32400)

---

## API Integration Matrix

| Service | Connects To | Purpose | API Key Location |
|---------|-------------|---------|------------------|
| Radarr | Prowlarr | Indexer sync | Prowlarr API key in Radarr |
| Radarr | Download Client | Send downloads | Download client creds in Radarr |
| Sonarr | Prowlarr | Indexer sync | Prowlarr API key in Sonarr |
| Sonarr | Download Client | Send downloads | Download client creds in Sonarr |
| Prowlarr | Radarr | Push indexers | Radarr API key in Prowlarr |
| Prowlarr | Sonarr | Push indexers | Sonarr API key in Prowlarr |
| Lidarr | Prowlarr | Indexer sync | Prowlarr API key in Lidarr |
| Readarr | Prowlarr | Indexer sync | Prowlarr API key in Readarr |

---

## Migration Notes

### Secrets to Create in Kubernetes
```yaml
# Example structure (DO NOT commit actual values to Git)
apiVersion: v1
kind: Secret
metadata:
  name: arr-suite-secrets
  namespace: media
type: Opaque
stringData:
  plex-token: "xxxxx"
  radarr-api-key: "xxxxx"
  sonarr-api-key: "xxxxx"
  prowlarr-api-key: "xxxxx"
  lidarr-api-key: "xxxxx"
  readarr-api-key: "xxxxx"
  download-client-username: "xxxxx"
  download-client-password: "xxxxx"
```

### Configuration Files to Backup
- [ ] Plex: `/config/Preferences.xml`
- [ ] Plex: `/config/Library/Application Support/Plex Media Server/`
- [ ] Radarr: `/config/config.xml`
- [ ] Sonarr: `/config/config.xml`
- [ ] Prowlarr: `/config/config.xml`
- [ ] Download client config

### Data Migration Strategy
1. Backup all config files from current system
2. Deploy services to Kubernetes with empty configs
3. Stop current services
4. Copy config files to Kubernetes PVCs
5. Restart Kubernetes pods
6. Verify connectivity and functionality

---

## UniFi Network Considerations

### DHCP vs MetalLB
- **UniFi DHCP Range:** (e.g., 10.69.1.50-149)
- **MetalLB IP Pool:** 10.69.1.150-160 (static, outside DHCP range)
- **No Conflict:** MetalLB assigns IPs statically from reserved pool

### Recommended IP Assignment
| Service | Access Method | IP Assignment |
|---------|---------------|---------------|
| Plex | Direct port access | MetalLB LoadBalancer (e.g., 10.69.1.150) |
| All *arr services | Ingress (web UI) | Single MetalLB IP (e.g., 10.69.1.151) ’ Ingress Controller |
| Download Client | Ingress (web UI) | Same as *arr services |

### DNS / Local Access
- Configure local DNS entries in UniFi (optional):
  - media.home ’ 10.69.1.151 (Ingress IP)
  - plex.home ’ 10.69.1.150
- Or use IP addresses directly

---

## TODO: Fill in Actual Values

**Instructions:**
1. Fill in the blanks above with your actual configuration
2. **NEVER commit API keys or tokens to Git** - use placeholder text only
3. Store actual secrets in password manager or encrypted vault
4. Use this document as reference during Phase 4 deployment
5. After migration, verify all API integrations still work

---

**Next Steps:**
- Complete this document with current configuration details
- See [TASKS.md](TASKS.md) for Phase 4 deployment tasks
- See [CLAUDE.md](CLAUDE.md) for deployment commands and procedures
