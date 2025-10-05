# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Production-grade Talos Kubernetes bare-metal cluster deployment on 6x Beelink SER5 mini PCs. The cluster provides high-availability infrastructure for home services, with a complete media automation stack as the primary production workload.

**Command Post:** This repository (`k8_cluster/`) serves as the centralized management and documentation hub for the entire cluster. All configurations, procedures, scripts, and cluster state tracking are maintained here.

**Current Media Server:** Existing Plex media stack running on Proxmox server at 10.69.1.180 (see [current_mediaserver.md](current_mediaserver.md)). This will be migrated to the Kubernetes cluster in Phase 4.

**Media Stack Components:**
- **Plex Media Server** - Media streaming and library management
- **Radarr** - Automated movie management
- **Sonarr** - Automated TV show management
- **Prowlarr** - Centralized indexer management
- **Lidarr** - Music collection management (optional)
- **Readarr** - Book/audiobook management (optional)
- **Download Client** - qBittorrent/Transmission/SABnzbd

**Network:** 10.69.1.0/24
**Management Workstation:** MacBook Pro M2 (10.69.1.167)
**Control Plane Nodes:** 10.69.1.101-103
**Worker Nodes:** 10.69.1.104-106
**NAS Storage:** 10.69.1.163 (NFS)
**Proxmox Station:** 10.69.1.180
**MetalLB Pool:** 10.69.1.150-160

## Commands

### Essential Tools Installation

**Install on MacBook Pro M2 (ARM64):**
```bash
# Install talosctl (required)
brew install siderolabs/tap/talosctl

# Install kubectl (required)
brew install kubectl

# Install helm (required for Phase 2+)
brew install helm

# Install k9s (optional but recommended)
brew install k9s
```

### Environment Setup

```bash
# Set Talos configuration (add to ~/.zshrc)
export TALOSCONFIG=~/talos-cluster/talosconfig

# Configure endpoints (all control plane nodes)
talosctl config endpoint 10.69.1.101 10.69.1.102 10.69.1.103

# Set default node
talosctl config node 10.69.1.101
```

### Cluster Management

**Talos Operations:**
```bash
# Check cluster health
talosctl health --wait-timeout 5m

# View node services
talosctl --nodes <node-ip> services

# View logs for specific service
talosctl --nodes <node-ip> logs <service-name>

# Follow logs in real-time
talosctl --nodes <node-ip> logs --follow <service-name>

# Apply configuration changes
talosctl apply-config --nodes <node-ip> --file <config.yaml>

# Upgrade Talos OS (rolling, one node at a time)
talosctl upgrade --nodes <node-ip> --image ghcr.io/siderolabs/installer:v1.11.2

# Upgrade Kubernetes (control plane first, then workers)
talosctl upgrade-k8s --nodes 10.69.1.101-103 --to <version>
talosctl upgrade-k8s --nodes 10.69.1.104-106 --to <version>

# Get etcd members
talosctl --nodes 10.69.1.101 get members

# Interactive dashboard
talosctl dashboard

# Reboot node
talosctl --nodes <node-ip> reboot

# Shutdown node
talosctl --nodes <node-ip> shutdown

# Get machine config
talosctl --nodes <node-ip> get machineconfig

# View kernel messages
talosctl --nodes <node-ip> dmesg

# etcd snapshot backup
talosctl --nodes 10.69.1.101 etcd snapshot /tmp/etcd-backup.db
```

**Kubernetes Operations:**
```bash
# Node status
kubectl get nodes

# View all pods across namespaces
kubectl get pods -A

# Check events for issues
kubectl get events -A --sort-by='.lastTimestamp'

# Get problematic pods only
kubectl get pods -A | grep -v Running

# Drain node for maintenance
kubectl drain <node-name> --ignore-daemonsets --delete-emptydir-data

# Restore node after maintenance
kubectl uncordon <node-name>

# View resource usage (requires metrics-server)
kubectl top nodes
kubectl top pods -A

# Label worker nodes
kubectl label node <node-name> node-role.kubernetes.io/worker=worker

# Get kubeconfig from Talos
talosctl kubeconfig .

# View cluster info
kubectl cluster-info
```

### Initial Cluster Setup

**Bootstrap Sequence (Phase 1):**
```bash
# 1. Generate cluster configuration
mkdir -p ~/talos-cluster && cd ~/talos-cluster
talosctl gen config my-cluster https://10.69.1.101:6443

# 2. Apply configs to control plane nodes
talosctl apply-config --insecure --nodes 10.69.1.101 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.1.102 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.1.103 --file controlplane.yaml

# 3. Apply configs to worker nodes
talosctl apply-config --insecure --nodes 10.69.1.104 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.1.105 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.1.106 --file worker.yaml

# 4. Bootstrap etcd (ONLY on first control plane)
talosctl bootstrap --nodes 10.69.1.101

# 5. Wait for cluster health
talosctl health --wait-timeout 10m

# 6. Get kubeconfig
talosctl kubeconfig .

# 7. Verify cluster
kubectl get nodes
```

