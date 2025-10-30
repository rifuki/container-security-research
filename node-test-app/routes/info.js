/**
 * System Information Routes
 * Endpoints for system, namespace, and cgroup information
 */

import express from "express";
import os from "os";
import { getCgroupInfo } from "../utils/cgroup.js";
import { getNamespaceInfo } from "../utils/namespace.js";

const router = express.Router();

/**
 * General system information
 * GET /info
 */
router.get("/", (_req, res) => {
  const uptime = process.uptime();
  const memUsage = process.memoryUsage();

  res.json({
    hostname: os.hostname(),
    platform: os.platform(),
    architecture: os.arch(),
    node_version: process.version,
    cpus: {
      count: os.cpus().length,
      model: os.cpus()[0]?.model || "Unknown",
    },
    memory: {
      total_mb: (os.totalmem() / 1024 / 1024).toFixed(2),
      free_mb: (os.freemem() / 1024 / 1024).toFixed(2),
      usage_percent: ((1 - os.freemem() / os.totalmem()) * 100).toFixed(2),
    },
    process: {
      pid: process.pid,
      uid: process.getuid ? process.getuid() : "N/A",
      gid: process.getgid ? process.getgid() : "N/A",
      uptime_seconds: uptime.toFixed(2),
      memory_rss_mb: (memUsage.rss / 1024 / 1024).toFixed(2),
    },
    timestamp: new Date().toISOString(),
  });
});

/**
 * Namespace isolation information
 * GET /info/namespace
 */
router.get("/namespace", (_req, res) => {
  const nsInfo = getNamespaceInfo();
  res.json({
    description: "Container namespace isolation information",
    ...nsInfo,
  });
});

/**
 * Cgroup limits and configuration
 * GET /info/cgroup
 */
router.get("/cgroup", (_req, res) => {
  const cgroupInfo = getCgroupInfo();
  res.json({
    description: "Container cgroup limits and configuration",
    ...cgroupInfo,
  });
});

export default router;
