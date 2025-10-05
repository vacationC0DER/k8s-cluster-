# Talos Windows Wipe Process - Complete Guide

## Overview
This document provides the exact step-by-step process to wipe Windows from NVMe drives and install Talos OS properly. This process was successfully tested on Node 2 (10.69.1.140).

## Problem Statement
- Beelink SER5 nodes come with Windows pre-installed on NVMe
- Talos installer boots from USB but may install to USB instead of NVMe
- We need Windows completely removed and Talos installed to internal NVMe
- Node should boot from NVMe without USB after completion

## Prerequisites
- Talos cluster configuration files generated (`~/talos-cluster/controlplane.yaml`)
- USB drive with Talos installer created
- Network connectivity to node
- UniFi DHCP assigns IP to node

---

## Step-by-Step Process

### Phase 1: Initial Boot and Connectivity

#### 1.1 Boot Node from USB
```bash
# Physical steps:
# 1. Insert USB drive with Talos installer
# 2. Power on Beelink SER5
# 3. Press F7 repeatedly during boot
# 4. Select USB drive from boot menu
# 5. Wait for Talos maintenance mode
# 6. Note IP address displayed on screen
```

#### 1.2 Test Connectivity
```bash
# Replace <NODE_IP> with IP shown on screen
ping -c 3 <NODE_IP>

# Verify Talos responds (should work even in maintenance mode)
talosctl get discoveredvolumes --insecure --nodes <NODE_IP>
```

#### 1.3 Record Node IP
```bash
# Add to tracking file
echo "Node X (Control Plane/Worker): <NODE_IP>" >> ~/talos-cluster/node-ips.txt
```

### Phase 2: Analyze Current Disk Layout

#### 2.1 Check Disk Configuration
```bash
# View all discovered volumes
talosctl get discoveredvolumes --insecure --nodes <NODE_IP>
```

**Expected Output Analysis:**
- **USB (sda):** Talos installer (iso9660, ~62GB)
- **NVMe (nvme0n1):** Windows partitions (512GB)
  - `nvme0n1p1`: EFI system partition
  - `nvme0n1p2`: Microsoft reserved partition ← **WINDOWS**
  - `nvme0n1p3`: Basic data partition ← **WINDOWS**
  - `nvme0n1p4`: Basic data partition ← **WINDOWS**

#### 2.2 Verify System Disk (if Talos was applied)
```bash
# Check which disk Talos is using (if already configured)
talosctl get systemdisk --insecure --nodes <NODE_IP>
```

**Problem Indicators:**
- If system disk shows `sda` → Talos installed to USB (wrong!)
- If Windows partitions still exist on nvme0n1 → Need to wipe

### Phase 3: Wipe Windows from NVMe

#### 3.1 Wipe NVMe Disk Specifically
```bash
# CRITICAL: Target nvme0n1 specifically, NOT sda (USB)
talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>
```

**What this does:**
- Removes ALL partitions from NVMe
- Deletes Windows completely
- Creates clean disk for Talos installation
- Does NOT touch USB drive

#### 3.2 Verify Windows Removal
```bash
# Check that Windows partitions are gone
talosctl get discoveredvolumes --insecure --nodes <NODE_IP> | grep nvme
```

**Expected Result:**
```
runtime     DiscoveredVolume   nvme0n1   2         disk   512 GB
```
- No partition entries (nvme0n1p1, nvme0n1p2, etc.)
- Just clean 512GB disk

### Phase 4: Install Talos to Clean NVMe

#### 4.1 Ensure Configuration Targets NVMe
```bash
# Verify controlplane.yaml has correct settings
grep -A 5 "install:" ~/talos-cluster/controlplane.yaml
```

**Required Settings:**
```yaml
install:
    disk: /dev/nvme0n1  # Target NVMe, not /dev/sda
    wipe: true          # Enable wiping (redundant after manual wipe)
```

#### 4.2 Apply Configuration
```bash
# Install Talos to the clean NVMe
talosctl apply-config --insecure --nodes <NODE_IP> --file ~/talos-cluster/controlplane.yaml
```

**What happens:**
- Talos installs to nvme0n1
- Creates proper Talos partitions
- Node reboots automatically (2-3 minutes)
- Boots from internal NVMe

#### 4.3 Wait for Installation and Reboot
```bash
# Wait for installation and reboot
echo "Waiting for installation and reboot..."
sleep 120

# Test connectivity after reboot
ping -c 3 <NODE_IP>
```

### Phase 5: Verify Success

#### 5.1 Check System Disk
```bash
# Verify Talos is running from NVMe
export TALOSCONFIG=~/talos-cluster/talosconfig
talosctl --nodes <NODE_IP> get systemdisk
```

**Success Indicator:**
```
NODE        NAMESPACE   TYPE         ID            VERSION   DISK
<NODE_IP>   runtime     SystemDisk   system-disk   1         nvme0n1
```