### Development Workflow

**Configuration Management:**
```bash
# Talos configs are in ~/talos-cluster/
# - controlplane.yaml: Control plane configuration
# - worker.yaml: Worker node configuration
# - talosconfig: Client configuration for talosctl

# Backup configs to Git
cd ~/talos-cluster
git init
git add .
git commit -m "Initial cluster configuration"
```

**Testing & Validation:**
```bash
# Deploy test pod
kubectl run nginx-test --image=nginx

# Test service connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- wget -O- <service-name>

# Check PVC provisioning
kubectl get pvc

# Test LoadBalancer service (Phase 2+)
kubectl expose deployment nginx-test --type=LoadBalancer --port=80

# Clean up test resources
kubectl delete pod nginx-test
kubectl delete svc nginx-test
```

### Daily Health Checks

```bash
# Morning cluster check
talosctl health
kubectl get nodes
kubectl get pods -A | grep -v Running
kubectl get events -A --sort-by='.lastTimestamp' | tail -20
```

## Architecture

### Cluster Topology

**Control Plane (HA with etcd quorum):**
- 3-node etcd cluster (quorum requires 2/3 healthy)
- kube-apiserver, kube-scheduler, kube-controller-manager replicated across all 3
- Leader election for scheduler and controller-manager
- Primary endpoint: https://10.69.1.101:6443

**Worker Nodes:**
- 3 worker nodes for workload distribution
- Each with 32GB RAM, 16-core Ryzen 7 5825U
- containerd as container runtime (no Docker)
- Flannel CNI for pod networking

**Storage Architecture:**
- NFS server on NAS (10.69.1.163)
- NFS CSI driver for dynamic PVC provisioning
- Storage class: nfs-client
- Media library structure: /mnt/media/{movies,tv,music,photos}

**Network Architecture:**
- Pod network: 10.244.0.0/16 (Flannel VXLAN)
- Service network: 10.96.0.0/12
- MetalLB for LoadBalancer services (L2 mode)
- Ingress controller (Traefik/NGINX) for HTTP/HTTPS routing

### Software Stack

**Operating System:**
- Talos Linux v1.11.2 (immutable, API-only, no SSH)
- All management via talosctl and gRPC API
- Automatic security updates

**Kubernetes:**
- Version: v1.34.1
- Components: etcd v3.6.4, CoreDNS v1.12.3, Flannel v0.27.2

**Cluster Add-ons (Phase 2-4):**
- MetalLB v0.14+ (Layer 2 load balancing)
- Traefik/NGINX Ingress
- NFS Subdir External Provisioner
- Prometheus + Grafana (monitoring)
- cert-manager (TLS certificates)

## Hardware Specifications

**Beelink SER5 Mini PC (6 units):**
- CPU: AMD Ryzen 7 5825U (8C/16T, 2.0-4.5GHz)
- RAM: 32GB DDR4 3200MHz
- Storage: 500GB NVMe SSD
- Network: 2.5Gb Ethernet
- Graphics: AMD Radeon (8 cores) for future transcoding

**Total Cluster Resources:**
- 48 cores / 96 threads
- 192GB RAM
- 3TB NVMe storage
- 15Gbps network capacity

**Power Consumption:** 90-210W cluster-wide (~$15-25/month)

## Important Context

### Talos Linux Specifics

**Immutability & API-Driven:**
- No SSH access - all operations via talosctl API
- Configuration changes require apply-config
- Disk installation WIPES all existing data (Windows was deleted during setup)
- Nodes run from internal NVMe after initial USB boot

**Configuration Files:**
- Machine configs are declarative YAML
- Changes applied via talosctl apply-config
- Version control all configs in Git for disaster recovery

### High Availability Considerations

**etcd Quorum:**
- Requires 2/3 control plane nodes healthy for cluster operations
- Can tolerate 1 control plane node failure
- Never shut down 2+ control plane nodes simultaneously

**Workload Scheduling:**
- Use Pod Disruption Budgets for critical services
- Configure resource requests/limits appropriately
- Use node affinity/anti-affinity for spread

### Phase-Based Implementation

**Current Status:** Phase 1 (Foundation) - ✅ COMPLETE (All 6 nodes operational)
**Last Updated:** October 3, 2025

