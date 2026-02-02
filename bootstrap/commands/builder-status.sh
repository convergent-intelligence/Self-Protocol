#!/bin/bash
#===============================================================================
# builder-status.sh - Show Builder Node status and health
# Builder Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
CONFIG_DIR="${KINGDOM_HOME}/config"
ARTIFACTS_DIR="${KINGDOM_HOME}/artifacts"
WORKSPACE_DIR="${KINGDOM_HOME}/workspace"
DOMAIN="${BUILDER_DOMAIN:-builder.kingdom.local}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
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
        echo -e "${OK} ${container}"
    elif docker ps -a --format '{{.Names}}' 2>/dev/null | grep -q "^${container}$"; then
        echo -e "${WARN} ${container} (stopped)"
    else
        echo -e "${INFO} ${container} (not created)"
    fi
}

check_repo() {
    local name=$1
    local path=$2
    if [[ -d "$path/.git" ]]; then
        cd "$path"
        local branch=$(git branch --show-current 2>/dev/null || echo "detached")
        local commit=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
        local status=""
        if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
            status=" ${YELLOW}(modified)${NC}"
        fi
        echo -e "${OK} ${name}: ${branch}@${commit}${status}"
        cd - > /dev/null
    else
        echo -e "${ERR} ${name}: not found"
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

check_build_tool() {
    local tool=$1
    local version_cmd=$2
    if command -v "$tool" &> /dev/null; then
        local version=$(eval "$version_cmd" 2>/dev/null | head -1)
        echo -e "${OK} ${tool}: ${version}"
    else
        echo -e "${ERR} ${tool}: not installed"
    fi
}

check_registry_health() {
    local response=$(curl -s "http://localhost:5000/v2/" 2>/dev/null)
    if [[ "$response" == "{}" ]]; then
        echo -e "${OK} Registry: healthy"
    else
        echo -e "${WARN} Registry: not responding"
    fi
}

count_registry_images() {
    local catalog=$(curl -s "http://localhost:5000/v2/_catalog" 2>/dev/null)
    if [[ -n "$catalog" ]]; then
        local count=$(echo "$catalog" | jq -r '.repositories | length' 2>/dev/null || echo "0")
        echo -e "   ${INFO} Images: ${count} repositories"
    fi
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}🔨 BUILDER NODE STATUS${NC}                      ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}                      ${CYAN}${DOMAIN}${NC}                          ${PURPLE}║${NC}"
echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════╝${NC}"

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
check_service "node_exporter"
check_service "builder-node"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "builder-registry"
check_docker_container "builder-api"
check_docker_container "builder-runner"

#-------------------------------------------------------------------------------
# Build Tools
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🛠️  Build Tools${NC}"
echo "─────────────────────────────────────"
check_build_tool "node" "node --version"
check_build_tool "npm" "npm --version"
check_build_tool "rustc" "rustc --version"
check_build_tool "cargo" "cargo --version"
check_build_tool "docker" "docker --version | cut -d' ' -f3 | tr -d ','"
check_build_tool "make" "make --version | head -1"
check_build_tool "gcc" "gcc --version | head -1"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 8080 "Build API"
check_port 5000 "Docker Registry"
check_port 9100 "Node Exporter"

#-------------------------------------------------------------------------------
# Docker Registry Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📦 Docker Registry${NC}"
echo "─────────────────────────────────────"
check_registry_health
count_registry_images

# Registry storage
if [[ -d /var/lib/docker/volumes ]]; then
    REGISTRY_SIZE=$(docker system df 2>/dev/null | grep "Local Volumes" | awk '{print $3}' || echo "unknown")
    echo -e "   ${INFO} Volume storage: ${REGISTRY_SIZE}"
fi

#-------------------------------------------------------------------------------
# Build Workspace
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🏗️  Build Workspace${NC}"
echo "─────────────────────────────────────"
if [[ -d "$WORKSPACE_DIR" ]]; then
    WORKSPACE_SIZE=$(du -sh "$WORKSPACE_DIR" 2>/dev/null | cut -f1)
    WORKSPACE_COUNT=$(find "$WORKSPACE_DIR" -maxdepth 1 -type d 2>/dev/null | wc -l)
    echo -e "   ${OK} Workspace: ${WORKSPACE_SIZE} (${WORKSPACE_COUNT} projects)"
else
    echo -e "   ${INFO} Workspace: not initialized"
fi

if [[ -d "$ARTIFACTS_DIR" ]]; then
    ARTIFACTS_SIZE=$(du -sh "$ARTIFACTS_DIR" 2>/dev/null | cut -f1)
    ARTIFACTS_COUNT=$(find "$ARTIFACTS_DIR" -type f 2>/dev/null | wc -l)
    echo -e "   ${OK} Artifacts: ${ARTIFACTS_SIZE} (${ARTIFACTS_COUNT} files)"
else
    echo -e "   ${INFO} Artifacts: not initialized"
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
        ufw status | grep -E "^(22|8080|5000|9100)" | while read line; do
            echo -e "   ${line}"
        done
    else
        echo -e "${WARN} UFW: Inactive"
    fi
else
    echo -e "${INFO} UFW: Not installed"
fi

#-------------------------------------------------------------------------------
# Repository Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📦 Repositories${NC}"
echo "─────────────────────────────────────"
check_repo "Kingdom" "${REPOS_DIR}/Kingdom"

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

if [[ -d "$KINGDOM_HOME" ]]; then
    KINGDOM_SIZE=$(du -sh "$KINGDOM_HOME" 2>/dev/null | cut -f1)
    echo -e "   Kingdom: ${KINGDOM_SIZE}"
fi

# Docker disk usage
DOCKER_USAGE=$(docker system df 2>/dev/null | tail -n +2 | awk '{printf "   %s: %s\n", $1, $3}')
if [[ -n "$DOCKER_USAGE" ]]; then
    echo -e "   Docker:"
    echo "$DOCKER_USAGE"
fi

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
echo -e "${BOLD}📋 Recent Activity${NC}"
echo "─────────────────────────────────────"
PIPELINE_LOG="${KINGDOM_HOME}/pipeline/logs"
if [[ -d "$PIPELINE_LOG" ]]; then
    RECENT_LOGS=$(ls -t "$PIPELINE_LOG"/*.log 2>/dev/null | head -5)
    if [[ -n "$RECENT_LOGS" ]]; then
        echo "   Recent build logs:"
        echo "$RECENT_LOGS" | while read log; do
            echo -e "   - $(basename "$log")"
        done
    else
        echo -e "   ${INFO} No build logs yet"
    fi
else
    echo -e "   ${INFO} No build logs yet"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   pull-kingdom.sh     - Update Kingdom repo"
echo "   builder-status.sh   - This status page"
echo "   status.sh           - General node status"
echo ""
echo "   Build API:          http://localhost:8080"
echo "   Registry:           http://localhost:5000"
echo "   Metrics:            http://localhost:9100"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Builder Status Check Complete${NC}"
echo ""
