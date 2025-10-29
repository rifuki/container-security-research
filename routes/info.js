/**
 * System Information Routes
 * Endpoints for retrieving system, container, and security information
 */

import express from 'express';
import os from 'os';
import fs from 'fs';
import path from 'path';
import logger from '../utils/logger.js';
import security from '../config/security.js';

const router = express.Router();

/**
 * Get basic system information
 */
function getSystemInfo() {
  const uptime = process.uptime();
  const memUsage = process.memoryUsage();
  
  return {
    hostname: os.hostname(),
    platform: os.platform(),
    architecture: os.arch(),
    node_version: process.version,
    cpus: {
      count: os.cpus().length,
      model: os.cpus()[0]?.model || 'Unknown',
    },
    memory: {
      total_mb: (os.totalmem() / 1024 / 1024).toFixed(2),
      free_mb: (os.freemem() / 1024 / 1024).toFixed(2),
      usage_percent: ((1 - os.freemem() / os.totalmem()) * 100).toFixed(2),
    },
    process: {
      pid: process.pid,
      uid: process.getuid ? process.getuid() : 'N/A',
      gid: process.getgid ? process.getgid() : 'N/A',
      uptime_seconds: uptime.toFixed(2),
      memory_rss_mb: (memUsage.rss / 1024 / 1024).toFixed(2),
      memory_heap_used_mb: (memUsage.heapUsed / 1024 / 1024).toFixed(2),
      memory_heap_total_mb: (memUsage.heapTotal / 1024 / 1024).toFixed(2),
    },
    timestamp: new Date().toISOString(),
  };
}

/**
 * Get namespace information
 */
function getNamespaceInfo() {
  try {
    const pid = process.pid;
    const nsPath = `/proc/${pid}/ns`;
    
    if (!fs.existsSync(nsPath)) {
      return { available: false, message: '/proc not accessible' };
    }

    const namespaces = ['pid', 'net', 'mnt', 'uts', 'ipc', 'user', 'cgroup'];
    const nsInfo = {};

    namespaces.forEach(ns => {
      try {
        const nsFile = path.join(nsPath, ns);
        if (fs.existsSync(nsFile)) {
          const stat = fs.lstatSync(nsFile);
          nsInfo[ns] = {
            exists: true,
            inode: stat.ino,
          };
        } else {
          nsInfo[ns] = { exists: false };
        }
      } catch (err) {
        nsInfo[ns] = { exists: false, error: err.message };
      }
    });

    return {
      available: true,
      namespaces: nsInfo,
    };
  } catch (err) {
    return {
      available: false,
      error: err.message,
    };
  }
}

/**
 * Get cgroup information
 */
function getCgroupInfo() {
  try {
    const cgroupFile = '/proc/self/cgroup';
    
    if (!fs.existsSync(cgroupFile)) {
      return { available: false, message: '/proc/self/cgroup not accessible' };
    }

    const cgroupData = fs.readFileSync(cgroupFile, 'utf8');
    const cgroups = cgroupData.split('\n')
      .filter(line => line.trim())
      .map(line => {
        const [id, controllers, path] = line.split(':');
        return { id, controllers, path };
      });

    // Try to read resource limits
    const limits = {};
    
    // CPU limit
    try {
      if (fs.existsSync('/sys/fs/cgroup/cpu.max')) {
        const cpuMax = fs.readFileSync('/sys/fs/cgroup/cpu.max', 'utf8').trim();
        limits.cpu = cpuMax;
      }
    } catch (e) { /* ignore */ }

    // Memory limit
    try {
      if (fs.existsSync('/sys/fs/cgroup/memory.max')) {
        const memMax = fs.readFileSync('/sys/fs/cgroup/memory.max', 'utf8').trim();
        limits.memory = memMax;
      }
    } catch (e) { /* ignore */ }

    // PIDs limit
    try {
      if (fs.existsSync('/sys/fs/cgroup/pids.max')) {
        const pidsMax = fs.readFileSync('/sys/fs/cgroup/pids.max', 'utf8').trim();
        limits.pids = pidsMax;
      }
    } catch (e) { /* ignore */ }

    return {
      available: true,
      cgroups: cgroups,
      limits: limits,
    };
  } catch (err) {
    return {
      available: false,
      error: err.message,
    };
  }
}

/**
 * General system information
 * GET /info
 */
router.get('/', (req, res) => {
  logger.debug('System info requested');
  const info = getSystemInfo();
  res.json(info);
});

/**
 * Namespace information
 * GET /info/namespace
 */
router.get('/namespace', (req, res) => {
  logger.debug('Namespace info requested');
  const nsInfo = getNamespaceInfo();
  res.json({
    description: 'Namespace isolation information for container security research',
    ...nsInfo,
  });
});

/**
 * Cgroup information
 * GET /info/cgroup
 */
router.get('/cgroup', (req, res) => {
  logger.debug('Cgroup info requested');
  const cgroupInfo = getCgroupInfo();
  res.json({
    description: 'Cgroup resource limits and configuration',
    ...cgroupInfo,
  });
});

/**
 * Security status information
 * GET /info/security
 */
router.get('/security', (req, res) => {
  logger.debug('Security info requested');
  
  const securityStatus = {
    user: security.process.getUserInfo(),
    hardening: {
      readOnlyFilesystem: security.hardening.isReadOnlyFilesystem(),
      warnings: security.hardening.getSecurityWarnings(security.process.getUserInfo()),
    },
    capabilities: {
      message: 'Capability inspection requires external tools like capsh',
    },
    timestamp: new Date().toISOString(),
  };
  
  res.json(securityStatus);
});

/**
 * Complete system overview
 * GET /info/all
 */
router.get('/all', (req, res) => {
  logger.debug('Complete system info requested');
  
  const completeInfo = {
    system: getSystemInfo(),
    namespace: getNamespaceInfo(),
    cgroup: getCgroupInfo(),
    security: {
      user: security.process.getUserInfo(),
      readOnlyFilesystem: security.hardening.isReadOnlyFilesystem(),
    },
    timestamp: new Date().toISOString(),
  };
  
  res.json(completeInfo);
});

export default router;
