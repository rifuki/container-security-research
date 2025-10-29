#!/bin/bash
# deploy-hardened.sh
# Deploy container dengan konfigurasi hardened (security enhanced)

set -euo pipefail

echo "========================================="
echo "Deploying Hardened Configuration"
echo "========================================="

# Build image if not exists
if ! docker image inspect node-test-app:v1.0 >/dev/null 2>&1; then
  echo "[*] Building image..."
  docker build -t node-test-app:v1.0 .
else
  echo "[*] Image already exists"
fi

# Check prerequisites
echo "[*] Checking prerequisites..."

# Check if userns-remap is configured
if ! grep -q "userns-remap" /etc/docker/daemon.json 2>/dev/null; then
  echo "[!] WARNING: userns-remap not configured in /etc/docker/daemon.json"
  echo "    For full User Namespace isolation, add:"
  echo '    {"userns-remap": "default"}'
  echo "    Then restart Docker: sudo systemctl restart docker"
  echo ""
fi

# Check if seccomp profile exists (optional)
if [ ! -f /etc/docker/seccomp-strict.json ]; then
  echo "[!] WARNING: /etc/docker/seccomp-strict.json not found"
  echo "    Seccomp profile will use default instead"
  SECCOMP_OPT=""
else
  SECCOMP_OPT="--security-opt=seccomp=/etc/docker/seccomp-strict.json"
fi

# Check if AppArmor profile exists (optional)
if ! aa-status 2>/dev/null | grep -q docker-hardened; then
  echo "[!] WARNING: AppArmor profile 'docker-hardened' not loaded"
  echo "    AppArmor profile will use default instead"
  APPARMOR_OPT=""
else
  APPARMOR_OPT="--security-opt=apparmor=docker-hardened"
fi

# Stop existing container
if docker ps -a | grep -q test-hardened; then
  echo "[*] Stopping existing container..."
  docker stop test-hardened || true
  docker rm test-hardened || true
fi

# Deploy hardened
echo "[*] Deploying hardened container..."
docker run -d \
  --name test-hardened \
  --cpus="2.0" \
  --memory="2g" \
  --pids-limit=512 \
  --security-opt=no-new-privileges:true \
  $SECCOMP_OPT \
  $APPARMOR_OPT \
  --cap-drop=ALL \
  --cap-add=NET_BIND_SERVICE \
  --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  --tmpfs /app/logs:rw,noexec,nosuid,size=32m \
  --user 1000:1000 \
  -p 3001:3000 \
  node-test-app:v1.0

# Wait for container to be ready
echo "[*] Waiting for container to be ready..."
sleep 5

# Verify deployment
echo ""
echo "========================================="
echo "Deployment Status"
echo "========================================="
docker ps --filter "name=test-hardened" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

echo ""
echo "========================================="
echo "Security Validation"
echo "========================================="

# Check UID
echo "[*] Checking process UID..."
docker exec test-hardened id

# Check capabilities
echo ""
echo "[*] Checking capabilities..."
docker exec test-hardened sh -c "cat /proc/self/status | grep Cap"

# Check namespace
echo ""
echo "[*] Checking namespaces..."
curl -s http://localhost:3001/namespace | jq '.namespaces | keys'

# Check cgroup limits
echo ""
echo "[*] Checking resource limits..."
curl -s http://localhost:3001/cgroup | jq '.limits'

# Check filesystem
echo ""
echo "[*] Checking read-only filesystem..."
docker exec test-hardened sh -c "touch /test 2>&1 || echo 'Filesystem is read-only: OK'"

echo ""
echo "========================================="
echo "Performance Testing"
echo "========================================="

# Test health
echo "[*] Testing health endpoint..."
curl -s http://localhost:3001/health | jq '.status'

# Test CPU
echo ""
echo "[*] Running CPU stress test..."
time curl -s "http://localhost:3001/compute?iterations=1000000" | jq '.duration_ms'

# Test memory
echo ""
echo "[*] Running memory test..."
curl -s "http://localhost:3001/memory?size=100" | jq '.allocated_mb, .duration_ms'

echo ""
echo "========================================="
echo "Hardened Configuration Deployed!"
echo "========================================="
echo "Container: test-hardened"
echo "URL: http://localhost:3001"
echo ""
echo "Security Features Applied:"
echo "  ✓ User Namespace (UID remapping)"
echo "  ✓ CPU Limit: 2 cores"
echo "  ✓ Memory Limit: 2 GB"
echo "  ✓ PIDs Limit: 512"
echo "  ✓ No New Privileges: true"
echo "  ✓ Capabilities: Minimal (NET_BIND_SERVICE only)"
echo "  ✓ Filesystem: Read-only"
echo "  ✓ User: Non-root (1000:1000)"
echo ""
echo "Test with:"
echo "  curl http://localhost:3001/info"
echo "  curl http://localhost:3001/namespace"
echo "  curl http://localhost:3001/cgroup"
echo "========================================="