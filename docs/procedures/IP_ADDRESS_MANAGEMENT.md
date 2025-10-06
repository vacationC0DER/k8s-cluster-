# IP Address Management Strategy

## Overview

This document describes the best practices for managing IP addresses across the Talos Kubernetes cluster infrastructure.

**Design Philosophy:** Single source of truth, version-controlled, programmatically accessible, human-readable.

---

## Architecture: 3-Layer Approach

### Layer 1: Git-Tracked Inventory (Source of Truth)
**File:** `infrastructure/network-inventory.yaml`

- ✅ **Version-controlled** in Git (full audit trail)
- ✅ **Human-readable** YAML format
- ✅ **Machine-parseable** for automation
- ✅ **ArgoCD-managed** (auto-syncs to cluster)
- ✅ **Single source of truth** for all IP addresses

### Layer 2: Kubernetes ConfigMaps (Runtime Access)
**ConfigMaps:**
- `network-inventory` (namespace: kube-system) - Cluster-wide IPs
- `media-stack-network` (namespace: media) - Media stack IPs

- ✅ **Programmatic access** from pods via environment variables
- ✅ **Service discovery** alternative to hardcoded IPs
- ✅ **Hot-reloadable** (some apps support ConfigMap updates without restart)

### Layer 3: Documentation (Human Reference)
**Files:**
- `CLAUDE.md` - High-level network overview
- `README.md` - Quick reference
- This file - Detailed management procedures

- ✅ **Searchable** for quick lookups
- ✅ **Context-rich** with explanations
- ✅ **Updated automatically** from Layer 1 (via scripts/CI)

---

## IP Address Allocation

### Reserved Ranges

| Range | Purpose | Count | Status |
|-------|---------|-------|--------|
| 10.69.1.1 | Default gateway | 1 | Static |
| 10.69.1.101-103 | Control plane nodes | 3 | Static |
| 10.69.1.104-106 | Worker nodes (planned) | 3 | Reserved |
| 10.69.1.140-197 | Worker nodes (current) | 5 | Static |
| 10.69.1.150-160 | MetalLB LoadBalancer pool | 11 | Dynamic |
| 10.69.1.163 | NFS server | 1 | Static |
| 10.69.1.167 | Management workstation | 1 | Static |
| 10.69.1.180 | Proxmox server | 1 | Static |

### LoadBalancer IP Assignments

| Service | IP | Port | Status |
|---------|-----|------|--------|
| ingress-nginx | 10.69.1.150 | 80,443 | Active |
| radarr | 10.69.1.151 | 7878 | Active |
| sonarr | 10.69.1.152 | 8989 | Active |
| prowlarr | 10.69.1.153 | 9696 | Active |
| qbittorrent | 10.69.1.154 | 8080 | Active |
| argocd-server | 10.69.1.162 | 80,443 | Active |
| plex | 10.69.1.165 | 32400 | Active |
| *Available* | 10.69.1.155-161 | - | Reserved |
| *Available* | 10.69.1.163-164 | - | Reserved |
| *Available* | 10.69.1.166-160 | - | Reserved |

---

## Usage Examples

### Example 1: Reference ConfigMap in Pod Environment Variables

**Option A: Single Value Reference**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: plex
  namespace: media
spec:
  template:
    spec:
      containers:
      - name: plex
        env:
        - name: ADVERTISE_IP
          valueFrom:
            configMapKeyRef:
              name: media-stack-network
              key: plex.external-url
        - name: PLEX_PREFERENCE_4
          valueFrom:
            configMapKeyRef:
              name: media-stack-network
              key: plex.external-url
```

**Option B: Mount Entire ConfigMap as Environment Variables**
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: example-app
  namespace: media
spec:
  template:
    spec:
      containers:
      - name: app
        envFrom:
        - configMapRef:
            name: media-stack-network
            prefix: NETWORK_
        # Creates environment variables like:
        # NETWORK_plex.external-ip=10.69.1.165
        # NETWORK_plex.external-url=http://10.69.1.165:32400
```

### Example 2: Reference ConfigMap in Service LoadBalancer

**Current Approach (Hardcoded):**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: plex
  namespace: media
spec:
  type: LoadBalancer
  loadBalancerIP: 10.69.1.165  # Hardcoded
```

**Alternative Approach (ConfigMap + Kustomize):**

Create `kustomization.yaml`:
```yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

resources:
  - plex.yaml

configMapGenerator:
  - name: media-stack-network
    behavior: merge

replacements:
  - source:
      kind: ConfigMap
      name: media-stack-network
      fieldPath: data.plex\.external-ip
    targets:
      - select:
          kind: Service
          name: plex
        fieldPaths:
          - spec.loadBalancerIP
