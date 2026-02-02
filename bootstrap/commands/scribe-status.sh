#!/bin/bash
#===============================================================================
# scribe-status.sh - Show Scribe Node status and health
# Scribe Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
DOCS_DIR="${KINGDOM_HOME}/docs"
KNOWLEDGE_DIR="${KINGDOM_HOME}/knowledge"
LOGS_DIR="${KINGDOM_HOME}/logs"
DATA_DIR="${KINGDOM_HOME}/data"
DOMAIN="${SCRIBE_DOMAIN:-scribe.kingdom.local}"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
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

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}📜 SCRIBE NODE STATUS${NC}                       ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}                      ${BLUE}${DOMAIN}${NC}                          ${PURPLE}║${NC}"
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
check_service "scribe-node"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "postgres"
check_docker_container "wikijs"
check_docker_container "mkdocs"
check_docker_container "knowledge-api"
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
check_port 3000 "Wiki.js"
check_port 3100 "Knowledge API"
check_port 8000 "MkDocs Dev"
check_port 9100 "Node Exporter"

#-------------------------------------------------------------------------------
# Documentation Endpoints
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📚 Documentation Endpoints${NC}"
echo "─────────────────────────────────────"
check_endpoint "http://localhost:3000" "Wiki.js"
check_endpoint "http://localhost:8000" "MkDocs"
check_endpoint "http://localhost:3100/health" "Knowledge API"

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
        ufw status | grep -E "^(22|80|443|3000|3100|9100)" | while read line; do
            echo -e "   ${line}"
        done
    else
        echo -e "${WARN} UFW: Inactive"
    fi
else
    echo -e "${INFO} UFW: Not installed"
fi

#-------------------------------------------------------------------------------
# Documentation Stats
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📖 Documentation${NC}"
echo "─────────────────────────────────────"
if [[ -d "${DOCS_DIR}/source" ]]; then
    DOC_COUNT=$(find "${DOCS_DIR}/source" -name "*.md" -type f 2>/dev/null | wc -l)
    echo -e "   ${INFO} Markdown files: ${DOC_COUNT}"
fi

if [[ -d "${DOCS_DIR}/site" ]]; then
    if [[ -f "${DOCS_DIR}/site/index.html" ]]; then
        echo -e "   ${OK} Static site: Built"
        SITE_SIZE=$(du -sh "${DOCS_DIR}/site" 2>/dev/null | cut -f1)
        echo -e "   ${INFO} Site size: ${SITE_SIZE}"
    else
        echo -e "   ${WARN} Static site: Not built"
    fi
fi

#-------------------------------------------------------------------------------
# Knowledge Base Stats
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🧠 Knowledge Base${NC}"
echo "─────────────────────────────────────"
if [[ -d "${KNOWLEDGE_DIR}" ]]; then
    if [[ -d "${KNOWLEDGE_DIR}/entries" ]]; then
        ENTRY_COUNT=$(find "${KNOWLEDGE_DIR}/entries" -name "*.md" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Knowledge entries: ${ENTRY_COUNT}"
    fi
    
    if [[ -d "${KNOWLEDGE_DIR}/archives" ]]; then
        ARCHIVE_COUNT=$(find "${KNOWLEDGE_DIR}/archives" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Archived items: ${ARCHIVE_COUNT}"
    fi
    
    KB_SIZE=$(du -sh "${KNOWLEDGE_DIR}" 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Total size: ${KB_SIZE}"
fi

#-------------------------------------------------------------------------------
# Logging Stats
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📝 Logging${NC}"
echo "─────────────────────────────────────"
if [[ -d "${LOGS_DIR}" ]]; then
    if [[ -d "${LOGS_DIR}/structured" ]]; then
        STRUCT_COUNT=$(find "${LOGS_DIR}/structured" -name "*.log" -type f 2>/dev/null | wc -l)
        STRUCT_SIZE=$(du -sh "${LOGS_DIR}/structured" 2>/dev/null | cut -f1)
        echo -e "   ${INFO} Structured logs: ${STRUCT_COUNT} files (${STRUCT_SIZE})"
    fi
    
    if [[ -d "${LOGS_DIR}/raw" ]]; then
        RAW_SIZE=$(du -sh "${LOGS_DIR}/raw" 2>/dev/null | cut -f1)
        echo -e "   ${INFO} Raw logs: ${RAW_SIZE}"
    fi
    
    TOTAL_LOG_SIZE=$(du -sh "${LOGS_DIR}" 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Total log storage: ${TOTAL_LOG_SIZE}"
fi

#-------------------------------------------------------------------------------
# Wiki.js Stats
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📰 Wiki.js${NC}"
echo "─────────────────────────────────────"
if curl -sf "http://localhost:3000" > /dev/null 2>&1; then
    echo -e "   ${OK} Wiki.js is running"
    if [[ -d "${DATA_DIR}/wikijs" ]]; then
        WIKI_SIZE=$(du -sh "${DATA_DIR}/wikijs" 2>/dev/null | cut -f1)
        echo -e "   ${INFO} Data size: ${WIKI_SIZE}"
    fi
else
    echo -e "   ${WARN} Wiki.js not accessible"
fi

#-------------------------------------------------------------------------------
# Database Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🗄️  Database${NC}"
echo "─────────────────────────────────────"
if docker ps --format '{{.Names}}' 2>/dev/null | grep -q "^postgres$"; then
    echo -e "   ${OK} PostgreSQL is running"
    if [[ -d "${DATA_DIR}/postgres" ]]; then
        DB_SIZE=$(du -sh "${DATA_DIR}/postgres" 2>/dev/null | cut -f1)
        echo -e "   ${INFO} Database size: ${DB_SIZE}"
    fi
else
    echo -e "   ${WARN} PostgreSQL not running"
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
# Recent Knowledge Entries
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Recent Activity${NC}"
echo "─────────────────────────────────────"
if [[ -d "${KNOWLEDGE_DIR}/entries" ]]; then
    RECENT=$(find "${KNOWLEDGE_DIR}/entries" -name "*.md" -type f -mtime -7 2>/dev/null | wc -l)
    echo -e "   ${INFO} Entries added this week: ${RECENT}"
    
    echo "   Recent entries:"
    find "${KNOWLEDGE_DIR}/entries" -name "*.md" -type f -printf '%T@ %p\n' 2>/dev/null | \
        sort -rn | head -3 | while read ts path; do
            name=$(basename "$path" .md)
            echo -e "   - ${name}"
        done
else
    echo -e "   ${INFO} No knowledge entries yet"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   scribe-status.sh     - This status page"
echo "   status.sh            - General node status"
echo "   docker logs wikijs   - View Wiki.js logs"
echo "   docker logs postgres - View database logs"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Scribe Status Check Complete${NC}"
echo -e "${PURPLE}\"What is written remains. What is remembered, lives.\"${NC}"
echo ""
