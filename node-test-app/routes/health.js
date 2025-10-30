/**
 * Health Check Routes
 * Endpoints for health checks
 */

import express from "express";

const router = express.Router();

/**
 * Basic health check
 * GET /health
 */
router.get("/", (_req, res) => {
  const memUsage = process.memoryUsage();
  const uptime = process.uptime();

  res.json({
    status: "healthy",
    uptime_seconds: uptime.toFixed(2),
    memory: {
      rss_mb: (memUsage.rss / 1024 / 1024).toFixed(),
      heap_used_mb: (memUsage.heapUsed / 1024 / 1024).toFixed(2),
      heap_total_mb: (memUsage.heapTotal / 1024 / 1024).toFixed(2),
    },
    timestamp: new Date().toISOString(),
  });
});

export default router;
