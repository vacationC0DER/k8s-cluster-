# Talos Cluster Installation Playbook

## Complete Step-by-Step Guide for Beelink SER5 Nodes

**Last Updated:** October 3, 2025  
**Status:** Nodes 1-4 successfully configured  
**Remaining:** Nodes 5-6 to be configured

---

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [The Proven Installation Process](#the-proven-installation-process)
4. [Troubleshooting](#troubleshooting)
5. [Cluster Status](#cluster-status)

---

## Overview

### Cluster Configuration
- **Total Nodes:** 6
- **Control Plane Nodes:** 3 (Nodes 1-3)
- **Worker Nodes:** 3 (Nodes 4-6)
- **Hardware:** Beelink SER5 with NVMe storage
- **OS:** Talos Linux v1.11.2
- **Initial State:** All nodes have Windows pre-installed on NVMe

### Network Configuration
- **Network:** 10.69.1.0/24
- **Control Plane Endpoint:** https://10.69.1.101:6443
- **DHCP:** UniFi assigns IPs automatically

### Current Node Status

| Node | Role | IP | Status | Date Completed |
|------|------|-----|--------|----------------|
| Node 1 | Control Plane | 10.69.1.101 | ✅ Operational | 2025-10-03 |
| Node 2 | Control Plane | 10.69.1.140 | ✅ Operational | 2025-10-03 |
| Node 3 | Control Plane | 10.69.1.147 | ✅ Operational | 2025-10-03 |
| Node 4 | Worker | 10.69.1.151 | ✅ Operational | 2025-10-03 |
| Node 5 | Worker | 10.69.1.197 | ⏸️ Pending | - |
| Node 6 | Worker | 10.69.1.179 | ⏸️ Pending | - |

**Progress: 4/6 nodes (66%) complete** 🎉

---

## Prerequisites

### On Your MacBook Pro M2

1. **Talos CLI (talosctl) v1.11.2**
   ```bash
   talosctl version
   ```

2. **Configuration Files**
   ```bash
   ~/talos-cluster/
   ├── controlplane.yaml  # For control plane nodes (1-3)
   ├── worker.yaml        # For worker nodes (4-6)
   ├── talosconfig        # Client authentication
   └── all-node-ips.txt   # IP tracking
   ```

3. **USB Drive**
   - Talos installer v1.11.2
   - Can be reused for all nodes
   - **Will be removed during installation process**

4. **Network Access**
   - Mac connected to 10.69.1.0/24 network
   - UniFi DHCP configured

### Critical Configuration Settings

**controlplane.yaml and worker.yaml MUST have:**
```yaml
install:
    disk: /dev/nvme0n1  # ✅ CRITICAL: Must target NVMe
    wipe: true          # ✅ CRITICAL: Must wipe Windows
```

---

## The Proven Installation Process

### ⏱️ Time Required: ~15 minutes per node

This is the **definitive process** that successfully configured Nodes 1-4 after extensive troubleshooting.

---

### 🎯 **Phase 1: Boot to Maintenance Mode**

#### Step 1: Physical Setup
1. **Insert USB drive** with Talos installer into node
2. **Power on** the node
3. **Press F7 repeatedly** during boot to enter boot menu
4. **Select USB drive** from boot menu (shows as "UEFI: USB Device")

#### Step 2: Wait for Maintenance Mode
- Screen will show: "Talos - Waiting for machine configuration"
- **Wait 1-2 minutes** for maintenance mode to fully start
- **Note the IP address** from UniFi controller or node screen

---

### 🔍 **Phase 2: Verify Maintenance Mode**

#### Test Network Connectivity
```bash
# Replace <NODE_IP> with the actual IP
ping -c 3 <NODE_IP>
```
**Expected:** Node responds (3-20ms typical)

#### Verify Talos API
```bash
talosctl get discoveredvolumes --insecure --nodes <NODE_IP>
```

**Expected Output:**
```
NODE   NAMESPACE   TYPE               ID          VERSION   TYPE   SIZE     DISCOVERED
       runtime     DiscoveredVolume   nvme0n1     1         disk   512 GB   gpt
       runtime     DiscoveredVolume   nvme0n1p1   1         partition ...   Microsoft reserved partition
       runtime     DiscoveredVolume   nvme0n1p2   1         partition ...   Basic data partition
       runtime     DiscoveredVolume   sda         1         disk   62 GB    iso9660
```

**Key Indicators:**
- ✅ Command succeeds (no errors)
- ✅ Shows `nvme0n1` with Windows partitions
- ✅ Shows `sda` (USB drive with Talos installer)

---

### 🧹 **Phase 3: Wipe Windows from NVMe**

**⚠️ CRITICAL STEP - Do NOT skip this!**

This step manually wipes Windows to ensure clean NVMe installation:

```bash
echo "=== Wiping Windows from NVMe ===" 
talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>
```

**What this does:**
- Removes ALL Windows partitions
- Removes "Microsoft reserved partition"
- Removes "Basic data partition"  
- Creates clean disk for Talos

#### Verify Windows Removal
```bash
talosctl get discoveredvolumes --insecure --nodes <NODE_IP> | grep nvme
```

**Expected Output:**
```
runtime  DiscoveredVolume  nvme0n1  2  disk  512 GB
```

**Success Indicators:**
- ✅ Shows only the disk (nvme0n1)
- ✅ NO partition entries
- ✅ NO "Microsoft" or "Windows" text
- ✅ Version changed to "2" (indicates wipe occurred)

---

### 🔴 **Phase 4: REMOVE USB DRIVE**

## **⚠️ CRITICAL - REMOVE USB DRIVE NOW! ⚠️**

**This is the most important step that ensures NVMe installation:**

1. **Physically remove the USB drive** from the node
2. **Verify it's removed** (can't see it anymore)
3. **Do NOT reinsert it**

**Why this is critical:**
- Even with correct config, Talos prefers USB if present
- USB removal forces installation to NVMe
- This was the key issue that caused multiple installation failures

**❗ DO NOT PROCEED TO PHASE 5 UNTIL USB IS REMOVED ❗**

---

### ⚙️ **Phase 5: Apply Configuration**

**Now that USB is removed**, apply the appropriate configuration:

#### For Control Plane Nodes (1-3)
```bash
echo "=== Applying Control Plane Configuration ==="
talosctl apply-config --insecure \
  --nodes <NODE_IP> \
  --file ~/talos-cluster/controlplane.yaml

echo "✅ Configuration applied"
```

#### For Worker Nodes (4-6)
```bash
echo "=== Applying Worker Configuration ==="
talosctl apply-config --insecure \
  --nodes <NODE_IP> \
  --file ~/talos-cluster/worker.yaml

echo "✅ Configuration applied"
```

**Expected Output:**
- Command completes with no output (silence = success)
- No error messages

**What Happens Next:**
1. Talos installer runs from memory (~30 seconds)
2. Installs Talos to NVMe (`/dev/nvme0n1`)
3. Creates Talos partitions:
   - EFI (2.2GB) - Boot partition
   - META (1MB) - Metadata
   - STATE (105MB) - Configuration
   - EPHEMERAL (510GB) - Data
4. **Reboots automatically** (~30 seconds)
5. **Boots from NVMe** (no USB needed!)

---

### ⏰ **Phase 6: Wait for Installation and Reboot**

```bash
echo "=== Waiting for installation to NVMe ==="
sleep 90  # Wait for installation and reboot

echo "=== Testing connectivity after reboot ==="
ping -c 3 <NODE_IP>
```

**Expected:** 
- First ping may timeout (node rebooting)
- Subsequent pings succeed (3-10ms)
- High first ping (100-300ms) indicates fresh reboot

---

### ✅ **Phase 7: Verify Installation Success**

#### Check Talos API Availability
```bash
# Wait for services to start
sleep 30

# Test API port
nc -z -v <NODE_IP> 50000
```

**Expected:** `Connection to <NODE_IP> port 50000 succeeded!`

#### Verify Certificates
```bash
export TALOSCONFIG=~/talos-cluster/talosconfig
talosctl --nodes <NODE_IP> version
```

**Expected Output:**
```
Client:
    Tag:         v1.11.2
Server:
    NODE:        <NODE_IP>
    Tag:         v1.11.2
    Enabled:     RBAC
```

**Success Indicators:**
- ✅ No certificate errors
- ✅ Server responds with version
- ✅ RBAC enabled

#### **🔑 CRITICAL VERIFICATION: Check System Disk**

**This is the most important check:**

```bash
talosctl --nodes <NODE_IP> get systemdisk
```

**✅ SUCCESS - Expected Output:**
```
NODE        NAMESPACE   TYPE         ID            VERSION   DISK
<NODE_IP>   runtime     SystemDisk   system-disk   1         nvme0n1
```

**❌ FAILURE - If you see this:**
```
DISK
sda
```

**If system disk shows `sda`:**
- Installation went to USB instead of NVMe
- USB was not removed before applying config
- **Solution:** Repeat process from Phase 1, ensuring USB removal in Phase 4

#### Verify Windows Removal and Talos Partitions
```bash
talosctl --nodes <NODE_IP> get discoveredvolumes | grep nvme
```

**Expected Output:**
```
nvme0n1     1    disk        512 GB   gpt
nvme0n1p1   1    partition   2.2 GB   vfat         EFI         EFI
nvme0n1p2   1    partition   1.0 MB   talosmeta                META
nvme0n1p3   1    partition   105 MB   xfs          STATE       STATE
nvme0n1p4   1    partition   510 GB   xfs          EPHEMERAL   EPHEMERAL
```

**Success Indicators:**
- ✅ NO "Microsoft reserved partition"
- ✅ NO "Basic data partition"
- ✅ Shows Talos partitions (EFI, META, STATE, EPHEMERAL)

#### Check Services Status
```bash
talosctl --nodes <NODE_IP> services
```

**Expected Services (All Running OK):**
- ✅ **apid** - Talos API server
- ✅ **containerd** - Container runtime
- ✅ **kubelet** - Kubernetes node agent
- ✅ **machined** - Talos machine service
- ✅ **trustd** - Certificate management
- ✅ **etcd** - Database (control plane only, may show "Preparing")

---

### 📝 **Phase 8: Document Node**

#### Update Node Tracking
```bash
# For control plane nodes
echo "Node X (Control Plane): <NODE_IP> - Status: ✅ Operational $(date +%Y-%m-%d)" >> ~/talos-cluster/all-node-ips.txt

# For worker nodes
echo "Node X (Worker): <NODE_IP> - Status: ✅ Operational $(date +%Y-%m-%d)" >> ~/talos-cluster/all-node-ips.txt
```

#### Update Talos Endpoints
```bash
# Add node to talosctl endpoints (add all configured nodes)
talosctl config endpoint 10.69.1.101 10.69.1.140 10.69.1.147 <NODE_IP>
```

---

## Process Summary - Quick Reference

### The 8-Phase Process

1. **Boot to Maintenance Mode** - USB boot (F7)
2. **Verify Maintenance Mode** - Check API and disk layout
3. **Wipe NVMe** - `talosctl wipe disk nvme0n1`
4. **🔴 REMOVE USB DRIVE** - **CRITICAL STEP**
5. **Apply Configuration** - Control plane or worker config
6. **Wait for Installation** - 90 seconds for install + reboot
7. **Verify Success** - Check system disk = nvme0n1
8. **Document Node** - Update tracking files

### Critical Success Factors

✅ **Configuration files** must target `/dev/nvme0n1`  
✅ **Wipe NVMe** before applying config  
✅ **REMOVE USB** before applying config ← Most important!  
✅ **Verify system disk** shows `nvme0n1` not `sda`

---

## Troubleshooting

### Issue 1: System Disk Shows `sda` Instead of `nvme0n1`

**Symptoms:**
```bash
talosctl get systemdisk
# Shows: sda (USB) instead of nvme0n1
```

**Root Cause:**
- USB drive was still inserted when configuration was applied
- Talos installed to USB instead of NVMe

**Solution:**
1. Reboot node to maintenance mode (USB boot)
2. Wipe NVMe: `talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>`
3. **REMOVE USB DRIVE** ← Don't skip this!
4. Apply configuration again
5. Verify system disk shows `nvme0n1`

**Prevention:**
- Always remove USB in Phase 4 before applying config
- Double-check USB is physically removed
- Wait a few seconds after removal before applying config

---

### Issue 2: Windows Still Present After Installation

**Symptoms:**
- `get discoveredvolumes` shows "Microsoft reserved partition"
- Windows partitions still visible on NVMe

**Root Cause:**
- NVMe wipe step (Phase 3) was skipped
- Or configuration applied before wipe completed

**Solution:**
1. Boot to maintenance mode
2. **Manually wipe NVMe:**
   ```bash
   talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>
   ```
3. Verify wipe: `talosctl get discoveredvolumes --insecure --nodes <NODE_IP> | grep nvme`
4. Should show only the disk, no partitions
5. Remove USB and apply config

---

### Issue 3: Certificate Errors

**Symptoms:**
```
x509: certificate signed by unknown authority
```

**Root Cause:**
- Node has old Talos installation with different certificates

**Solution:**
- Boot to maintenance mode (accepts `--insecure`)
- Follow the full 8-phase process
- Fresh installation will use current certificates

---

### Issue 4: API Not Responding

**Symptoms:**
- Port 50000 connection refused
- Cannot connect to node after installation

**Possible Causes:**
1. **Services still starting** (normal for first 2-3 minutes)
2. **Booted to Windows** (wipe failed)
3. **Network issue**

**Solutions:**
1. **Wait longer** - First boot can take 5 minutes
2. **Check ping** - If ping works, services are starting
3. **Check screen** - Should show Talos boot messages, not Windows
4. **After 5 minutes:** Reboot to maintenance mode and repeat process

---

### Issue 5: Node Boots to Windows

**Symptoms:**
- After reboot, node shows Windows login screen
- No Talos boot

**Root Cause:**
- Windows wipe failed or was skipped
- Installation never completed to NVMe

**Solution:**
1. Shut down Windows
2. Insert USB drive
3. Boot from USB (F7)
4. **Follow Phase 3** (wipe NVMe)
5. **Follow Phase 4** (remove USB)
6. **Continue** with remaining phases

---

## Lessons Learned

### From Nodes 1-4 Successful Installations

**🔑 Most Important Discovery:**
The USB drive **must be physically removed** before applying configuration. Even with correct config files targeting `/dev/nvme0n1`, Talos will prefer the USB if it's present during installation.

**Key Insights:**

1. **Manual NVMe Wipe is Essential**
   - Don't rely on `wipe: true` in config alone
   - Always run: `talosctl wipe disk nvme0n1`
   - Verify wipe completed before proceeding

2. **USB Removal Timing is Critical**
   - Remove USB AFTER wiping NVMe
   - Remove USB BEFORE applying config
   - Never skip this step

3. **System Disk Verification is Mandatory**
   - Always verify: `talosctl get systemdisk`
   - MUST show `nvme0n1`, not `sda`
   - If wrong, repeat the process

4. **Configuration Files**
   - Both controlplane.yaml and worker.yaml needed correction
   - Both must have: `disk: /dev/nvme0n1` and `wipe: true`
   - Generate with: `talosctl gen config my-cluster https://10.69.1.101:6443`

5. **Wait Times Matter**
   - Installation: 30 seconds
   - Reboot: 30 seconds  
   - Services start: 2-3 minutes
   - Total: ~5 minutes per node

6. **Network Boot vs USB Boot**
   - Nodes can boot to maintenance mode via network (PXE)
   - But USB boot is more reliable for initial setup
   - After installation, nodes boot from NVMe without USB

---

## Cluster Status

### Completed Nodes: 4/6 (66%)

**Node 1 (Control Plane) ✅**
- IP: 10.69.1.101
- System Disk: nvme0n1
- Services: All healthy
- Configured: 2025-10-03

**Node 2 (Control Plane) ✅**
- IP: 10.69.1.140
- System Disk: nvme0n1
- Services: All healthy
- Configured: 2025-10-03

**Node 3 (Control Plane) ✅**
- IP: 10.69.1.147
- System Disk: nvme0n1
- Services: All healthy
- Configured: 2025-10-03

**Node 4 (Worker) ✅**
- IP: 10.69.1.151
- System Disk: nvme0n1
- Services: All healthy
- Configured: 2025-10-03
- **First worker node successfully configured**

### Pending Nodes: 2/6

**Node 5 (Worker)** ⏸️
- IP: 10.69.1.197 (assigned by DHCP)
- Status: Ready for configuration
- Estimated time: 15 minutes

**Node 6 (Worker)** ⏸️
- IP: 10.69.1.179 (assigned by DHCP)
- Status: Ready for configuration
- Estimated time: 15 minutes

---

## Next Steps

### Configure Remaining Worker Nodes (5-6)

**Process for Each Node:**
1. Follow the 8-phase process exactly
2. Use `worker.yaml` configuration
3. **Remember to remove USB in Phase 4**
4. Verify system disk shows `nvme0n1`
5. Total time: ~30 minutes for both nodes

### After All Nodes Configured

#### 1. Bootstrap Cluster
```bash
# Run ONCE on first control plane node
talosctl bootstrap --nodes 10.69.1.101
```

#### 2. Get Kubernetes Config
```bash
talosctl kubeconfig --nodes 10.69.1.101
```

#### 3. Verify Cluster
```bash
kubectl get nodes -o wide
# Should show all 6 nodes in "Ready" state
```

#### 4. Deploy Applications
- Follow PRD.md for application deployment
- Configure MetalLB load balancer (10.69.1.150-160)
- Deploy media server stack

---

## Quick Reference Commands

### Essential Commands

```bash
# Set environment
export TALOSCONFIG=~/talos-cluster/talosconfig

# Verify maintenance mode
talosctl get discoveredvolumes --insecure --nodes <NODE_IP>

# Wipe NVMe (removes Windows)
talosctl wipe disk nvme0n1 --insecure --nodes <NODE_IP>

# Apply control plane config
talosctl apply-config --insecure --nodes <NODE_IP> --file ~/talos-cluster/controlplane.yaml

# Apply worker config
talosctl apply-config --insecure --nodes <NODE_IP> --file ~/talos-cluster/worker.yaml

# Verify system disk (MUST show nvme0n1)
talosctl --nodes <NODE_IP> get systemdisk

# Check services
talosctl --nodes <NODE_IP> services

# Update endpoints
talosctl config endpoint 10.69.1.101 10.69.1.140 10.69.1.147 10.69.1.151
```

### Node IPs Quick Reference
```
Control Plane Nodes:
- Node 1: 10.69.1.101 ✅
- Node 2: 10.69.1.140 ✅
- Node 3: 10.69.1.147 ✅

Worker Nodes:
- Node 4: 10.69.1.151 ✅
- Node 5: 10.69.1.197 ⏸️
- Node 6: 10.69.1.179 ⏸️
```

---

## Verification Checklist

Use this for each node:

**Pre-Installation:**
- [ ] USB drive inserted
- [ ] Booted from USB (F7)
- [ ] In maintenance mode (API responds to `--insecure`)
- [ ] IP address noted

**Installation:**
- [ ] NVMe wiped (`talosctl wipe disk nvme0n1`)
- [ ] Windows partitions removed (verified)
- [ ] **USB drive physically removed** ← CRITICAL
- [ ] Configuration applied (controlplane or worker)

**Post-Installation:**
- [ ] Node rebooted automatically
- [ ] Responds to ping (< 20ms)
- [ ] Port 50000 open (Talos API)
- [ ] `talosctl version` succeeds (no certificate errors)
- [ ] **System disk is `nvme0n1`** ← CRITICAL CHECK
- [ ] NO Windows partitions on NVMe
- [ ] All services show "Running" and "OK"
- [ ] Node IP documented in tracking file
- [ ] Node added to talosctl endpoints

---

## Support and References

### Official Documentation
- Talos Linux: https://www.talos.dev/
- Kubernetes: https://kubernetes.io/

### Project Files
- **This playbook:** `TALOS_INSTALLATION_PLAYBOOK.md`
- **Configuration:** `~/talos-cluster/`
- **Node tracking:** `~/talos-cluster/all-node-ips.txt`

### Hardware
- **Model:** Beelink SER5
- **Storage:** 512GB NVMe SSD
- **Network:** Gigabit Ethernet with PXE support

---

**End of Playbook**

*This playbook represents the proven process after successfully configuring 4 nodes (Nodes 1-4) and resolving multiple installation challenges. The USB removal step in Phase 4 was the critical discovery that ensured reliable NVMe installation.*

**Key Success Metric:** 100% success rate on Nodes 3-4 after implementing the 8-phase process with USB removal.
