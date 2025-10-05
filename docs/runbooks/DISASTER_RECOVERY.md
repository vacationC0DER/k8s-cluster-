# Disaster Recovery Runbook

**Cluster:** Talos Kubernetes v1.34.1 (6-node bare-metal)
**Last Updated:** 2025-10-05
**Owner:** Infrastructure Team

## Overview

This runbook provides step-by-step recovery procedures for various disaster scenarios affecting the Talos Kubernetes cluster.

## Prerequisites

Before executing any recovery procedure:

- [ ] Access to management workstation (10.69.1.167)
- [ ] `talosctl` CLI installed and configured
- [ ] `kubectl` CLI installed and configured
- [ ] TALOSCONFIG: `/Users/stevenbrown/talos-cluster/talosconfig`
- [ ] KUBECONFIG: `/Users/stevenbrown/talos-cluster/kubeconfig`
- [ ] Recent etcd backup available
- [ ] Git repository with cluster configs: `/Users/stevenbrown/Development/k8_cluster`

## Emergency Contacts

- **Primary Contact:** [Your Name/Email]
- **Escalation:** [Manager/Team Lead]
- **Network Team:** [For UniFi/network issues]

---

## Scenario 1: Single Control Plane Node Failure

**Symptoms:**
- One control plane node offline or unreachable
- kubectl commands still working (2/3 nodes healthy)
- etcd quorum maintained (2/3 members)

**Expected Behavior:**
- **Zero downtime** (etcd quorum maintained with 2/3 nodes)
- All workloads continue running normally
- New deployments succeed

### Recovery Steps

1. **Verify cluster status**
   ```bash
   kubectl get nodes
   talosctl health
   talosctl --nodes 10.69.1.101 get members
   ```

2. **Identify failed node**
   ```bash
   kubectl get nodes | grep NotReady
   # Example: talos-2xk-hsd (10.69.1.140)
   ```

3. **Power on failed node**
   - Physical access to Beelink SER5 mini PC
   - Press power button
   - Wait 60 seconds for boot

4. **Verify node rejoin**
   ```bash
   # Wait 2-5 minutes for automatic rejoin
   kubectl get nodes
   talosctl --nodes 10.69.1.140 get members
   ```

5. **Verify etcd health**
   ```bash
   talosctl --nodes 10.69.1.101,10.69.1.140,10.69.1.147 get members
   # Should show 3/3 members healthy
   ```

**Recovery Time Objective (RTO):** < 5 minutes
**Recovery Point Objective (RPO):** 0 (no data loss)

**Tested:** Phase 1 (Day 11) - talos-2xk-hsd shutdown test - 0 downtime confirmed

---

## Scenario 2: Single Worker Node Failure

**Symptoms:**
- One worker node offline or unreachable
- Workloads on that node terminating
- Pods rescheduling to remaining workers

**Expected Behavior:**
- Pods reschedule automatically to healthy workers
- <30 second recovery time (based on Phase 1 testing)
- Services remain accessible (multiple replicas)

### Recovery Steps

1. **Verify cluster status**
   ```bash
   kubectl get nodes
   kubectl get pods -A | grep -v Running
   ```

2. **Identify affected workloads**
   ```bash
   kubectl get pods -A -o wide | grep <failed-node-name>
   ```

3. **Verify pod rescheduling**
   ```bash
   # Pods should automatically reschedule within 30 seconds
   kubectl get pods -A -o wide
   ```

4. **Power on failed node**
   - Physical access to Beelink SER5 mini PC
   - Press power button
   - Wait 60 seconds for boot

5. **Uncordon node (if needed)**
   ```bash
   kubectl uncordon <node-name>
   ```

6. **Verify node rejoined**
   ```bash
   kubectl get nodes
   # Status should show Ready
   ```

**RTO:** < 2 minutes (pod reschedule + startup)
**RPO:** 0 (no data loss)

**Tested:** Phase 1 (Day 10) - talos-qal-bre shutdown test - 23 seconds recovery confirmed

---

## Scenario 3: etcd Quorum Loss (2+ Control Plane Nodes Down)

**Symptoms:**
- kubectl commands timeout or fail
- kube-apiserver unreachable
- "connection refused" or "context deadline exceeded" errors
- 2 or 3 control plane nodes offline

**Expected Behavior:**
- **Complete cluster outage** (etcd requires 2/3 quorum)
- Workloads stop responding
- No new operations possible

### Recovery Steps

**CRITICAL: DO NOT attempt this without recent etcd backup**

1. **Verify etcd quorum loss**
   ```bash
   kubectl get nodes
   # Command will timeout or fail

   talosctl --nodes 10.69.1.101,10.69.1.140,10.69.1.147 get members
   # Check how many members respond
   ```

