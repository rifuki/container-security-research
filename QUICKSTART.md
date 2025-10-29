# Quick Start Guide - Container Security Test Application

## 🚀 Quick Test (Local)

```bash
# Start application
npm start

# Test all endpoints
./scripts/test-all-endpoints.sh

# View results
ls -lh test-results/
```

## 🐳 Docker Testing

### 1. Build Image
```bash
docker build -t node-test-app:v1.0 .
```

### 2. Deploy Configurations

#### Baseline (No Hardening)
```bash
./scripts/deploy-baseline.sh
# Access at: http://localhost:3000
```

#### Hardened (Security Hardening)
```bash
./scripts/deploy-hardened.sh
# Access at: http://localhost:3001
```

### 3. Run Benchmarks

#### Test Single Container
```bash
# Set container name and port
export CONTAINER_NAME=test-baseline
export PORT=3000

# Run benchmark
./benchmark-performance.sh
```

#### Compare Baseline vs Hardened
```bash
./scripts/test-comparison.sh
```

## 📊 Available Endpoints

| Category | Endpoint | Description |
|----------|----------|-------------|
| **Health** | `GET /health` | Basic health check |
| | `GET /health/live` | Liveness probe |
| | `GET /health/ready` | Readiness probe |
| | `GET /health/startup` | Startup probe |
| **Info** | `GET /info` | System information |
| | `GET /info/namespace` | Namespace isolation |
| | `GET /info/cgroup` | Cgroup configuration |
| | `GET /info/security` | Security status |
| | `GET /info/all` | Complete overview |
| **Stress** | `GET /stress/cpu?iterations=N` | CPU stress test |
| | `GET /stress/memory?size=N` | Memory test (MB) |
| | `GET /stress/combined` | Combined test |
| | `GET /stress/disk?operations=N` | Disk I/O test |
| **Metrics** | `GET /metrics` | Prometheus metrics |

## 🧪 Testing Examples

### cURL Examples
```bash
# Health check
curl http://localhost:3000/health | jq

# System info
curl http://localhost:3000/info | jq

# CPU stress (1M iterations)
curl "http://localhost:3000/stress/cpu?iterations=1000000" | jq

# Memory stress (100MB)
curl "http://localhost:3000/stress/memory?size=100" | jq

# Prometheus metrics
curl http://localhost:3000/metrics
```

### Load Testing (with ApacheBench)
```bash
# Install ab (if not installed)
brew install httpd  # macOS
# or
apt install apache2-utils  # Linux

# Run load test
ab -n 1000 -c 50 http://localhost:3000/health
```

## 📈 Benchmark Results Location

```
benchmark-results/
├── benchmark_TIMESTAMP.json       # Performance metrics
├── inspect_TIMESTAMP.json         # Container inspection
└── ab_TIMESTAMP.txt               # Load test results

test-results/
├── test_TIMESTAMP.log             # Test execution log
├── *.json                         # Individual test results
└── metrics_TIMESTAMP.txt          # Prometheus metrics
```

## 🔍 Inspect Running Container

```bash
# View container stats
docker stats <container-name>

# Inspect configuration
docker inspect <container-name> | jq

# View logs
docker logs <container-name>

# Execute commands inside
docker exec -it <container-name> sh
```

## 🛑 Cleanup

```bash
# Stop containers
docker stop test-baseline test-hardened

# Remove containers
docker rm test-baseline test-hardened

# Remove image
docker rmi node-test-app:v1.0

# Clean all
docker system prune -af
```

## 📝 Common Use Cases

### 1. Security Research
```bash
# Deploy hardened container
./scripts/deploy-hardened.sh

# Check namespace isolation
curl http://localhost:3001/info/namespace | jq

# Check cgroup limits
curl http://localhost:3001/info/cgroup | jq

# Check security status
curl http://localhost:3001/info/security | jq
```

### 2. Performance Comparison
```bash
# Deploy both configurations
./scripts/deploy-baseline.sh
./scripts/deploy-hardened.sh

# Run comparison
./scripts/test-comparison.sh

# Results will show side-by-side comparison
```

### 3. Resource Limit Testing
```bash
# Test CPU limit enforcement
docker run -d --cpus="1.0" --name cpu-test node-test-app:v1.0
curl "http://localhost:3000/stress/cpu?iterations=100000000"
docker stats cpu-test --no-stream

# Test memory limit enforcement
docker run -d --memory="512m" --name mem-test node-test-app:v1.0
curl "http://localhost:3000/stress/memory?size=600"
# Should fail or be limited
```

## 🔧 Troubleshooting

### Container won't start
```bash
# Check logs
docker logs <container-name>

# Check if port is already in use
lsof -i :3000

# Try different port
docker run -p 3002:3000 node-test-app:v1.0
```

### Tests failing
```bash
# Check if app is running
curl http://localhost:3000/health

# Check logs
tail -f test-results/test_*.log

# Restart application
pkill -f "node app.js"
node app.js
```

### Permission issues (read-only filesystem)
```bash
# This is expected in hardened config
# Use tmpfs for writable directories
docker run --read-only \
  --tmpfs /tmp:rw,noexec,nosuid,size=64m \
  node-test-app:v1.0
```

## 📚 Additional Resources

- **Dockerfile**: Container image definition
- **README.md**: Complete documentation
- **config/security.js**: Security configuration
- **routes/**: API endpoint implementations
- **utils/**: Logger and metrics utilities

## 💡 Tips

1. **Always check logs first** when debugging
2. **Use `docker stats`** to monitor resource usage
3. **Run tests multiple times** for accurate benchmarks
4. **Compare baseline vs hardened** to measure security overhead
5. **Use `jq`** to pretty-print JSON responses

## ⚡ Performance Tips

```bash
# For faster tests, reduce iterations
curl "http://localhost:3000/stress/cpu?iterations=10000"

# For quick memory test
curl "http://localhost:3000/stress/memory?size=10"

# For comprehensive benchmark
./benchmark-performance.sh  # Takes 5-10 minutes
```

---

**Happy Testing!** 🚀
