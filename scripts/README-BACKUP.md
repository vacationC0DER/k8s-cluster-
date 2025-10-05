# etcd Backup Automation

## Overview

The `backup-etcd.sh` script creates automated snapshots of the etcd cluster state for disaster recovery.

## Features

- **Daily backups**: Designed to run at 2 AM via cron
- **Automatic retention**: Keeps 7 days of backups, deletes older ones
- **Error handling**: Validates connectivity and logs all operations
- **Backup location**: `/Users/stevenbrown/Development/k8_cluster/backups/etcd/`

## Manual Backup

To create a backup immediately:

```bash
cd /Users/stevenbrown/Development/k8_cluster
./scripts/backup-etcd.sh
```

## Automated Backups (cron)

### macOS Cron Setup

1. Edit crontab:
   ```bash
   crontab -e
   ```

2. Add this line to run backup daily at 2 AM:
   ```cron
   0 2 * * * /Users/stevenbrown/Development/k8_cluster/scripts/backup-etcd.sh
   ```

3. Save and exit (`:wq` in vim)

4. Verify cron job:
   ```bash
   crontab -l
   ```

### macOS Launchd Setup (Alternative)

macOS prefers launchd over cron. To use launchd:

1. Create plist file: `~/Library/LaunchAgents/com.k8s.etcd-backup.plist`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.k8s.etcd-backup</string>
    <key>ProgramArguments</key>
    <array>
        <string>/Users/stevenbrown/Development/k8_cluster/scripts/backup-etcd.sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Hour</key>
        <integer>2</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>/Users/stevenbrown/Development/k8_cluster/backups/etcd/launchd.log</string>
    <key>StandardErrorPath</key>
    <string>/Users/stevenbrown/Development/k8_cluster/backups/etcd/launchd.error.log</string>
</dict>
</plist>
```

2. Load the job:
   ```bash
   launchctl load ~/Library/LaunchAgents/com.k8s.etcd-backup.plist
   ```

3. Verify:
   ```bash
   launchctl list | grep etcd-backup
   ```

## Backup Files

- **Location**: `/Users/stevenbrown/Development/k8_cluster/backups/etcd/`
- **Naming**: `etcd-backup-YYYYMMDD-HHMMSS.db`
- **Size**: ~30MB per backup
- **Retention**: 7 days (automatic cleanup)

## Logs

- **Log file**: `/Users/stevenbrown/Development/k8_cluster/backups/etcd/backup.log`
- **View recent logs**:
  ```bash
  tail -f backups/etcd/backup.log
  ```

## Restoring from Backup

See `docs/runbooks/DISASTER_RECOVERY.md` for complete restore procedures.

Quick restore steps (emergency only):

```bash
# 1. Stop all control plane nodes except first node
talosctl --nodes 10.69.1.140,10.69.1.147 shutdown

# 2. Restore etcd on first node
talosctl --nodes 10.69.1.101 etcd restore --from /path/to/backup.db

# 3. Restart first node
talosctl --nodes 10.69.1.101 reboot

# 4. Verify cluster health
talosctl health

# 5. Restart remaining control plane nodes
talosctl --nodes 10.69.1.140,10.69.1.147 reboot
```

## Monitoring Backup Status

Check backup log for failures:

```bash
# View last backup
tail -20 backups/etcd/backup.log

# Check for errors
grep ERROR backups/etcd/backup.log

# List all backups
ls -lh backups/etcd/etcd-backup-*.db
```

## Troubleshooting

### Error: talosctl not found

```bash
brew install siderolabs/tap/talosctl
```

### Error: Cannot reach control plane node

- Verify network connectivity: `ping 10.69.1.101`
- Check TALOSCONFIG: `echo $TALOSCONFIG`
- Test manually: `talosctl --nodes 10.69.1.101 get members`

### Error: Permission denied

```bash
chmod +x scripts/backup-etcd.sh
```

### Backups not running automatically

- Verify cron job: `crontab -l`
- Check cron logs: `tail -f /var/mail/stevenbrown`
- Test manual run: `./scripts/backup-etcd.sh`

## Best Practices

1. **Test backups regularly**: Perform test restores quarterly
2. **Off-site storage**: Copy backups to NAS or cloud (10.69.1.163)
3. **Monitor logs**: Check backup.log weekly for errors
4. **Verify backup size**: ~30MB is normal, significantly smaller may indicate issues
5. **Keep Git configs**: etcd backups + Git configs = complete recovery

## Next Steps

After setting up automated backups:

1. Set up off-site backup replication (rsync to NAS)
2. Test disaster recovery procedure
3. Document in CHANGELOG.md
4. Add monitoring alert for backup failures
