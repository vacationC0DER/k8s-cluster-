#!/bin/bash
#
# Automated etcd Backup Script
#
# Purpose: Creates daily snapshots of etcd cluster state
# Retention: 7 days (older backups are automatically deleted)
# Location: /Users/stevenbrown/Development/k8_cluster/backups/etcd/
#
# Schedule: Run via cron at 2 AM daily
#   0 2 * * * /Users/stevenbrown/Development/k8_cluster/scripts/backup-etcd.sh
#
# Manual execution:
#   ./scripts/backup-etcd.sh
#

set -euo pipefail

# Configuration
BACKUP_DIR="/Users/stevenbrown/Development/k8_cluster/backups/etcd"
TALOSCONFIG="/Users/stevenbrown/talos-cluster/talosconfig"
CONTROL_PLANE_NODE="10.69.1.101"
RETENTION_DAYS=7
DATE=$(date +%Y%m%d-%H%M%S)
BACKUP_FILE="$BACKUP_DIR/etcd-backup-$DATE.db"
LOG_FILE="$BACKUP_DIR/backup.log"

# Ensure backup directory exists
mkdir -p "$BACKUP_DIR"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log "=== Starting etcd backup ==="

# Check if talosctl is available
if ! command -v talosctl &> /dev/null; then
    log "ERROR: talosctl not found in PATH"
    exit 1
fi

# Check if TALOSCONFIG exists
if [ ! -f "$TALOSCONFIG" ]; then
    log "ERROR: TALOSCONFIG not found at $TALOSCONFIG"
    exit 1
fi

# Verify control plane node is reachable
log "Checking control plane node connectivity..."
if ! TALOSCONFIG="$TALOSCONFIG" talosctl --nodes "$CONTROL_PLANE_NODE" get members &> /dev/null; then
    log "ERROR: Cannot reach control plane node $CONTROL_PLANE_NODE"
    exit 1
fi

# Create etcd snapshot
log "Creating etcd snapshot from $CONTROL_PLANE_NODE..."
if TALOSCONFIG="$TALOSCONFIG" talosctl --nodes "$CONTROL_PLANE_NODE" etcd snapshot "$BACKUP_FILE"; then
    log "SUCCESS: Backup created at $BACKUP_FILE"

    # Get backup file size
    BACKUP_SIZE=$(du -h "$BACKUP_FILE" | cut -f1)
    log "Backup size: $BACKUP_SIZE"
else
    log "ERROR: Failed to create etcd snapshot"
    exit 1
fi

# Remove old backups (older than RETENTION_DAYS)
log "Cleaning up backups older than $RETENTION_DAYS days..."
DELETED_COUNT=$(find "$BACKUP_DIR" -name "etcd-backup-*.db" -type f -mtime +$RETENTION_DAYS -delete -print | wc -l)
log "Deleted $DELETED_COUNT old backup(s)"

# List current backups
log "Current backups:"
ls -lh "$BACKUP_DIR"/etcd-backup-*.db 2>/dev/null | awk '{print $9, $5}' | tee -a "$LOG_FILE" || log "No backups found"

# Count total backups
TOTAL_BACKUPS=$(ls -1 "$BACKUP_DIR"/etcd-backup-*.db 2>/dev/null | wc -l)
log "Total backups: $TOTAL_BACKUPS"

log "=== Backup completed successfully ==="
echo ""

# Return success
exit 0
