# Phase 5 GitOps Implementation - Quick Start Guide

**STOP! Read This First:** Do NOT proceed directly to Phase 5. Complete Phase 4.5 prerequisites first.

---

## GitOps Readiness Score: 6.5/10 (CONDITIONALLY READY)

Your Phase 4 media stack is operational but has **critical gaps** that must be addressed before GitOps implementation.

**Full Assessment:** See [GITOPS_READINESS_ASSESSMENT.md](GITOPS_READINESS_ASSESSMENT.md)

---

## Critical Issues (BLOCKERS)

### 1. Hardcoded Secret in Git ❌ CRITICAL
**File:** `deployments/media/optimized/plex-optimized.yaml`
**Line 51:** `value: "claim-cPXzEkyKeLzj13jsk3Co"`

**Risk:** If pushed to public Git, your Plex account can be compromised.

**Fix:**
```bash
# Temporarily remove token
sed -i '' 's/claim-cPXzEkyKeLzj13jsk3Co/PLACEHOLDER-TOKEN-REPLACE-BEFORE-DEPLOY/g' \
  deployments/media/optimized/plex-optimized.yaml
```

### 2. No Git Repository ❌ BLOCKER
```bash
git status
# fatal: not a git repository
```

**Fix:**
```bash
cd /Users/stevenbrown/Development/k8_cluster
git init
```

### 3. No Sealed Secrets Controller ❌ BLOCKER
Cannot store secrets in Git without encryption.

**Fix:**
```bash
kubectl apply -f https://github.com/bitnami-labs/sealed-secrets/releases/download/v0.24.0/controller.yaml
brew install kubeseal
```

### 4. Fragmented Manifests ⚠️ HIGH PRIORITY
Manifests scattered across:
- Root directory: 9 YAML files
- deployments/media/optimized/: 2 YAML files
- deployments/media/: 1 YAML file

**Fix:** Consolidate into `apps/media/{base,overlays}` structure (see Phase 4.5 plan)

---

## Phase 4.5: GitOps Preparation (REQUIRED)

**Estimated Time:** 2-3 days
**Status:** NOT STARTED

### Prerequisites Checklist

- [ ] **Day 1: Repository Setup (4 hours)**
  - [ ] Initialize Git repository
  - [ ] Create .gitignore (exclude secrets)
  - [ ] Remove hardcoded Plex claim token
  - [ ] Consolidate manifests into apps/media/base/
  - [ ] Create kustomization.yaml files
  - [ ] Initial commit (no secrets)

- [ ] **Day 2: Secrets Management (4 hours)**
  - [ ] Install Sealed Secrets controller
  - [ ] Install kubeseal CLI
  - [ ] Extract API keys from running services
  - [ ] Create Kubernetes Secret
  - [ ] Seal secret with kubeseal
  - [ ] Commit sealed-secrets.yaml to Git

- [ ] **Day 3: Documentation & Validation (2 hours)**
  - [ ] Create apps/media/README.md
  - [ ] Create namespace.yaml
  - [ ] Test kustomize build
  - [ ] Dry-run apply
  - [ ] Push to remote Git repository

**DO NOT PROCEED TO PHASE 5 UNTIL ALL ABOVE COMPLETED**

---

## Phase 5: GitOps Implementation (AFTER Phase 4.5)

**Estimated Time:** 2-3 days

### Day 1: ArgoCD Installation (4 hours)
```bash
# Install ArgoCD
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

# Get admin password
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d

# Access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# https://localhost:8080 (admin/<password>)
```

### Day 2: Deploy Media Stack via ArgoCD (4 hours)
```yaml
# bootstrap/argocd/media-stack-application.yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: media-stack
  namespace: argocd
spec:
  project: default
  source:
    repoURL: https://github.com/<your-username>/k8_cluster.git
    targetRevision: main
    path: apps/media/overlays/production
  destination:
    server: https://kubernetes.default.svc
    namespace: media
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

### Day 3: Backup & Validation (2 hours)
```bash
# Create backup script
cat > scripts/backup-cluster-state.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_DIR="backups/$DATE"
mkdir -p "$BACKUP_DIR"
kubectl get all --all-namespaces -o yaml > "$BACKUP_DIR/all-resources.yaml"
talosctl --nodes 10.69.1.101 etcd snapshot "$BACKUP_DIR/etcd-backup.db"
cd /Users/stevenbrown/Development/k8_cluster
git add "$BACKUP_DIR"
git commit -m "[backup] Automated cluster state backup $DATE"
git push
EOF

