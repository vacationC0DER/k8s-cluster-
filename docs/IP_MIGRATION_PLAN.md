# IP Migration Plan: 10.69.1.0/24 → 10.69.2.0/24

**Date:** October 7, 2025
**Objective:** Move Kubernetes cluster to dedicated media network (10.69.2.0/24)
**Reason:** Avoid IP conflicts, improve security isolation

## New IP Allocations

### Infrastructure
| Component | Old IP | New IP | Notes |
|-----------|--------|--------|-------|
| Control Plane 1 | 10.69.1.101 | 10.69.2.101 | Primary API endpoint |
| Control Plane 2 | 10.69.1.102 | 10.69.2.102 | |
| Control Plane 3 | 10.69.1.103 | 10.69.2.103 | |
| Worker Node 1 | 10.69.1.104 | 10.69.2.104 | |
| Worker Node 2 | 10.69.1.105 | 10.69.2.105 | |
| Worker Node 3 | 10.69.1.106 | 10.69.2.106 | |
| NFS Storage | 10.69.1.163 | 10.69.2.163 | NAS/Media storage |
| Management Workstation | 10.69.1.167 | 10.69.2.167 | MacBook Pro M2 |

### MetalLB LoadBalancer Pool
| Range | Old | New |
|-------|-----|-----|
| Pool Start | 10.69.1.150 | 10.69.2.150 |
| Pool End | 10.69.1.160 | 10.69.2.160 |

### Media Stack Services
| Service | Old IP | New IP |
|---------|--------|--------|
| Plex | 10.69.1.165 | 10.69.2.165 |
| Prowlarr | 10.69.1.155 | 10.69.2.155 |
| Radarr | 10.69.1.156 | 10.69.2.156 |
| Sonarr | 10.69.1.157 | 10.69.2.157 |
| qBittorrent | 10.69.1.158 | 10.69.2.158 |
| SABnzbd | 10.69.1.161 | 10.69.2.161 |
| Overseerr | 10.69.1.160 | 10.69.2.160 |
| Ingress Controller | 10.69.1.150 | 10.69.2.150 |
| ArgoCD | 10.69.1.162 | 10.69.2.162 |

### Reserved/Future Use
- 10.69.2.170-179: Future media services
- 10.69.2.180-189: Monitoring/observability
- 10.69.2.190-199: Testing/staging

## Migration Strategy: OPTION B (Fresh Bootstrap - RECOMMENDED)

### Why Fresh Bootstrap?
1. ✅ Current Plex pod has networking issues - fresh start resolves this
2. ✅ Cleaner than in-place migration
3. ✅ Can test new cluster before cutover
4. ✅ Easy rollback if issues
5. ✅ Minimal production downtime

### Migration Steps

#### Phase 1: UniFi Network Preparation (15 min)
1. Create new VLAN 2 (10.69.2.0/24) in UniFi
2. Configure DHCP exclusions: 10.69.2.100-199 (static assignments)
3. Create firewall rules:
   - Allow inter-VLAN for NFS (10.69.2.163)
   - Allow management from workstation subnet
   - Block all other inter-VLAN traffic
4. Assign Beelink nodes to new VLAN
5. Create DHCP reservations for all IPs above

#### Phase 2: Backup Current Cluster (30 min)
```bash
# 1. etcd snapshot
talosctl --nodes 10.69.1.101 etcd snapshot ~/backups/etcd-pre-migration-$(date +%Y%m%d).db

# 2. Git backup
cd ~/Development/k8_cluster
git add . && git commit -m "Pre-migration backup - all configs"
git push

# 3. Export all cluster resources
kubectl get all --all-namespaces -o yaml > ~/backups/cluster-state-$(date +%Y%m%d).yaml

# 4. Backup sealed-secrets key (CRITICAL)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > ~/backups/sealed-secrets-key-$(date +%Y%m%d).yaml
```

#### Phase 3: Update Configuration Files (45 min)

