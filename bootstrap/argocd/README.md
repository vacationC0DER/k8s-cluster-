# ArgoCD Bootstrap Configuration

This directory contains ArgoCD Application manifests for GitOps-managed deployments.

## Current Limitation: No Git Remote

The k8_cluster repository is currently local-only (no GitHub/GitLab remote configured).

ArgoCD requires a Git repository URL to function as a GitOps tool. For Phase 5 testing, we have two options:

### Option 1: Create a GitHub Repository (Recommended)

```bash
# 1. Create GitHub repo: https://github.com/yourusername/k8_cluster
# 2. Add remote to local Git
git remote add origin https://github.com/yourusername/k8_cluster.git

# 3. Push to remote
git push -u origin main

# 4. Update media-stack-application.yaml repoURL to your GitHub URL
# 5. Apply Application: kubectl apply -f bootstrap/argocd/media-stack-application.yaml
```

### Option 2: Use ArgoCD Example App (Demo Only)

For testing ArgoCD functionality without setting up GitHub:

```bash
# Deploy example guestbook app
kubectl apply -f bootstrap/argocd/example-guestbook-application.yaml

# This demonstrates:
# - ArgoCD UI navigation
# - Application sync process
# - Health monitoring
# - Drift detection
```

### Option 3: Manual Manifest Management (Current)

Since media stack is already deployed, we can demonstrate ArgoCD by:

1. Deleting existing media resources
2. Deploying via ArgoCD from a Git repository
3. Testing sync, drift, and self-heal

**Decision**: Proceed with Option 1 (GitHub) if user wants full GitOps, or Option 2 (demo) for Phase 5 validation.

## ArgoCD Access

- **URL**: http://10.69.1.162 or https://10.69.1.162
- **Username**: admin
- **Password**: Retrieved from: `kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d`
- **LoadBalancer IP**: 10.69.1.162

## Next Steps

After choosing an option above:

1. Verify ArgoCD Application created
2. Test manual sync
3. Test drift detection
4. Enable auto-sync and self-heal
5. Document workflow in CHANGELOG.md
