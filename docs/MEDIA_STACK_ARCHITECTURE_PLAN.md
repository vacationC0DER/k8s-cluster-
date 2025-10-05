# Media Stack Architecture Plan: Option B (Multiple LoadBalancer IPs)

**Document Version:** 1.0
**Last Updated:** October 5, 2025
**Status:** Deployed and Operational

---

## Executive Summary

### Architecture Choice
This deployment uses **Option B: Multiple LoadBalancer IPs (One per Service)**, where each media stack service receives a dedicated external IP address from the MetalLB pool. This approach provides direct IP-based access to all services without requiring hostname-based routing or DNS configuration.

### Rationale Summary
Option B was chosen for this home lab environment due to:
1. **Simplicity:** Direct IP access without DNS dependencies
2. **Flexibility:** Each service independently accessible for testing and troubleshooting
3. **Isolation:** Service failures don't affect access to other services
4. **Protocol Support:** Native support for non-HTTP protocols (Plex port 32400, torrent ports)
5. **IP Availability:** Sufficient MetalLB pool capacity (16 IPs total)

### Current Deployment Status
**Phase 4 Complete** - All 8 media stack services deployed and operational:
- ✅ 8 services running with LoadBalancer IPs assigned
- ✅ 100% service-to-service API connectivity verified
- ✅ End-to-end download workflow operational (Overseerr → *arr → Download Client → Import)
- ✅ 50% MetalLB pool utilization (8/16 IPs used)

---

## Architecture Overview

### Network Topology

```
Internet / External Network
         │
         ├─ UniFi Router (10.69.1.1)
         │
         └─ Home LAN (10.69.1.0/24)
                │
                ├─ Management Workstation (10.69.1.167)
                │
                ├─ NAS Storage (10.69.1.163) - NFS Media Library
                │
                ├─ Kubernetes Cluster
                │  ├─ Control Plane: 10.69.1.101-103
                │  ├─ Workers: 10.69.1.104-106
                │  │
                │  ├─ Pod Network: 10.244.0.0/16 (Flannel VXLAN)
                │  ├─ Service Network: 10.96.0.0/12
                │  │
                │  └─ MetalLB LoadBalancer Pool: 10.69.1.150-165
                │     │
                │     ├─ NGINX Ingress: 10.69.1.150 (HTTP/HTTPS gateway)
                │     ├─ Grafana: 10.69.1.151 (monitoring)
                │     ├─ Prometheus: 10.69.1.152 (metrics)
                │     ├─ AlertManager: 10.69.1.153 (alerts)
                │     │
                │     └─ Media Stack (8 services):
                │        ├─ Plex: 10.69.1.154:32400
                │        ├─ Prowlarr: 10.69.1.155:9696
                │        ├─ Radarr: 10.69.1.156:7878
                │        ├─ Sonarr: 10.69.1.157:8989
                │        ├─ qBittorrent: 10.69.1.158:8080
                │        ├─ Lidarr: 10.69.1.159:8686
                │        ├─ Overseerr: 10.69.1.160:5055
                │        └─ SABnzbd: 10.69.1.161:8080
                │
                └─ Proxmox Server (10.69.1.180) - Legacy media stack
```

### MetalLB Configuration

**IP Address Pool:**
```yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.69.1.150-10.69.1.165  # 16 IPs total
```

**L2 Advertisement Mode:**
- MetalLB operates in Layer 2 mode (ARP/NDP)
- One worker node becomes the speaker for each LoadBalancer IP
- Automatic failover if speaker node fails
- Traffic flows: External Client → MetalLB Speaker → Service → Pod(s)

**Pool Capacity:**
- **Total IPs:** 16 (10.69.1.150-165)
- **Used IPs:** 12 (75%)
  - 4 infrastructure services (Ingress, Prometheus, Grafana, AlertManager)
  - 8 media stack services
- **Available IPs:** 4 (10.69.1.162-165)
- **Future Expansion:** Can extend to 10.69.1.166-170 if needed

### Service-to-Service Communication

**External Access Pattern:**
```
Home Network Device (e.g., MacBook)
    ↓ HTTP Request to 10.69.1.156:7878
MetalLB Speaker Node (L2 Advertisement)
    ↓ Forward to Cluster Service IP
Kubernetes Service (ClusterIP 10.100.232.134)
    ↓ Load Balance to Pod
Radarr Pod (10.244.x.x)
```

