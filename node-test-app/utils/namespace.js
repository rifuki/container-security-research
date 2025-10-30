/**
 * Namespace Inspection Utilities
 * Get Linux namespace information form /proc
 */

import fs from "fs";
import path from "path";

/**
 * Get namespace information for current process
 */
export function getNamespaceInfo() {
  try {
    const pid = process.pid;
    const nsPath = `/proc/${pid}/ns`;

    if (!fs.existsSync(nsPath)) {
      return {
        available: false,
        message:
          "/proc not accessible (not running on Linux or permission denied)",
      };
    }

    const namespaces = ["pid", "net", "mnt", "uts", "ipc", "user", "cgroup"];
    const nsInfo = {};

    namespaces.forEach((ns) => {
      try {
        const nsFile = path.join(nsPath, ns);
        if (fs.existsSync(nsFile)) {
          const stat = fs.lstatSync(nsFile);
          nsInfo[ns] = {
            exists: true,
            inode: stat.ino,
          };
        }
      } catch (error) {
        nsInfo[ns] = {
          exists: false,
          error: error.message,
        };
      }
    });

    return {
      available: true,
      namespaces: nsInfo,
    };
  } catch (error) {
    return {
      available: false,
      error: error.message,
    };
  }
}
