/**
 * Route aggregator
 * Combine all route modules
 */

import express from "express";
import os from "os";
import healthRoutes from "./health.js";
import infoRoutes from "./info.js";
import metricsRoutes from "./metrics.js";
import stressRoutes from "./stress.js";

const router = express.Router();

// Mount route modules
router.use("/health", healthRoutes);
router.use("/info", infoRoutes);
router.use("/metrics", metricsRoutes);
router.use("/stress", stressRoutes);

/**
 * Root endpoint - API Information
 * GET /
 */
router.get("/", (_req, res) => {
  res.json({
    name: "Container Security Test Application",
    description:
      "Node.js app for testing Docker namespace and cgroup isolation",
    endpoints: {
      root: "GET / - API information",
      health: "GET /health - Health check",
      info: "GET /info - System informatio",
      namespace: "GET /info/namespace - Namespace isolation details",
      cgroup: "GET /info/cgroup - Cgroup limits and configuration",
      cpu_stress: "GET /stress/cpu?iterations=N - CPU stress test",
      memory_stress: "GET /stress/memory?size=N - Memory stress test (MB)",
      metrics: "GET /metrics - Prometheus-style metrics",
    },
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

export default router;