**Internal Communication Pattern (API Calls):**
```
Radarr Pod (10.244.x.x)
    ↓ DNS Query: prowlarr.media.svc.cluster.local
CoreDNS (resolves to ClusterIP 10.100.68.61)
    ↓ Direct Service-to-Service (no LoadBalancer)
Kubernetes Service (ClusterIP)
    ↓ Load Balance to Pod
Prowlarr Pod (10.244.x.x)
```

**Key Point:** Services communicate internally using Kubernetes DNS names, **not** LoadBalancer IPs. This avoids unnecessary network hops through MetalLB.

---

## IP Address Allocation

### Complete Service Mapping

| Service | LoadBalancer IP | Port | ClusterIP | Purpose |
|---------|----------------|------|-----------|---------|
| **Infrastructure** |
| ingress-nginx-controller | 10.69.1.150 | 80/443 | 10.102.48.8 | HTTP/HTTPS gateway |
| prometheus-grafana | 10.69.1.151 | 80 | 10.109.201.32 | Monitoring dashboards |
| prometheus-kube-prometheus-prometheus | 10.69.1.152 | 9090 | 10.109.146.225 | Metrics database |
| prometheus-kube-prometheus-alertmanager | 10.69.1.153 | 9093 | 10.107.37.251 | Alert manager |
| **Media Stack** |
| plex | 10.69.1.154 | 32400 | 10.107.32.85 | Media streaming server |
| prowlarr | 10.69.1.155 | 9696 | 10.100.68.61 | Indexer manager |
| radarr | 10.69.1.156 | 7878 | 10.100.232.134 | Movie management |
| sonarr | 10.69.1.157 | 8989 | 10.98.163.65 | TV show management |
| qbittorrent | 10.69.1.158 | 8080 | 10.108.216.93 | Torrent download client |
| lidarr | 10.69.1.159 | 8686 | 10.111.140.117 | Music management |
| overseerr | 10.69.1.160 | 5055 | 10.111.196.248 | Media request manager |
| sabnzbd | 10.69.1.161 | 8080 | 10.108.244.210 | Usenet download client |
| **Available** |
| (unassigned) | 10.69.1.162 | - | - | Future service |
| (unassigned) | 10.69.1.163 | - | - | Future service |
| (unassigned) | 10.69.1.164 | - | - | Future service |
| (unassigned) | 10.69.1.165 | - | - | Future service |

### MetalLB Pool Capacity Analysis

**Current Utilization:**
- **Infrastructure Services:** 4 IPs (25%)
- **Media Stack Services:** 8 IPs (50%)
- **Total Used:** 12 IPs (75%)
- **Available:** 4 IPs (25%)

**Future Expansion Capacity:**
Remaining IPs can accommodate:
- 4 additional LoadBalancer services within current pool
- Easy expansion to 10.69.1.166-170 (5 more IPs) by updating IPAddressPool
- UniFi DHCP typically ends at .149, so no conflicts up to .200+

**Expansion Commands:**
```bash
# Expand MetalLB pool if more IPs needed
kubectl patch ipaddresspool first-pool -n metallb-system --type='json' \
  -p='[{"op": "replace", "path": "/spec/addresses/0", "value": "10.69.1.150-10.69.1.170"}]'

# Verify expansion
kubectl get ipaddresspool -n metallb-system -o yaml
```

---

## Service Access Patterns

### External Access (Home Network)

**Direct IP Access from Any Device:**

```bash
# Plex Media Server
http://10.69.1.154:32400/web

# Prowlarr (Indexer Manager)
http://10.69.1.155:9696

# Radarr (Movies)
http://10.69.1.156:7878

# Sonarr (TV Shows)
http://10.69.1.157:8989

# qBittorrent (Torrent Client)
http://10.69.1.158:8080

# Lidarr (Music)
http://10.69.1.159:8686

# Overseerr (Request Manager)
http://10.69.1.160:5055

# SABnzbd (Usenet Client)
http://10.69.1.161:8080

# Monitoring
http://10.69.1.151         # Grafana
http://10.69.1.152:9090    # Prometheus
http://10.69.1.153:9093    # AlertManager
```

**Advantages:**
- No DNS configuration required
- No hostname-based virtual hosting
- Direct bookmarkable URLs
- Easy troubleshooting (ping/curl specific IPs)
- Each service independently accessible

