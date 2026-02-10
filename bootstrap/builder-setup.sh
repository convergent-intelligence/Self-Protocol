#!/bin/bash
#===============================================================================
# Builder Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Builder in Kingdom Hierarchy
# Services: Docker Registry, Build Tools, CI/CD Runners
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
NODE_ROLE="builder"
INSTALL_DIR="/opt/kingdom"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="${INSTALL_DIR}/config"
BUILDS_DIR="${INSTALL_DIR}/builds"
ARTIFACTS_DIR="${INSTALL_DIR}/artifacts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
ORANGE='\033[0;33m'
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
    echo -e "${ORANGE}========================================${NC}"
    echo -e "${ORANGE} $1${NC}"
    echo -e "${ORANGE}========================================${NC}"
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
    
    # Check minimum disk space (builds need space)
    AVAILABLE_SPACE=$(df -BG / | tail -1 | awk '{print $4}' | tr -d 'G')
    if [[ $AVAILABLE_SPACE -lt 20 ]]; then
        log_warn "Low disk space: ${AVAILABLE_SPACE}GB available. Recommend 20GB+ for builds."
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
    
    # Core packages to install
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
        unzip
        build-essential
        gcc
        g++
        make
        cmake
        pkg-config
        libssl-dev
        apache2-utils
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
# Node.js Installation (for JS/TS builds)
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
    
    # Install common build tools
    npm install -g yarn pnpm typescript 2>/dev/null || true
    
    log_success "Node.js setup complete"
}

#-------------------------------------------------------------------------------
# Rust Installation (for Rust builds)
#-------------------------------------------------------------------------------
install_rust() {
    log_section "Installing Rust"
    
    # Check if Rust is already installed
    if command -v rustc &> /dev/null; then
        log_info "Rust already installed: $(rustc --version)"
    else
        log_info "Installing Rust..."
        
        # Install Rust via rustup (as root, system-wide)
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        
        # Add to system PATH
        if [[ ! -f /etc/profile.d/rust.sh ]]; then
            cat > /etc/profile.d/rust.sh << 'EOF'
export RUSTUP_HOME=/root/.rustup
export CARGO_HOME=/root/.cargo
export PATH="${CARGO_HOME}/bin:${PATH}"
EOF
        fi
        
        # Source for current session
        source /root/.cargo/env 2>/dev/null || true
        
        log_success "Rust installed"
    fi
    
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
    
    # Allow Docker Registry (port 5000)
    log_info "Allowing Docker Registry (port 5000)..."
    ufw allow 5000/tcp comment 'Docker Registry'
    
    # Allow Registry UI (port 8080)
    log_info "Allowing Registry UI (port 8080)..."
    ufw allow 8080/tcp comment 'Registry UI'
    
    # Allow Node Exporter (port 9100) - for Watcher monitoring
    log_info "Allowing Node Exporter (port 9100)..."
    ufw allow 9100/tcp comment 'Node Exporter'
    
    # Allow Gitea (port 3000) - optional Git server
    log_info "Allowing Gitea (port 3000)..."
    ufw allow 3000/tcp comment 'Gitea'
    
    # Allow Gitea SSH (port 2222)
    log_info "Allowing Gitea SSH (port 2222)..."
    ufw allow 2222/tcp comment 'Gitea SSH'
    
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

[docker-registry]
enabled = true
port = 5000
filter = docker-registry
logpath = /opt/kingdom/data/registry/logs/registry.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Docker Registry filter
    REGISTRY_FILTER="/etc/fail2ban/filter.d/docker-registry.conf"
    if [[ ! -f "$REGISTRY_FILTER" ]]; then
        cat > "$REGISTRY_FILTER" << 'EOF'
[Definition]
failregex = ^.*unauthorized.*<HOST>.*$
            ^.*authentication.*failed.*<HOST>.*$
ignoreregex =
EOF
        log_success "Docker Registry fail2ban filter created"
    fi
    
    # Enable and restart Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_success "Fail2Ban configured and running"
}

