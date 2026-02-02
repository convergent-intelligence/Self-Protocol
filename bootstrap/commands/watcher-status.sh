#!/bin/bash
#===============================================================================
# watcher-status.sh - Show Watcher Node status and health
# Watcher Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
CONFIG_DIR="${KINGDOM_HOME}/config"
DATA_DIR="${KINGDOM_HOME}/data"
DOMAIN="${WATCHER_DOMAIN:-watcher.kingdom.local}"

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
        local health=$(docker inspect --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no healthcheck{{end}}' "$container" 2>/dev/null)
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

check_prometheus_targets() {
    if curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq -e '.status == "success"' > /dev/null 2>&1; then
        local total=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq '.data.activeTargets | length')
        local up=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null | jq '[.data.activeTargets[] | select(.health == "up")] | length')
        echo -e "${OK} Prometheus: ${up}/${total} targets up"
    else
        echo -e "${INFO} Prometheus: API not accessible"
    fi
}

check_grafana_health() {
    if curl -s "http://localhost:3000/api/health" 2>/dev/null | jq -e '.database == "ok"' > /dev/null 2>&1; then
        echo -e "${OK} Grafana: Healthy"
    else
        echo -e "${INFO} Grafana: API not accessible"
    fi
}

check_loki_health() {
    if curl -s "http://localhost:3100/ready" 2>/dev/null | grep -q "ready"; then
        echo -e "${OK} Loki: Ready"
    else
        echo -e "${INFO} Loki: Not ready"
    fi
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                    ${BOLD}👁️  WATCHER NODE STATUS${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}║${NC}                      ${BLUE}${DOMAIN}${NC}                          ${CYAN}║${NC}"
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
check_service "nginx"
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
# Monitoring Stack Health
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Monitoring Stack Health${NC}"
echo "─────────────────────────────────────"
check_prometheus_targets
check_grafana_health
check_loki_health

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 80 "HTTP"
check_port 443 "HTTPS"
check_port 9090 "Prometheus"
check_port 3000 "Grafana"
check_port 3100 "Loki"
check_port 9093 "Alertmanager"
check_port 9100 "Node Exporter"

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
        ufw status | grep -E "^(22|80|443|9090|3000|3100|9093)" | head -5 | while read line; do
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

if [[ -d "${DATA_DIR}/prometheus" ]]; then
    PROM_SIZE=$(du -sh "${DATA_DIR}/prometheus" 2>/dev/null | cut -f1)
    echo -e "   Prometheus Data: ${PROM_SIZE}"
fi

if [[ -d "${DATA_DIR}/loki" ]]; then
    LOKI_SIZE=$(du -sh "${DATA_DIR}/loki" 2>/dev/null | cut -f1)
    echo -e "   Loki Data: ${LOKI_SIZE}"
fi

if [[ -d "${DATA_DIR}/grafana" ]]; then
    GRAFANA_SIZE=$(du -sh "${DATA_DIR}/grafana" 2>/dev/null | cut -f1)
    echo -e "   Grafana Data: ${GRAFANA_SIZE}"
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
# Active Alerts
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🚨 Active Alerts${NC}"
echo "─────────────────────────────────────"
if curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null | jq -e 'length > 0' > /dev/null 2>&1; then
    ALERT_COUNT=$(curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null | jq 'length')
    echo -e "${WARN} ${ALERT_COUNT} active alert(s)"
    curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null | jq -r '.[0:3][] | "   - \(.labels.alertname): \(.annotations.summary // "No summary")"' 2>/dev/null || true
else
    echo -e "${OK} No active alerts"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   watcher-status.sh    - This status page"
echo "   status.sh            - General node status"
echo ""
echo "   Grafana:      http://${DOMAIN}/grafana/"
echo "   Prometheus:   http://${DOMAIN}/prometheus/"
echo "   Alertmanager: http://${DOMAIN}/alertmanager/"

echo ""
echo -e "${CYAN}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Watcher Status Check Complete${NC}"
echo ""
