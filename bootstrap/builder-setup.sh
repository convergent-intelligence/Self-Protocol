#!/bin/bash
#===============================================================================
# Builder Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Builder in Kingdom Hierarchy
# Purpose: CI/CD, artifact building, deployments
# Integrates: Docker Registry, Build Tools, CI Runner
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
DOMAIN="${BUILDER_DOMAIN:-builder.kingdom.local}"
NODE_ROLE="builder"
INSTALL_DIR="/opt/kingdom"
DATA_DIR="${INSTALL_DIR}/data"
BUILD_DIR="${INSTALL_DIR}/builds"
REGISTRY_DIR="${INSTALL_DIR}/registry"
ARTIFACTS_DIR="${INSTALL_DIR}/artifacts"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
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
    echo -e "${MAGENTA}========================================${NC}"
    echo -e "${MAGENTA} $1${NC}"
    echo -e "${MAGENTA}========================================${NC}"
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
        certbot
        python3-certbot-nginx
        nginx
        python3
        python3-pip
        python3-venv
        jq
        htop
        tmux
        unzip
        build-essential
        make
        gcc
        g++
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
    
    # Enable Docker BuildKit by default
    if [[ ! -f /etc/docker/daemon.json ]]; then
        cat > /etc/docker/daemon.json << 'EOF'
{
  "features": {
    "buildkit": true
  },
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF
        systemctl restart docker
        log_success "Docker BuildKit enabled"
    fi
    
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
    
    # Install common build tools
    npm install -g yarn pnpm typescript 2>/dev/null || true
    
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
        
        # Install Rust via rustup (as root, system-wide)
        curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
        
        # Add to system PATH
        if [[ ! -f /etc/profile.d/rust.sh ]]; then
            cat > /etc/profile.d/rust.sh << 'EOF'
export RUSTUP_HOME="/root/.rustup"
export CARGO_HOME="/root/.cargo"
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
# Go Installation
#-------------------------------------------------------------------------------
install_go() {
    log_section "Installing Go"
    
    GO_VERSION="1.21.6"
    
    # Check if Go is already installed
    if command -v go &> /dev/null; then
        log_info "Go already installed: $(go version)"
    else
        log_info "Installing Go ${GO_VERSION}..."
        
        # Download and install Go
        wget -q "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -O /tmp/go.tar.gz
        rm -rf /usr/local/go
        tar -C /usr/local -xzf /tmp/go.tar.gz
        rm /tmp/go.tar.gz
        
        # Add to system PATH
        if [[ ! -f /etc/profile.d/go.sh ]]; then
            cat > /etc/profile.d/go.sh << 'EOF'
export GOROOT="/usr/local/go"
export GOPATH="/opt/kingdom/go"
export PATH="${GOROOT}/bin:${GOPATH}/bin:${PATH}"
EOF
        fi
        
        log_success "Go installed"
    fi
    
    log_success "Go setup complete"
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
    
    # Allow HTTP (port 80) for Let's Encrypt and redirects
    log_info "Allowing HTTP (port 80)..."
    ufw allow 80/tcp comment 'HTTP'
    
    # Allow HTTPS (port 443) for secure traffic
    log_info "Allowing HTTPS (port 443)..."
    ufw allow 443/tcp comment 'HTTPS'
    
    # Allow Docker Registry (port 5000) - internal only
    log_info "Allowing Docker Registry (port 5000) from internal..."
    ufw allow from 10.0.0.0/8 to any port 5000 proto tcp comment 'Docker Registry Internal'
    
    # Allow CI Runner webhook (port 8080) - internal only
    log_info "Allowing CI webhook (port 8080) from internal..."
    ufw allow from 10.0.0.0/8 to any port 8080 proto tcp comment 'CI Webhook Internal'
    
    # Allow Node Exporter (port 9100) - for Watcher to scrape
    log_info "Allowing Node Exporter (port 9100) from internal..."
    ufw allow from 10.0.0.0/8 to any port 9100 proto tcp comment 'Node Exporter'
    
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

[nginx-http-auth]
enabled = true
port = http,https
filter = nginx-http-auth
logpath = /var/log/nginx/error.log
maxretry = 3

[nginx-botsearch]
enabled = true
port = http,https
filter = nginx-botsearch
logpath = /var/log/nginx/access.log
maxretry = 2

[docker-registry]
enabled = true
port = 5000
filter = docker-registry
logpath = /opt/kingdom/logs/registry.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Docker Registry filter for Fail2Ban
    if [[ ! -f /etc/fail2ban/filter.d/docker-registry.conf ]]; then
        cat > /etc/fail2ban/filter.d/docker-registry.conf << 'EOF'
[Definition]
failregex = ^.*unauthorized.*addr="<HOST>.*$
            ^.*authentication failed.*addr="<HOST>.*$
ignoreregex =
EOF
        log_success "Docker Registry Fail2Ban filter created"
    fi
    
    # Enable and restart Fail2Ban
    systemctl enable fail2ban
    systemctl restart fail2ban
    
    log_success "Fail2Ban configured and running"
}

#-------------------------------------------------------------------------------
# Nginx Configuration
#-------------------------------------------------------------------------------
configure_nginx() {
    log_section "Configuring Nginx"
    
    NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"
    
    # Create initial HTTP-only config (for Let's Encrypt)
    if [[ ! -f "$NGINX_CONF" ]]; then
        log_info "Creating Nginx configuration for ${DOMAIN}..."
        cat > "$NGINX_CONF" << EOF
# Builder Node - ${DOMAIN}
# CI/CD and Artifact Building Gateway

# Increase client body size for large artifacts
client_max_body_size 500M;

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Root location - Builder dashboard
    location / {
        root /var/www/${DOMAIN};
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # Docker Registry proxy (v2 API)
    location /v2/ {
        proxy_pass http://127.0.0.1:5000;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 900;
        # Required for large image pushes
        client_max_body_size 0;
        chunked_transfer_encoding on;
    }
    
    # CI Webhook endpoint
    location /webhook/ {
        proxy_pass http://127.0.0.1:8080/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-GitHub-Event \$http_x_github_event;
        proxy_set_header X-GitHub-Delivery \$http_x_github_delivery;
        proxy_set_header X-Hub-Signature \$http_x_hub_signature;
        proxy_set_header X-Hub-Signature-256 \$http_x_hub_signature_256;
    }
    
    # Artifacts download
    location /artifacts/ {
        alias ${ARTIFACTS_DIR}/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
    
    # Build logs (protected)
    location /logs/ {
        alias ${INSTALL_DIR}/logs/;
        autoindex on;
        # auth_basic "Build Logs";
        # auth_basic_user_file /etc/nginx/.htpasswd;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "Builder Node OK\\n";
        add_header Content-Type text/plain;
    }
}
EOF
        log_success "Nginx configuration created"
    else
        log_info "Nginx configuration already exists"
    fi
    
    # Create web root directory
    mkdir -p "/var/www/${DOMAIN}"
    
    # Create placeholder index
    if [[ ! -f "/var/www/${DOMAIN}/index.html" ]]; then
        cat > "/var/www/${DOMAIN}/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Builder Node - Kingdom Network</title>
    <style>
        body { font-family: system-ui; background: #0a0a0a; color: #e0e0e0; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { color: #f59e0b; }
        .status { color: #22c55e; }
        .links { margin-top: 2rem; }
        .links a { color: #f59e0b; margin: 0 1rem; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔨 Builder Node</h1>
        <p class="status">Node Status: Active</p>
        <p>Role: Builder in Kingdom Hierarchy</p>
        <p>Purpose: CI/CD, Artifact Building, Deployments</p>
        <div class="links">
            <a href="/v2/">Docker Registry</a>
            <a href="/artifacts/">Artifacts</a>
        </div>
    </div>
</body>
</html>
EOF
    fi
    
    # Enable site (idempotent)
    ln -sf "$NGINX_CONF" /etc/nginx/sites-enabled/
    
    # Remove default site if exists
    rm -f /etc/nginx/sites-enabled/default
    
    # Test and reload Nginx
    nginx -t
    systemctl enable nginx
    systemctl reload nginx
    
    log_success "Nginx configured for ${DOMAIN}"
}

#-------------------------------------------------------------------------------
# SSL Certificate Setup (Let's Encrypt)
#-------------------------------------------------------------------------------
setup_ssl() {
    log_section "Setting Up SSL Certificate"
    
    # Check if certificate already exists
    if [[ -d "/etc/letsencrypt/live/${DOMAIN}" ]]; then
        log_info "SSL certificate already exists for ${DOMAIN}"
        log_info "Attempting renewal check..."
        certbot renew --dry-run || true
    else
        log_info "Obtaining SSL certificate for ${DOMAIN}..."
        log_warn "Make sure DNS is pointing to this server!"
        
        # Obtain certificate (will fail gracefully if DNS not ready)
        certbot --nginx \
            -d "${DOMAIN}" \
            --non-interactive \
            --agree-tos \
            --email "admin@${DOMAIN}" \
            --redirect \
            || log_warn "SSL setup failed - ensure DNS is configured and run: certbot --nginx -d ${DOMAIN}"
    fi
    
    # Setup auto-renewal cron (certbot package usually does this, but ensure it)
    if ! crontab -l 2>/dev/null | grep -q certbot; then
        log_info "Setting up SSL auto-renewal..."
        (crontab -l 2>/dev/null; echo "0 3 * * * certbot renew --quiet --post-hook 'systemctl reload nginx'") | crontab -
    fi
    
    log_success "SSL setup complete"
}

#-------------------------------------------------------------------------------
# Create Directory Structure
#-------------------------------------------------------------------------------
create_directories() {
    log_section "Creating Directory Structure"
    
    # Create main directories
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${BUILD_DIR}"
    mkdir -p "${REGISTRY_DIR}"
    mkdir -p "${ARTIFACTS_DIR}"
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/commands"
    mkdir -p "${INSTALL_DIR}/logs"
    mkdir -p "${INSTALL_DIR}/go"
    
    # Build-specific directories
    mkdir -p "${BUILD_DIR}/workspace"
    mkdir -p "${BUILD_DIR}/cache"
    mkdir -p "${BUILD_DIR}/scripts"
    mkdir -p "${REGISTRY_DIR}/data"
    mkdir -p "${REGISTRY_DIR}/auth"
    mkdir -p "${ARTIFACTS_DIR}/releases"
    mkdir -p "${ARTIFACTS_DIR}/snapshots"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Configure Docker Registry
#-------------------------------------------------------------------------------
configure_registry() {
    log_section "Configuring Docker Registry"
    
    REGISTRY_CONFIG="${REGISTRY_DIR}/config.yml"
    
    if [[ ! -f "$REGISTRY_CONFIG" ]]; then
        log_info "Creating Docker Registry configuration..."
        cat > "$REGISTRY_CONFIG" << EOF
# Docker Registry Configuration for Kingdom Builder Node
version: 0.1
log:
  level: info
  formatter: json
  fields:
    service: registry
    environment: kingdom
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
    
    # Create htpasswd file for registry authentication (optional)
    if [[ ! -f "${REGISTRY_DIR}/auth/htpasswd" ]]; then
        log_info "Creating registry authentication..."
        # Default credentials: kingdom / kingdom-builder
        htpasswd -Bbn kingdom kingdom-builder > "${REGISTRY_DIR}/auth/htpasswd"
        log_success "Registry authentication created (user: kingdom)"
    fi
}

#-------------------------------------------------------------------------------
# Configure CI Runner
#-------------------------------------------------------------------------------
configure_ci_runner() {
    log_section "Configuring CI Runner"
    
    CI_CONFIG="${INSTALL_DIR}/config/ci-runner.yaml"
    
    if [[ ! -f "$CI_CONFIG" ]]; then
        log_info "Creating CI Runner configuration..."
        cat > "$CI_CONFIG" << EOF
# CI Runner Configuration for Kingdom Builder Node
runner:
  name: kingdom-builder
  workdir: ${BUILD_DIR}/workspace
  concurrent: 2
  
webhook:
  port: 8080
  secret: kingdom-webhook-secret-change-me
  
builds:
  timeout: 3600
  cache_dir: ${BUILD_DIR}/cache
  artifacts_dir: ${ARTIFACTS_DIR}
  
docker:
  registry: localhost:5000
  build_args:
    - KINGDOM_BUILD=true
    
notifications:
  # Configure Slack, Discord, or webhook notifications
  # slack:
  #   webhook_url: https://hooks.slack.com/services/xxx
  #   channel: "#kingdom-builds"
EOF
        log_success "CI Runner configuration created"
    else
        log_info "CI Runner configuration already exists"
    fi
    
    # Create build scripts directory with example
    BUILD_SCRIPTS="${BUILD_DIR}/scripts"
    
    if [[ ! -f "${BUILD_SCRIPTS}/build-docker.sh" ]]; then
        cat > "${BUILD_SCRIPTS}/build-docker.sh" << 'EOF'
#!/bin/bash
# Kingdom Docker Build Script
set -euo pipefail

REPO_NAME="${1:-}"
TAG="${2:-latest}"
DOCKERFILE="${3:-Dockerfile}"

if [[ -z "$REPO_NAME" ]]; then
    echo "Usage: build-docker.sh <repo-name> [tag] [dockerfile]"
    exit 1
fi

REGISTRY="localhost:5000"
IMAGE="${REGISTRY}/${REPO_NAME}:${TAG}"

echo "Building ${IMAGE}..."
docker build -t "${IMAGE}" -f "${DOCKERFILE}" .

echo "Pushing ${IMAGE}..."
docker push "${IMAGE}"

echo "Build complete: ${IMAGE}"
EOF
        chmod +x "${BUILD_SCRIPTS}/build-docker.sh"
        log_success "Build scripts created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Builder Node
#-------------------------------------------------------------------------------
configure_builder() {
    log_section "Configuring Builder Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    # Create builder node configuration
    if [[ ! -f "${CONFIG_DIR}/builder.yaml" ]]; then
        cat > "${CONFIG_DIR}/builder.yaml" << EOF
# Builder Node Configuration
node:
  role: builder
  domain: ${DOMAIN}
  
registry:
  port: 5000
  storage: ${REGISTRY_DIR}/data
  
ci:
  webhook_port: 8080
  workspace: ${BUILD_DIR}/workspace
  
artifacts:
  releases: ${ARTIFACTS_DIR}/releases
  snapshots: ${ARTIFACTS_DIR}/snapshots
  
languages:
  nodejs: true
  rust: true
  go: true
  python: true
EOF
        log_success "Builder configuration created"
    fi
    
    # Copy commands directory
    COMMANDS_DIR="${INSTALL_DIR}/commands"
    mkdir -p "$COMMANDS_DIR"
    
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
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
export KINGDOM_ROLE="builder"
export PATH="\${PATH}:${COMMANDS_DIR}:${BUILD_DIR}/scripts"
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
Description=Builder Node - Kingdom Network CI/CD
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
    
    # Create docker-compose.yaml for build stack
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Builder Node Docker Compose - CI/CD Stack
version: '3.8'

networks:
  builder:
    driver: bridge

volumes:
  registry_data:

services:
  # Docker Registry
  registry:
    image: registry:2
    container_name: registry
    restart: unless-stopped
    volumes:
      - ${REGISTRY_DIR}/data:/var/lib/registry
      - ${REGISTRY_DIR}/config.yml:/etc/docker/registry/config.yml:ro
      # Uncomment for authentication:
      # - ${REGISTRY_DIR}/auth:/auth:ro
    environment:
      # Uncomment for authentication:
      # REGISTRY_AUTH: htpasswd
      # REGISTRY_AUTH_HTPASSWD_REALM: Kingdom Registry
      # REGISTRY_AUTH_HTPASSWD_PATH: /auth/htpasswd
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    ports:
      - "127.0.0.1:5000:5000"
    networks:
      - builder

  # CI Runner / Webhook Handler
  ci-runner:
    image: node:20-alpine
    container_name: ci-runner
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${BUILD_DIR}:/builds
      - ${ARTIFACTS_DIR}:/artifacts
      - ${INSTALL_DIR}/config:/config:ro
      - /var/run/docker.sock:/var/run/docker.sock
    environment:
      - KINGDOM_ROLE=builder
      - BUILD_DIR=/builds
      - ARTIFACTS_DIR=/artifacts
    ports:
      - "127.0.0.1:8080:8080"
    networks:
      - builder
    command: >
      sh -c "echo 'CI Runner placeholder - configure your CI system' && 
             while true; do sleep 3600; done"

  # Node Exporter - System Metrics
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
      - '--path.sysfs=/host/sys'
      - '--path.rootfs=/rootfs'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - builder

  # Registry UI (optional)
  registry-ui:
    image: joxit/docker-registry-ui:latest
    container_name: registry-ui
    restart: unless-stopped
    environment:
      - REGISTRY_TITLE=Kingdom Registry
      - REGISTRY_URL=http://registry:5000
      - SINGLE_REGISTRY=true
      - DELETE_IMAGES=true
    ports:
      - "127.0.0.1:8081:80"
    networks:
      - builder
    depends_on:
      - registry
EOF
        log_success "Docker compose configuration created"
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Builder Node Setup Complete"
    
    echo ""
    echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║           Builder Node Bootstrap Complete                   ║${NC}"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${MAGENTA}║${NC} Role:       ${BLUE}Builder${NC}"
    echo -e "${MAGENTA}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC} Services:"
    echo -e "${MAGENTA}║${NC}   - Nginx:     $(systemctl is-active nginx)"
    echo -e "${MAGENTA}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${MAGENTA}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${MAGENTA}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC} Build Stack:"
    echo -e "${MAGENTA}║${NC}   - Docker Registry: http://localhost:5000"
    echo -e "${MAGENTA}║${NC}   - Registry UI:     http://localhost:8081"
    echo -e "${MAGENTA}║${NC}   - CI Webhook:      http://localhost:8080"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC} Languages Installed:"
    echo -e "${MAGENTA}║${NC}   - Node.js: $(node --version 2>/dev/null || echo 'not found')"
    echo -e "${MAGENTA}║${NC}   - Rust:    $(rustc --version 2>/dev/null || echo 'not found')"
    echo -e "${MAGENTA}║${NC}   - Go:      $(go version 2>/dev/null | awk '{print $3}' || echo 'not found')"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC} Next Steps:"
    echo -e "${MAGENTA}║${NC}   1. Verify DNS points to this server"
    echo -e "${MAGENTA}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${MAGENTA}║${NC}   3. Start services: systemctl start builder-node"
    echo -e "${MAGENTA}║${NC}   4. Configure CI webhooks for your repositories"
    echo -e "${MAGENTA}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${MAGENTA}║${NC} Helper Commands (after re-login):"
    echo -e "${MAGENTA}║${NC}   - builder-status.sh  - Show builder status"
    echo -e "${MAGENTA}║${NC}   - build-docker.sh    - Build and push Docker images"
    echo -e "${MAGENTA}║${NC}   - status.sh          - Show node status"
    echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════╝${NC}"
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
    install_go
    configure_firewall
    configure_fail2ban
    create_directories
    configure_registry
    configure_ci_runner
    configure_nginx
    setup_ssl
    configure_builder
    create_services
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
