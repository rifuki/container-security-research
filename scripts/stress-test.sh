#!/bin/bash

##############################################################################
# Container Stress Test Script
#
# Purpose: Measure CPU and memory overhead for research purposes
# Scope: Docker Engine only (no K8s)
#
# Usage:
#   ./stress-test.sh baseline   # Test baseline container
#   ./stress-test.sh hardened   # Test hardened container
#   ./stress-test.sh compare    # Compare both containers
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# Configuration
MODE="${1:-baseline}"
OUTPUT_DIR="./test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$OUTPUT_DIR/stress_test_${MODE}_${TIMESTAMP}.txt"

# Container configuration
if [ "$MODE" = "hardened" ]; then
    CONTAINER_NAME="test-hardened"
    PORT=3001
elif [ "$MODE" = "compare" ]; then
    echo "Running comparison mode..."
    exec bash "$0" baseline
    exec bash "$0" hardened
    exit 0
else
    CONTAINER_NAME="test-baseline"
    PORT=3000
fi

# Test parameters for research
CPU_ITERATIONS=(
    1000000      # 1M  - Light load
    10000000     # 10M - Medium load
    50000000     # 50M - Heavy load
)

MEMORY_SIZES=(
    50           # 50MB  - Small allocation
    100          # 100MB - Medium allocation
    200          # 200MB - Large allocation
)

REPEAT_COUNT=5   # Number of times to repeat each test for averaging

# Create output directory
mkdir -p "$OUTPUT_DIR"

##############################################################################
# Helper Functions
##############################################################################

log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
    echo "[$(date +'%H:%M:%S')] $1" >> "$RESULTS_FILE"
}

success() {
    echo -e "${GREEN}✓${NC} $1"
    echo "✓ $1" >> "$RESULTS_FILE"
}

error() {
    echo -e "${RED}✗${NC} $1"
    echo "✗ $1" >> "$RESULTS_FILE"
}

section() {
    echo ""
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}========================================${NC}"
    echo ""
    echo "========================================" >> "$RESULTS_FILE"
    echo "$1" >> "$RESULTS_FILE"
    echo "========================================" >> "$RESULTS_FILE"
}

##############################################################################
# Container Management
##############################################################################

check_container() {
    if docker ps --format '{{.Names}}' | grep -q "^${CONTAINER_NAME}$"; then
        return 0
    else
        return 1
    fi
}

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

get_container_stats() {
    # Get container resource usage
    docker stats --no-stream --format "{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}" "$CONTAINER_NAME"
}

get_container_cpu() {
    docker stats --no-stream --format "{{.CPUPerc}}" "$CONTAINER_NAME" | sed 's/%//'
}

get_container_memory() {
    docker stats --no-stream --format "{{.MemUsage}}" "$CONTAINER_NAME" | awk '{print $1}'
}

##############################################################################
# Stress Test Functions
##############################################################################

# CPU Stress Test
test_cpu_stress() {
    local iterations=$1
    local run_number=$2

    log "CPU Test: $iterations iterations (Run $run_number/$REPEAT_COUNT)"

    # Get baseline CPU usage
    local cpu_before=$(get_container_cpu)

    # Execute stress test
    local start_time=$(date +%s%N)
    local response=$(curl -s "http://localhost:${PORT}/stress/cpu?iterations=$iterations")
    local end_time=$(date +%s%N)

    # Calculate duration in milliseconds
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))

    # Get CPU usage after stress
    sleep 1
    local cpu_after=$(get_container_cpu)

    # Extract response data
    local app_duration=$(echo "$response" | jq -r '.duration_ms // 0')
    local iterations_done=$(echo "$response" | jq -r '.iterations // 0')

    # Calculate throughput
    local throughput=0
    if [ "$app_duration" -gt 0 ]; then
        throughput=$((iterations_done * 1000 / app_duration))
    fi

    # Output results
    echo "  Iterations: $iterations_done"
    echo "  App Duration: ${app_duration}ms"
    echo "  Total Duration: ${duration_ms}ms"
    echo "  Throughput: ${throughput} iter/sec"
    echo "  CPU Before: ${cpu_before}%"
    echo "  CPU After: ${cpu_after}%"
    echo ""

    # Append to results file
    cat >> "$RESULTS_FILE" << EOF
  Run $run_number:
    Iterations: $iterations_done
    App Duration: ${app_duration}ms
    Total Duration: ${duration_ms}ms
    Throughput: ${throughput} iter/sec
    CPU Before: ${cpu_before}%
    CPU After: ${cpu_after}%
EOF

    # Return duration for averaging
    echo "$app_duration"
}

