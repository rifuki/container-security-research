/**
 * Cgroup Inspection Utilities
 * Get Linux cgroup information from /proc and /sys/fs/cgroup
 */

import fs from "fs";

/**
 * Get cgroup information for current process
 */
export function getCgroupInfo() {
  try {
    const cgroupFile = "/proc/self/cgroup";

    if (!fs.existsSync(cgroupFile)) {
      return {
        available: false,
        message: "/proc/self/cgroup not accessible (not running on Linux)",
      };
    }

    const cgroupData = fs.readFileSync(cgroupFile, "utf8");
    const cgroups = cgroupData
      .split("\n")
      .filter((line) => line.trim())
      .map((line) => {
        const [id, controllers, path] = line.split(":");
        return { id, controllers, path };
      });

    // Try to read resource limits
    const limits = {};

    // CPU limit (cgroup v2)
    try {
      if (fs.existsSync("/sys/fs/cgroup/cpu.max")) {
        limits.cpu = fs.readFileSync("/sys/fs/cgroup/cpu.max", "utf8").trim();
      }
    } catch (error) {
      /* ignore */
    }

    // Memory limit (cgroup v2)
    try {
      if (fs.existsSync("/sys/fs/cgroup/memory.max")) {
        limits.memory = fs
          .readFileSync("/sys/fs/cgroup/memory.max", "utf8")
          .trim();
      }
    } catch (error) {
      /* ignore */
    }

    // PIDs limit (cgroup v2)
    try {
      if (fs.existsSync("/sys/fs/cgroup/pids.max")) {
        limits.pids = fs.readFileSync("/sys/fs/cgroup/pids.max", "utf8").trim();
      }
    } catch (error) {
      /* ignore */
    }

    return {
      available: true,
      cgroups,
      limits,
    };
  } catch (error) {
    return {
      available: false,
      error: err.message,
    };
  }
}
