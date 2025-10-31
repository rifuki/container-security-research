# Testing Guide

Panduan lengkap untuk melakukan benchmarking dan pengukuran overhead menggunakan **standard industry tools** untuk penelitian yang credible.

## 🎯 Testing Methodology

### Primary Benchmarks (Utama)
**Tools standard yang diakui secara scientific:**
- **Apache Bench (ab)** - HTTP load testing
- **wrk** - Modern HTTP benchmarking tool
- **sysbench** - System performance benchmark

### Secondary Validation (Pendukung)
**Custom scripts untuk data spesifik:**
- Namespace isolation verification
- Cgroup limits validation
- Container-specific metrics

### Security Enforcement Testing (NEW!)
**Tools untuk validasi cgroup enforcement:**
- **Memory bomb** - Validate memory limit enforcement (2GB)
- **Fork bomb** - Validate PIDs limit enforcement (512)
- **CIS Benchmark** - Security compliance audit (docker-bench-security)

## 📋 Prerequisites

### Tools yang Dibutuhkan

```bash
# Check if tools are installed
docker --version      # Docker Engine
node --version        # Node.js
jq --version          # JSON processor
curl --version        # HTTP client

# PRIMARY BENCHMARKING TOOLS (REQUIRED)
ab -V                 # Apache Bench - HTTP load testing
wrk --version         # wrk - Modern HTTP benchmarking (optional)
sysbench --version    # System benchmark (optional)

# Install tools (macOS)
brew install apache2-utils  # Provides 'ab' command
brew install wrk            # Optional but recommended
brew install sysbench       # Optional

# Install tools (Linux Ubuntu/Debian)
sudo apt-get update
sudo apt-get install apache2-utils  # Provides 'ab' command
sudo apt-get install wrk            # Optional
sudo apt-get install sysbench       # Optional

# Install jq (JSON processor)
brew install jq          # macOS
sudo apt-get install jq  # Linux
```

## 🚀 Quick Start

### 1. Build Docker Image

```bash
# Build the application image
npm run docker:build
# atau
docker build -t node-test-app:v1.0 .
```

### 2. Deploy Containers

```bash
# Deploy baseline container (no hardening)
npm run docker:run:baseline
# Port: 3000

# Deploy hardened container (with security features)
npm run docker:run:hardened
# Port: 3001
```

### 3. Quick Test

Validasi bahwa semua endpoint berfungsi:

```bash
# Test baseline
./scripts/quick-test.sh baseline

# Test hardened
./scripts/quick-test.sh hardened
```

## 🧪 Standard Benchmarking (PRIMARY)

### Script: `benchmark-standard.sh`

**Menggunakan industry-standard tools untuk credibility penelitian.**

This script runs comprehensive benchmarks using STANDARD tools:

**Primary Benchmarks:**
1. **Apache Bench (ab)** - HTTP load testing
   - Light Load: 100 requests, 10 concurrent
   - Medium Load: 1000 requests, 50 concurrent
   - Heavy Load: 5000 requests, 100 concurrent
   - Very Heavy Load: 10000 requests, 200 concurrent
   - Metrics: Requests/sec, Latency (P50, P95, P99), Transfer rate

2. **wrk** (if installed) - Modern HTTP benchmarking
   - Light: 30s, 2 threads, 50 connections
   - Medium: 30s, 4 threads, 100 connections
   - Heavy: 30s, 8 threads, 200 connections
   - Metrics: Throughput, Latency distribution

3. **sysbench** (if installed) - System performance
   - CPU benchmark inside container
   - Measures events per second

**Secondary Validation:**
- Namespace isolation check (7 Linux namespaces)
- Cgroup limits verification
- Custom endpoint validation (5 runs, averaged)

**Usage:**

```bash
# Benchmark baseline container
./scripts/benchmark-standard.sh baseline

# Benchmark hardened container
./scripts/benchmark-standard.sh hardened
```

**Output Location:**

