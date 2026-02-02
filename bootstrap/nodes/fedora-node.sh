#!/bin/bash
#===============================================================================
# Fedora Node Bootstrap Script
# OS: Fedora | Role: Builder Node
# Part of Kingdom Mesh Network
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Uses DNF package manager (Fedora-specific)
# IDENTICAL to production deployment - no simulation flags
#===============================================================================

set -euo pipefail

# Configuration
NODE_ROLE="${KINGDOM_ROLE:-builder}"
INSTALL_DIR="/opt/kingdom"
REPOS_DIR="${INSTALL_DIR}/repos"
MESH_NETWORK="${KINGDOM_MESH_NETWORK:-192.168.1.0/24}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
NC='\033[0m'

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

log_section() {
    echo ""
    echo -e "${ORANGE}========================================${NC}"
    echo -e "${ORANGE} $1${NC}"
    echo -e "${ORANGE}========================================${NC}"
}

#-------------------------------------------------------------------------------
# Pre-flight Checks
#-------------------------------------------------------------------------------
preflight_checks() {
    log_section "Pre-flight Checks"
    
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "fedora" ]]; then
            log_warn "This script is designed for Fedora. Current: $ID"
        fi
        log_info "Detected: $PRETTY_NAME"
    fi
    
    # Verify dnf is available
    if ! command -v dnf &> /dev/null; then
        log_error "DNF package manager not found"
        exit 1
    fi
    
    log_success "Pre-flight checks passed"
}

#-------------------------------------------------------------------------------
# System Dependencies (DNF)
#-------------------------------------------------------------------------------
install_dependencies() {
    log_section "Installing System Dependencies (DNF)"
    
    # Update package cache
    dnf check-update || true  # Returns non-zero if updates available
    
    # Core packages
    PACKAGES=(
        git curl wget gnupg2 ca-certificates
        firewalld fail2ban
        nginx certbot python3-certbot-nginx
        python3 python3-pip python3-virtualenv
        jq htop tmux tree
        # Builder-specific packages
        gcc gcc-c++ make cmake
        rust cargo
        golang
        nodejs npm
        podman-docker  # Fedora prefers Podman, but we alias to docker
    )
    
    dnf install -y "${PACKAGES[@]}"
    log_success "Core packages installed"
}

#-------------------------------------------------------------------------------
# Docker/Podman Setup
#-------------------------------------------------------------------------------
install_docker() {
    log_section "Setting Up Container Runtime"
    
    # Fedora uses Podman by default, which is docker-compatible
    # We installed podman-docker which provides docker CLI compatibility
    
    if command -v docker &> /dev/null; then
        log_info "Container runtime available: $(docker --version 2>/dev/null || podman --version)"
    fi
    
    # For full Docker compatibility, install Docker CE
    if ! rpm -q docker-ce &> /dev/null; then
        log_info "Installing Docker CE for full compatibility..."
        
        dnf -y install dnf-plugins-core
        dnf config-manager --add-repo https://download.docker.com/linux/fedora/docker-ce.repo
        dnf install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        log_success "Docker CE installed"
    else
        log_info "Docker CE already installed"
    fi
    
    systemctl enable docker
    systemctl start docker
    log_success "Docker service active"
}

#-------------------------------------------------------------------------------
# Node.js Setup
#-------------------------------------------------------------------------------
setup_nodejs() {
    log_section "Setting Up Node.js"
    
    # Fedora's nodejs package is usually recent enough
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -lt 18 ]]; then
            log_warn "Node.js version too old, installing newer version..."
            dnf module reset nodejs -y 2>/dev/null || true
            dnf module enable nodejs:20 -y 2>/dev/null || true
            dnf install -y nodejs
        else
            log_info "Node.js version acceptable: $(node --version)"
        fi
    fi
    
    npm install -g npm@latest 2>/dev/null || true
    log_success "Node.js setup complete"
}

#-------------------------------------------------------------------------------
# Rust Setup (Builder Node)
#-------------------------------------------------------------------------------
setup_rust() {
    log_section "Setting Up Rust (Builder Node)"
    
    if command -v rustc &> /dev/null; then
        log_info "Rust already installed: $(rustc --version)"
    else
        log_info "Installing Rust via rustup..."
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        source "$HOME/.cargo/env" 2>/dev/null || true
    fi
    
    # Ensure cargo is in path for all users
    if [[ ! -f /etc/profile.d/rust.sh ]]; then
        cat > /etc/profile.d/rust.sh << 'EOF'
export PATH="$PATH:/root/.cargo/bin"
EOF
    fi
    
    log_success "Rust setup complete"
}

#-------------------------------------------------------------------------------
# Firewall Configuration (firewalld)
#-------------------------------------------------------------------------------
configure_firewall() {
    log_section "Configuring Firewall (firewalld)"
    
    # Fedora uses firewalld instead of ufw
    systemctl enable firewalld
    systemctl start firewalld
    
    # Allow SSH
    firewall-cmd --permanent --add-service=ssh
    
    # Allow HTTP/HTTPS
    firewall-cmd --permanent --add-service=http
    firewall-cmd --permanent --add-service=https
    
    # Kingdom mesh ports
    firewall-cmd --permanent --add-rich-rule="rule family='ipv4' source address='${MESH_NETWORK}' port port='3000-3100' protocol='tcp' accept"
    
    # Reload firewall
    firewall-cmd --reload
    
    log_success "Firewall configured"
    firewall-cmd --list-all
}

