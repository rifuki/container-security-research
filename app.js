/**
 * Container Security Test Application
 * Main application entry point using modular architecture
 */

import express from 'express';
import os from 'os';
import logger from './utils/logger.js';
import metrics from './utils/metrics.js';
import security from './config/security.js';
import routes from './routes/index.js';

// Initialize Express
const app = express();
const PORT = process.env.PORT || 3000;

// ============================================
// MIDDLEWARE
// ============================================

// Body parsers
app.use(express.json({ limit: security.limits.maxPayloadSize }));
app.use(express.urlencoded({ extended: true, limit: security.limits.maxPayloadSize }));

// Security headers
app.use(security.applySecurityHeaders);

// CORS
app.use(security.applyCORS);

// Request logging
app.use(logger.httpLogger());

// Metrics collection
app.use(metrics.metricsMiddleware());

// ============================================
// ROUTES
// ============================================

// Mount all routes
app.use('/', routes);

// ============================================
// ERROR HANDLING
// ============================================

/**
 * 404 handler
 */
app.use((req, res) => {
  logger.warn('404 Not Found', { method: req.method, path: req.path });
  
  res.status(404).json({
    error: 'Not Found',
    message: `Endpoint ${req.method} ${req.path} not found`,
    available_endpoints: [
      '/',
      '/health',
      '/info',
      '/stress',
      '/metrics',
    ],
  });
});

/**
 * Error handler
 */
app.use((err, req, res, next) => {
  logger.error('Error occurred', {
    error: err.message,
    stack: err.stack,
    method: req.method,
    path: req.path,
  });
  
  res.status(500).json({
    error: 'Internal Server Error',
    message: err.message,
  });
});

// ============================================
// GRACEFUL SHUTDOWN
// ============================================

function gracefulShutdown(signal) {
  logger.info(`${signal} received. Starting graceful shutdown...`);
  
  server.close(() => {
    logger.info('HTTP server closed');
    logger.info('Exiting process');
    process.exit(0);
  });
  
  // Force shutdown after 10 seconds
  setTimeout(() => {
    logger.error('Forced shutdown after timeout');
    process.exit(1);
  }, 10000);
}

process.on('SIGTERM', () => gracefulShutdown('SIGTERM'));
process.on('SIGINT', () => gracefulShutdown('SIGINT'));

// Handle uncaught exceptions
process.on('uncaughtException', (err) => {
  logger.error('Uncaught exception', { error: err.message, stack: err.stack });
  process.exit(1);
});

process.on('unhandledRejection', (reason, promise) => {
  logger.error('Unhandled rejection', { reason, promise });
  process.exit(1);
});

// ============================================
// STARTUP
// ============================================

// Check security status on startup
const securityStatus = security.hardening.getSecurityStatus();
if (securityStatus.warnings.length > 0) {
  logger.warn('Security warnings detected', { warnings: securityStatus.warnings });
}

// ============================================
// START SERVER
// ============================================

const server = app.listen(PORT, '0.0.0.0', () => {
  logger.info('='.repeat(60));
  logger.info('Container Security Test Application');
  logger.info('='.repeat(60));
  logger.info(`Server running on port: ${PORT}`);
  logger.info(`Process ID: ${process.pid}`);
  logger.info(`User UID: ${process.getuid ? process.getuid() : 'N/A'}`);
  logger.info(`User GID: ${process.getgid ? process.getgid() : 'N/A'}`);
  logger.info(`Hostname: ${os.hostname()}`);
  logger.info(`Node version: ${process.version}`);
  logger.info(`Platform: ${os.platform()} ${os.arch()}`);
  logger.info(`Memory limit: ${security.limits.maxMemoryMB} MB`);
  logger.info(`Read-only FS: ${securityStatus.readOnlyFilesystem}`);
  logger.info('='.repeat(60));
  logger.info('Available endpoints:');
  logger.info('  GET  /          - API information');
  logger.info('  GET  /health    - Health check');
  logger.info('  GET  /info      - System information');
  logger.info('  GET  /stress    - Stress testing');
  logger.info('  GET  /metrics   - Prometheus metrics');
  logger.info('='.repeat(60));
  
  // Log security warnings
  if (securityStatus.warnings.length > 0) {
    logger.warn('Security Configuration Warnings:');
    securityStatus.warnings.forEach(warning => {
      logger.warn(`  [${warning.severity}] ${warning.message}`);
      logger.warn(`  Recommendation: ${warning.recommendation}`);
    });
  }
});

// Server timeouts for reliability
server.timeout = security.limits.maxRequestTimeout;
server.keepAliveTimeout = 65000;
server.headersTimeout = 66000;