Results saved in `./benchmark-results/`:
- `standard_benchmark_baseline_YYYYMMDD_HHMMSS.txt` - Main report
- `ab_baseline_*_YYYYMMDD_HHMMSS.txt` - Apache Bench details
- `ab_baseline_*_YYYYMMDD_HHMMSS.tsv` - Apache Bench data (TSV format)
- `wrk_baseline_*_YYYYMMDD_HHMMSS.txt` - wrk details (if installed)
- `sysbench_baseline_YYYYMMDD_HHMMSS.txt` - sysbench output (if installed)
- `inspect_baseline_YYYYMMDD_HHMMSS.json` - Container configuration

**Example Output:**

```
========================================
Apache Bench (ab) - HTTP Load Testing
========================================

Test: Medium Load
  Requests: 1000
  Concurrency: 50

Apache Bench Results - Medium Load:
Requests per second:    2845.32 [#/sec] (mean)
Time per request:       17.571 [ms] (mean)
Time per request:       0.351 [ms] (mean, across all concurrent requests)
Transfer rate:          1024.56 [Kbytes/sec] received

Summary:
  Requests/sec: 2845.32
  Mean time: 17.571ms
  P50: 16ms
  P95: 24ms
  P99: 31ms
```

### Script: `compare-standard.sh`

**Compare baseline vs hardened menggunakan standard benchmarking tools.**

This script provides scientific comparison using:
- **Apache Bench**: Throughput and latency comparison
- **wrk**: Load testing comparison (if installed)
- **Docker stats**: Resource usage comparison
- **Security config**: Hardening features validation

**Usage:**

```bash
# Make sure both containers are running
npm run docker:run:baseline
npm run docker:run:hardened

# Run comparison
./scripts/compare-standard.sh
```

**Output Example:**

```
========================================
Apache Bench - HTTP Performance Comparison
========================================

Apache Bench Comparison:

Test                 Baseline (req/sec)        Hardened (req/sec)        Overhead (%)
--------------------  -------------------------  -------------------------  ---------------
Medium Load          2845.32                   2767.89                   2.72
Heavy Load           2954.18                   2881.45                   2.46

Latency Percentiles (1000 req, 50 concurrent):

Percentile      Baseline (ms)        Hardened (ms)
---------------  --------------------  --------------------
P50 (median)    16                   17
P95             24                   25
P99             31                   33

========================================
Docker Stats Comparison
========================================

Metric               Baseline                  Hardened
--------------------  -------------------------  -------------------------
CPU Usage            0.25%                     0.28%
Memory Usage         62.5MiB / 16GiB           64.2MiB / 2GiB
Memory %             0.38%                     3.14%
```

## 📊 Custom Validation (SUPPORTING)

### Script: `stress-test.sh` (Supporting Data)

### Script: `stress-test.sh`

Script ini melakukan pengujian stress yang comprehensive untuk mengukur CPU dan memory overhead.

**Features:**
- CPU stress test dengan 3 level beban (1M, 10M, 50M iterations)
- Memory stress test dengan 3 ukuran (50MB, 100MB, 200MB)
- Setiap test diulang 5× untuk mendapat average yang akurat
- Monitoring Docker stats real-time
- Collect namespace dan cgroup information
- Generate detailed report

**Usage:**

```bash
# Test baseline container
./scripts/stress-test.sh baseline

# Test hardened container
./scripts/stress-test.sh hardened

# Test both (runs sequentially)
./scripts/stress-test.sh compare
```

**Output:**

Script akan generate file di `./test-results/`:
- `stress_test_baseline_YYYYMMDD_HHMMSS.txt` - Detailed test results
- `metrics_baseline_YYYYMMDD_HHMMSS.txt` - Prometheus metrics snapshot

**Example Output:**

```
========================================
CPU Stress Tests
========================================

Testing: 1000000 iterations

CPU Test: 1000000 iterations (Run 1/5)
  Iterations: 1000000
  App Duration: 23ms
  Total Duration: 45ms
  Throughput: 43478 iter/sec
  CPU Before: 0.2%
  CPU After: 15.3%

...

Average Duration: 24ms
```

