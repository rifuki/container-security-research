/**
 * Cgroup Inspection Utilities
 * Get Linux cgroup information from /proc and /sys/fs/cgroup
 */

import fs from "fs";
import path from "path";

/**
 * Get cgroup v2 information for current process
 * Kernel 5.10+
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
        console.log({ id, controllers, path });
        return { id, controllers, path };
      });

    const basePath = "/sys/fs/cgroup";
    // CPU limit (cgroup v2)
    const cpuMax = readFileSafe(path.join(basePath, "cpu.max"));
    // Memory limit (cgroup v2)
    const memoryMax = readFileSafe(path.join(basePath, "memory.max"));
    // PIDs limit (cgroup v2)
    const pidsMax = readFileSafe(path.join(basePath, "pids.max"));

    return {
      available: true,
      cgroups,
      limits: {
        cpuMax,
        memoryMax,
        pidsMax,
      },
    };
  } catch (error) {
    return {
      available: false,
      error: `Error reading cgroup info: ${error.message}`,
    };
  }
}

// Helper to read file safely
function readFileSafe(filePath) {
  try {
    if (!fs.existsSync(filePath)) return null;
    return fs.readFileSync(filePath, "utf8").trim();
  } catch (error) {
    return null;
  }
}
