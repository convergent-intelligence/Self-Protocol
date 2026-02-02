#!/bin/bash
#===============================================================================
# status.sh - Show Guardian Node status and health
# Guardian Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
CONFIG_DIR="${KINGDOM_HOME}/config"
DOMAIN="mapyourmind.me"

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

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}🛡️  GUARDIAN NODE STATUS${NC}                      ${PURPLE}║${NC}"
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
check_service "nginx"
check_service "docker"
check_service "fail2ban"
check_service "guardian-node"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "guardian-api"
check_docker_container "self-viewer"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 3000 "OpenClaw API"
check_port 3001 "Self-Protocol Viewer"

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
        ufw status | grep -E "^(22|80|443)" | while read line; do
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
check_repo "Self-Protocol" "${REPOS_DIR}/Self-Protocol"
check_repo "OpenClaw" "${REPOS_DIR}/openclaw"

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
# Self-Protocol State
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔮 Self-Protocol State${NC}"
echo "─────────────────────────────────────"
SELF_REPO="${REPOS_DIR}/Self-Protocol"
if [[ -d "$SELF_REPO" ]]; then
    # Count interests
    if [[ -d "${SELF_REPO}/Interests" ]]; then
        INTEREST_COUNT=$(find "${SELF_REPO}/Interests" -name "*.md" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Interests: ${INTEREST_COUNT} tracked"
    fi
    
    # Count memories
    if [[ -d "${SELF_REPO}/Memory" ]]; then
        EXP_COUNT=$(find "${SELF_REPO}/Memory/experiences" -name "*.md" -type f 2>/dev/null | wc -l)
        KNOW_COUNT=$(find "${SELF_REPO}/Memory/knowledge" -name "*.md" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Experiences: ${EXP_COUNT} logged"
        echo -e "   ${INFO} Knowledge: ${KNOW_COUNT} entries"
    fi
    
    # Count relationships
    if [[ -d "${SELF_REPO}/Relationships" ]]; then
        REL_COUNT=$(find "${SELF_REPO}/Relationships" -name "*.md" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Relationships: ${REL_COUNT} mapped"
    fi
else
    echo -e "   ${WARN} Self-Protocol not initialized"
fi

#-------------------------------------------------------------------------------
# Recent Activity
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Recent Activity${NC}"
echo "─────────────────────────────────────"
if [[ -f "/var/log/kingdom/guardian.log" ]]; then
    echo "   Last 3 log entries:"
    tail -3 /var/log/kingdom/guardian.log 2>/dev/null | while read line; do
        echo -e "   ${line}"
    done
else
    echo -e "   ${INFO} No activity logs yet"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   pull-kingdom.sh    - Update Kingdom repo"
echo "   update-self.sh     - Update Self-Protocol"
echo "   sync-openclaw.sh   - Sync OpenClaw"
echo "   status.sh          - This status page"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Guardian Status Check Complete${NC}"
echo ""
