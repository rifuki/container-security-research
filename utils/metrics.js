/**
 * Metrics Collector
 * Collects and formats application metrics for monitoring
 */

import os from 'os';

class MetricsCollector {
  constructor() {
    this.customMetrics = new Map();
    this.startTime = Date.now();
    this.requestCount = 0;
    this.errorCount = 0;
  }

  /**
   * Increment request counter
   */
  incrementRequests() {
    this.requestCount++;
  }

  /**
   * Increment error counter
   */
  incrementErrors() {
    this.errorCount++;
  }

  /**
   * Set custom metric
   */
  setMetric(name, value, help = '', type = 'gauge') {
    this.customMetrics.set(name, { value, help, type });
  }

  /**
   * Increment custom counter
   */
  incrementMetric(name, amount = 1) {
    const metric = this.customMetrics.get(name);
    if (metric) {
      metric.value += amount;
    } else {
      this.setMetric(name, amount, '', 'counter');
    }
  }

  /**
   * Get process metrics
   */
  getProcessMetrics() {
    const memUsage = process.memoryUsage();
    const uptime = process.uptime();
    
    return {
      uptime_seconds: uptime,
      memory_rss_bytes: memUsage.rss,
      memory_heap_used_bytes: memUsage.heapUsed,
      memory_heap_total_bytes: memUsage.heapTotal,
      memory_external_bytes: memUsage.external,
      cpu_count: os.cpus().length,
      process_pid: process.pid,
      app_uptime_seconds: (Date.now() - this.startTime) / 1000,
    };
  }

  /**
   * Get system metrics
   */
  getSystemMetrics() {
    return {
      total_memory_bytes: os.totalmem(),
      free_memory_bytes: os.freemem(),
      load_average_1m: os.loadavg()[0],
      load_average_5m: os.loadavg()[1],
      load_average_15m: os.loadavg()[2],
    };
  }

  /**
   * Get application metrics
   */
  getApplicationMetrics() {
    return {
      http_requests_total: this.requestCount,
      http_errors_total: this.errorCount,
    };
  }

  /**
   * Get all metrics as object
   */
  getAllMetrics() {
    const metrics = {
      process: this.getProcessMetrics(),
      system: this.getSystemMetrics(),
      application: this.getApplicationMetrics(),
      custom: {},
    };

    // Add custom metrics
    this.customMetrics.forEach((metric, name) => {
      metrics.custom[name] = metric.value;
    });

    return metrics;
  }

  /**
   * Format metrics in Prometheus format
   */
  toPrometheusFormat() {
    const lines = [];
    
    // Process metrics
    const processMetrics = this.getProcessMetrics();
    
    lines.push('# HELP container_test_uptime_seconds Container uptime in seconds');
    lines.push('# TYPE container_test_uptime_seconds gauge');
    lines.push(`container_test_uptime_seconds ${processMetrics.uptime_seconds.toFixed(2)}`);
    lines.push('');

    lines.push('# HELP container_test_memory_rss_bytes Memory RSS in bytes');
    lines.push('# TYPE container_test_memory_rss_bytes gauge');
    lines.push(`container_test_memory_rss_bytes ${processMetrics.memory_rss_bytes}`);
    lines.push('');

    lines.push('# HELP container_test_memory_heap_used_bytes Heap memory used in bytes');
    lines.push('# TYPE container_test_memory_heap_used_bytes gauge');
    lines.push(`container_test_memory_heap_used_bytes ${processMetrics.memory_heap_used_bytes}`);
    lines.push('');

    lines.push('# HELP container_test_memory_heap_total_bytes Total heap memory in bytes');
    lines.push('# TYPE container_test_memory_heap_total_bytes gauge');
    lines.push(`container_test_memory_heap_total_bytes ${processMetrics.memory_heap_total_bytes}`);
    lines.push('');

    lines.push('# HELP container_test_cpu_count Number of CPUs');
    lines.push('# TYPE container_test_cpu_count gauge');
    lines.push(`container_test_cpu_count ${processMetrics.cpu_count}`);
    lines.push('');

    lines.push('# HELP container_test_process_pid Process PID');
    lines.push('# TYPE container_test_process_pid gauge');
    lines.push(`container_test_process_pid ${processMetrics.process_pid}`);
    lines.push('');

    // Application metrics
    const appMetrics = this.getApplicationMetrics();
    
    lines.push('# HELP container_test_http_requests_total Total HTTP requests');
    lines.push('# TYPE container_test_http_requests_total counter');
    lines.push(`container_test_http_requests_total ${appMetrics.http_requests_total}`);
    lines.push('');

    lines.push('# HELP container_test_http_errors_total Total HTTP errors');
    lines.push('# TYPE container_test_http_errors_total counter');
    lines.push(`container_test_http_errors_total ${appMetrics.http_errors_total}`);
    lines.push('');

    // System metrics
    const systemMetrics = this.getSystemMetrics();
    
    lines.push('# HELP container_test_system_memory_total_bytes Total system memory');
    lines.push('# TYPE container_test_system_memory_total_bytes gauge');
    lines.push(`container_test_system_memory_total_bytes ${systemMetrics.total_memory_bytes}`);
    lines.push('');

    lines.push('# HELP container_test_system_memory_free_bytes Free system memory');
    lines.push('# TYPE container_test_system_memory_free_bytes gauge');
    lines.push(`container_test_system_memory_free_bytes ${systemMetrics.free_memory_bytes}`);
    lines.push('');

    // Custom metrics
    this.customMetrics.forEach((metric, name) => {
      if (metric.help) {
        lines.push(`# HELP ${name} ${metric.help}`);
      }
      lines.push(`# TYPE ${name} ${metric.type}`);
      lines.push(`${name} ${metric.value}`);
      lines.push('');
    });

    return lines.join('\n');
  }

  /**
   * Get metrics middleware
   */
  metricsMiddleware() {
    return (req, res, next) => {
      this.incrementRequests();
      if (res.statusCode >= 400) this.incrementErrors();
      next();
    };
  }
}

export default new MetricsCollector();