#-------------------------------------------------------------------------------
# Fail2Ban Configuration
#-------------------------------------------------------------------------------
configure_fail2ban() {
    log_section "Configuring Fail2Ban"
    
    if [[ ! -f /etc/fail2ban/jail.local ]]; then
        cat > /etc/fail2ban/jail.local << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
maxretry = 3
bantime = 24h
EOF
    fi
    
    systemctl enable fail2ban
    systemctl restart fail2ban
    log_success "Fail2Ban configured"
}

#-------------------------------------------------------------------------------
# Clone Repositories
#-------------------------------------------------------------------------------
clone_repositories() {
    log_section "Cloning Repositories"
    
    mkdir -p "$REPOS_DIR"
    
    declare -A REPOS=(
        ["Kingdom"]="https://github.com/vergent/Kingdom.git"
        ["Self-Protocol"]="https://github.com/vergent/Self-Protocol.git"
    )
    
    for repo_name in "${!REPOS[@]}"; do
        repo_path="${REPOS_DIR}/${repo_name}"
        if [[ -d "$repo_path" ]]; then
            log_info "Updating ${repo_name}..."
            cd "$repo_path" && git pull --ff-only || true
            cd - > /dev/null
        else
            log_info "Cloning ${repo_name}..."
            git clone "${REPOS[$repo_name]}" "$repo_path" || log_warn "Could not clone ${repo_name}"
        fi
    done
    
    log_success "Repositories synchronized"
}

#-------------------------------------------------------------------------------
# Node Configuration
#-------------------------------------------------------------------------------
configure_node() {
    log_section "Configuring Fedora Builder Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    cat > "${CONFIG_DIR}/node.yaml" << EOF
# Fedora Builder Node Configuration
node:
  role: ${NODE_ROLE}
  platform: fedora
  capabilities:
    - rust
    - golang
    - nodejs
    - docker
  
mesh:
  network: ${MESH_NETWORK}
  port_range: 3000-3100

build:
  rust_version: $(rustc --version 2>/dev/null | cut -d' ' -f2 || echo 'not installed')
  go_version: $(go version 2>/dev/null | cut -d' ' -f3 || echo 'not installed')
  node_version: $(node --version 2>/dev/null || echo 'not installed')
EOF
    
    # Environment setup
    if [[ ! -f /etc/profile.d/kingdom.sh ]]; then
        cat > /etc/profile.d/kingdom.sh << EOF
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="${NODE_ROLE}"
export PATH="\${PATH}:${INSTALL_DIR}/commands"
EOF
    fi
    
    log_success "Node configured"
}

#-------------------------------------------------------------------------------
# Create Build Services
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Services"
    
    if [[ ! -f /etc/systemd/system/kingdom-builder.service ]]; then
        cat > /etc/systemd/system/kingdom-builder.service << EOF
[Unit]
Description=Kingdom Builder Node - Fedora
After=docker.service network-online.target
Requires=docker.service

[Service]
Type=simple
WorkingDirectory=${INSTALL_DIR}
ExecStart=/usr/bin/docker compose -f ${INSTALL_DIR}/docker-compose.yaml up
ExecStop=/usr/bin/docker compose -f ${INSTALL_DIR}/docker-compose.yaml down
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
version: '3.8'

services:
  # Build service for Rust projects
  rust-builder:
    image: rust:latest
    container_name: rust-builder
    working_dir: /build
    volumes:
      - ${REPOS_DIR}:/repos
      - ${INSTALL_DIR}/artifacts:/artifacts
    command: echo "Rust builder ready"
    restart: "no"

  # Build service for Node.js projects
  node-builder:
    image: node:20-alpine
    container_name: node-builder
    working_dir: /build
    volumes:
      - ${REPOS_DIR}:/repos
      - ${INSTALL_DIR}/artifacts:/artifacts
    command: echo "Node builder ready"
    restart: "no"
EOF
    fi
    
    # Create artifacts directory
    mkdir -p "${INSTALL_DIR}/artifacts"
    
    systemctl daemon-reload
    log_success "Services configured"
}

#-------------------------------------------------------------------------------
# Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Fedora Builder Node Setup Complete"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║            Fedora Builder Node Bootstrap Complete           ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Role:       ${ORANGE}${NODE_ROLE}${NC}"
    echo -e "${GREEN}║${NC} Platform:   ${BLUE}Fedora${NC}"
    echo -e "${GREEN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Build Tools:"
    echo -e "${GREEN}║${NC}   - Rust:      $(rustc --version 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Go:        $(go version 2>/dev/null | cut -d' ' -f3 || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Node.js:   $(node --version 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Docker:    $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'not installed')"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Services:"
    echo -e "${GREEN}║${NC}   - Docker:    $(systemctl is-active docker 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - Firewalld: $(systemctl is-active firewalld 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    log_section "Fedora Builder Node Bootstrap"
    log_info "Starting at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    setup_nodejs
    setup_rust
    configure_firewall
    configure_fail2ban
    clone_repositories
    configure_node
    create_services
    print_status
    
    log_info "Completed at $(date)"
}

main "$@"
