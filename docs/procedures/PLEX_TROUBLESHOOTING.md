# Plex Troubleshooting Guide

## Common Issues and Prevention

### Issue: "Unable to connect securely" from app.plex.tv

**Symptoms:**
- app.plex.tv shows "Unable to connect securely" warning
- Server appears as "SNL++" but won't connect
- Plex logs show "Failed to load preferences" errors

**Root Causes:**
1. Missing `secureConnections` and `customConnections` in Preferences.xml
2. File ownership mismatch preventing Plex from reading configuration
3. Plex not advertising its external LoadBalancer IP

**Prevention (Multi-Layer Defense):**

#### Layer 1: Native Environment Variables ✅
The deployment now uses Plex's native `PLEX_PREFERENCE_*` environment variables:
```yaml
- name: PLEX_PREFERENCE_3
  value: "secureConnections=1"
- name: PLEX_PREFERENCE_4
  value: "customConnections=http://10.69.1.165:32400"
- name: ADVERTISE_IP
  value: "http://10.69.1.165:32400"
```

**Why this works:**
- Environment variables are applied on every pod start
- Plex writes them to Preferences.xml automatically
- Cannot be lost or overwritten by user actions
- Survives pod restarts, updates, and ArgoCD syncs

#### Layer 2: Health Probes ✅
Kubernetes monitors Plex connectivity:
```yaml
readinessProbe:
  httpGet:
    path: /identity
    port: 32400
  failureThreshold: 3
```

**Why this works:**
- Pod marked "not ready" if /identity endpoint fails
- Kubernetes won't route traffic to unhealthy pods
- Auto-restarts pod if liveness probe fails
- Visible in `kubectl get pods -n media` status

#### Layer 3: InitContainer (Best-Effort) ✅
Attempts to fix NFS ownership issues:
```yaml
initContainers:
- name: fix-permissions
  command: ["chown", "-R", "1000:1000", "/config/plex"]
  securityContext:
    runAsUser: 0
```

**Why this is best-effort:**
- NFS mounts may have restrictive permissions
- Some NFS exports don't allow ownership changes from clients
- linuxserver/plex image handles permissions via PUID/PGID as fallback

#### Layer 4: ArgoCD GitOps ✅
All configuration is version-controlled:
- Changes committed to Git: `apps/media/base/plex.yaml`
- ArgoCD auto-syncs every 3 minutes
- Self-healing enabled: reverts manual changes
- Audit trail of all modifications

---

## Permanent NFS Ownership Fix (Optional)

If you want to eliminate NFS ownership warnings entirely:

### On NFS Server (10.69.1.163):

1. **Check current export configuration:**
   ```bash
   cat /etc/exports
   # Should show something like:
   # /mnt/media 10.69.1.0/24(rw,sync,no_subtree_check,no_root_squash)
   ```

2. **Verify directory ownership:**
   ```bash
   ls -ln /mnt/media/configs/plex
   # Look for UID/GID (should be 1000:1000 ideally)
   ```

3. **Fix ownership on NFS server (if needed):**
   ```bash
   sudo chown -R 1000:1000 /mnt/media/configs/plex
   sudo chmod -R 755 /mnt/media/configs/plex
   ```

4. **Ensure NFS export allows ownership changes:**
   ```bash
   # In /etc/exports, ensure these options:
   /mnt/media 10.69.1.0/24(rw,sync,no_subtree_check,no_root_squash,all_squash,anonuid=1000,anongid=1000)

   # Apply changes:
   sudo exportfs -ra
   ```

**Explanation:**
- `no_root_squash`: Allows root in containers to change ownership
- `all_squash,anonuid=1000,anongid=1000`: Maps all NFS clients to UID/GID 1000
- This ensures consistent ownership across all pods

---

## Monitoring and Alerts

### Manual Health Check:
```bash
# Test local Plex access
curl http://10.69.1.165:32400/identity

# Check Plex pod health
kubectl get pods -n media -l app=plex

# View Plex logs for errors
kubectl logs -n media -l app=plex --tail=50 | grep -iE "(error|failed|warning)"

# Verify environment variables are applied
kubectl exec -n media deployment/plex -- env | grep PLEX
```

