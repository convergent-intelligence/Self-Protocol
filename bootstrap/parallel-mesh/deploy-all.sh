#!/bin/bash
#===============================================================================
# Kingdom Mesh Deployment Orchestrator
# Deploys bootstrap scripts to all VMs in parallel
#===============================================================================
# Usage:
#   ./deploy-all.sh              # Deploy to all nodes
#   ./deploy-all.sh kali debian  # Deploy to specific nodes
#   ./deploy-all.sh --dry-run    # Show what would be deployed
#===============================================================================

set -euo pipefail

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BOOTSTRAP_DIR="$(dirname "$SCRIPT_DIR")"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Node definitions
declare -A NODE_IPS=(
    ["kali"]="192.168.1.10"
    ["debian"]="192.168.1.11"
    ["fedora"]="192.168.1.12"
    ["windows"]="192.168.1.13"
    ["macos"]="192.168.1.14"
    ["ubuntu"]="192.168.1.15"
)

declare -A NODE_SCRIPTS=(
    ["kali"]="guardian-setup-kali.sh"
    ["debian"]="nodes/debian-node.sh"
    ["fedora"]="nodes/fedora-node.sh"
    ["windows"]="nodes/windows-node.ps1"
    ["macos"]="nodes/macos-node.sh"
    ["ubuntu"]="nodes/ubuntu-node.sh"
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
SSH_OPTS="-o StrictHostKeyChecking=no -o ConnectTimeout=10 -o BatchMode=yes"
DRY_RUN=false
PARALLEL=true
LOG_DIR="${SCRIPT_DIR}/logs"

#-------------------------------------------------------------------------------
# Logging
#-------------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_section() {
    echo ""
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}════════════════════════════════════════════════════════════${NC}"
}

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------
parse_args() {
    NODES_TO_DEPLOY=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --dry-run)
                DRY_RUN=true
                shift
                ;;
            --sequential)
                PARALLEL=false
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                if [[ -n "${NODE_IPS[$1]:-}" ]]; then
                    NODES_TO_DEPLOY+=("$1")
                else
                    log_error "Unknown node: $1"
                    log_info "Available nodes: ${!NODE_IPS[*]}"
                    exit 1
                fi
                shift
                ;;
        esac
    done
    
    # Default to all nodes if none specified
    if [[ ${#NODES_TO_DEPLOY[@]} -eq 0 ]]; then
        NODES_TO_DEPLOY=("kali" "debian" "fedora" "ubuntu" "macos" "windows")
    fi
}

show_help() {
    cat << EOF
Kingdom Mesh Deployment Orchestrator

Usage: ./deploy-all.sh [OPTIONS] [NODES...]

Options:
    --dry-run       Show what would be deployed without executing
    --sequential    Deploy nodes one at a time (default: parallel)
    --help, -h      Show this help message

Nodes:
    kali            Guardian/Citadel node (Kali Linux)
    debian          Core infrastructure node (Debian 12)
    fedora          Builder node (Fedora)
    windows         Lenovo simulation (Windows 11)
    macos           Chariot simulation (macOS)
    ubuntu          Flexible role node (Ubuntu)

Examples:
    ./deploy-all.sh                    # Deploy to all nodes
    ./deploy-all.sh kali debian        # Deploy to specific nodes
    ./deploy-all.sh --dry-run          # Preview deployment
    ./deploy-all.sh --sequential kali  # Deploy sequentially

EOF
}

#-------------------------------------------------------------------------------
# Check Node Connectivity
#-------------------------------------------------------------------------------
check_connectivity() {
    local node=$1
    local ip="${NODE_IPS[$node]}"
    local user="${NODE_USERS[$node]}"
    
    if [[ "$node" == "windows" ]]; then
        # Windows uses WinRM or PowerShell remoting
        # For now, just ping check
        ping -c 1 -W 2 "$ip" &> /dev/null
        return $?
    else
        # Linux/macOS use SSH
        ssh $SSH_OPTS "${user}@${ip}" "echo ok" &> /dev/null
        return $?
    fi
}

#-------------------------------------------------------------------------------
# Deploy to Linux Node
#-------------------------------------------------------------------------------
deploy_linux() {
    local node=$1
    local ip="${NODE_IPS[$node]}"
    local user="${NODE_USERS[$node]}"
    local script="${NODE_SCRIPTS[$node]}"
    local script_path="${BOOTSTRAP_DIR}/${script}"
    local log_file="${LOG_DIR}/${node}.log"
    
    log_info "[$node] Deploying to ${ip}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[$node] Would copy: $script_path"
        log_info "[$node] Would execute: sudo bash /tmp/$(basename $script)"
        return 0
    fi
    
    # Copy script to node
    scp $SSH_OPTS "$script_path" "${user}@${ip}:/tmp/" >> "$log_file" 2>&1 || {
        log_error "[$node] Failed to copy script"
        return 1
    }
    
    # Execute script
    ssh $SSH_OPTS "${user}@${ip}" "sudo bash /tmp/$(basename $script)" >> "$log_file" 2>&1 || {
        log_error "[$node] Script execution failed - check $log_file"
        return 1
    }
    
    log_success "[$node] Deployment complete"
    return 0
}

#-------------------------------------------------------------------------------
# Deploy to macOS Node
#-------------------------------------------------------------------------------
deploy_macos() {
    local node=$1
    local ip="${NODE_IPS[$node]}"
    local user="${NODE_USERS[$node]}"
    local script="${NODE_SCRIPTS[$node]}"
    local script_path="${BOOTSTRAP_DIR}/${script}"
    local log_file="${LOG_DIR}/${node}.log"
    
    log_info "[$node] Deploying to ${ip}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[$node] Would copy: $script_path"
        log_info "[$node] Would execute: bash /tmp/$(basename $script) --user"
        return 0
    fi
    
    # Copy script to node
    scp $SSH_OPTS "$script_path" "${user}@${ip}:/tmp/" >> "$log_file" 2>&1 || {
        log_error "[$node] Failed to copy script"
        return 1
    }
    
    # Execute script (user-level install for VM)
    ssh $SSH_OPTS "${user}@${ip}" "bash /tmp/$(basename $script) --user" >> "$log_file" 2>&1 || {
        log_error "[$node] Script execution failed - check $log_file"
        return 1
    }
    
    log_success "[$node] Deployment complete"
    return 0
}

#-------------------------------------------------------------------------------
# Deploy to Windows Node
#-------------------------------------------------------------------------------
deploy_windows() {
    local node=$1
    local ip="${NODE_IPS[$node]}"
    local user="${NODE_USERS[$node]}"
    local script="${NODE_SCRIPTS[$node]}"
    local script_path="${BOOTSTRAP_DIR}/${script}"
    local log_file="${LOG_DIR}/${node}.log"
    
    log_info "[$node] Deploying to ${ip}..."
    
    if [[ "$DRY_RUN" == "true" ]]; then
        log_info "[$node] Would copy: $script_path"
        log_info "[$node] Would execute via PowerShell remoting"
        return 0
    fi
    
    # Windows deployment via PowerShell remoting
    # This requires WinRM to be configured on the Windows VM
    
    # Copy script via SCP (if OpenSSH is installed on Windows)
    scp $SSH_OPTS "$script_path" "${user}@${ip}:C:/temp/" >> "$log_file" 2>&1 || {
        log_warn "[$node] SCP failed - trying alternative method"
        
        # Alternative: Use PowerShell remoting
        # This requires the host to have PowerShell Core installed
        if command -v pwsh &> /dev/null; then
            pwsh -Command "
                \$cred = Get-Credential -UserName '$user' -Message 'Windows password'
                \$session = New-PSSession -ComputerName '$ip' -Credential \$cred
                Copy-Item '$script_path' -Destination 'C:\\temp\\' -ToSession \$session
                Invoke-Command -Session \$session -ScriptBlock { 
                    Set-ExecutionPolicy Bypass -Scope Process -Force
                    & 'C:\\temp\\windows-node.ps1'
                }
                Remove-PSSession \$session
            " >> "$log_file" 2>&1 || {
                log_error "[$node] PowerShell remoting failed"
                return 1
            }
        else
            log_error "[$node] No method available to deploy to Windows"
            log_warn "[$node] Please manually run the script on the Windows VM"
            return 1
        fi
    }
    
    # Execute via SSH if available
    ssh $SSH_OPTS "${user}@${ip}" "powershell -ExecutionPolicy Bypass -File C:\\temp\\windows-node.ps1" >> "$log_file" 2>&1 || {
        log_warn "[$node] SSH execution failed - script may need manual execution"
    }
    
    log_success "[$node] Deployment initiated"
    return 0
}

#-------------------------------------------------------------------------------
# Deploy to Single Node
#-------------------------------------------------------------------------------
deploy_node() {
    local node=$1
    
    case $node in
        windows)
            deploy_windows "$node"
            ;;
        macos)
            deploy_macos "$node"
            ;;
        *)
            deploy_linux "$node"
            ;;
    esac
}

