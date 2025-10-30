/**
 * Container Security Test Application
 *
 * Research: Docker namespace dan cgroup isolation
 */

import express from "express";
import os from "os";
import { APP_PORT } from "./config/constants.js";
import { requestLogger } from "./middleware/logger.js";
import { incrementErrors, metricsCollector } from "./middleware/metrics.js";
import { securityConfig } from "./config/security.js";
import routes from "./routes/index.js";

// ============================================
// CONFIGURATION
// ============================================
const app = express();

// ============================================
// MIDDLEWARE
// ============================================
app.use(express.json());
app.use(requestLogger);
app.use(metricsCollector);

// ============================================
// ROUTES
// ============================================
app.use("/", routes);

// ============================================
// ERROR HANDLING
// ============================================

/**
 * 404 handler
 */
app.use((req, res) => {
  res.status(404).json({
    error: "Not Found",
    message: `Endpoint ${req.method} ${req.path} not found`,
    available_endpoints: [
      "GET /",
      "GET /health",
      "GET /info",
      "GET /info/namespace",
      "GET /info/cgroup",
      "GET /stress/cpu?iterations=N",
      "GET /stress/memory?size=N",
      "GET /metrics",
    ],
  });
});

/**
 * Error handler
 */
app.use((err, _req, res, _next) => {
  incrementErrors();
  console.error(`[ERROR] ${err.message}`);

  res.status(500).json({
    error: "Internal Server Error",
    message: err.message,
  });
});

// ============================================
// GRACEFUL SHUTDOWN
// ============================================
function gracefulShutdown(signal) {
  console.log(`\n[${signal}] Received shutdown signal`);

  server.close(() => {
    console.log(`[SHUTDOWN] HTTP server closed`);
    process.exit(0);
  });

  // Force shutdown after 10 seconds
  setTimeout(() => {
    console.error("[SHUTDOWN] Forced shutdown after timeout");
    process.exit(1);
  }, 10000);
}

process.on("SIGTERM", () => gracefulShutdown("SIGTERM"));
process.on("SIGINT", () => gracefulShutdown("SIGINT"));

// Handle uncaught exceptions
process.on("uncughtException", (err) => {
  console.error("[FATAL] Uncaught exception:", err.message);
  process.exit(1);
});

process.on("unhandleRejection", (reason) => {
  console.error("[FATAL] Unhandled rejection:", reason);
  process.exit(1);
});

// ============================================
// START SERVER
// ============================================

const server = app.listen(APP_PORT, "0.0.0.0", () => {
  const userInfo = securityConfig.getUserInfo();

  console.log("=".repeat(60));
  console.log("Container Security Test Application");
  console.log("=".repeat(60));
  console.log(`Server:        http://0.0.0.0:${APP_PORT}`);
  console.log(`Process ID:    ${process.pid}`);
  console.log(`User UID:      ${userInfo.uid}`);
  console.log(`User GID:      ${userInfo.gid}`);
  console.log(`Running as:    ${userInfo.isRoot ? "ROOT ⚠️" : "Non-root ✅"}`);
  console.log(`Hostname:      ${os.hostname()}`);
  console.log(`Node version:  ${process.version}`);
  console.log(`Platform:      ${os.platform()} ${os.arch()}`);
  console.log(`Memory limit:  ${securityConfig.maxMemoryMB}MB`);
  console.log("-".repeat(60));
  console.log("Available endpoints");
  console.log("  GET  /                 - API information");
  console.log("  GET  /health           - Health check");
  console.log("  GET  /info             - System information");
  console.log("  GET  /info/namespace   - Namespace isolation");
  console.log("  GET  /info/cgroup      - Cgroup limits");
  console.log("  GET  /stress/cpu       - CPU stress test");
  console.log("  GET  /stress/memory    - Memory stress test");
  console.log("  GET  /metrics          - Prometheus metrics");
  console.log("-".repeat(60));
});