#### 5.2 Verify Disk Layout
```bash
# Check final partition layout
talosctl --nodes <NODE_IP> get discoveredvolumes
```

**Expected NVMe Layout (Success):**
```
nvme0n1     1    disk        512 GB   gpt
nvme0n1p1   1    partition   2.2 GB   vfat         EFI         EFI
nvme0n1p2   1    partition   1.0 MB   talosmeta                META
nvme0n1p3   1    partition   105 MB   xfs          STATE       STATE
nvme0n1p4   1    partition   510 GB   xfs          EPHEMERAL   EPHEMERAL
```

#### 5.3 Test Node Services
```bash
# Verify Talos services are running
talosctl --nodes <NODE_IP> services

# Check for any errors
talosctl --nodes <NODE_IP> dmesg | tail -20
```

### Phase 6: Cleanup

#### 6.1 Remove USB Drive
```bash
# Physical step: Remove USB drive from node
# Node should continue running from NVMe
```

#### 6.2 Test Boot Without USB
```bash
# Reboot node to verify it boots from NVMe
talosctl --nodes <NODE_IP> reboot

# Wait and verify it comes back online
sleep 60
ping -c 3 <NODE_IP>
talosctl --nodes <NODE_IP> version
```

#### 6.3 Update Documentation
```bash
# Update node status
cat >> ~/talos-cluster/node-status.txt <<EOF
Node X - COMPLETED
  IP: <NODE_IP>
  Role: Control Plane/Worker
  Boot: Internal NVMe (Windows wiped)
  Status: Ready
  Date: $(date +%Y-%m-%d)
EOF
```

---

## Troubleshooting Guide

### Issue: Talos Installs to USB Instead of NVMe

**Symptoms:**
- `get systemdisk` shows `sda`
- Windows partitions still on nvme0n1

**Solution:**
1. Wipe NVMe: `talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>`
2. Reapply config: `talosctl apply-config --insecure --nodes <NODE_IP> --file ~/talos-cluster/controlplane.yaml`

### Issue: TLS Certificate Errors

**Symptoms:**
```
transport: authentication handshake failed: tls: failed to verify certificate
```

**Solution:**
- Use `--insecure` flag for maintenance mode operations
- After configuration applied, use proper talosconfig

### Issue: Node Not Responding After Wipe

**Symptoms:**
- Ping fails after wipe command
- Node appears offline

**Solution:**
1. Wait 5 minutes (installation takes time)
2. Check physical connections
3. Verify node is still powered on
4. Try rebooting node physically

### Issue: Windows Still Present After Wipe

**Symptoms:**
- Still see "Microsoft reserved partition"
- Basic data partitions remain

**Solution:**
1. Verify you targeted correct disk: `nvme0n1` not `sda`
2. Re-run wipe command: `talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>`
3. Check output of `get discoveredvolumes`

---

## Quick Reference Commands

### Essential Commands for Each Node
```bash
# 1. Test connectivity
ping -c 3 <NODE_IP>

# 2. Check current layout
talosctl get discoveredvolumes --insecure --nodes <NODE_IP>

# 3. Wipe Windows from NVMe
talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>

# 4. Install Talos to NVMe
talosctl apply-config --insecure --nodes <NODE_IP> --file ~/talos-cluster/controlplane.yaml

# 5. Verify success
export TALOSCONFIG=~/talos-cluster/talosconfig
talosctl --nodes <NODE_IP> get systemdisk
```

### Node IP Tracking
```bash
# Current known IPs:
# Node 1 (CP-1): 10.69.1.101
# Node 2 (CP-2): 10.69.1.140 ✅ COMPLETED
# Node 3 (CP-3): TBD
# Node 4 (Worker-1): TBD  
# Node 5 (Worker-2): TBD
# Node 6 (Worker-3): TBD
```

---

## Success Criteria

For each node, verify ALL of these before moving to next node:

- [ ] Node responds to ping
- [ ] `get systemdisk` shows `nvme0n1` (not `sda`)
- [ ] No Windows partitions on NVMe (`get discoveredvolumes`)
- [ ] Talos services running (`services`)
- [ ] Node boots without USB drive
- [ ] Node IP documented in tracking file

---

## Time Estimates

- **Phase 1-2 (Boot & Analysis):** 5 minutes
- **Phase 3 (Wipe Windows):** 2 minutes  
- **Phase 4 (Install Talos):** 3-5 minutes
- **Phase 5 (Verify):** 3 minutes
- **Phase 6 (Cleanup):** 2 minutes

**Total per node:** ~15-20 minutes

---

## Notes

- This process is **irreversible** - Windows will be completely deleted
- USB drive can be reused for all nodes
- Each node gets a different IP from UniFi DHCP
- Process works for both Control Plane and Worker nodes
- Configuration file (`controlplane.yaml` or `worker.yaml`) determines node role

---

*Process documented after successful completion on Node 2 (10.69.1.140) on $(date +%Y-%m-%d)*