#-------------------------------------------------------------------------------
# Main Deployment
#-------------------------------------------------------------------------------
main() {
    log_section "Kingdom Mesh Deployment"
    log_info "Started at $(date)"
    
    parse_args "$@"
    
    # Create log directory
    mkdir -p "$LOG_DIR"
    
    # Show deployment plan
    log_info "Nodes to deploy: ${NODES_TO_DEPLOY[*]}"
    log_info "Parallel: $PARALLEL"
    log_info "Dry run: $DRY_RUN"
    echo ""
    
    # Check connectivity first
    log_section "Checking Connectivity"
    REACHABLE_NODES=()
    UNREACHABLE_NODES=()
    
    for node in "${NODES_TO_DEPLOY[@]}"; do
        if check_connectivity "$node"; then
            log_success "[$node] ${NODE_IPS[$node]} - reachable"
            REACHABLE_NODES+=("$node")
        else
            log_warn "[$node] ${NODE_IPS[$node]} - unreachable"
            UNREACHABLE_NODES+=("$node")
        fi
    done
    
    if [[ ${#UNREACHABLE_NODES[@]} -gt 0 ]]; then
        log_warn "Unreachable nodes will be skipped: ${UNREACHABLE_NODES[*]}"
    fi
    
    if [[ ${#REACHABLE_NODES[@]} -eq 0 ]]; then
        log_error "No reachable nodes to deploy to"
        exit 1
    fi
    
    # Deploy
    log_section "Deploying to Nodes"
    
    if [[ "$PARALLEL" == "true" ]]; then
        # Parallel deployment
        PIDS=()
        for node in "${REACHABLE_NODES[@]}"; do
            deploy_node "$node" &
            PIDS+=($!)
        done
        
        # Wait for all deployments
        FAILED=0
        for i in "${!PIDS[@]}"; do
            wait "${PIDS[$i]}" || ((FAILED++))
        done
        
        if [[ $FAILED -gt 0 ]]; then
            log_warn "$FAILED deployment(s) failed"
        fi
    else
        # Sequential deployment
        for node in "${REACHABLE_NODES[@]}"; do
            deploy_node "$node" || log_warn "[$node] Deployment failed"
        done
    fi
    
    # Summary
    log_section "Deployment Summary"
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Deployment Complete                            ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Deployed:     ${#REACHABLE_NODES[@]} nodes"
    echo -e "${GREEN}║${NC} Skipped:      ${#UNREACHABLE_NODES[@]} nodes"
    echo -e "${GREEN}║${NC} Logs:         ${LOG_DIR}/"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Next Steps:"
    echo -e "${GREEN}║${NC}   1. Run ./mesh-status.sh to verify all nodes"
    echo -e "${GREEN}║${NC}   2. Check individual logs for any errors"
    echo -e "${GREEN}║${NC}   3. Test mesh connectivity between nodes"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_info "Completed at $(date)"
}

main "$@"