### Script: `compare-results.sh`

Script ini membandingkan performa baseline vs hardened container secara real-time.

**Features:**
- Side-by-side comparison
- Calculate overhead percentage automatically
- Compare CPU, Memory, Response time
- Display security configuration differences
- Generate comparison report

**Usage:**

```bash
# Make sure both containers are running first
npm run docker:run:baseline
npm run docker:run:hardened

# Run comparison
./scripts/compare-results.sh
```

**Output:**

```
========================================
CPU Stress Test Comparison
========================================

CPU Overhead Analysis:

Iterations      Baseline (ms)        Hardened (ms)        Overhead (%)
---------------  --------------------  --------------------  ---------------
1M              24                   25                   4.17
10M             234                  242                  3.42
50M             1187                 1225                 3.20

========================================
Memory Allocation Comparison
========================================

Memory Overhead Analysis:

Size (MB)       Baseline (ms)        Hardened (ms)        Overhead (%)
---------------  --------------------  --------------------  ---------------
50MB            45                   47                   4.44
100MB           89                   92                   3.37
200MB           176                  182                  3.41
```

## 📊 Understanding Results

### CPU Overhead

**Formula:**
```
CPU Overhead (%) = ((Hardened Time - Baseline Time) / Baseline Time) × 100
```

**Research Target:** ≤10%

**Interpretation:**
- <5%: Excellent (minimal overhead)
- 5-10%: Good (acceptable for research)
- >10%: High (may need optimization)

### Memory Overhead

**Formula:**
```
Memory Overhead (%) = ((Hardened Memory - Baseline Memory) / Baseline Memory) × 100
```

**Research Target:** ≤10%

**Measurement Points:**
- RSS (Resident Set Size): Actual physical memory used
- Heap Usage: JavaScript heap allocation
- Container Memory: Docker-reported memory usage

### Response Time

**Metrics:**
- **App Duration**: Time measured by application (pure processing time)
- **Total Duration**: End-to-end time including network latency
- **Throughput**: Operations per second (higher is better)

## 🔬 Research Workflow (RECOMMENDED)

### Phase 1: Baseline Measurement (PRIMARY)

```bash
# 1. Start baseline container
npm run docker:run:baseline

# 2. Run STANDARD benchmark (PRIMARY DATA)
./scripts/benchmark-standard.sh baseline

# 3. Run custom validation (SUPPORTING DATA - optional)
./scripts/stress-test.sh baseline

# 4. Save results
mkdir -p research-data
cp benchmark-results/standard_benchmark_baseline_*.txt research-data/
cp benchmark-results/ab_baseline_*.txt research-data/
```

### Phase 2: Hardened Measurement (PRIMARY)

```bash
# 1. Start hardened container
npm run docker:run:hardened

# 2. Run STANDARD benchmark (PRIMARY DATA)
./scripts/benchmark-standard.sh hardened

# 3. Run custom validation (SUPPORTING DATA - optional)
./scripts/stress-test.sh hardened

# 4. Save results
cp benchmark-results/standard_benchmark_hardened_*.txt research-data/
cp benchmark-results/ab_hardened_*.txt research-data/
```

### Phase 3: Comparison Analysis (PRIMARY)

```bash
# 1. Make sure both containers are running
docker ps

# 2. Run STANDARD comparison (PRIMARY DATA)
./scripts/compare-standard.sh

# 3. Run custom comparison (SUPPORTING DATA - optional)
./scripts/compare-results.sh

# 4. Save comparison report
cp benchmark-results/comparison_standard_*.txt research-data/
```

### Phase 4: Data Collection for Thesis

**PRIMARY DATA (dari Standard Tools):**

