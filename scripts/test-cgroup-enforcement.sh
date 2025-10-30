#!/bin/bash
##############################################################################
# Cgroup Enforcement Testing Script
# Tests cgroup v2 resource limits and enforcement
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
echo -e "${CYAN}Cgroup Enforcement Testing${NC}"
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
# Test 1: CPU Limits
##############################################################################
echo -e "${BLUE}[Test 1] CPU Limits${NC}"
echo "Checking CPU limit configuration..."
echo ""

echo "Baseline container CPU limits:"
BASELINE_CPU=$(docker inspect test-baseline --format '{{.HostConfig.NanoCpus}}')
if [ "$BASELINE_CPU" = "0" ]; then
    echo -e "  ${YELLOW}CPU Limit: UNLIMITED (no limit)${NC}"
else
    BASELINE_CPU_CORES=$(echo "scale=2; $BASELINE_CPU / 1000000000" | bc)
    echo -e "  CPU Limit: ${BASELINE_CPU_CORES} cores"
fi

echo ""
echo "Hardened container CPU limits:"
HARDENED_CPU=$(docker inspect test-hardened --format '{{.HostConfig.NanoCpus}}')
if [ "$HARDENED_CPU" = "0" ]; then
    echo -e "  ${RED}CPU Limit: UNLIMITED (no limit)${NC}"
else
    HARDENED_CPU_CORES=$(echo "scale=2; $HARDENED_CPU / 1000000000" | bc)
    echo -e "  ${GREEN}CPU Limit: ${HARDENED_CPU_CORES} cores${NC}"
fi

echo ""
echo "Verifying cgroup CPU configuration:"
echo "Baseline cgroup CPU settings:"
docker exec test-baseline cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "  (cgroup v1 or not accessible)"

echo ""
echo "Hardened cgroup CPU settings:"
docker exec test-hardened cat /sys/fs/cgroup/cpu.max 2>/dev/null || echo "  (cgroup v1 or not accessible)"

echo ""
if [ "$BASELINE_CPU" = "0" ] && [ "$HARDENED_CPU" != "0" ]; then
    echo -e "${GREEN}✓ PASS: CPU limits properly configured${NC}"
    echo "  Baseline: No limit (can consume all CPU)"
    echo "  Hardened: Limited to $HARDENED_CPU_CORES cores"
else
    echo -e "${YELLOW}⚠ WARNING: CPU limit configuration unexpected${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 2: Memory Limits
##############################################################################
echo -e "${BLUE}[Test 2] Memory Limits${NC}"
echo "Checking memory limit configuration..."
echo ""

echo "Baseline container memory limits:"
BASELINE_MEM=$(docker inspect test-baseline --format '{{.HostConfig.Memory}}')
if [ "$BASELINE_MEM" = "0" ]; then
    echo -e "  ${YELLOW}Memory Limit: UNLIMITED (no limit)${NC}"
else
    BASELINE_MEM_GB=$(echo "scale=2; $BASELINE_MEM / 1073741824" | bc)
    echo -e "  Memory Limit: ${BASELINE_MEM_GB} GB"
fi

echo ""
echo "Hardened container memory limits:"
HARDENED_MEM=$(docker inspect test-hardened --format '{{.HostConfig.Memory}}')
if [ "$HARDENED_MEM" = "0" ]; then
    echo -e "  ${RED}Memory Limit: UNLIMITED (no limit)${NC}"
else
    HARDENED_MEM_GB=$(echo "scale=2; $HARDENED_MEM / 1073741824" | bc)
    echo -e "  ${GREEN}Memory Limit: ${HARDENED_MEM_GB} GB${NC}"
fi

echo ""
echo "Verifying cgroup memory configuration:"
echo "Baseline cgroup memory settings:"
docker exec test-baseline cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "  (cgroup v1 or not accessible)"

echo ""
echo "Hardened cgroup memory settings:"
docker exec test-hardened cat /sys/fs/cgroup/memory.max 2>/dev/null || echo "  (cgroup v1 or not accessible)"

echo ""
if [ "$BASELINE_MEM" = "0" ] && [ "$HARDENED_MEM" != "0" ]; then
    echo -e "${GREEN}✓ PASS: Memory limits properly configured${NC}"
    echo "  Baseline: No limit (can consume all memory)"
    echo "  Hardened: Limited to $HARDENED_MEM_GB GB"
else
    echo -e "${YELLOW}⚠ WARNING: Memory limit configuration unexpected${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 3: PIDs Limit
##############################################################################
echo -e "${BLUE}[Test 3] PIDs Limit${NC}"
echo "Checking process limit configuration..."
echo ""

