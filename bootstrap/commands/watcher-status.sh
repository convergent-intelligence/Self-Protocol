#!/bin/bash
#===============================================================================
# watcher-status.sh - Show Watcher Node status and health
# Watcher Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
CONFIG_DIR="${KINGDOM_HOME}/config"
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

check_prometheus_targets() {
    local status=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
    if [[ -n "$status" ]]; then
        local up_count=$(echo "$status" | jq -r '.data.activeTargets | map(select(.health == "up")) | length' 2>/dev/null || echo "0")
        local down_count=$(echo "$status" | jq -r '.data.activeTargets | map(select(.health == "down")) | length' 2>/dev/null || echo "0")
        local total=$((up_count + down_count))
        
        if [[ $down_count -eq 0 ]]; then
            echo -e "${OK} Targets: ${up_count}/${total} healthy"
        else
            echo -e "${WARN} Targets: ${up_count}/${total} healthy (${down_count} down)"
        fi
    else
        echo -e "${INFO} Prometheus API not accessible"
    fi
}

check_alertmanager_alerts() {
    local alerts=$(curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null)
    if [[ -n "$alerts" ]]; then
        local alert_count=$(echo "$alerts" | jq -r 'length' 2>/dev/null || echo "0")
        if [[ $alert_count -eq 0 ]]; then
            echo -e "${OK} No active alerts"
        else
            echo -e "${WARN} ${alert_count} active alert(s)"
        fi
    else
        echo -e "${INFO} Alertmanager API not accessible"
    fi
}

#-------------------------------------------------------------------------------
# Main Status Display
#-------------------------------------------------------------------------------
clear 2>/dev/null || true

echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║${NC}                    ${BOLD}👁️  WATCHER NODE STATUS${NC}                      ${PURPLE}║${NC}"
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
check_service "prometheus"
check_service "grafana-server"
check_service "docker"
check_service "fail2ban"
check_service "watcher-node"

#-------------------------------------------------------------------------------
# Monitoring Services
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📊 Monitoring Services${NC}"
echo "─────────────────────────────────────"
check_service "alertmanager"
check_service "node_exporter"

#-------------------------------------------------------------------------------
# Docker Containers
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🐳 Docker Containers${NC}"
echo "─────────────────────────────────────"
check_docker_container "watcher-dashboard"
check_docker_container "watcher-loki"

#-------------------------------------------------------------------------------
# Network Ports
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🌐 Network Ports${NC}"
echo "─────────────────────────────────────"
check_port 22 "SSH"
check_port 9090 "Prometheus"
check_port 3000 "Grafana"
check_port 9093 "Alertmanager"
check_port 9100 "Node Exporter"
check_port 3100 "Loki"

#-------------------------------------------------------------------------------
# Prometheus Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}📈 Prometheus Status${NC}"
echo "─────────────────────────────────────"
check_prometheus_targets

# Check Prometheus storage
if [[ -d /var/lib/prometheus ]]; then
    PROM_SIZE=$(du -sh /var/lib/prometheus 2>/dev/null | cut -f1)
    echo -e "   ${INFO} Storage: ${PROM_SIZE}"
fi

#-------------------------------------------------------------------------------
# Alertmanager Status
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🚨 Alertmanager Status${NC}"
echo "─────────────────────────────────────"
check_alertmanager_alerts

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
        ufw status | grep -E "^(22|9090|3000|9093|9100)" | while read line; do
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
# Monitored Nodes Summary
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🔍 Monitored Nodes${NC}"
echo "─────────────────────────────────────"
# Try to get target info from Prometheus
TARGETS=$(curl -s "http://localhost:9090/api/v1/targets" 2>/dev/null)
if [[ -n "$TARGETS" ]]; then
    echo "$TARGETS" | jq -r '.data.activeTargets[] | "   \(.labels.job): \(.labels.instance) [\(.health)]"' 2>/dev/null | head -10 || echo -e "   ${INFO} No targets configured"
else
    echo -e "   ${INFO} Prometheus not accessible"
fi

#-------------------------------------------------------------------------------
# Recent Alerts
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}🚨 Recent Alerts${NC}"
echo "─────────────────────────────────────"
ALERTS=$(curl -s "http://localhost:9093/api/v2/alerts" 2>/dev/null)
if [[ -n "$ALERTS" ]] && [[ $(echo "$ALERTS" | jq -r 'length' 2>/dev/null) -gt 0 ]]; then
    echo "$ALERTS" | jq -r '.[:5][] | "   [\(.labels.severity)] \(.labels.alertname): \(.annotations.summary // "No summary")"' 2>/dev/null || echo -e "   ${OK} No active alerts"
else
    echo -e "   ${OK} No active alerts"
fi

#-------------------------------------------------------------------------------
# Quick Commands
#-------------------------------------------------------------------------------
echo ""
echo -e "${BOLD}⚡ Quick Commands${NC}"
echo "─────────────────────────────────────"
echo "   pull-kingdom.sh     - Update Kingdom repo"
echo "   watcher-status.sh   - This status page"
echo "   status.sh           - General node status"
echo ""
echo "   Prometheus UI:      http://localhost:9090"
echo "   Grafana UI:         http://localhost:3000"
echo "   Alertmanager UI:    http://localhost:9093"

echo ""
echo -e "${PURPLE}════════════════════════════════════════════════════════════════════${NC}"
echo -e "${BOLD}Watcher Status Check Complete${NC}"
echo ""
