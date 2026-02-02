#!/bin/bash
#===============================================================================
# Builder Node Bootstrap Script
# VPS: Debian 12 | Role: Builder in Kingdom Hierarchy
# Integrates: CI/CD, Build Pipelines, Artifact Management
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
DOMAIN="${BUILDER_DOMAIN:-builder.kingdom.local}"
NODE_ROLE="builder"
INSTALL_DIR="/opt/kingdom"
REPOS_DIR="${INSTALL_DIR}/repos"
ARTIFACTS_DIR="${INSTALL_DIR}/artifacts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_section() {
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} $1${NC}"
    echo -e "${GREEN}========================================${NC}"
}

#-------------------------------------------------------------------------------
# Pre-flight Checks
#-------------------------------------------------------------------------------
preflight_checks() {
    log_section "Pre-flight Checks"
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        log_error "This script must be run as root"
        exit 1
    fi
    
    # Check Debian version
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "debian" ]] || [[ "${VERSION_ID:-}" != "12" ]]; then
            log_warn "This script is designed for Debian 12. Current: $ID $VERSION_ID"
        fi
    fi
    
    log_success "Pre-flight checks passed"
}

#-------------------------------------------------------------------------------
# System Dependencies Installation
#-------------------------------------------------------------------------------
install_dependencies() {
    log_section "Installing System Dependencies"
    
    # Update package lists (always do this)
    log_info "Updating package lists..."
    apt-get update -qq
    
    # Core packages for Builder node
    PACKAGES=(
        git
        curl
        wget
        gnupg
        ca-certificates
        apt-transport-https
        software-properties-common
        ufw
        fail2ban
        python3
        python3-pip
        python3-venv
        jq
        htop
        tmux
        build-essential
        cmake
        pkg-config
        libssl-dev
        make
        gcc
        g++
    )
    
    # Install packages (apt-get is idempotent)
    log_info "Installing core packages..."
    apt-get install -y "${PACKAGES[@]}"
    
    log_success "Core packages installed"
}

#-------------------------------------------------------------------------------
# Docker Installation
#-------------------------------------------------------------------------------
install_docker() {
    log_section "Installing Docker"
    
    # Check if Docker is already installed
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
    else
        log_info "Installing Docker..."
        
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Add Docker repository
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
          $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
          tee /etc/apt/sources.list.d/docker.list > /dev/null
        
        apt-get update -qq
        apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
        
        log_success "Docker installed"
    fi
    
    # Ensure Docker service is running
    systemctl enable docker
    systemctl start docker
    
    log_success "Docker service is active"
}

#-------------------------------------------------------------------------------
# Node.js Installation (via NodeSource)
#-------------------------------------------------------------------------------
install_nodejs() {
    log_section "Installing Node.js"
    
    # Check if Node.js is already installed
    if command -v node &> /dev/null; then
        log_info "Node.js already installed: $(node --version)"
    else
        log_info "Installing Node.js LTS..."
        
        # Install Node.js 20.x LTS
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
        
        log_success "Node.js installed: $(node --version)"
    fi
    
    # Install/update npm to latest
    npm install -g npm@latest 2>/dev/null || true
    
    log_success "Node.js setup complete"
}

#-------------------------------------------------------------------------------
# Rust Installation
#-------------------------------------------------------------------------------
install_rust() {
    log_section "Installing Rust"
    
    # Check if Rust is already installed
    if command -v rustc &> /dev/null; then
        log_info "Rust already installed: $(rustc --version)"
    else
        log_info "Installing Rust..."
        
        # Install Rust via rustup (as non-root user if possible)
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
        
        # Source cargo env
        source "$HOME/.cargo/env" 2>/dev/null || true
        
        log_success "Rust installed"
    fi
    
    # Ensure cargo is in PATH
    export PATH="$HOME/.cargo/bin:$PATH"
    
    log_success "Rust setup complete"
}

