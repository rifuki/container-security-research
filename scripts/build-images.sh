#!/bin/bash

##############################################################################
# Build Container Image Script
#
# Builds single neutral image for security comparison research
# Same image will be used for both baseline and hardened deployments
##############################################################################

set -e

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Building Container Image${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

echo -e "${BLUE}Research Design:${NC}"
echo "  ✓ Single neutral image (node:20-alpine)"
echo "  ✓ Same code, same dependencies"
echo "  ✓ Fair comparison (apple-to-apple)"
echo "  ✓ Security differs at RUNTIME only"
echo ""

# Build image
echo -e "${BLUE}Building image: node-test-app:v1.0${NC}"
echo ""
docker build -t node-test-app:v1.0 .
echo ""
echo -e "${GREEN}✓ Image built successfully${NC}"
echo ""

# Show image info
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Image Information:${NC}"
echo -e "${CYAN}========================================${NC}"
docker images node-test-app:v1.0
echo ""

# Image size
IMAGE_SIZE=$(docker images node-test-app:v1.0 --format "{{.Size}}")
echo "Image Size: $IMAGE_SIZE (Alpine-based)"
echo ""

# Verify image contents
echo -e "${CYAN}Image Contents:${NC}"
docker run --rm node-test-app:v1.0 ls -lh /app
echo ""

echo -e "${GREEN}✓ Image ready for deployment!${NC}"
echo ""
echo "Next steps:"
echo "  1. Deploy baseline (no hardening):"
echo "     ./scripts/deploy-baseline.sh"
echo ""
echo "  2. Deploy hardened (full security):"
echo "     ./scripts/deploy-hardened.sh"
echo ""
echo "  3. Compare security:"
echo "     docker exec test-baseline whoami    # root"
echo "     docker exec test-hardened whoami    # appuser"
echo ""
echo -e "${CYAN}========================================${NC}"
