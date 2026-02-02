#!/bin/bash
#===============================================================================
# builder-status.sh - Show Builder Node status and health
# Builder Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
CONFIG_DIR="${KINGDOM_HOME}/config"
DATA_DIR="${KINGDOM_HOME}/data"
ARTIFACTS_DIR="${KINGDOM_HOME}/artifacts"
BUILDS_DIR="${KINGDOM_HOME}/builds"
DOMAIN="${BUILDER_DOMAIN:-builder.kingdom.local}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
ORANGE='\033[0;33m'
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

check_registry_health() {
    if curl -s "http://localhost:5000/v2/" 2>/dev/null | grep -q "{}"; then
        echo -e "${OK} Registry: Healthy"
    else
        echo -e "${INFO} Registry: Not accessible"
    fi
}

count_registry_images() {
    local count=$(curl -s "http://localhost:5000/v2/_catalog" 2>/dev/null | jq -r '.repositories | length' 2>/dev/null || echo "0")
    echo "$count"
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${ORANGE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${ORANGE}║${NC}                    ${BOLD}🔨 BUILDER NODE STATUS${NC}                       ${ORANGE}║${NC}"
echo -e "${ORANGE}║${NC}                      ${BLUE}${DOMAIN}${NC}                          ${ORANGE}║${NC}"
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
check_docker_container "webhook"
check_docker_container "runner"

#-------------------------------------------------------------------------------
# Builder Stack Health
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🏗️  Builder Stack Health${NC}"
echo "─────────────────────────────────────"
check_registry_health
IMAGE_COUNT=$(count_registry_images)
echo -e "${INFO} Registry Images: ${IMAGE_COUNT}"

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
check_port 5001 "Registry UI"
check_port 8080 "CI Runner"
check_port 9000 "Webhook"

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
        ufw status | grep -E "^(22|80|443|5000|5001|8080|9000)" | head -5 | while read line; do
            echo -e "   ${line}"
        done
    else
        echo -e "${WARN} UFW: Inactive"
    fi
else
    echo -e "${INFO} UFW: Not installed"
fi

#-------------------------------------------------------------------------------
# Registry Images
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📦 Registry Images${NC}"
echo "─────────────────────────────────────"
if [[ "$IMAGE_COUNT" -gt 0 ]]; then
    curl -s "http://localhost:5000/v2/_catalog" 2>/dev/null | jq -r '.repositories[]' 2>/dev/null | head -5 | while read repo; do
        TAGS=$(curl -s "http://localhost:5000/v2/${repo}/tags/list" 2>/dev/null | jq -r '.tags | length' 2>/dev/null || echo "0")
        echo -e "   ${INFO} ${repo} (${TAGS} tags)"
    done
    if [[ "$IMAGE_COUNT" -gt 5 ]]; then
        echo -e "   ... and $((IMAGE_COUNT - 5)) more"
    fi
else
    echo -e "   ${INFO} No images in registry"
fi

#-------------------------------------------------------------------------------
# Recent Builds
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔄 Recent Builds${NC}"
echo "─────────────────────────────────────"
if [[ -d "${BUILDS_DIR}/logs" ]]; then
    BUILD_COUNT=$(find "${BUILDS_DIR}/logs" -name "*.log" -type f 2>/dev/null | wc -l)
    if [[ "$BUILD_COUNT" -gt 0 ]]; then
        echo -e "   ${INFO} ${BUILD_COUNT} build log(s) found"
        echo "   Recent:"
        ls -lt "${BUILDS_DIR}/logs/"*.log 2>/dev/null | head -3 | while read line; do
            filename=$(echo "$line" | awk '{print $NF}')
            basename "$filename"
        done | while read name; do
            echo -e "   - ${name}"
        done
    else
        echo -e "   ${INFO} No build logs yet"
    fi
else
    echo -e "   ${INFO} Build logs directory not found"
fi

#-------------------------------------------------------------------------------
# Artifacts
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📁 Artifacts${NC}"
echo "─────────────────────────────────────"
if [[ -d "${ARTIFACTS_DIR}" ]]; then
    RELEASE_COUNT=$(find "${ARTIFACTS_DIR}/releases" -type f 2>/dev/null | wc -l)
    SNAPSHOT_COUNT=$(find "${ARTIFACTS_DIR}/snapshots" -type f 2>/dev/null | wc -l)
    ARTIFACTS_SIZE=$(du -sh "${ARTIFACTS_DIR}" 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Releases: ${RELEASE_COUNT} files"
    echo -e "   ${INFO} Snapshots: ${SNAPSHOT_COUNT} files"
    echo -e "   ${INFO} Total Size: ${ARTIFACTS_SIZE}"
else
    echo -e "   ${INFO} Artifacts directory not found"
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

if [[ -d "${DATA_DIR}/registry" ]]; then
    REG_SIZE=$(du -sh "${DATA_DIR}/registry" 2>/dev/null | cut -f1)
    echo -e "   Registry Data: ${REG_SIZE}"
fi

# Docker disk usage
DOCKER_SIZE=$(docker system df --format '{{.Size}}' 2>/dev/null | head -1 || echo "N/A")
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
# Build Tools
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🛠️  Build Tools${NC}"
echo "─────────────────────────────────────"
if command -v node &> /dev/null; then
    echo -e "   ${OK} Node.js: $(node --version)"
else
    echo -e "   ${INFO} Node.js: Not installed"
fi

if command -v rustc &> /dev/null; then
    echo -e "   ${OK} Rust: $(rustc --version | awk '{print $2}')"
else
    echo -e "   ${INFO} Rust: Not installed"
fi

if command -v docker &> /dev/null; then
    echo -e "   ${OK} Docker: $(docker --version | awk '{print $3}' | tr -d ',')"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   builder-status.sh   - This status page"
echo "   status.sh           - General node status"
echo ""
echo "   Registry UI:  http://${DOMAIN}/registry/"
echo "   Artifacts:    http://${DOMAIN}/artifacts/"
echo ""
echo "   Docker login: docker login localhost:5000"

echo ""
echo -e "${ORANGE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Builder Status Check Complete${NC}"
echo ""
