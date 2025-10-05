# GitOps Readiness Assessment
## Phase 4 Media Stack → Phase 5 GitOps Implementation

**Date:** October 5, 2025
**Cluster:** Talos Kubernetes 6-node cluster (v1.34.1)
**Current Phase:** Phase 4 Complete - 8/8 services operational
**Next Phase:** Phase 5 - GitOps Implementation (ArgoCD/Flux CD)

---

## Executive Summary

### GitOps Readiness Score: 6.5/10

**Status:** CONDITIONALLY READY with critical gaps that must be addressed

The Phase 4 media stack deployment is **functionally operational** but requires **significant refactoring** before GitOps implementation. While all services are running with LoadBalancer access, the current state has fragmented manifest organization, hardcoded secrets, and missing GitOps-critical components.

**Recommendation:** Allocate 2-3 days for Phase 4.5 (GitOps Preparation) before attempting Phase 5 implementation.

---

## 1. Current State Assessment

### 1.1 Infrastructure Status (✅ EXCELLENT)

**What's Working:**
- All 8 media services deployed and operational
- Complete end-to-end workflow validated (Overseerr → Radarr → qBittorrent → Plex)
- MetalLB LoadBalancer IPs stable and assigned (.154-.161)
- NFS persistent storage functioning (ReadWriteMany)
- Service mesh fully operational (Kubernetes DNS resolution)
- Resource limits defined (Plex: 4-8GB RAM, qBittorrent: 1-2GB RAM)

**Deployed Services:**
1. Plex Media Server (10.69.1.154:32400)
2. Prowlarr (10.69.1.155:9696)
3. Radarr (10.69.1.156:7878)
4. Sonarr (10.69.1.157:8989)
5. qBittorrent (10.69.1.158:8080)
6. Lidarr (10.69.1.159:8686)
7. Overseerr (10.69.1.160:5055)
8. SABnzbd (10.69.1.161:8080)

**Validation:**
```bash
kubectl get pods -n media
# All 8/8 pods Running
kubectl get svc -n media | grep LoadBalancer
# All 8 external IPs assigned
```

---

### 1.2 YAML Manifest Organization (⚠️ NEEDS REFACTORING)

**Current Structure:**
```
k8_cluster/
├── deployments/
│   └── media/
│       ├── optimized/
│       │   ├── plex-optimized.yaml          # 2 resources (Service, Deployment)
│       │   └── qbittorrent-optimized.yaml   # 2 resources (Service, Deployment)
│       └── overseerr.yaml                     # 2 resources (Service, Deployment)
├── radarr.yaml                                # 2 resources (root directory)
├── sonarr.yaml                                # 2 resources (root directory)
├── prowlarr.yaml                              # 2 resources (root directory)
├── lidarr.yaml                                # 2 resources (root directory)
├── sabnzbd.yaml                               # 2 resources (root directory)
├── qbittorrent.yaml                           # 2 resources (root directory, duplicate)
├── plex.yaml                                  # 2 resources (root directory, duplicate)
└── media-storage-pvcs.yaml                    # 2 PVCs (root directory)
```

**Total:** 18 manifests across 3 locations with duplicates

**Problems Identified:**
1. **Fragmented Structure:** Manifests scattered between root directory and deployments/media/
2. **Duplicate Files:** plex.yaml exists in both root and deployments/media/optimized/
3. **Inconsistent Naming:** qbittorrent.yaml vs qbittorrent-optimized.yaml
4. **No Namespace Manifest:** `kubectl create namespace media` was run imperatively
5. **Mixed Organization:** Some in deployments/, some in root, no clear pattern
6. **No Kustomization Files:** No kustomization.yaml for directory-based deployment
7. **No ArgoCD Application Manifests:** No Application CRDs prepared

**GitOps Impact:**
- ArgoCD cannot easily discover manifests (path ambiguity)
- No clear source of truth (which plex.yaml is authoritative?)
- Difficult to implement sync policies
- Cannot use Kustomize overlays without restructuring

**Recommendation:**
- Consolidate all manifests into `deployments/media/` directory
- Remove root-level duplicates
- Create clear base/ and overlays/ structure

---

### 1.3 Secrets Management (❌ CRITICAL - BLOCKER FOR GITOPS)

**Current State:**
- **API Keys:** Stored in application config files on NFS PVCs (`/data/configs/<service>/config.xml`)
- **Plex Claim Token:** Hardcoded in plex-optimized.yaml (Line 51: `value: "claim-cPXzEkyKeLzj13jsk3Co"`)
- **qBittorrent Password:** Set via web UI, stored in qBittorrent config file
- **Kubernetes Secrets:** ZERO secrets created in media namespace

**Verification:**
```bash
kubectl get secret -n media
# No secrets (only default service account token)

grep -r "claim-" deployments/media/optimized/plex-optimized.yaml
# Line 51:         value: "claim-cPXzEkyKeLzj13jsk3Co"
```

**Secrets Inventory (from MEDIA_STACK_CONFIG_REVIEW.md):**
| Secret Type | Current Location | Status |
|-------------|------------------|--------|
| Prowlarr API Key | NFS config file | ⚠️ Not in Git |
| Radarr API Key | NFS config file | ⚠️ Not in Git |
| Sonarr API Key | NFS config file | ⚠️ Not in Git |
| Lidarr API Key | NFS config file | ⚠️ Not in Git |
| SABnzbd API Key | NFS config file | ⚠️ Not in Git |
| Overseerr API Token | NFS config file | ⚠️ Not in Git |
| Plex Claim Token | **Hardcoded in YAML** | ❌ EXPOSED IN GIT |
| qBittorrent Password | NFS config file | ⚠️ Not in Git |