#### Phase 1: Foundation (Weeks 1-2)
**Objectives:** Deploy 6-node cluster, verify health and stability
**Key Tasks:**
- Hardware setup and network configuration
- Create Talos boot media and install on all nodes
- Bootstrap cluster and verify health
- Failover testing and performance baseline
**Success Criteria:**
- All nodes healthy for 48+ hours
- Survive single control plane/worker node failure
- kubectl access from workstation

#### Phase 2: Core Infrastructure (Weeks 3-4)
**Objectives:** Deploy networking and storage infrastructure
**Key Tasks:**
- Install MetalLB (IP pool: 10.69.1.150-160)
- Deploy Ingress controller (Traefik/NGINX)
- Configure NFS CSI driver for NAS (10.69.1.200)
- Install cert-manager for SSL/TLS
**Success Criteria:**
- LoadBalancer services accessible externally
- HTTPS ingress functional with valid certificates
- PVC creation and mounting successful

#### Phase 3: Observability (Weeks 5-6)
**Objectives:** Deploy monitoring and logging stack
**Key Tasks:**
- Deploy Prometheus + Grafana via Helm
- Configure ServiceMonitors for cluster components
- Import community dashboards (Kubernetes cluster, node metrics)
- Configure AlertManager with notification channels
- Optional: Deploy Loki for log aggregation
**Success Criteria:**
- View CPU/memory/network metrics for all nodes
- Receive alerts when test node shutdown
- Dashboards accessible via Ingress

#### Phase 4: Production Workloads (Weeks 7-8)
**Objectives:** Deploy complete media automation stack (Plex + *arr suite)
**Key Tasks:**
- Create namespace: media
- Create Kubernetes secrets for API keys and credentials (see [current_mediaserver.md](current_mediaserver.md))
- Deploy Prowlarr first (indexer manager)
- Deploy Radarr, Sonarr, Lidarr, Readarr (configure API connections)
- Deploy download client (qBittorrent/Transmission/SABnzbd)
- Deploy Plex Media Server last
- Configure LoadBalancer services and/or Ingress
- Migrate existing configurations and data
- Verify API integrations between services
- Test failover scenarios
**Success Criteria:**
- All services accessible via Ingress or LoadBalancer
- API integrations working (Prowlarr ↔ *arr services)
- Multiple Plex users streaming simultaneously
- Pod failures recover within 2 minutes
- Node failures recover within 5 minutes
**See also:** [current_mediaserver.md](current_mediaserver.md) for configuration details

#### Phase 5: Advanced Features (Weeks 9+)
**Objectives:** GitOps workflow and optimization
**Key Tasks:**
- Install ArgoCD or Flux CD
- Implement secrets management (Sealed Secrets)
- Implement Pod Disruption Budgets
- Configure autoscaling (HPA) where applicable
- Implement etcd backup automation
- Document DR runbook and test recovery
**Success Criteria:**
- Automated deployments from Git
- Backup/restore tested successfully

## Media Stack Deployment (Phase 4)

**Reference:** See [current_mediaserver.md](current_mediaserver.md) for your existing configuration, API keys, and migration notes.

### Overview

The media automation stack consists of multiple interconnected services that communicate via REST APIs. Proper deployment order is critical to ensure all services can discover and integrate with each other.

**Service Architecture:**
```
Indexers (External)
       ↓
   Prowlarr (Indexer Manager) ←──┐
       ↓                          │
   ┌───┴────┬────────┬─────────┐  │ API Integration
   ↓        ↓        ↓         ↓  │
Radarr   Sonarr   Lidarr   Readarr │
   └────────┴────────┴─────────┘  │
              ↓                    │
       Download Client             │
              ↓                    │
         Media Files ──────────────┘
              ↓
       Plex Media Server
              ↓
       End Users (Streaming)
```

### Deployment Order

**IMPORTANT: Deploy in this exact order to avoid API connection issues:**

1. **Namespace and Secrets** (first)
2. **Prowlarr** - Indexer manager (must be first to generate API key)
3. **Download Client** - qBittorrent/Transmission/SABnzbd
4. **Radarr, Sonarr, Lidarr, Readarr** - Can deploy in parallel
5. **Plex Media Server** - Deploy last (depends on media files)

### Network Architecture: LoadBalancer vs Ingress

**MetalLB + UniFi DHCP Coexistence:**
- MetalLB IP pool: 10.69.1.150-160 (static assignments, outside UniFi DHCP range)
- UniFi DHCP typically uses: 10.69.1.50-149 or similar
- **No conflict**: MetalLB assigns IPs from reserved pool; UniFi DHCP won't touch those IPs
- Configure UniFi to exclude .150-.160 from DHCP pool if not already done

