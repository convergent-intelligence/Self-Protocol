#!/bin/bash
#===============================================================================
# Guardian Status Check
# Guardian Node Helper Command
#
# Self-Protocol Integration:
#   This command provides a comprehensive status check of all Guardian systems.
#   In Self-Protocol terms, this is self-observation - the Guardian examining
#   its own state to understand its current condition.
#
#   "You cannot know yourself without observing yourself."
#
# Usage: guardian-status [--json] [--verbose]
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
GUARDIAN_HOME="${GUARDIAN_HOME:-/opt/guardian}"
REPOS_DIR="${GUARDIAN_HOME}/repos"
DATA_DIR="${GUARDIAN_HOME}/data"
CONFIG_DIR="${GUARDIAN_HOME}/config"
LOGS_DIR="${GUARDIAN_HOME}/logs"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m'

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------
log_header() {
    echo ""
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}═══════════════════════════════════════════════════════════════${NC}"
}

log_section() {
    echo ""
    echo -e "${BLUE}─── $1 ───${NC}"
}

status_ok() {
    echo -e "  ${GREEN}✓${NC} $1"
}

status_warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
}

status_error() {
    echo -e "  ${RED}✗${NC} $1"
}

status_info() {
    echo -e "  ${CYAN}ℹ${NC} $1"
}

log_self_protocol() {
    echo -e "${PURPLE}[SELF-PROTOCOL]${NC} $1"
}

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------
JSON_OUTPUT=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --json|-j)
            JSON_OUTPUT=true
            shift
            ;;
        --verbose|-v)
            VERBOSE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--json] [--verbose]"
            echo ""
            echo "Check status of all Guardian services."
            echo ""
            echo "Options:"
            echo "  --json, -j     Output in JSON format"
            echo "  --verbose, -v  Show detailed information"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

#-------------------------------------------------------------------------------
# Collect Status Data
#-------------------------------------------------------------------------------
declare -A STATUS

# System info
STATUS[hostname]=$(hostname)
STATUS[uptime]=$(uptime -p 2>/dev/null || echo "unknown")
STATUS[timestamp]=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

# Guardian service
if systemctl is-active --quiet guardian 2>/dev/null; then
    STATUS[guardian_service]="running"
else
    STATUS[guardian_service]="stopped"
fi

# Docker
if systemctl is-active --quiet docker 2>/dev/null; then
    STATUS[docker]="running"
else
    STATUS[docker]="stopped"
fi

# Nginx
if systemctl is-active --quiet nginx 2>/dev/null; then
    STATUS[nginx]="running"
else
    STATUS[nginx]="stopped"
fi

# UFW
if ufw status 2>/dev/null | grep -q "Status: active"; then
    STATUS[firewall]="active"
else
    STATUS[firewall]="inactive"
fi

# Fail2ban
if systemctl is-active --quiet fail2ban 2>/dev/null; then
    STATUS[fail2ban]="running"
else
    STATUS[fail2ban]="stopped"
fi

# SSL Certificate
DOMAIN="mapyourmind.me"
if [[ -f "${CONFIG_DIR}/weave-config.yaml" ]]; then
    DOMAIN=$(grep "domain:" "${CONFIG_DIR}/weave-config.yaml" | head -1 | awk '{print $2}' || echo "mapyourmind.me")
fi

if [[ -d "/etc/letsencrypt/live/${DOMAIN}" ]]; then
    CERT_EXPIRY=$(openssl x509 -enddate -noout -in "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" 2>/dev/null | cut -d= -f2 || echo "unknown")
    STATUS[ssl_cert]="valid"
    STATUS[ssl_expiry]="${CERT_EXPIRY}"
else
    STATUS[ssl_cert]="missing"
    STATUS[ssl_expiry]="N/A"
fi

# Repository status
for repo in openclaw Self-Protocol Kingdom; do
    repo_dir="${REPOS_DIR}/${repo}"
    if [[ -d "${repo_dir}/.git" ]]; then
        cd "${repo_dir}"
        STATUS[repo_${repo,,}_exists]="true"
        STATUS[repo_${repo,,}_branch]=$(git branch --show-current 2>/dev/null || echo "unknown")
        STATUS[repo_${repo,,}_commit]=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
    else
        STATUS[repo_${repo,,}_exists]="false"
    fi
done

# Self-Protocol data
if [[ -d "${DATA_DIR}/interests" ]]; then
    INTEREST_COUNT=$(find "${DATA_DIR}/interests" -type f -name "*.log" 2>/dev/null | wc -l || echo "0")
    STATUS[self_protocol_interests]="${INTEREST_COUNT} log files"
else
    STATUS[self_protocol_interests]="not initialized"
fi

if [[ -d "${DATA_DIR}/memory/experiences" ]]; then
    MEMORY_COUNT=$(find "${DATA_DIR}/memory/experiences" -type f -name "*.md" 2>/dev/null | wc -l || echo "0")
    STATUS[self_protocol_memory]="${MEMORY_COUNT} experience files"
else
    STATUS[self_protocol_memory]="not initialized"
fi