#-------------------------------------------------------------------------------
# Firewall Configuration (UFW)
#-------------------------------------------------------------------------------
configure_firewall() {
    log_section "Configuring Firewall (UFW)"
    
    # Reset UFW to default (deny incoming, allow outgoing)
    log_info "Setting UFW defaults..."
    ufw default deny incoming
    ufw default allow outgoing
    
    # Allow SSH (port 22) - CRITICAL: Do this first!
    log_info "Allowing SSH (port 22)..."
    ufw allow 22/tcp comment 'SSH'
    
    # Allow Build API (port 8080)
    log_info "Allowing Build API (port 8080)..."
    ufw allow 8080/tcp comment 'Build API'
    
    # Allow Artifact Registry (port 5000)
    log_info "Allowing Artifact Registry (port 5000)..."
    ufw allow 5000/tcp comment 'Artifact Registry'
    
    # Allow Node Exporter (port 9100) - for Watcher monitoring
    log_info "Allowing Node Exporter (port 9100)..."
    ufw allow from 10.0.0.0/8 to any port 9100 comment 'Node Exporter Internal'
    ufw allow from 172.16.0.0/12 to any port 9100 comment 'Node Exporter Internal'
    ufw allow from 192.168.0.0/16 to any port 9100 comment 'Node Exporter Internal'
    
    # Enable UFW (idempotent - won't prompt if already enabled)
    log_info "Enabling UFW..."
    echo "y" | ufw enable
    
    # Show status
    ufw status verbose
    
    log_success "Firewall configured"
}