2. **Power on ALL control plane nodes**
   - Physically access all 3 control plane nodes
   - Power on in order: 10.69.1.101 → 10.69.1.140 → 10.69.1.147
   - Wait 2 minutes between each node

3. **Wait for automatic recovery**
   ```bash
   # Wait 5-10 minutes for etcd to reform quorum
   watch -n 5 'talosctl --nodes 10.69.1.101 get members 2>&1'
   ```

4. **If automatic recovery fails: Restore from backup**

   **WARNING: This is a destructive operation. All changes since backup will be lost.**

   ```bash
   # Step 1: Stop secondary control plane nodes
   talosctl --nodes 10.69.1.140,10.69.1.147 shutdown

   # Step 2: Get latest etcd backup
   LATEST_BACKUP=$(ls -t /Users/stevenbrown/Development/k8_cluster/backups/etcd/etcd-backup-*.db | head -1)
   echo "Using backup: $LATEST_BACKUP"

   # Step 3: Restore etcd on primary node
   talosctl --nodes 10.69.1.101 etcd snapshot restore --from "$LATEST_BACKUP"

   # Step 4: Reboot primary node
   talosctl --nodes 10.69.1.101 reboot

   # Step 5: Wait for primary node Ready
   watch -n 5 'kubectl get nodes | grep talos-l7v-3rn'

   # Step 6: Verify etcd running
   talosctl --nodes 10.69.1.101 get members

   # Step 7: Power on secondary nodes
   # Physical access required

   # Step 8: Wait for cluster recovery
   watch -n 5 'kubectl get nodes'

   # Step 9: Verify etcd cluster
   talosctl --nodes 10.69.1.101,10.69.1.140,10.69.1.147 get members
   ```

5. **Verify all workloads recovered**
   ```bash
   kubectl get pods -A
   kubectl get svc -A
   ```

**RTO:** 15-30 minutes (with backup restore)
**RPO:** Up to 24 hours (last backup)

**Tested:** Not tested (requires intentional multi-node failure)

---

## Scenario 4: Complete Cluster Loss (All Nodes Down)

**Symptoms:**
- All 6 nodes offline
- Power outage or network failure
- Physical hardware failure

### Recovery Steps

1. **Power on all nodes**
   - Start with control plane nodes: 10.69.1.101, 10.69.1.140, 10.69.1.147
   - Wait 5 minutes for control plane to stabilize
   - Then power on workers: 10.69.1.104, 10.69.1.106, 10.69.1.179

2. **Verify automatic cluster recovery**
   ```bash
   # Wait 10 minutes for all services to start
   watch -n 10 'kubectl get nodes'
   ```

3. **If cluster doesn't recover: Bootstrap from scratch**

   **Prerequisites:**
   - etcd backup: `/Users/stevenbrown/Development/k8_cluster/backups/etcd/etcd-backup-*.db`
   - Cluster configs: `/Users/stevenbrown/talos-cluster/controlplane.yaml`, `worker.yaml`
   - This Git repository

   ```bash
   # Step 1: Apply configs to all nodes
   talosctl apply-config --insecure --nodes 10.69.1.101 --file ~/talos-cluster/controlplane.yaml
   talosctl apply-config --insecure --nodes 10.69.1.140 --file ~/talos-cluster/controlplane.yaml
   talosctl apply-config --insecure --nodes 10.69.1.147 --file ~/talos-cluster/controlplane.yaml
   talosctl apply-config --insecure --nodes 10.69.1.104 --file ~/talos-cluster/worker.yaml
   talosctl apply-config --insecure --nodes 10.69.1.106 --file ~/talos-cluster/worker.yaml
   talosctl apply-config --insecure --nodes 10.69.1.179 --file ~/talos-cluster/worker.yaml

   # Step 2: Bootstrap etcd (ONLY on first node)
   talosctl bootstrap --nodes 10.69.1.101

   # Step 3: Wait for cluster health
   talosctl health --wait-timeout 10m

   # Step 4: Get kubeconfig
   talosctl kubeconfig .

   # Step 5: Restore etcd from backup (if needed)
   LATEST_BACKUP=$(ls -t backups/etcd/etcd-backup-*.db | head -1)
   talosctl --nodes 10.69.1.101 etcd snapshot restore --from "$LATEST_BACKUP"
   talosctl --nodes 10.69.1.101 reboot

   # Step 6: Redeploy workloads from Git
   kubectl apply -k apps/media/base/
   kubectl apply -f bootstrap/argocd/
   kubectl apply -f apps/ha/

   # Step 7: Verify all services
   kubectl get pods -A
   ```

**RTO:** 1-2 hours
**RPO:** Up to 24 hours (last backup)