**Option A: Single Ingress with Multiple Hostnames (Recommended)**
```yaml
# One MetalLB LoadBalancer IP for Ingress Controller
# All services accessed via hostname-based routing
apiVersion: v1
kind: Service
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  type: LoadBalancer
  # MetalLB assigns from pool (e.g., 10.69.1.150)

# Access services via:
# - http://radarr.k8s.home
# - http://sonarr.k8s.home
# - http://prowlarr.k8s.home
# - http://plex.k8s.home (or separate LoadBalancer for port 32400)
```

**Benefits:**
- Uses only 1-2 MetalLB IPs
- Clean hostname-based access
- Easier certificate management (wildcard cert)
- Better for services with web UIs only

**Option B: Multiple LoadBalancer IPs (One per Service)**
```yaml
# Each service gets own LoadBalancer IP
apiVersion: v1
kind: Service
metadata:
  name: radarr
  namespace: media
spec:
  type: LoadBalancer
  # MetalLB assigns: 10.69.1.151

apiVersion: v1
kind: Service
metadata:
  name: sonarr
  namespace: media
spec:
  type: LoadBalancer
  # MetalLB assigns: 10.69.1.152
# ... etc
```

**Benefits:**
- Direct IP access to each service
- No hostname dependencies
- Better for services needing non-HTTP protocols

**Recommended Hybrid Approach:**
- **Plex**: Dedicated LoadBalancer (needs port 32400) → 10.69.1.150
- **All *arr services**: Shared Ingress → 10.69.1.151
- **Download Client**: Include in shared Ingress

### Secrets Management

**CRITICAL: Never commit secrets to Git!**

**Step 1: Prepare Secrets from Current Setup**

Refer to [current_mediaserver.md](current_mediaserver.md) and extract:
- API keys from each *arr service
- Plex claim token and Plex token
- Download client username/password
- Indexer API keys (from Prowlarr)

**Step 2: Create Kubernetes Secret**

```bash
# Create namespace first
kubectl create namespace media

# Create secret with all credentials
kubectl create secret generic media-stack-secrets \
  --namespace=media \
  --from-literal=plex-claim-token='claim-XXXXXXXXXXXX' \
  --from-literal=plex-token='XXXXXXXXXXXX' \
  --from-literal=radarr-api-key='XXXXXXXXXXXX' \
  --from-literal=sonarr-api-key='XXXXXXXXXXXX' \
  --from-literal=prowlarr-api-key='XXXXXXXXXXXX' \
  --from-literal=lidarr-api-key='XXXXXXXXXXXX' \
  --from-literal=readarr-api-key='XXXXXXXXXXXX' \
  --from-literal=download-client-user='admin' \
  --from-literal=download-client-pass='XXXXXXXXXXXX'

# Verify secret created
kubectl get secret media-stack-secrets -n media

# View secret keys (not values)
kubectl describe secret media-stack-secrets -n media
```

**Step 3: Reference Secrets in Deployments**

```yaml
# Example: Radarr deployment using secrets
apiVersion: apps/v1
kind: Deployment
metadata:
  name: radarr
  namespace: media
spec:
  replicas: 1
  template:
    spec:
      containers:
      - name: radarr
        image: linuxserver/radarr:latest
        env:
        - name: RADARR__API_KEY
          valueFrom:
            secretKeyRef:
              name: media-stack-secrets
              key: radarr-api-key
        - name: PROWLARR__API_KEY
          valueFrom:
            secretKeyRef:
              name: media-stack-secrets
              key: prowlarr-api-key
```

### Persistent Storage Configuration

**NFS Storage Structure:**
```
NFS Server: 10.69.1.163
Mount: /mnt/media/

Directory Structure:
/mnt/media/
├── downloads/        # Download client working directory
│   ├── incomplete/
│   └── complete/
├── movies/          # Radarr root folder
├── tv/              # Sonarr root folder
├── music/           # Lidarr root folder
├── books/           # Readarr root folder
├── configs/         # Persistent configs for each service
│   ├── plex/
│   ├── radarr/
│   ├── sonarr/
│   ├── prowlarr/
│   ├── lidarr/
│   ├── readarr/
│   └── qbittorrent/
```

**PVC Examples:**

```yaml
# Single large PVC for all media
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-storage
  namespace: media
spec:
  accessModes:
    - ReadWriteMany  # Multiple pods can read/write simultaneously
  storageClassName: nfs-client
  resources:
    requests:
      storage: 5Ti  # Adjust based on your NAS capacity
---
# Separate PVC for configs (better for backups)
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: media-configs
  namespace: media
spec:
  accessModes:
    - ReadWriteMany
  storageClassName: nfs-client
  resources:
    requests:
      storage: 50Gi
```

### Deployment Commands

**1. Create Namespace and Secrets**
```bash
kubectl create namespace media
# Create secrets as shown in Secrets Management section
```

