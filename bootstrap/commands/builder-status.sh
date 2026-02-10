#!/bin/bash
#===============================================================================
# builder-status.sh - Show Builder Node status and health
# Builder Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
BUILD_DIR="${KINGDOM_HOME}/builds"
REGISTRY_DIR="${KINGDOM_HOME}/registry"
ARTIFACTS_DIR="${KINGDOM_HOME}/artifacts"
DOMAIN="${BUILDER_DOMAIN:-builder.kingdom.local}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

# Status indicators
OK="${GREEN}●${NC}"
WARN="${YELLOW}●${NC}"
ERR="${RED}●${NC}"
INFO="${BLUE}●${NC}"

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------
check_service() {
    local service=$1
    if systemctl is-active --quiet "$service" 2>/dev/null; then
        echo -e "${OK} ${service}"
    else
        echo -e "${ERR} ${service} (not running)"
    fi
}

check_docker_container() {
    local container=$1
    if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        echo -e "${OK} ${container}"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        echo -e "${WARN} ${container} (stopped)"
    else
        echo -e "${INFO} ${container} (not created)"
    fi
}

check_port() {
    local port=$1
    local name=$2
    if ss -tlnp 2>/dev/null | grep -q ":${port} "; then
        echo -e "${OK} Port ${port} (${name})"
    else
        echo -e "${INFO} Port ${port} (${name}) - not listening"
    fi
}

check_endpoint() {
    local url=$1
    local name=$2
    if curl -sf --max-time 2 "$url" > /dev/null 2>&1; then
        echo -e "${OK} ${name}"
    else
        echo -e "${WARN} ${name} - not responding"
    fi
}

check_ssl() {
    local domain=$1
    if [[ -d "/etc/letsencrypt/live/${domain}" ]]; then
        local expiry=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${domain}/cert.pem" 2>/dev/null | cut -d= -f2)
        local expiry_epoch=$(date -d "$expiry" +%s 2>/dev/null || echo 0)
        local now_epoch=$(date +%s)
        local days_left=$(( (expiry_epoch - now_epoch) / 86400 ))
        
        if [[ $days_left -gt 30 ]]; then
            echo -e "${OK} SSL: Valid (${days_left} days remaining)"
        elif [[ $days_left -gt 0 ]]; then
            echo -e "${WARN} SSL: Expiring soon (${days_left} days)"
        else
            echo -e "${ERR} SSL: Expired or invalid"
        fi
    else
        echo -e "${WARN} SSL: Not configured"
    fi
}