#-------------------------------------------------------------------------------
# SSH Hardening
#-------------------------------------------------------------------------------
harden_ssh() {
    log_section "Hardening SSH Configuration"
    
    SSH_CONFIG="/etc/ssh/sshd_config.d/99-kingdom-hardening.conf"
    
    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_info "Creating SSH hardening configuration..."
        cat > "$SSH_CONFIG" << 'EOF'
# Kingdom Builder Node SSH Hardening
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
X11Forwarding no
AllowTcpForwarding no
EOF
        log_success "SSH hardening configuration created"
        
        # Test SSH config before restarting
        if sshd -t; then
            systemctl restart sshd
            log_success "SSH service restarted with hardened config"
        else
            log_error "SSH config test failed - reverting"
            rm -f "$SSH_CONFIG"
        fi
    else
        log_info "SSH hardening already configured"
    fi
}

#-------------------------------------------------------------------------------
# Builder Node Directory Structure
#-------------------------------------------------------------------------------
create_directory_structure() {
    log_section "Creating Builder Node Directory Structure"
    
    # Create main directories
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${BUILDS_DIR}"
    mkdir -p "${ARTIFACTS_DIR}"
    mkdir -p "${INSTALL_DIR}/commands"
    mkdir -p "${INSTALL_DIR}/logs"
    
    # Builder-specific directories
    mkdir -p "${DATA_DIR}/registry"
    mkdir -p "${DATA_DIR}/registry/logs"
    mkdir -p "${DATA_DIR}/gitea"
    mkdir -p "${DATA_DIR}/runners"
    mkdir -p "${CONFIG_DIR}/registry"
    mkdir -p "${CONFIG_DIR}/gitea"
    mkdir -p "${CONFIG_DIR}/runners"
    mkdir -p "${BUILDS_DIR}/cache"
    mkdir -p "${BUILDS_DIR}/workspace"
    mkdir -p "${ARTIFACTS_DIR}/images"
    mkdir -p "${ARTIFACTS_DIR}/binaries"
    mkdir -p "${ARTIFACTS_DIR}/packages"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Docker Registry Configuration
#-------------------------------------------------------------------------------
configure_registry() {
    log_section "Configuring Docker Registry"
    
    REGISTRY_CONFIG="${CONFIG_DIR}/registry/config.yml"
    
    if [[ ! -f "$REGISTRY_CONFIG" ]]; then
        log_info "Creating Docker Registry configuration..."
        cat > "$REGISTRY_CONFIG" << 'EOF'
# Docker Registry Configuration for Kingdom Builder
version: 0.1
log:
  level: info
  formatter: json
  fields:
    service: registry
    environment: kingdom
  accesslog:
    disabled: false

storage:
  filesystem:
    rootdirectory: /var/lib/registry
  delete:
    enabled: true
  cache:
    blobdescriptor: inmemory
  maintenance:
    uploadpurging:
      enabled: true
      age: 168h
      interval: 24h
      dryrun: false

http:
  addr: :5000
  headers:
    X-Content-Type-Options: [nosniff]
  http2:
    disabled: false

health:
  storagedriver:
    enabled: true
    interval: 10s
    threshold: 3
EOF
        log_success "Docker Registry configuration created"
    else
        log_info "Docker Registry configuration already exists"
    fi
    
    # Create htpasswd file for registry authentication
    HTPASSWD_FILE="${CONFIG_DIR}/registry/htpasswd"
    if [[ ! -f "$HTPASSWD_FILE" ]]; then
        log_info "Creating registry authentication..."
        # Default credentials: kingdom / kingdom-builder-2024
        htpasswd -Bbn kingdom kingdom-builder-2024 > "$HTPASSWD_FILE"
        log_success "Registry authentication created (user: kingdom)"
    fi
}

#-------------------------------------------------------------------------------
# Gitea Configuration (Optional Git Server)
#-------------------------------------------------------------------------------
configure_gitea() {
    log_section "Configuring Gitea"
    
    GITEA_CONFIG="${CONFIG_DIR}/gitea/app.ini"
    
    if [[ ! -f "$GITEA_CONFIG" ]]; then
        log_info "Creating Gitea configuration..."
        cat > "$GITEA_CONFIG" << 'EOF'
; Gitea Configuration for Kingdom Builder
APP_NAME = Kingdom Builder Git
RUN_MODE = prod
RUN_USER = git

[repository]
ROOT = /data/git/repositories
DEFAULT_BRANCH = main

[server]
DOMAIN = localhost
HTTP_PORT = 3000
ROOT_URL = http://localhost:3000/
DISABLE_SSH = false
SSH_PORT = 2222
START_SSH_SERVER = true
LFS_START_SERVER = true

[database]
DB_TYPE = sqlite3
PATH = /data/gitea/gitea.db

[security]
INSTALL_LOCK = false
SECRET_KEY = 
INTERNAL_TOKEN = 

[service]
DISABLE_REGISTRATION = true
REQUIRE_SIGNIN_VIEW = true
DEFAULT_KEEP_EMAIL_PRIVATE = true

[log]
MODE = file
LEVEL = Info
ROOT_PATH = /data/gitea/log

[actions]
ENABLED = true
DEFAULT_ACTIONS_URL = github
EOF
        log_success "Gitea configuration created"
    else
        log_info "Gitea configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# CI/CD Runner Configuration
#-------------------------------------------------------------------------------
configure_runners() {
    log_section "Configuring CI/CD Runners"
    
    # Create runner configuration template
    RUNNER_CONFIG="${CONFIG_DIR}/runners/runner-config.yml"
    
    if [[ ! -f "$RUNNER_CONFIG" ]]; then
        log_info "Creating runner configuration template..."
        cat > "$RUNNER_CONFIG" << 'EOF'
# Kingdom Builder Runner Configuration
runner:
  name: kingdom-builder-runner
  workdir: /opt/kingdom/builds/workspace
  labels:
    - kingdom
    - builder
    - docker
  
cache:
  enabled: true
  dir: /opt/kingdom/builds/cache
  
container:
  network: kingdom-build
  privileged: false
  
limits:
  memory: 4G
  cpus: 2
EOF
        log_success "Runner configuration template created"
    fi
    
    # Create build script template
    BUILD_SCRIPT="${CONFIG_DIR}/runners/build-template.sh"
    if [[ ! -f "$BUILD_SCRIPT" ]]; then
        cat > "$BUILD_SCRIPT" << 'EOF'
#!/bin/bash
# Kingdom Build Script Template
set -euo pipefail

# Build environment
export BUILD_ID="${BUILD_ID:-$(date +%Y%m%d%H%M%S)}"
export BUILD_DIR="/opt/kingdom/builds/workspace/${BUILD_ID}"
export ARTIFACT_DIR="/opt/kingdom/artifacts"

# Create build directory
mkdir -p "${BUILD_DIR}"
cd "${BUILD_DIR}"

# Clone repository
# git clone "${REPO_URL}" .

# Build steps (customize per project)
echo "Build ${BUILD_ID} started at $(date)"

# Example: Docker build
# docker build -t kingdom/${PROJECT_NAME}:${BUILD_ID} .
# docker tag kingdom/${PROJECT_NAME}:${BUILD_ID} localhost:5000/kingdom/${PROJECT_NAME}:${BUILD_ID}
# docker push localhost:5000/kingdom/${PROJECT_NAME}:${BUILD_ID}

echo "Build ${BUILD_ID} completed at $(date)"
EOF
        chmod +x "$BUILD_SCRIPT"
        log_success "Build script template created"
    fi
}

#-------------------------------------------------------------------------------
# Docker Compose Setup
#-------------------------------------------------------------------------------
create_docker_compose() {
    log_section "Creating Docker Compose Configuration"
    
    COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yaml"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_info "Creating Docker Compose file..."
        cat > "$COMPOSE_FILE" << EOF
# Builder Node Docker Compose - Kingdom CI/CD Stack
version: '3.8'

networks:
  kingdom-build:
    driver: bridge

volumes:
  registry_data:
  gitea_data:
  runner_data:

services:
  # Docker Registry - Image Storage
  registry:
    image: registry:2
    container_name: registry
    restart: unless-stopped
    volumes:
      - registry_data:/var/lib/registry
      - ${CONFIG_DIR}/registry/config.yml:/etc/docker/registry/config.yml:ro
      - ${CONFIG_DIR}/registry/htpasswd:/auth/htpasswd:ro
    environment:
      - REGISTRY_AUTH=htpasswd
      - REGISTRY_AUTH_HTPASSWD_REALM=Kingdom Registry
      - REGISTRY_AUTH_HTPASSWD_PATH=/auth/htpasswd
    ports:
      - "5000:5000"
    networks:
      - kingdom-build

  # Registry UI - Web Interface
  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: registry-ui
    restart: unless-stopped
    environment:
      - SINGLE_REGISTRY=true
      - REGISTRY_TITLE=Kingdom Builder Registry
      - DELETE_IMAGES=true
      - SHOW_CONTENT_DIGEST=true
      - NGINX_PROXY_PASS_URL=http://registry:5000
      - SHOW_CATALOG_NB_TAGS=true
      - CATALOG_MIN_BRANCHES=1
      - CATALOG_MAX_BRANCHES=1
      - TAGLIST_PAGE_SIZE=100
      - REGISTRY_SECURED=false
      - CATALOG_ELEMENTS_LIMIT=1000
    ports:
      - "8080:80"
    networks:
      - kingdom-build
    depends_on:
      - registry

  # Gitea - Git Server (Optional)
  gitea:
    image: gitea/gitea:latest
    container_name: gitea
    restart: unless-stopped
    volumes:
      - gitea_data:/data
      - ${CONFIG_DIR}/gitea:/data/gitea/conf
      - /etc/timezone:/etc/timezone:ro
      - /etc/localtime:/etc/localtime:ro
    environment:
      - USER_UID=1000
      - USER_GID=1000
      - GITEA__database__DB_TYPE=sqlite3
      - GITEA__database__PATH=/data/gitea/gitea.db
    ports:
      - "3000:3000"
      - "2222:22"
    networks:
      - kingdom-build

  # Node Exporter - System Metrics (for Watcher)
  node-exporter:
    image: prom/node-exporter:latest
    container_name: node-exporter
    restart: unless-stopped
    volumes:
      - /proc:/host/proc:ro
      - /sys:/host/sys:ro
      - /:/rootfs:ro
    command:
      - '--path.procfs=/host/proc'
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - kingdom-build

  # Watchtower - Auto-update containers (optional)
  watchtower:
    image: containrrr/watchtower
    container_name: watchtower
    restart: unless-stopped
    volumes:
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - WATCHTOWER_CLEANUP=true
      - WATCHTOWER_POLL_INTERVAL=86400
      - WATCHTOWER_INCLUDE_STOPPED=false
    networks:
      - kingdom-build
EOF
        log_success "Docker Compose file created"
    else
        log_info "Docker Compose file already exists"
    fi
}

#-------------------------------------------------------------------------------
# Create Systemd Service
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Systemd Services"
    
    # Builder Node Service
    if [[ ! -f /etc/systemd/system/builder-node.service ]]; then
        cat > /etc/systemd/system/builder-node.service << EOF
[Unit]
Description=Builder Node - Kingdom CI/CD Stack
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
    
    # Build cleanup timer
    if [[ ! -f /etc/systemd/system/builder-cleanup.timer ]]; then
        cat > /etc/systemd/system/builder-cleanup.service << EOF
[Unit]
Description=Cleanup old builds and artifacts

[Service]
Type=oneshot
ExecStart=/bin/bash -c 'find ${BUILDS_DIR}/workspace -maxdepth 1 -type d -mtime +7 -exec rm -rf {} \; 2>/dev/null || true'
ExecStart=/bin/bash -c 'docker system prune -f --filter "until=168h" 2>/dev/null || true'
EOF

        cat > /etc/systemd/system/builder-cleanup.timer << EOF
[Unit]
Description=Run build cleanup daily

[Timer]
OnCalendar=daily
Persistent=true

[Install]
WantedBy=timers.target
EOF
        systemctl enable builder-cleanup.timer
        log_success "Build cleanup timer created"
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Configure Builder Node
#-------------------------------------------------------------------------------
configure_builder() {
    log_section "Configuring Builder Node"
    
    # Copy helper commands
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    COMMANDS_DIR="${INSTALL_DIR}/commands"
    
    if [[ -d "${SCRIPT_DIR}/commands" ]]; then
        cp "${SCRIPT_DIR}/commands/builder-status.sh" "$COMMANDS_DIR/" 2>/dev/null || true
        chmod +x "$COMMANDS_DIR/"*.sh 2>/dev/null || true
        log_success "Helper commands installed to ${COMMANDS_DIR}"
    fi
    
    # Add commands to PATH via profile.d
    if [[ ! -f /etc/profile.d/kingdom.sh ]]; then
        cat > /etc/profile.d/kingdom.sh << EOF
# Kingdom Builder Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="${NODE_ROLE}"
export PATH="\${PATH}:${COMMANDS_DIR}"

# Rust environment (if installed)
if [[ -f /root/.cargo/env ]]; then
    source /root/.cargo/env
fi
EOF
        log_success "Kingdom environment configured"
    fi
    
    # Create log directory
    mkdir -p /var/log/kingdom
    
    # Configure Docker to use local registry
    DOCKER_DAEMON="/etc/docker/daemon.json"
    if [[ ! -f "$DOCKER_DAEMON" ]]; then
        cat > "$DOCKER_DAEMON" << 'EOF'
{
  "insecure-registries": ["localhost:5000"],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}
EOF
        systemctl restart docker
        log_success "Docker configured for local registry"
    fi
    
    log_success "Builder node configured"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Builder Node Setup Complete"
    
    echo ""
    echo -e "${ORANGE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${ORANGE}║           Builder Node Bootstrap Complete                   ║${NC}"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Role:       ${BLUE}Builder (CI/CD)${NC}"
    echo -e "${ORANGE}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Services:"
    echo -e "${ORANGE}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${ORANGE}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${ORANGE}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Build Stack (after start):"
    echo -e "${ORANGE}║${NC}   - Registry:      http://localhost:5000"
    echo -e "${ORANGE}║${NC}   - Registry UI:   http://localhost:8080"
    echo -e "${ORANGE}║${NC}   - Gitea:         http://localhost:3000"
    echo -e "${ORANGE}║${NC}   - Gitea SSH:     ssh://localhost:2222"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Default Registry Credentials:"
    echo -e "${ORANGE}║${NC}   - Username: kingdom"
    echo -e "${ORANGE}║${NC}   - Password: kingdom-builder-2024"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Build Tools Installed:"
    echo -e "${ORANGE}║${NC}   - Node.js:   $(node --version 2>/dev/null || echo 'not installed')"
    echo -e "${ORANGE}║${NC}   - npm:       $(npm --version 2>/dev/null || echo 'not installed')"
    echo -e "${ORANGE}║${NC}   - Rust:      $(rustc --version 2>/dev/null || echo 'not installed')"
    echo -e "${ORANGE}║${NC}   - Docker:    $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',')"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Next Steps:"
    echo -e "${ORANGE}║${NC}   1. Start services: systemctl start builder-node"
    echo -e "${ORANGE}║${NC}   2. Change registry password"
    echo -e "${ORANGE}║${NC}   3. Configure Gitea (first-run setup)"
    echo -e "${ORANGE}║${NC}   4. Add to Watcher monitoring"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Helper Commands (after re-login):"
    echo -e "${ORANGE}║${NC}   - builder-status.sh  - Show build status"
    echo -e "${ORANGE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Builder Node Bootstrap - Kingdom CI/CD"
    log_info "Starting bootstrap at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    install_nodejs
    install_rust
    configure_firewall
    configure_fail2ban
    harden_ssh
    create_directory_structure
    configure_registry
    configure_gitea
    configure_runners
    create_docker_compose
    create_services
    configure_builder
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