```

Then in `plex.yaml`:
```yaml
apiVersion: v1
kind: Service
metadata:
  name: plex
  namespace: media
spec:
  type: LoadBalancer
  loadBalancerIP: PLACEHOLDER  # Replaced by Kustomize
```

**Note:** The current hardcoded approach is acceptable for static IPs. Use Kustomize replacements only if IPs change frequently.

### Example 3: Query ConfigMap from kubectl

```bash
# Get all network IPs
kubectl get configmap network-inventory -n kube-system -o yaml

# Get specific IP
kubectl get configmap network-inventory -n kube-system -o jsonpath='{.data.loadbalancer\.plex\.ip}'
# Output: 10.69.1.165

# Get media stack URLs
kubectl get configmap media-stack-network -n media -o jsonpath='{.data.plex\.external-url}'
# Output: http://10.69.1.165:32400
```

### Example 4: Use in Shell Scripts

```bash
#!/bin/bash
# Get Plex IP from ConfigMap
PLEX_IP=$(kubectl get configmap network-inventory -n kube-system -o jsonpath='{.data.loadbalancer\.plex\.ip}')

# Test connectivity
curl -s "http://${PLEX_IP}:32400/identity"
```

---

## Workflow: Changing IP Addresses

### Scenario 1: Changing a LoadBalancer IP (e.g., Plex)

**Steps:**

1. **Update source of truth:**
   ```bash
   cd /Users/stevenbrown/Development/k8_cluster
   vim infrastructure/network-inventory.yaml

   # Change:
   loadbalancer.plex.ip: "10.69.1.165"
   # To:
   loadbalancer.plex.ip: "10.69.1.170"

   # Also update media-stack-network ConfigMap:
   plex.external-ip: "10.69.1.170"
   plex.external-url: "http://10.69.1.170:32400"
   ```

2. **Update service definition:**
   ```bash
   vim apps/media/base/plex.yaml

   # Change:
   spec:
     loadBalancerIP: 10.69.1.165
   # To:
   spec:
     loadBalancerIP: 10.69.1.170
   ```

3. **Update environment variables in deployment:**
   ```bash
   vim apps/media/base/plex.yaml

   # Change:
   - name: PLEX_PREFERENCE_4
     value: "customConnections=http://10.69.1.165:32400"
   - name: ADVERTISE_IP
     value: "http://10.69.1.165:32400"
   # To:
   - name: PLEX_PREFERENCE_4
     value: "customConnections=http://10.69.1.170:32400"
   - name: ADVERTISE_IP
     value: "http://10.69.1.170:32400"
   ```

4. **Commit and push to Git:**
   ```bash
   git add infrastructure/network-inventory.yaml apps/media/base/plex.yaml
   git commit -m "[update] Change Plex LoadBalancer IP to 10.69.1.170"
   git push origin main
   ```

5. **ArgoCD auto-syncs within 3 minutes** (or force sync):
   ```bash
   kubectl patch application media-stack -n argocd --type merge \
     -p '{"metadata":{"annotations":{"argocd.argoproj.io/refresh":"hard"}}}'
   ```

6. **Verify:**
   ```bash
   # Check service
   kubectl get svc plex -n media

   # Check ConfigMap
   kubectl get configmap media-stack-network -n media -o yaml | grep plex.external-ip

   # Test connectivity
   curl http://10.69.1.170:32400/identity
   ```

### Scenario 2: Adding a New LoadBalancer Service

**Example: Add Lidarr with LoadBalancer IP 10.69.1.155**

1. **Reserve IP in network-inventory.yaml:**
   ```yaml
   loadbalancer.lidarr.ip: "10.69.1.155"
   ```

2. **Add to media-stack-network ConfigMap:**
   ```yaml
   lidarr.external-ip: "10.69.1.155"
   lidarr.external-url: "http://10.69.1.155:8686"
   lidarr.internal-url: "http://lidarr.media.svc.cluster.local:8686"
   ```

3. **Create service with LoadBalancer:**
   ```yaml
   apiVersion: v1
   kind: Service
   metadata:
     name: lidarr
     namespace: media
   spec:
     type: LoadBalancer
     loadBalancerIP: 10.69.1.155
     selector:
       app: lidarr
     ports:
     - port: 8686
       targetPort: 8686
   ```

4. **Commit, push, and sync via ArgoCD**

### Scenario 3: Changing NFS Server IP

**Critical: Affects all pods using NFS storage**

1. **Update network-inventory.yaml:**
   ```yaml
   nfs.server.ip: "10.69.1.200"  # New IP
   ```

2. **Update media-stack-network ConfigMap:**
   ```yaml
   nfs.server: "10.69.1.200"
   ```

3. **Update PersistentVolume definitions:**
   ```bash
   # Find all PVs using NFS
   kubectl get pv -o yaml | grep "10.69.1.163"

   # Update each PV (or recreate with new IP)
   kubectl patch pv <pv-name> -p '{"spec":{"nfs":{"server":"10.69.1.200"}}}'
   ```

4. **Restart pods to mount new NFS server:**
   ```bash
   kubectl rollout restart deployment -n media
   ```

---

## Best Practices

### ✅ DO

1. **Always update `infrastructure/network-inventory.yaml` first**
   - This is the single source of truth
   - All other files reference this

2. **Use ConfigMaps for service discovery**
   - Reference ConfigMaps in environment variables
   - Avoids hardcoded IPs in multiple places

3. **Document IP changes in CHANGELOG.md**
   - Include reason for change
   - Document impact and downtime

4. **Test connectivity after IP changes**
   - Verify LoadBalancer IPs assigned correctly
   - Test external access from outside cluster
   - Check internal service discovery

5. **Use descriptive comments**
   - Explain why specific IPs are chosen
   - Note dependencies and conflicts

### ❌ DON'T

1. **Don't hardcode IPs in multiple files**
   - Update `network-inventory.yaml` → Let Kustomize/ArgoCD propagate
   - If hardcoding is necessary, add comment pointing to network-inventory.yaml

2. **Don't skip Git commits for IP changes**
   - Every IP change must be version-controlled
   - Include descriptive commit messages

3. **Don't change IPs during peak usage**
   - Schedule changes during maintenance windows
   - Communicate downtime to users

4. **Don't reuse IPs immediately**
   - Wait 24 hours before reassigning IPs
   - Prevents DNS caching issues

5. **Don't forget to update documentation**
   - Update CLAUDE.md with major changes
   - Update README.md quick reference
   - Update CHANGELOG.md

---

## Automation Opportunities

### Future Enhancements

1. **IP Conflict Detection Script**
   ```bash
   #!/bin/bash
   # Check for duplicate IP assignments in network-inventory.yaml
   grep -oE '([0-9]{1,3}\.){3}[0-9]{1,3}' infrastructure/network-inventory.yaml | sort | uniq -d
   ```

2. **IP Availability Checker**
   ```bash
   #!/bin/bash
   # Find next available LoadBalancer IP
   USED=$(kubectl get svc -A -o jsonpath='{.items[*].spec.loadBalancerIP}')
   # Compare with MetalLB pool range
   ```

3. **ConfigMap Generator from Inventory**
   - Parse `network-inventory.yaml`
   - Auto-generate namespace-specific ConfigMaps
   - Run as pre-commit hook

4. **DNS Sync Script**
   - Update local `/etc/hosts` from network-inventory.yaml
   - Sync with DNS server (if using CoreDNS customization)

---

## Troubleshooting

### Issue: LoadBalancer IP Not Assigned

**Symptoms:**
```bash
kubectl get svc plex -n media
# Shows: EXTERNAL-IP <pending>
```

**Diagnosis:**
```bash
# Check MetalLB controller
kubectl get pods -n metallb-system