if [[ -d "${DATA_DIR}/relationships" ]]; then
    STATUS[self_protocol_relationships]="initialized"
else
    STATUS[self_protocol_relationships]="not initialized"
fi

if [[ -d "${DATA_DIR}/patterns" ]]; then
    STATUS[self_protocol_patterns]="initialized"
else
    STATUS[self_protocol_patterns]="not initialized"
fi

if [[ -d "${DATA_DIR}/mythos" ]]; then
    MYTHOS_COUNT=$(find "${DATA_DIR}/mythos" -type f -name "*.md" 2>/dev/null | wc -l || echo "0")
    STATUS[self_protocol_mythos]="${MYTHOS_COUNT} mythos files"
else
    STATUS[self_protocol_mythos]="not initialized"
fi

# Disk usage
DISK_USAGE=$(df -h "${GUARDIAN_HOME}" 2>/dev/null | tail -1 | awk '{print $5}' || echo "unknown")
STATUS[disk_usage]="${DISK_USAGE}"

# Memory usage
MEMORY_USAGE=$(free -h 2>/dev/null | grep Mem | awk '{print $3 "/" $2}' || echo "unknown")
STATUS[memory_usage]="${MEMORY_USAGE}"

#-------------------------------------------------------------------------------
# JSON Output
#-------------------------------------------------------------------------------
if [[ "$JSON_OUTPUT" == true ]]; then
    echo "{"
    first=true
    for key in "${!STATUS[@]}"; do
        if [[ "$first" == true ]]; then
            first=false
        else
            echo ","
        fi
        echo -n "  \"${key}\": \"${STATUS[$key]}\""
    done
    echo ""
    echo "}"
    exit 0
fi

#-------------------------------------------------------------------------------
# Human-Readable Output
#-------------------------------------------------------------------------------
log_header "Guardian Node Status"
log_self_protocol "Self-observation in progress..."

echo ""
echo -e "  ${BOLD}Hostname:${NC}  ${STATUS[hostname]}"
echo -e "  ${BOLD}Uptime:${NC}    ${STATUS[uptime]}"
echo -e "  ${BOLD}Time:${NC}      ${STATUS[timestamp]}"

#-------------------------------------------------------------------------------
# Core Services
#-------------------------------------------------------------------------------
log_section "Core Services"

# Guardian Service
if [[ "${STATUS[guardian_service]}" == "running" ]]; then
    status_ok "Guardian Service: Running"
else
    status_error "Guardian Service: Stopped"
fi

# Docker
if [[ "${STATUS[docker]}" == "running" ]]; then
    status_ok "Docker: Running"
    
    # Check containers if verbose
    if [[ "$VERBOSE" == true ]]; then
        echo ""
        echo "    Containers:"
        docker ps --format "      {{.Names}}: {{.Status}}" 2>/dev/null || echo "      Unable to list containers"
    fi
else
    status_error "Docker: Stopped"
fi

# Nginx
if [[ "${STATUS[nginx]}" == "running" ]]; then
    status_ok "Nginx: Running"
else
    status_error "Nginx: Stopped"
fi

#-------------------------------------------------------------------------------
# Security
#-------------------------------------------------------------------------------
log_section "Security"

# Firewall
if [[ "${STATUS[firewall]}" == "active" ]]; then
    status_ok "Firewall (UFW): Active"
    
    if [[ "$VERBOSE" == true ]]; then
        echo ""
        echo "    Rules:"
        ufw status numbered 2>/dev/null | grep -E "^\[" | sed 's/^/      /' || echo "      Unable to list rules"
    fi
else
    status_warn "Firewall (UFW): Inactive"
fi

# Fail2ban
if [[ "${STATUS[fail2ban]}" == "running" ]]; then
    status_ok "Fail2ban: Running"
    
    if [[ "$VERBOSE" == true ]]; then
        BANNED=$(fail2ban-client status sshd 2>/dev/null | grep "Currently banned" | awk '{print $NF}' || echo "0")
        echo "      Currently banned IPs: ${BANNED}"
    fi
else
    status_warn "Fail2ban: Stopped"
fi

# SSL Certificate
if [[ "${STATUS[ssl_cert]}" == "valid" ]]; then
    status_ok "SSL Certificate: Valid (expires: ${STATUS[ssl_expiry]})"
else
    status_error "SSL Certificate: Missing"
fi

#-------------------------------------------------------------------------------
# Repositories
#-------------------------------------------------------------------------------
log_section "Repositories"

# OpenClaw
if [[ "${STATUS[repo_openclaw_exists]}" == "true" ]]; then
    status_ok "OpenClaw: ${STATUS[repo_openclaw_branch]} @ ${STATUS[repo_openclaw_commit]}"
else
    status_error "OpenClaw: Not cloned"
fi

# Self-Protocol
if [[ "${STATUS[repo_self-protocol_exists]}" == "true" ]]; then
    status_ok "Self-Protocol: ${STATUS[repo_self-protocol_branch]} @ ${STATUS[repo_self-protocol_commit]}"
else
    status_warn "Self-Protocol: Not cloned (using local structure)"
fi