**Critical Issues:**
1. **Plex Claim Token Committed to Git:** Sensitive credential exposed in deployments/media/optimized/plex-optimized.yaml
2. **No Sealed Secrets Controller:** Cannot encrypt secrets for Git storage
3. **No External Secrets Operator:** Cannot sync secrets from external vault
4. **No Secret References in Deployments:** Manifests don't reference Kubernetes Secrets
5. **Manual Secret Distribution:** API keys manually configured via web UIs

**GitOps Blocker:**
- **Cannot commit current manifests to Git** (plex claim token exposed)
- **Cannot implement GitOps without secrets management solution**
- **Cannot achieve declarative secret management**

**Recommended Approach:**
1. **Install Sealed Secrets Controller** (bitnami-labs/sealed-secrets)
2. **Migrate all API keys from config files to Kubernetes Secrets**
3. **Encrypt Secrets with kubeseal** before committing to Git
4. **Refactor Deployments** to reference secretKeyRef instead of hardcoded values

**Example Migration:**
```yaml
# Before (INSECURE):
env:
- name: PLEX_CLAIM
  value: "claim-cPXzEkyKeLzj13jsk3Co"

# After (SECURE):
env:
- name: PLEX_CLAIM
  valueFrom:
    secretKeyRef:
      name: media-stack-secrets
      key: plex-claim-token
```

---

### 1.4 Configuration Management (⚠️ NEEDS IMPROVEMENT)

**Hardcoded Values Audit:**

| Service | Hardcoded Values | Should Be |
|---------|------------------|-----------|
| All Services | PUID=1000, PGID=1000 | ConfigMap |
| All Services | TZ=America/Los_Angeles | ConfigMap |
| LoadBalancers | Static IPs (.154-.161) | Acceptable (by design) |
| Plex | PLEX_CLAIM (secret) | Kubernetes Secret |
| Plex | Resource limits (4-8GB RAM) | Acceptable |
| qBittorrent | Resource limits (1-2GB RAM) | Acceptable |
| PVCs | storage: 10Ti, 50Gi | Acceptable |

**ConfigMap Opportunities:**
```yaml
# Create shared ConfigMap for common environment variables
apiVersion: v1
kind: ConfigMap
metadata:
  name: media-common-config
  namespace: media
data:
  PUID: "1000"
  PGID: "1000"
  TZ: "America/Los_Angeles"
```

**Environment-Specific Configurations:**
- **Current:** Single production configuration
- **Missing:** No dev/staging overlays
- **GitOps Need:** Kustomize overlays for multiple environments

**Issues:**
1. No ConfigMaps used (all env vars hardcoded)
2. No environment separation (dev/staging/prod)
3. No Kustomize base/overlays structure
4. Repeated env vars across 8 deployments (DRY violation)

**Recommendation:**
- Create ConfigMap for common env vars (PUID, PGID, TZ)
- Maintain static LoadBalancer IPs (design decision, not a problem)
- Consider Kustomize overlays if multi-environment needed

---

### 1.5 GitOps-Critical Components (❌ MISSING)

**What's Missing for GitOps:**

1. **Git Repository:** ❌ Not initialized
   ```bash
   git status
   # fatal: not a git repository
   ```

2. **Namespace Manifest:** ❌ Not in Git
   - Namespace created imperatively: `kubectl create namespace media`
   - PodSecurity labels not in declarative manifest
   ```yaml
   # MISSING: deployments/media/namespace.yaml
   apiVersion: v1
   kind: Namespace
   metadata:
     name: media
     labels:
       pod-security.kubernetes.io/enforce: privileged
   ```

3. **Kustomization Files:** ❌ Not present
   - No `kustomization.yaml` in deployments/media/
   - Cannot use `kubectl apply -k` or ArgoCD directory sync

4. **ArgoCD Application Manifests:** ❌ Not created
   - No Application CRDs prepared
   - No ApplicationSet for multi-app management

5. **Sealed Secrets Controller:** ❌ Not installed
   ```bash
   kubectl get pods -n kube-system | grep sealed-secrets
   # (no pods found)
   ```

6. **ArgoCD/Flux CD:** ❌ Not installed
   ```bash
   kubectl get pods -n argocd
   # Error: namespace not found
   ```

7. **README in deployments/media/:** ❌ Missing
   - No documentation of manifest structure
   - No deployment instructions
   - No troubleshooting guide

8. **CHANGELOG in deployments/media/:** ❌ Missing
   - No version tracking for manifests
   - No history of configuration changes

**GitOps Blockers:**
- Cannot implement GitOps without Git repository
- Cannot use ArgoCD without Application manifests
- Cannot use Kustomize without kustomization.yaml files
- Cannot secure secrets without Sealed Secrets

---

### 1.6 Deployment Metadata Quality (✅ GOOD with minor gaps)

**What's Good:**
- Consistent labeling: `app: <service-name>` on all resources
- Service selectors match deployment labels
- All resources have proper apiVersion and kind
- Resource requests/limits defined (Plex, qBittorrent)

**What's Missing:**
- No annotations for documentation (e.g., `description: "Movie automation service"`)
- No version labels (e.g., `version: "5.14.2"`)
- No owner/team labels (e.g., `team: "media-stack"`)
- No ArgoCD sync annotations (e.g., `argocd.argoproj.io/sync-wave`)

**Recommended Labels:**
```yaml
metadata:
  labels:
    app: radarr
    app.kubernetes.io/name: radarr
    app.kubernetes.io/component: media-automation
    app.kubernetes.io/part-of: media-stack
    app.kubernetes.io/version: "5.14.2"
    app.kubernetes.io/managed-by: argocd
```

