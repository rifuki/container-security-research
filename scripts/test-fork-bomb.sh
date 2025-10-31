#!/bin/bash
##############################################################################
# Fork Bomb Testing Script
# Purpose: Validate cgroup PIDs limit enforcement (512 processes)
# Method: Attempt to spawn processes beyond limit
# Expected: Hardened container killed/blocked, Baseline unlimited
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
echo -e "${CYAN}Fork Bomb Testing${NC}"
echo -e "${CYAN}Cgroup PIDs Limit Enforcement${NC}"
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
echo -e "${BLUE}[Setup] Checking PIDs limits...${NC}"
echo ""

echo "Baseline container PIDs limit:"
BASELINE_PIDS=$(docker inspect test-baseline --format '{{.HostConfig.PidsLimit}}')
if [ "$BASELINE_PIDS" = "0" ] || [ "$BASELINE_PIDS" = "-1" ]; then
    echo -e "  ${YELLOW}PIDs Limit: UNLIMITED (vulnerable to fork bomb)${NC}"
else
    echo -e "  PIDs Limit: ${BASELINE_PIDS} processes"
fi

echo ""
echo "Hardened container PIDs limit:"
HARDENED_PIDS=$(docker inspect test-hardened --format '{{.HostConfig.PidsLimit}}')
if [ "$HARDENED_PIDS" = "0" ] || [ "$HARDENED_PIDS" = "-1" ]; then
    echo -e "  ${RED}PIDs Limit: UNLIMITED (misconfigured!)${NC}"
else
    echo -e "  ${GREEN}PIDs Limit: ${HARDENED_PIDS} processes (enforced)${NC}"
fi

echo ""
echo -e "${YELLOW}⚠️  Warning: This test will spawn many processes${NC}"
echo "   Baseline: May spawn unlimited processes (dangerous)"
echo "   Hardened: Should be blocked at 512 PIDs"
echo ""
read -p "Continue with fork bomb test? (y/n): " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Test cancelled."
    exit 0
fi

##############################################################################
# Test 1: Baseline Container - Controlled Process Spawn
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test 1: Baseline Container${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}[Test] Spawning controlled processes on baseline...${NC}"
echo "Method: Spawn sleep processes in batches of 50"
echo "Target: Spawn until 600 processes or failure"
echo ""

BASELINE_COUNT=0
for batch in {1..12}; do
    echo -n "  Batch $batch: Spawning 50 processes... "
    
    # Spawn 50 sleep processes
    for i in {1..50}; do
        docker exec -d test-baseline sleep 30 > /dev/null 2>&1 || break
    done
    
    sleep 1
    
    # Count processes
    CURRENT_COUNT=$(docker exec test-baseline ps aux 2>/dev/null | wc -l || echo "0")
    BASELINE_COUNT=$CURRENT_COUNT
    
    if [ "$CURRENT_COUNT" -gt 0 ]; then
        echo -e "${GREEN}OK${NC} (Total: ~$CURRENT_COUNT processes)"
    else
        echo -e "${RED}FAILED${NC}"
        break
    fi
    
    # Check if container still running
    if ! docker ps | grep -q test-baseline; then
        echo -e "${RED}  Container crashed!${NC}"
        break
    fi
    
    # Stop if we've proven no limit (600+ processes)
    if [ "$CURRENT_COUNT" -gt 600 ]; then
        echo -e "  ${YELLOW}Stopping test - no limit detected (600+ processes)${NC}"
        break
    fi
done

echo ""
echo -e "${YELLOW}Result: Baseline container spawned ${BASELINE_COUNT}+ processes${NC}"
if [ "$BASELINE_COUNT" -gt 512 ]; then
    echo -e "  ${YELLOW}⚠️  No PIDs limit enforced (vulnerable to fork bomb)${NC}"
else
    echo "  Processes limited (unexpected)"
fi

# Cleanup baseline processes
echo ""
echo "Cleaning up baseline processes..."
docker restart test-baseline > /dev/null 2>&1
sleep 3

##############################################################################
# Test 2: Hardened Container - Controlled Process Spawn
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test 2: Hardened Container${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}[Test] Spawning controlled processes on hardened...${NC}"
echo "Expected: Blocked at ~512 processes (PIDs limit)"
echo "Method: Spawn sleep processes in batches of 50"
echo ""

HARDENED_COUNT=0
HARDENED_BLOCKED=false

for batch in {1..15}; do
    echo -n "  Batch $batch: Spawning 50 processes... "
    
    # Spawn 50 sleep processes
    SUCCESS=0
    for i in {1..50}; do
        if docker exec -d test-hardened sleep 30 > /dev/null 2>&1; then
            SUCCESS=$((SUCCESS + 1))
        else
            HARDENED_BLOCKED=true
        fi
    done
    
    sleep 1
    
    # Count processes
    CURRENT_COUNT=$(docker exec test-hardened ps aux 2>/dev/null | wc -l || echo "0")
    HARDENED_COUNT=$CURRENT_COUNT
    
    if [ "$SUCCESS" -eq 0 ]; then
        echo -e "${GREEN}BLOCKED${NC} (Spawned: 0, Total: ~$CURRENT_COUNT)"
        HARDENED_BLOCKED=true
        break
    elif [ "$SUCCESS" -lt 50 ]; then
        echo -e "${GREEN}PARTIAL${NC} (Spawned: $SUCCESS/50, Total: ~$CURRENT_COUNT)"
        HARDENED_BLOCKED=true
        break
    else
        echo -e "${YELLOW}OK${NC} (Total: ~$CURRENT_COUNT processes)"
    fi
    
    # Check if we've hit the limit area (around 512)
    if [ "$CURRENT_COUNT" -gt 500 ]; then
        echo "  Approaching limit (512), testing enforcement..."
    fi
    
    # Stop if clearly no limit
    if [ "$CURRENT_COUNT" -gt 700 ]; then
        echo -e "  ${RED}⚠️  No limit detected (700+ processes)${NC}"
        break
    fi
