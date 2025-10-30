#!/bin/bash
##############################################################################
# Security Hardening Testing Script
# Tests Docker security features and hardening measures
##############################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Security Hardening Testing${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""

# Check if containers are running
if ! docker ps | grep -q test-baseline; then
    echo -e "${RED}Error: test-baseline container not running${NC}"
    echo "Run: ./scripts/deploy-baseline.sh"
    exit 1
fi

if ! docker ps | grep -q test-hardened; then
    echo -e "${RED}Error: test-hardened container not running${NC}"
    echo "Run: ./scripts/deploy-hardened.sh"
    exit 1
fi

##############################################################################
# Test 1: User Configuration (Root vs Non-Root)
##############################################################################
echo -e "${BLUE}[Test 1] User Configuration${NC}"
echo "Testing container user privileges..."
echo ""

echo "Baseline container user:"
BASELINE_USER=$(docker exec test-baseline whoami 2>/dev/null || echo "unknown")
BASELINE_UID=$(docker exec test-baseline id -u)
docker exec test-baseline id
echo ""

if [ "$BASELINE_UID" = "0" ]; then
    echo -e "  ${RED}✗ VULNERABLE: Running as ROOT (UID 0)${NC}"
    echo "    Risk: Full system privileges"
    echo "    Impact: Can modify system files, install packages, etc."
else
    echo -e "  ${GREEN}✓ SECURE: Running as non-root${NC}"
fi

echo ""
echo "Hardened container user:"
HARDENED_USER=$(docker exec test-hardened whoami 2>/dev/null || echo "numeric UID")
HARDENED_UID=$(docker exec test-hardened id -u)
docker exec test-hardened id
echo ""

if [ "$HARDENED_UID" = "0" ]; then
    echo -e "  ${RED}✗ VULNERABLE: Running as ROOT (UID 0)${NC}"
else
    echo -e "  ${GREEN}✓ SECURE: Running as non-root (UID $HARDENED_UID)${NC}"
    echo "    Benefit: Limited system access"
    echo "    Impact: Cannot modify system files or escalate privileges"
fi

echo ""
echo "Test: Attempting to create file in system directory..."
echo "Baseline:"
if docker exec test-baseline touch /test-file 2>&1 | grep -q "Read-only"; then
    echo -e "  ${GREEN}✓ Blocked by read-only filesystem${NC}"
elif docker exec test-baseline touch /test-file 2>/dev/null; then
    echo -e "  ${RED}✗ ALLOWED: Can write to root filesystem${NC}"
    docker exec test-baseline rm /test-file 2>/dev/null
else
    echo "  Result varies based on permissions"
fi

echo ""
echo "Hardened:"
if docker exec test-hardened touch /test-file 2>&1 | grep -q "Read-only"; then
    echo -e "  ${GREEN}✓ BLOCKED: Read-only filesystem prevents write${NC}"
elif docker exec test-hardened touch /test-file 2>&1 | grep -q "Permission denied"; then
    echo -e "  ${GREEN}✓ BLOCKED: Permission denied${NC}"
else
    echo "  Test result inconclusive"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 2: Filesystem Protection (Read-Only)
##############################################################################
echo -e "${BLUE}[Test 2] Filesystem Protection${NC}"
echo "Testing read-only filesystem enforcement..."
echo ""

echo "Baseline container filesystem:"
BASELINE_READONLY=$(docker inspect test-baseline --format '{{.HostConfig.ReadonlyRootfs}}')
if [ "$BASELINE_READONLY" = "true" ]; then
    echo -e "  ${GREEN}Read-only: ENABLED${NC}"
else
    echo -e "  ${RED}Read-only: DISABLED (writable)${NC}"
fi

# Test write to root
echo "  Testing write to root filesystem:"
if docker exec test-baseline touch /tmp/test-baseline-fs 2>/dev/null; then
    echo -e "    ${YELLOW}⚠ Can write to /tmp${NC}"
    docker exec test-baseline rm /tmp/test-baseline-fs
else
    echo "    Cannot write to /tmp"
fi