**2. Deploy Prowlarr First**
```bash
# Using Helm (recommended)
helm repo add k8s-at-home https://k8s-at-home.com/charts/
helm repo update

helm install prowlarr k8s-at-home/prowlarr \
  --namespace media \
  --set env.TZ="America/Los_Angeles" \
  --set persistence.config.enabled=true \
  --set persistence.config.existingClaim=media-configs \
  --set persistence.config.subPath=prowlarr

# Verify deployment
kubectl get pods -n media
kubectl logs -n media -l app.kubernetes.io/name=prowlarr
```

**3. Get Prowlarr LoadBalancer IP or Configure Ingress**
```bash
# If using LoadBalancer
kubectl get svc prowlarr -n media

# Access Prowlarr and complete initial setup
# Generate API key in Prowlarr settings
```

**4. Deploy Download Client**
```bash
# Example: qBittorrent
helm install qbittorrent k8s-at-home/qbittorrent \
  --namespace media \
  --set env.TZ="America/Los_Angeles" \
  --set persistence.config.enabled=true \
  --set persistence.config.existingClaim=media-configs \
  --set persistence.config.subPath=qbittorrent \
  --set persistence.downloads.enabled=true \
  --set persistence.downloads.existingClaim=media-storage \
  --set persistence.downloads.subPath=downloads
```

**5. Deploy *arr Services**
```bash
# Radarr
helm install radarr k8s-at-home/radarr \
  --namespace media \
  --set env.TZ="America/Los_Angeles" \
  --set persistence.config.enabled=true \
  --set persistence.config.existingClaim=media-configs \
  --set persistence.config.subPath=radarr \
  --set persistence.media.enabled=true \
  --set persistence.media.existingClaim=media-storage \
  --set persistence.media.subPath=movies

# Sonarr
helm install sonarr k8s-at-home/sonarr \
  --namespace media \
  --set env.TZ="America/Los_Angeles" \
  --set persistence.config.enabled=true \
  --set persistence.config.existingClaim=media-configs \
  --set persistence.config.subPath=sonarr \
  --set persistence.media.enabled=true \
  --set persistence.media.existingClaim=media-storage \
  --set persistence.media.subPath=tv

# Lidarr (optional)
helm install lidarr k8s-at-home/lidarr \
  --namespace media \
  --set env.TZ="America/Los_Angeles" \
  --set persistence.config.enabled=true \
  --set persistence.config.existingClaim=media-configs \
  --set persistence.config.subPath=lidarr \
  --set persistence.media.enabled=true \
  --set persistence.media.existingClaim=media-storage \
  --set persistence.media.subPath=music
```

**6. Configure API Integrations**
```bash
# Access each *arr service and configure:
# 1. Settings → General → API Key (set from secret or generate)
# 2. Settings → Indexers → Add Prowlarr
#    - URL: http://prowlarr.media.svc.cluster.local:9696
#    - API Key: (Prowlarr API key from secret)
# 3. Settings → Download Clients → Add qBittorrent
#    - URL: http://qbittorrent.media.svc.cluster.local:8080
#    - Username/Password: (from secret)
# 4. Settings → Media Management → Root Folders
#    - Add: /media/movies (Radarr)
#    - Add: /media/tv (Sonarr)
#    - Add: /media/music (Lidarr)
```

**7. Deploy Plex Last**
```bash
# Get Plex claim token from: https://www.plex.tv/claim/
# Valid for 4 minutes - use immediately

helm install plex k8s-at-home/plex \
  --namespace media \
  --set env.TZ="America/Los_Angeles" \
  --set env.PLEX_CLAIM="claim-XXXXXXXXXXXX" \
  --set service.main.type=LoadBalancer \
  --set service.main.loadBalancerIP=10.69.1.150 \
  --set persistence.config.enabled=true \
  --set persistence.config.existingClaim=media-configs \
  --set persistence.config.subPath=plex \
  --set persistence.media.enabled=true \
  --set persistence.media.existingClaim=media-storage
```

**8. Verify All Services**
```bash
# Check all pods running
kubectl get pods -n media

# Check all services
kubectl get svc -n media

# Check LoadBalancer IPs assigned
kubectl get svc -n media | grep LoadBalancer

# Check persistent volumes
kubectl get pvc -n media

# View logs for any issues
kubectl logs -n media <pod-name>
```

### Service Communication

**Internal Cluster DNS:**
- Services communicate using Kubernetes DNS: `<service-name>.<namespace>.svc.cluster.local`
- Examples:
  - `http://prowlarr.media.svc.cluster.local:9696`
  - `http://radarr.media.svc.cluster.local:7878`
  - `http://sonarr.media.svc.cluster.local:8989`
  - `http://qbittorrent.media.svc.cluster.local:8080`

