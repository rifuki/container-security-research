/**
 * Metrics Routes
 * Prometheus-style metrics endpoint
 */

import express from "express";
import os from "os";
import { getMetrics } from "../middleware/metrics.js";

const router = express.Router();

/**
 * Prometheus-style metrics
 * GET /metrics
 */
router.get("/", (_req, res) => {
  const memUsage = process.memoryUsage();
  const uptime = process.uptime();
  const metrics = getMetrics();

  const prometheusMetrics = `
# HELP container_test_uptime_seconds Container uptime in seconds
# TYPE container_test_uptime_seconds gauge
container_test_uptime_seconds ${uptime.toFixed(2)}

# HELP container_test_memory_rss_bytes Memory RSS in bytes
# TYPE container_test_memory_rss_bytes gauge
container_test_memory_rss_bytes ${memUsage.rss}

# HELP container_test_memory_heap_used_bytes Heap memory used in bytes
# TYPE container_test_memory_heap_used_bytes gauge
container_test_memory_heap_used_bytes ${memUsage.heapUsed}

# HELP container_test_cpu_count Number of CPUs
# TYPE container_test_cpu_count gauge
container_test_cpu_count ${os.cpus().length}

# HELP container_test_process_pid Process PID
# TYPE container_test_process_pid gauge
container_test_process_pid ${process.pid}

# HELP container_test_http_requests_total Total HTTP requests
# TYPE container_test_http_requests_total counter
container_test_http_requests_total ${metrics.requests}

# HELP container_test_http_errors_total Total HTTP errors
# TYPE container_test_http_errors_total counter
container_test_http_errors_total ${metrics.errors}
`;

  res.set("Content-Type", "text/plain");
  res.send(prometheusMetrics);
});

export default router;
