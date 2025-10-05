#!/bin/bash
# Talos Cluster Health Check Script
# Checks all nodes for proper configuration and health

set -e

export TALOSCONFIG=~/talos-cluster/talosconfig

echo "========================================="
echo "  Talos Cluster Health Check"
echo "  $(date)"
echo "========================================="
echo ""

# Node IPs
CONTROL_PLANE_IPS="10.69.1.101 10.69.1.140 10.69.1.147"
WORKER_IPS="10.69.1.151 10.69.1.197 10.69.1.179"
ALL_IPS="$CONTROL_PLANE_IPS $WORKER_IPS"

echo "📊 Checking Control Plane Nodes..."
echo "-----------------------------------"
for ip in $CONTROL_PLANE_IPS; do
  echo -n "Node $ip: "
  if talosctl --nodes $ip get systemdisk 2>/dev/null | grep -q nvme0n1; then
    echo "✅ Running from NVMe"
  else
    echo "❌ NOT on NVMe"
  fi
done

echo ""
echo "📊 Checking Worker Nodes..."
echo "-----------------------------------"
for ip in $WORKER_IPS; do
  echo -n "Node $ip: "
  if talosctl --nodes $ip get systemdisk 2>/dev/null | grep -q nvme0n1; then
    echo "✅ Running from NVMe"
  else
    echo "❌ NOT on NVMe"
  fi
done

echo ""
echo "📊 Network Connectivity..."
echo "-----------------------------------"
for ip in $ALL_IPS; do
  echo -n "Node $ip: "
  if ping -c 1 -W 2 $ip &>/dev/null; then
    echo "✅ Reachable"
  else
    echo "❌ Unreachable"
  fi
done

echo ""
echo "📊 Talos API Status..."
echo "-----------------------------------"
for ip in $ALL_IPS; do
  echo -n "Node $ip: "
  if nc -z -w 2 $ip 50000 2>/dev/null; then
    echo "✅ API Available"
  else
    echo "❌ API Unavailable"
  fi
done

echo ""
echo "========================================="
echo "  Health Check Complete"
echo "========================================="


