#!/bin/bash

# Container Performance Benchmark Script
# Comprehensive performance testing for baseline vs hardened containers

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
CONTAINER_NAME="${CONTAINER_NAME:-node-test-app}"
PORT="${PORT:-3000}"
OUTPUT_DIR="./benchmark-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$OUTPUT_DIR/benchmark_${TIMESTAMP}.json"

# Test parameters
CPU_ITERATIONS=(100000 1000000 10000000)
MEMORY_SIZES=(50 100 200)
DISK_OPERATIONS=(100 500 1000)
HTTP_REQUESTS=1000
CONCURRENT_REQUESTS=50

# Create output directory
mkdir -p "$OUTPUT_DIR"

# Functions
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
}

error() {
    echo -e "${RED}✗${NC} $1"
}

section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
}

# Check if container is running
check_container() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

# Wait for container to be ready
wait_for_ready() {
    local max_attempts=30
    local attempt=0
    
    log "Waiting for container to be ready..."
    
    while [ $attempt -lt $max_attempts ]; do
        if curl -sf http://localhost:${PORT}/health > /dev/null 2>&1; then
            success "Container is ready"
            return 0
        fi
        sleep 1
        ((attempt++))
    done
    
    error "Container failed to become ready"
    return 1
}

# Get container stats
get_container_stats() {
    docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}\t{{.BlockIO}}" "$CONTAINER_NAME"
}

# Benchmark function
benchmark_endpoint() {
    local name=$1
    local endpoint=$2
    local output_file=$3
    
    log "Benchmarking: $name"
    
    # Using curl for timing
    local start_time=$(date +%s%3N)
    local response=$(curl -s -w "\n%{time_total}" "http://localhost:${PORT}${endpoint}")
    local end_time=$(date +%s%3N)
    
    local response_time=$(echo "$response" | tail -n1)
    local response_body=$(echo "$response" | sed '$d')
    
    local duration=$((end_time - start_time))
    
    echo "{" >> "$output_file"
    echo "  \"test\": \"$name\"," >> "$output_file"
    echo "  \"endpoint\": \"$endpoint\"," >> "$output_file"
    echo "  \"response_time_s\": $response_time," >> "$output_file"
    echo "  \"total_duration_ms\": $duration," >> "$output_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"" >> "$output_file"
    echo "}," >> "$output_file"
    
    success "$name completed in ${duration}ms (response time: ${response_time}s)"
}

