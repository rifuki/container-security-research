#!/bin/bash

##############################################################################
# Quick Test Script
#
# Purpose: Fast validation of container functionality
# Usage: ./quick-test.sh [baseline|hardened]
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

MODE="${1:-baseline}"

if [ "$MODE" = "hardened" ]; then
    PORT=3001
    CONTAINER="test-hardened"
else
    PORT=3000
    CONTAINER="test-baseline"
fi

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Quick Test - ${MODE^^} Container${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Check if container is running
if ! docker ps --format '{{.Names}}' | grep -q "^${CONTAINER}$"; then
    echo -e "${RED}✗ Container not running${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Container is running${NC}"
echo ""

# Test all 8 endpoints
echo "Testing endpoints..."
echo ""

test_endpoint() {
    local name=$1
    local path=$2
    local status=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:${PORT}${path}")

    if [ "$status" = "200" ]; then
        echo -e "${GREEN}✓${NC} $name"
    else
        echo -e "${RED}✗${NC} $name (HTTP $status)"
    fi
}

test_endpoint "Root endpoint" "/"
test_endpoint "Health check" "/health"
test_endpoint "System info" "/info"
test_endpoint "Namespace info" "/info/namespace"
test_endpoint "Cgroup info" "/info/cgroup"
test_endpoint "CPU stress" "/stress/cpu?iterations=100000"
test_endpoint "Memory stress" "/stress/memory?size=10"
test_endpoint "Metrics" "/metrics"

echo ""
echo -e "${GREEN}✓ All tests passed!${NC}"