**Browser Access:**
Simply enter the IP:port in any browser on the home network. Services are accessible from:
- Management workstation (MacBook)
- Desktop PCs
- Mobile devices on home WiFi
- Tablets
- Smart TVs (for Plex)

### Internal Service-to-Service (Kubernetes DNS)

**API Communication:**

Services communicate internally using Kubernetes DNS names, following the pattern:
```
<service-name>.<namespace>.svc.cluster.local:<port>
```

**Media Stack Internal URLs:**

```bash
# Prowlarr → *arr services (pushing indexers)
http://radarr.media.svc.cluster.local:7878
http://sonarr.media.svc.cluster.local:8989
http://lidarr.media.svc.cluster.local:8686

# *arr services → Prowlarr (indexer queries)
http://prowlarr.media.svc.cluster.local:9696

# *arr services → Download Clients
http://qbittorrent.media.svc.cluster.local:8080
http://sabnzbd.media.svc.cluster.local:8080

# *arr services → Overseerr (webhooks)
http://overseerr.media.svc.cluster.local:5055

# Overseerr → *arr services (submitting requests)
http://radarr.media.svc.cluster.local:7878
http://sonarr.media.svc.cluster.local:8989
```

**Why Not Use LoadBalancer IPs Internally?**

Using Kubernetes DNS names provides:
1. **No External Hop:** Direct pod-to-pod communication via ClusterIP
2. **Faster:** Avoids MetalLB speaker node routing
3. **Resilience:** Works even if MetalLB fails
4. **Standard Practice:** Kubernetes-native service discovery

**Testing Internal Connectivity:**
```bash
# From within any pod, test DNS resolution
kubectl exec -n media deployment/radarr -- nslookup prowlarr.media.svc.cluster.local

# Test HTTP connectivity
kubectl exec -n media deployment/radarr -- wget -O- http://prowlarr.media.svc.cluster.local:9696
```

### Port Mappings

**Standard Application Ports:**

| Service | Internal Port | External Port | Protocol | Notes |
|---------|--------------|---------------|----------|-------|
| Plex | 32400 | 32400 | HTTP | Web UI + API |
| Prowlarr | 9696 | 9696 | HTTP | Web UI + API |
| Radarr | 7878 | 7878 | HTTP | Web UI + API |
| Sonarr | 8989 | 8989 | HTTP | Web UI + API |
| qBittorrent | 8080 | 8080 | HTTP | Web UI + API |
| Lidarr | 8686 | 8686 | HTTP | Web UI + API |
| Overseerr | 5055 | 5055 | HTTP | Web UI + API |
| SABnzbd | 8080 | 8080 | HTTP | Web UI + API |

**Additional Exposed Ports:**

```yaml
# qBittorrent - Torrent peer connectivity
- port: 6881-6889
  protocol: TCP
  targetPort: 6881-6889

- port: 6881-6889
  protocol: UDP
  targetPort: 6881-6889

# Plex - Additional streaming/discovery ports (if needed)
- port: 1900
  protocol: UDP
  targetPort: 1900  # DLNA discovery

- port: 5353
  protocol: UDP
  targetPort: 5353  # Bonjour/Avahi discovery

- port: 8324
  protocol: TCP
  targetPort: 8324  # Plex Companion
```

---

## Comparison: Option A vs Option B

### Option A: Single Ingress with Multiple Hostnames

**Architecture:**
```
All Services → NGINX Ingress (10.69.1.150) → Hostname-based routing
  - radarr.k8s.home → Radarr service
  - sonarr.k8s.home → Sonarr service
  - plex.k8s.home → Plex service (except port 32400 needs separate LB)
```

**Advantages:**
- Uses only 1-2 MetalLB IPs
- Clean hostname-based access
- Easier SSL/TLS certificate management (wildcard cert)
- Professional appearance (proper domain names)
- Better for production environments

**Disadvantages:**
- Requires DNS configuration (either local DNS server or /etc/hosts)
- Hostname resolution dependency
- Additional complexity with Ingress rules
- Plex still needs separate LoadBalancer for port 32400
- Non-HTTP protocols require special handling

### Option B: Multiple LoadBalancer IPs (Current Architecture)

**Architecture:**
```
Each Service → Dedicated LoadBalancer IP → Direct access
  - 10.69.1.154:32400 → Plex
  - 10.69.1.155:9696 → Prowlarr
  - 10.69.1.156:7878 → Radarr
  - etc.
```

