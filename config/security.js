/**
 * Security Configuration
 * Centralized security settings for the container application
 */

import fs from 'fs';

const security = {
  // Resource Limits
  limits: {
    maxMemoryMB: parseInt(process.env.MAX_MEMORY_MB || '512', 10),
    maxComputeIterations: 100000000, // 100M iterations max
    maxRequestTimeout: 30000, // 30 seconds
    maxPayloadSize: '10mb', // Maximum request body size
  },

  // HTTP Security Headers
  headers: {
    // Prevent MIME type sniffing
    'X-Content-Type-Options': 'nosniff',
    
    // Enable XSS protection
    'X-XSS-Protection': '1; mode=block',
    
    // Prevent clickjacking
    'X-Frame-Options': 'DENY',
    
    // Content Security Policy
    'Content-Security-Policy': "default-src 'self'; script-src 'self'; style-src 'self'; img-src 'self' data:;",
    
    // Referrer Policy
    'Referrer-Policy': 'strict-origin-when-cross-origin',
    
    // Permissions Policy
    'Permissions-Policy': 'geolocation=(), microphone=(), camera=()',
  },

  // CORS Configuration
  cors: {
    enabled: process.env.CORS_ENABLED === 'true',
    allowedOrigins: process.env.CORS_ORIGINS ? process.env.CORS_ORIGINS.split(',') : ['*'],
    allowedMethods: ['GET', 'POST', 'OPTIONS'],
    allowedHeaders: ['Content-Type', 'Authorization'],
    credentials: false,
    maxAge: 86400, // 24 hours
  },

  // Rate Limiting (if implemented)
  rateLimit: {
    windowMs: 15 * 60 * 1000, // 15 minutes
    maxRequests: 100, // Max requests per window
  },

  // Process Security
  process: {
    // Recommended UID/GID for non-root execution
    recommendedUID: 1000,
    recommendedGID: 1000,
    
    // Check if running as root
    isRunningAsRoot() {
      if (typeof process.getuid === 'function') {
        return process.getuid() === 0;
      }
      return false;
    },
    
    // Get current user info
    getUserInfo() {
      if (typeof process.getuid === 'function' && typeof process.getgid === 'function') {
        return {
          uid: process.getuid(),
          gid: process.getgid(),
          isRoot: this.isRunningAsRoot(),
        };
      }
      return {
        uid: 'N/A',
        gid: 'N/A',
        isRoot: false,
      };
    },
  },

  // Container Hardening Checks
  hardening: {
    // Check if running in read-only filesystem
    isReadOnlyFilesystem() {
      try {
        fs.writeFileSync('/test-write', 'test');
        fs.unlinkSync('/test-write');
        return false;
      } catch (err) {
        return err.code === 'EROFS' || err.code === 'EACCES';
      }
    },

    // Get security status summary
    getSecurityStatus() {
      const userInfo = security.process.getUserInfo();
      
      return {
        user: userInfo,
        readOnlyFilesystem: this.isReadOnlyFilesystem(),
        recommendedSettings: {
          nonRootUser: !userInfo.isRoot,
          readOnlyFS: this.isReadOnlyFilesystem(),
        },
        warnings: this.getSecurityWarnings(userInfo),
      };
    },

    // Get security warnings
    getSecurityWarnings(userInfo) {
      const warnings = [];
      
      if (userInfo.isRoot) {
        warnings.push({
          severity: 'HIGH',
          message: 'Application running as root user (UID 0)',
          recommendation: 'Use non-root user (e.g., --user 1000:1000)',
        });
      }
      
      if (!this.isReadOnlyFilesystem()) {
        warnings.push({
          severity: 'MEDIUM',
          message: 'Filesystem is writable',
          recommendation: 'Use read-only filesystem (--read-only with --tmpfs /tmp)',
        });
      }
      
      return warnings;
    },
  },

  // Logging Configuration
  logging: {
    level: process.env.LOG_LEVEL || 'info',
    enableAccessLog: true,
    enableErrorLog: true,
    logFormat: process.env.LOG_FORMAT || 'json', // 'json' or 'text'
    
    // Sensitive data patterns to redact
    sensitivePatterns: [
      /password/i,
      /token/i,
      /secret/i,
      /api[_-]?key/i,
      /authorization/i,
    ],
  },
};

// Apply security headers middleware
security.applySecurityHeaders = (req, res, next) => {
  Object.entries(security.headers).forEach(([header, value]) => {
    res.setHeader(header, value);
  });
  next();
};

// Apply CORS middleware
security.applyCORS = (req, res, next) => {
  if (security.cors.enabled) {
    const origin = req.headers.origin;
    
    if (security.cors.allowedOrigins.includes('*') || 
        security.cors.allowedOrigins.includes(origin)) {
      res.setHeader('Access-Control-Allow-Origin', origin || '*');
    }
    
    res.setHeader('Access-Control-Allow-Methods', security.cors.allowedMethods.join(', '));
    res.setHeader('Access-Control-Allow-Headers', security.cors.allowedHeaders.join(', '));
    res.setHeader('Access-Control-Max-Age', security.cors.maxAge);
    
    if (security.cors.credentials) {
      res.setHeader('Access-Control-Allow-Credentials', 'true');
    }
    
    // Handle preflight requests
    if (req.method === 'OPTIONS') {
      return res.sendStatus(204);
    }
  }
  
  next();
};

// Validate and sanitize numeric input
security.sanitizeNumericInput = (value, defaultValue, min, max) => {
  const num = parseInt(value, 10);
  if (isNaN(num)) return defaultValue;
  if (min !== undefined && num < min) return min;
  if (max !== undefined && num > max) return max;
  return num;
};

export default security;