# Check MetalLB IP pool
kubectl get ipaddresspool -n metallb-system

# Check service events
kubectl describe svc plex -n media
```

**Common Causes:**
1. IP outside MetalLB pool range
2. IP already assigned to another service
3. MetalLB controller not running

**Resolution:**
```bash
# Verify IP is in pool range (10.69.1.150-160)
# Check for conflicts:
kubectl get svc -A -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.loadBalancerIP}{"\n"}{end}' | grep "10.69.1.165"

# If conflict found, change IP in network-inventory.yaml and service definition
```

### Issue: ConfigMap Not Found

**Symptoms:**
```bash
kubectl get configmap network-inventory -n kube-system
# Error: configmap "network-inventory" not found
```

**Resolution:**
```bash
# Apply ConfigMap from infrastructure directory
kubectl apply -f infrastructure/network-inventory.yaml

# Or apply via Kustomize
kubectl apply -k infrastructure/
```

---

## References

- **Network Inventory:** `infrastructure/network-inventory.yaml`
- **Kubernetes ConfigMaps:** https://kubernetes.io/docs/concepts/configuration/configmap/
- **Kustomize Replacements:** https://kubectl.docs.kubernetes.io/references/kustomize/kustomization/replacements/
- **MetalLB Configuration:** https://metallb.universe.tf/configuration/
- **Service Discovery:** https://kubernetes.io/docs/concepts/services-networking/service/

---

## Changelog

- **2025-10-06**: Initial version - defined 3-layer IP management strategy
- **2025-10-06**: Created network-inventory.yaml ConfigMaps
- **2025-10-06**: Documented workflows and best practices