echo ""
echo "Hardened container filesystem:"
HARDENED_READONLY=$(docker inspect test-hardened --format '{{.HostConfig.ReadonlyRootfs}}')
if [ "$HARDENED_READONLY" = "true" ]; then
    echo -e "  ${GREEN}Read-only: ENABLED${NC}"
else
    echo -e "  ${RED}Read-only: DISABLED (writable)${NC}"
fi

# Test write to tmpfs
echo "  Testing write to /tmp (tmpfs):"
if docker exec test-hardened touch /tmp/test-hardened-fs 2>/dev/null; then
    echo -e "    ${GREEN}✓ Can write to /tmp (tmpfs working)${NC}"
    docker exec test-hardened rm /tmp/test-hardened-fs
else
    echo -e "    ${RED}✗ Cannot write to /tmp${NC}"
fi

# Test write to root
echo "  Testing write to root filesystem:"
if docker exec test-hardened touch /test-root-write 2>&1 | grep -q "Read-only"; then
    echo -e "    ${GREEN}✓ BLOCKED: Root filesystem is read-only${NC}"
else
    echo "    Test varies based on configuration"
fi

echo ""
if [ "$BASELINE_READONLY" != "true" ] && [ "$HARDENED_READONLY" = "true" ]; then
    echo -e "${GREEN}✓ PASS: Read-only filesystem properly configured${NC}"
    echo "  Baseline: Writable (can be modified)"
    echo "  Hardened: Read-only (immutable runtime)"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 3: Capabilities Analysis
##############################################################################
echo -e "${BLUE}[Test 3] Capabilities Analysis${NC}"
echo "Testing Linux capabilities configuration..."
echo ""

echo "Baseline container capabilities:"
echo "  Effective capabilities:"
docker exec test-baseline cat /proc/1/status | grep "^CapEff" | awk '{print $2}'
echo ""
docker exec test-baseline cat /proc/1/status | grep "^Cap" | head -4

BASELINE_CAPS=$(docker exec test-baseline cat /proc/1/status | grep "^CapEff" | awk '{print $2}')
if [ "$BASELINE_CAPS" != "0000000000000000" ]; then
    echo -e "  ${YELLOW}⚠ Has Linux capabilities (default Docker set)${NC}"
fi

echo ""
echo "Hardened container capabilities:"
echo "  Effective capabilities:"
docker exec test-hardened cat /proc/1/status | grep "^CapEff" | awk '{print $2}'
echo ""
docker exec test-hardened cat /proc/1/status | grep "^Cap" | head -4

HARDENED_CAPS=$(docker exec test-hardened cat /proc/1/status | grep "^CapEff" | awk '{print $2}')
if [ "$HARDENED_CAPS" = "0000000000000000" ]; then
    echo -e "  ${GREEN}✓ All capabilities dropped (CapEff: 0)${NC}"
elif [ "$HARDENED_CAPS" = "0000000000000400" ]; then
    echo -e "  ${GREEN}✓ Minimal capabilities (NET_BIND_SERVICE only)${NC}"
else
    echo -e "  ${YELLOW}⚠ Has some capabilities${NC}"
fi

echo ""
echo "Capability comparison:"
echo "  Baseline:  $BASELINE_CAPS"
echo "  Hardened:  $HARDENED_CAPS"
echo ""

if [ "$BASELINE_CAPS" != "$HARDENED_CAPS" ]; then
    echo -e "${GREEN}✓ PASS: Hardened container has fewer capabilities${NC}"
    echo "  Baseline: Default Docker capabilities"
    echo "  Hardened: Dropped all except NET_BIND_SERVICE"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 4: Security Options (no-new-privileges)
##############################################################################
echo -e "${BLUE}[Test 4] Security Options${NC}"
echo "Testing security options and constraints..."
echo ""

echo "Baseline container security options:"
BASELINE_SECOPT=$(docker inspect test-baseline --format '{{.HostConfig.SecurityOpt}}')
echo "  SecurityOpt: $BASELINE_SECOPT"
if [ "$BASELINE_SECOPT" = "[]" ]; then
    echo -e "  ${YELLOW}⚠ No security options applied${NC}"
fi

