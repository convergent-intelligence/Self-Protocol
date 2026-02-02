#!/bin/bash
#===============================================================================
# scribe-status.sh - Show Scribe Node status and health
# Scribe Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
CONFIG_DIR="${KINGDOM_HOME}/config"
DATA_DIR="${KINGDOM_HOME}/data"
DOCS_DIR="${KINGDOM_HOME}/docs"
LOGS_DIR="${KINGDOM_HOME}/logs"
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

check_bookstack_health() {
    if curl -s "http://localhost:8080/status" 2>/dev/null | grep -qi "ok\|healthy"; then
        echo -e "${OK} BookStack: Healthy"
    elif curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/" 2>/dev/null | grep -q "200\|302"; then
        echo -e "${OK} BookStack: Responding"
    else
        echo -e "${INFO} BookStack: Not accessible"
    fi
}

check_log_receiver_health() {
    if curl -s -o /dev/null -w "%{http_code}" "http://localhost:8081/" 2>/dev/null | grep -q "200\|405"; then
        echo -e "${OK} Log Receiver: Running"
    else
        echo -e "${INFO} Log Receiver: Not accessible"
    fi
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}📜 SCRIBE NODE STATUS${NC}                        ${PURPLE}║${NC}"
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
check_docker_container "mariadb"
check_docker_container "bookstack"
check_docker_container "log-receiver"

#-------------------------------------------------------------------------------
# Scribe Stack Health
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📚 Scribe Stack Health${NC}"
echo "─────────────────────────────────────"
check_bookstack_health
check_log_receiver_health

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 8080 "BookStack"
check_port 8081 "Log Receiver"
check_port 3306 "MariaDB"

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
        ufw status | grep -E "^(22|80|443|8080)" | head -5 | while read line; do
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
echo -e "${BOLD}📖 Documentation Stats${NC}"
echo "─────────────────────────────────────"
if [[ -d "${DOCS_DIR}/static" ]]; then
    DOC_COUNT=$(find "${DOCS_DIR}/static" -name "*.md" -type f 2>/dev/null | wc -l)
    echo -e "   ${INFO} Static Docs: ${DOC_COUNT} markdown files"
fi

if [[ -d "${DOCS_DIR}/templates" ]]; then
    TEMPLATE_COUNT=$(find "${DOCS_DIR}/templates" -name "*.md" -type f 2>/dev/null | wc -l)
    echo -e "   ${INFO} Templates: ${TEMPLATE_COUNT} available"
fi

if [[ -d "${DOCS_DIR}/generated" ]]; then
    GEN_COUNT=$(find "${DOCS_DIR}/generated" -type f 2>/dev/null | wc -l)
    echo -e "   ${INFO} Generated: ${GEN_COUNT} files"
fi

#-------------------------------------------------------------------------------
# Log Statistics
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Log Statistics${NC}"
echo "─────────────────────────────────────"
if [[ -d "${LOGS_DIR}/kingdom" ]]; then
    # Count log files by node
    for node_dir in "${LOGS_DIR}/kingdom/"*/; do
        if [[ -d "$node_dir" ]]; then
            node_name=$(basename "$node_dir")
            log_count=$(find "$node_dir" -name "*.log" -type f 2>/dev/null | wc -l)
            if [[ "$log_count" -gt 0 ]]; then
                latest=$(ls -t "$node_dir"/*.log 2>/dev/null | head -1)
                latest_date=$(stat -c %y "$latest" 2>/dev/null | cut -d' ' -f1)
                echo -e "   ${INFO} ${node_name}: ${log_count} logs (latest: ${latest_date})"
            fi
        fi
    done
    
    TOTAL_LOGS=$(find "${LOGS_DIR}/kingdom" -name "*.log" -type f 2>/dev/null | wc -l)
    if [[ "$TOTAL_LOGS" -eq 0 ]]; then
        echo -e "   ${INFO} No logs received yet"
    fi
else
    echo -e "   ${INFO} Kingdom logs directory not found"
fi

if [[ -d "${LOGS_DIR}/archive" ]]; then
    ARCHIVE_COUNT=$(find "${LOGS_DIR}/archive" -name "*.log.gz" -type f 2>/dev/null | wc -l)
    ARCHIVE_SIZE=$(du -sh "${LOGS_DIR}/archive" 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Archived: ${ARCHIVE_COUNT} files (${ARCHIVE_SIZE})"
fi

#-------------------------------------------------------------------------------
# Recent Log Entries
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📝 Recent Log Entries${NC}"
echo "─────────────────────────────────────"
LATEST_LOG=$(find "${LOGS_DIR}/kingdom" -name "*.log" -type f 2>/dev/null | xargs ls -t 2>/dev/null | head -1)
if [[ -n "$LATEST_LOG" && -f "$LATEST_LOG" ]]; then
    echo "   From: $(basename $(dirname $LATEST_LOG))/$(basename $LATEST_LOG)"
    tail -3 "$LATEST_LOG" 2>/dev/null | while read line; do
        # Truncate long lines
        echo "   $(echo "$line" | cut -c1-60)..."
    done
else
    echo -e "   ${INFO} No recent log entries"
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

if [[ -d "${DATA_DIR}/bookstack" ]]; then
    BS_SIZE=$(du -sh "${DATA_DIR}/bookstack" 2>/dev/null | cut -f1)
    echo -e "   BookStack Data: ${BS_SIZE}"
fi

if [[ -d "${DATA_DIR}/mariadb" ]]; then
    DB_SIZE=$(du -sh "${DATA_DIR}/mariadb" 2>/dev/null | cut -f1)
    echo -e "   MariaDB Data: ${DB_SIZE}"
fi

if [[ -d "${LOGS_DIR}" ]]; then
    LOGS_SIZE=$(du -sh "${LOGS_DIR}" 2>/dev/null | cut -f1)
    echo -e "   Logs Total: ${LOGS_SIZE}"
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
# Database Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🗄️  Database Status${NC}"
echo "─────────────────────────────────────"
if docker exec mariadb mysqladmin ping -h localhost 2>/dev/null | grep -q "alive"; then
    echo -e "${OK} MariaDB: Responding to ping"
    
    # Get database size
    DB_SIZE=$(docker exec mariadb mysql -N -e "SELECT ROUND(SUM(data_length + index_length) / 1024 / 1024, 2) FROM information_schema.tables WHERE table_schema = 'bookstack';" 2>/dev/null || echo "N/A")
    echo -e "   ${INFO} BookStack DB Size: ${DB_SIZE} MB"
else
    echo -e "${INFO} MariaDB: Not accessible"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   scribe-status.sh   - This status page"
echo "   status.sh          - General node status"
echo ""
echo "   Wiki:         http://${DOMAIN}/wiki/"
echo "   Static Docs:  http://${DOMAIN}/docs/"
echo "   Logs:         http://${DOMAIN}/logs/"
echo ""
echo "   Generate PDF: docker compose run doc-generator pandoc input.md -o output.pdf"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Scribe Status Check Complete${NC}"
echo -e "${CYAN}\"The Scribe records all. The Kingdom remembers.\"${NC}"
echo ""
