#!/bin/bash
#===============================================================================
# Kingdom Mesh Status Monitor
# Shows status of all 6 nodes in the mesh
#===============================================================================
# Usage:
#   ./mesh-status.sh              # Show all node status
#   ./mesh-status.sh --watch      # Continuous monitoring
#   ./mesh-status.sh --json       # Output as JSON
#===============================================================================

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

# Node definitions
declare -A NODE_IPS=(
    ["kali"]="192.168.1.10"
    ["debian"]="192.168.1.11"
    ["fedora"]="192.168.1.12"
    ["windows"]="192.168.1.13"
    ["macos"]="192.168.1.14"
    ["ubuntu"]="192.168.1.15"
)

declare -A NODE_ROLES=(
    ["kali"]="Guardian/Citadel"
    ["debian"]="Core Infrastructure"
    ["fedora"]="Builder"
    ["windows"]="Lenovo Simulation"
    ["macos"]="Chariot Simulation"
    ["ubuntu"]="Flexible"
)

declare -A NODE_USERS=(
    ["kali"]="kingdom"
    ["debian"]="kingdom"
    ["fedora"]="kingdom"
    ["windows"]="kingdom"
    ["macos"]="kingdom"
    ["ubuntu"]="kingdom"
)

# Configuration
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=5 -o BatchMode=yes"
WATCH_MODE=false
JSON_OUTPUT=false
WATCH_INTERVAL=10

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --watch|-w)
                WATCH_MODE=true
                shift
                ;;
            --json|-j)
                JSON_OUTPUT=true
                shift
                ;;
            --interval|-i)
                WATCH_INTERVAL=$2
                shift 2
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                shift
                ;;
        esac
    done
}

show_help() {
    cat << EOF
Kingdom Mesh Status Monitor

Usage: ./mesh-status.sh [OPTIONS]

Options:
    --watch, -w         Continuous monitoring mode
    --interval, -i N    Watch interval in seconds (default: 10)
    --json, -j          Output status as JSON
    --help, -h          Show this help message

Examples:
    ./mesh-status.sh                    # Show current status
    ./mesh-status.sh --watch            # Continuous monitoring
    ./mesh-status.sh --watch -i 5       # Watch every 5 seconds
    ./mesh-status.sh --json             # JSON output for scripting

EOF
}

#-------------------------------------------------------------------------------
# Check Node Status
#-------------------------------------------------------------------------------
check_ping() {
    local ip=$1
    ping -c 1 -W 2 "$ip" &> /dev/null
    return $?
}

check_ssh() {
    local ip=$1
    local user=$2
    ssh $SSH_OPTS "${user}@${ip}" "echo ok" &> /dev/null
    return $?
}

get_node_info() {
    local node=$1
    local ip="${NODE_IPS[$node]}"
    local user="${NODE_USERS[$node]}"
    
    # For Windows, we can only do basic checks
    if [[ "$node" == "windows" ]]; then
        if check_ping "$ip"; then
            echo "reachable"
        else
            echo "unreachable"
        fi
        return
    fi
    
    # For Linux/macOS, get detailed info
    if check_ssh "$ip" "$user"; then
        # Get system info
        local info=$(ssh $SSH_OPTS "${user}@${ip}" "
            echo -n 'uptime:'; uptime -p 2>/dev/null || uptime | awk '{print \$3,\$4}';
            echo -n 'load:'; cat /proc/loadavg 2>/dev/null | awk '{print \$1}' || sysctl -n vm.loadavg 2>/dev/null | awk '{print \$2}';
            echo -n 'docker:'; docker ps -q 2>/dev/null | wc -l | tr -d ' ';
            echo -n 'memory:'; free -m 2>/dev/null | awk '/^Mem:/{printf \"%.0f%%\", \$3/\$2*100}' || vm_stat 2>/dev/null | awk '/Pages free/{print \"ok\"}';
        " 2>/dev/null)
        echo "$info"
    else
        echo "unreachable"
    fi
}

#-------------------------------------------------------------------------------
# Display Functions
#-------------------------------------------------------------------------------
print_header() {
    clear
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}                    ${BOLD}KINGDOM MESH STATUS MONITOR${NC}                               ${CYAN}║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC}  Last Updated: $(date '+%Y-%m-%d %H:%M:%S')                                            ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_node_status() {
    local node=$1
    local ip="${NODE_IPS[$node]}"
    local role="${NODE_ROLES[$node]}"
    local status
    local status_color
    local status_icon
    
    # Check basic connectivity
    if check_ping "$ip"; then
        status="ONLINE"
        status_color="${GREEN}"
        status_icon="●"
    else
        status="OFFLINE"
        status_color="${RED}"
        status_icon="○"
    fi
    
    # Node-specific colors
    local node_color
    case $node in
        kali)    node_color="${MAGENTA}" ;;
        debian)  node_color="${BLUE}" ;;
        fedora)  node_color="${YELLOW}" ;;
        windows) node_color="${CYAN}" ;;
        macos)   node_color="${GREEN}" ;;
        ubuntu)  node_color="${RED}" ;;
    esac
    
    printf "${node_color}%-10s${NC} │ %-15s │ ${status_color}%s %s${NC} │ %-20s\n" \
        "$node" "$ip" "$status_icon" "$status" "$role"
}

