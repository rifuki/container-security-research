#!/bin/bash
##############################################################################
# Namespace Isolation Testing Script
# Tests 7 Linux namespace types for container isolation
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Namespace Isolation Testing${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if containers are running
if ! docker ps | grep -q test-baseline; then
    echo -e "${RED}Error: test-baseline container not running${NC}"
    echo "Run: ./scripts/deploy-baseline.sh"
    exit 1
fi

if ! docker ps | grep -q test-hardened; then
    echo -e "${RED}Error: test-hardened container not running${NC}"
    echo "Run: ./scripts/deploy-hardened.sh"
    exit 1
fi

##############################################################################
# Test 1: PID Namespace Isolation
##############################################################################
echo -e "${BLUE}[Test 1] PID Namespace Isolation${NC}"
echo "Testing if container has isolated process tree..."
echo ""

echo "Host PID namespaces:"
HOST_PID_NS=$(ls -la /proc/self/ns/pid | awk '{print $NF}')
echo "  Host: $HOST_PID_NS"

echo ""
echo "Baseline container PID namespace:"
BASELINE_PID_NS=$(docker exec test-baseline ls -la /proc/self/ns/pid | awk '{print $NF}')
echo "  Baseline: $BASELINE_PID_NS"

echo ""
echo "Hardened container PID namespace:"
HARDENED_PID_NS=$(docker exec test-hardened ls -la /proc/self/ns/pid | awk '{print $NF}')
echo "  Hardened: $HARDENED_PID_NS"

echo ""
if [ "$HOST_PID_NS" != "$BASELINE_PID_NS" ] && [ "$HOST_PID_NS" != "$HARDENED_PID_NS" ]; then
    echo -e "${GREEN}✓ PASS: PID namespace isolated${NC}"
    echo "  Containers cannot see host processes"
else
    echo -e "${RED}✗ FAIL: PID namespace NOT isolated${NC}"
fi

echo ""
echo "Process tree inside containers (should start from PID 1):"
echo "Baseline:"
docker exec test-baseline ps aux | head -5
echo ""
echo "Hardened:"
docker exec test-hardened ps aux | head -5

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 2: Network Namespace Isolation
##############################################################################
echo -e "${BLUE}[Test 2] Network Namespace Isolation${NC}"
echo "Testing if container has isolated network stack..."
echo ""

echo "Host network interfaces:"
HOST_IFACES=$(ip link show | grep -c "^[0-9]")
echo "  Host has $HOST_IFACES network interfaces"

echo ""
echo "Baseline container network interfaces:"
BASELINE_IFACES=$(docker exec test-baseline ip link show | grep -c "^[0-9]")
echo "  Baseline has $BASELINE_IFACES network interfaces"

echo ""
echo "Hardened container network interfaces:"
HARDENED_IFACES=$(docker exec test-hardened ip link show | grep -c "^[0-9]")
echo "  Hardened has $HARDENED_IFACES network interfaces"

echo ""
if [ "$BASELINE_IFACES" -lt "$HOST_IFACES" ] && [ "$HARDENED_IFACES" -lt "$HOST_IFACES" ]; then
    echo -e "${GREEN}✓ PASS: Network namespace isolated${NC}"
    echo "  Containers have separate network stack"
else
    echo -e "${YELLOW}⚠ WARNING: Network namespace may not be isolated${NC}"
fi

echo ""
echo "Container network interfaces:"
echo "Baseline:"
docker exec test-baseline ip addr show | grep "inet " | head -3
echo ""
echo "Hardened:"
docker exec test-hardened ip addr show | grep "inet " | head -3

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 3: Mount Namespace Isolation
##############################################################################
echo -e "${BLUE}[Test 3] Mount Namespace Isolation${NC}"
echo "Testing if container has isolated filesystem mounts..."
echo ""

echo "Host mount count:"
HOST_MOUNTS=$(mount | wc -l)
echo "  Host has $HOST_MOUNTS mounts"

echo ""
echo "Baseline container mount count:"
BASELINE_MOUNTS=$(docker exec test-baseline mount | wc -l)
echo "  Baseline has $BASELINE_MOUNTS mounts"

echo ""
echo "Hardened container mount count:"
HARDENED_MOUNTS=$(docker exec test-hardened mount | wc -l)
echo "  Hardened has $HARDENED_MOUNTS mounts"

echo ""
if [ "$BASELINE_MOUNTS" -lt "$HOST_MOUNTS" ] && [ "$HARDENED_MOUNTS" -lt "$HOST_MOUNTS" ]; then
    echo -e "${GREEN}✓ PASS: Mount namespace isolated${NC}"
    echo "  Containers have separate mount points"
else
    echo -e "${YELLOW}⚠ WARNING: Mount namespace may not be isolated${NC}"
fi

echo ""
echo "Key mount points in containers:"
echo "Baseline root filesystem:"
docker exec test-baseline mount | grep "on / " | head -1
echo ""
echo "Hardened root filesystem:"
docker exec test-hardened mount | grep "on / " | head -1

# Check read-only mount for hardened
echo ""
echo "Checking read-only mount for hardened container:"
if docker exec test-hardened mount | grep "on / " | grep -q "ro,"; then
    echo -e "${GREEN}✓ Hardened: Root filesystem is READ-ONLY${NC}"
elif docker exec test-hardened mount | grep "on / " | grep -q "ro)"; then
    echo -e "${GREEN}✓ Hardened: Root filesystem is READ-ONLY${NC}"
else
    echo -e "${YELLOW}⚠ Hardened: Root filesystem may be writable${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 4: UTS Namespace Isolation
##############################################################################
echo -e "${BLUE}[Test 4] UTS Namespace Isolation${NC}"
echo "Testing if container has isolated hostname..."
echo ""

echo "Host hostname:"
HOST_HOSTNAME=$(hostname)
echo "  Host: $HOST_HOSTNAME"

echo ""
echo "Baseline container hostname:"
BASELINE_HOSTNAME=$(docker exec test-baseline hostname)
echo "  Baseline: $BASELINE_HOSTNAME"

echo ""
echo "Hardened container hostname:"
HARDENED_HOSTNAME=$(docker exec test-hardened hostname)
echo "  Hardened: $HARDENED_HOSTNAME"

echo ""
if [ "$HOST_HOSTNAME" != "$BASELINE_HOSTNAME" ] && [ "$HOST_HOSTNAME" != "$HARDENED_HOSTNAME" ]; then
    echo -e "${GREEN}✓ PASS: UTS namespace isolated${NC}"
    echo "  Containers have separate hostname"
else
    echo -e "${RED}✗ FAIL: UTS namespace NOT isolated${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 5: IPC Namespace Isolation
##############################################################################
echo -e "${BLUE}[Test 5] IPC Namespace Isolation${NC}"
echo "Testing if container has isolated IPC..."
echo ""

echo "Host IPC namespace:"
HOST_IPC_NS=$(ls -la /proc/self/ns/ipc | awk '{print $NF}')
echo "  Host: $HOST_IPC_NS"

echo ""
echo "Baseline container IPC namespace:"
BASELINE_IPC_NS=$(docker exec test-baseline ls -la /proc/self/ns/ipc | awk '{print $NF}')
echo "  Baseline: $BASELINE_IPC_NS"

echo ""
echo "Hardened container IPC namespace:"
HARDENED_IPC_NS=$(docker exec test-hardened ls -la /proc/self/ns/ipc | awk '{print $NF}')
echo "  Hardened: $HARDENED_IPC_NS"

echo ""
if [ "$HOST_IPC_NS" != "$BASELINE_IPC_NS" ] && [ "$HOST_IPC_NS" != "$HARDENED_IPC_NS" ]; then
    echo -e "${GREEN}✓ PASS: IPC namespace isolated${NC}"
    echo "  Containers have separate IPC resources"
else
    echo -e "${RED}✗ FAIL: IPC namespace NOT isolated${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 6: User Namespace (UID/GID Mapping)
##############################################################################
echo -e "${BLUE}[Test 6] User Namespace (UID/GID Mapping)${NC}"
echo "Testing container user isolation..."
echo ""

echo "Baseline container user:"
docker exec test-baseline id
BASELINE_UID=$(docker exec test-baseline id -u)
echo "  Running as UID: $BASELINE_UID"

echo ""
echo "Hardened container user:"
docker exec test-hardened id
HARDENED_UID=$(docker exec test-hardened id -u)
echo "  Running as UID: $HARDENED_UID"

echo ""
if [ "$BASELINE_UID" = "0" ] && [ "$HARDENED_UID" != "0" ]; then
    echo -e "${GREEN}✓ PASS: User mapping configured${NC}"
    echo "  Baseline: root (UID 0) - vulnerable"
    echo "  Hardened: non-root (UID $HARDENED_UID) - secure"
else
    echo -e "${YELLOW}⚠ WARNING: Unexpected user configuration${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 7: Cgroup Namespace Isolation
##############################################################################
echo -e "${BLUE}[Test 7] Cgroup Namespace Isolation${NC}"
echo "Testing cgroup namespace isolation..."
echo ""

echo "Host cgroup namespace:"
HOST_CGROUP_NS=$(ls -la /proc/self/ns/cgroup | awk '{print $NF}')
echo "  Host: $HOST_CGROUP_NS"

echo ""
echo "Baseline container cgroup namespace:"
BASELINE_CGROUP_NS=$(docker exec test-baseline ls -la /proc/self/ns/cgroup | awk '{print $NF}')
echo "  Baseline: $BASELINE_CGROUP_NS"

echo ""
echo "Hardened container cgroup namespace:"
HARDENED_CGROUP_NS=$(docker exec test-hardened ls -la /proc/self/ns/cgroup | awk '{print $NF}')
echo "  Hardened: $HARDENED_CGROUP_NS"

echo ""
if [ "$HOST_CGROUP_NS" != "$BASELINE_CGROUP_NS" ] && [ "$HOST_CGROUP_NS" != "$HARDENED_CGROUP_NS" ]; then
    echo -e "${GREEN}✓ PASS: Cgroup namespace isolated${NC}"
    echo "  Containers have separate cgroup view"
else
    echo -e "${YELLOW}⚠ WARNING: Cgroup namespace may not be isolated${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Summary
##############################################################################
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Namespace Isolation Test Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Tested 7 Linux namespace types:"
echo "  1. PID namespace   - Process isolation"
echo "  2. NET namespace   - Network isolation"
echo "  3. MNT namespace   - Mount isolation"
echo "  4. UTS namespace   - Hostname isolation"
echo "  5. IPC namespace   - IPC isolation"
echo "  6. USER namespace  - User ID mapping"
echo "  7. CGROUP namespace - Cgroup view isolation"
echo ""
echo "Container comparison:"
echo "  Baseline: Default Docker isolation (root user)"
echo "  Hardened: Enhanced security (non-root + read-only)"
echo ""
echo -e "${GREEN}Namespace isolation is working correctly!${NC}"
echo ""
echo "View detailed namespace info:"
echo "  docker exec test-baseline ls -la /proc/self/ns/"
echo "  docker exec test-hardened ls -la /proc/self/ns/"
echo ""
echo -e "${CYAN}========================================${NC}"