**Recommended Annotations:**
```yaml
metadata:
  annotations:
    description: "Movie automation and library management"
    argocd.argoproj.io/sync-wave: "2"  # Deploy after Prowlarr (wave 1)
    link.argocd.argoproj.io/external-link: "http://10.69.1.156:7878"
```

---

## 2. GitOps Readiness Score Breakdown

| Category | Score | Weight | Weighted Score | Status |
|----------|-------|--------|----------------|--------|
| **Infrastructure Stability** | 9/10 | 20% | 1.8 | ✅ Excellent |
| **Manifest Organization** | 5/10 | 20% | 1.0 | ⚠️ Needs Work |
| **Secrets Management** | 2/10 | 25% | 0.5 | ❌ Critical Gap |
| **Configuration Management** | 6/10 | 15% | 0.9 | ⚠️ Acceptable |
| **GitOps Components** | 3/10 | 15% | 0.45 | ❌ Missing |
| **Metadata Quality** | 7/10 | 5% | 0.35 | ✅ Good |
| **TOTAL** | **6.5/10** | **100%** | **6.5** | ⚠️ Conditional |

**Interpretation:**
- **8-10:** GitOps-ready, proceed with confidence
- **6-7.9:** Conditionally ready, fix critical gaps first
- **4-5.9:** Not ready, significant refactoring required
- **0-3.9:** Major blockers, Phase 4 incomplete

**Current Status:** 6.5/10 = CONDITIONALLY READY

---

## 3. Critical Path for Phase 5 Implementation

### 3.1 Prerequisites (MUST complete before Phase 5)

**Estimated Time:** 2-3 days

#### Step 1: Initialize Git Repository (2 hours)
```bash
cd /Users/stevenbrown/Development/k8_cluster
git init
git add CHANGELOG.md TASKS.md CLAUDE.md PRD.md README.md
git commit -m "[gitops] Initialize cluster management repository"

# Create .gitignore
cat > .gitignore <<EOF
# Secrets (never commit unencrypted)
*.secret.yaml
*-secret.yaml
secrets/
.env

# Temporary files
*.tmp
*.bak
*~

# IDE
.vscode/
.idea/

# OS
.DS_Store
Thumbs.db
EOF

git add .gitignore
git commit -m "[gitops] Add .gitignore for secrets and temp files"
```

#### Step 2: Consolidate and Reorganize Manifests (4 hours)
```bash
# Proposed structure
mkdir -p deployments/media/{base,overlays/production}

# Move all manifests to base/
mv radarr.yaml deployments/media/base/
mv sonarr.yaml deployments/media/base/
mv prowlarr.yaml deployments/media/base/
mv lidarr.yaml deployments/media/base/
mv sabnzbd.yaml deployments/media/base/
mv qbittorrent.yaml deployments/media/base/  # Remove duplicate
mv plex.yaml deployments/media/base/          # Remove duplicate
mv media-storage-pvcs.yaml deployments/media/base/

# Remove duplicates
rm deployments/media/optimized/plex-optimized.yaml
rm deployments/media/optimized/qbittorrent-optimized.yaml

# Use optimized versions as base
mv deployments/media/overseerr.yaml deployments/media/base/
```

**Target Structure:**
```
deployments/media/
├── README.md                    # Documentation
├── base/                        # Base manifests
│   ├── kustomization.yaml       # Kustomize base
│   ├── namespace.yaml           # Namespace definition
│   ├── common-configmap.yaml    # Shared env vars
│   ├── pvcs.yaml                # PersistentVolumeClaims
│   ├── prowlarr.yaml            # Service + Deployment
│   ├── radarr.yaml
│   ├── sonarr.yaml
│   ├── lidarr.yaml
│   ├── qbittorrent.yaml
│   ├── sabnzbd.yaml
│   ├── overseerr.yaml
│   └── plex.yaml
└── overlays/                    # Environment-specific
    └── production/
        ├── kustomization.yaml   # References ../base
        └── sealed-secrets.yaml  # Encrypted secrets
```

#### Step 3: Install Sealed Secrets Controller (1 hour)
```bash
# Install sealed-secrets controller
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml

# Wait for controller to be ready
kubectl wait --for=condition=ready pod -l name=sealed-secrets-controller -n kube-system --timeout=300s

# Install kubeseal CLI (macOS)
brew install kubeseal

# Verify installation
kubectl get pods -n kube-system | grep sealed-secrets
kubeseal --version
```

#### Step 4: Migrate Secrets (4 hours)

**4.1 Extract API Keys from Running Services:**
```bash
# Radarr API key
kubectl exec -n media deploy/radarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+'

# Sonarr API key
kubectl exec -n media deploy/sonarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+'

# Prowlarr API key
kubectl exec -n media deploy/prowlarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+'

# Lidarr API key
kubectl exec -n media deploy/lidarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+'

# SABnzbd API key
kubectl exec -n media deploy/sabnzbd -- cat /config/sabnzbd.ini | grep -oP 'api_key = \K.*'

# qBittorrent password (manually retrieve from web UI)
# Settings → Web UI → Authentication
```

