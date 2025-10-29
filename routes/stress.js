/**
 * Stress Testing Routes
 * Endpoints for CPU and memory stress testing
 */

import express from 'express';
import fs from 'fs';
import os from 'os';
import path from 'path';
import logger from '../utils/logger.js';
import security from '../config/security.js';

const router = express.Router();

/**
 * CPU stress test endpoint
 * GET /stress/cpu?iterations=N
 */
router.get('/cpu', (req, res) => {
  const iterations = security.sanitizeNumericInput(
    req.query.iterations,
    1000000,
    1,
    security.limits.maxComputeIterations
  );
  
  logger.info('CPU stress test started', { iterations });
  
  const start = Date.now();
  let result = 0;
  
  try {
    // CPU-intensive computation
    for (let i = 0; i < iterations; i++) {
      result += Math.sqrt(i) * Math.sin(i) * Math.cos(i);
    }
    
    const duration = Date.now() - start;
    
    logger.info('CPU stress test completed', { iterations, duration_ms: duration });
    
    res.json({
      status: 'completed',
      test: 'CPU computation',
      iterations: iterations,
      duration_ms: duration,
      result: result,
      avg_time_per_iteration_ns: ((duration * 1000000) / iterations).toFixed(2),
      message: `CPU stress test completed in ${duration}ms`,
    });
  } catch (error) {
    logger.error('CPU stress test failed', { error: error.message });
    
    res.status(500).json({
      status: 'error',
      test: 'CPU computation',
      error: error.message,
      iterations: iterations,
    });
  }
});

/**
 * Memory stress test endpoint
 * GET /stress/memory?size=N
 */
router.get('/memory', (req, res) => {
  const sizeMB = security.sanitizeNumericInput(
    req.query.size,
    100,
    1,
    security.limits.maxMemoryMB
  );
  
  logger.info('Memory stress test started', { size_mb: sizeMB });
  
  try {
    const start = Date.now();
    
    // Allocate memory using Buffer
    const buffer = Buffer.alloc(sizeMB * 1024 * 1024);
    
    // Write data to ensure actual allocation
    for (let i = 0; i < buffer.length; i += 4096) {
      buffer[i] = (i % 256);
    }
    
    const duration = Date.now() - start;
    const memUsage = process.memoryUsage();
    
    logger.info('Memory stress test completed', { size_mb: sizeMB, duration_ms: duration });
    
    res.json({
      status: 'success',
      test: 'Memory allocation',
      allocated_mb: sizeMB,
      duration_ms: duration,
      memory_usage: {
        rss_mb: (memUsage.rss / 1024 / 1024).toFixed(2),
        heap_used_mb: (memUsage.heapUsed / 1024 / 1024).toFixed(2),
        heap_total_mb: (memUsage.heapTotal / 1024 / 1024).toFixed(2),
        external_mb: (memUsage.external / 1024 / 1024).toFixed(2),
      },
      message: `Successfully allocated ${sizeMB} MB in ${duration}ms`,
    });
    
    // Cleanup after sending response
    setImmediate(() => {
      if (global.gc) {
        global.gc();
      }
    });
    
  } catch (error) {
    logger.error('Memory stress test failed', { error: error.message });
    
    res.status(500).json({
      status: 'error',
      test: 'Memory allocation',
      error: error.message,
      requested_mb: sizeMB,
      max_allowed_mb: security.limits.maxMemoryMB,
      message: 'Memory allocation failed',
    });
  }
});

/**
 * Combined stress test endpoint
 * GET /stress/combined?iterations=N&size=M
 */
router.get('/combined', (req, res) => {
  const iterations = security.sanitizeNumericInput(
    req.query.iterations,
    1000000,
    1,
    security.limits.maxComputeIterations
  );
  
  const sizeMB = security.sanitizeNumericInput(
    req.query.size,
    50,
    1,
    security.limits.maxMemoryMB
  );
  
  logger.info('Combined stress test started', { iterations, size_mb: sizeMB });
  
  try {
    const start = Date.now();
    
    // Allocate memory
    const buffer = Buffer.alloc(sizeMB * 1024 * 1024);
    for (let i = 0; i < buffer.length; i += 4096) {
      buffer[i] = (i % 256);
    }
    
    // CPU computation
    let result = 0;
    for (let i = 0; i < iterations; i++) {
      result += Math.sqrt(i) * Math.sin(i) * Math.cos(i);
    }
    
    const duration = Date.now() - start;
    const memUsage = process.memoryUsage();
    
    logger.info('Combined stress test completed', { 
      iterations, 
      size_mb: sizeMB, 
      duration_ms: duration 
    });
    
    res.json({
      status: 'completed',
      test: 'Combined CPU and Memory stress',
      cpu: {
        iterations: iterations,
        result: result,
      },
      memory: {
        allocated_mb: sizeMB,
      },
      duration_ms: duration,
      memory_usage: {
        rss_mb: (memUsage.rss / 1024 / 1024).toFixed(2),
        heap_used_mb: (memUsage.heapUsed / 1024 / 1024).toFixed(2),
        heap_total_mb: (memUsage.heapTotal / 1024 / 1024).toFixed(2),
        external_mb: (memUsage.external / 1024 / 1024).toFixed(2),
      },
      message: `Combined test completed in ${duration}ms`,
    });
    
    // Cleanup
    setImmediate(() => {
      if (global.gc) {
        global.gc();
      }
    });
    
  } catch (error) {
    logger.error('Combined stress test failed', { error: error.message });
    
    res.status(500).json({
      status: 'error',
      test: 'Combined stress',
      error: error.message,
    });
  }
});

/**
 * Disk I/O stress test endpoint
 * GET /stress/disk?operations=N
 */
router.get('/disk', (req, res) => {
  const operations = security.sanitizeNumericInput(
    req.query.operations,
    100,
    1,
    10000
  );
  
  logger.info('Disk I/O stress test started', { operations });
  
  try {
    const start = Date.now();
    const tmpDir = os.tmpdir();
    const testFile = path.join(tmpDir, `stress-test-${Date.now()}.tmp`);
    
    // Write operations
    const data = Buffer.alloc(1024, 'x'); // 1KB buffer
    let writeCount = 0;
    
    for (let i = 0; i < operations; i++) {
      fs.writeFileSync(testFile, data);
      writeCount++;
    }
    
    // Read operations
    let readCount = 0;
    for (let i = 0; i < operations; i++) {
      fs.readFileSync(testFile);
      readCount++;
    }
    
    // Cleanup
    fs.unlinkSync(testFile);
    
    const duration = Date.now() - start;
    
    logger.info('Disk I/O stress test completed', { operations, duration_ms: duration });
    
    res.json({
      status: 'completed',
      test: 'Disk I/O',
      operations: operations,
      write_operations: writeCount,
      read_operations: readCount,
      duration_ms: duration,
      ops_per_second: ((operations * 2) / (duration / 1000)).toFixed(2),
      message: `Disk I/O test completed in ${duration}ms`,
    });
    
  } catch (error) {
    logger.error('Disk I/O stress test failed', { error: error.message });
    
    res.status(500).json({
      status: 'error',
      test: 'Disk I/O',
      error: error.message,
      message: 'Disk I/O test failed (possibly read-only filesystem)',
    });
  }
});

export default router;
