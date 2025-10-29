/**
 * Health Check Routes
 * Endpoints for health checks and liveness/readiness probes
 */

import express from 'express';
import logger from '../utils/logger.js';

const router = express.Router();

/**
 * Basic health check endpoint
 * GET /health
 */
router.get('/', (req, res) => {
  const memUsage = process.memoryUsage();
  const uptime = process.uptime();

  const healthData = {
    status: 'healthy',
    uptime_seconds: uptime.toFixed(2),
    memory: {
      rss_mb: (memUsage.rss / 1024 / 1024).toFixed(2),
      heap_used_mb: (memUsage.heapUsed / 1024 / 1024).toFixed(2),
      heap_total_mb: (memUsage.heapTotal / 1024 / 1024).toFixed(2),
      external_mb: (memUsage.external / 1024 / 1024).toFixed(2),
    },
    timestamp: new Date().toISOString(),
  };

  logger.debug('Health check requested', { uptime: uptime.toFixed(2) });
  res.json(healthData);
});

/**
 * Liveness probe - checks if application is running
 * GET /health/live
 */
router.get('/live', (req, res) => {
  res.json({
    status: 'alive',
    timestamp: new Date().toISOString(),
  });
});

/**
 * Readiness probe - checks if application is ready to serve traffic
 * GET /health/ready
 */
router.get('/ready', (req, res) => {
  // Add checks for dependencies (database, external services, etc.)
  const isReady = true; // Simplified for this example
  
  if (isReady) {
    res.json({
      status: 'ready',
      timestamp: new Date().toISOString(),
    });
  } else {
    res.status(503).json({
      status: 'not ready',
      timestamp: new Date().toISOString(),
    });
  }
});

/**
 * Startup probe - checks if application has started successfully
 * GET /health/startup
 */
router.get('/startup', (req, res) => {
  const uptime = process.uptime();
  
  // Consider app started if running for more than 5 seconds
  const isStarted = uptime > 5;
  
  if (isStarted) {
    res.json({
      status: 'started',
      uptime_seconds: uptime.toFixed(2),
      timestamp: new Date().toISOString(),
    });
  } else {
    res.status(503).json({
      status: 'starting',
      uptime_seconds: uptime.toFixed(2),
      timestamp: new Date().toISOString(),
    });
  }
});

export default router;
