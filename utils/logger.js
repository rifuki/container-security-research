/**
 * Logger Utility
 * Provides structured logging with different log levels
 */

import os from 'os';

class Logger {
  constructor(options = {}) {
    this.level = options.level || process.env.LOG_LEVEL || 'info';
    this.format = options.format || process.env.LOG_FORMAT || 'json';
    this.includeTimestamp = options.includeTimestamp !== false;
    this.includeHostname = options.includeHostname || false;
    
    this.levels = {
      error: 0,
      warn: 1,
      info: 2,
      debug: 3,
      trace: 4,
    };
    
    this.currentLevel = this.levels[this.level] || this.levels.info;
  }

  /**
   * Format log entry
   */
  formatLog(level, message, metadata = {}) {
    const entry = {
      level,
      message,
      timestamp: this.includeTimestamp ? new Date().toISOString() : undefined,
      hostname: this.includeHostname ? os.hostname() : undefined,
      pid: process.pid,
      ...metadata,
    };

    // Remove undefined values
    Object.keys(entry).forEach(key => {
      if (entry[key] === undefined) {
        delete entry[key];
      }
    });

    if (this.format === 'json') {
      return JSON.stringify(entry);
    } else {
      // Text format
      const timestamp = entry.timestamp ? `[${entry.timestamp}]` : '';
      const hostname = entry.hostname ? `[${entry.hostname}]` : '';
      const metaStr = Object.keys(metadata).length > 0 
        ? ` ${JSON.stringify(metadata)}` 
        : '';
      
      return `${timestamp}${hostname} ${level.toUpperCase()}: ${message}${metaStr}`;
    }
  }

  /**
   * Write log to stdout/stderr
   */
  write(level, message, metadata = {}) {
    const levelValue = this.levels[level];
    
    if (levelValue === undefined || levelValue > this.currentLevel) {
      return;
    }

    const formatted = this.formatLog(level, message, metadata);
    
    if (level === 'error') {
      console.error(formatted);
    } else {
      console.log(formatted);
    }
  }

  /**
   * Error level logging
   */
  error(message, metadata = {}) {
    this.write('error', message, metadata);
  }

  /**
   * Warning level logging
   */
  warn(message, metadata = {}) {
    this.write('warn', message, metadata);
  }

  /**
   * Info level logging
   */
  info(message, metadata = {}) {
    this.write('info', message, metadata);
  }

  /**
   * Debug level logging
   */
  debug(message, metadata = {}) {
    this.write('debug', message, metadata);
  }

  /**
   * Trace level logging
   */
  trace(message, metadata = {}) {
    this.write('trace', message, metadata);
  }

  /**
   * HTTP request logging middleware
   */
  httpLogger() {
    return (req, res, next) => {
      const start = Date.now();
      
      res.on('finish', () => {
        const duration = Date.now() - start;
        this.info('HTTP Request', {
          method: req.method,
          path: req.path,
          status: res.statusCode,
          duration_ms: duration,
          ip: req.ip,
        });
      });
      
      next();
    };
  }
}

export default new Logger();