Run the migration script (see below) to update all files automatically.

#### Phase 4: Bootstrap New Cluster (60 min)
```bash
# 1. Verify nodes have new IPs
ping 10.69.2.101
ping 10.69.2.102
ping 10.69.2.103

# 2. Generate new cluster configs
cd ~/talos-cluster-new
talosctl gen config my-cluster https://10.69.2.101:6443

# 3. Apply updated configs
talosctl apply-config --insecure --nodes 10.69.2.101 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.2.102 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.2.103 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.2.104 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.2.105 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.2.106 --file worker.yaml

# 4. Bootstrap etcd (ONLY on first control plane)
talosctl bootstrap --nodes 10.69.2.101

# 5. Wait for cluster health
talosctl health --wait-timeout 10m

# 6. Get kubeconfig
talosctl kubeconfig ~/talos-cluster-new/kubeconfig
export KUBECONFIG=~/talos-cluster-new/kubeconfig

# 7. Verify cluster
kubectl get nodes
```

#### Phase 5: Deploy Infrastructure (30 min)
```bash
# 1. Deploy MetalLB
kubectl apply -f infrastructure/metallb/

# 2. Deploy cert-manager (if used)
kubectl apply -f infrastructure/cert-manager/

# 3. Deploy ingress controller
kubectl apply -f infrastructure/ingress-nginx/

# 4. Deploy ArgoCD
kubectl apply -f bootstrap/argocd/install.yaml
kubectl apply -f bootstrap/argocd/media-stack-app.yaml

# 5. Restore sealed-secrets key
kubectl apply -f ~/backups/sealed-secrets-key-*.yaml
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

#### Phase 6: Deploy Media Stack (45 min)
```bash
# ArgoCD will auto-deploy from Git
# Or manually:
kubectl apply -k apps/media/base/

# Wait for all pods
kubectl get pods -n media --watch
```

#### Phase 7: Verification & Testing (30 min)
```bash
# 1. Check all services have LoadBalancer IPs
kubectl get svc -n media

# 2. Test each service
curl http://10.69.2.165:32400/identity  # Plex
curl http://10.69.2.155:9696/api/v1/health  # Prowlarr
curl http://10.69.2.156:7878/api/v3/health  # Radarr

# 3. Test Overseerr → Plex connection
# Access http://10.69.2.160:5055 and configure

# 4. Verify NFS mounts
kubectl exec -n media deployment/plex -- df -h | grep /data
```

#### Phase 8: Update External References (15 min)
1. Update Plex client apps with new IP: 10.69.2.165
2. Update bookmarks/shortcuts
3. Update DNS records (if any)
4. Update documentation

## Rollback Plan

If migration fails, old cluster still exists on 10.69.1.0/24:
```bash
# 1. Switch nodes back to old VLAN in UniFi
# 2. Restore old kubeconfig
export KUBECONFIG=~/talos-cluster/kubeconfig

# 3. Old cluster resumes operation
kubectl get pods -A
```

## Total Estimated Time
- **Preparation:** 1 hour
- **Migration:** 3 hours
- **Testing:** 1 hour
- **Buffer:** 1 hour
- **Total:** ~6 hours

## Pre-Migration Checklist
- [ ] All configs backed up to Git
- [ ] etcd snapshot created
- [ ] Sealed secrets key backed up
- [ ] UniFi VLAN configured
- [ ] All new IP reservations created
- [ ] NFS server accessible on new subnet
- [ ] Workstation can reach new subnet

## Post-Migration Checklist
- [ ] All nodes show Ready
- [ ] All pods Running
- [ ] All services have LoadBalancer IPs
- [ ] Plex accessible externally
- [ ] Overseerr can connect to Plex
- [ ] Radarr/Sonarr can reach Prowlarr
- [ ] Download clients accessible
- [ ] NFS mounts working
- [ ] ArgoCD syncing from Git
- [ ] Old cluster shutdown and archived