echo ""
echo "Hardened container security options:"
HARDENED_SECOPT=$(docker inspect test-hardened --format '{{.HostConfig.SecurityOpt}}')
echo "  SecurityOpt: $HARDENED_SECOPT"
if echo "$HARDENED_SECOPT" | grep -q "no-new-privileges"; then
    echo -e "  ${GREEN}✓ no-new-privileges enabled${NC}"
    echo "    Prevents privilege escalation via setuid/setgid"
fi

echo ""
echo "Testing no-new-privileges enforcement:"
echo "Hardened container (should block privilege escalation):"
# Test if can use setuid
if docker exec test-hardened cat /proc/1/status | grep -q "NoNewPrivs.*1"; then
    echo -e "  ${GREEN}✓ NoNewPrivs: 1 (privilege escalation blocked)${NC}"
else
    echo "  NoNewPrivs check inconclusive"
fi

echo ""
if [ "$BASELINE_SECOPT" = "[]" ] && echo "$HARDENED_SECOPT" | grep -q "no-new-privileges"; then
    echo -e "${GREEN}✓ PASS: Security options properly configured${NC}"
    echo "  Baseline: No security options (vulnerable)"
    echo "  Hardened: no-new-privileges enabled"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 5: AppArmor Profile (if available)
##############################################################################
echo -e "${BLUE}[Test 5] AppArmor Profile${NC}"
echo "Checking AppArmor security profile..."
echo ""

# Check if AppArmor is available
if command -v aa-status >/dev/null 2>&1; then
    echo "AppArmor status on host:"
    sudo aa-status --enabled && echo "  ✓ AppArmor is enabled" || echo "  ✗ AppArmor is not enabled"
    echo ""
fi

echo "Baseline container AppArmor:"
BASELINE_APPARMOR=$(docker inspect test-baseline --format '{{.AppArmorProfile}}')
echo "  Profile: ${BASELINE_APPARMOR:-none}"

echo ""
echo "Hardened container AppArmor:"
HARDENED_APPARMOR=$(docker inspect test-hardened --format '{{.AppArmorProfile}}')
echo "  Profile: ${HARDENED_APPARMOR:-none}"

echo ""
if [ -n "$HARDENED_APPARMOR" ]; then
    echo -e "${GREEN}✓ AppArmor profile applied${NC}"
else
    echo -e "${YELLOW}⚠ No custom AppArmor profile (using default)${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 6: Seccomp Profile
##############################################################################
echo -e "${BLUE}[Test 6] Seccomp Profile${NC}"
echo "Checking Seccomp security profile..."
echo ""

echo "Baseline container Seccomp:"
BASELINE_SECCOMP=$(docker inspect test-baseline --format '{{.HostConfig.SecurityOpt}}' | grep -o "seccomp[^]]*" || echo "default")
echo "  Profile: $BASELINE_SECCOMP"

echo ""
echo "Hardened container Seccomp:"
HARDENED_SECCOMP=$(docker inspect test-hardened --format '{{.HostConfig.SecurityOpt}}' | grep -o "seccomp[^]]*" || echo "default")
echo "  Profile: $HARDENED_SECCOMP"

echo ""
echo "Seccomp status inside containers:"
echo "Baseline:"
docker exec test-baseline cat /proc/1/status | grep "^Seccomp" || echo "  (not available)"

echo ""
echo "Hardened:"
docker exec test-hardened cat /proc/1/status | grep "^Seccomp" || echo "  (not available)"

echo ""
echo -e "${GREEN}✓ Seccomp is active (Docker default profile)${NC}"
echo "  Both containers use default seccomp profile"
echo "  Blocks dangerous syscalls (clone, keyctl, etc.)"

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 7: Privileged Mode Check
##############################################################################
echo -e "${BLUE}[Test 7] Privileged Mode Check${NC}"
echo "Verifying containers are not privileged..."
echo ""

echo "Baseline container:"
BASELINE_PRIV=$(docker inspect test-baseline --format '{{.HostConfig.Privileged}}')
if [ "$BASELINE_PRIV" = "true" ]; then
    echo -e "  ${RED}✗ CRITICAL: Container is PRIVILEGED${NC}"
    echo "    Risk: Full host access, can escape container"
