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
  res.json({
    status: "ok",
    message: "Service is healthy and running",
    uptime_seconds: process.uptime().toFixed(2),
    timestamp: new Date().toISOString(),
  });
});

export default router;