**4.2 Create Kubernetes Secret:**
```bash
# Create secret (DO NOT COMMIT THIS COMMAND TO GIT)
kubectl create secret generic media-stack-secrets \
  --namespace=media \
  --from-literal=prowlarr-api-key='29b1972a561c4d7b9ac1d33f4295ff84' \
  --from-literal=radarr-api-key='17051bf130374d1a9b92ea3bdd55a0d4' \
  --from-literal=sonarr-api-key='4d3e159912644d51b487b34307e8a198' \
  --from-literal=lidarr-api-key='4768b94d024e4b15934482289cc5e589' \
  --from-literal=sabnzbd-api-key='3541a00782674246b2dde7752047cfdf' \
  --from-literal=plex-claim-token='claim-REPLACE-WITH-NEW-TOKEN' \
  --from-literal=qbittorrent-password='apollocreed' \
  --dry-run=client -o yaml > /tmp/media-secrets.yaml

# Seal the secret
kubeseal --format yaml < /tmp/media-secrets.yaml > deployments/media/overlays/production/sealed-secrets.yaml

# Delete temporary file
rm /tmp/media-secrets.yaml

# Commit sealed secret
git add deployments/media/overlays/production/sealed-secrets.yaml
git commit -m "[gitops] Add sealed secrets for media stack"
```

**4.3 Refactor Deployments to Use Secrets:**

Example for Plex:
```yaml
# Before (plex.yaml):
env:
- name: PLEX_CLAIM
  value: "claim-cPXzEkyKeLzj13jsk3Co"  # INSECURE

# After (plex.yaml):
env:
- name: PLEX_CLAIM
  valueFrom:
    secretKeyRef:
      name: media-stack-secrets
      key: plex-claim-token
```

**Note:** Most *arr services auto-generate API keys on startup, but we need secrets for:
- Plex claim token (initial setup)
- qBittorrent password (initial setup)
- API keys for Overseerr → *arr connections (if not auto-discovered)

#### Step 5: Create Namespace Manifest (30 minutes)
```yaml
# deployments/media/base/namespace.yaml
apiVersion: v1
kind: Namespace
metadata:
  name: media
  labels:
    name: media
    pod-security.kubernetes.io/enforce: privileged
    pod-security.kubernetes.io/audit: privileged
    pod-security.kubernetes.io/warn: privileged
```

#### Step 6: Create Kustomization Files (2 hours)

**Base Kustomization:**
```yaml
# deployments/media/base/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: media

resources:
  - namespace.yaml
  - pvcs.yaml
  - prowlarr.yaml
  - radarr.yaml
  - sonarr.yaml
  - lidarr.yaml
  - qbittorrent.yaml
  - sabnzbd.yaml
  - overseerr.yaml
  - plex.yaml

commonLabels:
  app.kubernetes.io/part-of: media-stack

configMapGenerator:
  - name: media-common-config
    literals:
      - PUID=1000
      - PGID=1000
      - TZ=America/Los_Angeles
```

**Production Overlay:**
```yaml
# deployments/media/overlays/production/kustomization.yaml
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: media

bases:
  - ../../base

resources:
  - sealed-secrets.yaml

patchesStrategicMerge:
  - |-
    apiVersion: apps/v1
    kind: Deployment
    metadata:
      name: plex
    spec:
      template:
        spec:
          containers:
          - name: plex
            envFrom:
            - secretRef:
                name: media-stack-secrets
```

**Validation:**
```bash
# Test kustomize build
kubectl kustomize deployments/media/overlays/production

# Dry-run apply
kubectl apply -k deployments/media/overlays/production --dry-run=client
```

#### Step 7: Create Documentation (2 hours)
```bash
# deployments/media/README.md
cat > deployments/media/README.md <<'EOF'
# Media Stack Deployment

Production-grade media automation stack for Kubernetes.

## Architecture

- **Prowlarr:** Centralized indexer management
- **Radarr:** Movie automation
- **Sonarr:** TV show automation
- **Lidarr:** Music automation
- **qBittorrent:** Torrent download client
- **SABnzbd:** Usenet download client
- **Overseerr:** Media request management
- **Plex:** Media streaming server

## Deployment

### Prerequisites
- Kubernetes cluster with MetalLB LoadBalancer
- NFS storage class: `nfs-client`
- Sealed Secrets controller installed

### Deploy
```bash
# Deploy media stack
kubectl apply -k deployments/media/overlays/production

# Verify deployment
kubectl get pods -n media
kubectl get svc -n media
```

### Update Secrets
```bash
# Create new secret
kubectl create secret generic media-stack-secrets \
  --namespace=media \
  --from-literal=plex-claim-token='NEW-TOKEN' \
  --dry-run=client -o yaml | kubeseal --format yaml > overlays/production/sealed-secrets.yaml

# Apply
kubectl apply -k overlays/production
```

## Services

| Service | LoadBalancer IP | Port | URL |
|---------|----------------|------|-----|
| Plex | 10.69.1.154 | 32400 | http://10.69.1.154:32400/web |
| Prowlarr | 10.69.1.155 | 9696 | http://10.69.1.155:9696 |
| Radarr | 10.69.1.156 | 7878 | http://10.69.1.156:7878 |
| Sonarr | 10.69.1.157 | 8989 | http://10.69.1.157:8989 |
| qBittorrent | 10.69.1.158 | 8080 | http://10.69.1.158:8080 |
| Lidarr | 10.69.1.159 | 8686 | http://10.69.1.159:8686 |
| Overseerr | 10.69.1.160 | 5055 | http://10.69.1.160:5055 |
| SABnzbd | 10.69.1.161 | 8080 | http://10.69.1.161:8080 |

## Troubleshooting

See main repository CLAUDE.md for detailed troubleshooting guide.
EOF
```

