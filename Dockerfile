# ============================================
# Dockerfile for Container Security Test App
# Multi-stage build for optimization
# ============================================

# ============================================
# Stage 1: Builder
# ============================================
FROM node:20-alpine AS builder

LABEL maintainer="rifuki"
LABEL description="Container Security Test Application - Builder Stage"

WORKDIR /build

# Copy package files
COPY package*.json ./

# Install dependencies (production only)
RUN npm ci --only=production --ignore-scripts

# ============================================
# Stage 2: Production
# ============================================
FROM node:20-alpine

LABEL maintainer="rifuki"
LABEL description="Container Security Test Application"
LABEL version="1.0.0"

# Install dumb-init for proper signal handling
RUN apk add --no-cache dumb-init

# Create non-root user
RUN addgroup -g 1000 appuser && \
    adduser -D -u 1000 -G appuser appuser

# Set working directory
WORKDIR /app

# Copy node_modules from builder
COPY --from=builder --chown=appuser:appuser /build/node_modules ./node_modules

# Copy application files
COPY --chown=appuser:appuser app.js ./
COPY --chown=appuser:appuser package*.json ./
COPY --chown=appuser:appuser config/ ./config/
COPY --chown=appuser:appuser routes/ ./routes/
COPY --chown=appuser:appuser utils/ ./utils/

# Create necessary directories with proper permissions
RUN mkdir -p /app/logs && \
    chown -R appuser:appuser /app

# Switch to non-root user
USER appuser

# Expose port
EXPOSE 3000

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=40s --retries=3 \
  CMD node -e "require('http').get('http://localhost:3000/health', (r) => {process.exit(r.statusCode === 200 ? 0 : 1)})"

# Environment variables
ENV NODE_ENV=production \
    PORT=3000 \
    MAX_MEMORY_MB=512

# Use dumb-init to handle signals properly
ENTRYPOINT ["/usr/bin/dumb-init", "--"]

# Start application
CMD ["node", "app.js"]