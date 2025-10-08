# IP Migration Quick Start Guide

**Target:** Move to 10.69.2.0/24 dedicated media network

## Pre-Migration (Do First!)

### 1. Get MAC Addresses (5 min)
```bash
# While cluster is still on 10.69.1.0/24:
for ip in 101 102 103 104 105 106; do
  echo -n "Node 10.69.1.$ip: "
  arp 10.69.1.$ip 2>/dev/null | grep -o '[a-f0-9:]\{17\}' || echo "Not found"
done
```
**Save these MACs** - you'll need them for UniFi DHCP reservations!

### 2. Create Backups (15 min)
```bash
# etcd backup
talosctl --nodes 10.69.1.101 etcd snapshot ~/backups/etcd-pre-migration-$(date +%Y%m%d).db

# Git backup
cd ~/Development/k8_cluster
git add . && git commit -m "Pre-migration backup" && git push

# Sealed secrets backup (CRITICAL!)
kubectl get secret -n kube-system sealed-secrets-key -o yaml > ~/backups/sealed-secrets-key.yaml

# Full cluster state
kubectl get all --all-namespaces -o yaml > ~/backups/cluster-state.yaml
```

## Migration Steps

### Step 1: Configure UniFi (30 min)
Follow: `docs/UNIFI_VLAN_SETUP.md`

**Quick checklist:**
- [ ] Create VLAN 2 (10.69.2.0/24)
- [ ] Set DHCP range: 10.69.2.10-99
- [ ] Add DHCP reservations for all 6 nodes (use MACs from above)
- [ ] Add reservation for NFS: 10.69.2.163
- [ ] Configure firewall rules
- [ ] Assign nodes to new VLAN
- [ ] Test connectivity: `ping 10.69.2.101`

### Step 2: Update Configuration Files (10 min)
```bash
# Run automated migration script
cd ~/Development/k8_cluster
./scripts/migrate-to-new-subnet.sh

# Review changes
git diff

# Commit changes
git add .
git commit -m "Update IPs to 10.69.2.0/24 subnet"
git push
```

### Step 3: Bootstrap New Cluster (60 min)
```bash
# Create new config directory
mkdir -p ~/talos-cluster-new
cd ~/talos-cluster-new

# Generate fresh cluster configs
talosctl gen config my-cluster https://10.69.2.101:6443

# Apply to all nodes
talosctl apply-config --insecure --nodes 10.69.2.101 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.2.102 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.2.103 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.2.104 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.2.105 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.2.106 --file worker.yaml

# Bootstrap etcd (ONLY on first control plane!)
talosctl bootstrap --nodes 10.69.2.101

# Wait for health
talosctl health --wait-timeout 10m

# Get kubeconfig
talosctl kubeconfig kubeconfig
export KUBECONFIG=~/talos-cluster-new/kubeconfig

# Verify
kubectl get nodes
```

### Step 4: Deploy Infrastructure (30 min)
```bash
export KUBECONFIG=~/talos-cluster-new/kubeconfig

# Deploy in order:
kubectl apply -f ~/Development/k8_cluster/infrastructure/metallb/
kubectl apply -f ~/Development/k8_cluster/infrastructure/cert-manager/ # if exists
kubectl apply -f ~/Development/k8_cluster/infrastructure/ingress-nginx/ # if exists

# Deploy ArgoCD
kubectl apply -f ~/Development/k8_cluster/bootstrap/argocd/install.yaml
kubectl apply -f ~/Development/k8_cluster/bootstrap/argocd/media-stack-app.yaml

# Restore sealed-secrets key (IMPORTANT!)
kubectl apply -f ~/backups/sealed-secrets-key.yaml
kubectl rollout restart deployment sealed-secrets-controller -n kube-system
```

### Step 5: Deploy Media Stack (30 min)
```bash
# Let ArgoCD sync, or manually apply:
kubectl apply -k ~/Development/k8_cluster/apps/media/base/

# Watch deployment
kubectl get pods -n media --watch

# Wait for all Running
kubectl wait --for=condition=ready pod --all -n media --timeout=10m
```

### Step 6: Verify Everything Works (15 min)
```bash
# Check service IPs
kubectl get svc -n media

# Test services
curl http://10.69.2.165:32400/identity  # Plex
curl http://10.69.2.155:9696/  # Prowlarr
curl http://10.69.2.156:7878/  # Radarr

# Test NFS
kubectl exec -n media deployment/plex -- df -h | grep /data

# Configure Overseerr
open http://10.69.2.160:5055
# Use: http://plex.media.svc.cluster.local:32400
```

### Step 7: Update Workstation (5 min)
```bash
# Update talosctl endpoints
talosctl config endpoint 10.69.2.101 10.69.2.102 10.69.2.103

# Use new kubeconfig permanently
mv ~/talos-cluster ~/talos-cluster-old
mv ~/talos-cluster-new ~/talos-cluster
export KUBECONFIG=~/talos-cluster/kubeconfig

# Add to ~/.zshrc:
echo 'export KUBECONFIG=~/talos-cluster/kubeconfig' >> ~/.zshrc
```

## Troubleshooting

### Nodes won't get new IPs
```bash
# Check UniFi DHCP leases
# Verify nodes are on VLAN 2
# Try rebooting nodes: talosctl reboot --nodes <ip>
```

### Can't reach nodes after VLAN change
```bash
# Ensure workstation is on VLAN with access
# Check UniFi firewall rules
# Verify DHCP reservations are correct
```

### Cluster won't bootstrap
```bash
# Check all 3 control plane nodes are up
# Verify API endpoint: https://10.69.2.101:6443
# Check talosctl config: talosctl config info
```

### Pods stuck Pending
```bash
# Check MetalLB: kubectl get pods -n metallb-system
# Verify NFS: ping 10.69.2.163
# Check PVC: kubectl get pvc -n media
```

## Success Criteria

✅ All 6 nodes show `Ready`
✅ All pods in `media` namespace `Running`
✅ All services have LoadBalancer IPs (10.69.2.x)
✅ Plex accessible at http://10.69.2.165:32400
✅ Overseerr can connect to Plex
✅ Media files accessible in Plex
✅ No errors in `kubectl get events -A`

## Rollback (If Needed)

```bash
# 1. In UniFi, reassign nodes back to old VLAN
# 2. Reboot nodes to get old IPs
# 3. Use old kubeconfig
export KUBECONFIG=~/talos-cluster-old/kubeconfig
kubectl get nodes  # Should work on 10.69.1.x
```

## Time Estimate
- **Preparation:** 30 minutes
- **Migration:** 3 hours
- **Testing:** 30 minutes
- **Total:** ~4 hours

## Questions Before Starting?

Read full details:
- **Migration Plan:** `docs/IP_MIGRATION_PLAN.md`
- **UniFi Setup:** `docs/UNIFI_VLAN_SETUP.md`

Good luck! 🚀