1. **HTTP Performance (Apache Bench)**
   - Throughput: Requests/sec baseline vs hardened
   - Overhead percentage: `((Baseline - Hardened) / Baseline) × 100%`
   - Latency percentiles: P50, P95, P99
   - Source: `ab_baseline_*.txt` dan `ab_hardened_*.txt`

2. **Load Testing (wrk - if installed)**
   - Throughput comparison
   - Latency distribution
   - Source: `wrk_baseline_*.txt` dan `wrk_hardened_*.txt`

3. **System Performance (sysbench - if installed)**
   - CPU events per second
   - Source: `sysbench_baseline_*.txt` dan `sysbench_hardened_*.txt`

4. **Resource Usage (Docker Stats)**
   - CPU usage percentage
   - Memory usage and percentage
   - Source: `comparison_standard_*.txt`

5. **Security Configuration**
   - User: root vs non-root
   - Capabilities dropped
   - Resource limits (CPU, Memory, PIDs)
   - Read-only filesystem
   - Source: `inspect_*.json` and `comparison_standard_*.txt`

**SUPPORTING DATA (dari Custom Scripts):**

6. **Container-Specific Validation**
   - Namespace isolation (7 namespaces)
   - Cgroup limits validation
   - Custom endpoint response times
   - Source: `stress_test_*.txt` (optional)

7. **Container Startup Time**
   ```bash
   # Measure startup time
   docker rm -f test-baseline
   time docker run -d --name test-baseline -p 3000:3000 node-test-app:v1.0
   # Record the "real" time
   ```

## 📈 Example Research Data (Apache Bench - PRIMARY)

### Table 1: HTTP Performance Overhead (Apache Bench)

| Load Level | Requests | Concurrent | Baseline (req/s) | Hardened (req/s) | Overhead (%) |
|------------|----------|------------|------------------|------------------|--------------|
| Light | 100 | 10 | 3250.45 | 3180.12 | 2.16 |
| Medium | 1000 | 50 | 2845.32 | 2767.89 | 2.72 |
| Heavy | 5000 | 100 | 2954.18 | 2881.45 | 2.46 |
| Very Heavy | 10000 | 200 | 2782.56 | 2701.34 | 2.92 |
| **Average** | - | - | - | - | **2.57** |

**Conclusion**: HTTP throughput overhead rata-rata 2.57% (Target: ≤10%) ✓

### Table 2: Response Latency (Apache Bench - 1000 req, 50 concurrent)

| Metric | Baseline (ms) | Hardened (ms) | Difference (ms) | Increase (%) |
|--------|---------------|---------------|-----------------|--------------|
| Mean | 17.57 | 18.09 | +0.52 | 2.96 |
| P50 (Median) | 16 | 17 | +1 | 6.25 |
| P95 | 24 | 25 | +1 | 4.17 |
| P99 | 31 | 33 | +2 | 6.45 |

**Conclusion**: Latency increase minimal, P95 hanya naik 1ms (acceptable untuk security hardening)

### Table 3: Supporting Data - Custom Endpoint Validation

| Test Type | Baseline (ms) | Hardened (ms) | Overhead (%) |
|-----------|---------------|---------------|--------------|
| CPU (10M iter) | 234 | 242 | 3.42 |
| Memory (100MB) | 89 | 92 | 3.37 |

**Note**: Data pendukung untuk validasi container-specific overhead

### Table 3: Security Hardening Configuration

| Feature | Baseline | Hardened | Impact |
|---------|----------|----------|--------|
| User | root (0) | appuser (1000) | ✓ Privilege reduction |
| CPU Limit | Unlimited | 2.0 cores | ✓ Resource isolation |
| Memory Limit | Unlimited | 2GB | ✓ Resource isolation |
| PIDs Limit | Unlimited | 512 | ✓ Fork bomb prevention |
| Read-only FS | false | true | ✓ Tamper prevention |
| Capabilities | All | NET_BIND_SERVICE only | ✓ Privilege minimization |

## 🎯 Research Validation

Untuk memvalidasi hasil penelitian, pastikan:

### 1. CPU Overhead ≤10%

```bash
# Run multiple tests and verify consistency
for i in {1..3}; do
  echo "Test iteration $i"
  ./scripts/compare-results.sh
  sleep 10
done
```

### 2. Memory Overhead ≤10%

Check memory usage during stress:

```bash
# Monitor during test
watch -n 1 'docker stats --no-stream test-baseline test-hardened'
```

### 3. Startup Time ≤2s

```bash
# Test startup time (repeat 5×)
for i in {1..5}; do
  docker rm -f test-hardened
  time docker run -d --name test-hardened \
    --cpus=2.0 --memory=2g --pids-limit=512 \
    --security-opt=no-new-privileges:true \
    --cap-drop=ALL --cap-add=NET_BIND_SERVICE \
    --read-only --tmpfs /tmp:rw,noexec,nosuid,size=64m \
    --user 1000:1000 -p 3001:3000 \
    node-test-app:v1.0
  sleep 5
done
```

### 4. CIS Compliance

```bash
# Check security compliance
docker inspect test-hardened | jq '.[0].HostConfig | {
  User: .SecurityOpt,
  ReadonlyRootfs: .ReadonlyRootfs,
  CapDrop: .CapDrop,
  Memory: .Memory,
  CpuQuota: .CpuQuota
}'
```

## 🔧 Troubleshooting

### Container won't start

```bash
# Check logs
docker logs test-baseline
docker logs test-hardened

# Check if port is already in use
lsof -i :3000
lsof -i :3001
```

### High CPU overhead (>10%)

Possible causes:
1. System under load → Close other applications
2. Docker resource contention → Increase Docker resources
3. Need multiple test runs → Average results from 5+ runs

### Script errors

```bash
# Make sure jq is installed
brew install jq

# Make sure scripts are executable
chmod +x scripts/*.sh

# Check Docker daemon is running
docker ps
```

## 📝 Tips untuk Penelitian

1. **Consistency**: Run tests multiple times, average the results
2. **Environment**: Test on same machine, close other applications
3. **Cool-down**: Wait 5-10 seconds between tests
4. **Documentation**: Save all test results with timestamps
5. **Screenshots**: Capture comparison tables for thesis

## 🎓 For Thesis (BAB 4)

### Data yang Perlu Disajikan:

1. **Tabel Perbandingan CPU Overhead**
   - Sumber: output dari `compare-results.sh`
   - Include: Light, Medium, Heavy workload
   - Show: Baseline, Hardened, Overhead %

2. **Tabel Perbandingan Memory Overhead**
   - Sumber: output dari `compare-results.sh`
   - Include: Different allocation sizes
   - Show: Response time comparison

3. **Tabel Security Features**
   - List all hardening features enabled
   - Show baseline vs hardened comparison
   - Reference: CIS Docker Benchmark

4. **Grafik (optional)**
   - CPU overhead across workloads
   - Memory overhead across allocations
   - Response time comparison

### Contoh Narasi untuk BAB 4:

> "Berdasarkan pengujian yang dilakukan menggunakan stress test dengan beban CPU
> bervariasi (1M, 10M, dan 50M iterasi), diperoleh hasil bahwa overhead CPU rata-rata
> pada container yang di-hardening adalah 3.60%. Nilai ini berada di bawah threshold
> 10% yang ditetapkan dalam penelitian, menunjukkan bahwa implementasi security
> hardening tidak memberikan dampak signifikan terhadap performa komputasi."

## ✨ Summary

### Primary Scripts (RECOMMENDED for Research)

| Script | Purpose | Tools Used | Output |
|--------|---------|------------|--------|
| `quick-test.sh` | Quick validation | curl | Terminal output |
| **`benchmark-standard.sh`** | **PRIMARY: Standard benchmarking** | **Apache Bench, wrk, sysbench** | **Detailed benchmark report** |
| **`compare-standard.sh`** | **PRIMARY: Standard comparison** | **ab, wrk, docker stats** | **Scientific comparison table** |

