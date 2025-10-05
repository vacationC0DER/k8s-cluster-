# Media Stack Application

**Purpose:** Complete media automation stack with Plex and *arr services
**Namespace:** media
**Architecture:** Option B - Multiple LoadBalancer IPs
**Status:** ✅ Production (Deployed Oct 4-5, 2025)

---

## Directory Structure

```
apps/media/
├── README.md                  # This file
└── base/                      # Base Kustomize manifests
    ├── namespace.yaml         # Namespace with privileged PodSecurity
    ├── kustomization.yaml     # Kustomize configuration
    ├── media-storage-pvcs.yaml    # PVCs for media and configs
    ├── prowlarr.yaml          # Indexer manager
    ├── qbittorrent.yaml       # Torrent download client
    ├── sabnzbd.yaml           # Usenet download client
    ├── radarr.yaml            # Movie management
    ├── sonarr.yaml            # TV show management
    ├── lidarr.yaml            # Music management
    ├── plex.yaml              # Media server
    └── overseerr.yaml         # Request management
```

---

## Services

| Service | LoadBalancer IP | Port | Purpose |
|---------|-----------------|------|---------|
| Plex | 10.69.1.154 | 32400 | Media streaming server |
| Prowlarr | 10.69.1.155 | 9696 | Indexer manager (Usenet) |
| Radarr | 10.69.1.156 | 7878 | Movie management |
| Sonarr | 10.69.1.157 | 8989 | TV show management |
| qBittorrent | 10.69.1.158 | 8080 | Torrent download client |
| Lidarr | 10.69.1.159 | 8686 | Music management |
| Overseerr | 10.69.1.160 | 5055 | Media request management |
| SABnzbd | 10.69.1.161 | 8080 | Usenet download client |

**Total:** 8 services using 8 MetalLB LoadBalancer IPs (.154-.161)

---

## Deployment

### Using Kustomize

**Build and preview:**
```bash
kubectl kustomize apps/media/base/
```

**Apply to cluster:**
```bash
kubectl apply -k apps/media/base/
```

**Delete from cluster:**
```bash
kubectl delete -k apps/media/base/
```

### Deployment Order

The kustomization.yaml defines resources in recommended deployment order:

1. **Namespace** - Create media namespace with privileged PodSecurity
2. **PVCs** - Provision persistent storage (media-storage 10Ti, media-configs 50Gi)
3. **Prowlarr** - Deploy first (generates API key, pushes indexers to *arr services)
4. **Download Clients** - qBittorrent + SABnzbd
5. ***arr Services** - Radarr, Sonarr, Lidarr (can deploy in parallel)
6. **Plex** - Deploy last (depends on media files)
7. **Overseerr** - Optional request management

---

## Configuration

### Common Environment Variables

All services use LinuxServer.io images with consistent configuration:

```yaml
env:
  - name: PUID
    value: "1000"
  - name: PGID
    value: "1000"
  - name: TZ
    value: "America/Los_Angeles"
```

### Storage

**NFS Server:** 10.69.1.163
**StorageClass:** nfs-client
**Access Mode:** ReadWriteMany (RWX)

**Volume Mounts:**
- All services mount at `/data` (single mount point)
- Subdirectories: `/data/media/`, `/data/downloads/`, `/data/configs/`

---

## Service Communication

### Internal (Service-to-Service)

Services communicate via Kubernetes DNS:

```
http://prowlarr.media.svc.cluster.local:9696
http://radarr.media.svc.cluster.local:7878
http://sonarr.media.svc.cluster.local:8989
http://lidarr.media.svc.cluster.local:8686
http://qbittorrent.media.svc.cluster.local:8080
http://sabnzbd.media.svc.cluster.local:8080
http://overseerr.media.svc.cluster.local:5055
http://plex.media.svc.cluster.local:32400
```

### External (User Access)

Direct IP access via MetalLB LoadBalancer:

```
http://10.69.1.154:32400/web    (Plex)
http://10.69.1.155:9696         (Prowlarr)
http://10.69.1.156:7878         (Radarr)
http://10.69.1.157:8989         (Sonarr)
http://10.69.1.158:8080         (qBittorrent)
http://10.69.1.159:8686         (Lidarr)
http://10.69.1.160:5055         (Overseerr)
http://10.69.1.161:8080         (SABnzbd)
```

---

## Critical Configuration

### Remote Path Mappings

**REQUIRED** for download imports to work:

