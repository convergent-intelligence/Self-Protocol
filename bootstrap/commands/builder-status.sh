#!/bin/bash
#===============================================================================
# builder-status.sh - Show Builder Node status and health
# Builder Node Helper Command - Kingdom CI/CD Stack
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
DATA_DIR="${KINGDOM_HOME}/data"
CONFIG_DIR="${KINGDOM_HOME}/config"
BUILDS_DIR="${KINGDOM_HOME}/builds"
ARTIFACTS_DIR="${KINGDOM_HOME}/artifacts"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
ORANGE='\033[0;33m'
CYAN='\033[0;36m'
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
        local status=$(docker inspect --format='{{.State.Status}}' "$container" 2>/dev/null)
        echo -e "${OK} ${container} (${status})"
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

check_tool() {
    local tool=$1
    local version_cmd=$2
    if command -v "$tool" &> /dev/null; then
        local version=$(eval "$version_cmd" 2>/dev/null || echo "unknown")
        echo -e "${OK} ${tool}: ${version}"
    else
        echo -e "${INFO} ${tool}: not installed"
    fi
}

format_size() {
    local size=$1
    if [[ $size -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $size/1073741824" | bc)GB"
    elif [[ $size -ge 1048576 ]]; then
        echo "$(echo "scale=2; $size/1048576" | bc)MB"
    elif [[ $size -ge 1024 ]]; then
        echo "$(echo "scale=2; $size/1024" | bc)KB"
    else
        echo "${size}B"
    fi
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${ORANGE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${ORANGE}║${NC}                    ${BOLD}🔨 BUILDER NODE STATUS${NC}                        ${ORANGE}║${NC}"
echo -e "${ORANGE}║${NC}                     ${CYAN}Kingdom CI/CD Stack${NC}                          ${ORANGE}║${NC}"
echo -e "${ORANGE}╚══════════════════════════════════════════════════════════════════╝${NC}"

echo ""
echo -e "${BOLD}📅 Timestamp:${NC} $(date '+%Y-%m-%d %H:%M:%S %Z')"
echo -e "${BOLD}⏱️  Uptime:${NC}    $(uptime -p 2>/dev/null || uptime | awk -F'up ' '{print $2}' | awk -F',' '{print $1}')"

#-------------------------------------------------------------------------------
# System Services
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔧 System Services${NC}"
echo "─────────────────────────────────────"
check_service "docker"
check_service "fail2ban"
check_service "builder-node"
check_service "builder-cleanup.timer"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "registry"
check_docker_container "registry-ui"
check_docker_container "gitea"
check_docker_container "node-exporter"
check_docker_container "watchtower"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 5000 "Docker Registry"
check_port 8080 "Registry UI"
check_port 3000 "Gitea"
check_port 2222 "Gitea SSH"
check_port 9100 "Node Exporter"

#-------------------------------------------------------------------------------
# Build Tools
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🛠️  Build Tools${NC}"
echo "─────────────────────────────────────"
check_tool "docker" "docker --version | cut -d' ' -f3 | tr -d ','"
check_tool "node" "node --version"
check_tool "npm" "npm --version"
check_tool "yarn" "yarn --version"
check_tool "pnpm" "pnpm --version"
check_tool "rustc" "rustc --version | cut -d' ' -f2"
check_tool "cargo" "cargo --version | cut -d' ' -f2"
check_tool "gcc" "gcc --version | head -1 | awk '{print \$NF}'"
check_tool "make" "make --version | head -1 | awk '{print \$NF}'"

#-------------------------------------------------------------------------------
# Docker Registry Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📦 Docker Registry${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:5000/v2/" 2>/dev/null | grep -q "{}"; then
    echo -e "${OK} Registry API: Healthy"
    
    # Get catalog
    CATALOG=$(curl -s "http://localhost:5000/v2/_catalog" 2>/dev/null)
    if echo "$CATALOG" | jq -e '.repositories' > /dev/null 2>&1; then
        REPO_COUNT=$(echo "$CATALOG" | jq '.repositories | length' 2>/dev/null || echo "0")
        echo -e "   ${INFO} Repositories: ${REPO_COUNT}"
        
        if [[ "$REPO_COUNT" -gt 0 ]]; then
            echo ""
            echo -e "   ${BOLD}Images:${NC}"
            echo "$CATALOG" | jq -r '.repositories[]' 2>/dev/null | while read repo; do
                TAGS=$(curl -s "http://localhost:5000/v2/${repo}/tags/list" 2>/dev/null | jq -r '.tags | length' 2>/dev/null || echo "0")
                echo -e "      - ${repo} (${TAGS} tags)"
            done | head -10
        fi
    fi
else
    echo -e "${WARN} Registry API: Not responding"
fi

#-------------------------------------------------------------------------------
# Gitea Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📚 Gitea Git Server${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:3000/api/v1/version" 2>/dev/null | jq -e '.version' > /dev/null 2>&1; then
    VERSION=$(curl -s "http://localhost:3000/api/v1/version" 2>/dev/null | jq -r '.version' 2>/dev/null)
    echo -e "${OK} Gitea: v${VERSION}"
    
    # Check if setup is complete
    if curl -s "http://localhost:3000/" 2>/dev/null | grep -q "Installation"; then
        echo -e "   ${WARN} First-run setup required"
    else
        echo -e "   ${OK} Setup complete"
    fi
else
    echo -e "${INFO} Gitea: Not responding (may need setup)"
fi

#-------------------------------------------------------------------------------
# Build Workspace
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🏗️  Build Workspace${NC}"
echo "─────────────────────────────────────"
if [[ -d "${BUILDS_DIR}/workspace" ]]; then
    BUILD_COUNT=$(find "${BUILDS_DIR}/workspace" -maxdepth 1 -type d 2>/dev/null | wc -l)
    BUILD_COUNT=$((BUILD_COUNT - 1))  # Subtract the workspace dir itself
    WORKSPACE_SIZE=$(du -sh "${BUILDS_DIR}/workspace" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   ${INFO} Active builds: ${BUILD_COUNT}"
    echo -e "   ${INFO} Workspace size: ${WORKSPACE_SIZE}"
    
    # Show recent builds
    if [[ $BUILD_COUNT -gt 0 ]]; then
        echo ""
        echo -e "   ${BOLD}Recent builds:${NC}"
        ls -lt "${BUILDS_DIR}/workspace" 2>/dev/null | head -6 | tail -5 | while read line; do
            echo -e "      ${line}"
        done
    fi
else
    echo -e "   ${INFO} No build workspace found"
fi

if [[ -d "${BUILDS_DIR}/cache" ]]; then
    CACHE_SIZE=$(du -sh "${BUILDS_DIR}/cache" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   ${INFO} Cache size: ${CACHE_SIZE}"
fi

#-------------------------------------------------------------------------------
# Artifacts
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📁 Artifacts${NC}"
echo "─────────────────────────────────────"
if [[ -d "${ARTIFACTS_DIR}" ]]; then
    TOTAL_SIZE=$(du -sh "${ARTIFACTS_DIR}" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   ${INFO} Total artifacts: ${TOTAL_SIZE}"
    
    if [[ -d "${ARTIFACTS_DIR}/images" ]]; then
        IMG_COUNT=$(find "${ARTIFACTS_DIR}/images" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Images: ${IMG_COUNT}"
    fi
    
    if [[ -d "${ARTIFACTS_DIR}/binaries" ]]; then
        BIN_COUNT=$(find "${ARTIFACTS_DIR}/binaries" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Binaries: ${BIN_COUNT}"
    fi
    
    if [[ -d "${ARTIFACTS_DIR}/packages" ]]; then
        PKG_COUNT=$(find "${ARTIFACTS_DIR}/packages" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Packages: ${PKG_COUNT}"
    fi
else
    echo -e "   ${INFO} No artifacts directory found"
fi

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
        ufw status | grep -E "^(22|5000|8080|3000|2222|9100)" | while read line; do
            echo -e "   ${line}"
        done
    else
        echo -e "${WARN} UFW: Inactive"
    fi
else
    echo -e "${INFO} UFW: Not installed"
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

# Docker disk usage
echo ""
echo -e "   ${BOLD}Docker Disk Usage:${NC}"
docker system df 2>/dev/null | tail -n +2 | while read line; do
    echo -e "      ${line}"
done

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

# Container memory usage
echo ""
echo -e "   ${BOLD}Container Memory:${NC}"
docker stats --no-stream --format "   {{.Name}}: {{.MemUsage}}" 2>/dev/null | grep -E "(registry|gitea)" | head -5

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   builder-status.sh           - This status page"
echo "   docker compose logs -f      - View container logs"
echo "   docker compose restart      - Restart all services"
echo "   docker system prune -f      - Clean up Docker"
echo ""
echo -e "${BOLD}📍 Web Interfaces${NC}"
echo "─────────────────────────────────────"
echo "   Registry UI:   http://localhost:8080"
echo "   Gitea:         http://localhost:3000"
echo ""
echo -e "${BOLD}🔐 Registry Credentials${NC}"
echo "─────────────────────────────────────"
echo "   Username: kingdom"
echo "   Password: (see ${CONFIG_DIR}/registry/htpasswd)"

echo ""
echo -e "${ORANGE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Builder Status Check Complete${NC}"
echo ""
