#!/bin/bash
#===============================================================================
# scribe-status.sh - Show Scribe Node status and health
# Scribe Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
CONFIG_DIR="${KINGDOM_HOME}/config"
DOCS_DIR="${KINGDOM_HOME}/docs"
KNOWLEDGE_DIR="${KINGDOM_HOME}/knowledge"
DOMAIN="${SCRIBE_DOMAIN:-scribe.kingdom.local}"

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

check_postgresql() {
    if sudo -u postgres psql -c "SELECT 1" &>/dev/null; then
        echo -e "${OK} PostgreSQL: connected"
        
        # Check scribe database
        if sudo -u postgres psql -lqt | cut -d \| -f 1 | grep -qw scribe_db; then
            local db_size=$(sudo -u postgres psql -d scribe_db -c "SELECT pg_size_pretty(pg_database_size('scribe_db'));" -t 2>/dev/null | xargs)
            echo -e "   ${INFO} scribe_db: ${db_size}"
        else
            echo -e "   ${WARN} scribe_db: not found"
        fi
    else
        echo -e "${ERR} PostgreSQL: not accessible"
    fi
}

count_documents() {
    local dir=$1
    local ext=$2
    find "$dir" -name "*.$ext" -type f 2>/dev/null | wc -l
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}📜 SCRIBE NODE STATUS${NC}                       ${PURPLE}║${NC}"
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
check_service "postgresql"
check_service "docker"
check_service "fail2ban"
check_service "node_exporter"
check_service "scribe-node"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "scribe-docs-api"
check_docker_container "scribe-search"
check_docker_container "scribe-processor"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 3000 "Docs API"
check_port 3001 "Search Service"
check_port 5432 "PostgreSQL"
check_port 9100 "Node Exporter"

#-------------------------------------------------------------------------------
# SSL Certificate
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔒 SSL Certificate${NC}"
echo "─────────────────────────────────────"
check_ssl "$DOMAIN"

#-------------------------------------------------------------------------------
# Database Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🗄️  Database Status${NC}"
echo "─────────────────────────────────────"
check_postgresql

#-------------------------------------------------------------------------------
# Documentation Storage
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📚 Documentation Storage${NC}"
echo "─────────────────────────────────────"
if [[ -d "$DOCS_DIR" ]]; then
    DOCS_SIZE=$(du -sh "$DOCS_DIR" 2>/dev/null | cut -f1)
    MD_COUNT=$(count_documents "$DOCS_DIR" "md")
    HTML_COUNT=$(count_documents "$DOCS_DIR" "html")
    PDF_COUNT=$(count_documents "$DOCS_DIR" "pdf")
    echo -e "   ${OK} Docs directory: ${DOCS_SIZE}"
    echo -e "   ${INFO} Markdown files: ${MD_COUNT}"
    echo -e "   ${INFO} HTML files: ${HTML_COUNT}"
    echo -e "   ${INFO} PDF files: ${PDF_COUNT}"
else
    echo -e "   ${INFO} Docs directory: not initialized"
fi

#-------------------------------------------------------------------------------
# Knowledge Base
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🧠 Knowledge Base${NC}"
echo "─────────────────────────────────────"
if [[ -d "$KNOWLEDGE_DIR" ]]; then
    KB_SIZE=$(du -sh "$KNOWLEDGE_DIR" 2>/dev/null | cut -f1)
    DOC_COUNT=$(find "${KNOWLEDGE_DIR}/documents" -type f 2>/dev/null | wc -l)
    echo -e "   ${OK} Knowledge base: ${KB_SIZE}"
    echo -e "   ${INFO} Documents: ${DOC_COUNT}"
    
    # Check search index
    if [[ -f "${KNOWLEDGE_DIR}/indexes/search.db" ]]; then
        INDEX_SIZE=$(du -sh "${KNOWLEDGE_DIR}/indexes/search.db" 2>/dev/null | cut -f1)
        echo -e "   ${OK} Search index: ${INDEX_SIZE}"
    else
        echo -e "   ${INFO} Search index: not built"
    fi
    
    # Check archives
    if [[ -d "${KNOWLEDGE_DIR}/archives" ]]; then
        ARCHIVE_COUNT=$(find "${KNOWLEDGE_DIR}/archives" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Archives: ${ARCHIVE_COUNT} files"
    fi
else
    echo -e "   ${INFO} Knowledge base: not initialized"
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
# Recent Documents
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📝 Recent Documents${NC}"
echo "─────────────────────────────────────"
if [[ -d "${DOCS_DIR}/source" ]]; then
    RECENT_DOCS=$(find "${DOCS_DIR}/source" -type f -name "*.md" -mtime -7 2>/dev/null | head -5)
    if [[ -n "$RECENT_DOCS" ]]; then
        echo "   Recently modified (last 7 days):"
        echo "$RECENT_DOCS" | while read doc; do
            echo -e "   - $(basename "$doc")"
        done
    else
        echo -e "   ${INFO} No recent documents"
    fi
else
    echo -e "   ${INFO} No source documents yet"
fi

#-------------------------------------------------------------------------------
# Content Statistics
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Content Statistics${NC}"
echo "─────────────────────────────────────"
if [[ -d "$DOCS_DIR" ]]; then
    # Count total words in markdown files
    TOTAL_WORDS=$(find "$DOCS_DIR" -name "*.md" -type f -exec cat {} \; 2>/dev/null | wc -w)
    echo -e "   ${INFO} Total words: ${TOTAL_WORDS}"
    
    # Count generated files
    if [[ -d "${DOCS_DIR}/generated" ]]; then
        GEN_COUNT=$(find "${DOCS_DIR}/generated" -type f 2>/dev/null | wc -l)
        echo -e "   ${INFO} Generated files: ${GEN_COUNT}"
    fi
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   pull-kingdom.sh    - Update Kingdom repo"
echo "   scribe-status.sh   - This status page"
echo "   status.sh          - General node status"
echo ""
echo "   Web:               https://${DOMAIN}"
echo "   Docs API:          http://localhost:3000"
echo "   Search:            http://localhost:3001"
echo "   Metrics:           http://localhost:9100"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Scribe Status Check Complete${NC}"
echo ""
