#!/bin/bash
# IP Migration Script: 10.69.1.0/24 → 10.69.2.0/24
# Automatically updates all configuration files

set -e

OLD_SUBNET="10.69.1"
NEW_SUBNET="10.69.2"

REPO_ROOT="/Users/stevenbrown/Development/k8_cluster"
BACKUP_DIR="$HOME/backups/ip-migration-$(date +%Y%m%d-%H%M%S)"

echo "=========================================="
echo "IP Migration: ${OLD_SUBNET}.0/24 → ${NEW_SUBNET}.0/24"
echo "=========================================="
echo ""

# Safety check
read -p "This will modify all cluster configs. Continue? (yes/no): " confirm
if [ "$confirm" != "yes" ]; then
    echo "Aborted."
    exit 1
fi

# Create backup
echo "[1/5] Creating backup..."
mkdir -p "$BACKUP_DIR"
cd "$REPO_ROOT"
git add .
git commit -m "Pre-migration backup - $(date)" || true
tar -czf "$BACKUP_DIR/k8_cluster-backup.tar.gz" "$REPO_ROOT"
echo "✓ Backup created: $BACKUP_DIR"
echo ""

# Update IP allocations manifest
echo "[2/5] Updating IP allocations..."
cat > "$REPO_ROOT/infrastructure/ip-management/ip-allocations.yaml" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: ip-allocations
  namespace: kube-system
data:
  # Infrastructure IPs
  control-plane-1: "${NEW_SUBNET}.101"
  control-plane-2: "${NEW_SUBNET}.102"
  control-plane-3: "${NEW_SUBNET}.103"
  worker-1: "${NEW_SUBNET}.104"
  worker-2: "${NEW_SUBNET}.105"
  worker-3: "${NEW_SUBNET}.106"
  nfs-server: "${NEW_SUBNET}.163"

  # MetalLB Pool
  metallb-pool-start: "${NEW_SUBNET}.150"
  metallb-pool-end: "${NEW_SUBNET}.160"

  # Media Stack Services
  plex: "${NEW_SUBNET}.165"
  prowlarr: "${NEW_SUBNET}.155"
  radarr: "${NEW_SUBNET}.156"
  sonarr: "${NEW_SUBNET}.157"
  qbittorrent: "${NEW_SUBNET}.158"
  sabnzbd: "${NEW_SUBNET}.161"
  overseerr: "${NEW_SUBNET}.160"
  argocd: "${NEW_SUBNET}.162"
  ingress-nginx: "${NEW_SUBNET}.150"
EOF
echo "✓ IP allocations updated"
echo ""

# Update MetalLB pool
echo "[3/5] Updating MetalLB IP pool..."
if [ -f "$REPO_ROOT/infrastructure/metallb/ipaddresspool.yaml" ]; then
    sed -i '' "s/${OLD_SUBNET}\./${NEW_SUBNET}./g" "$REPO_ROOT/infrastructure/metallb/ipaddresspool.yaml"
    echo "✓ MetalLB pool updated"
else
    echo "⚠ MetalLB config not found - will need manual update"
fi
echo ""

# Update media stack services
echo "[4/5] Updating media stack services..."
for file in "$REPO_ROOT/apps/media/base"/*.yaml; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")

        # Replace all IPs in the subnet
        sed -i '' "s/${OLD_SUBNET}\./${NEW_SUBNET}./g" "$file"

        echo "  ✓ Updated: $filename"
    fi
done
echo ""

# Update NFS storage references
echo "[5/5] Updating NFS storage configuration..."
if [ -f "$REPO_ROOT/apps/media/base/media-storage-pvcs.yaml" ]; then
    sed -i '' "s/${OLD_SUBNET}\.163/${NEW_SUBNET}.163/g" "$REPO_ROOT/apps/media/base/media-storage-pvcs.yaml"
    echo "✓ NFS server IP updated"
else
    echo "⚠ NFS PVC config not found - will need manual update"
fi
echo ""

# Update documentation
echo "Updating documentation..."
if [ -f "$REPO_ROOT/CLAUDE.md" ]; then
    sed -i '' "s/${OLD_SUBNET}\./${NEW_SUBNET}./g" "$REPO_ROOT/CLAUDE.md"
    echo "✓ CLAUDE.md updated"
fi
if [ -f "$REPO_ROOT/README.md" ]; then
    sed -i '' "s/${OLD_SUBNET}\./${NEW_SUBNET}./g" "$REPO_ROOT/README.md"
    echo "✓ README.md updated"
fi
echo ""

# Show summary
echo "=========================================="
echo "Configuration Update Complete!"
echo "=========================================="
echo ""
echo "Updated files:"
git diff --name-only | while read file; do
    echo "  - $file"
done
echo ""
echo "Next steps:"
echo "1. Review changes: git diff"
echo "2. Commit changes: git add . && git commit -m 'Update IPs to ${NEW_SUBNET}.0/24'"
echo "3. Configure UniFi VLAN and DHCP reservations"
echo "4. Follow IP_MIGRATION_PLAN.md for cluster bootstrap"
echo ""
echo "Backup location: $BACKUP_DIR"
echo ""