# Memory Stress Test
test_memory_stress() {
    local size_mb=$1
    local run_number=$2

    log "Memory Test: ${size_mb}MB (Run $run_number/$REPEAT_COUNT)"

    # Get baseline memory usage
    local mem_before=$(get_container_memory)

    # Execute stress test
    local start_time=$(date +%s%N)
    local response=$(curl -s "http://localhost:${PORT}/stress/memory?size=$size_mb")
    local end_time=$(date +%s%N)

    # Calculate duration in milliseconds
    local duration_ns=$((end_time - start_time))
    local duration_ms=$((duration_ns / 1000000))

    # Wait for memory to stabilize
    sleep 2
    local mem_after=$(get_container_memory)

    # Extract response data
    local app_duration=$(echo "$response" | jq -r '.duration_ms // 0')
    local allocated_mb=$(echo "$response" | jq -r '.allocated_mb // 0')
    local rss_mb=$(echo "$response" | jq -r '.memory_usage.rss_mb // 0')

    # Output results
    echo "  Allocated: ${allocated_mb}MB"
    echo "  App Duration: ${app_duration}ms"
    echo "  Total Duration: ${duration_ms}ms"
    echo "  RSS Usage: ${rss_mb}MB"
    echo "  Memory Before: ${mem_before}"
    echo "  Memory After: ${mem_after}"
    echo ""

    # Append to results file
    cat >> "$RESULTS_FILE" << EOF
  Run $run_number:
    Allocated: ${allocated_mb}MB
    App Duration: ${app_duration}ms
    Total Duration: ${duration_ms}ms
    RSS Usage: ${rss_mb}MB
    Memory Before: ${mem_before}
    Memory After: ${mem_after}
EOF

    # Return duration for averaging
    echo "$app_duration"
}

##############################################################################
# Statistical Analysis
##############################################################################

calculate_average() {
    local sum=0
    local count=0

    for value in "$@"; do
        sum=$((sum + value))
        count=$((count + 1))
    done

    if [ $count -gt 0 ]; then
        echo $((sum / count))
    else
        echo 0
    fi
}

##############################################################################
# Main Test Execution
##############################################################################