#-------------------------------------------------------------------------------
# Fail2Ban Configuration
#-------------------------------------------------------------------------------
configure_fail2ban() {
    log_section "Configuring Fail2Ban"
    
    # Create local jail configuration
    JAIL_LOCAL="/etc/fail2ban/jail.local"
    
    if [[ ! -f "$JAIL_LOCAL" ]]; then
        log_info "Creating Fail2Ban jail configuration..."
        cat > "$JAIL_LOCAL" << 'EOF'
[DEFAULT]
bantime = 1h
findtime = 10m
maxretry = 5
backend = systemd

[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 24h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Enable and restart Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_success "Fail2Ban configured and running"
}

#-------------------------------------------------------------------------------
# Docker Registry Configuration
#-------------------------------------------------------------------------------
configure_registry() {
    log_section "Configuring Docker Registry"
    
    REGISTRY_DIR="${INSTALL_DIR}/registry"
    mkdir -p "$REGISTRY_DIR"
    
    # Create registry configuration
    if [[ ! -f "${REGISTRY_DIR}/config.yml" ]]; then
        log_info "Creating Docker Registry configuration..."
        cat > "${REGISTRY_DIR}/config.yml" << 'EOF'
version: 0.1
log:
  fields:
    service: registry
storage:
  cache:
    blobdescriptor: inmemory
  filesystem:
    rootdirectory: /var/lib/registry
http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
        log_success "Docker Registry configuration created"
    fi
    
    log_success "Docker Registry configured"
}

#-------------------------------------------------------------------------------
# Build Pipeline Configuration
#-------------------------------------------------------------------------------
configure_build_pipeline() {
    log_section "Configuring Build Pipeline"
    
    PIPELINE_DIR="${INSTALL_DIR}/pipeline"
    mkdir -p "$PIPELINE_DIR"
    mkdir -p "${PIPELINE_DIR}/jobs"
    mkdir -p "${PIPELINE_DIR}/logs"
    
    # Create pipeline configuration
    cat > "${PIPELINE_DIR}/config.yaml" << EOF
# Builder Node - Pipeline Configuration
pipeline:
  workspace: ${INSTALL_DIR}/workspace
  artifacts: ${ARTIFACTS_DIR}
  logs: ${PIPELINE_DIR}/logs
  
build_environments:
  node:
    image: node:20-alpine
    cache: /cache/node
  rust:
    image: rust:latest
    cache: /cache/rust
  python:
    image: python:3.11-slim
    cache: /cache/python

artifact_retention:
  days: 30
  max_size_gb: 50
EOF
    
    # Create workspace directory
    mkdir -p "${INSTALL_DIR}/workspace"
    mkdir -p "$ARTIFACTS_DIR"
    
    log_success "Build pipeline configured"
}

#-------------------------------------------------------------------------------
# Repository Cloning
#-------------------------------------------------------------------------------
clone_repositories() {
    log_section "Cloning Repositories"
    
    # Create installation directory
    mkdir -p "$REPOS_DIR"
    
    # Repository definitions: name -> URL
    declare -A REPOS=(
        ["Kingdom"]="https://github.com/vergent/Kingdom.git"
    )
    
    for repo_name in "${!REPOS[@]}"; do
        repo_url="${REPOS[$repo_name]}"
        repo_path="${REPOS_DIR}/${repo_name}"
        
        if [[ -d "$repo_path" ]]; then
            log_info "Repository ${repo_name} already exists, pulling latest..."
            cd "$repo_path"
            git pull --ff-only || log_warn "Could not fast-forward ${repo_name}"
            cd - > /dev/null
        else
            log_info "Cloning ${repo_name}..."
            git clone "$repo_url" "$repo_path" || log_warn "Could not clone ${repo_name} - repo may not exist yet"
        fi
    done
    
    log_success "Repositories synchronized"
}

#-------------------------------------------------------------------------------
# Builder Node Configuration
#-------------------------------------------------------------------------------
configure_builder() {
    log_section "Configuring Builder Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    # Create builder-specific configuration
    cat > "${CONFIG_DIR}/builder.yaml" << EOF
# Builder Node Configuration
node:
  role: builder
  domain: ${DOMAIN}
  
build:
  api_port: 8080
  registry_port: 5000
  workspace: ${INSTALL_DIR}/workspace
  artifacts: ${ARTIFACTS_DIR}
  
capabilities:
  - docker
  - node
  - rust
  - python
  
limits:
  concurrent_builds: 4
  build_timeout_minutes: 60
  artifact_max_size_mb: 500
EOF
    
    # Copy weave config if it exists in bootstrap
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    if [[ -f "${SCRIPT_DIR}/weave-config.yaml" ]]; then
        cp "${SCRIPT_DIR}/weave-config.yaml" "${CONFIG_DIR}/"
        log_success "Weave configuration installed"
    fi
    
    # Create commands directory and copy helper scripts
    COMMANDS_DIR="${INSTALL_DIR}/commands"
    mkdir -p "$COMMANDS_DIR"
    
    if [[ -d "${SCRIPT_DIR}/commands" ]]; then
        cp "${SCRIPT_DIR}/commands/"*.sh "$COMMANDS_DIR/" 2>/dev/null || true
        chmod +x "$COMMANDS_DIR/"*.sh 2>/dev/null || true
        log_success "Helper commands installed to ${COMMANDS_DIR}"
    fi
    
    # Add commands to PATH via profile.d
    if [[ ! -f /etc/profile.d/kingdom.sh ]]; then
        cat > /etc/profile.d/kingdom.sh << EOF
# Kingdom Builder Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export PATH="\${PATH}:${COMMANDS_DIR}"
export PATH="\${PATH}:\$HOME/.cargo/bin"
EOF
        log_success "Kingdom environment configured"
    fi
    
    log_success "Builder node configured"
}

#-------------------------------------------------------------------------------
# Create Systemd Services
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Systemd Services"
    
    # Builder Node Service
    if [[ ! -f /etc/systemd/system/builder-node.service ]]; then
        cat > /etc/systemd/system/builder-node.service << EOF
[Unit]
Description=Builder Node - Kingdom Network
After=docker.service network-online.target
Requires=docker.service
Wants=network-online.target

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
        log_success "Builder node service created"
    fi
    
    # Create placeholder docker-compose.yaml
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Builder Node Docker Compose
# Build and artifact management services

version: '3.8'

services:
  # Docker Registry for artifacts
  registry:
    image: registry:2
    container_name: builder-registry
    ports:
      - "5000:5000"
    volumes:
      - registry-data:/var/lib/registry
      - ${INSTALL_DIR}/registry/config.yml:/etc/docker/registry/config.yml:ro
    restart: unless-stopped

  # Build API service
  build-api:
    image: node:20-alpine
    container_name: builder-api
    working_dir: /app
    volumes:
      - ${INSTALL_DIR}/pipeline:/app
      - ${INSTALL_DIR}/workspace:/workspace
      - ${ARTIFACTS_DIR}:/artifacts
      - /var/run/docker.sock:/var/run/docker.sock
    ports:
      - "8080:8080"
    command: echo "Build API pending implementation"
    restart: unless-stopped

  # Build runner
  build-runner:
    image: docker:dind
    container_name: builder-runner
    privileged: true
    volumes:
      - ${INSTALL_DIR}/workspace:/workspace
      - builder-cache:/cache
    environment:
      - DOCKER_TLS_CERTDIR=/certs
    volumes:
      - builder-certs:/certs
    restart: unless-stopped

volumes:
  registry-data:
  builder-cache:
  builder-certs:
EOF
        log_success "Docker compose template created"
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Install Node Exporter for Monitoring
#-------------------------------------------------------------------------------
install_node_exporter() {
    log_section "Installing Node Exporter"
    
    if command -v node_exporter &> /dev/null || [[ -f /usr/local/bin/node_exporter ]]; then
        log_info "Node Exporter already installed"
    else
        log_info "Installing Node Exporter..."
        
        # Download and install node_exporter
        NODE_EXPORTER_VERSION="1.7.0"
        cd /tmp
        wget -q "https://github.com/prometheus/node_exporter/releases/download/v${NODE_EXPORTER_VERSION}/node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
        tar xzf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64.tar.gz"
        cp "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64/node_exporter" /usr/local/bin/
        rm -rf "node_exporter-${NODE_EXPORTER_VERSION}.linux-amd64"*
        cd - > /dev/null
        
        log_success "Node Exporter installed"
    fi
    
    # Create systemd service
    if [[ ! -f /etc/systemd/system/node_exporter.service ]]; then
        cat > /etc/systemd/system/node_exporter.service << 'EOF'
[Unit]
Description=Node Exporter
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/node_exporter
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    systemctl daemon-reload
    systemctl enable node_exporter
    systemctl start node_exporter
    
    log_success "Node Exporter running on port 9100"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Builder Node Setup Complete"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Builder Node Bootstrap Complete                   ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${GREEN}║${NC} Role:       ${BLUE}Builder${NC}"
    echo -e "${GREEN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Services:"
    echo -e "${GREEN}║${NC}   - Docker:        $(systemctl is-active docker)"
    echo -e "${GREEN}║${NC}   - Fail2Ban:      $(systemctl is-active fail2ban)"
    echo -e "${GREEN}║${NC}   - Node Exporter: $(systemctl is-active node_exporter 2>/dev/null || echo 'not running')"
    echo -e "${GREEN}║${NC}   - UFW:           $(ufw status | head -1)"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Build Capabilities:"
    echo -e "${GREEN}║${NC}   - Node.js:  $(node --version 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Rust:     $(rustc --version 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Docker:   $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Endpoints:"
    echo -e "${GREEN}║${NC}   - Build API:  http://localhost:8080"
    echo -e "${GREEN}║${NC}   - Registry:   http://localhost:5000"
    echo -e "${GREEN}║${NC}   - Metrics:    http://localhost:9100"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Next Steps:"
    echo -e "${GREEN}║${NC}   1. Start services: systemctl start builder-node"
    echo -e "${GREEN}║${NC}   2. Configure build pipelines"
    echo -e "${GREEN}║${NC}   3. Register with Watcher node"
    echo -e "${GREEN}║${NC}   4. Test build capabilities"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Helper Commands (after re-login):"
    echo -e "${GREEN}║${NC}   - pull-kingdom.sh    - Pull Kingdom updates"
    echo -e "${GREEN}║${NC}   - builder-status.sh  - Show builder status"
    echo -e "${GREEN}║${NC}   - status.sh          - Show node status"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Builder Node Bootstrap - ${DOMAIN}"
    log_info "Starting bootstrap at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    install_nodejs
    install_rust
    configure_firewall
    configure_fail2ban
    configure_registry
    configure_build_pipeline
    clone_repositories
    configure_builder
    create_services
    install_node_exporter
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