**External Access:**
- Via LoadBalancer IPs (if configured)
- Via Ingress hostnames (if configured)

### Migration from Existing Setup

**1. Backup Current Configurations**
```bash
# On current media server, backup config directories
tar -czf plex-config-backup.tar.gz /path/to/plex/config
tar -czf radarr-config-backup.tar.gz /path/to/radarr/config
tar -czf sonarr-config-backup.tar.gz /path/to/sonarr/config
tar -czf prowlarr-config-backup.tar.gz /path/to/prowlarr/config
# etc...
```

**2. Deploy New Services to Kubernetes**
- Follow deployment commands above
- Let services start with fresh configs initially

**3. Restore Configurations**
```bash
# Method 1: Copy configs to PVC via temporary pod
kubectl run -it --rm copy-configs \
  --image=busybox \
  --namespace=media \
  --overrides='
{
  "spec": {
    "containers": [{
      "name": "copy-configs",
      "image": "busybox",
      "stdin": true,
      "tty": true,
      "volumeMounts": [{
        "name": "configs",
        "mountPath": "/configs"
      }]
    }],
    "volumes": [{
      "name": "configs",
      "persistentVolumeClaim": {
        "claimName": "media-configs"
      }
    }]
  }
}'

# From another terminal, copy files
kubectl cp radarr-config-backup.tar.gz media/copy-configs:/configs/
# Extract inside pod: tar -xzf /configs/radarr-config-backup.tar.gz -C /configs/radarr/

# Method 2: Copy to NFS mount directly (if NAS accessible)
# Mount NFS share on MacBook, copy files directly
```

**4. Update Configuration Files**
- Edit config.xml files to update URLs:
  - Change localhost to Kubernetes service names
  - Example: `http://localhost:9696` → `http://prowlarr.media.svc.cluster.local:9696`

**5. Restart Pods to Load New Configs**
```bash
kubectl rollout restart deployment/radarr -n media
kubectl rollout restart deployment/sonarr -n media
kubectl rollout restart deployment/prowlarr -n media
# etc...
```

### Troubleshooting Media Stack

**Prowlarr Not Pushing Indexers to *arr Services:**
```bash
# Check Prowlarr logs
kubectl logs -n media -l app.kubernetes.io/name=prowlarr --tail=100

# Verify *arr services are accessible from Prowlarr
kubectl exec -n media -it <prowlarr-pod> -- wget -O- http://radarr.media.svc.cluster.local:7878

# Check API keys are correct
kubectl get secret media-stack-secrets -n media -o yaml
```

**Download Client Not Connecting:**
```bash
# Check download client is running
kubectl get pods -n media | grep qbittorrent

# Test connectivity from *arr service
kubectl exec -n media -it <radarr-pod> -- wget -O- http://qbittorrent.media.svc.cluster.local:8080

# Check download client credentials
kubectl logs -n media -l app.kubernetes.io/name=qbittorrent
```

**Plex Not Scanning Library:**
```bash
# Check Plex can access media files
kubectl exec -n media -it <plex-pod> -- ls -la /media/movies
kubectl exec -n media -it <plex-pod> -- ls -la /media/tv

# Check PVC mount
kubectl describe pod <plex-pod> -n media | grep -A5 "Mounts:"

# Verify NFS mount
kubectl get pvc media-storage -n media
kubectl describe pvc media-storage -n media
```

**Services Can't Communicate:**
```bash
# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n media -- \
  nslookup prowlarr.media.svc.cluster.local

# Test HTTP connectivity
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -n media -- \
  curl http://prowlarr.media.svc.cluster.local:9696

# Check NetworkPolicies (if enabled)
kubectl get networkpolicies -n media
```

**LoadBalancer IP Not Assigned:**
```bash
# Check MetalLB is running
kubectl get pods -n metallb-system

# Check MetalLB IP pool configuration
kubectl get ipaddresspool -n metallb-system
kubectl describe ipaddresspool -n metallb-system

# Check service events
kubectl describe svc <service-name> -n media
```

## Security Considerations

- Talos has no SSH daemon (enhanced security model)
- All API calls use mutual TLS authentication
- Implement RBAC for Kubernetes access control
- Enable NetworkPolicies in Phase 3
- Never commit secrets to Git (use sealed-secrets or external-secrets)
- Regular backups of etcd and cluster state

## Disaster Recovery

**Backup Strategy:**
- Daily etcd snapshots (30-day retention)
- Cluster configs in Git (unlimited retention)
- Media backups weekly (12-week retention)

**Recovery Objectives:**
- Single pod failure: <2 minutes
- Single worker node failure: <5 minutes
- Single control plane failure: 0 downtime (HA)
- Complete cluster rebuild: <4 hours

