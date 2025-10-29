#!/bin/bash
# deploy-baseline.sh
# Deploy container dengan konfigurasi default (baseline)

set -euo pipefail

echo "========================================="
echo "Deploying Baseline Configuration"
echo "========================================="

# Build image if not exists
if ! docker image inspect node-test-app:v1.0 >/dev/null 2>&1; then
  echo "[*] Building image..."
  docker build -t node-test-app:v1.0 .
else
  echo "[*] Image already exists"
fi

# Stop existing container
if docker ps -a | grep -q test-baseline; then
  echo "[*] Stopping existing container..."
  docker stop test-baseline || true
  docker rm test-baseline || true
fi

# Deploy baseline
echo "[*] Deploying baseline container..."
docker run -d \
  --name test-baseline \
  -p 3000:3000 \
  node-test-app:v1.0

# Wait for container to be ready
echo "[*] Waiting for container to be ready..."
sleep 3

# Verify deployment
echo ""
echo "========================================="
echo "Deployment Status"
echo "========================================="
docker ps --filter "name=test-baseline" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "========================================="
echo "Testing Endpoints"
echo "========================================="

# Test health endpoint
echo "[*] Testing health endpoint..."
curl -s http://localhost:3000/health | jq .

echo ""
echo "[*] Testing namespace info..."
curl -s http://localhost:3000/namespace | jq '.namespaces | keys'

echo ""
echo "[*] Testing cgroup info..."
curl -s http://localhost:3000/cgroup | jq '.limits // "No limits configured"'

echo ""
echo "========================================="
echo "Baseline Configuration Deployed!"
echo "========================================="
echo "Container: test-baseline"
echo "URL: http://localhost:3000"
echo ""
echo "Test with:"
echo "  curl http://localhost:3000/info"
echo "  curl http://localhost:3000/namespace"
echo "  curl http://localhost:3000/cgroup"
echo "========================================="