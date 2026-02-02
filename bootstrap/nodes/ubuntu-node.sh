#!/bin/bash
#===============================================================================
# Ubuntu Node Bootstrap Script
# OS: Ubuntu 22.04+ | Role: Flexible
# Part of Kingdom Mesh Network
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# IDENTICAL to production deployment - no simulation flags
#===============================================================================

set -euo pipefail

# Configuration
NODE_ROLE="${KINGDOM_ROLE:-flex}"
INSTALL_DIR="/opt/kingdom"
REPOS_DIR="${INSTALL_DIR}/repos"
MESH_NETWORK="${KINGDOM_MESH_NETWORK:-192.168.1.0/24}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
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
        if [[ "$ID" != "ubuntu" ]]; then
            log_warn "This script is designed for Ubuntu. Current: $ID"
        fi
        log_info "Detected: $PRETTY_NAME"
    fi
    
    log_success "Pre-flight checks passed"
}

#-------------------------------------------------------------------------------
# System Dependencies
#-------------------------------------------------------------------------------
install_dependencies() {
    log_section "Installing System Dependencies"
    
    # Disable interactive prompts
    export DEBIAN_FRONTEND=noninteractive
    
    apt-get update -qq
    
    PACKAGES=(
        git curl wget gnupg ca-certificates
        apt-transport-https software-properties-common
        ufw fail2ban
        nginx certbot python3-certbot-nginx
        python3 python3-pip python3-venv
        jq htop tmux tree
        build-essential
        # Ubuntu-specific useful packages
        snapd
        net-tools
    )
    
    apt-get install -y "${PACKAGES[@]}"
    log_success "Core packages installed"
}

#-------------------------------------------------------------------------------
# Docker Installation
#-------------------------------------------------------------------------------
install_docker() {
    log_section "Installing Docker"
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
    else
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add Docker repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        log_success "Docker installed"
    fi
    
    systemctl enable docker
    systemctl start docker
    log_success "Docker service active"
}

#-------------------------------------------------------------------------------
# Node.js Installation
#-------------------------------------------------------------------------------
install_nodejs() {
    log_section "Installing Node.js"
    
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -lt 18 ]]; then
            log_warn "Node.js version too old, upgrading..."
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
        else
            log_info "Node.js version acceptable: $(node --version)"
        fi
    else
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        log_success "Node.js installed: $(node --version)"
    fi
    
    npm install -g npm@latest 2>/dev/null || true
    log_success "Node.js setup complete"
}

#-------------------------------------------------------------------------------
# Firewall Configuration
#-------------------------------------------------------------------------------
configure_firewall() {
    log_section "Configuring Firewall"
    
    ufw default deny incoming
    ufw default allow outgoing
    
    ufw allow 22/tcp comment 'SSH'
    ufw allow 80/tcp comment 'HTTP'
    ufw allow 443/tcp comment 'HTTPS'
    
    # Kingdom mesh ports
    ufw allow from ${MESH_NETWORK} to any port 3000:3100 proto tcp comment 'Kingdom Mesh'
    
    echo "y" | ufw enable
    log_success "Firewall configured"
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

[nginx-http-auth]
enabled = true
port = http,https
maxretry = 3
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
    log_section "Configuring Ubuntu Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    cat > "${CONFIG_DIR}/node.yaml" << EOF
# Ubuntu Flex Node Configuration
node:
  role: ${NODE_ROLE}
  platform: ubuntu
  
mesh:
  network: ${MESH_NETWORK}
  port_range: 3000-3100

# Flexible role - can be assigned dynamically
capabilities:
  - general
  - testing
  - development
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
# Create Services
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Services"
    
    if [[ ! -f /etc/systemd/system/kingdom-node.service ]]; then
        cat > /etc/systemd/system/kingdom-node.service << EOF
[Unit]
Description=Kingdom Node - Ubuntu
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
  kingdom-flex:
    image: node:20-alpine
    container_name: kingdom-flex
    working_dir: /app
    volumes:
      - ${REPOS_DIR}/Kingdom:/app
    ports:
      - "127.0.0.1:3000:3000"
    command: echo "Kingdom flex node ready"
    restart: unless-stopped
EOF
    fi
    
    systemctl daemon-reload
    log_success "Services configured"
}

#-------------------------------------------------------------------------------
# Ubuntu-Specific Optimizations
#-------------------------------------------------------------------------------
ubuntu_optimizations() {
    log_section "Ubuntu-Specific Optimizations"
    
    # Enable automatic security updates
    if [[ ! -f /etc/apt/apt.conf.d/20auto-upgrades ]]; then
        apt-get install -y unattended-upgrades
        cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
APT::Periodic::Update-Package-Lists "1";
APT::Periodic::Unattended-Upgrade "1";
APT::Periodic::AutocleanInterval "7";
EOF
        log_success "Automatic security updates enabled"
    fi
    
    # Optimize swap (if low memory)
    if [[ $(free -m | awk '/^Mem:/{print $2}') -lt 4096 ]]; then
        log_info "Low memory detected, optimizing swap..."
        if [[ ! -f /swapfile ]]; then
            fallocate -l 2G /swapfile
            chmod 600 /swapfile
            mkswap /swapfile
            swapon /swapfile
            echo '/swapfile none swap sw 0 0' >> /etc/fstab
            log_success "Swap file created"
        fi
    fi
    
    log_success "Ubuntu optimizations complete"
}

#-------------------------------------------------------------------------------
# Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Ubuntu Node Setup Complete"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              Ubuntu Node Bootstrap Complete                 ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Role:       ${MAGENTA}${NODE_ROLE}${NC}"
    echo -e "${GREEN}║${NC} Platform:   ${BLUE}Ubuntu${NC}"
    echo -e "${GREEN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Services:"
    echo -e "${GREEN}║${NC}   - Docker:    $(systemctl is-active docker 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - Nginx:     $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - UFW:       $(ufw status 2>/dev/null | head -1 || echo 'unknown')"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} System:"
    echo -e "${GREEN}║${NC}   - Memory:    $(free -h | awk '/^Mem:/{print $2}')"
    echo -e "${GREEN}║${NC}   - Disk:      $(df -h / | awk 'NR==2{print $4}') available"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    log_section "Ubuntu Node Bootstrap"
    log_info "Starting at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    install_nodejs
    configure_firewall
    configure_fail2ban
    clone_repositories
    configure_node
    create_services
    ubuntu_optimizations
    print_status
    
    log_info "Completed at $(date)"
}

main "$@"
