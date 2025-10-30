/**
 * Metrics Collector Middleware
 * Track request counts and errors
 */

// Global counters
let requestCount = 0;
let errorCount = 0;

/**
 * Request counter middleware
 */
export function metricsCollector(_req, _res, next) {
  requestCount++;
  next();
}

/**
 * Increment error counter
 */
export function incrementErrors() {
  errorCount++;
}

/**
 * Get current metrics
 */
export function getMetrics() {
  return {
    requests: requestCount,
    errors: errorCount,
  };
}