main() {
    # Header
    section "Container Stress Test - ${MODE^^} MODE"

    echo "Configuration:"
    echo "  Container: $CONTAINER_NAME"
    echo "  Port: $PORT"
    echo "  Timestamp: $TIMESTAMP"
    echo "  Repeat Count: $REPEAT_COUNT"
    echo ""

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it: brew install jq"
        exit 1
    fi

    # Check if container is running
    if ! check_container; then
        error "Container '$CONTAINER_NAME' is not running"
        echo ""
        echo "To start the container, run:"
        if [ "$MODE" = "hardened" ]; then
            echo "  npm run docker:run:hardened"
        else
            echo "  npm run docker:run:baseline"
        fi
        exit 1
    fi

    success "Container '$CONTAINER_NAME' is running"

    # Wait for container to be ready
    if ! wait_for_ready; then
        exit 1
    fi

    # Get container information
    section "Container Information"

    log "Fetching system info..."
    local info=$(curl -s "http://localhost:${PORT}/info")

    echo "System Information:" | tee -a "$RESULTS_FILE"
    echo "$info" | jq -r '"  Hostname: " + .hostname' | tee -a "$RESULTS_FILE"
    echo "$info" | jq -r '"  Platform: " + .platform + " " + .architecture' | tee -a "$RESULTS_FILE"
    echo "$info" | jq -r '"  Node: " + .node_version' | tee -a "$RESULTS_FILE"
    echo "$info" | jq -r '"  CPUs: " + (.cpus.count | tostring)' | tee -a "$RESULTS_FILE"
    echo "$info" | jq -r '"  Total Memory: " + .memory.total_mb + "MB"' | tee -a "$RESULTS_FILE"
    echo ""

    # Get namespace information
    log "Checking namespace isolation..."
    local ns_info=$(curl -s "http://localhost:${PORT}/info/namespace")
    if echo "$ns_info" | jq -e '.available' > /dev/null 2>&1; then
        success "Namespace isolation: ACTIVE"
        echo "  Namespaces detected:" | tee -a "$RESULTS_FILE"
        echo "$ns_info" | jq -r '.namespaces | to_entries[] | "    - " + .key + ": " + (.value.inode | tostring)' | tee -a "$RESULTS_FILE"
    else
        echo "$ns_info" | jq -r '"  Namespace: " + .message' | tee -a "$RESULTS_FILE"
    fi
    echo ""

    # Get cgroup information
    log "Checking cgroup limits..."
    local cg_info=$(curl -s "http://localhost:${PORT}/info/cgroup")
    if echo "$cg_info" | jq -e '.available' > /dev/null 2>&1; then
        success "Cgroup limits: ACTIVE"
        echo "  Resource limits:" | tee -a "$RESULTS_FILE"
        echo "$cg_info" | jq -r 'if .limits.cpu then "    CPU: " + .limits.cpu else "    CPU: unlimited" end' | tee -a "$RESULTS_FILE"
        echo "$cg_info" | jq -r 'if .limits.memory then "    Memory: " + .limits.memory else "    Memory: unlimited" end' | tee -a "$RESULTS_FILE"
        echo "$cg_info" | jq -r 'if .limits.pids then "    PIDs: " + .limits.pids else "    PIDs: unlimited" end' | tee -a "$RESULTS_FILE"
    else
        echo "$cg_info" | jq -r '"  Cgroup: " + .message' | tee -a "$RESULTS_FILE"
    fi
    echo ""

    ##########################################################################
    # CPU Stress Tests
    ##########################################################################

    section "CPU Stress Tests"

    for iterations in "${CPU_ITERATIONS[@]}"; do
        echo -e "${MAGENTA}Testing: $iterations iterations${NC}"
        echo "" >> "$RESULTS_FILE"
        echo "CPU Test: $iterations iterations" >> "$RESULTS_FILE"

        # Array to store durations for averaging
        declare -a durations=()

        # Run test multiple times
        for run in $(seq 1 $REPEAT_COUNT); do
            duration=$(test_cpu_stress "$iterations" "$run")
            durations+=("$duration")
            sleep 2  # Cool down between runs
        done

        # Calculate average
        avg_duration=$(calculate_average "${durations[@]}")

        echo -e "${GREEN}Average Duration: ${avg_duration}ms${NC}"
        echo "Average Duration: ${avg_duration}ms" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"

        sleep 3
    done

    ##########################################################################
    # Memory Stress Tests
    ##########################################################################

    section "Memory Stress Tests"

    for size in "${MEMORY_SIZES[@]}"; do
        echo -e "${MAGENTA}Testing: ${size}MB allocation${NC}"
        echo "" >> "$RESULTS_FILE"
        echo "Memory Test: ${size}MB" >> "$RESULTS_FILE"

        # Array to store durations for averaging
        declare -a durations=()

        # Run test multiple times
        for run in $(seq 1 $REPEAT_COUNT); do
            duration=$(test_memory_stress "$size" "$run")
            durations+=("$duration")
            sleep 3  # Cool down between runs
        done

        # Calculate average
        avg_duration=$(calculate_average "${durations[@]}")

        echo -e "${GREEN}Average Duration: ${avg_duration}ms${NC}"
        echo "Average Duration: ${avg_duration}ms" >> "$RESULTS_FILE"
        echo "" >> "$RESULTS_FILE"

        sleep 3
    done

    ##########################################################################
    # Final Container Statistics
    ##########################################################################

    section "Final Container Statistics"

    log "Collecting final metrics..."
    echo "" >> "$RESULTS_FILE"

    # Docker stats
    echo "Container Resource Usage:" | tee -a "$RESULTS_FILE"
    docker stats --no-stream --format "  CPU: {{.CPUPerc}}\n  Memory: {{.MemUsage}} ({{.MemPerc}})\n  Network: {{.NetIO}}\n  Block I/O: {{.BlockIO}}" "$CONTAINER_NAME" | tee -a "$RESULTS_FILE"
    echo ""

    # Application metrics
    log "Fetching application metrics..."
    curl -s "http://localhost:${PORT}/metrics" > "$OUTPUT_DIR/metrics_${MODE}_${TIMESTAMP}.txt"
    success "Metrics saved to: $OUTPUT_DIR/metrics_${MODE}_${TIMESTAMP}.txt"

    ##########################################################################
    # Summary
    ##########################################################################

    section "Test Summary"

    success "All tests completed!"
    echo ""
    echo "Results saved to: $RESULTS_FILE"
    echo ""
    echo "Test Configuration:"
    echo "  - CPU tests: ${#CPU_ITERATIONS[@]} scenarios × $REPEAT_COUNT runs"
    echo "  - Memory tests: ${#MEMORY_SIZES[@]} scenarios × $REPEAT_COUNT runs"
    echo "  - Total tests: $(( (${#CPU_ITERATIONS[@]} + ${#MEMORY_SIZES[@]}) * REPEAT_COUNT ))"
    echo ""

    if [ "$MODE" = "baseline" ]; then
        echo -e "${YELLOW}Next step: Run hardened container test${NC}"
        echo "  npm run docker:run:hardened"
        echo "  ./scripts/stress-test.sh hardened"
    elif [ "$MODE" = "hardened" ]; then
        echo -e "${YELLOW}Next step: Compare results${NC}"
        echo "  ./scripts/compare-results.sh"
    fi

    echo ""
    success "Stress test completed! ✨"
}

# Run main function
main "$@"