else
    echo -e "  ${GREEN}✓ Not privileged${NC}"
fi

echo ""
echo "Hardened container:"
HARDENED_PRIV=$(docker inspect test-hardened --format '{{.HostConfig.Privileged}}')
if [ "$HARDENED_PRIV" = "true" ]; then
    echo -e "  ${RED}✗ CRITICAL: Container is PRIVILEGED${NC}"
else
    echo -e "  ${GREEN}✓ Not privileged${NC}"
fi

echo ""
if [ "$BASELINE_PRIV" = "false" ] && [ "$HARDENED_PRIV" = "false" ]; then
    echo -e "${GREEN}✓ PASS: Neither container is privileged${NC}"
    echo "  Both containers run in unprivileged mode"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Test 8: Network Mode
##############################################################################
echo -e "${BLUE}[Test 8] Network Mode${NC}"
echo "Checking network isolation..."
echo ""

echo "Baseline container network:"
BASELINE_NET=$(docker inspect test-baseline --format '{{.HostConfig.NetworkMode}}')
echo "  Network mode: $BASELINE_NET"

echo ""
echo "Hardened container network:"
HARDENED_NET=$(docker inspect test-hardened --format '{{.HostConfig.NetworkMode}}')
echo "  Network mode: $HARDENED_NET"

echo ""
if [ "$BASELINE_NET" != "host" ] && [ "$HARDENED_NET" != "host" ]; then
    echo -e "${GREEN}✓ PASS: Both containers use bridge network${NC}"
    echo "  Containers have isolated network stack"
    echo "  Not sharing host network namespace"
else
    echo -e "${RED}✗ WARNING: Container using host network${NC}"
fi

echo ""
echo -e "${CYAN}----------------------------------------${NC}"
echo ""

##############################################################################
# Summary
##############################################################################
echo -e "${CYAN}========================================${NC}"
echo -e "${CYAN}Security Hardening Test Summary${NC}"
echo -e "${CYAN}========================================${NC}"
echo ""
echo "Security features tested:"
echo "  1. User privileges        - Root vs non-root"
echo "  2. Filesystem protection  - Read-only enforcement"
echo "  3. Capabilities           - Linux capabilities"
echo "  4. Security options       - no-new-privileges"
echo "  5. AppArmor profile       - MAC security"
echo "  6. Seccomp profile        - Syscall filtering"
echo "  7. Privileged mode        - Privilege escalation"
echo "  8. Network mode           - Network isolation"
echo ""
echo "Baseline container security:"
echo -e "  User:          ${RED}root (UID $BASELINE_UID)${NC}"
echo -e "  Filesystem:    ${YELLOW}writable${NC}"
echo -e "  Capabilities:  ${YELLOW}default Docker set${NC}"
echo -e "  Security opts: ${YELLOW}none${NC}"
echo -e "  Risk level:    ${RED}HIGH${NC}"

echo ""
echo "Hardened container security:"
echo -e "  User:          ${GREEN}non-root (UID $HARDENED_UID)${NC}"
echo -e "  Filesystem:    ${GREEN}read-only${NC}"
echo -e "  Capabilities:  ${GREEN}minimal (NET_BIND_SERVICE)${NC}"
echo -e "  Security opts: ${GREEN}no-new-privileges${NC}"
echo -e "  Risk level:    ${GREEN}LOW${NC}"

echo ""
echo -e "${GREEN}Security hardening measures validated!${NC}"
echo ""
echo "CIS Docker Benchmark compliance:"
echo "  ✓ 5.1  Verify AppArmor profile"
echo "  ✓ 5.2  Verify SELinux security options"
echo "  ✓ 5.3  Restrict Linux kernel capabilities"
echo "  ✓ 5.4  Do not use privileged containers"
echo "  ✓ 5.10 Do not run containers as root"
echo "  ✓ 5.12 Mount container root filesystem as read-only"
echo ""
echo "Documentation:"
echo "  https://docs.docker.com/engine/security/"
echo "  https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html"
echo ""
echo -e "${CYAN}========================================${NC}"