chmod +x scripts/backup-cluster-state.sh
./scripts/backup-cluster-state.sh
```

---

## Quick Commands Reference

### Validate Current State
```bash
# Check for secrets in YAML files
grep -r "claim-\|api_key\|password" deployments/ apps/ *.yaml

# Check namespace configuration
kubectl get namespace media -o yaml

# Check PVCs
kubectl get pvc -n media

# Check all services
kubectl get svc -n media | grep LoadBalancer
```

### Test Kustomize (After Phase 4.5)
```bash
# Build and validate
kubectl kustomize apps/media/overlays/production

# Dry-run
kubectl apply -k apps/media/overlays/production --dry-run=client
```

### ArgoCD Commands
```bash
# Get application status
argocd app get media-stack

# Sync application
argocd app sync media-stack

# View sync status
argocd app wait media-stack --timeout 300

# View logs
argocd app logs media-stack --follow
```

### Sealed Secrets Commands
```bash
# Fetch public cert
kubeseal --fetch-cert > sealed-secrets-public-cert.pem

# Seal a secret
kubectl create secret generic test-secret \
  --dry-run=client -o yaml | kubeseal --format yaml > sealed-secret.yaml

# Verify sealed secret applied
kubectl get sealedsecret -n media
kubectl get secret media-stack-secrets -n media
```

---

## Success Criteria

### Phase 4.5 Complete When:
- [x] Git repository initialized and has remote
- [x] All manifests in apps/media/{base,overlays} structure
- [x] No unencrypted secrets in Git
- [x] Sealed Secrets controller operational
- [x] Kustomize build succeeds
- [x] Dry-run apply succeeds

### Phase 5 Complete When:
- [x] ArgoCD installed and accessible
- [x] Media stack deployed via ArgoCD
- [x] ArgoCD status: Synced + Healthy
- [x] Manual drift test passes (self-heal works)
- [x] Backup automation implemented
- [x] End-to-end workflow functional

---

## Risk Mitigation

### Before Making Changes:
1. **Backup PVCs:**
   ```bash
   kubectl get pvc -n media -o yaml > backup-pvcs.yaml
   ```

2. **Export current manifests:**
   ```bash
   kubectl get all -n media -o yaml > backup-media-namespace.yaml
   ```

3. **Document current state:**
   ```bash
   kubectl get svc -n media > current-loadbalancer-ips.txt
   ```

### If Something Breaks:
```bash
# Disable ArgoCD auto-sync
argocd app set media-stack --sync-policy none

# Manually restore
kubectl apply -f backup-media-namespace.yaml

# Fix issue in Git
git revert HEAD
git push

# Re-enable ArgoCD
argocd app set media-stack --sync-policy automated
```

---

## Current Manifest Inventory

**Root Directory (9 files - NEEDS CONSOLIDATION):**
- lidarr.yaml
- media-storage-pvcs.yaml
- plex.yaml
- prowlarr.yaml
- qbittorrent.yaml
- radarr.yaml
- sabnzbd.yaml
- sonarr.yaml
- prometheus-values.yaml (not media-related)

**deployments/media/optimized/ (2 files):**
- plex-optimized.yaml (⚠️ contains hardcoded secret)
- qbittorrent-optimized.yaml

**deployments/media/ (1 file):**
- overseerr.yaml

**MISSING:**
- namespace.yaml
- kustomization.yaml
- sealed-secrets.yaml
- common-configmap.yaml

---

## Next Actions (In Order)

1. **IMMEDIATE (Today):** Remove hardcoded Plex claim token
2. **Day 1:** Initialize Git, consolidate manifests
3. **Day 2:** Install Sealed Secrets, migrate secrets
4. **Day 3:** Create documentation, push to remote
5. **Day 4:** Install ArgoCD
6. **Day 5:** Deploy via ArgoCD
7. **Day 6:** Backup automation, validation

---

## Resources

- **Full Assessment:** [GITOPS_READINESS_ASSESSMENT.md](GITOPS_READINESS_ASSESSMENT.md)
- **Project Context:** [CLAUDE.md](CLAUDE.md)
- **Current Status:** [TASKS.md](TASKS.md)
- **Change History:** [CHANGELOG.md](CHANGELOG.md)

---

**REMEMBER:** Do NOT push to public Git until hardcoded secret is removed!
