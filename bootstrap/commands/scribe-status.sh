#!/bin/bash
#===============================================================================
# scribe-status.sh - Show Scribe Node status and health
# Scribe Node Helper Command - Kingdom Documentation Stack
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
DATA_DIR="${KINGDOM_HOME}/data"
CONFIG_DIR="${KINGDOM_HOME}/config"
DOCS_DIR="${KINGDOM_HOME}/docs"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
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
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null)
        if [[ "$health" == "healthy" ]] || [[ "$health" == "no-healthcheck" ]]; then
            echo -e "${OK} ${container} (${status})"
        else
            echo -e "${WARN} ${container} (${status}, ${health})"
        fi
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

count_files() {
    local dir=$1
    local pattern=${2:-"*"}
    find "$dir" -type f -name "$pattern" 2>/dev/null | wc -l
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    ${BOLD}📜 SCRIBE NODE STATUS${NC}                         ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                  ${BLUE}Kingdom Documentation Stack${NC}                     ${CYAN}║${NC}"
echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════╝${NC}"

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
check_service "scribe-node"
check_service "wiki-backup.timer"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "postgres"
check_docker_container "wikijs"
check_docker_container "nginx"
check_docker_container "node-exporter"
check_docker_container "promtail"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 80 "HTTP (Nginx)"
check_port 443 "HTTPS"
check_port 3000 "Wiki.js"
check_port 9100 "Node Exporter"
check_port 9080 "Promtail"

#-------------------------------------------------------------------------------
# Wiki.js Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📚 Wiki.js Status${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:3000/healthz" 2>/dev/null | grep -q "ok"; then
    echo -e "${OK} Wiki.js: Healthy"
    
    # Check if setup is complete
    SETUP_CHECK=$(curl -s "http://localhost:3000/" 2>/dev/null)
    if echo "$SETUP_CHECK" | grep -q "setup\|installation\|configure" -i; then
        echo -e "   ${WARN} First-run setup may be required"
    else
        echo -e "   ${OK} Wiki is operational"
    fi
elif curl -s -o /dev/null -w "%{http_code}" "http://localhost:3000/" 2>/dev/null | grep -q "200\|302"; then
    echo -e "${OK} Wiki.js: Responding"
else
    echo -e "${WARN} Wiki.js: Not responding"
fi

# Database status
echo ""
echo -e "   ${BOLD}Database:${NC}"
if docker exec postgres pg_isready -U wikijs -d wiki 2>/dev/null | grep -q "accepting"; then
    echo -e "   ${OK} PostgreSQL: Accepting connections"
    
    # Get database size
    DB_SIZE=$(docker exec postgres psql -U wikijs -d wiki -t -c "SELECT pg_size_pretty(pg_database_size('wiki'));" 2>/dev/null | tr -d ' ')
    if [[ -n "$DB_SIZE" ]]; then
        echo -e "   ${INFO} Database size: ${DB_SIZE}"
    fi
else
    echo -e "   ${WARN} PostgreSQL: Not ready"
fi

#-------------------------------------------------------------------------------
# Documentation Statistics
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Documentation Statistics${NC}"
echo "─────────────────────────────────────"
if [[ -d "${DOCS_DIR}" ]]; then
    TOTAL_DOCS=$(count_files "${DOCS_DIR}" "*.md")
    echo -e "   ${INFO} Total markdown files: ${TOTAL_DOCS}"
    
    if [[ -d "${DOCS_DIR}/kingdom" ]]; then
        KINGDOM_DOCS=$(count_files "${DOCS_DIR}/kingdom" "*.md")
        echo -e "   ${INFO} Kingdom docs: ${KINGDOM_DOCS}"
    fi
    
    if [[ -d "${DOCS_DIR}/protocols" ]]; then
        PROTOCOL_DOCS=$(count_files "${DOCS_DIR}/protocols" "*.md")
        echo -e "   ${INFO} Protocol docs: ${PROTOCOL_DOCS}"
    fi
    
    if [[ -d "${DOCS_DIR}/archives" ]]; then
        ARCHIVE_DOCS=$(count_files "${DOCS_DIR}/archives" "*.md")
        echo -e "   ${INFO} Archived docs: ${ARCHIVE_DOCS}"
    fi
    
    DOCS_SIZE=$(du -sh "${DOCS_DIR}" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   ${INFO} Total size: ${DOCS_SIZE}"
else
    echo -e "   ${INFO} Documentation directory not found"
fi

#-------------------------------------------------------------------------------
# Backup Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}💾 Backup Status${NC}"
echo "─────────────────────────────────────"
BACKUP_DIR="${DATA_DIR}/backups"
if [[ -d "$BACKUP_DIR" ]]; then
    BACKUP_COUNT=$(find "$BACKUP_DIR" -name "wiki_backup_*.tar.gz" -type f 2>/dev/null | wc -l)
    echo -e "   ${INFO} Total backups: ${BACKUP_COUNT}"
    
    # Latest backup
    LATEST_BACKUP=$(ls -t "$BACKUP_DIR"/wiki_backup_*.tar.gz 2>/dev/null | head -1)
    if [[ -n "$LATEST_BACKUP" ]]; then
        BACKUP_NAME=$(basename "$LATEST_BACKUP")
        BACKUP_SIZE=$(ls -lh "$LATEST_BACKUP" 2>/dev/null | awk '{print $5}')
        BACKUP_DATE=$(stat -c %y "$LATEST_BACKUP" 2>/dev/null | cut -d' ' -f1)
        echo -e "   ${OK} Latest: ${BACKUP_NAME}"
        echo -e "      Size: ${BACKUP_SIZE}, Date: ${BACKUP_DATE}"
    else
        echo -e "   ${WARN} No backups found"
    fi
    
    # Backup timer status
    NEXT_BACKUP=$(systemctl list-timers wiki-backup.timer 2>/dev/null | grep wiki-backup | awk '{print $1, $2}')
    if [[ -n "$NEXT_BACKUP" ]]; then
        echo -e "   ${INFO} Next backup: ${NEXT_BACKUP}"
    fi
else
    echo -e "   ${INFO} Backup directory not found"
fi

#-------------------------------------------------------------------------------
# Log Shipping Status (Promtail)
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📤 Log Shipping (Promtail)${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:9080/ready" 2>/dev/null | grep -q "Ready"; then
    echo -e "${OK} Promtail: Ready"
    
    # Check targets
    TARGETS=$(curl -s "http://localhost:9080/targets" 2>/dev/null)
    if [[ -n "$TARGETS" ]]; then
        TARGET_COUNT=$(echo "$TARGETS" | grep -c "state.*ready" 2>/dev/null || echo "0")
        echo -e "   ${INFO} Active targets: ${TARGET_COUNT}"
    fi
else
    echo -e "${WARN} Promtail: Not ready"
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
        ufw status | grep -E "^(22|80|443|3000|9100|9080)" | while read line; do
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

# Wiki.js data size
if [[ -d "${DATA_DIR}/wikijs" ]]; then
    WIKI_SIZE=$(du -sh "${DATA_DIR}/wikijs" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   Wiki.js data: ${WIKI_SIZE}"
fi

# PostgreSQL data size
if [[ -d "${DATA_DIR}/postgres" ]]; then
    PG_SIZE=$(du -sh "${DATA_DIR}/postgres" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   PostgreSQL data: ${PG_SIZE}"
fi

# Backups size
if [[ -d "${DATA_DIR}/backups" ]]; then
    BACKUP_SIZE=$(du -sh "${DATA_DIR}/backups" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   Backups: ${BACKUP_SIZE}"
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

# Container memory usage
echo ""
echo -e "   ${BOLD}Container Memory:${NC}"
docker stats --no-stream --format "   {{.Name}}: {{.MemUsage}}" 2>/dev/null | grep -E "(postgres|wikijs|nginx)" | head -5

#-------------------------------------------------------------------------------
# Recent Wiki Activity
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📝 Recent Activity${NC}"
echo "─────────────────────────────────────"
if [[ -d "${DATA_DIR}/wikijs/logs" ]]; then
    LATEST_LOG=$(ls -t "${DATA_DIR}/wikijs/logs"/*.log 2>/dev/null | head -1)
    if [[ -n "$LATEST_LOG" ]]; then
        echo "   Last 3 log entries:"
        tail -3 "$LATEST_LOG" 2>/dev/null | while read line; do
            echo -e "   ${line}" | cut -c1-70
        done
    else
        echo -e "   ${INFO} No wiki logs found"
    fi
else
    echo -e "   ${INFO} Wiki log directory not found"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   scribe-status.sh            - This status page"
echo "   backup-wiki.sh              - Create wiki backup"
echo "   docker compose logs -f      - View container logs"
echo "   docker compose restart      - Restart all services"
echo ""
echo -e "${BOLD}📍 Web Interfaces${NC}"
echo "─────────────────────────────────────"
echo "   Wiki.js:       http://localhost:3000"
echo "   Via Nginx:     http://localhost:80"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Scribe Status Check Complete${NC}"
echo ""