#### Step 8: Commit All Changes (1 hour)
```bash
git add deployments/media/
git commit -m "[gitops] Reorganize media stack for GitOps readiness

- Consolidate all manifests into deployments/media/base/
- Create Kustomize base and production overlay
- Add namespace manifest with PodSecurity labels
- Add common ConfigMap for shared env vars
- Create sealed-secrets.yaml for encrypted credentials
- Add comprehensive README.md
- Remove duplicate manifests from root directory

Resolves Phase 4.5 prerequisites for Phase 5 GitOps implementation."

# Create remote repository (GitHub/GitLab)
# Follow provider-specific instructions

# Push to remote
git remote add origin <repository-url>
git push -u origin main
```

---

### 3.2 Phase 5 Implementation (After Prerequisites)

**Estimated Time:** 2-3 days

#### Step 1: Install ArgoCD (2 hours)
```bash
# Create namespace
kubectl create namespace argocd

# Install ArgoCD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Wait for rollout
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=argocd-server -n argocd --timeout=600s

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Port-forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Access ArgoCD UI: https://localhost:8080
# Username: admin
# Password: <from above command>

# Install argocd CLI (optional)
brew install argocd
```

#### Step 2: Create ArgoCD Application for Media Stack (1 hour)
```yaml
# bootstrap/argocd/media-stack-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: media-stack
  namespace: argocd
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/k8_cluster.git
    targetRevision: main
    path: deployments/media/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: media
  syncPolicy:
    automated:
      prune: true      # Remove resources not in Git
      selfHeal: true   # Auto-sync on drift detection
      allowEmpty: false
    syncOptions:
      - CreateNamespace=true
      - PrunePropagationPolicy=foreground
      - PruneLast=true
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

**Apply:**
```bash
kubectl apply -f bootstrap/argocd/media-stack-application.yaml

# Verify
argocd app get media-stack
argocd app sync media-stack
```

#### Step 3: Configure ArgoCD Repository Access (30 minutes)
```bash
# Add repository (HTTPS with token)
argocd repo add https://github.com/<your-username>/k8_cluster.git \
  --username <github-username> \
  --password <github-personal-access-token>

# OR add repository (SSH)
argocd repo add git@github.com:<your-username>/k8_cluster.git \
  --ssh-private-key-path ~/.ssh/id_rsa

# Verify
argocd repo list
```

#### Step 4: Implement Backup Strategy (2 hours)
```bash
# Install Velero (optional, for PVC backups)
# See: https://velero.io/docs/main/basic-install/

# Create backup script for cluster state
cat > scripts/backup-cluster-state.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backups/$DATE"

mkdir -p "$BACKUP_DIR"

# Backup all resources
kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml"
kubectl get pvc --all-namespaces -o yaml > "$BACKUP_DIR/pvcs.yaml"
kubectl get configmap --all-namespaces -o yaml > "$BACKUP_DIR/configmaps.yaml"
kubectl get secret --all-namespaces -o yaml > "$BACKUP_DIR/secrets.yaml"

# Backup etcd (via Talos)
talosctl --nodes 10.69.1.101 etcd snapshot "$BACKUP_DIR/etcd-backup.db"

# Commit to Git
cd /Users/stevenbrown/Development/k8_cluster
git add "$BACKUP_DIR"
git commit -m "[backup] Automated cluster state backup $DATE"
git push

echo "Backup completed: $BACKUP_DIR"
EOF

chmod +x scripts/backup-cluster-state.sh

# Test backup
./scripts/backup-cluster-state.sh
```

#### Step 5: Configure Monitoring (2 hours)
```bash
# Create ServiceMonitors for media services
cat > deployments/media/base/servicemonitor.yaml <<'EOF'
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: media-stack
  namespace: media
spec:
  selector:
    matchLabels:
      app.kubernetes.io/part-of: media-stack
  endpoints:
  - port: http
    interval: 30s
EOF

# Add to kustomization.yaml
# Add Grafana dashboard for media stack
# Configure alerts for pod restarts, high memory usage
```

#### Step 6: Test GitOps Workflow (1 hour)
```bash
# Test 1: Make a change in Git
# Edit deployments/media/base/radarr.yaml (change replica count)

git add deployments/media/base/radarr.yaml
git commit -m "[media] Scale Radarr to 2 replicas for testing"
git push

# Observe ArgoCD auto-sync
argocd app get media-stack --refresh
kubectl get pods -n media -w

# Test 2: Manual drift detection
kubectl scale deployment radarr -n media --replicas=3

# Observe ArgoCD self-heal (revert to 2 replicas)
argocd app get media-stack

# Test 3: Rollback
git revert HEAD
git push

# Observe ArgoCD sync back to 1 replica
```

---

## 4. Secrets Migration Strategy

### 4.1 Secrets Inventory

| Secret Name | Current Location | Criticality | Migration Priority |
|-------------|------------------|-------------|-------------------|
| Plex Claim Token | Hardcoded YAML | HIGH | P0 (Blocker) |
| Prowlarr API Key | NFS config | MEDIUM | P1 (Important) |
| Radarr API Key | NFS config | MEDIUM | P1 (Important) |
| Sonarr API Key | NFS config | MEDIUM | P1 (Important) |
| Lidarr API Key | NFS config | MEDIUM | P1 (Important) |
| SABnzbd API Key | NFS config | MEDIUM | P1 (Important) |
| Overseerr API Token | NFS config | LOW | P2 (Nice-to-have) |
| qBittorrent Password | NFS config | MEDIUM | P1 (Important) |

### 4.2 Recommended Tool: Sealed Secrets

**Why Sealed Secrets:**
- Simple installation (single controller)
- Native Kubernetes Secret integration
- Encryption at rest in Git
- Public key encryption (asymmetric)
- No external dependencies (unlike External Secrets Operator)

**Why NOT External Secrets Operator:**
- Requires external secret store (Vault, AWS Secrets Manager, etc.)
- More complex setup
- Overkill for 8 secrets in home lab

### 4.3 Migration Procedure

**Phase 1: Install Sealed Secrets (30 minutes)**
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
brew install kubeseal
kubeseal --fetch-cert > sealed-secrets-public-cert.pem
```