**Critical Commands:**
```bash
# etcd backup
talosctl --nodes 10.69.1.101 etcd snapshot /tmp/etcd-backup.db

# Cluster state backup
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml
```

## Context7 MCP Integration

This project uses Context7 MCP for up-to-date documentation. To leverage it, include "use context7" in prompts when working with:
- Kubernetes v1.34.1 manifests and APIs
- Talos Linux v1.11.2 configuration
- Helm charts and operators
- Container image specifications

## Common Troubleshooting

**Node Not Ready:**
```bash
kubectl describe node <node-name>
talosctl --nodes <node-ip> logs kubelet
kubectl top node <node-name>  # Check resource pressure
```

**Pod Stuck Pending:**
```bash
kubectl describe pod <pod-name> -n <namespace>
# Common causes:
# - Insufficient resources (check resource requests)
# - Volume mount issues (check PVC status)
# - Node selector not matching (check labels)
# - Image pull errors (check imagePullPolicy)
```

**Pod Crash Loop:**
```bash
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous  # View previous crash logs
kubectl describe pod <pod-name> -n <namespace>
```

**etcd Issues:**
```bash
talosctl --nodes 10.69.1.101 get members
talosctl --nodes 10.69.1.101 logs etcd
# Verify quorum (need 2/3 healthy)
talosctl --nodes 10.69.1.101,10.69.1.102,10.69.1.103 get members
```

**Cluster Bootstrap Failed:**
```bash
# Check if already bootstrapped
talosctl --nodes 10.69.1.101 get members

# If empty, bootstrap may have failed - try again
talosctl bootstrap --nodes 10.69.1.101

# Wait and check health
talosctl health --wait-timeout 10m
```

**Network Issues:**
```bash
# Check pod networking
kubectl get pods -n kube-system | grep -E "flannel|coredns"

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -- nslookup kubernetes.default

# Check service endpoints
kubectl get endpoints <service-name> -n <namespace>
```

**Storage Issues:**
```bash
# Check PVC status
kubectl get pvc -A

# Check StorageClass
kubectl get storageclass

# Describe PVC for events
kubectl describe pvc <pvc-name> -n <namespace>

# Check NFS connectivity (Phase 2+)
kubectl run -it --rm debug --image=busybox --restart=Never -- ping 10.69.1.163
```

## Project Tracking

### Task Management

**TASKS.md** - Day-by-day Phase 1 implementation checklist
- Check off tasks as you complete them
- Record actual time spent vs estimated
- Document issues and blockers
- Track performance metrics

**After completing each task:**
```bash
# 1. Check off task in TASKS.md
# 2. Add notes about any issues encountered
# 3. Record actual time spent
# 4. Update CHANGELOG.md with changes made
```

### Change Tracking

**CRITICAL: ALWAYS UPDATE CHANGELOG.md**

**CHANGELOG.md** - Project history and changes
- Document all configuration changes
- Record IP address updates
- Track software version upgrades
- Note lessons learned
- **MUST be updated after every task, issue resolution, or configuration change**

**When making changes:**
1. **IMMEDIATELY** update CHANGELOG.md with the change
2. Describe what was added/changed/fixed
3. Include relevant commands or configs
4. Note any breaking changes or issues encountered
5. Reference related tasks from TASKS.md
6. Include date/timestamp

**Example changelog entry:**
```markdown
## [2025-10-03]

### Added
- Deployed MetalLB with IP pool 10.69.1.150-160

### Changed
- Updated NFS server IP from .200 to .163

### Fixed
- Resolved etcd quorum issue on node restart
  - Issue: Node 2 not rejoining etcd after reboot
  - Solution: Waited 5 minutes for automatic rejoin
  - Prevention: Normal behavior, no action needed

### Tasks Completed
- TASKS.md: Day 2-3 Network Configuration

### Issues Encountered
- None
```

### Issue Resolution Workflow

When encountering an issue:
1. **Document in TASKS.md** under "Active Issues"
2. **Troubleshoot** using commands in this guide
3. **Record solution** in TASKS.md under "Resolved Issues"
4. **Update CHANGELOG.md** with fix details
5. **Move to "Lessons Learned"** if applicable

### Phase Completion

Before marking a phase complete:
- [ ] All tasks in TASKS.md checked off
- [ ] CHANGELOG.md updated with phase summary
- [ ] Success criteria verified
- [ ] Lessons learned documented
- [ ] Git commit of all configs
- [ ] Backup of cluster state

## Beelink SER5 Specific Notes

**BIOS Boot Key:** Press **F7** repeatedly during boot to enter boot menu
- Alternative keys: F12 or ESC
- Required for initial USB boot to install Talos