### Expected Output:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<MediaContainer size="0" apiVersion="1.1.1" claimed="1"
  machineIdentifier="..." version="1.42.2...">
</MediaContainer>
```

### Automated Monitoring (Future Enhancement):
Consider adding Prometheus alerts:
```yaml
- alert: PlexDown
  expr: kube_pod_status_ready{namespace="media",pod=~"plex-.*"} == 0
  for: 5m
  annotations:
    summary: "Plex pod not ready for 5+ minutes"
```

---

## Recovery Procedures

### If Plex becomes inaccessible from app.plex.tv:

1. **Check pod status:**
   ```bash
   kubectl get pods -n media -l app=plex
   # If not "Running" or "Ready", check events
   ```

2. **Verify environment variables:**
   ```bash
   kubectl exec -n media deployment/plex -- env | grep -E "(PLEX_PREFERENCE|ADVERTISE)"
   ```

3. **Force pod restart:**
   ```bash
   kubectl delete pod -n media -l app=plex
   # ArgoCD will recreate with correct config
   ```

4. **Check Preferences.xml:**
   ```bash
   kubectl exec -n media deployment/plex -- cat "/config/Library/Application Support/Plex Media Server/Preferences.xml" | grep -oE '(secureConnections|customConnections)="[^"]*"'
   ```

5. **If still failing, trigger ArgoCD sync:**
   ```bash
   kubectl patch application media-stack -n argocd --type merge -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```

---

## Why This Won't Happen Again

### Previous Approach (Fragile):
- ❌ Manually edited Preferences.xml via initContainer
- ❌ Settings could be overwritten by Plex UI changes
- ❌ No health monitoring
- ❌ No automated recovery

### Current Approach (Robust):
- ✅ **Environment variables**: Plex native configuration, cannot be lost
- ✅ **Health probes**: Auto-detection and recovery
- ✅ **GitOps**: Configuration as code, version-controlled
- ✅ **Auto-healing**: ArgoCD reverts drift automatically
- ✅ **Multi-layer defense**: 4 independent protection mechanisms

### What Could Still Go Wrong:

1. **LoadBalancer IP changes** → Solution: Update Git, ArgoCD syncs automatically
2. **NFS server offline** → Solution: Health probe detects, prevents traffic routing
3. **Plex updates break compatibility** → Solution: Pin image version, test updates in staging
4. **Manual kubectl edit** → Solution: ArgoCD reverts within 3 minutes

---

## Testing the Protection

### Test 1: Pod Restart
```bash
kubectl delete pod -n media -l app=plex
# Wait 60 seconds
kubectl exec -n media deployment/plex -- env | grep PLEX_PREFERENCE
# Should show all 4 preferences
```

### Test 2: Manual Configuration Drift
```bash
kubectl set env deployment/plex PLEX_PREFERENCE_3=secureConnections=0 -n media
# Wait 3 minutes for ArgoCD sync
kubectl get deployment plex -n media -o yaml | grep PLEX_PREFERENCE_3
# Should be reset to "secureConnections=1"
```

### Test 3: Health Probe Detection
```bash
# Simulate Plex failure (breaks identity endpoint)
kubectl exec -n media deployment/plex -- killall "Plex Media Server"
# Wait 30 seconds
kubectl get pods -n media -l app=plex
# Should show "Not Ready" or restarting
```

---

## References

- **Plex Environment Variables**: https://github.com/linuxserver/docker-plex#parameters
- **Kubernetes Health Probes**: https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/
- **ArgoCD Auto-Sync**: https://argo-cd.readthedocs.io/en/stable/user-guide/auto_sync/
- **NFS Export Options**: https://linux.die.net/man/5/exports

---

## Changelog

- **2025-10-06**: Initial version - documented multi-layer prevention strategy
- **2025-10-06**: Added health probes and native environment variables
- **2025-10-06**: Removed XML manipulation in favor of Plex-native configuration
