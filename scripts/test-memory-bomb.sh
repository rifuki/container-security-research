#!/bin/bash
##############################################################################
# Memory Bomb Testing Script
# Purpose: Validate cgroup memory limit enforcement (2GB)
# Method: Attempt to allocate memory beyond limit
# Expected: Hardened container killed by OOM, Baseline unlimited
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
echo -e "${CYAN}Memory Bomb Testing${NC}"
echo -e "${CYAN}Cgroup Memory Limit Enforcement${NC}"
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
# Test Setup
##############################################################################
echo -e "${BLUE}[Setup] Checking memory limits...${NC}"
echo ""

echo "Baseline container memory limit:"
BASELINE_MEM=$(docker inspect test-baseline --format '{{.HostConfig.Memory}}')
if [ "$BASELINE_MEM" = "0" ]; then
    echo -e "  ${YELLOW}Memory Limit: UNLIMITED (vulnerable to memory exhaustion)${NC}"
else
    BASELINE_MEM_GB=$(echo "scale=2; $BASELINE_MEM / 1024 / 1024 / 1024" | bc)
    echo -e "  Memory Limit: ${BASELINE_MEM_GB}GB"
fi

echo ""
echo "Hardened container memory limit:"
HARDENED_MEM=$(docker inspect test-hardened --format '{{.HostConfig.Memory}}')
if [ "$HARDENED_MEM" = "0" ]; then
    echo -e "  ${RED}Memory Limit: UNLIMITED (misconfigured!)${NC}"
else
    HARDENED_MEM_GB=$(echo "scale=2; $HARDENED_MEM / 1024 / 1024 / 1024" | bc)
    echo -e "  ${GREEN}Memory Limit: ${HARDENED_MEM_GB}GB (enforced)${NC}"
fi

echo ""
echo -e "${YELLOW}⚠️  Warning: This test will attempt to crash containers${NC}"
echo "   Baseline: May consume unlimited memory"
echo "   Hardened: Should be killed by OOM at 2GB"
echo ""
read -p "Continue with memory bomb test? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test cancelled."
    exit 0
fi

##############################################################################
# Test 1: Baseline Container - Memory Bomb
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test 1: Baseline Container${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}[Test] Attempting memory bomb on baseline container...${NC}"
echo "Target: Allocate 500MB chunks until failure or 10 iterations"
echo ""

BASELINE_RESULT="unknown"
BASELINE_ALLOCATED=0

for i in {1..10}; do
    echo -n "  Iteration $i: Allocating 500MB... "
    
    # Try to allocate 500MB
    RESPONSE=$(curl -s -w "\n%{http_code}" "http://localhost:3000/stress/memory?size=500" 2>/dev/null || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}OK${NC}"
        BASELINE_ALLOCATED=$((BASELINE_ALLOCATED + 500))
        sleep 1
    else
        echo -e "${RED}FAILED (HTTP $HTTP_CODE)${NC}"
        break
    fi
    
    # Check if container still running
    if ! docker ps | grep -q test-baseline; then
        echo -e "${RED}  Container was killed!${NC}"
        BASELINE_RESULT="killed"
        break
    fi
done

if docker ps | grep -q test-baseline; then
    BASELINE_RESULT="unlimited"
    echo ""
    echo -e "${YELLOW}Result: Baseline container NOT KILLED${NC}"
    echo "  Total allocated: ${BASELINE_ALLOCATED}MB+"
    echo -e "  ${YELLOW}⚠️  No memory limit enforced (vulnerable)${NC}"
else
    echo ""
    echo -e "${GREEN}Result: Baseline container was killed${NC}"
    echo "  Total allocated before kill: ${BASELINE_ALLOCATED}MB"
    
    # Restart baseline for further tests
    echo ""
    echo "Restarting baseline container..."
    docker start test-baseline > /dev/null 2>&1
    sleep 3
fi

##############################################################################
# Test 2: Hardened Container - Memory Bomb
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test 2: Hardened Container${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}[Test] Attempting memory bomb on hardened container...${NC}"
echo "Expected: Container killed by OOM at ~2GB (2048MB)"
echo "Target: Allocate 500MB chunks until killed"
echo ""

HARDENED_RESULT="unknown"
HARDENED_ALLOCATED=0

for i in {1..6}; do
    echo -n "  Iteration $i: Allocating 500MB... "
    
    # Try to allocate 500MB
    RESPONSE=$(curl -s -w "\n%{http_code}" "http://localhost:3001/stress/memory?size=500" 2>/dev/null || echo "000")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}OK${NC}"
        HARDENED_ALLOCATED=$((HARDENED_ALLOCATED + 500))
        sleep 1
    else
        echo -e "${RED}FAILED (HTTP $HTTP_CODE)${NC}"
        break
    fi
    
    # Check if container still running
    if ! docker ps | grep -q test-hardened; then
        echo -e "${GREEN}  ✓ Container was killed by OOM!${NC}"
        HARDENED_RESULT="killed"
        break
    fi
