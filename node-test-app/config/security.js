/**
 * Security Configuration
 * Centralized security settings and validation
 */

import { MAX_ITERATIONS, MAX_MEMORY_MB } from "./constants.js";

export const securityConfig = {
  // Resource limits
  maxMemoryMB: Number(MAX_MEMORY_MB),
  maxIterations: Number(MAX_ITERATIONS),

  // Check if running as root
  isRunningAsRoot() {
    if (typeof process.getuid === "function") {
      return process.getuid() === 0;
    }
    return false;
  },

  // Get user info
  getUserInfo() {
    return {
      uid: process.getuid ? process.getuid() : "N/A",
      gid: process.getgid ? process.getgid() : "N/A",
      isRoot: this.isRunningAsRoot(),
    };
  },
};