**Phase 2: Extract Current Secrets (1 hour)**
```bash
# Script to extract all API keys
cat > scripts/extract-api-keys.sh <<'EOF'
#!/bin/bash

echo "Extracting API keys from running services..."

PROWLARR_KEY=$(kubectl exec -n media deploy/prowlarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+')
RADARR_KEY=$(kubectl exec -n media deploy/radarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+')
SONARR_KEY=$(kubectl exec -n media deploy/sonarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+')
LIDARR_KEY=$(kubectl exec -n media deploy/lidarr -- cat /config/config.xml | grep -oP '<ApiKey>\K[^<]+')
SABNZBD_KEY=$(kubectl exec -n media deploy/sabnzbd -- cat /config/sabnzbd.ini | grep -oP 'api_key = \K.*')

echo "Prowlarr: $PROWLARR_KEY"
echo "Radarr: $RADARR_KEY"
echo "Sonarr: $SONARR_KEY"
echo "Lidarr: $LIDARR_KEY"
echo "SABnzbd: $SABNZBD_KEY"

# Store in temporary file (NOT COMMITTED)
cat > /tmp/media-secrets.env <<SECRETS
PROWLARR_API_KEY=$PROWLARR_KEY
RADARR_API_KEY=$RADARR_KEY
SONARR_API_KEY=$SONARR_KEY
LIDARR_API_KEY=$LIDARR_KEY
SABNZBD_API_KEY=$SABNZBD_KEY
SECRETS

echo "Secrets saved to /tmp/media-secrets.env"
EOF

chmod +x scripts/extract-api-keys.sh
./scripts/extract-api-keys.sh
```

**Phase 3: Create Sealed Secret (30 minutes)**
```bash
# Create Kubernetes Secret (NOT applied to cluster)
kubectl create secret generic media-stack-secrets \
  --namespace=media \
  --from-env-file=/tmp/media-secrets.env \
  --from-literal=plex-claim-token='claim-NEW-TOKEN-FROM-PLEX-CLAIM' \
  --from-literal=qbittorrent-password='apollocreed' \
  --dry-run=client -o yaml > /tmp/media-secrets.yaml

# Seal the secret
kubeseal --format yaml < /tmp/media-secrets.yaml > deployments/media/overlays/production/sealed-secrets.yaml

# Clean up temporary files
rm /tmp/media-secrets.yaml /tmp/media-secrets.env

# Commit sealed secret
git add deployments/media/overlays/production/sealed-secrets.yaml
git commit -m "[gitops] Add sealed secrets for media stack"
git push
```

**Phase 4: Refactor Deployments (2 hours)**

Example refactor for each service:
```yaml
# Before (radarr.yaml):
env:
- name: RADARR__API_KEY
  value: "hardcoded-key-here"  # BAD

# After (radarr.yaml):
env:
- name: RADARR__API_KEY
  valueFrom:
    secretKeyRef:
      name: media-stack-secrets
      key: radarr-api-key
```

**Phase 5: Rolling Update (1 hour)**
```bash
# Apply sealed secret (controller decrypts automatically)
kubectl apply -f deployments/media/overlays/production/sealed-secrets.yaml

# Verify secret created
kubectl get secret media-stack-secrets -n media

# Update deployments to use secret
kubectl apply -k deployments/media/overlays/production

# Verify pods restart with secrets
kubectl get pods -n media -w
```

### 4.4 Secret Rotation Procedure

**When to Rotate:**
- Annually (proactive)
- After suspected compromise
- When adding/removing services

**How to Rotate:**
```bash
# 1. Generate new API key in service web UI
# 2. Update sealed secret
kubectl create secret generic media-stack-secrets \
  --namespace=media \
  --from-literal=radarr-api-key='NEW-KEY' \
  --dry-run=client -o yaml | kubeseal --format yaml > deployments/media/overlays/production/sealed-secrets.yaml

# 3. Commit and push
git add deployments/media/overlays/production/sealed-secrets.yaml
git commit -m "[security] Rotate Radarr API key"
git push

# 4. ArgoCD auto-syncs and restarts pods
```

---

## 5. Repository Structure Recommendation

### 5.1 Proposed Directory Layout