**Advantages:**
- ✅ **No DNS required** - works immediately
- ✅ **Simple troubleshooting** - direct IP:port access
- ✅ **Service isolation** - failures don't cascade
- ✅ **Protocol flexibility** - any TCP/UDP port supported
- ✅ **No Ingress complexity** - no hostname rules to manage
- ✅ **Independent scaling** - each service fully independent

**Disadvantages:**
- Uses 8 MetalLB IPs (still have 4 available)
- Requires remembering/bookmarking IP addresses
- No SSL/TLS termination (HTTP only, not HTTPS)
- Less "professional" appearance

### Why Option B Was Chosen

**Decision Rationale:**

1. **Home Lab Environment:** Not customer-facing, internal use only
2. **Simplicity Priority:** Faster deployment, less complexity
3. **Learning Opportunity:** Better understanding of LoadBalancer mechanics
4. **Flexibility:** Easier to experiment and test individual services
5. **IP Availability:** MetalLB pool has sufficient capacity (16 IPs)
6. **No DNS Server:** Avoids need for Pi-hole, CoreDNS, or manual /etc/hosts
7. **Protocol Support:** Plex port 32400 and torrent ports work natively

**When Option A Might Be Reconsidered:**

1. **External Access:** If exposing services outside home network (requires SSL/TLS)
2. **IP Exhaustion:** If MetalLB pool runs out of IPs
3. **Professional Appearance:** If sharing access with non-technical users
4. **Wildcard SSL:** If wanting HTTPS for all services with Let's Encrypt
5. **Mobile Apps:** If mobile apps require proper domain names (most work with IP:port)

---

## Network Configuration

### UniFi Router Configuration

**Static Routes:** Not required - all traffic is on same 10.69.1.0/24 subnet

**DHCP Pool Configuration:**
```
DHCP Range: 10.69.1.50 - 10.69.1.149 (100 IPs)
Static Reservations: 10.69.1.101-106 (Kubernetes nodes)
MetalLB Pool: 10.69.1.150-165 (16 IPs, outside DHCP)
```

**Important:** Ensure UniFi DHCP pool does **NOT** include 10.69.1.150-165 to avoid IP conflicts.

**Verification:**
```bash
# Check UniFi DHCP settings
# Network → Settings → Networks → LAN → DHCP
# Confirm range ends at .149 or lower
```

**Firewall Rules:**
- Default LAN to LAN allowed (no restrictions needed)
- Optional: Create alias for "MediaStack" (10.69.1.154-161) for future ACLs

### MetalLB Configuration Files

**IPAddressPool:**
```yaml
# File: metallb-ipaddresspool.yaml
apiVersion: metallb.io/v1beta1
kind: IPAddressPool
metadata:
  name: first-pool
  namespace: metallb-system
spec:
  addresses:
  - 10.69.1.150-10.69.1.165
```

**L2Advertisement:**
```yaml
# File: metallb-l2advertisement.yaml
apiVersion: metallb.io/v1beta1
kind: L2Advertisement
metadata:
  name: l2-advert
  namespace: metallb-system
spec:
  ipAddressPools:
  - first-pool
```

**Deployment Commands:**
```bash
# Apply MetalLB pool configuration
kubectl apply -f metallb-ipaddresspool.yaml
kubectl apply -f metallb-l2advertisement.yaml

# Verify MetalLB is running
kubectl get pods -n metallb-system

# Check IP pool
kubectl get ipaddresspool -n metallb-system -o yaml

# View IP assignments
kubectl get svc -A | grep LoadBalancer
```

### DNS Considerations (Optional)

