# UniFi VLAN Configuration for Media Network

## Overview
Creating dedicated VLAN 2 (10.69.2.0/24) for Kubernetes media cluster

## Step-by-Step UniFi Configuration

### 1. Create New Network (VLAN)
1. Log into UniFi Controller
2. Navigate to **Settings** → **Networks**
3. Click **Create New Network**
4. Configure:
   - **Name:** Media-Cluster
   - **VLAN ID:** 2
   - **Gateway/Subnet:** 10.69.2.1/24
   - **DHCP Mode:** DHCP Server
   - **DHCP Range:** 10.69.2.10 - 10.69.2.99
   - **Domain Name:** media.local (optional)
   - **Auto Scale Network:** Disabled

### 2. Configure DHCP Reservations
Navigate to **Settings** → **Networks** → **Media-Cluster** → **DHCP**

Add the following reservations:

#### Control Plane Nodes
| MAC Address | IP Address | Hostname | Notes |
|-------------|------------|----------|-------|
| [Node 1 MAC] | 10.69.2.101 | talos-cp-1 | Control Plane 1 |
| [Node 2 MAC] | 10.69.2.102 | talos-cp-2 | Control Plane 2 |
| [Node 3 MAC] | 10.69.2.103 | talos-cp-3 | Control Plane 3 |

#### Worker Nodes
| MAC Address | IP Address | Hostname | Notes |
|-------------|------------|----------|-------|
| [Node 4 MAC] | 10.69.2.104 | talos-worker-1 | Worker 1 |
| [Node 5 MAC] | 10.69.2.105 | talos-worker-2 | Worker 2 |
| [Node 6 MAC] | 10.69.2.106 | talos-worker-3 | Worker 3 |

#### Infrastructure
| Device | IP Address | Hostname | Notes |
|--------|------------|----------|-------|
| NAS/NFS | 10.69.2.163 | nas-media | Media storage |
| Management Workstation | 10.69.2.167 | macbook-mgmt | Admin access |

**Note:** Get MAC addresses from current DHCP leases on old VLAN

### 3. Configure Firewall Rules

#### Rule 1: Allow Management Access
- **Name:** Allow-Mgmt-to-Media
- **Type:** LAN In
- **Action:** Accept
- **Source:** Management VLAN (or specific workstation IP)
- **Destination:** Media-Cluster (10.69.2.0/24)
- **Port Group:** Any

#### Rule 2: Allow NFS Access (If NAS on different VLAN)
- **Name:** Allow-NFS-to-Media
- **Type:** LAN In
- **Action:** Accept
- **Source:** Media-Cluster (10.69.2.0/24)
- **Destination:** NAS IP
- **Port Group:** NFS (2049, 111)

#### Rule 3: Block Inter-VLAN (Security)
- **Name:** Block-Media-to-Other-VLANs
- **Type:** LAN In
- **Action:** Drop
- **Source:** Media-Cluster (10.69.2.0/24)
- **Destination:** !Media-Cluster (anything NOT 10.69.2.0/24)
- **Port Group:** Any
- **Logging:** Enabled

#### Rule 4: Allow Internet Access
- **Name:** Allow-Media-to-Internet
- **Type:** LAN In
- **Action:** Accept
- **Source:** Media-Cluster (10.69.2.0/24)
- **Destination:** Internet
- **Port Group:** Any

### 4. Assign Devices to VLAN

#### Option A: Port-Based Assignment (Recommended)
If using managed switch:
1. Navigate to **Devices** → [Your Switch]
2. Go to **Ports** tab
3. For each port connected to a Beelink node:
   - **Port Profile:** All
   - **Native VLAN:** Media-Cluster (2)
   - **Tagged VLANs:** None

#### Option B: Device-Based Assignment
If using UniFi DHCP:
1. Navigate to **Clients**
2. Find each Beelink node
3. Click device → **Settings** → **Network**
4. Set **Fixed IP Address** to new IP
5. Set **Network** to Media-Cluster (VLAN 2)

### 5. Verify Network Configuration

#### From UniFi Controller:
1. Check all 6 nodes show up in **Clients** on VLAN 2
2. Verify IP assignments are correct
3. Check **Insights** → **Traffic Routes** for connectivity

#### From Workstation:
```bash
# Test connectivity to new IPs
ping 10.69.2.101
ping 10.69.2.102
ping 10.69.2.103
ping 10.69.2.104
ping 10.69.2.105
ping 10.69.2.106

# Test NFS if on new subnet
ping 10.69.2.163
showmount -e 10.69.2.163
```

## MAC Address Discovery

Get current MAC addresses from old VLAN:
```bash
# From UniFi:
# Settings → Networks → [Old Network] → DHCP Leases

# Or from workstation while still on old VLAN:
for ip in 101 102 103 104 105 106; do
  echo -n "10.69.1.$ip: "
  arp 10.69.1.$ip | grep -o '[a-f0-9:]\{17\}'
done
```

Save these for DHCP reservations!

## Rollback Procedure

If issues occur:
1. Navigate to **Settings** → **Networks** → **Media-Cluster**
2. Click **Delete Network** (or just disable)
3. Devices will revert to previous VLAN assignments
4. Or manually reassign devices back to original VLAN

## Security Best Practices

1. ✅ Isolate media cluster from personal devices
2. ✅ Restrict management access to specific IPs
3. ✅ Block unnecessary inter-VLAN traffic
4. ✅ Enable firewall logging for auditing
5. ✅ Use different SSIDs for different VLANs (if WiFi)
6. ✅ Keep management VLAN separate

## Post-Configuration Checklist

- [ ] VLAN 2 created with 10.69.2.0/24
- [ ] DHCP configured (range: .10-.99, reservations: .100+)
- [ ] All 6 nodes have DHCP reservations
- [ ] NAS/NFS accessible on new subnet
- [ ] Firewall rules created and ordered correctly
- [ ] Management workstation can reach new subnet
- [ ] Nodes assigned to new VLAN
- [ ] Connectivity tested from workstation
- [ ] MAC addresses documented for reference
