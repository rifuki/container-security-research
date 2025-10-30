#!/bin/bash

##############################################################################
# Standard Benchmark Script
#
# Purpose: Measure container overhead using STANDARD benchmarking tools
# Primary Tools: Apache Bench (ab), wrk, sysbench
# Secondary: Custom endpoint validation
#
# Research Methodology: Industry-standard benchmarking
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
OUTPUT_DIR="./benchmark-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
RESULTS_FILE="$OUTPUT_DIR/standard_benchmark_${MODE}_${TIMESTAMP}.txt"

if [ "$MODE" = "hardened" ]; then
    CONTAINER_NAME="test-hardened"
    PORT=3001
else
    CONTAINER_NAME="test-baseline"
    PORT=3000
fi

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

warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo "⚠ $1" >> "$RESULTS_FILE"
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
# Tool Checks
##############################################################################

check_tools() {
    section "Checking Required Tools"

    local missing_tools=()

    # Check Apache Bench
    if command -v ab &> /dev/null; then
        success "Apache Bench (ab) - installed"
    else
        error "Apache Bench (ab) - not installed"
        missing_tools+=("ab")
    fi

    # Check wrk
    if command -v wrk &> /dev/null; then
        success "wrk - installed"
    else
        warning "wrk - not installed (optional)"
        echo "  Install: brew install wrk"
    fi

    # Check sysbench
    if command -v sysbench &> /dev/null; then
        success "sysbench - installed"
    else
        warning "sysbench - not installed (optional)"
        echo "  Install: brew install sysbench"
    fi

    # Check Docker
    if command -v docker &> /dev/null; then
        success "Docker - installed"
    else
        error "Docker - not installed"
        missing_tools+=("docker")
    fi

    # Check curl
    if command -v curl &> /dev/null; then
        success "curl - installed"
    else
        error "curl - not installed"
        missing_tools+=("curl")
    fi

    if [ ${#missing_tools[@]} -gt 0 ]; then
        echo ""
        error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Install instructions:"
        echo "  macOS: brew install apache2-utils"
        echo "  Linux: sudo apt-get install apache2-utils"
        exit 1
    fi

    echo ""
}

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

##############################################################################
# PRIMARY BENCHMARKS - Standard Tools
##############################################################################

benchmark_apache_bench() {
    section "Apache Bench (ab) - HTTP Load Testing"

    log "Running Apache Bench tests..."
    echo "" >> "$RESULTS_FILE"

    # Test configurations
    local tests=(
        "100:10:Light Load"
        "1000:50:Medium Load"
        "5000:100:Heavy Load"
        "10000:200:Very Heavy Load"
    )

    for test_config in "${tests[@]}"; do
        IFS=':' read -r requests concurrency description <<< "$test_config"

        echo -e "${MAGENTA}Test: $description${NC}"
        echo "  Requests: $requests"
        echo "  Concurrency: $concurrency"
        echo "" | tee -a "$RESULTS_FILE"

        log "Running ab -n $requests -c $concurrency..."

        # Run Apache Bench
        ab -n "$requests" -c "$concurrency" -g "$OUTPUT_DIR/ab_${MODE}_${requests}_${TIMESTAMP}.tsv" \
           "http://localhost:${PORT}/health" > "$OUTPUT_DIR/ab_${MODE}_${requests}_${TIMESTAMP}.txt" 2>&1

        # Extract key metrics
        local ab_output=$(cat "$OUTPUT_DIR/ab_${MODE}_${requests}_${TIMESTAMP}.txt")

        echo "Apache Bench Results - $description:" | tee -a "$RESULTS_FILE"
        echo "$ab_output" | grep "Requests per second:" | tee -a "$RESULTS_FILE"
        echo "$ab_output" | grep "Time per request:" | tee -a "$RESULTS_FILE"
        echo "$ab_output" | grep "Transfer rate:" | tee -a "$RESULTS_FILE"
        echo "$ab_output" | grep "Percentage of the requests" | head -5 | tee -a "$RESULTS_FILE"

        # Key metrics extraction
        local rps=$(echo "$ab_output" | grep "Requests per second:" | awk '{print $4}')
        local mean_time=$(echo "$ab_output" | grep "Time per request:" | head -1 | awk '{print $4}')
        local p50=$(echo "$ab_output" | grep "50%" | awk '{print $2}')
        local p95=$(echo "$ab_output" | grep "95%" | awk '{print $2}')
        local p99=$(echo "$ab_output" | grep "99%" | awk '{print $2}')

        echo "" | tee -a "$RESULTS_FILE"
        echo "Summary:" | tee -a "$RESULTS_FILE"
        echo "  Requests/sec: $rps" | tee -a "$RESULTS_FILE"
        echo "  Mean time: ${mean_time}ms" | tee -a "$RESULTS_FILE"
        echo "  P50: ${p50}ms" | tee -a "$RESULTS_FILE"
        echo "  P95: ${p95}ms" | tee -a "$RESULTS_FILE"
        echo "  P99: ${p99}ms" | tee -a "$RESULTS_FILE"
        echo "" | tee -a "$RESULTS_FILE"

        success "Completed: $description"
        sleep 3
    done

    success "Apache Bench tests completed"
}

benchmark_wrk() {
    if ! command -v wrk &> /dev/null; then
        warning "wrk not installed, skipping"
        return
    fi

    section "wrk - Modern HTTP Benchmarking Tool"

    log "Running wrk tests..."
    echo "" >> "$RESULTS_FILE"

    # Test configurations: duration:threads:connections:description
    local tests=(
        "30s:2:50:Light Load"
        "30s:4:100:Medium Load"
        "30s:8:200:Heavy Load"
    )

    for test_config in "${tests[@]}"; do
        IFS=':' read -r duration threads connections description <<< "$test_config"

        echo -e "${MAGENTA}Test: $description${NC}"
        echo "  Duration: $duration"
        echo "  Threads: $threads"
        echo "  Connections: $connections"
        echo "" | tee -a "$RESULTS_FILE"

        log "Running wrk -t$threads -c$connections -d$duration..."

        # Run wrk
        wrk -t"$threads" -c"$connections" -d"$duration" \
            --latency "http://localhost:${PORT}/health" \
            > "$OUTPUT_DIR/wrk_${MODE}_${description// /_}_${TIMESTAMP}.txt" 2>&1

        local wrk_output=$(cat "$OUTPUT_DIR/wrk_${MODE}_${description// /_}_${TIMESTAMP}.txt")

        echo "wrk Results - $description:" | tee -a "$RESULTS_FILE"
        echo "$wrk_output" | tee -a "$RESULTS_FILE"
        echo "" | tee -a "$RESULTS_FILE"

        success "Completed: $description"
        sleep 3
    done

    success "wrk tests completed"
}

benchmark_sysbench() {
    if ! command -v sysbench &> /dev/null; then
        warning "sysbench not installed, skipping"
        return
    fi

    section "sysbench - System Performance Benchmark"

    log "Running sysbench CPU test inside container..."
    echo "" >> "$RESULTS_FILE"

    # CPU benchmark inside container
    echo "CPU Benchmark (inside container):" | tee -a "$RESULTS_FILE"

    docker exec "$CONTAINER_NAME" sh -c "
        # Install sysbench if not available (Alpine)
        if ! command -v sysbench &> /dev/null; then
            apk add --no-cache sysbench 2>/dev/null || true
        fi

        # Run CPU benchmark if sysbench available
        if command -v sysbench &> /dev/null; then
            sysbench cpu --cpu-max-prime=20000 run
        else
            echo 'sysbench not available in container'
        fi
    " 2>&1 | tee -a "$OUTPUT_DIR/sysbench_${MODE}_${TIMESTAMP}.txt" | tee -a "$RESULTS_FILE"

    echo "" | tee -a "$RESULTS_FILE"

    success "sysbench test completed"
}

##############################################################################
# SECONDARY BENCHMARKS - Custom Validation
##############################################################################

benchmark_custom_endpoints() {
    section "Custom Endpoint Validation (Supporting Data)"

    log "Testing container-specific endpoints..."
    echo "" >> "$RESULTS_FILE"

    # Test namespace isolation
    echo "1. Namespace Isolation Check:" | tee -a "$RESULTS_FILE"
    local ns_response=$(curl -s "http://localhost:${PORT}/info/namespace")
    echo "$ns_response" | jq -r 'if .available then "   ✓ Namespace isolation: ACTIVE (" + (.namespaces | length | tostring) + " namespaces)" else "   ✗ Namespace: " + .message end' | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"

    # Test cgroup limits
    echo "2. Cgroup Resource Limits:" | tee -a "$RESULTS_FILE"
    local cg_response=$(curl -s "http://localhost:${PORT}/info/cgroup")
    echo "$cg_response" | jq -r 'if .available then "   ✓ Cgroup limits: ACTIVE" else "   ✗ Cgroup: " + .message end' | tee -a "$RESULTS_FILE"

    if echo "$cg_response" | jq -e '.limits' > /dev/null 2>&1; then
        echo "   Resource Limits:" | tee -a "$RESULTS_FILE"
        echo "$cg_response" | jq -r '
            if .limits.cpu then "     - CPU: " + .limits.cpu else "     - CPU: unlimited" end,
            if .limits.memory then "     - Memory: " + .limits.memory else "     - Memory: unlimited" end,
            if .limits.pids then "     - PIDs: " + .limits.pids else "     - PIDs: unlimited" end
        ' | tee -a "$RESULTS_FILE"
    fi
    echo "" | tee -a "$RESULTS_FILE"

    # CPU stress validation (5 runs for averaging)
    echo "3. CPU Stress Validation (Supporting):" | tee -a "$RESULTS_FILE"
    local cpu_iterations=10000000
    declare -a cpu_times=()

    for run in {1..5}; do
        local response=$(curl -s "http://localhost:${PORT}/stress/cpu?iterations=$cpu_iterations")
        local duration=$(echo "$response" | jq -r '.duration_ms // 0')
        cpu_times+=("$duration")
        echo "   Run $run: ${duration}ms" | tee -a "$RESULTS_FILE"
        sleep 1
    done

    # Calculate average
    local sum=0
    for time in "${cpu_times[@]}"; do
        sum=$((sum + time))
    done
    local avg=$((sum / 5))
    echo "   Average: ${avg}ms" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"

    # Memory stress validation (5 runs)
    echo "4. Memory Stress Validation (Supporting):" | tee -a "$RESULTS_FILE"
    local mem_size=100
    declare -a mem_times=()

    for run in {1..5}; do
        local response=$(curl -s "http://localhost:${PORT}/stress/memory?size=$mem_size")
        local duration=$(echo "$response" | jq -r '.duration_ms // 0')
        mem_times+=("$duration")
        echo "   Run $run: ${duration}ms" | tee -a "$RESULTS_FILE"
        sleep 2
    done

    # Calculate average
    local sum=0
    for time in "${mem_times[@]}"; do
        sum=$((sum + time))
    done
    local avg=$((sum / 5))
    echo "   Average: ${avg}ms" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"

    success "Custom validation completed"
}

##############################################################################
# Container Statistics
##############################################################################

collect_container_stats() {
    section "Container Resource Usage"

    log "Collecting Docker statistics..."
    echo "" >> "$RESULTS_FILE"

    echo "Docker Stats:" | tee -a "$RESULTS_FILE"
    docker stats --no-stream --format "  CPU: {{.CPUPerc}}\n  Memory: {{.MemUsage}} ({{.MemPerc}})\n  Network I/O: {{.NetIO}}\n  Block I/O: {{.BlockIO}}\n  PIDs: {{.PIDs}}" "$CONTAINER_NAME" | tee -a "$RESULTS_FILE"

    echo "" | tee -a "$RESULTS_FILE"

    # Save full inspect
    log "Saving container inspection data..."
    docker inspect "$CONTAINER_NAME" > "$OUTPUT_DIR/inspect_${MODE}_${TIMESTAMP}.json"

    # Extract security config
    echo "Security Configuration:" | tee -a "$RESULTS_FILE"
    docker inspect "$CONTAINER_NAME" | jq -r '.[0] | {
        User: .Config.User,
        ReadonlyRootfs: .HostConfig.ReadonlyRootfs,
        Memory: .HostConfig.Memory,
        NanoCpus: .HostConfig.NanoCpus,
        PidsLimit: .HostConfig.PidsLimit,
        CapDrop: .HostConfig.CapDrop,
        CapAdd: .HostConfig.CapAdd
    }' | tee -a "$RESULTS_FILE"

    echo "" | tee -a "$RESULTS_FILE"
}

##############################################################################
# Main Execution
##############################################################################

main() {
    section "Standard Benchmark Tool - ${MODE^^} MODE"

    echo "Configuration:" | tee -a "$RESULTS_FILE"
    echo "  Container: $CONTAINER_NAME" | tee -a "$RESULTS_FILE"
    echo "  Port: $PORT" | tee -a "$RESULTS_FILE"
    echo "  Timestamp: $TIMESTAMP" | tee -a "$RESULTS_FILE"
    echo "" | tee -a "$RESULTS_FILE"

    # Check tools
    check_tools

    # Check container
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

    # Wait for ready
    if ! wait_for_ready; then
        exit 1
    fi

    ##########################################################################
    # Run Benchmarks
    ##########################################################################

    # PRIMARY: Standard benchmarking tools
    benchmark_apache_bench
    benchmark_wrk
    benchmark_sysbench

    # SECONDARY: Custom endpoint validation
    benchmark_custom_endpoints

    # Collect stats
    collect_container_stats

    ##########################################################################
    # Summary
    ##########################################################################

    section "Benchmark Complete"

    success "All benchmarks completed!"
    echo ""
    echo "Results saved to: $RESULTS_FILE"
    echo ""
    echo "Detailed outputs:"
    echo "  - Apache Bench: $OUTPUT_DIR/ab_${MODE}_*_${TIMESTAMP}.txt"
    if command -v wrk &> /dev/null; then
        echo "  - wrk: $OUTPUT_DIR/wrk_${MODE}_*_${TIMESTAMP}.txt"
    fi
    if command -v sysbench &> /dev/null; then
        echo "  - sysbench: $OUTPUT_DIR/sysbench_${MODE}_${TIMESTAMP}.txt"
    fi
    echo "  - Container inspection: $OUTPUT_DIR/inspect_${MODE}_${TIMESTAMP}.json"
    echo ""

    if [ "$MODE" = "baseline" ]; then
        echo -e "${YELLOW}Next step: Run hardened container benchmark${NC}"
        echo "  npm run docker:run:hardened"
        echo "  ./scripts/benchmark-standard.sh hardened"
    elif [ "$MODE" = "hardened" ]; then
        echo -e "${YELLOW}Next step: Compare results${NC}"
        echo "  ./scripts/compare-standard.sh"
    fi

    echo ""
    success "Standard benchmark completed! ✨"
}

main "$@"