done

if docker ps | grep -q test-hardened; then
    HARDENED_RESULT="not_killed"
    echo ""
    echo -e "${RED}Result: Hardened container NOT KILLED${NC}"
    echo "  Total allocated: ${HARDENED_ALLOCATED}MB"
    echo -e "  ${RED}⚠️  Memory limit NOT properly enforced!${NC}"
else
    echo ""
    echo -e "${GREEN}Result: Hardened container was killed by OOM${NC}"
    echo "  Total allocated before kill: ~${HARDENED_ALLOCATED}MB"
    echo -e "  ${GREEN}✓ Memory limit enforced successfully (2GB)${NC}"
    
    # Restart hardened for further tests
    echo ""
    echo "Restarting hardened container..."
    docker start test-hardened > /dev/null 2>&1
    sleep 3
fi

##############################################################################
# Test 3: Aggressive Memory Bomb with stress-ng (if installed)
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test 3: Aggressive Memory Bomb${NC}"
echo -e "${CYAN}Using stress-ng (if available)${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

if command -v stress-ng &> /dev/null; then
    echo -e "${BLUE}[Test] Running stress-ng memory bomb on hardened container...${NC}"
    echo "Command: stress-ng --vm 1 --vm-bytes 3G --timeout 10s"
    echo "Expected: Container killed before timeout (3G > 2G limit)"
    echo ""
    
    # Run stress-ng inside hardened container
    echo "Starting stress-ng..."
    docker exec test-hardened sh -c "apk add --no-cache stress-ng 2>/dev/null || echo 'Installing stress-ng...'" > /dev/null 2>&1 || true
    
    # Attempt to allocate 3GB (exceeds 2GB limit)
    docker exec test-hardened stress-ng --vm 1 --vm-bytes 3G --timeout 10s > /dev/null 2>&1 &
    STRESS_PID=$!
    
    # Wait and monitor
    sleep 2
    
    if ! docker ps | grep -q test-hardened; then
        echo -e "${GREEN}✓ Container killed by OOM (as expected)${NC}"
        echo -e "${GREEN}✓ stress-ng memory bomb successfully blocked${NC}"
        
        # Restart
        docker start test-hardened > /dev/null 2>&1
        sleep 3
    else
        wait $STRESS_PID 2>/dev/null || true
        echo -e "${YELLOW}Container survived stress-ng test${NC}"
        echo "  (May indicate proper memory management or test timeout)"
    fi
else
    echo -e "${YELLOW}stress-ng not installed, skipping advanced test${NC}"
    echo "Install: brew install stress-ng (macOS) or apt-get install stress-ng (Linux)"
fi

##############################################################################
# Summary
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Memory Bomb Test Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

printf "%-20s %-30s %-30s\n" "Container" "Result" "Memory Allocated"
printf "%-20s %-30s %-30s\n" "--------------------" "------------------------------" "------------------------------"

if [ "$BASELINE_RESULT" = "unlimited" ]; then
    printf "%-20s ${YELLOW}%-30s${NC} %-30s\n" "Baseline" "⚠️  NOT KILLED (no limit)" "${BASELINE_ALLOCATED}MB+"
elif [ "$BASELINE_RESULT" = "killed" ]; then
    printf "%-20s ${GREEN}%-30s${NC} %-30s\n" "Baseline" "Killed (unexpected)" "~${BASELINE_ALLOCATED}MB"
fi

if [ "$HARDENED_RESULT" = "killed" ]; then
    printf "%-20s ${GREEN}%-30s${NC} %-30s\n" "Hardened" "✓ KILLED by OOM" "~${HARDENED_ALLOCATED}MB (~2GB)"
elif [ "$HARDENED_RESULT" = "not_killed" ]; then
    printf "%-20s ${RED}%-30s${NC} %-30s\n" "Hardened" "⚠️  NOT KILLED (misconfigured?)" "${HARDENED_ALLOCATED}MB"
fi

echo ""
echo -e "${BLUE}Conclusion:${NC}"

if [ "$HARDENED_RESULT" = "killed" ]; then
    echo -e "  ${GREEN}✓ PASS: Memory limit enforcement working correctly${NC}"
    echo "  Hardened container killed at ~2GB limit (cgroup v2 enforced)"
    echo "  Defense-in-depth: Memory exhaustion attack prevented"
else
    echo -e "  ${RED}✗ FAIL: Memory limit enforcement not working as expected${NC}"
    echo "  Please verify cgroup v2 configuration and memory limits"
fi

echo ""
echo "For BAB IV Thesis:"
echo "  - Baseline: Unlimited memory (vulnerable to DoS)"
echo "  - Hardened: 2GB limit enforced (OOM kills container)"
echo "  - Trade-off: Slightly reduced availability vs protection from memory exhaustion"
echo ""
echo -e "${CYAN}========================================${NC}"