# Main script
main() {
    # Header
    echo ""
    echo "======================================================================"
    echo "  Container Performance Benchmark"
    echo "======================================================================"
    echo "  Container: $CONTAINER_NAME"
    echo "  Port: $PORT"
    echo "  Timestamp: $TIMESTAMP"
    echo "======================================================================"
    echo ""
    
    # Check if container is running
    if ! check_container; then
        error "Container '$CONTAINER_NAME' is not running"
        error "Please start the container first"
        exit 1
    fi
    
    success "Container '$CONTAINER_NAME' is running"
    
    # Wait for container to be ready
    if ! wait_for_ready; then
        exit 1
    fi
    
    # Initialize results file
    echo "{" > "$RESULTS_FILE"
    echo "  \"benchmark_info\": {" >> "$RESULTS_FILE"
    echo "    \"container_name\": \"$CONTAINER_NAME\"," >> "$RESULTS_FILE"
    echo "    \"timestamp\": \"$(date -Iseconds)\"," >> "$RESULTS_FILE"
    echo "    \"port\": $PORT" >> "$RESULTS_FILE"
    echo "  }," >> "$RESULTS_FILE"
    echo "  \"results\": [" >> "$RESULTS_FILE"
    
    # ========================================
    # 1. Health Check Baseline
    # ========================================
    section "1. Health Check Baseline"
    benchmark_endpoint "Health Check" "/health" "$RESULTS_FILE"
    get_container_stats
    sleep 2
    
    # ========================================
    # 2. CPU Performance Tests
    # ========================================
    section "2. CPU Performance Tests"
    
    for iterations in "${CPU_ITERATIONS[@]}"; do
        log "Testing CPU with $iterations iterations"
        benchmark_endpoint "CPU-${iterations}" "/stress/cpu?iterations=$iterations" "$RESULTS_FILE"
        get_container_stats
        sleep 3
    done
    
    # ========================================
    # 3. Memory Performance Tests
    # ========================================
    section "3. Memory Performance Tests"
    
    for size in "${MEMORY_SIZES[@]}"; do
        log "Testing Memory allocation: ${size}MB"
        benchmark_endpoint "Memory-${size}MB" "/stress/memory?size=$size" "$RESULTS_FILE"
        get_container_stats
        sleep 3
    done
    
    # ========================================
    # 4. Combined Stress Tests
    # ========================================
    section "4. Combined Stress Tests"
    
    log "Testing combined CPU + Memory stress"
    benchmark_endpoint "Combined-Stress" "/stress/combined?iterations=1000000&size=100" "$RESULTS_FILE"
    get_container_stats
    sleep 3
    
    # ========================================
    # 5. Disk I/O Tests
    # ========================================
    section "5. Disk I/O Tests"
    
    for ops in "${DISK_OPERATIONS[@]}"; do
        log "Testing Disk I/O: $ops operations"
        benchmark_endpoint "DiskIO-${ops}" "/stress/disk?operations=$ops" "$RESULTS_FILE"
        get_container_stats
        sleep 3
    done
    
    # ========================================
    # 6. HTTP Load Testing
    # ========================================
    section "6. HTTP Load Testing"
    
    if command -v ab > /dev/null 2>&1; then
        log "Running ApacheBench test ($HTTP_REQUESTS requests, $CONCURRENT_REQUESTS concurrent)"
        
        ab_output=$(ab -n $HTTP_REQUESTS -c $CONCURRENT_REQUESTS -q "http://localhost:${PORT}/health" 2>&1)
        
        # Extract metrics
        requests_per_sec=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
        time_per_request=$(echo "$ab_output" | grep "Time per request.*mean" | head -1 | awk '{print $4}')
        
        log "Requests per second: $requests_per_sec"
        log "Time per request: ${time_per_request}ms"
        
        echo "$ab_output" > "$OUTPUT_DIR/ab_${TIMESTAMP}.txt"
    else
        warning "ApacheBench (ab) not installed. Skipping HTTP load test."
    fi
    
    # ========================================
    # 7. Container Resource Usage
    # ========================================
    section "7. Final Container Stats"
    
    get_container_stats
    
    # Get detailed container info
    log "Collecting container inspection data..."
    docker inspect "$CONTAINER_NAME" > "$OUTPUT_DIR/inspect_${TIMESTAMP}.json"
    
    # ========================================
    # Finalize Results
    # ========================================
    
    # Remove trailing comma from last result
    sed -i.bak '$ s/,$//' "$RESULTS_FILE" && rm "${RESULTS_FILE}.bak"
    
    echo "  ]," >> "$RESULTS_FILE"
    echo "  \"final_stats\": {" >> "$RESULTS_FILE"
    echo "    \"timestamp\": \"$(date -Iseconds)\"" >> "$RESULTS_FILE"
    echo "  }" >> "$RESULTS_FILE"
    echo "}" >> "$RESULTS_FILE"
    
    # ========================================
    # Summary
    # ========================================
    section "Benchmark Complete"
    
    success "Results saved to: $RESULTS_FILE"
    success "Container inspection: $OUTPUT_DIR/inspect_${TIMESTAMP}.json"
    
    if [ -f "$OUTPUT_DIR/ab_${TIMESTAMP}.txt" ]; then
        success "Load test results: $OUTPUT_DIR/ab_${TIMESTAMP}.txt"
    fi
    
    echo ""
    log "Summary:"
    echo "  - CPU tests: ${#CPU_ITERATIONS[@]}"
    echo "  - Memory tests: ${#MEMORY_SIZES[@]}"
    echo "  - Disk I/O tests: ${#DISK_OPERATIONS[@]}"
    echo "  - Combined tests: 1"
    if [ -f "$OUTPUT_DIR/ab_${TIMESTAMP}.txt" ]; then
        echo "  - HTTP load test: ✓"
    fi
    
    echo ""
    success "Benchmark completed successfully! ✨"
}

# Run main function
main "$@"
