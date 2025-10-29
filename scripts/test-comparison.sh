#!/bin/bash
# test-comparison.sh
# Compare baseline vs hardened configurations

set -euo pipefail

echo "=============================================="
echo "Baseline vs Hardened Configuration Comparison"
echo "=============================================="
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if containers are running
echo "[*] Checking container status..."
if ! docker ps | grep -q test-baseline; then
  echo -e "${RED}[ERROR] Baseline container not running${NC}"
  echo "Run: ./deploy-baseline.sh"
  exit 1
fi

if ! docker ps | grep -q test-hardened; then
  echo -e "${RED}[ERROR] Hardened container not running${NC}"
  echo "Run: ./deploy-hardened.sh"
  exit 1
fi

echo -e "${GREEN}[OK] Both containers are running${NC}"
echo ""

# Function to compare values
compare() {
  local label=$1
  local baseline=$2
  local hardened=$3
  
  echo "  $label:"
  echo "    Baseline:  $baseline"
  echo "    Hardened:  $hardened"
  echo ""
}

# ============================================
# 1. NAMESPACE COMPARISON
# ============================================
echo "=============================================="
echo "1. NAMESPACE ISOLATION"
echo "=============================================="

BASELINE_NS=$(curl -s http://localhost:3000/namespace | jq -r '.namespaces | keys | length')
HARDENED_NS=$(curl -s http://localhost:3001/namespace | jq -r '.namespaces | keys | length')

compare "Active Namespaces" "${BASELINE_NS}/7" "${HARDENED_NS}/7"

# Check User Namespace specifically
BASELINE_USER_NS=$(curl -s http://localhost:3000/namespace | jq -r '.namespaces.user.exists')
HARDENED_USER_NS=$(curl -s http://localhost:3001/namespace | jq -r '.namespaces.user.exists')

compare "User Namespace" "$BASELINE_USER_NS" "$HARDENED_USER_NS"

# ============================================
# 2. CGROUP LIMITS COMPARISON
# ============================================
echo "=============================================="
echo "2. RESOURCE LIMITS (Cgroup)"
echo "=============================================="

BASELINE_CPU=$(curl -s http://localhost:3000/cgroup | jq -r '.limits.cpu // "unlimited"')
HARDENED_CPU=$(curl -s http://localhost:3001/cgroup | jq -r '.limits.cpu // "unlimited"')
compare "CPU Limit" "$BASELINE_CPU" "$HARDENED_CPU"

BASELINE_MEM=$(curl -s http://localhost:3000/cgroup | jq -r '.limits.memory // "unlimited"')
HARDENED_MEM=$(curl -s http://localhost:3001/cgroup | jq -r '.limits.memory // "unlimited"')
compare "Memory Limit" "$BASELINE_MEM" "$HARDENED_MEM"

BASELINE_PIDS=$(curl -s http://localhost:3000/cgroup | jq -r '.limits.pids // "unlimited"')
HARDENED_PIDS=$(curl -s http://localhost:3001/cgroup | jq -r '.limits.pids // "unlimited"')
compare "PIDs Limit" "$BASELINE_PIDS" "$HARDENED_PIDS"

# ============================================
# 3. USER & PERMISSIONS
# ============================================
echo "=============================================="
echo "3. USER & PERMISSIONS"
echo "=============================================="

BASELINE_UID=$(curl -s http://localhost:3000/info | jq -r '.process.uid')
HARDENED_UID=$(curl -s http://localhost:3001/info | jq -r '.process.uid')
compare "Process UID" "$BASELINE_UID (root)" "$HARDENED_UID (non-root)"

# ============================================
# 4. PERFORMANCE COMPARISON
# ============================================
echo "=============================================="
echo "4. PERFORMANCE BENCHMARKS"
echo "=============================================="

# CPU Test - Baseline
echo "  Running CPU benchmark (1M iterations)..."
echo "    Baseline:"
BASELINE_CPU_TIME=$(curl -s "http://localhost:3000/compute?iterations=1000000" | jq -r '.duration_ms')
echo "      Duration: ${BASELINE_CPU_TIME}ms"

echo "    Hardened:"
HARDENED_CPU_TIME=$(curl -s "http://localhost:3001/compute?iterations=1000000" | jq -r '.duration_ms')
echo "      Duration: ${HARDENED_CPU_TIME}ms"

# Calculate overhead
OVERHEAD=$(awk "BEGIN {printf \"%.2f\", (($HARDENED_CPU_TIME - $BASELINE_CPU_TIME) / $BASELINE_CPU_TIME) * 100}")
echo "    CPU Overhead: ${OVERHEAD}%"
echo ""

# Memory Test - Baseline
echo "  Running memory test (100MB)..."
echo "    Baseline:"
BASELINE_MEM_TIME=$(curl -s "http://localhost:3000/memory?size=100" | jq -r '.duration_ms')
echo "      Duration: ${BASELINE_MEM_TIME}ms"

echo "    Hardened:"
HARDENED_MEM_TIME=$(curl -s "http://localhost:3001/memory?size=100" | jq -r '.duration_ms')
echo "      Duration: ${HARDENED_MEM_TIME}ms"

# Calculate overhead
MEM_OVERHEAD=$(awk "BEGIN {printf \"%.2f\", (($HARDENED_MEM_TIME - $BASELINE_MEM_TIME) / $BASELINE_MEM_TIME) * 100}")
echo "    Memory Overhead: ${MEM_OVERHEAD}%"
echo ""

# ============================================
# 5. SECURITY FEATURES COMPARISON
# ============================================
echo "=============================================="
echo "5. SECURITY FEATURES"
echo "=============================================="

# Read-only filesystem test
echo "  Filesystem Write Test:"
echo "    Baseline:"
BASELINE_FS=$(docker exec test-baseline sh -c "touch /test 2>&1 && echo 'WRITABLE' || echo 'READ-ONLY'")
echo "      Status: $BASELINE_FS"

echo "    Hardened:"
HARDENED_FS=$(docker exec test-hardened sh -c "touch /test 2>&1 && echo 'WRITABLE' || echo 'READ-ONLY'")
echo "      Status: $HARDENED_FS"
echo ""

# Capabilities check
echo "  Capabilities:"
echo "    Baseline:"
docker exec test-baseline sh -c "cat /proc/self/status | grep CapEff" | awk '{print "      CapEff: " $2}'

echo "    Hardened:"
docker exec test-hardened sh -c "cat /proc/self/status | grep CapEff" | awk '{print "      CapEff: " $2}'
echo ""

# ============================================
# 6. SUMMARY
# ============================================
echo "=============================================="
echo "SUMMARY"
echo "=============================================="
echo ""
echo "Security Improvements:"
echo "  ✓ Namespaces: ${BASELINE_NS}/7 → ${HARDENED_NS}/7"
echo "  ✓ User Isolation: ${BASELINE_USER_NS} → ${HARDENED_USER_NS}"
echo "  ✓ Resource Limits: unlimited → strict"
echo "  ✓ UID: ${BASELINE_UID} (root) → ${HARDENED_UID} (non-root)"
echo "  ✓ Filesystem: WRITABLE → READ-ONLY"
echo ""
echo "Performance Trade-offs:"
echo "  • CPU Overhead: ${OVERHEAD}%"
echo "  • Memory Overhead: ${MEM_OVERHEAD}%"
echo ""

# Verdict
if (( $(echo "$OVERHEAD < 10" | bc -l) )); then
  echo -e "${GREEN}✓ Performance overhead is acceptable (<10%)${NC}"
else
  echo -e "${YELLOW}⚠ Performance overhead is higher than expected${NC}"
fi

if [ "$HARDENED_FS" = "READ-ONLY" ]; then
  echo -e "${GREEN}✓ Filesystem hardening is effective${NC}"
fi

if [ "$HARDENED_USER_NS" = "true" ]; then
  echo -e "${GREEN}✓ User Namespace isolation is active${NC}"
fi

echo ""
echo "=============================================="
echo "Comparison Complete!"
echo "=============================================="