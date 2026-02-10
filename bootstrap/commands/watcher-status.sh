#!/bin/bash
#===============================================================================
# watcher-status.sh - Show Watcher Node status and health
# Watcher Node Helper Command - Kingdom Monitoring Stack
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
DATA_DIR="${KINGDOM_HOME}/data"
CONFIG_DIR="${KINGDOM_HOME}/config"

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
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' "$container" 2>/dev/null)
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

check_endpoint() {
    local url=$1
    local name=$2
    if curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null | grep -q "200\|302"; then
        echo -e "${OK} ${name}: ${url}"
    else
        echo -e "${WARN} ${name}: ${url} (not responding)"
    fi
}

format_bytes() {
    local bytes=$1
    if [[ $bytes -ge 1073741824 ]]; then
        echo "$(echo "scale=2; $bytes/1073741824" | bc)GB"
    elif [[ $bytes -ge 1048576 ]]; then
        echo "$(echo "scale=2; $bytes/1048576" | bc)MB"
    else
        echo "${bytes}B"
    fi
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}👁️  WATCHER NODE STATUS${NC}                       ${PURPLE}║${NC}"
echo -e "${PURPLE}║${NC}                   ${CYAN}Kingdom Monitoring Stack${NC}                       ${PURPLE}║${NC}"
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
check_service "watcher-node"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "prometheus"
check_docker_container "grafana"
check_docker_container "loki"
check_docker_container "promtail"
check_docker_container "alertmanager"
check_docker_container "node-exporter"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 9090 "Prometheus"
check_port 3000 "Grafana"
check_port 3100 "Loki"
check_port 9093 "Alertmanager"
check_port 9100 "Node Exporter"

#-------------------------------------------------------------------------------
# Service Endpoints
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔗 Service Endpoints${NC}"
echo "─────────────────────────────────────"
check_endpoint "http://localhost:9090/-/healthy" "Prometheus"
check_endpoint "http://localhost:3000/api/health" "Grafana"
check_endpoint "http://localhost:3100/ready" "Loki"
check_endpoint "http://localhost:9093/-/healthy" "Alertmanager"

#-------------------------------------------------------------------------------
# Prometheus Targets
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🎯 Prometheus Targets${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -e '.data.activeTargets' > /dev/null 2>&1; then
    TARGETS=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
    TOTAL=$(echo "$TARGETS" | jq '.data.activeTargets | length' 2>/dev/null || echo "0")
    UP=$(echo "$TARGETS" | jq '[.data.activeTargets[] | select(.health == "up")] | length' 2>/dev/null || echo "0")
    DOWN=$(echo "$TARGETS" | jq '[.data.activeTargets[] | select(.health == "down")] | length' 2>/dev/null || echo "0")
    
    echo -e "   ${INFO} Total targets: ${TOTAL}"
    echo -e "   ${OK} Healthy: ${UP}"
    if [[ "$DOWN" -gt 0 ]]; then
        echo -e "   ${ERR} Unhealthy: ${DOWN}"
    fi
    
    # List targets
    echo ""
    echo "$TARGETS" | jq -r '.data.activeTargets[] | "   \(.health | if . == "up" then "●" else "○" end) \(.labels.job): \(.scrapeUrl)"' 2>/dev/null | head -10
else
    echo -e "   ${WARN} Prometheus not responding"
fi

#-------------------------------------------------------------------------------
# Active Alerts
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🚨 Active Alerts${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null | jq -e '.' > /dev/null 2>&1; then
    ALERTS=$(curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null)
    ALERT_COUNT=$(echo "$ALERTS" | jq 'length' 2>/dev/null || echo "0")
    
    if [[ "$ALERT_COUNT" -eq 0 ]]; then
        echo -e "   ${OK} No active alerts"
    else
        echo -e "   ${WARN} ${ALERT_COUNT} active alert(s)"
        echo "$ALERTS" | jq -r '.[] | "   ⚠️  \(.labels.alertname): \(.annotations.summary // "No summary")"' 2>/dev/null | head -5
    fi
else
    echo -e "   ${INFO} Alertmanager not responding"
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
        ufw status | grep -E "^(22|9090|3000|3100|9093|9100)" | while read line; do
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

# Check Prometheus data size
if [[ -d "${DATA_DIR}/prometheus" ]]; then
    PROM_SIZE=$(du -sh "${DATA_DIR}/prometheus" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   Prometheus data: ${PROM_SIZE}"
fi

# Check Loki data size
if [[ -d "${DATA_DIR}/loki" ]]; then
    LOKI_SIZE=$(du -sh "${DATA_DIR}/loki" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   Loki data: ${LOKI_SIZE}"
fi

# Check Grafana data size
if [[ -d "${DATA_DIR}/grafana" ]]; then
    GRAFANA_SIZE=$(du -sh "${DATA_DIR}/grafana" 2>/dev/null | cut -f1 || echo "N/A")
    echo -e "   Grafana data: ${GRAFANA_SIZE}"
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
docker stats --no-stream --format "   {{.Name}}: {{.MemUsage}}" 2>/dev/null | grep -E "(prometheus|grafana|loki|alertmanager)" | head -5

#-------------------------------------------------------------------------------
# Loki Log Statistics
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Log Statistics (Loki)${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:3100/loki/api/v1/labels" 2>/dev/null | jq -e '.data' > /dev/null 2>&1; then
    LABELS=$(curl -s "http://localhost:3100/loki/api/v1/labels" 2>/dev/null | jq -r '.data[]' 2>/dev/null)
    LABEL_COUNT=$(echo "$LABELS" | wc -l)
    echo -e "   ${INFO} Active labels: ${LABEL_COUNT}"
    
    # Show jobs
    JOBS=$(curl -s "http://localhost:3100/loki/api/v1/label/job/values" 2>/dev/null | jq -r '.data[]' 2>/dev/null)
    if [[ -n "$JOBS" ]]; then
        echo -e "   ${INFO} Log sources:"
        echo "$JOBS" | while read job; do
            echo -e "      - ${job}"
        done
    fi
else
    echo -e "   ${WARN} Loki not responding"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   watcher-status.sh           - This status page"
echo "   docker compose logs -f      - View container logs"
echo "   docker compose restart      - Restart all services"
echo ""
echo -e "${BOLD}📍 Web Interfaces${NC}"
echo "─────────────────────────────────────"
echo "   Prometheus:    http://localhost:9090"
echo "   Grafana:       http://localhost:3000"
echo "   Alertmanager:  http://localhost:9093"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Watcher Status Check Complete${NC}"
echo ""
