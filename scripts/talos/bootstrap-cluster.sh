#!/bin/bash
# Bootstrap Talos Kubernetes Cluster
# Run this ONCE after all nodes are configured

set -e

export TALOSCONFIG=~/talos-cluster/talosconfig

echo "========================================="
echo "  Talos Cluster Bootstrap"
echo "  $(date)"
echo "========================================="
echo ""

echo "⚠️  This script will bootstrap the Kubernetes cluster."
echo "⚠️  Run this ONLY ONCE after all nodes are configured."
echo ""
read -p "Continue with bootstrap? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
  echo "Bootstrap cancelled."
  exit 0
fi

echo ""
echo "🚀 Bootstrapping cluster on primary control plane node..."
talosctl bootstrap --nodes 10.69.1.101

echo ""
echo "⏳ Waiting for bootstrap to complete (60 seconds)..."
sleep 60

echo ""
echo "📥 Retrieving kubeconfig..."
talosctl kubeconfig --nodes 10.69.1.101

echo ""
echo "✅ Kubeconfig saved to ~/.kube/config"

echo ""
echo "📊 Checking cluster nodes..."
kubectl get nodes -o wide

echo ""
echo "========================================="
echo "  Bootstrap Complete!"
echo "========================================="
echo ""
echo "Next steps:"
echo "1. Wait for all nodes to show 'Ready' status"
echo "2. Deploy core services (MetalLB, storage, etc.)"
echo "3. Deploy applications per PRD.md"