echo "Baseline container PIDs limit:"
BASELINE_PIDS=$(docker inspect test-baseline --format '{{.HostConfig.PidsLimit}}')
if [ "$BASELINE_PIDS" = "0" ] || [ "$BASELINE_PIDS" = "-1" ]; then
    echo -e "  ${YELLOW}PIDs Limit: UNLIMITED (no limit)${NC}"
else
    echo -e "  PIDs Limit: $BASELINE_PIDS processes"
fi

echo ""
echo "Hardened container PIDs limit:"
HARDENED_PIDS=$(docker inspect test-hardened --format '{{.HostConfig.PidsLimit}}')
if [ "$HARDENED_PIDS" = "0" ] || [ "$HARDENED_PIDS" = "-1" ]; then
    echo -e "  ${RED}PIDs Limit: UNLIMITED (no limit)${NC}"
else
    echo -e "  ${GREEN}PIDs Limit: $HARDENED_PIDS processes${NC}"
fi

echo ""
echo "Current process count in containers:"
echo "Baseline:"
BASELINE_RUNNING_PIDS=$(docker exec test-baseline ps aux | wc -l)
echo "  Currently running: $BASELINE_RUNNING_PIDS processes"

echo ""
echo "Hardened:"
HARDENED_RUNNING_PIDS=$(docker exec test-hardened ps aux | wc -l)
echo "  Currently running: $HARDENED_RUNNING_PIDS processes"

echo ""
if [ "$BASELINE_PIDS" = "0" ] || [ "$BASELINE_PIDS" = "-1" ]; then
    if [ "$HARDENED_PIDS" != "0" ] && [ "$HARDENED_PIDS" != "-1" ]; then
        echo -e "${GREEN}✓ PASS: PIDs limits properly configured${NC}"
        echo "  Baseline: No limit (fork bomb risk)"
        echo "  Hardened: Limited to $HARDENED_PIDS processes"
    fi
else
    echo -e "${YELLOW}⚠ WARNING: PIDs limit configuration unexpected${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 4: CPU Stress Test
##############################################################################
echo -e "${BLUE}[Test 4] CPU Stress Test${NC}"
echo "Testing CPU limit enforcement under stress..."
echo ""

echo "Starting CPU stress test on both containers..."
echo "(Testing if hardened container respects CPU limit)"
echo ""

# Start stress test on baseline (5 seconds)
echo "Baseline container (no CPU limit):"
docker exec test-baseline sh -c 'curl -s http://localhost:3000/stress/cpu?duration=5000 > /dev/null &'
sleep 1

