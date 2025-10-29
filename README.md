# Container Security Test Application

A Node.js web application designed for testing and demonstrating Docker container security mechanisms including namespace isolation, cgroup resource limits, and container hardening techniques.

## Features

- **Health Monitoring**: Health check endpoint with process metrics
- **System Information**: Detailed system and container information
- **Namespace Inspection**: View container namespace isolation details
- **Cgroup Analysis**: Inspect cgroup resource limits and configuration
- **Stress Testing**: CPU and memory stress testing endpoints
- **Metrics Export**: Prometheus-compatible metrics endpoint

## Project Structure

```
container-security-test-app/
├── app.js                    # Main application
├── package.json              # Dependencies
├── package-lock.json         # Lock file
├── Dockerfile                # Container image
├── .dockerignore             # Docker ignore
├── README.md                 # Documentation
├── config/
│   └── security.js           # Security configurations
├── routes/
│   ├── health.js             # Health check routes
│   ├── info.js               # System info routes
│   ├── stress.js             # Stress testing routes
│   └── index.js              # Route aggregator
└── utils/
    ├── logger.js             # Logging utility
    └── metrics.js            # Metrics collector
```

## Installation

### Local Development

```bash
# Install dependencies
npm install

# Run in development mode
npm run dev

# Run in production mode
npm start
```

### Docker Deployment

#### Baseline Container (No Hardening)

```bash
# Build image
docker build -t node-test-app:v1.0 .

# Run baseline container
./deploy-baseline.sh
# or
npm run docker:run:baseline
```

#### Hardened Container (Security Best Practices)

```bash
# Run hardened container
./deploy-hardened.sh
# or
npm run docker:run:hardened
```

## API Endpoints

### Health & Status

- `GET /` - API information and available endpoints
- `GET /health` - Health check with basic metrics

### System Information

- `GET /info` - Detailed system and container information
- `GET /namespace` - Namespace isolation information
- `GET /cgroup` - Cgroup configuration and resource limits

### Stress Testing

- `GET /compute?iterations=N` - CPU intensive workload
  - Default: 1,000,000 iterations
  - Max: 100,000,000 iterations
- `GET /memory?size=N` - Memory allocation test
  - Size in MB (default: 100)
  - Max: 512 MB or MAX_MEMORY_MB env var

### Metrics

- `GET /metrics` - Prometheus-style metrics

## Environment Variables

- `PORT` - Server port (default: 3000)
- `MAX_MEMORY_MB` - Maximum memory allocation for tests (default: 512)

## Container Hardening Features

The hardened container deployment includes:

1. **Resource Limits**
   - CPU: 2.0 cores
   - Memory: 2GB
   - PIDs: 512 processes

2. **Security Options**
   - No new privileges
   - All capabilities dropped
   - Only NET_BIND_SERVICE capability added
   - Read-only root filesystem
   - Non-root user (UID/GID 1000)

3. **Filesystem Security**
   - Read-only root filesystem
   - Temporary storage in tmpfs with noexec, nosuid

## Testing Container Security

### Compare Baseline vs Hardened

```bash
# Run comparison test
./test-comparison.sh
```

This will:
1. Deploy both baseline and hardened containers
2. Run health checks
3. Test CPU and memory stress endpoints
4. Compare namespace and cgroup configurations
5. Display security differences

### Manual Testing

```bash
# Test baseline container
curl http://localhost:3000/health
curl http://localhost:3000/namespace
curl http://localhost:3000/cgroup

# Test hardened container
curl http://localhost:3001/health
curl http://localhost:3001/namespace
curl http://localhost:3001/cgroup

# Stress tests
curl http://localhost:3000/compute?iterations=10000000
curl http://localhost:3000/memory?size=200
```

## Security Considerations

### Baseline Container Issues
- Runs as root (UID 0)
- Full capabilities
- Writable root filesystem
- No resource limits
- Can escalate privileges

### Hardened Container Benefits
- Non-root user
- Minimal capabilities
- Read-only filesystem
- Resource constraints
- No privilege escalation
- Process isolation

## Development

### Scripts

```bash
npm start          # Start production server
npm run dev        # Start with watch mode
npm test          # Run tests
npm run lint      # Lint code
```

### Docker Scripts

```bash
npm run docker:build          # Build image
npm run docker:run:baseline   # Run baseline
npm run docker:run:hardened   # Run hardened
npm run docker:stop           # Stop containers
npm run docker:rm             # Remove containers
npm run docker:clean          # Stop and remove
```

## Research & Analysis

This application is designed for container security research, specifically:

- Namespace isolation effectiveness
- Cgroup resource limit enforcement
- Container escape prevention
- Security hardening impact
- Performance implications of security controls

## License

MIT

## Author

Rifuki