**Tested:** Not tested (catastrophic scenario)

---

## Scenario 5: Media Stack Data Loss (PVC Corruption)

**Symptoms:**
- Pod crash loops with database errors
- "database disk image is malformed" errors
- SQLite corruption (e.g., Plex, *arr services)

### Recovery Steps

**Tested:** Phase 4 (Oct 5) - Plex database corruption - <2 minute recovery confirmed

1. **Identify affected service**
   ```bash
   kubectl get pods -n media | grep -v Running
   kubectl logs <pod-name> -n media
   ```

2. **Stop affected service**
   ```bash
   kubectl scale deployment/<service> -n media --replicas=0
   ```

3. **Delete corrupted PVC**
   ```bash
   kubectl get pvc -n media
   kubectl delete pvc media-configs -n media
   ```

4. **Recreate PVC**
   ```bash
   kubectl apply -f apps/media/base/media-storage-pvcs.yaml
   ```

5. **Restart service**
   ```bash
   kubectl scale deployment/<service> -n media --replicas=1
   ```

6. **Verify service healthy**
   ```bash
   kubectl get pods -n media
   kubectl logs <pod-name> -n media
   ```

7. **Reconfigure service via web UI**
   - Access service LoadBalancer IP
   - Complete setup wizard
   - Reconfigure API integrations

**RTO:** < 5 minutes
**RPO:** Config loss (media files preserved on NFS)

**Prevention:**
- NFS snapshot strategy (if supported by NAS)
- Export configs before changes
- Document all API keys in CHANGELOG.md

---

## Scenario 6: Sealed Secrets Controller Failure

**Symptoms:**
- Cannot decrypt SealedSecret resources
- New secrets fail to create
- Pod startup failures due to missing secrets

### Recovery Steps

1. **Verify Sealed Secrets controller status**
   ```bash
   kubectl get pods -n kube-system -l name=sealed-secrets-controller
   kubectl logs -n kube-system -l name=sealed-secrets-controller
   ```

2. **Backup encryption key (CRITICAL - do this NOW if not done)**
   ```bash
   kubectl get secret -n kube-system sealed-secrets-key -o yaml > sealed-secrets-key-backup.yaml
   # Store in SECURE location (NOT in Git!)
   ```

3. **If controller pod crashed: Restart it**
   ```bash
   kubectl delete pod -n kube-system -l name=sealed-secrets-controller
   # Wait for new pod to start
   kubectl get pods -n kube-system -l name=sealed-secrets-controller
   ```

4. **If encryption key lost: Restore from backup**
   ```bash
   # Restore encryption key
   kubectl apply -f sealed-secrets-key-backup.yaml

   # Restart controller
   kubectl rollout restart deployment sealed-secrets-controller -n kube-system

   # Verify
   kubectl get sealedsecrets -A
   ```

5. **If key cannot be restored: Recreate all secrets**
   ```bash
   # Reinstall Sealed Secrets (generates new key)
   kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.27.1/controller.yaml

   # Re-seal all secrets with new key
   kubeseal --fetch-cert > pub-cert.pem

   # For each secret, re-encrypt and apply
   # (This requires original secret values)
   ```

**RTO:** < 10 minutes (if backup exists)
**RPO:** 0 (if encryption key backed up)

**Prevention:**
- **BACKUP ENCRYPTION KEY IMMEDIATELY**
- Store backup off-cluster (NAS, cloud)
- Test restore procedure quarterly

---

## Scenario 7: MetalLB IP Pool Exhaustion

**Symptoms:**
- New LoadBalancer services stuck in `<pending>`
- Events show "no available IPs"
- Cannot create new LoadBalancer services

### Recovery Steps

1. **Check current IP usage**
   ```bash
   kubectl get svc -A | grep LoadBalancer
   kubectl get ipaddresspool -n metallb-system -o yaml
   ```

2. **Expand MetalLB IP pool**
   ```bash
   kubectl edit ipaddresspool -n metallb-system

   # Change:
   # addresses:
   # - 10.69.1.150-10.69.1.165
   # To:
   # addresses:
   # - 10.69.1.150-10.69.1.175
   ```

3. **Verify in UniFi**
   - Ensure new IP range excluded from DHCP
   - Update DHCP pool if needed

4. **Verify service gets IP**
   ```bash
   kubectl get svc -n <namespace> <service-name>
   ```

**RTO:** < 5 minutes
**RPO:** N/A (no data loss)

**Current Pool:** 10.69.1.150-165 (16 IPs, 8 assigned, 8 available)

---

## Scenario 8: ArgoCD Application OutOfSync

**Symptoms:**
- ArgoCD showing "OutOfSync" status
- Manual changes detected
- Workloads not matching Git state

