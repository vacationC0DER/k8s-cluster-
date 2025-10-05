# K8 Cluster Quick Start Guide

**Your 6-Node Talos Kubernetes Cluster Command Post**

---

## 🚀 Getting Started

### Your Cluster is Ready!
✅ All 6 nodes configured  
✅ Windows removed from all nodes  
✅ All running from NVMe  
✅ Ready for bootstrap

---

## ⚡ Quick Commands

### 1. Check Cluster Health
```bash
./scripts/talos/check-cluster-health.sh
```

### 2. Bootstrap Cluster (Run ONCE)
```bash
./scripts/talos/bootstrap-cluster.sh
```

### 3. Access Cluster
```bash
export TALOSCONFIG=~/talos-cluster/talosconfig
kubectl get nodes
```

---

## 📁 Important Files

| File | Purpose |
|------|---------|
| `README.md` | Main command post overview |
| `docs/procedures/TALOS_INSTALLATION_PLAYBOOK.md` | Complete installation guide |
| `cluster-state/nodes.yaml` | Node inventory |
| `cluster-state/status.md` | Current cluster status |
| `config/talos/live-config/` | Live Talos configuration |
| `scripts/talos/` | Automation scripts |

---

## 🎯 Next Steps

1. **Bootstrap the cluster:**
   ```bash
   cd /Users/stevenbrown/Development/k8_cluster
   ./scripts/talos/bootstrap-cluster.sh
   ```

2. **Verify nodes:**
   ```bash
   kubectl get nodes -o wide
   ```

3. **Deploy applications:**
   - Follow `PRD.md` for deployment plan
   - Use `TASKS.md` for task tracking

---

## 📞 Need Help?

- **Installation Issues:** See `docs/procedures/TALOS_INSTALLATION_PLAYBOOK.md`
- **Cluster Operations:** See `README.md`
- **Application Deployment:** See `PRD.md`
- **Current Tasks:** See `TASKS.md`

---

**Your command post is ready! Let's bootstrap this cluster! 🚀**