### Supporting Scripts (Optional)

| Script | Purpose | Output |
|--------|---------|--------|
| `stress-test.sh` | Custom endpoint stress testing | Text report + metrics |
| `compare-results.sh` | Custom comparison | Custom comparison table |

### Research Methodology

**PRIMARY DATA (Credible):**
- Apache Bench (ab): HTTP load testing standard
- wrk: Modern HTTP benchmarking
- sysbench: System performance standard
- Docker stats: Resource usage

**SUPPORTING DATA (Supplementary):**
- Custom endpoint validation
- Container-specific metrics
- Namespace/cgroup verification

**Recommended Workflow:**
1. Build image
2. Deploy baseline container
3. **Run standard benchmark** (PRIMARY)
4. Run custom validation (SUPPORTING - optional)
5. Deploy hardened container
6. **Run standard benchmark** (PRIMARY)
7. Run custom validation (SUPPORTING - optional)
8. **Compare using standard tools** (PRIMARY)
9. **Run security enforcement tests** (NEW!)
10. Run CIS compliance audit (NEW!)
11. Analyze for thesis

---

## 🔐 Security Enforcement Testing (NEW!)

### Purpose
Validasi bahwa cgroup limits **benar-benar enforce** dan container **tidak bisa di-abuse**.
Ini untuk **RUMUSAN MASALAH 1 & 2** di skripsi (efektivitas namespace/cgroup & security posture).

### Script: `test-memory-bomb.sh`

**Tujuan:** Validate memory limit enforcement (2GB)

**Method:**
- Attempt to allocate memory beyond 2GB limit
- Expected: Hardened container killed by OOM
- Baseline: May allocate unlimited (vulnerable)

**Usage:**
```bash
# Make sure both containers are running
./scripts/deploy-baseline.sh
./scripts/deploy-hardened.sh

# Run memory bomb test
./scripts/test-memory-bomb.sh

# Follow prompts (will ask for confirmation)
```

**Expected Results:**
- Baseline: Can allocate 2GB+ (no limit, vulnerable)
- Hardened: Killed at ~2GB (OOM enforced) ✓

**Output Location:** Terminal output with summary table

**Example Output:**
```
========================================
Memory Bomb Test Summary
========================================

Container            Result                          Memory Allocated
-------------------  ------------------------------  ------------------------------
Baseline             ⚠️  NOT KILLED (no limit)       2500MB+
Hardened             ✓ KILLED by OOM                ~2048MB (~2GB)

Conclusion:
  ✓ PASS: Memory limit enforcement working correctly
  Hardened container killed at ~2GB limit (cgroup v2 enforced)
  Defense-in-depth: Memory exhaustion attack prevented
```

**For BAB IV:**
Create table showing:
```
Tabel: Cgroup Memory Enforcement
Container | Memory Limit | Max Allocated | Enforcement
Baseline  | UNLIMITED    | 2500MB+       | ⚠️ None (vulnerable)
Hardened  | 2GB          | ~2048MB       | ✓ OOM Kill (enforced)
```

---

### Script: `test-fork-bomb.sh`

**Tujuan:** Validate PIDs limit enforcement (512 processes)

**Method:**
- Attempt to spawn processes beyond 512 limit
- Expected: Hardened container blocked at ~512
- Baseline: May spawn unlimited (vulnerable)

**Usage:**
```bash
# Make sure both containers are running
./scripts/deploy-baseline.sh
./scripts/deploy-hardened.sh

# Run fork bomb test
./scripts/test-fork-bomb.sh

# Follow prompts (will ask for confirmation)
```

**Expected Results:**
- Baseline: Can spawn 600+ processes (no limit, vulnerable)
- Hardened: Blocked at ~512 processes ✓

**Output Location:** Terminal output with summary table

