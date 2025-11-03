/**
 * Stress Testing Routes
 * Endpoints for CPU and memory stress testing
 */

import express from "express";
import { sanitizeNumber } from "../utils/sanitizeNumber.js";
import { securityConfig } from "../config/security.js";

const router = express.Router();

/**
 * CPU stress test
 * GET /stress/cpu?iterations=N
 */
router.get("/cpu", (req, res) => {
  const iterations = sanitizeNumber(
    req.query.iterations,
    1000000,
    1,
    securityConfig.maxIterations,
  );

  console.log(`[CPU Stress] Starting with ${iterations} iterations`);

  try {
    const start = Date.now();
    let result = 0;
    // CPU-intensive computation
    for (let i = 0; i < iterations; i++) {
      result += Math.sqrt(i) * Math.sin(i) * Math.cos(i);
    }

    const duration_ms = Date.now() - start;

    console.log(`[CPU Stress] Completed in ${duration_ms}ms`);

    res.json({
      status: "completed",
      test: "CPU computation",
      iterations,
      duration_ms,
      result,
      avg_time_per_iteration_ns: ((duration_ms * 1000000) / iterations).toFixed(
        2,
      ),
      message: `CPU stress test completed in ${duration_ms}ms`,
    });
  } catch (error) {
    console.error(`[CPU Stress] Failed: ${error.message}`);

    res.status(500).json({
      status: "error",
      test: "CPU computation",
      error: error.message,
      iterations,
    });
  }
});

/**
 * Memory stress test
 * GET /stress/memory?size=N
 */
router.get("/memory", (req, res) => {
  const sizeMB = sanitizeNumber(
    req.query.size,
    100,
    1,
    securityConfig.maxMemoryMB,
  );

  console.log(`[Memory Stress] Starting allocation of ${sizeMB}MB`);

  try {
    const start = Date.now();

    // Allocate memory using buffer
    const buffer = Buffer.alloc(sizeMB * 1024 * 1024);

    // Write data to ensure actual allocation
    for (let i = 0; i < buffer.length; i += 4096) {
      buffer[i] = i % 256;
    }

    const duration_ms = Date.now() - start;
    const memUsage = process.memoryUsage();

    console.log(`[Memory Stress] Completed in ${duration_ms}ms`);

    res.json({
      status: "success",
      test: "Memory allocation",
      allocated_mb: sizeMB,
      duration_ms: duration_ms,
      memory_usage: {
        rss_mb: (memUsage.rss / 1024 / 1024).toFixed(2),
        heap_used_mb: (memUsage.heapUsed / 1024 / 1024).toFixed(2),
        heap_total_mb: (memUsage.heapTotal / 1024 / 1024).toFixed(2),
        external_mb: (memUsage.external / 1024 / 1024).toFixed(2),
      },
      message: `Successfully allocated ${sizeMB}MB in ${duration_ms}ms`,
    });

    // Cleanup after sending response
    setImmediate(() => {
      if (global.gc) {
        global.gc();
      }
    });
  } catch (error) {
    console.error(`[Memory Stress] Failed: ${error.message}`);

    res.status(500).json({
      status: "error",
      test: "Memory allocation",
      error: error.message,
      requested_mb: sizeMB,
      max_allowed_mb: securityConfig.maxMemoryMB,
      message: "Memory allocation failed",
    });
  }
});

export default router;