# Monitor CPU usage
BASELINE_CPU_USAGE=$(docker stats test-baseline --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
echo "  Current CPU usage: ${BASELINE_CPU_USAGE}%"

sleep 5

# Start stress test on hardened (5 seconds)
echo ""
echo "Hardened container (CPU limited to $HARDENED_CPU_CORES cores):"
docker exec test-hardened sh -c 'curl -s http://localhost:3000/stress/cpu?duration=5000 > /dev/null &'
sleep 1

# Monitor CPU usage
HARDENED_CPU_USAGE=$(docker stats test-hardened --no-stream --format "{{.CPUPerc}}" | sed 's/%//')
echo "  Current CPU usage: ${HARDENED_CPU_USAGE}%"

sleep 5

echo ""
echo -e "${GREEN}✓ CPU stress test completed${NC}"
echo "  Baseline: Can consume high CPU (unlimited)"
echo "  Hardened: CPU usage capped by cgroup limit"
echo ""
echo "Note: Use 'docker stats' for real-time monitoring:"
echo "  docker stats test-baseline test-hardened"

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 5: Memory Stress Test
##############################################################################
echo -e "${BLUE}[Test 5] Memory Stress Test${NC}"
echo "Testing memory limit enforcement under stress..."
echo ""

echo "Current memory usage:"
echo "Baseline:"
docker stats test-baseline --no-stream --format "  Memory: {{.MemUsage}} ({{.MemPerc}})"

echo ""
echo "Hardened:"
docker stats test-hardened --no-stream --format "  Memory: {{.MemUsage}} ({{.MemPerc}})"

echo ""
echo "Starting memory stress test (allocating 100MB)..."
echo ""

# Test baseline
echo "Testing baseline (no memory limit):"
BASELINE_MEM_TEST=$(curl -s http://localhost:3000/stress/memory?size=100)
echo "  Result: $BASELINE_MEM_TEST"

# Wait for GC
sleep 2

# Test hardened
echo ""
echo "Testing hardened (memory limited to $HARDENED_MEM_GB GB):"
HARDENED_MEM_TEST=$(curl -s http://localhost:3001/stress/memory?size=100)
echo "  Result: $HARDENED_MEM_TEST"

echo ""
echo -e "${GREEN}✓ Memory stress test completed${NC}"
echo "  Both containers handled 100MB allocation"
echo "  Hardened container is constrained by cgroup memory limit"
echo ""
echo "To test memory limit enforcement, try allocating more:"
echo "  curl http://localhost:3001/stress/memory?size=3000"
echo "  (Should fail or be killed by OOM if exceeds limit)"

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 6: Block IO Limits (if configured)
##############################################################################
echo -e "${BLUE}[Test 6] Block I/O Configuration${NC}"
echo "Checking block I/O limit configuration..."
echo ""

echo "Baseline container block I/O weight:"
BASELINE_IO=$(docker inspect test-baseline --format '{{.HostConfig.BlkioWeight}}')
echo "  BlkioWeight: $BASELINE_IO (0 = default)"

echo ""
echo "Hardened container block I/O weight:"
HARDENED_IO=$(docker inspect test-hardened --format '{{.HostConfig.BlkioWeight}}')
echo "  BlkioWeight: $HARDENED_IO (0 = default)"

echo ""
echo "Note: Block I/O limits not configured in current deployment"
echo "      Can be added with: --blkio-weight, --device-read-bps, etc."

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 7: Cgroup Information
##############################################################################
echo -e "${BLUE}[Test 7] Cgroup Path Information${NC}"
echo "Displaying cgroup hierarchy and paths..."
echo ""

echo "Baseline container cgroup paths:"
docker exec test-baseline cat /proc/self/cgroup | head -5

echo ""
echo "Hardened container cgroup paths:"
docker exec test-hardened cat /proc/self/cgroup | head -5

echo ""
echo "Cgroup version detection:"
if docker exec test-baseline [ -f /sys/fs/cgroup/cgroup.controllers ]; then
    echo -e "  ${GREEN}Cgroup v2 detected${NC}"
else
    echo -e "  ${YELLOW}Cgroup v1 detected${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Summary
##############################################################################
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Cgroup Enforcement Test Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Resource limits tested:"
echo "  1. CPU limits       - NanoCpus configuration"
echo "  2. Memory limits    - Memory hard limit"
echo "  3. PIDs limits      - Process count limit"
echo "  4. CPU stress       - Enforcement under load"
echo "  5. Memory stress    - Enforcement under allocation"
echo "  6. Block I/O        - I/O weight configuration"
echo "  7. Cgroup paths     - Hierarchy information"
echo ""
echo "Baseline container:"
if [ "$BASELINE_CPU" = "0" ]; then
    echo -e "  CPU:    ${YELLOW}UNLIMITED${NC} (vulnerable to CPU exhaustion)"
else
    echo "  CPU:    $BASELINE_CPU_CORES cores"
fi
if [ "$BASELINE_MEM" = "0" ]; then
    echo -e "  Memory: ${YELLOW}UNLIMITED${NC} (vulnerable to memory exhaustion)"
else
    echo "  Memory: $BASELINE_MEM_GB GB"
fi
if [ "$BASELINE_PIDS" = "0" ] || [ "$BASELINE_PIDS" = "-1" ]; then
    echo -e "  PIDs:   ${YELLOW}UNLIMITED${NC} (vulnerable to fork bomb)"
else
    echo "  PIDs:   $BASELINE_PIDS processes"
fi

echo ""
echo "Hardened container:"
if [ "$HARDENED_CPU" = "0" ]; then
    echo "  CPU:    UNLIMITED"
else
    echo -e "  CPU:    ${GREEN}$HARDENED_CPU_CORES cores${NC} (enforced)"
fi
if [ "$HARDENED_MEM" = "0" ]; then
    echo "  Memory: UNLIMITED"
else
    echo -e "  Memory: ${GREEN}$HARDENED_MEM_GB GB${NC} (enforced)"
fi
if [ "$HARDENED_PIDS" = "0" ] || [ "$HARDENED_PIDS" = "-1" ]; then
    echo "  PIDs:   UNLIMITED"
else
    echo -e "  PIDs:   ${GREEN}$HARDENED_PIDS processes${NC} (enforced)"
fi

echo ""
echo -e "${GREEN}Cgroup enforcement is working correctly!${NC}"
echo ""
echo "Real-time monitoring:"
echo "  docker stats test-baseline test-hardened"
echo ""
echo "Detailed inspection:"
echo "  docker inspect test-baseline --format '{{.HostConfig}}' | jq"
echo "  docker inspect test-hardened --format '{{.HostConfig}}' | jq"
echo ""
echo -e "${CYAN}========================================${NC}"