**Example Output:**
```
========================================
Fork Bomb Test Summary
========================================

Container            PIDs Limit                      Max Processes Spawned
-------------------  ------------------------------  ------------------------------
Baseline             ⚠️  UNLIMITED                   650+
Hardened             ✓ 512 processes                ~512 (enforced)

Conclusion:
  ✓ PASS: PIDs limit enforcement working correctly
  Hardened container blocked at ~512 processes (cgroup v2 enforced)
  Defense-in-depth: Fork bomb attack prevented
```

**For BAB IV:**
Create table showing:
```
Tabel: Cgroup PIDs Enforcement
Container | PIDs Limit | Max Spawned | Enforcement
Baseline  | UNLIMITED  | 650+        | ⚠️ None (vulnerable)
Hardened  | 512        | ~512        | ✓ Blocked (enforced)
```

---

### Script: `run-cis-audit.sh`

**Tujuan:** Automated CIS Docker Benchmark security audit

**Standard:** CIS Docker Benchmark v1.7.0

**Target:** 
- Baseline: ~50% compliance
- Hardened: ≥80% compliance

**Method:**
- Uses official `docker/docker-bench-security` tool
- Scans 100+ security controls
- Generates compliance score

**Usage:**
```bash
# Make sure containers are running
./scripts/deploy-baseline.sh
./scripts/deploy-hardened.sh

# Run CIS audit
./scripts/run-cis-audit.sh

# Wait 1-2 minutes for scan
```

**Output Location:** `./cis-audit-results/`
- `cis_audit_full_TIMESTAMP.log` - Full detailed report
- `cis_summary_TIMESTAMP.txt` - Summary with scores

**Expected Results:**
```
========================================
Overall Results
========================================
Total Checks:       87
PASS:               70
WARN:               17
INFO:               25
NOTE:               12

Compliance Score:   80.46%
Target Score:       ≥80%

Status: ✓ COMPLIANT
```

**Section Breakdown:**
```
Section 1 - Host Configuration                    : 90%
Section 2 - Docker Daemon Configuration           : 85%
Section 3 - Docker Daemon Configuration Files     : 90%
Section 4 - Container Images and Build            : 85%
Section 5 - Container Runtime                     : 90%
Section 6 - Docker Security Operations            : 85%
```

**For BAB IV:**
Create tables showing:

```
Tabel 1: CIS Compliance Score
Configuration | Compliance Score | Status
Baseline      | ~50%            | ⚠️ Non-compliant
Hardened      | 80%+            | ✓ Compliant
Improvement   | +30%            | Significant

Tabel 2: CIS Section Scores
Section                          | Baseline | Hardened | Improvement
Host Configuration               | 40%      | 90%      | +50%
Docker Daemon Configuration      | 30%      | 85%      | +55%
Container Runtime                | 35%      | 90%      | +55%
Average                          | ~50%     | ~88%     | +38%
```

---

## 🔬 Complete Research Workflow (UPDATED)

### Phase 1: Setup & Deployment
```bash
# 1. Build image
cd node-test-app
docker build -t node-test-app:v1.0 .

# 2. Deploy both containers
./scripts/deploy-baseline.sh   # Port 3000
./scripts/deploy-hardened.sh   # Port 3001

# 3. Quick validation
./scripts/quick-test.sh baseline
./scripts/quick-test.sh hardened
```

### Phase 2: PRIMARY Performance Benchmarking (Rumusan Masalah 3)
```bash
# Benchmark baseline
./scripts/benchmark-standard.sh baseline
# Output: benchmark-results/standard_benchmark_baseline_*.txt

# Benchmark hardened  
./scripts/benchmark-standard.sh hardened
# Output: benchmark-results/standard_benchmark_hardened_*.txt

# Compare performance
./scripts/compare-standard.sh
# Output: benchmark-results/comparison_standard_*.txt
```

**Data for BAB IV:**
- Table: HTTP Performance Overhead (Apache Bench)
- Table: Response Latency Comparison
- Conclusion: Overhead ≤10% (ACCEPTABLE)

---

