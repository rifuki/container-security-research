#!/bin/bash

##############################################################################
# Compare Baseline vs Hardened Container Results
#
# Purpose: Calculate overhead percentage for research analysis
# Metrics: CPU overhead, Memory overhead, Response time increase
#
# Usage:
#   ./compare-results.sh
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

RESULTS_DIR="./test-results"
TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
COMPARISON_FILE="$RESULTS_DIR/comparison_${TIMESTAMP}.txt"

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
# Real-time Comparison Test
##############################################################################

compare_live_containers() {
    local baseline_port=3000
    local hardened_port=3001

    section "Live Container Comparison"

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
        return 1
    fi

    echo "" | tee "$COMPARISON_FILE"

    ##########################################################################
    # 1. CPU Stress Comparison
    ##########################################################################

    section "CPU Stress Test Comparison"

    local cpu_iterations=(1000000 10000000 50000000)

    echo "CPU Overhead Analysis:" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    printf "%-15s %-20s %-20s %-15s\n" "Iterations" "Baseline (ms)" "Hardened (ms)" "Overhead (%)" | tee -a "$COMPARISON_FILE"
    printf "%-15s %-20s %-20s %-15s\n" "---------------" "--------------------" "--------------------" "---------------" | tee -a "$COMPARISON_FILE"

    for iterations in "${cpu_iterations[@]}"; do
        log "Testing CPU: $iterations iterations..."

        # Test baseline
        local baseline_response=$(curl -s "http://localhost:${baseline_port}/stress/cpu?iterations=$iterations")
        local baseline_time=$(echo "$baseline_response" | jq -r '.duration_ms // 0')

        sleep 2

        # Test hardened
        local hardened_response=$(curl -s "http://localhost:${hardened_port}/stress/cpu?iterations=$iterations")
        local hardened_time=$(echo "$hardened_response" | jq -r '.duration_ms // 0')

        # Calculate overhead
        local overhead=0
        if [ "$baseline_time" -gt 0 ]; then
            overhead=$(awk "BEGIN {printf \"%.2f\", (($hardened_time - $baseline_time) / $baseline_time) * 100}")
        fi

        # Format iterations for display
        local iter_display="${iterations}"
        if [ $iterations -ge 1000000 ]; then
            iter_display="$((iterations / 1000000))M"
        fi

        printf "%-15s %-20s %-20s %-15s\n" "$iter_display" "$baseline_time" "$hardened_time" "$overhead" | tee -a "$COMPARISON_FILE"

        sleep 3
    done

    echo "" | tee -a "$COMPARISON_FILE"

    ##########################################################################
    # 2. Memory Allocation Comparison
    ##########################################################################

    section "Memory Allocation Comparison"

    local memory_sizes=(50 100 200)

    echo "Memory Overhead Analysis:" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    printf "%-15s %-20s %-20s %-15s\n" "Size (MB)" "Baseline (ms)" "Hardened (ms)" "Overhead (%)" | tee -a "$COMPARISON_FILE"
    printf "%-15s %-20s %-20s %-15s\n" "---------------" "--------------------" "--------------------" "---------------" | tee -a "$COMPARISON_FILE"

    for size in "${memory_sizes[@]}"; do
        log "Testing Memory: ${size}MB..."

        # Test baseline
        local baseline_response=$(curl -s "http://localhost:${baseline_port}/stress/memory?size=$size")
        local baseline_time=$(echo "$baseline_response" | jq -r '.duration_ms // 0')

        sleep 2

        # Test hardened
        local hardened_response=$(curl -s "http://localhost:${hardened_port}/stress/memory?size=$size")
        local hardened_time=$(echo "$hardened_response" | jq -r '.duration_ms // 0')

        # Calculate overhead
        local overhead=0
        if [ "$baseline_time" -gt 0 ]; then
            overhead=$(awk "BEGIN {printf \"%.2f\", (($hardened_time - $baseline_time) / $baseline_time) * 100}")
        fi

        printf "%-15s %-20s %-20s %-15s\n" "${size}MB" "$baseline_time" "$hardened_time" "$overhead" | tee -a "$COMPARISON_FILE"

        sleep 3
    done

    echo "" | tee -a "$COMPARISON_FILE"

    ##########################################################################
    # 3. Container Resource Usage Comparison
    ##########################################################################

    section "Container Resource Usage"

    echo "Docker Stats Comparison:" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    log "Collecting baseline stats..."
    local baseline_stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" test-baseline)
    local baseline_cpu=$(echo "$baseline_stats" | cut -d'|' -f1 | sed 's/%//')
    local baseline_mem=$(echo "$baseline_stats" | cut -d'|' -f2)
    local baseline_mem_pct=$(echo "$baseline_stats" | cut -d'|' -f3 | sed 's/%//')

    log "Collecting hardened stats..."
    local hardened_stats=$(docker stats --no-stream --format "{{.CPUPerc}}|{{.MemUsage}}|{{.MemPerc}}" test-hardened)
    local hardened_cpu=$(echo "$hardened_stats" | cut -d'|' -f1 | sed 's/%//')
    local hardened_mem=$(echo "$hardened_stats" | cut -d'|' -f2)
    local hardened_mem_pct=$(echo "$hardened_stats" | cut -d'|' -f3 | sed 's/%//')

    printf "%-20s %-20s %-20s\n" "Metric" "Baseline" "Hardened" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-20s %-20s\n" "--------------------" "--------------------" "--------------------" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-20s %-20s\n" "CPU Usage" "${baseline_cpu}%" "${hardened_cpu}%" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-20s %-20s\n" "Memory Usage" "$baseline_mem" "$hardened_mem" | tee -a "$COMPARISON_FILE"
    printf "%-20s %-20s %-20s\n" "Memory %" "${baseline_mem_pct}%" "${hardened_mem_pct}%" | tee -a "$COMPARISON_FILE"

    echo "" | tee -a "$COMPARISON_FILE"

    ##########################################################################
    # 4. Security Configuration Comparison
    ##########################################################################

    section "Security Configuration"

    echo "Security Hardening Features:" | tee -a "$COMPARISON_FILE"
    echo "" | tee -a "$COMPARISON_FILE"

    log "Analyzing baseline container..."
    local baseline_inspect=$(docker inspect test-baseline)

    log "Analyzing hardened container..."
    local hardened_inspect=$(docker inspect test-hardened)

    printf "%-30s %-20s %-20s\n" "Feature" "Baseline" "Hardened" | tee -a "$COMPARISON_FILE"
    printf "%-30s %-20s %-20s\n" "------------------------------" "--------------------" "--------------------" | tee -a "$COMPARISON_FILE"

    # User
    local baseline_user=$(echo "$baseline_inspect" | jq -r '.[0].Config.User // "root"')
    local hardened_user=$(echo "$hardened_inspect" | jq -r '.[0].Config.User // "root"')
    [ -z "$baseline_user" ] && baseline_user="root"
    [ -z "$hardened_user" ] && hardened_user="root"
    printf "%-30s %-20s %-20s\n" "User" "$baseline_user" "$hardened_user" | tee -a "$COMPARISON_FILE"

    # CPU Limit
    local baseline_cpu_limit=$(echo "$baseline_inspect" | jq -r '.[0].HostConfig.NanoCpus // 0')
    local hardened_cpu_limit=$(echo "$hardened_inspect" | jq -r '.[0].HostConfig.NanoCpus // 0')
    baseline_cpu_limit=$(awk "BEGIN {printf \"%.1f\", $baseline_cpu_limit / 1000000000}")
    hardened_cpu_limit=$(awk "BEGIN {printf \"%.1f\", $hardened_cpu_limit / 1000000000}")
    [ "$baseline_cpu_limit" = "0.0" ] && baseline_cpu_limit="unlimited"
    [ "$hardened_cpu_limit" = "0.0" ] && hardened_cpu_limit="unlimited"
    printf "%-30s %-20s %-20s\n" "CPU Limit" "$baseline_cpu_limit" "$hardened_cpu_limit" | tee -a "$COMPARISON_FILE"

    # Memory Limit
    local baseline_mem_limit=$(echo "$baseline_inspect" | jq -r '.[0].HostConfig.Memory // 0')
    local hardened_mem_limit=$(echo "$hardened_inspect" | jq -r '.[0].HostConfig.Memory // 0')
    if [ "$baseline_mem_limit" = "0" ]; then
        baseline_mem_limit="unlimited"
    else
        baseline_mem_limit="$((baseline_mem_limit / 1024 / 1024))MB"
    fi
    if [ "$hardened_mem_limit" = "0" ]; then
        hardened_mem_limit="unlimited"
    else
        hardened_mem_limit="$((hardened_mem_limit / 1024 / 1024))MB"
    fi
    printf "%-30s %-20s %-20s\n" "Memory Limit" "$baseline_mem_limit" "$hardened_mem_limit" | tee -a "$COMPARISON_FILE"

    # PIDs Limit
    local baseline_pids=$(echo "$baseline_inspect" | jq -r '.[0].HostConfig.PidsLimit // 0')
    local hardened_pids=$(echo "$hardened_inspect" | jq -r '.[0].HostConfig.PidsLimit // 0')
    [ "$baseline_pids" = "0" ] && baseline_pids="unlimited"
    [ "$hardened_pids" = "0" ] && hardened_pids="unlimited"
    printf "%-30s %-20s %-20s\n" "PIDs Limit" "$baseline_pids" "$hardened_pids" | tee -a "$COMPARISON_FILE"

    # Read-only Filesystem
    local baseline_ro=$(echo "$baseline_inspect" | jq -r '.[0].HostConfig.ReadonlyRootfs')
    local hardened_ro=$(echo "$hardened_inspect" | jq -r '.[0].HostConfig.ReadonlyRootfs')
    printf "%-30s %-20s %-20s\n" "Read-only Filesystem" "$baseline_ro" "$hardened_ro" | tee -a "$COMPARISON_FILE"

    # Capabilities
    local baseline_caps_count=$(echo "$baseline_inspect" | jq -r '.[0].HostConfig.CapDrop | length')
    local hardened_caps_count=$(echo "$hardened_inspect" | jq -r '.[0].HostConfig.CapDrop | length')
    printf "%-30s %-20s %-20s\n" "Capabilities Dropped" "$baseline_caps_count" "$hardened_caps_count" | tee -a "$COMPARISON_FILE"

    echo "" | tee -a "$COMPARISON_FILE"

    ##########################################################################
    # Summary
    ##########################################################################

    section "Summary"

    echo -e "${GREEN}Comparison Report:${NC}"
    echo "  Results saved to: $COMPARISON_FILE"
    echo ""
    echo -e "${YELLOW}Key Findings:${NC}"
    echo "  - Compare CPU overhead across different workload sizes"
    echo "  - Compare memory allocation overhead"
    echo "  - Verify security hardening features are active"
    echo ""
    echo -e "${CYAN}For Research Analysis:${NC}"
    echo "  - CPU Overhead Target: ≤10%"
    echo "  - Memory Overhead Target: ≤10%"
    echo "  - Security Score: Based on CIS Benchmark compliance"
    echo ""

    success "Comparison completed! ✨"
}

##############################################################################
# Main
##############################################################################

main() {
    section "Container Comparison Tool"

    echo "This tool compares baseline vs hardened container performance"
    echo ""

    # Check if jq is installed
    if ! command -v jq &> /dev/null; then
        error "jq is not installed. Please install it: brew install jq"
        exit 1
    fi

    # Run live comparison
    compare_live_containers
}

main "$@"
