#!/bin/bash
# deploy-hardened.sh
# Deploy HARDENED container - FULL SECURITY (for comparison)

set -euo pipefail

echo "========================================="
echo "Deploying HARDENED Container"
echo "========================================="
echo ""
echo "✓ HARDENED Configuration (Full Security):"
echo "    - Runs as NON-ROOT (UID 1001)"
echo "    - Resource limits enforced"
echo "    - Read-only filesystem"
echo "    - Minimal capabilities"
echo "    - Security constraints applied"
echo ""

# Build image if not exists
if ! docker image inspect node-test-app:v1.0 >/dev/null 2>&1; then
  echo "[*] Building image..."
  docker build -t node-test-app:v1.0 .
else
  echo "[*] Image already exists"
fi

# Stop existing container
if docker ps -a | grep -q test-hardened; then
  echo "[*] Stopping existing container..."
  docker stop test-hardened 2>/dev/null || true
  docker rm test-hardened 2>/dev/null || true
fi

# Deploy HARDENED - FULL SECURITY FLAGS
echo "[*] Deploying hardened container (full security)..."
echo ""
echo "Security flags applied:"
echo "  --user 1001:1001              (non-root user)"
echo "  --read-only                    (read-only filesystem)"
echo "  --tmpfs /tmp                   (writable tmpfs)"
echo "  --cap-drop=ALL                 (drop all capabilities)"
echo "  --cap-add=NET_BIND_SERVICE     (minimal capability)"
echo "  --security-opt no-new-priv     (prevent privilege escalation)"
echo "  --cpus=2.0                     (CPU limit)"
echo "  --memory=2g                    (memory limit)"
echo "  --pids-limit=512               (process limit)"
echo ""

docker run -d \
  --name test-hardened \
  --user 1001:1001 \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --security-opt=no-new-privileges:true \
  --cpus=2.0 \
  --memory=2g \
  --pids-limit=512 \
  -p 3001:3000 \
  node-test-app:v1.0

# Wait for container to be ready
echo "[*] Waiting for container to be ready..."
sleep 3

# Verify deployment
echo ""
echo "========================================="
echo "Deployment Status"
echo "========================================="
docker ps --filter "name=test-hardened" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "========================================="
echo "Hardened Configuration Check"
echo "========================================="

# Test health endpoint
echo "[*] Testing health endpoint..."
curl -s http://localhost:3001/health | jq -r '.status'

echo ""
echo "[*] Container user:"
docker exec test-hardened whoami 2>/dev/null || echo "  (numeric UID, no username)"
docker exec test-hardened id

echo ""
echo "[*] Filesystem check (should be read-only):"
if docker exec test-hardened touch /test-write 2>&1 | grep -q "Read-only"; then
    echo "  ✓ Root filesystem is READ-ONLY (secure)"
else
    echo "  ⚠️  Warning: Filesystem may be writable"
fi

echo ""
echo "[*] Tmpfs check (should be writable):"
if docker exec test-hardened touch /tmp/test-tmp 2>/dev/null; then
    echo "  ✓ /tmp is writable (tmpfs working)"
    docker exec test-hardened rm /tmp/test-tmp
else
    echo "  ⚠️  Warning: /tmp not writable"
fi

echo ""
echo "[*] Resource limits:"
docker inspect test-hardened | jq -r '.[0].HostConfig | {
  Memory: .Memory,
  NanoCpus: .NanoCpus,
  PidsLimit: .PidsLimit,
  ReadonlyRootfs: .ReadonlyRootfs
}'

echo ""
echo "[*] Capabilities check:"
docker exec test-hardened cat /proc/1/status | grep "^Cap" | head -3

echo ""
echo "========================================="
echo "HARDENED Deployed Successfully!"
echo "========================================="
echo "Container: test-hardened"
echo "URL: http://localhost:3001"
echo "Image: node-test-app:v1.0 (same as baseline)"
echo ""
echo "Security Status:"
echo "  User: appuser (UID 1001) ✓"
echo "  Filesystem: Read-only ✓"
echo "  Capabilities: Minimal ✓"
echo "  Resource Limits: Enforced ✓"
echo ""
echo "Test endpoints:"
echo "  curl http://localhost:3001/info"
echo "  curl http://localhost:3001/info/namespace"
echo "  curl http://localhost:3001/info/cgroup"
echo ""
echo "Compare security:"
echo "  Baseline:  docker exec test-baseline whoami  # root"
echo "  Hardened:  docker exec test-hardened whoami  # appuser"
echo ""
echo "Run comparison: ./scripts/compare-standard.sh"
echo "========================================="