check_language() {
    local name=$1
    local cmd=$2
    local version
    version=$($cmd 2>/dev/null | head -1) || version="not installed"
    echo -e "   ${INFO} ${name}: ${version}"
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${MAGENTA}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║${NC}                    ${BOLD}🔨 BUILDER NODE STATUS${NC}                      ${MAGENTA}║${NC}"
echo -e "${MAGENTA}║${NC}                      ${BLUE}${DOMAIN}${NC}                          ${MAGENTA}║${NC}"
echo -e "${MAGENTA}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BOLD}📅 Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${BOLD}⏱️  Uptime:${NC}    $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"

#-------------------------------------------------------------------------------
# System Services
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔧 System Services${NC}"
echo "─────────────────────────────────────"
check_service "nginx"
check_service "docker"
check_service "fail2ban"
check_service "builder-node"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "registry"
check_docker_container "registry-ui"
check_docker_container "ci-runner"
check_docker_container "node-exporter"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 5000 "Docker Registry"
check_port 8080 "CI Webhook"
check_port 8081 "Registry UI"
check_port 9100 "Node Exporter"

#-------------------------------------------------------------------------------
# Build Endpoints
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🏗️  Build Endpoints${NC}"
echo "─────────────────────────────────────"
check_endpoint "http://localhost:5000/v2/" "Docker Registry API"
check_endpoint "http://localhost:8081" "Registry UI"

#-------------------------------------------------------------------------------
# SSL Certificate
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔒 SSL Certificate${NC}"
echo "─────────────────────────────────────"
check_ssl "$DOMAIN"

#-------------------------------------------------------------------------------
# Firewall Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🛡️  Firewall (UFW)${NC}"
echo "─────────────────────────────────────"
if command -v ufw &> /dev/null; then
    UFW_STATUS=$(ufw status 2>/dev/null | head -1)
    if echo "$UFW_STATUS" | grep -q "active"; then
        echo -e "${OK} UFW: Active"
        ufw status | grep -E "^(22|80|443|5000|8080|9100)" | while read line; do
            echo -e "   ${line}"
        done
    else
        echo -e "${WARN} UFW: Inactive"
    fi
else
    echo -e "${INFO} UFW: Not installed"
fi

#-------------------------------------------------------------------------------
# Languages & Tools
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🛠️  Languages & Tools${NC}"
echo "─────────────────────────────────────"
check_language "Node.js" "node --version"
check_language "npm" "npm --version"
check_language "Rust" "rustc --version"
check_language "Cargo" "cargo --version"
check_language "Go" "go version"
check_language "Docker" "docker --version"
check_language "Docker Compose" "docker compose version"

#-------------------------------------------------------------------------------
# Docker Registry Stats
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📦 Docker Registry${NC}"
echo "─────────────────────────────────────"
if curl -sf "http://localhost:5000/v2/_catalog" > /dev/null 2>&1; then
    CATALOG=$(curl -sf "http://localhost:5000/v2/_catalog" 2>/dev/null)
    REPO_COUNT=$(echo "$CATALOG" | jq '.repositories | length' 2>/dev/null || echo "0")
    echo -e "   ${INFO} Repositories: ${REPO_COUNT}"
    
    if [[ "$REPO_COUNT" -gt 0 ]]; then
        echo "   Recent repositories:"
        echo "$CATALOG" | jq -r '.repositories[]' 2>/dev/null | head -5 | while read repo; do
            TAGS=$(curl -sf "http://localhost:5000/v2/${repo}/tags/list" 2>/dev/null | jq '.tags | length' 2>/dev/null || echo "0")
            echo -e "   - ${repo} (${TAGS} tags)"
        done
    fi
else
    echo -e "   ${INFO} Registry not accessible"
fi

#-------------------------------------------------------------------------------
# Build Workspace
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🏭 Build Workspace${NC}"
echo "─────────────────────────────────────"
if [[ -d "${BUILD_DIR}/workspace" ]]; then
    WORKSPACE_COUNT=$(find "${BUILD_DIR}/workspace" -maxdepth 1 -type d 2>/dev/null | wc -l)
    WORKSPACE_COUNT=$((WORKSPACE_COUNT - 1))
    echo -e "   ${INFO} Active workspaces: ${WORKSPACE_COUNT}"
fi

if [[ -d "${BUILD_DIR}/cache" ]]; then
    CACHE_SIZE=$(du -sh "${BUILD_DIR}/cache" 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Build cache: ${CACHE_SIZE}"
fi

#-------------------------------------------------------------------------------
# Artifacts
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📁 Artifacts${NC}"
echo "─────────────────────────────────────"
if [[ -d "${ARTIFACTS_DIR}" ]]; then
    ARTIFACTS_SIZE=$(du -sh "${ARTIFACTS_DIR}" 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Total size: ${ARTIFACTS_SIZE}"
    
    if [[ -d "${ARTIFACTS_DIR}/releases" ]]; then
        RELEASE_COUNT=$(find "${ARTIFACTS_DIR}/releases" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Releases: ${RELEASE_COUNT} files"
    fi
    
    if [[ -d "${ARTIFACTS_DIR}/snapshots" ]]; then
        SNAPSHOT_COUNT=$(find "${ARTIFACTS_DIR}/snapshots" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Snapshots: ${SNAPSHOT_COUNT} files"
    fi
fi

#-------------------------------------------------------------------------------
# Disk Usage
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}💾 Disk Usage${NC}"
echo "─────────────────────────────────────"
df -h / 2>/dev/null | tail -1 | awk '{
    used=$3; avail=$4; pct=$5;
    gsub(/%/, "", pct);
    if (pct > 90) color="\033[0;31m";
    else if (pct > 75) color="\033[1;33m";
    else color="\033[0;32m";
    printf "   Root: %s used, %s available (%s%s%%\033[0m)\n", used, avail, color, pct
}'

if [[ -d "${REGISTRY_DIR}/data" ]]; then
    REG_SIZE=$(du -sh "${REGISTRY_DIR}/data" 2>/dev/null | cut -f1)
    echo -e "   Registry Data: ${REG_SIZE}"
fi

# Docker disk usage
DOCKER_SIZE=$(docker system df --format "{{.Size}}" 2>/dev/null | head -1 || echo "unknown")
echo -e "   Docker Images: ${DOCKER_SIZE}"

#-------------------------------------------------------------------------------
# Memory Usage
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🧠 Memory Usage${NC}"
echo "─────────────────────────────────────"
free -h 2>/dev/null | awk '/^Mem:/ {
    total=$2; used=$3; avail=$7;
    printf "   Total: %s | Used: %s | Available: %s\n", total, used, avail
}'

#-------------------------------------------------------------------------------
# Recent Builds
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Recent Activity${NC}"
echo "─────────────────────────────────────"
if [[ -f "${KINGDOM_HOME}/logs/builds.log" ]]; then
    echo "   Last 3 builds:"
    tail -3 "${KINGDOM_HOME}/logs/builds.log" 2>/dev/null | while read line; do
        echo -e "   ${line}"
    done
else
    echo -e "   ${INFO} No build logs yet"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   builder-status.sh     - This status page"
echo "   build-docker.sh       - Build and push Docker images"
echo "   status.sh             - General node status"
echo "   docker logs registry  - View registry logs"

echo ""
echo -e "${MAGENTA}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Builder Status Check Complete${NC}"
echo ""
