# K8 Cluster Command Post

**Talos Kubernetes Cluster - 6-Node Production Setup**

---

## 🎯 Quick Status

**Cluster Status:** ✅ All Nodes Operational (6/6) - Ready for Bootstrap
**Last Updated:** October 3, 2025
**Talos Version:** v1.11.2
**Kubernetes Version:** (Pending Bootstrap)
**Phase:** Phase 1 Week 1 Complete | Phase 1 Week 2 Ready

---

## 📊 Cluster Overview

### Node Configuration

| Node | Role | IP | System Disk | Windows Removed | Status |
|------|------|-----|-------------|-----------------|---------|
| Node 1 | Control Plane | 10.69.1.101 | nvme0n1 | ✅ Yes | ✅ Operational |
| Node 2 | Control Plane | 10.69.1.140 | nvme0n1 | ✅ Yes | ✅ Operational |
| Node 3 | Control Plane | 10.69.1.147 | nvme0n1 | ✅ Yes | ✅ Operational |
| Node 4 | Worker | 10.69.1.151 | nvme0n1 | ✅ Yes | ✅ Operational |
| Node 5 | Worker | 10.69.1.197 | nvme0n1 | ✅ Yes | ✅ Operational |
| Node 6 | Worker | 10.69.1.179 | nvme0n1 | ✅ Yes | ✅ Operational |

### Network Configuration
- **Network:** 10.69.1.0/24
- **Control Plane Endpoint:** https://10.69.1.101:6443
- **MetalLB Pool:** 10.69.1.150-160 (Reserved)
- **NAS Storage:** 10.69.1.163 (NFS)
- **Proxmox Media Server:** 10.69.1.180 (Current Plex stack - see current_mediaserver.md)

---

## 📁 Command Post Structure

```
k8_cluster/                          # Main command post
├── README.md                        # This file - quick reference
├── PRD.md                           # Product Requirements Document
├── CLAUDE.md                        # AI assistant context
├── TASKS.md                         # Task tracking
├── CHANGELOG.md                     # Change history
│
├── config/                          # All configuration files
│   └── talos/
│       └── live-config/             # Symlink to ~/talos-cluster/
│           ├── controlplane.yaml
│           ├── worker.yaml
│           ├── talosconfig
│           └── all-node-ips.txt
│
├── docs/                            # Documentation
│   ├── procedures/                  # Step-by-step procedures
│   │   ├── TALOS_INSTALLATION_PLAYBOOK.md
│   │   └── TALOS_WINDOWS_WIPE_PROCESS.md
│   └── talos/                       # Talos-specific docs
│
├── scripts/                         # Automation scripts
│   └── talos/                       # Talos management scripts
│
└── cluster-state/                   # Current cluster state
    ├── nodes.yaml                   # Node inventory
    └── status.md                    # Current status
```

---

## 🚀 Quick Commands

### Talos Management

```bash
# Set environment
export TALOSCONFIG=~/talos-cluster/talosconfig

# Check all nodes
talosctl --nodes 10.69.1.101,10.69.1.140,10.69.1.147 version

# Check specific node
talosctl --nodes <NODE_IP> get systemdisk
talosctl --nodes <NODE_IP> services

# Bootstrap cluster (run ONCE)
talosctl bootstrap --nodes 10.69.1.101

# Get kubeconfig
talosctl kubeconfig --nodes 10.69.1.101
```

### Kubernetes Management

```bash
# View all nodes
kubectl get nodes -o wide

# View all pods
kubectl get pods -A

# Check cluster health
kubectl cluster-info
kubectl get componentstatuses
```

---

## 📚 Documentation Index

### Procedures
- **[Talos Installation Playbook](docs/procedures/TALOS_INSTALLATION_PLAYBOOK.md)** - Complete 8-phase installation process
- **[Windows Wipe Process](docs/procedures/TALOS_WINDOWS_WIPE_PROCESS.md)** - Detailed Windows removal guide

### Planning
- **[PRD.md](PRD.md)** - Product Requirements & Architecture
- **[TASKS.md](TASKS.md)** - Implementation Tasks
- **[current_mediaserver.md](current_mediaserver.md)** - Current setup documentation

### Operations
- **[CHANGELOG.md](CHANGELOG.md)** - Change history
- **[CLAUDE.md](CLAUDE.md)** - AI assistant context & commands

---

## 🔑 Key Files & Locations

### Configuration Files
- **Talos Config:** `~/talos-cluster/` (symlinked from `config/talos/live-config/`)
- **Talos Client Auth:** `~/talos-cluster/talosconfig`
- **Kubeconfig:** `~/.kube/config` (after bootstrap)

### Important Endpoints
- **Control Plane API:** https://10.69.1.101:6443
- **Talos API:** Port 50000 on each node
- **Kubernetes API:** Port 6443

---

## ⚡ Common Operations

### Check Node Health
```bash
# Quick health check
for ip in 10.69.1.101 10.69.1.140 10.69.1.147 10.69.1.151 10.69.1.197 10.69.1.179; do
  echo "Node $ip:"
  talosctl --nodes $ip get systemdisk 2>/dev/null | grep nvme0n1 && echo "✅" || echo "❌"
done
```

### View Node Services
```bash
# Check services on all control plane nodes
talosctl --nodes 10.69.1.101,10.69.1.140,10.69.1.147 services
```

### Cluster Bootstrap Status
```bash
# Check if etcd is running (after bootstrap)
talosctl --nodes 10.69.1.101 get members

# Check Kubernetes pods
kubectl get pods -n kube-system
```

---

## 🛠️ Next Steps

### Immediate Tasks
1. **Bootstrap Cluster**
   ```bash
   talosctl bootstrap --nodes 10.69.1.101
   ```

2. **Get Kubernetes Access**
   ```bash
   talosctl kubeconfig --nodes 10.69.1.101
   kubectl get nodes
   ```

3. **Deploy Core Services**
   - MetalLB (Load Balancer)
   - Storage provisioner
   - Ingress controller

### Application Deployment
- Follow `PRD.md` for media server stack deployment
- Configure NFS storage integration
- Set up MetalLB load balancing

---

## 📞 Support & References

### Official Documentation
- **Talos Linux:** https://www.talos.dev/
- **Kubernetes:** https://kubernetes.io/

### Hardware
- **Nodes:** Beelink SER5 (6 units)
- **Storage:** 512GB NVMe per node
- **Network:** Gigabit Ethernet (UniFi managed)
- **NAS:** 10.69.1.163 (NFS)

---

## 🎓 Lessons Learned

### Critical Success Factors
1. **USB Removal** - Must remove USB before applying config
2. **NVMe Wipe** - Always manually wipe Windows first
3. **System Disk Verification** - Always verify `nvme0n1` not `sda`
4. **8-Phase Process** - Following the proven process ensures success

### Configuration Requirements
- `disk: /dev/nvme0n1` in both controlplane.yaml and worker.yaml
- `wipe: true` to ensure clean installation
- Certificates must match across all nodes

---

## 📈 Cluster Milestones

- **2025-10-03:** ✅ All 6 nodes successfully configured with Talos
- **2025-10-03:** ✅ Windows completely removed from all nodes
- **2025-10-03:** ✅ All nodes running from NVMe (no USB required)
- **2025-10-03:** ✅ Phase 1 Week 1 Complete - Hardware setup and Talos installation
- **Next:** Cluster bootstrap and Kubernetes deployment (Phase 1 Week 2)

---

**Last Updated:** October 3, 2025  
**Status:** Ready for Bootstrap ✅