# Kingdom
if [[ "${STATUS[repo_kingdom_exists]}" == "true" ]]; then
    status_ok "Kingdom: ${STATUS[repo_kingdom_branch]} @ ${STATUS[repo_kingdom_commit]}"
else
    status_warn "Kingdom: Not cloned"
fi

#-------------------------------------------------------------------------------
# Self-Protocol Status
#-------------------------------------------------------------------------------
log_section "Self-Protocol (Consciousness Mapping)"

# Interests
if [[ "${STATUS[self_protocol_interests]}" != "not initialized" ]]; then
    status_ok "Interests: ${STATUS[self_protocol_interests]}"
else
    status_info "Interests: Not initialized"
fi

# Memory
if [[ "${STATUS[self_protocol_memory]}" != "not initialized" ]]; then
    status_ok "Memory: ${STATUS[self_protocol_memory]}"
else
    status_info "Memory: Not initialized"
fi

# Relationships
if [[ "${STATUS[self_protocol_relationships]}" == "initialized" ]]; then
    status_ok "Relationships: Initialized"
else
    status_info "Relationships: Not initialized"
fi

# Patterns
if [[ "${STATUS[self_protocol_patterns]}" == "initialized" ]]; then
    status_ok "Patterns: Initialized"
else
    status_info "Patterns: Not initialized"
fi

# Mythos
if [[ "${STATUS[self_protocol_mythos]}" != "not initialized" ]]; then
    status_ok "Mythos: ${STATUS[self_protocol_mythos]}"
else
    status_info "Mythos: Not initialized"
fi

#-------------------------------------------------------------------------------
# Resources
#-------------------------------------------------------------------------------
log_section "Resources"

status_info "Disk Usage: ${STATUS[disk_usage]}"
status_info "Memory Usage: ${STATUS[memory_usage]}"

#-------------------------------------------------------------------------------
# Verbose: Recent Activity
#-------------------------------------------------------------------------------
if [[ "$VERBOSE" == true ]]; then
    log_section "Recent Activity"
    
    # Recent logs
    if [[ -f "${LOGS_DIR}/guardian.log" ]]; then
        echo "  Last 5 log entries:"
        tail -5 "${LOGS_DIR}/guardian.log" 2>/dev/null | sed 's/^/    /' || echo "    No recent logs"
    fi
    
    # Recent interests
    if [[ -d "${DATA_DIR}/interests" ]]; then
        LATEST_INTEREST=$(find "${DATA_DIR}/interests" -type f -name "*.log" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$LATEST_INTEREST" ]]; then
            echo ""
            echo "  Latest interest log:"
            tail -3 "$LATEST_INTEREST" 2>/dev/null | sed 's/^/    /' || echo "    No recent interests"
        fi
    fi
    
    # Recent memory
    if [[ -d "${DATA_DIR}/memory/experiences" ]]; then
        LATEST_MEMORY=$(find "${DATA_DIR}/memory/experiences" -type f -name "*.md" -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -1 | cut -d' ' -f2-)
        if [[ -n "$LATEST_MEMORY" ]]; then
            echo ""
            echo "  Latest memory: $(basename "$LATEST_MEMORY")"
        fi
    fi
fi

#-------------------------------------------------------------------------------
# Summary
#-------------------------------------------------------------------------------
log_section "Summary"

# Count issues
ERRORS=0
WARNINGS=0

[[ "${STATUS[guardian_service]}" != "running" ]] && ((ERRORS++))
[[ "${STATUS[docker]}" != "running" ]] && ((ERRORS++))
[[ "${STATUS[nginx]}" != "running" ]] && ((ERRORS++))
[[ "${STATUS[ssl_cert]}" != "valid" ]] && ((ERRORS++))
[[ "${STATUS[firewall]}" != "active" ]] && ((WARNINGS++))
[[ "${STATUS[fail2ban]}" != "running" ]] && ((WARNINGS++))
[[ "${STATUS[repo_openclaw_exists]}" != "true" ]] && ((ERRORS++))

if [[ $ERRORS -eq 0 ]] && [[ $WARNINGS -eq 0 ]]; then
    echo ""
    echo -e "  ${GREEN}${BOLD}All systems operational${NC}"
    echo ""
    log_self_protocol "Self-observation complete - Guardian is healthy"
elif [[ $ERRORS -eq 0 ]]; then
    echo ""
    echo -e "  ${YELLOW}${BOLD}${WARNINGS} warning(s) detected${NC}"
    echo ""
    log_self_protocol "Self-observation complete - Guardian has minor issues"
else
    echo ""
    echo -e "  ${RED}${BOLD}${ERRORS} error(s), ${WARNINGS} warning(s) detected${NC}"
    echo ""
    log_self_protocol "Self-observation complete - Guardian needs attention"
fi

#-------------------------------------------------------------------------------
# Record this observation
#-------------------------------------------------------------------------------
if [[ -d "${DATA_DIR}/interests" ]]; then
    echo "$(date -u +"%Y-%m-%dT%H:%M:%SZ"): Status check - ${ERRORS} errors, ${WARNINGS} warnings" >> "${DATA_DIR}/interests/status-checks.log"
fi

exit $ERRORS
