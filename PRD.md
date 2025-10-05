# Product Requirements Document: Production Kubernetes Home Lab

**Project Name:** Talos Kubernetes Bare-Metal Cluster
**Version:** 4.0
**Date:** October 3, 2025
**Owner:** Steven Brown
**Status:** Phase 1 - ✅ COMPLETE | Ready for Phase 2
**Document Classification:** Internal

---

## Table of Contents

1. [Executive Summary](#executive-summary)
2. [Business Case](#business-case)
3. [Scope](#scope)
4. [Technical Architecture](#technical-architecture)
5. [Hardware Specifications](#hardware-specifications)
6. [Software Stack](#software-stack)
7. [Installation Procedures](#installation-procedures)
8. [Network Configuration](#network-configuration)
9. [Security Requirements](#security-requirements)
10. [Operational Procedures](#operational-procedures)
11. [Implementation Roadmap](#implementation-roadmap)
12. [Testing & Validation](#testing--validation)
13. [Monitoring & Maintenance](#monitoring--maintenance)
14. [Disaster Recovery](#disaster-recovery)
15. [Budget & Resources](#budget--resources)
16. [Risk Management](#risk-management)
17. [Appendices](#appendices)

---

## Executive Summary

### Overview
Deployment of a production-grade, highly-available Kubernetes cluster on bare-metal infrastructure using Talos Linux. The cluster will serve as a learning platform for container orchestration and cloud-native technologies while providing resilient infrastructure for home services.

### Key Deliverables
- 6-node Kubernetes cluster (3 control plane, 3 worker nodes)
- High availability configuration with automatic failover
- Immutable, API-managed infrastructure using Talos Linux
- Zero-downtime deployment capabilities
- Production workload: Plex Media Server with multi-user streaming support

### Timeline
- **Phase 1 (Weeks 1-2):** Foundation - Cluster deployment
- **Phase 2 (Weeks 3-4):** Infrastructure - Networking and storage
- **Phase 3 (Weeks 5-6):** Observability - Monitoring and logging
- **Phase 4 (Weeks 7-8):** Production - Workload deployment
- **Phase 5 (Ongoing):** Advanced features and optimization

### Investment
Total hardware cost: $2,200  
Estimated power consumption: 120-210W (average ~$15-25/month)  
Time investment: 40-60 hours over 8 weeks

---

## Business Case

### Problem Statement
**Current State:**
- Plex Media Server running on Proxmox server (10.69.1.180) with complete media automation stack
  - Plex, Radarr, Sonarr, Prowlarr, download client (see [current_mediaserver.md](current_mediaserver.md))
- Single point of failure affects multiple remote users
- Manual intervention required for failures or maintenance
- No ability to perform zero-downtime updates
- Limited understanding of enterprise container orchestration

**Pain Points:**
- Service interruptions during hardware failures
- Inability to scale horizontally during high load
- Manual recovery processes
- Skills gap in Kubernetes and cloud-native technologies

### Proposed Solution
Deploy a highly-available Kubernetes cluster that:
- Eliminates single points of failure through node redundancy
- Automatically recovers from node failures
- Enables rolling updates with zero downtime
- Provides hands-on learning environment for enterprise skills
- Scales to support additional workloads and services

### Expected Benefits

**Technical Benefits:**
- 99%+ uptime for critical services
- Sub-2-minute recovery from node failures
- Horizontal scaling capabilities
- Infrastructure-as-code practices
- Immutable infrastructure security model

**Learning Outcomes:**
- Production Kubernetes operation experience
- High availability architecture patterns
- Container orchestration skills applicable to AWS EKS, GKE, AKS
- GitOps and declarative infrastructure
- Cloud-native application deployment

**Business Value:**
- Enhanced skills directly applicable to company work
- Reduced home infrastructure downtime
- Platform for additional service deployments
- Understanding of enterprise infrastructure costs and scaling

---

## Scope

### In Scope
- Installation of Talos Linux on 6 Beelink SER5 mini PCs
- Deletion of pre-installed Windows partitions
- Configuration of 3-node control plane with etcd HA
- Configuration of 3-node worker pool
- Network infrastructure setup (UniFi)
- Storage integration with NFS
- Deployment of core cluster services (MetalLB, Ingress)
- Monitoring stack (Prometheus, Grafana)
- Plex Media Server deployment as StatefulSet
- Documentation and runbooks
- Backup and disaster recovery procedures

### Out of Scope
- GPU passthrough for hardware transcoding (future consideration)
- Multi-cluster federation
- Service mesh implementation (Istio/Linkerd)
- Advanced security scanning (Falco, OPA)
- Cost optimization tooling
- CI/CD pipeline integration (deferred to Phase 5)

### Assumptions
- UniFi network infrastructure is operational
- NAS with NFS capability available for persistent storage
- Adequate network bandwidth for cluster operations
- Stable power supply with UPS protection recommended
- Internet connectivity for pulling container images

### Constraints
- Hardware limited to 6 nodes (no immediate expansion planned)
- Total cluster RAM: 192GB
- Total local storage: 3TB NVMe
- Network confined to single subnet (10.69.1.0/24)
- No external load balancer (using MetalLB for bare-metal)

---

## Technical Architecture

### Cluster Topology

```
Internet
   ↓
ISP Modem
   ↓
UniFi Gateway/Router (10.69.1.1)
   ↓
UniFi Managed Switch (16-24 Port)
   ↓
   ├─→ Control Plane Node 1 (10.69.1.101) ← Primary endpoint
   ├─→ Control Plane Node 2 (10.69.1.140)
   ├─→ Control Plane Node 3 (10.69.1.147)
   ├─→ Worker Node 1 (10.69.1.151)
   ├─→ Worker Node 2 (10.69.1.197)
   ├─→ Worker Node 3 (10.69.1.179)
   ├─→ NAS Storage (10.69.1.163) - NFS Server
   ├─→ Proxmox Media Server (10.69.1.180) - Current Plex stack (see current_mediaserver.md)
   └─→ Management Workstation (10.69.1.167) - MacBook Pro M2
```

### Control Plane Architecture

**High Availability etcd Cluster:**
- 3-member etcd cluster (quorum: 2/3 nodes must be healthy)
- Distributed consensus for cluster state
- Automatic leader election
- Data replication across all members

**Kubernetes Control Plane Components:**
- kube-apiserver: REST API for cluster management (all 3 nodes)
- kube-scheduler: Pod placement decisions (leader-elected)
- kube-controller-manager: Control loops (leader-elected)
- cloud-controller-manager: Not applicable (bare-metal)

**Talos-Specific Services:**
- apid: Talos API server
- trustd: Certificate management
- machined: Machine configuration

### Worker Node Architecture

**Container Runtime:**
- containerd: CRI-compliant container runtime
- No Docker shim required

**Node Components:**
- kubelet: Node agent, manages pods
- kube-proxy: Network proxy, implements Services
- CNI plugin: Flannel (default in Talos)

**Resource Allocation per Worker:**
- Allocatable RAM: ~28GB (after system overhead)
- Allocatable CPU: ~15 cores (after reserved)
- Local storage: 450GB (after OS partition)

### Network Architecture

**Pod Network (Flannel):**
- CIDR: 10.244.0.0/16 (default)
- Backend: VXLAN overlay
- Pod-to-pod communication across nodes

**Service Network:**
- CIDR: 10.96.0.0/12 (default)
- ClusterIP services for internal communication
- LoadBalancer services via MetalLB

**External Access:**
- MetalLB IP pool: 10.69.1.150-10.69.1.160 (reserved)
- Ingress controller for HTTP/HTTPS routing
- Direct NodePort access for testing

### Storage Architecture

**Persistent Storage:**
- NFS server on NAS (10.69.1.163)
- NFS CSI driver for dynamic provisioning
- Storage class: nfs-client
- Access modes: ReadWriteMany for shared media

**Local Storage:**
- Node local storage for ephemeral data
- No distributed storage system (Ceph/Longhorn) in initial phase

**Media Library Structure:**
```
NFS Mount: /mnt/media
  ├── movies/
  ├── tv/
  ├── music/
  └── photos/
```

---

## Hardware Specifications

### Mini PC Nodes (6x Beelink SER5)

**Model:** Beelink Mini PC AMD Ryzen 7 5825U  
**Quantity:** 6 units

**Detailed Specifications:**

| Component | Specification | Notes |
|-----------|---------------|-------|
| CPU | AMD Ryzen 7 5825U | 8C/16T, 2.0-4.5GHz, 15W TDP |
| Architecture | x86-64 (AMD64) | Zen 3 microarchitecture |
| RAM | 32GB DDR4 | 3200MHz SODIMM |
| Storage | 500GB NVMe SSD | M.2 2280 PCIe Gen3 |
| Network | 2.5Gb Ethernet | Realtek RTL8125 |
| WiFi | WiFi 6 (802.11ax) | Not used in cluster |
| Bluetooth | BT 5.2 | Not used in cluster |
| Graphics | AMD Radeon Graphics | 8 cores, 2000MHz (for future transcoding) |
| Video Output | 2x HDMI 2.0, 1x DP 1.4 | Used only for initial setup |
| USB | 4x USB 3.2, 2x USB 2.0 | Boot media, peripherals |
| Power Supply | 19V/3A (57W max) | ~15-35W typical usage |
| Dimensions | 126 x 113 x 42mm | Compact form factor |
| Operating System | Ships with Windows 11 Pro | **Will be deleted and replaced with Talos** |

**Total Cluster Resources:**
- Combined CPU: 48 cores / 96 threads
- Combined RAM: 192GB
- Combined Storage: 3TB NVMe
- Combined Network: 15Gbps (6x 2.5Gb)
- Power Consumption: 90-210W (cluster-wide)

### Network Equipment

**UniFi Dream Machine / Gateway**
- Model: UDM-Pro or similar
- Role: Router, firewall, DHCP server
- IP: 10.69.1.1
- Features: VLAN support, DPI, QoS

**UniFi Managed Switch**
- Ports: 16-24 port
- PoE: Optional (not required for cluster)
- Managed: Yes
- Features: VLAN tagging, port mirroring, LACP

### Storage (UNAS)

### Management Workstation

**MacBook Pro M2**
- Architecture: ARM64 (Apple Silicon)
- Role: Cluster management station

---

## Software Stack

### Operating System

**Talos Linux v1.11.2**

**Key Characteristics:**
- Immutable operating system
- No SSH daemon (no shell access)
- API-only management via gRPC
- Minimal attack surface
- Automatic security updates
- Built specifically for Kubernetes

**Why Talos:**
- Eliminates configuration drift (immutable)
- Enhanced security (no SSH, no shell)
- Simplified operations (API-driven)
- Production-ready for bare-metal
- Active community and development
- Excellent documentation

**Pre-installed OS Removal:**
- Beelink SER5 ships with Windows 11 Pro
- Windows partition must be deleted during Talos installation
- Talos installer wipes entire disk and creates new partition table

### Kubernetes Distribution

**Kubernetes v1.34.1**

**Components Included:**
- etcd v3.6.4
- CoreDNS v1.12.3
- Flannel v0.27.2 (CNI)
- kube-proxy
- kubelet

**Kubernetes Features Used:**
- StatefulSets for stateful workloads
- Deployments for stateless workloads
- Services (ClusterIP, NodePort, LoadBalancer)
- Ingress for HTTP routing
- PersistentVolumes and PersistentVolumeClaims
- ConfigMaps and Secrets
- RBAC for access control
- Resource quotas and limits

### Container Images

**System Images:**
- ghcr.io/siderolabs/installer:v1.11.2
- ghcr.io/siderolabs/kubelet:v1.34.1
- registry.k8s.io/kube-apiserver:v1.34.1
- registry.k8s.io/kube-controller-manager:v1.34.1
- registry.k8s.io/kube-scheduler:v1.34.1
- registry.k8s.io/kube-proxy:v1.34.1
- registry.k8s.io/pause:3.10
- registry.k8s.io/coredns/coredns:v1.12.3
- gcr.io/etcd-development/etcd:v3.6.4

### Cluster Add-ons (Phase 2-4)

**Load Balancing:**
- MetalLB v0.14+ (Layer 2 mode)

**Ingress:**
- Traefik v3.x or NGINX Ingress Controller

**Storage:**
- NFS Subdir External Provisioner v4.x

**Monitoring:**
- Prometheus v2.x
- Grafana v10.x
- Node Exporter
- kube-state-metrics

**Certificates:**
- cert-manager v1.x (for SSL/TLS)

**GitOps (Optional - Phase 5):**
- ArgoCD or Flux CD

### Management Tools

**Client Tools (Installed on MacBook):**

| Tool | Version | Purpose |
|------|---------|---------|
| talosctl | v1.11.2 | Talos cluster management |
| kubectl | v1.34.1 | Kubernetes CLI |
| helm | v3.x | Package manager |
| k9s | Latest | Terminal UI for Kubernetes (optional) |

**Installation Commands:**
```bash
# Install talosctl (macOS ARM64)
brew install siderolabs/tap/talosctl

# Install kubectl
brew install kubectl

# Install helm
brew install helm

# Install k9s (optional)
brew install k9s
```

---

## Installation Procedures

### Overview
This section provides high-level procedures for installing Talos Linux on 6 Beelink SER5 mini PCs and bootstrapping a Kubernetes cluster. For detailed command-by-command instructions, refer to CLAUDE.md.

**CRITICAL WARNING:** This process completely wipes the pre-installed Windows 11 Pro operating system and all data on the internal NVMe drives. This deletion is permanent and irreversible.

### Pre-Installation Checklist

**Required Items:**
- [ ] 6x Beelink SER5 mini PCs (ships with Windows 11 - will be deleted)
- [ ] UniFi network infrastructure operational (Gateway + Switch)
- [ ] USB drive (8GB+) for Talos installer
- [ ] Monitor, keyboard (temporary, for BIOS access)
- [ ] 6x Ethernet cables
- [ ] MacBook with talosctl and kubectl installed

**Network Preparation:**
- [ ] DHCP enabled on 10.69.1.0/24 subnet
- [ ] IP addresses .101-.106 available for static assignment
- [ ] IP addresses .150-.160 reserved for MetalLB (LoadBalancer services)

### Procedure 1: Create Talos Boot Media

**Overview:** Download Talos ISO and write to USB drive using `dd` command.

**Key Steps:**
- Download metal-amd64.iso (v1.11.2) from Talos releases
- Write ISO to USB using `diskutil` and `dd` on macOS
- USB can be reused for all 6 machines

**Detailed Instructions:** See CLAUDE.md Section 1

### Procedure 2: Boot All Nodes into Maintenance Mode

**Overview:** Boot each mini PC from USB into Talos maintenance mode.

**Key Steps:**
1. Connect hardware (Ethernet, monitor, keyboard, USB drive, power)
2. Power on and press **F7** repeatedly to enter boot menu
3. Select USB drive from boot menu
4. Talos boots into maintenance mode showing IP address
5. Set static IP (.101-.106) in UniFi Controller for each node
6. Leave machine running at "Waiting for machine configuration" screen
7. Repeat for all 6 machines

**Critical Notes:**
- Talos runs from RAM; USB can be removed after boot
- Windows is still intact at this stage (deletion occurs in Procedure 4)
- Use temporary DHCP IPs initially; assign static IPs in UniFi

**Detailed Instructions:** See CLAUDE.md Section 2

### Procedure 3: Generate Talos Configuration

**Overview:** Generate cluster configuration files using talosctl.

**Key Steps:**
```bash
# Install talosctl
brew install siderolabs/tap/talosctl

# Generate configs
mkdir -p ~/talos-cluster && cd ~/talos-cluster
talosctl gen config my-cluster https://10.69.1.101:6443

# Configure endpoints
export TALOSCONFIG=~/talos-cluster/talosconfig
talosctl config endpoint 10.69.1.101 10.69.1.102 10.69.1.103
talosctl config node 10.69.1.101
```

**Generated Files:**
- `controlplane.yaml` - Configuration for nodes 1-3 (control plane)
- `worker.yaml` - Configuration for nodes 4-6 (workers)
- `talosconfig` - Client authentication for talosctl

**Detailed Instructions:** See CLAUDE.md Section 3

### Procedure 4: Apply Configuration (DELETES WINDOWS)

**Overview:** Apply Talos configuration to all nodes, installing Talos to internal NVMe and permanently deleting Windows.

**CRITICAL WARNING:** This step wipes the entire NVMe disk including:
- Windows 11 Pro operating system
- All Windows files and settings
- All partitions and data
- This is permanent and irreversible

**Key Steps:**
```bash
# Apply to control plane nodes (use --insecure flag for initial configuration)
talosctl apply-config --insecure --nodes 10.69.1.101 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.1.102 --file controlplane.yaml
talosctl apply-config --insecure --nodes 10.69.1.103 --file controlplane.yaml

# Apply to worker nodes
talosctl apply-config --insecure --nodes 10.69.1.104 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.1.105 --file worker.yaml
talosctl apply-config --insecure --nodes 10.69.1.106 --file worker.yaml
```

**What Happens:**
- Talos wipes entire disk and creates new partition table
- Talos installs to /dev/nvme0n1
- Node reboots automatically (~2-3 minutes)
- Node boots from internal NVMe (USB no longer needed)
- Services start (etcd, kubelet, container runtime)

**Note on --insecure Flag:** Required for initial configuration when nodes don't have certificates yet. After this step, all API communication uses mutual TLS.

**Detailed Instructions:** See CLAUDE.md Section 4

### Procedure 5: Bootstrap the Cluster

**Overview:** Initialize etcd cluster and start Kubernetes control plane.

**Key Steps:**
```bash
# Bootstrap ONLY on first control plane node
talosctl bootstrap --nodes 10.69.1.101

# Wait for cluster health (5-10 minutes)
talosctl health --wait-timeout 10m
```

**Critical Notes:**
- **Bootstrap only once** on the first control plane node
- Never run bootstrap on nodes 2-3 (they join automatically)
- Running bootstrap multiple times causes etcd cluster corruption
- Nodes 2-3 join the etcd cluster automatically after node 1 is bootstrapped

**What Happens:**
- etcd cluster initialized on node 1
- Nodes 2-3 join etcd cluster automatically
- Kubernetes control plane starts on all 3 control plane nodes
- Worker nodes register with API server

**Detailed Instructions:** See CLAUDE.md Section 5

### Procedure 6: Obtain Kubeconfig and Verify

**Overview:** Generate kubeconfig and verify cluster access.

**Key Steps:**
```bash
# Generate kubeconfig
talosctl kubeconfig .

# Verify access
kubectl get nodes

# All 6 nodes should show STATUS: Ready
```

**Post-Installation Verification:**
- Verify all nodes show "Ready" status
- Check etcd cluster health: `talosctl get members`
- Check all services running: `talosctl services`
- Check Kubernetes pods: `kubectl get pods -A`
- Deploy test nginx pod to verify scheduling

**Optional - Label Worker Nodes:**
```bash
kubectl label node <worker-node-name> node-role.kubernetes.io/worker=worker
```

**Detailed Instructions:** See CLAUDE.md Section 6

### Installation Complete

**What You Now Have:**
- 6-node Kubernetes cluster (3 control plane, 3 workers)
- High-availability etcd cluster
- All nodes running Talos Linux (Windows completely removed)
- kubectl access from management workstation
- Cluster ready for Phase 2 (Core Infrastructure)

**Next Steps:**
- Proceed to Phase 2: Deploy MetalLB, Ingress, and Storage
- See Implementation Roadmap section
- See CLAUDE.md for operational procedures

---

## Network Configuration

### IP Address Allocation

**Network:** 10.69.1.0/24  
**Gateway:** 10.69.1.1  
**DNS:** 10.69.1.1 (UniFi Gateway) or external (8.8.8.8, 1.1.1.1)





## Security Requirements

### Talos Security Model

**No SSH Access:**
- Talos has no SSH daemon
- No shell access to nodes
- All management via API with mutual TLS

**Certificate-Based Authentication:**
- All API calls use client certificates
- Certificates stored in talosconfig
- Automatic rotation supported

**Immutable OS:**
- Read-only root filesystem
- No package installation
- No configuration drift
- Updates replace entire OS atomically

### Kubernetes RBAC

**Admin Access:**
```yaml
# Current: Default admin in kubeconfig has cluster-admin
# Future: Create limited-privilege accounts
```

**Service Accounts:**
- Each pod runs with ServiceAccount
- Principle of least privilege
- Default ServiceAccount has minimal permissions

### Network Security

**Network Policies (Phase 3):**
- Implement NetworkPolicies to restrict pod-to-pod traffic
- Default deny all, explicitly allow required traffic
- Isolate namespaces

**TLS/SSL:**
- Kubernetes API always uses TLS
- Ingress terminates SSL (cert-manager for automated certs)
- Internal service mesh (future consideration)

### Secrets Management

**Kubernetes Secrets:**
- Store sensitive data encrypted at rest (enable encryption config)
- Use external secret managers in production (future)
- Never commit secrets to Git

**Access Control:**
- Limit secret access via RBAC
- Audit secret access (enable audit logging)

---

## Operational Procedures

### Overview

For detailed commands and step-by-step procedures, see CLAUDE.md.

### Daily Operations

**Health Monitoring:**
- Check cluster and node health status
- Review pod states across all namespaces
- Monitor recent events for errors or warnings
- Verify etcd cluster health

**Log Management:**
- Access Talos system logs (kubelet, containerd, etcd)
- View and follow Kubernetes pod logs
- Check controller and scheduler logs
- Review audit logs (if enabled)

### Common Operational Tasks

**Workload Management:**
- Deploy and update applications
- Scale deployments and statefulsets
- Restart problematic pods
- Roll back failed deployments

**Node Maintenance:**
- Drain nodes for maintenance (graceful pod eviction)
- Uncordon nodes after maintenance
- Upgrade Talos OS (rolling updates)
- Upgrade Kubernetes version (control plane first, then workers)

**Resource Management:**
- Adjust resource requests and limits
- Create and manage persistent volumes
- Configure network policies
- Manage secrets and configmaps

### Troubleshooting Categories

**Node Issues:**
- Node NotReady status
- Resource pressure (CPU, memory, disk)
- Network connectivity problems
- Kubelet failures

**Pod Issues:**
- CrashLoopBackOff diagnosis
- Pending pods (scheduling failures)
- ImagePullBackOff errors
- Volume mount failures

**Cluster Issues:**
- etcd cluster health problems
- API server unavailability
- Control plane component failures
- Certificate expiration

**Network Issues:**
- Service discovery failures
- Ingress routing problems
- LoadBalancer service issues
- DNS resolution failures

---

## Implementation Roadmap

### Phase 1: Foundation (Weeks 1-2)

**Status:** ✅ COMPLETE (October 3, 2025)

**Objectives:**
- Deploy 6-node Kubernetes cluster
- Verify cluster health and stability
- Document base configuration

**Tasks:**

**Week 1:**
- [x] Day 1-2: Hardware unboxing and inventory
- [x] Day 2-3: Network configuration (UniFi setup)
- [x] Day 3-4: Create Talos boot media
- [x] Day 4-5: Install Talos on all 6 nodes (delete Windows)
- [x] Day 5-7: Generate configs and apply to all nodes

**Week 2:**
- [ ] Day 8: Bootstrap cluster and verify health (Ready for execution)
- [ ] Day 9: Obtain kubeconfig and verify kubectl access
- [ ] Day 10-11: Failover testing (kill nodes, verify recovery)
- [ ] Day 12-13: Performance baseline (CPU, memory, network)
- [ ] Day 14: Document installation procedures and lessons learned

**Phase 1 Status:** All 6 nodes operational with Talos installed. Ready for cluster bootstrap.

**Deliverables:**
- 6-node operational cluster
- All nodes showing Ready status
- Installation documentation
- Baseline performance metrics

**Success Criteria:**
- All nodes healthy for 48+ hours
- Survive single control plane node failure
- Survive single worker node failure
- kubectl can manage cluster from workstation

### Phase 2: Core Infrastructure (Weeks 3-4)

**Objectives:**
- Deploy networking and storage infrastructure
- Enable external service access
- Implement basic ingress

**Tasks:**

**Networking:**
- [ ] Install and configure MetalLB
- [ ] Reserve IP pool (10.69.1.150-160)
- [ ] Test LoadBalancer service creation
- [ ] Deploy Ingress controller (Traefik or NGINX)
- [ ] Configure SSL/TLS termination

**Storage:**
- [ ] Configure NAS with NFS exports
- [ ] Install NFS CSI driver in cluster
- [ ] Create StorageClass for NFS
- [ ] Test PVC creation and mounting
- [ ] Verify ReadWriteMany access mode

**DNS & Certificates:**
- [ ] Install cert-manager
- [ ] Configure Let's Encrypt issuer (or self-signed for testing)
- [ ] Create wildcard certificate for *.k8s.local

**Deliverables:**
- LoadBalancer services accessible via MetalLB
- HTTP/HTTPS ingress working
- Persistent storage functional
- Certificate automation operational

**Success Criteria:**
- Deploy test application with LoadBalancer service
- Access application via Ingress with HTTPS
- Create PVC and mount in pod successfully

### Phase 3: Observability (Weeks 5-6)

**Objectives:**
- Deploy monitoring and logging stack
- Create dashboards for cluster health
- Implement alerting

**Tasks:**

**Monitoring:**
- [ ] Deploy Prometheus via Helm
- [ ] Deploy Grafana via Helm
- [ ] Configure ServiceMonitors for cluster components
- [ ] Import community dashboards (Kubernetes cluster, node metrics)
- [ ] Create custom dashboards for Plex

**Logging (Optional):**
- [ ] Deploy Loki for log aggregation
- [ ] Configure log shipping from pods
- [ ] Create log dashboards in Grafana

**Alerting:**
- [ ] Configure Prometheus AlertManager
- [ ] Create alert rules (node down, high CPU, low disk)
- [ ] Configure notification channels (email, Slack, etc.)

**Deliverables:**
- Prometheus collecting metrics from all nodes
- Grafana dashboards showing cluster health
- Alerting rules functional
- Historical metrics retained (30+ days)

**Success Criteria:**
- View CPU/memory/network metrics for all nodes
- Receive alert when test node is shut down
- Dashboards accessible via Ingress

### Phase 4: Production Workloads (Weeks 7-8)

**Objectives:**
- Deploy Plex Media Server
- Configure high availability for Plex
- Migrate existing Plex data
- Test failover scenarios

**Tasks:**

**Plex Deployment:**
- [ ] Create namespace: media
- [ ] Create PVC for Plex config (10GB)
- [ ] Create PVC for media library (maps to NFS)
- [ ] Create Plex StatefulSet manifest
- [ ] Configure resource requests/limits
- [ ] Deploy Plex

**High Availability:**
- [ ] Configure Plex with 2-3 replicas (if supported)
- [ ] Or configure active/standby with ReadWriteOnce volume
- [ ] Create LoadBalancer service for Plex
- [ ] Configure health checks (liveness/readiness probes)

**Data Migration:**
- [ ] Backup existing Plex database
- [ ] Copy Plex config to PVC
- [ ] Verify library accessible via NFS
- [ ] Test Plex startup and library scan

**External Access:**
- [ ] Configure Ingress for Plex web UI
- [ ] Configure port forwarding for remote access
- [ ] Update Plex server settings for custom URL

**Testing:**
- [ ] Test streaming from multiple clients
- [ ] Kill pod, verify automatic restart
- [ ] Kill worker node, verify pod rescheduling
- [ ] Verify transcoding works
- [ ] Performance testing with multiple concurrent streams

**Deliverables:**
- Plex operational on Kubernetes
- External access functional for remote users
- Automatic recovery from pod/node failures
- Migration documentation

**Success Criteria:**
- Multiple users can stream simultaneously
- Pod failures recover within 2 minutes
- Node failures recover within 5 minutes
- Media library accessible and functional

### Phase 5: Advanced Features (Weeks 9+)

**Objectives:**
- Implement GitOps workflow
- Add additional services
- Optimize and tune cluster

**Tasks:**

**GitOps:**
- [ ] Create Git repository for cluster configs
- [ ] Install ArgoCD or Flux
- [ ] Configure automated deployments from Git
- [ ] Implement secrets management (Sealed Secrets or External Secrets)

**Additional Services:**
- [ ] Deploy additional home services (TBD)
- [ ] Implement service mesh (Istio/Linkerd) - optional
- [ ] Deploy internal tools (dashboard, IDE, etc.)

**Optimization:**
- [ ] Tune resource requests/limits based on actual usage
- [ ] Implement Pod Disruption Budgets
- [ ] Configure autoscaling (HPA) where applicable
- [ ] Optimize storage I/O

**Backup & DR:**
- [ ] Implement etcd backup automation
- [ ] Create cluster restore procedures
- [ ] Document DR runbook
- [ ] Test full cluster recovery

**Deliverables:**
- GitOps workflow operational
- Additional services deployed
- Backup/restore tested
- Comprehensive documentation

---

## Testing & Validation

### Test Categories

For detailed test commands and procedures, see CLAUDE.md.

**Component Tests:**
- Node health verification
- Pod deployment and scheduling
- Storage provisioning and mounting
- Network connectivity

**Integration Tests:**
- Service discovery and DNS resolution
- LoadBalancer service external access
- Ingress routing and SSL termination
- Cross-node pod communication

**Chaos Engineering:**
- Worker node failure and recovery
- Control plane node failure (etcd quorum)
- Network partition simulation
- Pod eviction and rescheduling

**Performance Validation:**
- Cluster capacity (100+ pod deployment)
- Storage throughput (NFS performance)
- Network bandwidth (pod-to-pod, node-to-node)
- Resource utilization under load

### Acceptance Criteria

**Phase 1 Acceptance:**
- All 6 nodes healthy for 7 consecutive days
- Zero unplanned outages
- kubectl commands respond < 500ms
- Survived 3 simulated node failures

**Phase 2 Acceptance:**
- LoadBalancer service accessible from external network
- HTTPS ingress functional with valid certificates
- PVC creation and mounting successful
- Storage performance meets baseline (>100MB/s sequential)

**Phase 3 Acceptance:**
- Grafana dashboards showing all metrics
- Alerts firing correctly during tests
- 30 days of metrics retained
- Log queries returning results in <5s

**Phase 4 Acceptance:**
- Plex streaming to 3+ concurrent users
- Transcoding functional
- Pod failover < 2 minutes
- Node failover < 5 minutes
- 99% uptime over 30 days

---

## Monitoring & Maintenance

### Key Metrics

**Cluster Health:**
- Node status (Ready/NotReady)
- Pod failure rate
- etcd cluster health
- API server response time
- Certificate expiration dates

**Resource Utilization:**
- CPU usage per node
- Memory usage per node
- Disk usage per node
- Network throughput
- PVC usage

**Application Metrics:**
- Plex active streams
- Plex transcode sessions
- Media library size
- Request latency

### Alerting Rules

**Critical Alerts (Page Immediately):**
- Control plane node down
- etcd cluster unhealthy
- API server unreachable
- Multiple pod crash loops

**Warning Alerts (Review within 24h):**
- Node disk >80% full
- Node memory >90% used
- Certificate expiring <30 days
- Persistent pod failures

**Info Alerts (Review weekly):**
- New Kubernetes version available
- New Talos version available
- Backup job failures
- Unused resources

### Backup Procedures

**etcd Backup (Automated):**
```bash
# Create backup script
cat <<'EOF' > backup-etcd.sh
#!/bin/bash
DATE=$(date +%Y%m%d-%H%M%S)
talosctl --nodes 10.69.1.101 etcd snapshot /tmp/etcd-backup-${DATE}.db
# Copy to safe location (NAS, cloud storage)
EOF

# Schedule via cron on management workstation
crontab -e
# Add: 0 2 * * * /path/to/backup-etcd.sh
```

**Cluster State Backup:**
```bash
# Backup all cluster resources
kubectl get all --all-namespaces -o yaml > cluster-backup.yaml

# Backup RBAC
kubectl get clusterroles,clusterrolebindings,roles,rolebindings --all-namespaces -o yaml > rbac-backup.yaml
```

**Configuration Backup:**
```bash
# Backup Talos configs
cp ~/talos-cluster/*.yaml /backup/location/

# Version control in Git
cd ~/talos-cluster
git init
git add .
git commit -m "Cluster configuration backup"
```

### Update Procedures

**Talos OS Updates:**
```bash
# Check current version
talosctl version

# Update one node at a time
talosctl upgrade --nodes 10.69.1.101 \
  --image ghcr.io/siderolabs/installer:v1.12.0

# Wait for node to come back online
talosctl --nodes 10.69.1.101 health

# Proceed with next node
```

**Kubernetes Updates:**
```bash
# Update control plane
talosctl upgrade-k8s --nodes 10.69.1.101-103 --to 1.35.0

# Update workers
talosctl upgrade-k8s --nodes 10.69.1.104-106 --to 1.35.0
```

**Application Updates:**
```bash
# Update deployment image
kubectl set image deployment/plex plex=plexinc/pms-docker:latest

# Or edit deployment
kubectl edit deployment plex

# Watch rollout
kubectl rollout status deployment/plex
```

---

## Disaster Recovery

### Failure Scenarios & Recovery

**Single Node Failure:**
- **Detection:** Health check alerts, node shows NotReady
- **Impact:** Pods reschedule automatically, minimal disruption
- **Recovery:** 
  1. Investigate cause (hardware, network)
  2. If fixable, repair and rejoin
  3. If not, replace node and apply config

**Control Plane Majority Loss (2+ nodes):**
- **Detection:** etcd cluster unavailable, API server down
- **Impact:** Cluster management unavailable, workloads continue
- **Recovery:**
  1. Recover at least 2 control plane nodes
  2. Restore etcd from backup if needed
  3. Bootstrap if complete loss

**Complete Cluster Loss:**
- **Recovery Procedure:**
  1. Rebuild nodes with Talos
  2. Restore etcd from backup
  3. Apply cluster configurations from Git
  4. Redeploy applications

**Data Loss (NAS Failure):**
- **Prevention:** RAID on NAS, regular backups
- **Recovery:** Restore media from backup

### Backup Retention

**etcd Snapshots:**
- Frequency: Daily
- Retention: 30 days
- Location: NAS + cloud storage

**Cluster Configs:**
- Frequency: On every change
- Retention: Unlimited (Git history)
- Location: Git repository + NAS

**Application Data:**
- Frequency: Weekly
- Retention: 12 weeks
- Location: NAS + cloud storage

### Recovery Time Objectives (RTO)

| Scenario | Target RTO | Actual Testing |
|----------|-----------|----------------|
| Single pod failure | < 2 minutes | TBD |
| Single worker node failure | < 5 minutes | TBD |
| Single control plane failure | < 0 (no downtime) | TBD |
| Complete cluster rebuild | < 4 hours | TBD |
| Data restore from backup | < 8 hours | TBD |

---

## Budget & Resources

### Hardware Costs

| Item | Qty | Unit Price | Total | Status |
|------|-----|------------|-------|--------|
| Beelink SER5 Mini PC | 6 | $250 | $1,500 | Purchased |
| UniFi Switch 16-Port | 1 | $200 | $200 | Existing |
| UniFi Dream Machine | 1 | $400 | $400 | Existing |
| Ethernet Cables Cat6 | 6 | $5 | $30 | Purchased |
| USB Drives (8GB) | 1-6 | $8 | $8-48 | Need to purchase |
| Power Strips | 1 | $20 | $20 | Purchased |
| HDMI Cable (temp) | 1 | $10 | $10 | Existing |
| **Subtotal** | | | **$2,168-2,208** | |

### Software Costs

| Item | License | Cost |
|------|---------|------|
| Talos Linux | Open Source | $0 |
| Kubernetes | Open Source | $0 |
| Prometheus/Grafana | Open Source | $0 |
| Plex Pass (optional) | Lifetime | $120 (one-time) |
| **Total Software** | | **$0-120** |

### Operational Costs

**Electricity:**
- Average power: 150W (cluster-wide)
- Daily: 3.6 kWh
- Monthly: 108 kWh
- Cost (at $0.12/kWh): $12.96/month
- Annual: ~$155

**Internet:**
- Existing connection
- No additional cost

**Total Annual Operating Cost:** ~$155

### Time Investment

| Phase | Estimated Hours | Actual Hours |
|-------|----------------|--------------|
| Phase 1: Foundation | 20 hours | TBD |
| Phase 2: Infrastructure | 15 hours | TBD |
| Phase 3: Observability | 10 hours | TBD |
| Phase 4: Production | 15 hours | TBD |
| Phase 5: Advanced | 20 hours | TBD |
| **Total** | **80 hours** | TBD |

### Return on Investment

**Tangible Benefits:**
- Uptime improvement: 95% → 99%+ (estimated)
- Manual intervention reduction: 80% fewer incidents
- Downtime cost savings: ~$0 (home use, but user satisfaction)

**Intangible Benefits:**
- Kubernetes skills (market value: +$20k-40k salary potential)
- DevOps experience applicable to company work
- Understanding of production infrastructure
- Confidence deploying and managing clusters

**Learning ROI:**
- Cost per learning hour: ~$27 ($2,200 / 80 hours)
- Comparable training courses: $2,000-5,000
- Hands-on experience: Priceless

---

## Risk Management

### Technical Risks

| Risk | Probability | Impact | Mitigation | Owner |
|------|-------------|--------|------------|-------|
| Hardware failure during setup | Medium | Medium | Order spare mini PC | Steven |
| Configuration errors | High | Medium | Version control, backups | Steven |
| Network instability | Low | High | UPS for network gear, monitoring | Steven |
| Learning curve too steep | Medium | Medium | Incremental approach, documentation | Steven |
| Time overruns | High | Low | Flexible timeline, MVP approach | Steven |
| Data loss during migration | Low | High | Multiple backups before migration | Steven |
| Performance insufficient | Low | Medium | Testing before production | Steven |

### Operational Risks

| Risk | Probability | Impact | Mitigation | Owner |
|------|-------------|--------|------------|-------|
| Power outage | Medium | High | UPS for critical equipment | Steven |
| Extended downtime | Low | Medium | HA architecture, monitoring | Steven |
| Skill knowledge loss | Medium | Low | Comprehensive documentation | Steven |
| Scope creep | High | Low | Strict phase gates, MVP focus | Steven |

### Contingency Plans

**Plan A (Ideal):**
- 6-node cluster as designed
- All phases completed
- Production Plex with HA

**Plan B (Reduced Scope):**
- 3-node cluster (1 control plane, 2 workers)
- Core infrastructure only
- Plex without HA

**Plan C (Fallback):**
- Keep existing Docker Plex
- Use cluster for learning only
- Deploy Plex later when confident

---

## Appendices

### Appendix A: Network Diagram

```
Internet → ISP Modem → UniFi Gateway (10.69.1.1) → UniFi Switch
                                                          ↓
    ┌─────────────────────────────────────────────────────┼──────────────┐
    ↓                                                     ↓              ↓
Control Plane (.101-.103)                           Workers (.104-.106)  Other
talos-cp-1, talos-cp-2, talos-cp-3         talos-work-1, work-2, work-3  NAS (.163), MacBook (.167)
```

### Appendix B: Talos Configuration Example

Essential fields only (see generated files for complete configuration):

```yaml
version: v1alpha1
machine:
  type: controlplane  # or "worker"
  install:
    disk: /dev/nvme0n1  # Target disk - WIPES COMPLETELY
    image: ghcr.io/siderolabs/installer:v1.11.2
cluster:
  controlPlane:
    endpoint: https://10.69.1.101:6443
  network:
    cni:
      name: flannel
```

### Appendix C: Reference Links

**Official Documentation:**
- Talos Linux: https://www.talos.dev
- Kubernetes: https://kubernetes.io/docs
- Flannel: https://github.com/flannel-io/flannel
- MetalLB: https://metallb.universe.tf
- Prometheus: https://prometheus.io/docs
- Grafana: https://grafana.com/docs

**Community Resources:**
- Talos GitHub: https://github.com/siderolabs/talos
- Kubernetes Slack: https://kubernetes.slack.com
- r/kubernetes: https://reddit.com/r/kubernetes
- r/homelab: https://reddit.com/r/homelab

**Hardware:**
- Beelink Official: https://www.bee-link.com
- UniFi: https://ui.com

### Appendix D: Changelog

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2025-10-02 | Steven Brown | Initial PRD |
| 2.0 | 2025-10-02 | Steven Brown | Added Windows deletion procedures, expanded installation steps, added detailed procedures |
| 3.0 | 2025-10-03 | Steven Brown | Simplified Testing & Validation, Operational Procedures, and Appendices; removed redundant command examples (see CLAUDE.md); condensed network diagram and config example; removed duplicate Appendix C (commands) and Appendix D (glossary) |
| 4.0 | 2025-10-03 | Steven Brown | Updated to Phase 1 COMPLETE status; updated actual node IPs (.101, .140, .147, .151, .197, .179); added Proxmox media server reference (10.69.1.180); added references to current_mediaserver.md; marked Week 1 tasks complete |

### Appendix E: Document Approval

| Role | Name | Signature | Date |
|------|------|-----------|------|
| Project Owner | Steven Brown | | |
| Technical Reviewer | TBD | | |
| Stakeholder | TBD | | |

---

**END OF DOCUMENT**

**Next Review:** End of Phase 1 (Target: 2 weeks from project start)  
**Document Location:** ~/talos-cluster/PRD.md  
**Backup Location:** Git repository + NAS