**USB Boot Display:**
- USB drive appears as "UEFI: USB Device" or brand name
- After Talos installation, boot from internal NVMe (no USB needed)

**Windows Removal:**
- Talos installer WIPES entire NVMe disk during installation
- Pre-installed Windows 11 Pro is permanently deleted
- No recovery possible after apply-config

**Hardware Features:**
- 2.5Gb Ethernet (ensure UniFi switch supports)
- AMD Radeon graphics (available for future GPU transcoding)
- Low power consumption: 15-35W per node typical

## Key Reminders

### Cluster Operations
1. **Never bootstrap more than once** - Only run `talosctl bootstrap` on first control plane node during initial setup
2. **etcd quorum** - Need 2/3 control plane nodes healthy; never shut down 2+ simultaneously
3. **No SSH** - All node access via talosctl API only
4. **Backup talosconfig** - Store ~/talos-cluster/talosconfig safely; required for cluster management
5. **Version control configs** - Git commit all YAML configs for disaster recovery

### Network & Storage
6. **MetalLB IP pool** - Reserve 10.69.1.150-160; don't assign to any devices
7. **UniFi DHCP** - Exclude .150-.160 from DHCP range to avoid conflicts with MetalLB
8. **NFS dependency** - Phase 2+ workloads depend on NAS (10.69.1.163) being operational

### Media Stack (Phase 4)
9. **Deployment order matters** - Always deploy: Prowlarr → Download Client → *arr services → Plex
10. **Secrets never in Git** - Never commit API keys or tokens; use Kubernetes Secrets only
11. **Document current setup** - Fill out [current_mediaserver.md](current_mediaserver.md) before migration
12. **Service communication** - Use Kubernetes DNS names: `<service>.media.svc.cluster.local`

### Documentation & Tracking
13. **Use context7** - Include "use context7" in prompts for up-to-date Kubernetes/Talos documentation
14. **Update tracking** - After completing tasks, update TASKS.md and CHANGELOG.md
15. **Document issues** - Log problems in TASKS.md Issue Tracking section for future reference

## Repository Structure

This is your command post for managing the Talos Kubernetes cluster:

```
k8_cluster/                          # Command post root
├── README.md                        # Quick reference and overview
├── QUICK_START.md                   # Quick start guide
├── CLUSTER_COMPLETE.md              # Phase 1 completion documentation
├── PRD.md                           # Product Requirements Document
├── TASKS.md                         # Implementation task tracking
├── CHANGELOG.md                     # Change history (UPDATE WITH EVERY CHANGE)
├── CLAUDE.md                        # This file - AI assistant context
├── current_mediaserver.md           # Proxmox media server documentation
│
├── config/                          # Configuration files
│   └── talos/
│       └── live-config/             # Symlink to ~/talos-cluster/
│           ├── controlplane.yaml    # Control plane node config
│           ├── worker.yaml          # Worker node config
│           ├── talosconfig          # Talos client authentication
│           └── all-node-ips.txt     # Node IP inventory
│
├── docs/                            # Documentation
│   ├── procedures/                  # Step-by-step procedures
│   │   ├── TALOS_INSTALLATION_PLAYBOOK.md
│   │   └── TALOS_WINDOWS_WIPE_PROCESS.md
│   └── talos/                       # Talos-specific docs
│
├── scripts/                         # Automation scripts
│   └── talos/                       # Talos management scripts
│       ├── check-cluster-health.sh
│       └── bootstrap-cluster.sh
│
└── cluster-state/                   # Current cluster state
    ├── nodes.yaml                   # Node inventory
    └── status.md                    # Current status
```

## Reference Documentation

### Project Files
- **[PRD.md](PRD.md)** - Complete product requirements and specifications
- **[TASKS.md](TASKS.md)** - Phase 1 implementation checklist with day-by-day tasks
- **[CHANGELOG.md](CHANGELOG.md)** - Project history and change log (**UPDATE WITH EVERY CHANGE**)
- **[current_mediaserver.md](current_mediaserver.md)** - Existing Proxmox media server configuration, API keys, and migration notes (Phase 4)

### External Documentation
- **Talos Linux:** https://www.talos.dev
- **Kubernetes:** https://kubernetes.io/docs
- **MetalLB:** https://metallb.universe.tf
- **Prometheus:** https://prometheus.io/docs
- **Flannel:** https://github.com/flannel-io/flannel
- **cert-manager:** https://cert-manager.io/docs

### Quick Start Workflow

**For new Claude Code sessions:**
1. Read this CLAUDE.md file for context
2. Check TASKS.md for current phase progress
3. Review CHANGELOG.md for recent changes
4. Use "use context7" in prompts for up-to-date docs
5. Update TASKS.md and CHANGELOG.md after completing work
