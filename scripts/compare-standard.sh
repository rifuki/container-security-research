#!/bin/bash

##############################################################################
# Compare Standard Benchmark Results
#
# Purpose: Compare baseline vs hardened using STANDARD tools
# Analysis: Apache Bench, wrk, sysbench results
# Output: Scientific comparison for research
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

RESULTS_DIR="./benchmark-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
COMPARISON_FILE="$RESULTS_DIR/comparison_standard_${TIMESTAMP}.txt"

##############################################################################
# Helper Functions
##############################################################################

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
    echo ""
}

##############################################################################
# Real-time Benchmark Comparison
##############################################################################

compare_apache_bench() {
    section "Apache Bench - HTTP Performance Comparison"

    local baseline_port=3000
    local hardened_port=3001

    # Test configurations
    local tests=(
        "1000:50:Medium Load"
        "5000:100:Heavy Load"
    )

    echo "Apache Bench Comparison:" | tee "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    printf "%-20s %-25s %-25s %-15s\n" "Test" "Baseline (req/sec)" "Hardened (req/sec)" "Overhead (%)" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-25s %-25s %-15s\n" "--------------------" "-------------------------" "-------------------------" "---------------" | tee -a "$COMPARISON_FILE"

    for test_config in "${tests[@]}"; do
        IFS=':' read -r requests concurrency description <<< "$test_config"

        log "Testing: $description ($requests requests, $concurrency concurrent)"

        # Test baseline
        log "  Baseline..."
        ab -n "$requests" -c "$concurrency" -q "http://localhost:${baseline_port}/health" \
            > "$RESULTS_DIR/ab_baseline_compare_${TIMESTAMP}.tmp" 2>&1
        local baseline_rps=$(grep "Requests per second:" "$RESULTS_DIR/ab_baseline_compare_${TIMESTAMP}.tmp" | awk '{print $4}')
        local baseline_mean=$(grep "Time per request:" "$RESULTS_DIR/ab_baseline_compare_${TIMESTAMP}.tmp" | head -1 | awk '{print $4}')

        sleep 2

        # Test hardened
        log "  Hardened..."
        ab -n "$requests" -c "$concurrency" -q "http://localhost:${hardened_port}/health" \
            > "$RESULTS_DIR/ab_hardened_compare_${TIMESTAMP}.tmp" 2>&1
        local hardened_rps=$(grep "Requests per second:" "$RESULTS_DIR/ab_hardened_compare_${TIMESTAMP}.tmp" | awk '{print $4}')
        local hardened_mean=$(grep "Time per request:" "$RESULTS_DIR/ab_hardened_compare_${TIMESTAMP}.tmp" | head -1 | awk '{print $4}')

        # Calculate overhead (lower RPS = higher overhead)
        local overhead=0
        if [ -n "$baseline_rps" ] && [ -n "$hardened_rps" ]; then
            overhead=$(awk "BEGIN {printf \"%.2f\", (($baseline_rps - $hardened_rps) / $baseline_rps) * 100}")
        fi

        printf "%-20s %-25s %-25s %-15s\n" "$description" "$baseline_rps" "$hardened_rps" "$overhead" | tee -a "$COMPARISON_FILE"

        sleep 2
    done

    echo "" | tee -a "$COMPARISON_FILE"

    # Latency percentiles comparison
    echo "Latency Percentiles (1000 req, 50 concurrent):" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    # Run detailed test for percentiles
    log "Running detailed latency test..."

    ab -n 1000 -c 50 "http://localhost:${baseline_port}/health" \
        > "$RESULTS_DIR/ab_baseline_latency_${TIMESTAMP}.txt" 2>&1

    ab -n 1000 -c 50 "http://localhost:${hardened_port}/health" \
        > "$RESULTS_DIR/ab_hardened_latency_${TIMESTAMP}.txt" 2>&1

    local baseline_p50=$(grep "50%" "$RESULTS_DIR/ab_baseline_latency_${TIMESTAMP}.txt" | awk '{print $2}')
    local baseline_p95=$(grep "95%" "$RESULTS_DIR/ab_baseline_latency_${TIMESTAMP}.txt" | awk '{print $2}')
    local baseline_p99=$(grep "99%" "$RESULTS_DIR/ab_baseline_latency_${TIMESTAMP}.txt" | awk '{print $2}')

    local hardened_p50=$(grep "50%" "$RESULTS_DIR/ab_hardened_latency_${TIMESTAMP}.txt" | awk '{print $2}')
    local hardened_p95=$(grep "95%" "$RESULTS_DIR/ab_hardened_latency_${TIMESTAMP}.txt" | awk '{print $2}')
    local hardened_p99=$(grep "99%" "$RESULTS_DIR/ab_hardened_latency_${TIMESTAMP}.txt" | awk '{print $2}')

    printf "%-15s %-20s %-20s\n" "Percentile" "Baseline (ms)" "Hardened (ms)" | tee -a "$COMPARISON_FILE"
    printf "%-15s %-20s %-20s\n" "---------------" "--------------------" "--------------------" | tee -a "$COMPARISON_FILE"
    printf "%-15s %-20s %-20s\n" "P50 (median)" "$baseline_p50" "$hardened_p50" | tee -a "$COMPARISON_FILE"
    printf "%-15s %-20s %-20s\n" "P95" "$baseline_p95" "$hardened_p95" | tee -a "$COMPARISON_FILE"
    printf "%-15s %-20s %-20s\n" "P99" "$baseline_p99" "$hardened_p99" | tee -a "$COMPARISON_FILE"

    echo "" | tee -a "$COMPARISON_FILE"

    # Clean up temp files
    rm -f "$RESULTS_DIR"/*.tmp

    success "Apache Bench comparison completed"
}

compare_wrk() {
    if ! command -v wrk &> /dev/null; then
        echo "wrk not installed, skipping comparison" | tee -a "$COMPARISON_FILE"
        return
    fi

    section "wrk - HTTP Benchmark Comparison"

    local baseline_port=3000
    local hardened_port=3001

    echo "wrk Benchmark Comparison (30s, 4 threads, 100 connections):" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    log "Testing baseline..."
    wrk -t4 -c100 -d30s --latency "http://localhost:${baseline_port}/health" \
        > "$RESULTS_DIR/wrk_baseline_compare_${TIMESTAMP}.txt" 2>&1

    sleep 3

    log "Testing hardened..."
    wrk -t4 -c100 -d30s --latency "http://localhost:${hardened_port}/health" \
        > "$RESULTS_DIR/wrk_hardened_compare_${TIMESTAMP}.txt" 2>&1

    # Extract metrics
    echo "Baseline Results:" | tee -a "$COMPARISON_FILE"
    grep -E "Requests/sec:|Latency|Transfer/sec" "$RESULTS_DIR/wrk_baseline_compare_${TIMESTAMP}.txt" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    echo "Hardened Results:" | tee -a "$COMPARISON_FILE"
    grep -E "Requests/sec:|Latency|Transfer/sec" "$RESULTS_DIR/wrk_hardened_compare_${TIMESTAMP}.txt" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    success "wrk comparison completed"
}

compare_docker_stats() {
    section "Docker Stats Comparison"

    local baseline_name="test-baseline"
    local hardened_name="test-hardened"

    echo "Container Resource Usage:" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    # Check both containers are running
    if ! docker ps --format '{{.Names}}' | grep -q "^${baseline_name}$"; then
        error "Baseline container not running"
        return
    fi

    if ! docker ps --format '{{.Names}}' | grep -q "^${hardened_name}$"; then
        error "Hardened container not running"
        return
    fi

    # Collect stats
    local baseline_stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" "$baseline_name")
    local hardened_stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" "$hardened_name")

    local baseline_cpu=$(echo "$baseline_stats" | cut -d'|' -f1)
    local baseline_mem=$(echo "$baseline_stats" | cut -d'|' -f2)
    local baseline_mem_pct=$(echo "$baseline_stats" | cut -d'|' -f3)

    local hardened_cpu=$(echo "$hardened_stats" | cut -d'|' -f1)
    local hardened_mem=$(echo "$hardened_stats" | cut -d'|' -f2)
    local hardened_mem_pct=$(echo "$hardened_stats" | cut -d'|' -f3)

    printf "%-20s %-25s %-25s\n" "Metric" "Baseline" "Hardened" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-25s %-25s\n" "--------------------" "-------------------------" "-------------------------" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-25s %-25s\n" "CPU Usage" "$baseline_cpu" "$hardened_cpu" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-25s %-25s\n" "Memory Usage" "$baseline_mem" "$hardened_mem" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-25s %-25s\n" "Memory %" "$baseline_mem_pct" "$hardened_mem_pct" | tee -a "$COMPARISON_FILE"

    echo "" | tee -a "$COMPARISON_FILE"

    success "Docker stats comparison completed"
}

compare_security_config() {
    section "Security Configuration Comparison"

    local baseline_name="test-baseline"
    local hardened_name="test-hardened"

    echo "Security Hardening Features:" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    printf "%-35s %-20s %-20s\n" "Feature" "Baseline" "Hardened" | tee -a "$COMPARISON_FILE"
    printf "%-35s %-20s %-20s\n" "-----------------------------------" "--------------------" "--------------------" | tee -a "$COMPARISON_FILE"

    # User
    local baseline_user=$(docker inspect "$baseline_name" | jq -r '.[0].Config.User // "root"')
    local hardened_user=$(docker inspect "$hardened_name" | jq -r '.[0].Config.User // "root"')
    [ -z "$baseline_user" ] && baseline_user="root"
    printf "%-35s %-20s %-20s\n" "User" "$baseline_user" "$hardened_user" | tee -a "$COMPARISON_FILE"

    # CPU Limit
    local baseline_cpu=$(docker inspect "$baseline_name" | jq -r '.[0].HostConfig.NanoCpus // 0')
    local hardened_cpu=$(docker inspect "$hardened_name" | jq -r '.[0].HostConfig.NanoCpus // 0')
    baseline_cpu=$(awk "BEGIN {printf \"%.1f\", $baseline_cpu / 1000000000}")
    hardened_cpu=$(awk "BEGIN {printf \"%.1f\", $hardened_cpu / 1000000000}")
    [ "$baseline_cpu" = "0.0" ] && baseline_cpu="unlimited"
    [ "$hardened_cpu" = "0.0" ] && hardened_cpu="unlimited"
    printf "%-35s %-20s %-20s\n" "CPU Limit" "$baseline_cpu" "$hardened_cpu" | tee -a "$COMPARISON_FILE"

    # Memory Limit
    local baseline_mem=$(docker inspect "$baseline_name" | jq -r '.[0].HostConfig.Memory // 0')
    local hardened_mem=$(docker inspect "$hardened_name" | jq -r '.[0].HostConfig.Memory // 0')
    if [ "$baseline_mem" = "0" ]; then
        baseline_mem="unlimited"
    else
        baseline_mem="$((baseline_mem / 1024 / 1024))MB"
    fi
    if [ "$hardened_mem" = "0" ]; then
        hardened_mem="unlimited"
    else
        hardened_mem="$((hardened_mem / 1024 / 1024))MB"
    fi
    printf "%-35s %-20s %-20s\n" "Memory Limit" "$baseline_mem" "$hardened_mem" | tee -a "$COMPARISON_FILE"

    # PIDs Limit
    local baseline_pids=$(docker inspect "$baseline_name" | jq -r '.[0].HostConfig.PidsLimit // 0')
    local hardened_pids=$(docker inspect "$hardened_name" | jq -r '.[0].HostConfig.PidsLimit // 0')
    [ "$baseline_pids" = "0" ] && baseline_pids="unlimited"
    [ "$hardened_pids" = "0" ] && hardened_pids="unlimited"
    printf "%-35s %-20s %-20s\n" "PIDs Limit" "$baseline_pids" "$hardened_pids" | tee -a "$COMPARISON_FILE"

    # Read-only Filesystem
    local baseline_ro=$(docker inspect "$baseline_name" | jq -r '.[0].HostConfig.ReadonlyRootfs')
    local hardened_ro=$(docker inspect "$hardened_name" | jq -r '.[0].HostConfig.ReadonlyRootfs')
    printf "%-35s %-20s %-20s\n" "Read-only Filesystem" "$baseline_ro" "$hardened_ro" | tee -a "$COMPARISON_FILE"

    # Capabilities
    local baseline_caps=$(docker inspect "$baseline_name" | jq -r '.[0].HostConfig.CapDrop | length')
    local hardened_caps=$(docker inspect "$hardened_name" | jq -r '.[0].HostConfig.CapDrop | length')
    printf "%-35s %-20s %-20s\n" "Capabilities Dropped" "$baseline_caps" "$hardened_caps" | tee -a "$COMPARISON_FILE"

    # No New Privileges
    local baseline_nnp=$(docker inspect "$baseline_name" | jq -r '.[0].HostConfig.SecurityOpt | select(. != null) | map(select(startswith("no-new-privileges"))) | length')
    local hardened_nnp=$(docker inspect "$hardened_name" | jq -r '.[0].HostConfig.SecurityOpt | select(. != null) | map(select(startswith("no-new-privileges"))) | length')
    [ "$baseline_nnp" = "0" ] || [ -z "$baseline_nnp" ] && baseline_nnp="false" || baseline_nnp="true"
    [ "$hardened_nnp" = "0" ] || [ -z "$hardened_nnp" ] && hardened_nnp="false" || hardened_nnp="true"
    printf "%-35s %-20s %-20s\n" "No New Privileges" "$baseline_nnp" "$hardened_nnp" | tee -a "$COMPARISON_FILE"

    echo "" | tee -a "$COMPARISON_FILE"

    success "Security configuration comparison completed"
}

##############################################################################
# Main
##############################################################################

main() {
    section "Standard Benchmark Comparison"

    echo "This tool compares baseline vs hardened using STANDARD benchmarking tools"
    echo ""

    # Check if both containers are running
    log "Checking container status..."

    local baseline_running=false
    local hardened_running=false

    if docker ps --format '{{.Names}}' | grep -q "^test-baseline$"; then
        baseline_running=true
        success "Baseline container: Running"
    else
        error "Baseline container: Not running"
    fi

    if docker ps --format '{{.Names}}' | grep -q "^test-hardened$"; then
        hardened_running=true
        success "Hardened container: Running"
    else
        error "Hardened container: Not running"
    fi

    if [ "$baseline_running" = false ] || [ "$hardened_running" = false ]; then
        echo ""
        echo "Please start both containers:"
        echo "  npm run docker:run:baseline"
        echo "  npm run docker:run:hardened"
        exit 1
    fi

    echo ""

    # Check required tools
    if ! command -v ab &> /dev/null; then
        error "Apache Bench (ab) not installed"
        echo "Install: brew install apache2-utils"
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        error "jq not installed"
        echo "Install: brew install jq"
        exit 1
    fi

    ##########################################################################
    # Run Comparisons
    ##########################################################################

    # PRIMARY: Apache Bench comparison
    compare_apache_bench

    # OPTIONAL: wrk comparison
    compare_wrk

    # Docker stats
    compare_docker_stats

    # Security configuration
    compare_security_config

    ##########################################################################
    # Summary
    ##########################################################################

    section "Comparison Summary"

    echo -e "${GREEN}Standard Benchmark Comparison Report:${NC}"
    echo "  Results saved to: $COMPARISON_FILE"
    echo ""
    echo -e "${YELLOW}Detailed Outputs:${NC}"
    echo "  - Apache Bench baseline: $RESULTS_DIR/ab_baseline_latency_${TIMESTAMP}.txt"
    echo "  - Apache Bench hardened: $RESULTS_DIR/ab_hardened_latency_${TIMESTAMP}.txt"
    if command -v wrk &> /dev/null; then
        echo "  - wrk baseline: $RESULTS_DIR/wrk_baseline_compare_${TIMESTAMP}.txt"
        echo "  - wrk hardened: $RESULTS_DIR/wrk_hardened_compare_${TIMESTAMP}.txt"
    fi
    echo ""
    echo -e "${CYAN}Research Analysis:${NC}"
    echo "  ✓ HTTP Performance: Apache Bench requests/sec comparison"
    echo "  ✓ Latency: P50, P95, P99 percentiles"
    echo "  ✓ Resource Usage: Docker stats comparison"
    echo "  ✓ Security: Configuration hardening validation"
    echo ""
    echo -e "${MAGENTA}For Thesis (BAB 4):${NC}"
    echo "  1. HTTP throughput overhead from Apache Bench"
    echo "  2. Response latency percentiles (P95, P99)"
    echo "  3. Resource consumption (CPU, Memory)"
    echo "  4. Security hardening features table"
    echo ""

    success "Comparison completed! ✨"
}

main "$@"