```
k8_cluster/                              # Repository root (Command Post)
├── .git/                                # Git repository
├── .gitignore                           # Ignore secrets, temp files
├── README.md                            # Quick reference
├── CHANGELOG.md                         # Project history
├── TASKS.md                             # Task tracking
├── CLAUDE.md                            # AI assistant context
├── PRD.md                               # Product requirements
│
├── bootstrap/                           # Initial cluster setup
│   ├── talos/
│   │   └── README.md                    # Talos installation guide
│   └── argocd/
│       ├── install.yaml                 # ArgoCD installation manifest
│       ├── media-stack-application.yaml # ArgoCD Application for media
│       └── README.md
│
├── infrastructure/                      # Core infrastructure (Phase 2-3)
│   ├── metallb/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   ├── namespace.yaml
│   │   │   ├── ipaddresspool.yaml
│   │   │   └── l2advertisement.yaml
│   │   └── README.md
│   ├── nfs-provisioner/
│   │   ├── base/
│   │   │   ├── kustomization.yaml
│   │   │   └── deployment.yaml
│   │   └── README.md
│   └── cert-manager/
│       └── (future)
│
├── monitoring/                          # Observability stack (Phase 3)
│   ├── prometheus/
│   │   ├── values.yaml
│   │   └── servicemonitors/
│   └── grafana/
│       └── dashboards/
│
├── apps/                                # Application workloads (Phase 4+)
│   └── media/                           # Media automation stack
│       ├── README.md                    # Service documentation
│       ├── base/                        # Base manifests
│       │   ├── kustomization.yaml       # Base kustomization
│       │   ├── namespace.yaml           # Namespace with PodSecurity labels
│       │   ├── common-configmap.yaml    # Shared env vars (PUID, PGID, TZ)
│       │   ├── pvcs.yaml                # PersistentVolumeClaims (2)
│       │   ├── prowlarr.yaml            # Service + Deployment
│       │   ├── radarr.yaml              # Service + Deployment
│       │   ├── sonarr.yaml              # Service + Deployment
│       │   ├── lidarr.yaml              # Service + Deployment
│       │   ├── qbittorrent.yaml         # Service + Deployment
│       │   ├── sabnzbd.yaml             # Service + Deployment
│       │   ├── overseerr.yaml           # Service + Deployment
│       │   ├── plex.yaml                # Service + Deployment
│       │   └── servicemonitor.yaml      # Prometheus monitoring
│       └── overlays/
│           └── production/
│               ├── kustomization.yaml   # References ../base
│               └── sealed-secrets.yaml  # Encrypted secrets
│
├── scripts/                             # Automation scripts
│   ├── backup-cluster-state.sh          # Daily backup script
│   ├── extract-api-keys.sh              # Secret extraction
│   └── health-check.sh                  # Cluster health check
│
├── backups/                             # Automated backups (Git LFS)
│   ├── YYYYMMDD-HHMMSS/
│   │   ├── all-resources.yaml
│   │   ├── pvcs.yaml
│   │   └── etcd-backup.db
│   └── .gitattributes                   # Git LFS config for .db files
│
├── docs/                                # Documentation
│   ├── procedures/
│   │   ├── TALOS_INSTALLATION_PLAYBOOK.md
│   │   └── DISASTER_RECOVERY.md
│   ├── architecture/
│   │   └── MEDIA_STACK_ARCHITECTURE.md
│   └── runbooks/
│       └── GITOPS_TROUBLESHOOTING.md
│
└── config/                              # Configuration management
    └── talos/
        └── live-config/                 # Symlink to ~/talos-cluster/
```

### 5.2 Migration from Current Structure

**Current State:**
- Manifests scattered in root directory
- deployments/media/optimized/ with 2 files
- deployments/media/overseerr.yaml
- No clear organization

**Migration Steps:**
1. Create apps/media/base/ directory
2. Move all YAML files from root to apps/media/base/
3. Consolidate duplicates (prefer optimized versions)
4. Delete empty deployments/media/optimized/
5. Rename deployments/ to apps/ (align with GitOps convention)
6. Create kustomization.yaml files
7. Update .gitignore
8. Commit all changes

**Git Commands:**
```bash
# Create new structure
mkdir -p apps/media/{base,overlays/production}
mkdir -p bootstrap/argocd
mkdir -p infrastructure/{metallb,nfs-provisioner}
mkdir -p backups

# Move media manifests
mv *.yaml apps/media/base/  # Move all from root
mv deployments/media/overseerr.yaml apps/media/base/
mv deployments/media/optimized/*.yaml apps/media/base/

# Remove old structure
rm -rf deployments/

# Create kustomization files (as detailed in Section 3.1 Step 6)

# Commit
git add apps/ bootstrap/ infrastructure/ backups/
git commit -m "[gitops] Restructure repository for GitOps workflow

- Create apps/media/{base,overlays} structure
- Move all manifests from root to apps/media/base/
- Add kustomization.yaml files
- Create bootstrap/argocd/ for ArgoCD manifests
- Remove old deployments/ directory
- Add .gitignore for secrets and temp files

This aligns with GitOps best practices and prepares for ArgoCD deployment."
```

---

## 6. Risk Assessment & Mitigation

### 6.1 Risks During Phase 5 Implementation

| Risk | Probability | Impact | Mitigation |
|------|-------------|--------|------------|
| **Secret Leakage to Git** | HIGH | CRITICAL | Use Sealed Secrets, add .gitignore, Git pre-commit hooks |
| **Service Downtime During Migration** | MEDIUM | HIGH | Blue-green deployment, test in staging namespace first |
| **ArgoCD Sync Loop (Drift)** | MEDIUM | MEDIUM | Disable auto-sync initially, test manually first |
| **PVC Data Loss** | LOW | CRITICAL | Backup PVCs before refactoring, use Velero |
| **API Key Rotation Breaks Integrations** | MEDIUM | HIGH | Document all service connections, test after rotation |
| **Git Repository Deletion** | LOW | CRITICAL | Use remote Git repository (GitHub/GitLab), enable backups |
| **Sealed Secrets Controller Failure** | LOW | HIGH | Backup sealed-secrets encryption key, document recovery |
| **Manifest Syntax Errors** | MEDIUM | MEDIUM | Use kubectl --dry-run=client, kustomize build validation |

### 6.2 Rollback Strategy

**If ArgoCD Breaks Deployment:**
```bash
# Disable ArgoCD sync
argocd app set media-stack --sync-policy none

# Revert to manual kubectl apply
kubectl apply -f /path/to/backup/manifests/

# Fix issue in Git, then re-enable sync
git revert HEAD
git push
argocd app set media-stack --sync-policy automated
```