**Option 1: No DNS (Current)**
- Access services via IP:port (e.g., http://10.69.1.156:7878)
- Bookmark URLs in browser
- Share IP addresses with other users

**Option 2: Local /etc/hosts (Per Device)**
```bash
# Add to /etc/hosts on MacBook
10.69.1.154 plex.home plex
10.69.1.155 prowlarr.home prowlarr
10.69.1.156 radarr.home radarr
10.69.1.157 sonarr.home sonarr
10.69.1.158 qbittorrent.home qbittorrent
10.69.1.159 lidarr.home lidarr
10.69.1.160 overseerr.home overseerr
10.69.1.161 sabnzbd.home sabnzbd

# Access via hostnames
http://radarr.home:7878
http://plex.home:32400/web
```

**Option 3: Pi-hole / Local DNS Server (Network-Wide)**
- Install Pi-hole on Raspberry Pi or Docker container
- Configure as DNS server in UniFi
- Add custom DNS entries for all services
- All devices get hostname resolution automatically

**Recommendation:** Stick with IP:port for simplicity. Only add DNS if sharing with non-technical users.

---

## Security Considerations

### Network Isolation

**Current State:**
- All services on same 10.69.1.0/24 subnet
- No network segmentation or VLANs
- Default Kubernetes NetworkPolicies allow all pod-to-pod traffic

**Security Posture:**
- ✅ Services not exposed to internet (home network only)
- ✅ Kubernetes RBAC enabled
- ✅ Talos Linux immutable OS (no SSH)
- ⚠️ No SSL/TLS encryption (HTTP only)
- ⚠️ No authentication on some services (Prowlarr, Overseerr)
- ⚠️ No NetworkPolicies (all pods can communicate)

**Threat Model:**
- **Low Risk:** Home network with trusted users
- **Medium Risk:** If WiFi password compromised
- **High Risk:** If port-forwarding services to internet

### No TLS Termination (Direct HTTP Access)

**Current Implementation:**
- All services accessible via HTTP (not HTTPS)
- No certificate management required
- Traffic between home devices and services is unencrypted

**Implications:**
- ✅ Simpler deployment (no cert-manager needed)
- ✅ No certificate expiration issues
- ⚠️ Credentials sent in plaintext over LAN
- ⚠️ Session cookies not encrypted
- ⚠️ Not suitable for external access

**Acceptable Risk:** For home network with WPA2/WPA3 WiFi encryption, HTTP is typically acceptable for internal services.

### Application-Level Security

**Authentication Status:**

| Service | Authentication | Notes |
|---------|---------------|-------|
| Plex | ✅ Plex Account | Multi-user, managed users, parental controls |
| Radarr | ⚠️ API Key Only | Web UI has no login by default |
| Sonarr | ⚠️ API Key Only | Web UI has no login by default |
| Prowlarr | ⚠️ API Key Only | Web UI has no login by default |
| Lidarr | ⚠️ API Key Only | Web UI has no login by default |
| qBittorrent | ✅ Username/Password | Web UI login required |
| SABnzbd | ⚠️ API Key Only | Web UI has no login by default |
| Overseerr | ✅ Plex OAuth | Uses Plex account for authentication |

**Recommendations:**
1. Enable authentication on all *arr services:
   - Settings → General → Security → Authentication: Forms (Login Page)
   - Create username/password for each service
2. Restrict qBittorrent Web UI to localhost + VPN only
3. Use strong API keys (auto-generated by services)
4. Don't share API keys outside trusted systems

### Future: Adding Ingress for SSL/TLS

**Hybrid Approach (Best of Both Worlds):**
1. **Internal Access:** Keep LoadBalancer IPs for home network (HTTP)
2. **External Access:** Add NGINX Ingress with SSL for remote access (HTTPS)

**Implementation Steps:**
```bash
# 1. Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# 2. Configure Let's Encrypt ClusterIssuer
kubectl apply -f letsencrypt-issuer.yaml

# 3. Create Ingress resources with TLS
kubectl apply -f media-stack-ingress-tls.yaml

# 4. Configure port forwarding on UniFi router
# Forward ports 80/443 to NGINX Ingress LoadBalancer (10.69.1.150)
```

**Result:**
- Internal: http://10.69.1.156:7878 (fast, direct)
- External: https://radarr.example.com (secure, via Cloudflare tunnel or VPN)

---

## Operational Considerations

### Monitoring LoadBalancer IPs

**Check Service Status:**
```bash
# View all LoadBalancer services
kubectl get svc -A | grep LoadBalancer

# Check specific service
kubectl get svc plex -n media

# Describe service for events
kubectl describe svc plex -n media

# View MetalLB speaker logs
kubectl logs -n metallb-system -l component=speaker

# View MetalLB controller logs
kubectl logs -n metallb-system -l component=controller
```

**Expected Output:**
```
NAMESPACE         NAME                                    TYPE           CLUSTER-IP       EXTERNAL-IP    PORT(S)
media             plex                                    LoadBalancer   10.107.32.85     10.69.1.154    32400:31842/TCP
media             prowlarr                                LoadBalancer   10.100.68.61     10.69.1.155    9696:32313/TCP
media             radarr                                  LoadBalancer   10.100.232.134   10.69.1.156    7878:32509/TCP
media             sonarr                                  LoadBalancer   10.98.163.65     10.69.1.157    8989:30125/TCP
media             qbittorrent                             LoadBalancer   10.108.216.93    10.69.1.158    8080:32555/TCP
media             lidarr                                  LoadBalancer   10.111.140.117   10.69.1.159    8686:30569/TCP
media             overseerr                               LoadBalancer   10.111.196.248   10.69.1.160    5055:31234/TCP
media             sabnzbd                                 LoadBalancer   10.108.244.210   10.69.1.161    8080:30476/TCP
```

### Troubleshooting Access Issues

**Issue: Service shows `<pending>` instead of LoadBalancer IP**

```bash
# Check MetalLB is running
kubectl get pods -n metallb-system

# Check IP pool configuration
kubectl get ipaddresspool -n metallb-system -o yaml

# Describe service for events
kubectl describe svc <service-name> -n media
```

**Common Causes:**
1. MetalLB not installed or crashed
2. IP pool exhausted (all IPs assigned)
3. IP pool range doesn't include requested IP
4. L2Advertisement not configured

**Solution:**
```bash
# Expand IP pool if exhausted
kubectl patch ipaddresspool first-pool -n metallb-system --type='json' \
  -p='[{"op": "replace", "path": "/spec/addresses/0", "value": "10.69.1.150-10.69.1.170"}]'

# Restart MetalLB if crashed
kubectl rollout restart deployment -n metallb-system
kubectl rollout restart daemonset -n metallb-system
```

**Issue: Can't access service from browser**

```bash
# Test from MacBook terminal
curl http://10.69.1.156:7878

# Test from another pod
kubectl run -it --rm debug --image=curlimages/curl --restart=Never -- \
  curl http://10.69.1.156:7878

# Check pod is running
kubectl get pods -n media

# Check pod logs
kubectl logs -n media deployment/radarr
```

**Common Causes:**
1. Pod not running (CrashLoopBackOff)
2. Service selector doesn't match pod labels
3. Firewall blocking port (unlikely on LAN)
4. Wrong IP or port

**Issue: Service accessible externally but not internally**

```bash
# Check ClusterIP is assigned
kubectl get svc radarr -n media

# Test DNS resolution
kubectl run -it --rm debug --image=busybox --restart=Never -n media -- \
  nslookup radarr.media.svc.cluster.local

# Test HTTP from another pod
kubectl exec -n media deployment/sonarr -- \
  wget -O- http://radarr.media.svc.cluster.local:7878
```

**Common Causes:**
1. DNS resolution failing (CoreDNS issue)
2. NetworkPolicy blocking traffic
3. Service port mismatch

### Adding New Services

**Workflow for Deploying Additional LoadBalancer Services:**

1. **Check IP Availability:**
```bash
kubectl get svc -A | grep LoadBalancer | wc -l
# Compare to MetalLB pool size (16 IPs)
```

2. **Deploy Service:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: new-service
  namespace: media
spec:
  type: LoadBalancer
  # Optional: Request specific IP
  # loadBalancerIP: 10.69.1.162
  selector:
    app: new-service
  ports:
  - port: 8080
    targetPort: 8080
    protocol: TCP
```

3. **Verify IP Assignment:**
```bash
kubectl get svc new-service -n media

# Should show EXTERNAL-IP assigned within seconds
```

4. **Test Accessibility:**
```bash
curl http://10.69.1.162:8080
```

5. **Update Documentation:**
- Add to this document's IP allocation table
- Update CHANGELOG.md
- Add to browser bookmarks

**IP Selection Strategy:**
- Let MetalLB auto-assign unless specific IP needed
- Use sequential IPs for related services
- Reserve .150-153 for infrastructure
- Reserve .154-165 for applications

---

## Future Enhancements

### Potential Hybrid Approach

**Scenario:** Best of both worlds - keep LoadBalancers for internal access, add Ingress for external access.

**Architecture:**
```
Internal Users (Home Network)
  ↓ Direct access via LoadBalancer IPs
  10.69.1.154-161 → Services

External Users (Internet)
  ↓ HTTPS via domain name
  https://radarr.example.com → Cloudflare Tunnel
  ↓ Port 443
  NGINX Ingress (10.69.1.150)
  ↓ TLS termination
  radarr.media.svc.cluster.local:7878 → Radarr Pod
```

**Benefits:**
- Internal: Fast, direct access (no TLS overhead)
- External: Secure HTTPS with Let's Encrypt certificates
- No performance penalty for internal users
- Can selectively expose only certain services externally

**Implementation:**
```yaml
# media-stack-ingress-external.yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: media-stack-external
  namespace: media
  annotations:
    cert-manager.io/cluster-issuer: letsencrypt-prod
    nginx.ingress.kubernetes.io/ssl-redirect: "true"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - radarr.example.com
    - sonarr.example.com
    - overseerr.example.com
    secretName: media-stack-tls
  rules:
  - host: radarr.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: radarr
            port:
              number: 7878
  - host: sonarr.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: sonarr
            port:
              number: 8989
  - host: overseerr.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: overseerr
            port:
              number: 5055
```

### SSL/TLS Termination Options

**Option 1: Let's Encrypt with cert-manager**
- Free SSL certificates
- Automatic renewal
- Requires public domain name
- Requires DNS challenge or HTTP challenge (port 80 exposed)

**Option 2: Cloudflare Tunnel (Zero Trust)**
- No port forwarding required
- Cloudflare handles SSL/TLS
- Free for personal use
- Requires Cloudflare account and domain

**Option 3: VPN Only (Tailscale/WireGuard)**
- No port forwarding
- Encrypted VPN tunnel
- No SSL certificates needed
- Access internal IPs remotely via VPN

**Option 4: Self-Signed Certificates**
- No domain required
- No external dependencies
- Browser warnings for untrusted cert
- Acceptable for internal use only

### Custom Domain Names

**Local DNS with .home TLD:**

Setup Pi-hole or CoreDNS for network-wide DNS:
```
media.home      → 10.69.1.154 (Plex)
movies.home     → 10.69.1.156 (Radarr)
tv.home         → 10.69.1.157 (Sonarr)
music.home      → 10.69.1.159 (Lidarr)
request.home    → 10.69.1.160 (Overseerr)
```

**Public Domain with Split-Brain DNS:**

Register domain (e.g., example.com):
- External DNS: Points to Cloudflare Tunnel or public IP
- Internal DNS: Points to LoadBalancer IPs (faster, no internet dependency)

Example:
```
# External (public DNS)
radarr.example.com → Cloudflare Tunnel → 10.69.1.150 (Ingress)

# Internal (Pi-hole DNS)
radarr.example.com → 10.69.1.156 (direct LoadBalancer)
```

Result: Same domain name works internally and externally, but routes differently.

---

## Reference Information

### Related Documentation

**Project Documentation:**
- [/Users/stevenbrown/Development/k8_cluster/CLAUDE.md](../CLAUDE.md) - Complete project overview and commands
- [/Users/stevenbrown/Development/k8_cluster/CHANGELOG.md](../CHANGELOG.md) - Change history and deployments
- [/Users/stevenbrown/Development/k8_cluster/docs/MEDIA_STACK_CONFIG_REVIEW.md](MEDIA_STACK_CONFIG_REVIEW.md) - Service configuration and API verification

**Deployment Files:**
- `/Users/stevenbrown/Development/k8_cluster/deployments/media/*.yaml` - Service manifests
- `/Users/stevenbrown/Development/k8_cluster/deployments/metallb/*.yaml` - MetalLB configuration

### MetalLB Documentation

**Official Documentation:**
- MetalLB Homepage: https://metallb.universe.tf/
- Layer 2 Configuration: https://metallb.universe.tf/configuration/#layer-2-configuration
- IP Address Pools: https://metallb.universe.tf/configuration/#defining-the-ips-to-assign-to-the-load-balancer-services
- Troubleshooting: https://metallb.universe.tf/configuration/troubleshooting/

**Key Concepts:**
- **Speaker:** DaemonSet pod on each node that responds to ARP requests for LoadBalancer IPs
- **Controller:** Deployment that watches for LoadBalancer services and assigns IPs
- **L2 Mode:** Uses ARP/NDP to announce LoadBalancer IPs on local network (no BGP router required)
- **IP Sharing:** Multiple services can share same IP if using different ports (not used in this deployment)

### Kubernetes LoadBalancer Service Documentation

**Official Kubernetes Docs:**
- Service Types: https://kubernetes.io/docs/concepts/services-networking/service/#loadbalancer
- Service API Reference: https://kubernetes.io/docs/reference/kubernetes-api/service-resources/service-v1/

**LoadBalancer Service Spec:**
```yaml
apiVersion: v1
kind: Service
metadata:
  name: example
  namespace: media
spec:
  type: LoadBalancer                    # Service type
  loadBalancerIP: 10.69.1.162          # Optional: Request specific IP
  externalTrafficPolicy: Cluster        # Default: Load balance across all nodes
  # externalTrafficPolicy: Local        # Alternative: Preserve source IP
  selector:
    app: example                        # Match pods with this label
  ports:
  - name: http
    port: 8080                          # External port
    targetPort: 8080                    # Container port
    protocol: TCP
```

**Key Fields:**
- `type: LoadBalancer` - Requests external IP from MetalLB
- `loadBalancerIP` - Optional specific IP request (deprecated in K8s 1.24+, use annotations)
- `externalTrafficPolicy: Cluster` - Load balance to any node, then to pod
- `externalTrafficPolicy: Local` - Only send traffic to node with pod (preserves source IP)
- `selector` - Matches pods to include in service endpoints

### MetalLB Best Practices

1. **IP Pool Management:**
   - Reserve sufficient IPs for growth
   - Document IP assignments
   - Use sequential IPs for related services
   - Exclude MetalLB range from DHCP

2. **High Availability:**
   - MetalLB speaker runs on all nodes (DaemonSet)
   - Automatic failover if speaker node fails
   - Use multiple control plane nodes for HA

3. **Monitoring:**
   - Monitor MetalLB controller and speaker pods
   - Alert on IP pool exhaustion
   - Track IP assignment failures

4. **Troubleshooting:**
   - Check MetalLB logs first
   - Verify IP pool configuration
   - Test ARP resolution with `arp -a | grep <IP>`
   - Use tcpdump to debug network issues

---

## Appendix: Quick Reference Commands

### Service Access URLs
```bash
# Media Stack Services
http://10.69.1.154:32400/web    # Plex
http://10.69.1.155:9696         # Prowlarr
http://10.69.1.156:7878         # Radarr
http://10.69.1.157:8989         # Sonarr
http://10.69.1.158:8080         # qBittorrent
http://10.69.1.159:8686         # Lidarr
http://10.69.1.160:5055         # Overseerr
http://10.69.1.161:8080         # SABnzbd

# Infrastructure Services
http://10.69.1.151              # Grafana
http://10.69.1.152:9090         # Prometheus
http://10.69.1.153:9093         # AlertManager
```

### Common kubectl Commands
```bash
# View all LoadBalancer services
kubectl get svc -A | grep LoadBalancer

# Check media stack pods
kubectl get pods -n media

# View service details
kubectl describe svc plex -n media

# Check MetalLB status
kubectl get pods -n metallb-system

# View IP pool configuration
kubectl get ipaddresspool -n metallb-system -o yaml

# Test service from cluster
kubectl run -it --rm curl --image=curlimages/curl --restart=Never -- \
  curl http://radarr.media.svc.cluster.local:7878
```

### Health Check Script
```bash
#!/bin/bash
# File: check-media-stack.sh

echo "=== Media Stack Health Check ==="
echo

echo "1. Checking all LoadBalancer IPs..."
kubectl get svc -n media | grep LoadBalancer

echo
echo "2. Checking pod status..."
kubectl get pods -n media

echo
echo "3. Testing external connectivity..."
services=(
  "10.69.1.154:32400|Plex"
  "10.69.1.155:9696|Prowlarr"
  "10.69.1.156:7878|Radarr"
  "10.69.1.157:8989|Sonarr"
  "10.69.1.158:8080|qBittorrent"
  "10.69.1.159:8686|Lidarr"
  "10.69.1.160:5055|Overseerr"
  "10.69.1.161:8080|SABnzbd"
)

for service in "${services[@]}"; do
  IFS='|' read -r url name <<< "$service"
  if curl -s -o /dev/null -w "%{http_code}" "http://$url" | grep -q "200\|401"; then
    echo "✅ $name ($url) - OK"
  else
    echo "❌ $name ($url) - FAILED"
  fi
done

echo
echo "=== Health Check Complete ==="
```

---

**Document End**

**Maintained by:** Steven Brown
**Repository:** /Users/stevenbrown/Development/k8_cluster/
**Cluster:** Talos Kubernetes on 6x Beelink SER5
**Last Updated:** October 5, 2025