### Recovery Steps

1. **Check Application status**
   ```bash
   kubectl get application -n argocd
   kubectl describe application <app-name> -n argocd
   ```

2. **View diff**
   ```bash
   # Via ArgoCD UI: http://10.69.1.162
   # Or via CLI (if installed):
   argocd app diff <app-name>
   ```

3. **If drift is intentional: Update Git**
   ```bash
   # Export live resource
   kubectl get <resource> -n <namespace> -o yaml > apps/path/to/file.yaml

   # Remove managed fields
   # Edit file to remove: metadata.managedFields, metadata.uid, etc.

   # Commit to Git
   git add .
   git commit -m "Update resource to match live state"
   git push
   ```

4. **If drift is unintentional: Sync from Git**
   ```bash
   kubectl patch application <app-name> -n argocd --type merge -p '{"spec": {"syncPolicy": {"automated": {"prune": true}}}}'
   # Or use ArgoCD UI: Click "Sync"
   ```

5. **Verify sync**
   ```bash
   kubectl get application <app-name> -n argocd
   # Should show: Synced / Healthy
   ```

**RTO:** < 2 minutes
**RPO:** Depends on Git history

---

## Recovery Testing Schedule

| Scenario | Frequency | Last Tested | Next Test | Pass/Fail |
|----------|-----------|-------------|-----------|-----------|
| Single Control Plane Failure | Quarterly | 2025-10-03 | 2026-01-03 | PASS |
| Single Worker Failure | Quarterly | 2025-10-03 | 2026-01-03 | PASS |
| etcd Quorum Loss | Annually | Not Tested | 2026-01-01 | - |
| Complete Cluster Loss | Annually | Not Tested | 2026-01-01 | - |
| Media Stack PVC Corruption | As Needed | 2025-10-05 | - | PASS |
| Sealed Secrets Failure | Annually | Not Tested | 2026-01-01 | - |
| MetalLB Pool Exhaustion | Annually | Not Tested | 2026-01-01 | - |
| ArgoCD Drift | Quarterly | 2025-10-05 | 2026-01-05 | PASS |

## Backup Verification

- [ ] etcd backups running daily (automated via cron)
- [ ] Backups stored: `/Users/stevenbrown/Development/k8_cluster/backups/etcd/`
- [ ] 7-day retention policy active
- [ ] Latest backup size: ~30MB (normal)
- [ ] Sealed Secrets encryption key backed up: **ACTION REQUIRED**
- [ ] Git repository configs up to date: YES
- [ ] Off-site backup configured: **ACTION REQUIRED**

## Post-Recovery Checklist

After completing any recovery procedure:

- [ ] Verify cluster health: `talosctl health`
- [ ] Verify all nodes Ready: `kubectl get nodes`
- [ ] Verify etcd members: `talosctl get members`
- [ ] Verify all pods Running: `kubectl get pods -A`
- [ ] Verify LoadBalancer IPs assigned: `kubectl get svc -A | grep LoadBalancer`
- [ ] Test media service access: HTTP 200 to all LoadBalancer IPs
- [ ] Test ArgoCD access: http://10.69.1.162
- [ ] Document incident in CHANGELOG.md
- [ ] Update this runbook if procedures changed
- [ ] Create etcd backup: `./scripts/backup-etcd.sh`

## Critical Files Backup

Always have these available for recovery:

1. **Talos Configs** (encrypted, safe in Git):
   - `/Users/stevenbrown/talos-cluster/controlplane.yaml`
   - `/Users/stevenbrown/talos-cluster/worker.yaml`
   - `/Users/stevenbrown/talos-cluster/talosconfig`

2. **Kubernetes Configs**:
   - `/Users/stevenbrown/talos-cluster/kubeconfig`
   - `/Users/stevenbrown/Development/k8_cluster/apps/`

3. **Backups**:
   - etcd: `/Users/stevenbrown/Development/k8_cluster/backups/etcd/`
   - Sealed Secrets key: **BACKUP IMMEDIATELY**

4. **Git Repository**:
   - Full clone: `/Users/stevenbrown/Development/k8_cluster/`
   - Remote: **Push to GitHub ASAP**

## Additional Resources

- [Talos Disaster Recovery](https://www.talos.dev/v1.11/advanced/disaster-recovery/)
- [Kubernetes Disaster Recovery Best Practices](https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#backing-up-an-etcd-cluster)
- [etcd Recovery Guide](https://etcd.io/docs/v3.5/op-guide/recovery/)

## Revision History

| Date | Version | Author | Changes |
|------|---------|--------|---------|
| 2025-10-05 | 1.0 | Phase 5 Implementation | Initial creation with 8 scenarios |