```bash
# Add to Radarr, Sonarr, Lidarr after deployment
POST /api/v3/remotepathmapping
{
  "host": "qbittorrent.media.svc.cluster.local",
  "remotePath": "/downloads/",
  "localPath": "/data/downloads/"
}
```

**Why?** qBittorrent sees `/downloads/`, *arr services see `/data/downloads/` (same NFS location, different mount points).

### Prowlarr Integration

1. Deploy Prowlarr first
2. Add indexers to Prowlarr
3. Configure Prowlarr → Apps:
   - Add Radarr (URL: http://radarr.media.svc.cluster.local:7878, API key from Radarr)
   - Add Sonarr (URL: http://sonarr.media.svc.cluster.local:8989, API key from Sonarr)
   - Add Lidarr (URL: http://lidarr.media.svc.cluster.local:8686, API key from Lidarr)
4. Trigger sync - indexers automatically pushed to all *arr services

---

## Resource Limits

### Plex (Resource-Intensive)

```yaml
resources:
  requests:
    memory: "4Gi"
    cpu: "2000m"
  limits:
    memory: "8Gi"
    cpu: "4000m"
```

**Transcoding:** Uses local NVMe SSD via emptyDir (20Gi), NOT NFS

### qBittorrent

```yaml
resources:
  requests:
    memory: "1Gi"
    cpu: "500m"
  limits:
    memory: "2Gi"
    cpu: "2000m"
```

### Other Services

Default limits acceptable (~100-200MB RAM, minimal CPU)

---

## Troubleshooting

### Check All Pods

```bash
kubectl get pods -n media
kubectl get svc -n media
kubectl get pvc -n media
```

### Check Service Connectivity

```bash
# Test internal DNS
kubectl run -it --rm debug --image=busybox --restart=Never -n media -- \
  nslookup prowlarr.media.svc.cluster.local

# Test HTTP connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n media -- \
  curl http://prowlarr.media.svc.cluster.local:9696
```

### Common Issues

**Pod stuck ContainerCreating:**
- Check PVC status: `kubectl describe pvc -n media`
- Check events: `kubectl get events -n media --sort-by='.lastTimestamp'`

**LoadBalancer IP pending:**
- Check MetalLB: `kubectl get pods -n metallb-system`
- Check IP pool: `kubectl get ipaddresspool -n metallb-system`

**Import failures:**
- Add remote path mappings (see Critical Configuration above)
- Verify download client connectivity from *arr service logs

---

## Maintenance

### Update Single Service

```bash
# Update image tag in YAML
kubectl apply -k apps/media/base/

# Or restart pod
kubectl rollout restart deployment/plex -n media
```

### Backup Configuration

```bash
# Backup all manifests
kubectl get all,pvc,secrets -n media -o yaml > media-backup-$(date +%Y%m%d).yaml

# Backup PVC data (via NFS)
# PVCs backed by NFS at 10.69.1.163:/mnt/media/
```

### Add New Service

1. Add YAML manifest to `apps/media/base/`
2. Add to `kustomization.yaml` resources list
3. Assign LoadBalancer IP from MetalLB pool (.162-.165 available)
4. Apply: `kubectl apply -k apps/media/base/`

---

## Documentation References

- **Architecture Decision:** See [MEDIA_STACK_ARCHITECTURE_PLAN.md](../../docs/MEDIA_STACK_ARCHITECTURE_PLAN.md)
- **Configuration Review:** See [MEDIA_STACK_CONFIG_REVIEW.md](../../MEDIA_STACK_CONFIG_REVIEW.md)
- **Optimization Guide:** See [MEDIA_STACK_OPTIMIZATION.md](../../MEDIA_STACK_OPTIMIZATION.md)
- **CHANGELOG:** See [CHANGELOG.md](../../CHANGELOG.md) entries [2025-10-04] and [2025-10-05]
- **Tasks:** See [TASKS.md](../../TASKS.md) Phase 4 section

---

## Status

**Last Updated:** October 5, 2025
**Deployment Status:** ✅ Production
**Services:** 8/8 operational
**End-to-End Workflow:** ✅ Verified (Overseerr → Radarr → qBittorrent → Import → Plex)
**Resource Usage:** ~1.5GB memory cluster-wide (idle)
**MetalLB Pool:** 8/16 IPs used (50% utilization)

**Next Steps:** Phase 5 - GitOps with ArgoCD + Sealed Secrets