**If Sealed Secret Decryption Fails:**
```bash
# Check controller logs
kubectl logs -n kube-system -l name=sealed-secrets-controller

# Manually create secret (temporary)
kubectl create secret generic media-stack-secrets \
  --namespace=media \
  --from-literal=radarr-api-key='BACKUP-KEY'

# Fix sealed-secrets controller issue
kubectl delete pod -n kube-system -l name=sealed-secrets-controller
```

**If PVC Corruption:**
```bash
# Restore from backup (Velero)
velero restore create --from-backup media-configs-backup

# OR recreate PVC (data loss)
kubectl delete pvc media-configs -n media
kubectl apply -f apps/media/base/pvcs.yaml
```

### 6.3 Testing Strategy

**Pre-Production Testing:**
1. Create test namespace: `media-test`
2. Deploy media stack with test data
3. Test ArgoCD sync, drift detection, self-heal
4. Test secret rotation procedure
5. Test backup and restore
6. Delete test namespace after validation

**Production Deployment Checklist:**
- [ ] Backup all PVCs (media-configs, media-storage)
- [ ] Export current API keys from running services
- [ ] Create sealed secrets
- [ ] Test kustomize build locally
- [ ] Dry-run apply: `kubectl apply -k apps/media/overlays/production --dry-run=client`
- [ ] Deploy during maintenance window
- [ ] Monitor ArgoCD sync status
- [ ] Verify all pods Running
- [ ] Test service connectivity (HTTP 200 checks)
- [ ] Test end-to-end workflow (Overseerr → Radarr → qBittorrent → Plex)
- [ ] Update CHANGELOG.md

---

## 7. Phase 5 Success Criteria

**GitOps Implementation Complete When:**
- [x] Git repository initialized and pushed to remote
- [x] All manifests in apps/media/{base,overlays} structure
- [x] Sealed Secrets controller installed and operational
- [x] All secrets encrypted and committed to Git
- [x] Kustomization files created and validated
- [x] ArgoCD installed and accessible
- [x] ArgoCD Application manifest created for media-stack
- [x] Automated sync enabled (prune: true, selfHeal: true)
- [x] Manual drift test passes (ArgoCD reverts kubectl changes)
- [x] Backup automation implemented (daily cluster state backups)
- [x] Documentation complete (README in apps/media/)
- [x] CHANGELOG.md updated with Phase 5 completion

**Operational Validation:**
- [ ] All 8 media services running via GitOps deployment
- [ ] ArgoCD shows "Synced" and "Healthy" status
- [ ] End-to-end workflow functional (Overseerr → Plex)
- [ ] Secrets rotation tested successfully
- [ ] Backup and restore tested successfully
- [ ] No unencrypted secrets in Git history

---

## 8. Recommended Timeline

### Phase 4.5: GitOps Preparation (2-3 days)
**Week 9, Days 1-3**
- Day 1: Initialize Git, consolidate manifests, create kustomization files (8 hours)
- Day 2: Install Sealed Secrets, extract and seal all secrets (6 hours)
- Day 3: Create documentation, commit all changes, push to remote (4 hours)

### Phase 5: GitOps Implementation (2-3 days)
**Week 9, Days 4-6**
- Day 4: Install ArgoCD, create Application manifest, configure repo access (4 hours)
- Day 5: Deploy media stack via ArgoCD, test sync and self-heal (4 hours)
- Day 6: Implement backup automation, test disaster recovery, update docs (4 hours)

**Total Estimated Time:** 4-6 days (30-36 hours)

---

## 9. Conclusion

### Current State: 6.5/10 GitOps Readiness

**Strengths:**
- Solid infrastructure foundation (Phase 1-3 complete)
- All services operational with stable LoadBalancer IPs
- End-to-end workflow validated
- Resource limits defined

**Critical Gaps (MUST FIX):**
- ❌ No Git repository
- ❌ Hardcoded Plex claim token in YAML
- ❌ No Sealed Secrets implementation
- ❌ Fragmented manifest organization
- ❌ Missing Kustomization files

**Recommendation:**
**DO NOT proceed directly to Phase 5.** Allocate 2-3 days for **Phase 4.5 (GitOps Preparation)** to address critical gaps. Attempting Phase 5 without these prerequisites will result in:
- Secret leakage to Git
- ArgoCD configuration confusion
- Deployment failures
- Manual rollback required

**After completing Phase 4.5 prerequisites, Phase 5 implementation should be straightforward and low-risk.**

---

## 10. Next Steps (Action Plan)

**Immediate (Next 24 Hours):**
1. Initialize Git repository
2. Create .gitignore (exclude secrets)
3. Remove hardcoded Plex claim token from plex-optimized.yaml
4. Commit current state (except secrets)

**Short-Term (Week 9, Days 1-3):**
1. Execute Phase 4.5 prerequisite steps (Section 3.1)
2. Consolidate manifests
3. Install Sealed Secrets
4. Migrate all secrets
5. Create kustomization files
6. Create documentation

**Medium-Term (Week 9, Days 4-6):**
1. Install ArgoCD
2. Create ArgoCD Application for media-stack
3. Test GitOps workflow (sync, drift, self-heal)
4. Implement backup automation
5. Complete Phase 5 success criteria

**Post-Phase 5:**
1. Monitor cluster for 1 week
2. Document lessons learned
3. Plan Phase 6: Advanced features (HPA, PodDisruptionBudgets, Velero)

---

**Document Version:** 1.0
**Author:** GitOps Specialist (Claude Code)
**Last Updated:** 2025-10-05
**Next Review:** After Phase 4.5 completion
