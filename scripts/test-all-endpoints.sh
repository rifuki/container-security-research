#!/bin/bash

# Container Security Test Application - Endpoint Testing Script
# Tests all available endpoints to verify functionality

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
BASE_URL="${BASE_URL:-http://localhost:3000}"
OUTPUT_DIR="./test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Log file
LOG_FILE="$OUTPUT_DIR/test_${TIMESTAMP}.log"

# Functions
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1" | tee -a "$LOG_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1" | tee -a "$LOG_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1" | tee -a "$LOG_FILE"
}

warning() {
    echo -e "${YELLOW}⚠${NC} $1" | tee -a "$LOG_FILE"
}

test_endpoint() {
    local name=$1
    local endpoint=$2
    local expected_status=${3:-200}
    
    log "Testing: $name"
    
    response=$(curl -s -w "\n%{http_code}" "$BASE_URL$endpoint")
    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | sed '$d')
    
    if [ "$http_code" -eq "$expected_status" ]; then
        success "$name - Status: $http_code"
        echo "$body" | jq '.' > "$OUTPUT_DIR/${name// /_}_${TIMESTAMP}.json" 2>/dev/null || echo "$body" > "$OUTPUT_DIR/${name// /_}_${TIMESTAMP}.txt"
        return 0
    else
        error "$name - Expected: $expected_status, Got: $http_code"
        return 1
    fi
}

# Header
echo ""
echo "======================================================================"
echo "  Container Security Test Application - Endpoint Testing"
echo "======================================================================"
echo ""
log "Base URL: $BASE_URL"
log "Output Directory: $OUTPUT_DIR"
log "Log File: $LOG_FILE"
echo ""

# Check if server is running
log "Checking server availability..."
if ! curl -s --max-time 5 "$BASE_URL" > /dev/null; then
    error "Server is not responding at $BASE_URL"
    error "Please start the server first: node app.js"
    exit 1
fi
success "Server is running"
echo ""

# Test counters
total_tests=0
passed_tests=0
failed_tests=0

# ========================================
# 1. Basic Endpoints
# ========================================
echo "========================================"
echo "1. Basic Endpoints"
echo "========================================"

((total_tests++))
test_endpoint "Root API Info" "/" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Health Check" "/health" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Health Live" "/health/live" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Health Ready" "/health/ready" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Health Startup" "/health/startup" && ((passed_tests++)) || ((failed_tests++))
echo ""

# ========================================
# 2. System Information Endpoints
# ========================================
echo "========================================"
echo "2. System Information Endpoints"
echo "========================================"

((total_tests++))
test_endpoint "System Info" "/info" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Namespace Info" "/info/namespace" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Cgroup Info" "/info/cgroup" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Security Info" "/info/security" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
test_endpoint "Complete Info" "/info/all" && ((passed_tests++)) || ((failed_tests++))
echo ""

# ========================================
# 3. Stress Testing Endpoints
# ========================================
echo "========================================"
echo "3. Stress Testing Endpoints"
echo "========================================"

((total_tests++))
log "Testing: CPU Stress (Small)"
test_endpoint "CPU Stress Small" "/stress/cpu?iterations=100000" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: CPU Stress (Medium)"
test_endpoint "CPU Stress Medium" "/stress/cpu?iterations=1000000" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Memory Stress (Small)"
test_endpoint "Memory Stress Small" "/stress/memory?size=50" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Memory Stress (Medium)"
test_endpoint "Memory Stress Medium" "/stress/memory?size=100" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Combined Stress"
test_endpoint "Combined Stress" "/stress/combined?iterations=50000&size=25" && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Disk I/O Stress"
test_endpoint "Disk IO Stress" "/stress/disk?operations=50" && ((passed_tests++)) || ((failed_tests++))
echo ""

# ========================================
# 4. Metrics Endpoint
# ========================================
echo "========================================"
echo "4. Metrics Endpoint"
echo "========================================"

((total_tests++))
log "Testing: Prometheus Metrics"
if curl -s "$BASE_URL/metrics" > "$OUTPUT_DIR/metrics_${TIMESTAMP}.txt"; then
    success "Prometheus Metrics"
    ((passed_tests++))
else
    error "Prometheus Metrics"
    ((failed_tests++))
fi
echo ""

# ========================================
# 5. Legacy Endpoints (Backward Compatibility)
# ========================================
echo "========================================"
echo "5. Legacy Endpoints"
echo "========================================"

((total_tests++))
log "Testing: Legacy Namespace (expects redirect)"
test_endpoint "Legacy Namespace" "/namespace" 302 && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Legacy Cgroup (expects redirect)"
test_endpoint "Legacy Cgroup" "/cgroup" 302 && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Legacy Compute (expects redirect)"
test_endpoint "Legacy Compute" "/compute?iterations=50000" 302 && ((passed_tests++)) || ((failed_tests++))
echo ""

((total_tests++))
log "Testing: Legacy Memory (expects redirect)"
test_endpoint "Legacy Memory" "/memory?size=50" 302 && ((passed_tests++)) || ((failed_tests++))
echo ""

# ========================================
# 6. Error Handling (Negative Tests)
# ========================================
echo "========================================"
echo "6. Error Handling Tests"
echo "========================================"

((total_tests++))
log "Testing: 404 Not Found"
test_endpoint "404 Not Found" "/nonexistent" 404 && ((passed_tests++)) || ((failed_tests++))
echo ""

# ========================================
# Performance Benchmarking
# ========================================
echo "========================================"
echo "7. Performance Benchmarking"
echo "========================================"

log "Running performance benchmarks..."

# Benchmark health endpoint
log "Benchmarking /health endpoint (100 requests)..."
ab -n 100 -c 10 -q "$BASE_URL/health" > "$OUTPUT_DIR/bench_health_${TIMESTAMP}.txt" 2>&1 || {
    warning "ApacheBench (ab) not installed. Skipping performance benchmarks."
    warning "Install with: brew install httpd (macOS) or apt install apache2-utils (Linux)"
}

# ========================================
# Summary
# ========================================
echo ""
echo "======================================================================"
echo "  Test Summary"
echo "======================================================================"
echo ""
echo "Total Tests:  $total_tests"
success "Passed:       $passed_tests"
error "Failed:       $failed_tests"
echo ""

# Calculate success rate
success_rate=$((passed_tests * 100 / total_tests))
echo "Success Rate: ${success_rate}%"
echo ""

if [ $failed_tests -eq 0 ]; then
    success "All tests passed! ✨"
    echo ""
    log "Results saved to: $OUTPUT_DIR"
    exit 0
else
    error "Some tests failed. Please check the logs."
    echo ""
    log "Results saved to: $OUTPUT_DIR"
    exit 1
fi