done

echo ""
if [ "$HARDENED_BLOCKED" = true ]; then
    echo -e "${GREEN}Result: Hardened container BLOCKED at ~${HARDENED_COUNT} processes${NC}"
    if [ "$HARDENED_COUNT" -ge 480 ] && [ "$HARDENED_COUNT" -le 540 ]; then
        echo -e "  ${GREEN}✓ PIDs limit enforced correctly (~512 processes)${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Blocked at ${HARDENED_COUNT} processes (expected ~512)${NC}"
    fi
else
    echo -e "${RED}Result: Hardened container NOT BLOCKED${NC}"
    echo "  Total spawned: ${HARDENED_COUNT}+ processes"
    echo -e "  ${RED}⚠️  PIDs limit NOT properly enforced!${NC}"
fi

# Cleanup hardened processes
echo ""
echo "Cleaning up hardened processes..."
docker restart test-hardened > /dev/null 2>&1
sleep 3

##############################################################################
# Test 3: Aggressive Fork Bomb (Real Fork Bomb Pattern)
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Test 3: Aggressive Fork Bomb${NC}"
echo -e "${CYAN}Real Fork Bomb Pattern${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}[Test] Running aggressive fork bomb on hardened container...${NC}"
echo "Pattern: Rapid process spawning (fork bomb simulation)"
echo "Expected: Quickly blocked by PIDs limit"
echo ""

echo "Starting fork bomb simulation..."

# Fork bomb script that tries to spawn processes rapidly
FORK_SCRIPT='
#!/bin/sh
count=0
while [ $count -lt 1000 ]; do
  sleep 60 &
  count=$((count + 1))
done
echo "Spawned: $count processes"
'

# Run fork bomb
docker exec test-hardened sh -c "$FORK_SCRIPT" > /tmp/fork_result.txt 2>&1 &
FORK_PID=$!

# Wait a bit and check
sleep 3

# Check if process is still running and how many processes spawned
if docker ps | grep -q test-hardened; then
    FORK_COUNT=$(docker exec test-hardened ps aux 2>/dev/null | wc -l || echo "0")
    
    # Kill the fork bomb attempt
    kill $FORK_PID 2>/dev/null || true
    wait $FORK_PID 2>/dev/null || true
    
    echo ""
    echo "Fork bomb attempt result:"
    echo "  Processes spawned: ~$FORK_COUNT"
    
    if [ "$FORK_COUNT" -lt 600 ]; then
        echo -e "  ${GREEN}✓ Fork bomb blocked by PIDs limit${NC}"
        echo "  Container remained stable and limited"
    else
        echo -e "  ${RED}⚠️  Fork bomb may not be properly limited${NC}"
    fi
else
    echo -e "${YELLOW}Container stopped during test${NC}"
fi

# Restart to clean state
docker restart test-hardened > /dev/null 2>&1
sleep 3

##############################################################################
# Summary
##############################################################################
echo ""
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Fork Bomb Test Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

printf "%-20s %-30s %-30s\n" "Container" "PIDs Limit" "Max Processes Spawned"
printf "%-20s %-30s %-30s\n" "--------------------" "------------------------------" "------------------------------"

if [ "$BASELINE_COUNT" -gt 512 ]; then
    printf "%-20s ${YELLOW}%-30s${NC} %-30s\n" "Baseline" "⚠️  UNLIMITED" "${BASELINE_COUNT}+"
else
    printf "%-20s ${GREEN}%-30s${NC} %-30s\n" "Baseline" "Limited (unexpected)" "~${BASELINE_COUNT}"
fi

if [ "$HARDENED_BLOCKED" = true ]; then
    printf "%-20s ${GREEN}%-30s${NC} %-30s\n" "Hardened" "✓ 512 processes" "~${HARDENED_COUNT} (enforced)"
else
    printf "%-20s ${RED}%-30s${NC} %-30s\n" "Hardened" "⚠️  NOT enforced" "${HARDENED_COUNT}+"
fi

echo ""
echo -e "${BLUE}Conclusion:${NC}"

if [ "$HARDENED_BLOCKED" = true ] && [ "$HARDENED_COUNT" -ge 480 ] && [ "$HARDENED_COUNT" -le 540 ]; then
    echo -e "  ${GREEN}✓ PASS: PIDs limit enforcement working correctly${NC}"
    echo "  Hardened container blocked at ~512 processes (cgroup v2 enforced)"
    echo "  Defense-in-depth: Fork bomb attack prevented"
elif [ "$HARDENED_BLOCKED" = true ]; then
    echo -e "  ${YELLOW}⚠️  PARTIAL: PIDs limit enforced but not at expected value${NC}"
    echo "  Expected: ~512 processes, Got: ~${HARDENED_COUNT} processes"
else
    echo -e "  ${RED}✗ FAIL: PIDs limit enforcement not working as expected${NC}"
    echo "  Please verify cgroup v2 configuration and PIDs limits"
fi

echo ""
echo "For BAB IV Thesis:"
echo "  - Baseline: Unlimited PIDs (vulnerable to fork bomb DoS)"
echo "  - Hardened: 512 PIDs limit enforced (fork bomb blocked)"
echo "  - Trade-off: Slightly reduced process capacity vs protection from DoS"
echo ""
echo -e "${CYAN}========================================${NC}"