print_mesh_diagram() {
    echo ""
    echo -e "${BOLD}Mesh Topology:${NC}"
    echo ""
    
    # Check each node and color accordingly
    local kali_color=$(check_ping "${NODE_IPS[kali]}" && echo "${GREEN}" || echo "${RED}")
    local debian_color=$(check_ping "${NODE_IPS[debian]}" && echo "${GREEN}" || echo "${RED}")
    local fedora_color=$(check_ping "${NODE_IPS[fedora]}" && echo "${GREEN}" || echo "${RED}")
    local windows_color=$(check_ping "${NODE_IPS[windows]}" && echo "${GREEN}" || echo "${RED}")
    local macos_color=$(check_ping "${NODE_IPS[macos]}" && echo "${GREEN}" || echo "${RED}")
    local ubuntu_color=$(check_ping "${NODE_IPS[ubuntu]}" && echo "${GREEN}" || echo "${RED}")
    
    cat << EOF
    ${kali_color}┌──────────┐${NC}      ${debian_color}┌──────────┐${NC}      ${fedora_color}┌──────────┐${NC}
    ${kali_color}│   KALI   │${NC}──────${debian_color}│  DEBIAN  │${NC}──────${fedora_color}│  FEDORA  │${NC}
    ${kali_color}│ Guardian │${NC}      ${debian_color}│   Core   │${NC}      ${fedora_color}│ Builder  │${NC}
    ${kali_color}└──────────┘${NC}      ${debian_color}└──────────┘${NC}      ${fedora_color}└──────────┘${NC}
          │                  │                  │
          │                  │                  │
          │                  │                  │
    ${windows_color}┌──────────┐${NC}      ${macos_color}┌──────────┐${NC}      ${ubuntu_color}┌──────────┐${NC}
    ${windows_color}│ WINDOWS  │${NC}──────${macos_color}│  macOS   │${NC}──────${ubuntu_color}│  UBUNTU  │${NC}
    ${windows_color}│  Lenovo  │${NC}      ${macos_color}│ Chariot  │${NC}      ${ubuntu_color}│   Flex   │${NC}
    ${windows_color}└──────────┘${NC}      ${macos_color}└──────────┘${NC}      ${ubuntu_color}└──────────┘${NC}
EOF
    echo ""
}

print_detailed_status() {
    echo ""
    echo -e "${BOLD}Node Details:${NC}"
    echo "────────────────────────────────────────────────────────────────────────"
    printf "%-10s │ %-15s │ %-8s │ %-20s\n" "NODE" "IP" "STATUS" "ROLE"
    echo "────────────────────────────────────────────────────────────────────────"
    
    for node in kali debian fedora windows macos ubuntu; do
        print_node_status "$node"
    done
    
    echo "────────────────────────────────────────────────────────────────────────"
}

print_summary() {
    local online=0
    local offline=0
    
    for node in "${!NODE_IPS[@]}"; do
        if check_ping "${NODE_IPS[$node]}"; then
            ((online++))
        else
            ((offline++))
        fi
    done
    
    echo ""
    echo -e "${BOLD}Summary:${NC}"
    echo -e "  ${GREEN}●${NC} Online:  $online nodes"
    echo -e "  ${RED}○${NC} Offline: $offline nodes"
    echo -e "  Total:   ${#NODE_IPS[@]} nodes"
    echo ""
}

#-------------------------------------------------------------------------------
# JSON Output
#-------------------------------------------------------------------------------
output_json() {
    echo "{"
    echo '  "timestamp": "'$(date -Iseconds)'",'
    echo '  "nodes": {'
    
    local first=true
    for node in "${!NODE_IPS[@]}"; do
        local ip="${NODE_IPS[$node]}"
        local role="${NODE_ROLES[$node]}"
        local status="offline"
        
        if check_ping "$ip"; then
            status="online"
        fi
        
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo ","
        fi
        
        echo -n "    \"$node\": {"
        echo -n "\"ip\": \"$ip\", "
        echo -n "\"role\": \"$role\", "
        echo -n "\"status\": \"$status\""
        echo -n "}"
    done
    
    echo ""
    echo "  }"
    echo "}"
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    parse_args "$@"
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        output_json
        exit 0
    fi
    
    if [[ "$WATCH_MODE" == "true" ]]; then
        while true; do
            print_header
            print_mesh_diagram
            print_detailed_status
            print_summary
            
            echo -e "${YELLOW}Refreshing in ${WATCH_INTERVAL}s... (Ctrl+C to exit)${NC}"
            sleep "$WATCH_INTERVAL"
        done
    else
        print_header
        print_mesh_diagram
        print_detailed_status
        print_summary
    fi
}

main "$@"
