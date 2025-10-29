/**
 * Route Aggregator
 * Combines all route modules and provides main router
 */

import express from 'express';
import os from 'os';
import metrics from '../utils/metrics.js';
import healthRoutes from './health.js';
import infoRoutes from './info.js';
import stressRoutes from './stress.js';

const router = express.Router();

// Mount route modules
router.use('/health', healthRoutes);
router.use('/info', infoRoutes);
router.use('/stress', stressRoutes);

// Legacy routes for backward compatibility
router.get('/namespace', (req, res) => {
  res.redirect('/info/namespace');
});

router.get('/cgroup', (req, res) => {
  res.redirect('/info/cgroup');
});

router.get('/compute', (req, res) => {
  res.redirect('/stress/cpu' + (req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : ''));
});

router.get('/memory', (req, res) => {
  res.redirect('/stress/memory' + (req.url.includes('?') ? req.url.substring(req.url.indexOf('?')) : ''));
});

/**
 * Root endpoint - API information
 * GET /
 */
router.get('/', (req, res) => {
  res.json({
    name: 'Container Security Test Application',
    version: '1.0.0',
    description: 'Node.js application for testing container namespace and cgroup isolation',
    endpoints: {
      root: {
        path: 'GET /',
        description: 'API information',
      },
      health: {
        path: 'GET /health',
        description: 'Health check with basic metrics',
        sub_endpoints: [
          'GET /health/live - Liveness probe',
          'GET /health/ready - Readiness probe',
          'GET /health/startup - Startup probe',
        ],
      },
      info: {
        path: 'GET /info',
        description: 'System information',
        sub_endpoints: [
          'GET /info/namespace - Namespace isolation',
          'GET /info/cgroup - Cgroup configuration',
          'GET /info/security - Security status',
          'GET /info/all - Complete system overview',
        ],
      },
      stress: {
        path: 'GET /stress',
        description: 'Stress testing endpoints',
        sub_endpoints: [
          'GET /stress/cpu?iterations=N - CPU stress test',
          'GET /stress/memory?size=N - Memory stress test (MB)',
          'GET /stress/combined?iterations=N&size=M - Combined test',
          'GET /stress/disk?operations=N - Disk I/O test',
        ],
      },
      metrics: {
        path: 'GET /metrics',
        description: 'Prometheus-style metrics',
      },
      legacy: {
        description: 'Legacy endpoints (backward compatibility)',
        endpoints: [
          'GET /namespace - Redirects to /info/namespace',
          'GET /cgroup - Redirects to /info/cgroup',
          'GET /compute - Redirects to /stress/cpu',
          'GET /memory - Redirects to /stress/memory',
        ],
      },
    },
    hostname: os.hostname(),
    timestamp: new Date().toISOString(),
  });
});

/**
 * Prometheus-style metrics endpoint
 * GET /metrics
 */
router.get('/metrics', (req, res) => {
  const prometheusMetrics = metrics.toPrometheusFormat();
  res.set('Content-Type', 'text/plain');
  res.send(prometheusMetrics);
});

export default router;
