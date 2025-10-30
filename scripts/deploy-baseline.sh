#!/bin/bash
# deploy-baseline.sh
# Deploy BASELINE container - NO HARDENING (vulnerable for comparison)

set -euo pipefail

echo "========================================="
echo "Deploying BASELINE Container"
echo "========================================="
echo ""
echo "⚠️  BASELINE Configuration (No Hardening):"
echo "    - Runs as ROOT (UID 0)"
echo "    - No resource limits"
echo "    - Writable filesystem"
echo "    - Full capabilities"
echo "    - For research comparison only"
echo ""

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
  docker stop test-baseline 2>/dev/null || true
  docker rm test-baseline 2>/dev/null || true
fi

# Deploy BASELINE - NO SECURITY FLAGS
echo "[*] Deploying baseline container (no hardening)..."
echo ""

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
echo "Baseline Configuration Check"
echo "========================================="

# Test health endpoint
echo "[*] Testing health endpoint..."
curl -s http://localhost:3000/health | jq -r '.status'

echo ""
echo "[*] Container user:"
docker exec test-baseline whoami
docker exec test-baseline id

echo ""
echo "[*] Filesystem check (should be writable):"
if docker exec test-baseline touch /tmp/test-write 2>/dev/null; then
    echo "  ⚠️  Filesystem is WRITABLE (vulnerable)"
    docker exec test-baseline rm /tmp/test-write
else
    echo "  Unexpected: Filesystem is read-only"
fi

echo ""
echo "[*] Resource limits:"
docker inspect test-baseline | jq -r '.[0].HostConfig | {
  Memory: .Memory,
  NanoCpus: .NanoCpus,
  PidsLimit: .PidsLimit
}'

echo ""
echo "========================================="
echo "BASELINE Deployed Successfully!"
echo "========================================="
echo "Container: test-baseline"
echo "URL: http://localhost:3000"
echo "Image: node-test-app:v1.0"
echo ""
echo "Security Status:"
echo "  User: root (UID 0) ⚠️"
echo "  Filesystem: Writable ⚠️"
echo "  Capabilities: Full ⚠️"
echo "  Resource Limits: None ⚠️"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost:3000/info"
echo "  curl http://localhost:3000/info/namespace"
echo "  curl http://localhost:3000/info/cgroup"
echo ""
echo "Compare with hardened: ./scripts/deploy-hardened.sh"
echo "========================================="