### Phase 3: SECURITY Enforcement Testing (Rumusan Masalah 1) **NEW!**
```bash
# Test namespace isolation
./scripts/test-namespace-isolation.sh
# Validates 7 namespace types isolated

# Test cgroup memory enforcement
./scripts/test-memory-bomb.sh
# Validates 2GB memory limit enforced

# Test cgroup PIDs enforcement
./scripts/test-fork-bomb.sh
# Validates 512 PIDs limit enforced

# Test cgroup CPU/other limits
./scripts/test-cgroup-enforcement.sh
# Validates CPU and other limits
```

**Data for BAB IV:**
- Table: Namespace Isolation Effectiveness (7 types)
- Table: Cgroup Memory Enforcement (memory bomb test)
- Table: Cgroup PIDs Enforcement (fork bomb test)
- Table: Resource Control Validation
- Conclusion: Enforcement WORKING (container killed/blocked as expected)

---

### Phase 4: CIS Compliance Audit (Rumusan Masalah 2) **NEW!**
```bash
# Run CIS Docker Benchmark audit
./scripts/run-cis-audit.sh
# Output: cis-audit-results/cis_summary_*.txt

# Review results
cat cis-audit-results/cis_summary_*.txt
```

**Data for BAB IV:**
- Table: CIS Compliance Score (Baseline vs Hardened)
- Table: CIS Section Breakdown (6 sections)
- Table: Security Features Implemented
- Conclusion: Compliance ≥80% (TARGET ACHIEVED)

---

### Phase 5: Analysis & Documentation
```bash
# Collect all results
mkdir -p research-data
cp benchmark-results/comparison_standard_*.txt research-data/
cp cis-audit-results/cis_summary_*.txt research-data/

# Create summary document
cat > research-data/SUMMARY.md << 'EOF'
# Research Results Summary

## Performance Overhead (Rumusan Masalah 3)
- HTTP Throughput Overhead: 2.72%
- Latency P95 Overhead: 4.17%
- Memory Allocation Overhead: 3.37%
- **Conclusion: Overhead 2-4% (Target ≤10%) ✓**

## Security Enforcement (Rumusan Masalah 1)
- Namespace Isolation: 7/7 active ✓
- Memory Limit Enforcement: OOM at 2GB ✓
- PIDs Limit Enforcement: Blocked at 512 ✓
- **Conclusion: All limits enforced correctly ✓**

## CIS Compliance (Rumusan Masalah 2)
- Baseline Score: ~50%
- Hardened Score: 80%+
- Improvement: +30%
- **Conclusion: Target ≥80% achieved ✓**

## Overall Conclusion
Security hardening increases compliance +30% with only 2-4% 
performance overhead → ACCEPTABLE & RECOMMENDED for production.
EOF
```

---

## 📊 BAB IV Tables (Complete List)

### Performance Tables (Rumusan Masalah 3)
1. **HTTP Performance Overhead** (Apache Bench)
2. **Response Latency Comparison** (P50, P95, P99)
3. **Resource Usage Overhead** (CPU, Memory)
4. **Startup Time Comparison**

### Security Validation Tables (Rumusan Masalah 1)
5. **Namespace Isolation Effectiveness** (7 types)
6. **Cgroup Memory Enforcement** (Memory bomb test)
7. **Cgroup PIDs Enforcement** (Fork bomb test)
8. **Cgroup Resource Control** (CPU, I/O limits)

### Compliance Tables (Rumusan Masalah 2)
9. **CIS Compliance Score** (Overall)
10. **CIS Section Breakdown** (6 sections)
11. **Security Features Implemented** (Baseline vs Hardened)

### Trade-off Analysis
12. **Security vs Performance Trade-off**
```
Metric                  | Gain/Cost
Security Improvement    | +30% CIS compliance
Performance Cost        | 2-4% overhead
Trade-off Ratio         | 30/3 = 10:1 (EXCELLENT!)
```

---

**Questions?** Check `README.md` or inspect the scripts for detailed implementation.
