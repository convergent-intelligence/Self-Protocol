#!/bin/bash
#===============================================================================
# Builder Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Builder in Kingdom Hierarchy
# Purpose: CI/CD, artifact building, deployments
# Installs: Docker registry, build tools, CI runner capabilities
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
CONFIG_DIR="${INSTALL_DIR}/config"
ARTIFACTS_DIR="${INSTALL_DIR}/artifacts"
BUILDS_DIR="${INSTALL_DIR}/builds"

# Ports
REGISTRY_PORT=5000
REGISTRY_UI_PORT=5001
RUNNER_PORT=8080
WEBHOOK_PORT=9000

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
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
    
    # Check available disk space (builders need more space)
    AVAILABLE_SPACE=$(df -BG / | awk 'NR==2 {print $4}' | tr -d 'G')
    if [[ "$AVAILABLE_SPACE" -lt 20 ]]; then
        log_warn "Low disk space: ${AVAILABLE_SPACE}GB available. Recommend at least 20GB for builds."
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
        # Build tools
        build-essential
        gcc
        g++
        make
        cmake
        pkg-config
        libssl-dev
        # Additional utilities
        zip
        unzip
        rsync
        apache2-utils  # For htpasswd
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
    
    # Configure Docker for builds (increase limits)
    if [[ ! -f /etc/docker/daemon.json ]]; then
        log_info "Configuring Docker daemon for builds..."
        cat > /etc/docker/daemon.json << 'EOF'
{
  "storage-driver": "overlay2",
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "100m",
    "max-file": "3"
  },
  "insecure-registries": ["localhost:5000"],
  "features": {
    "buildkit": true
  }
}
EOF
        systemctl restart docker
        log_success "Docker daemon configured"
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
    log_info "Installing global npm packages..."
    npm install -g yarn pnpm typescript 2>/dev/null || true
    
    log_success "Node.js setup complete"
}

#-------------------------------------------------------------------------------
# Rust Installation (for Rust builds)
#-------------------------------------------------------------------------------
install_rust() {
    log_section "Installing Rust"
    
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
    
    # Builder-specific ports
    log_info "Allowing Docker Registry (port ${REGISTRY_PORT})..."
    ufw allow ${REGISTRY_PORT}/tcp comment 'Docker Registry'
    
    log_info "Allowing Registry UI (port ${REGISTRY_UI_PORT})..."
    ufw allow ${REGISTRY_UI_PORT}/tcp comment 'Registry UI'
    
    log_info "Allowing CI Runner (port ${RUNNER_PORT})..."
    ufw allow ${RUNNER_PORT}/tcp comment 'CI Runner'
    
    log_info "Allowing Webhook (port ${WEBHOOK_PORT})..."
    ufw allow ${WEBHOOK_PORT}/tcp comment 'Webhook'
    
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
port = 5000,5001
filter = docker-registry
logpath = /opt/kingdom/data/registry/logs/*.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Docker registry filter if it doesn't exist
    if [[ ! -f /etc/fail2ban/filter.d/docker-registry.conf ]]; then
        cat > /etc/fail2ban/filter.d/docker-registry.conf << 'EOF'
[Definition]
failregex = ^.*unauthorized.*addr="<HOST>.*$
            ^.*authentication failure.*addr="<HOST>.*$
ignoreregex =
EOF
        log_success "Docker registry fail2ban filter created"
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
# Initial HTTP configuration (SSL will be added by Certbot)

# Increase client body size for large artifacts
client_max_body_size 2G;

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
    
    # Docker Registry proxy
    location /v2/ {
        proxy_pass http://127.0.0.1:${REGISTRY_PORT};
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_read_timeout 900;
        client_max_body_size 2G;
    }
    
    # Registry UI proxy
    location /registry/ {
        proxy_pass http://127.0.0.1:${REGISTRY_UI_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # CI Runner / Build status
    location /builds/ {
        proxy_pass http://127.0.0.1:${RUNNER_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Webhook endpoint
    location /webhook/ {
        proxy_pass http://127.0.0.1:${WEBHOOK_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
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
    <title>Builder Node - ${DOMAIN}</title>
    <style>
        body { font-family: system-ui; background: #0a0a0a; color: #e0e0e0; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { color: #f59e0b; }
        .status { color: #22c55e; }
        .links { margin-top: 2rem; }
        .links a { color: #fbbf24; margin: 0 1rem; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>🔨 Builder Node</h1>
        <p class="status">Node Status: Initializing</p>
        <p>Domain: ${DOMAIN}</p>
        <p>Role: Builder in Kingdom Hierarchy</p>
        <div class="links">
            <a href="/registry/">Registry UI</a>
            <a href="/builds/">Build Status</a>
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
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${ARTIFACTS_DIR}"
    mkdir -p "${BUILDS_DIR}"
    
    # Builder-specific directories
    mkdir -p "${DATA_DIR}/registry"
    mkdir -p "${DATA_DIR}/registry/logs"
    mkdir -p "${CONFIG_DIR}/registry"
    mkdir -p "${CONFIG_DIR}/runner"
    mkdir -p "${CONFIG_DIR}/webhook"
    mkdir -p "${BUILDS_DIR}/logs"
    mkdir -p "${BUILDS_DIR}/workspace"
    mkdir -p "${ARTIFACTS_DIR}/releases"
    mkdir -p "${ARTIFACTS_DIR}/snapshots"
    
    # Create build scripts directory
    mkdir -p "${INSTALL_DIR}/scripts"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Configure Docker Registry
#-------------------------------------------------------------------------------
configure_registry() {
    log_section "Configuring Docker Registry"
    
    REGISTRY_CONFIG="${CONFIG_DIR}/registry/config.yml"
    
    if [[ ! -f "$REGISTRY_CONFIG" ]]; then
        log_info "Creating Docker Registry configuration..."
        cat > "$REGISTRY_CONFIG" << 'EOF'
# Docker Registry Configuration for Kingdom Builder Node
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
        # Generate a random password for the default user
        REGISTRY_PASSWORD=$(openssl rand -base64 16)
        htpasswd -Bbn kingdom "${REGISTRY_PASSWORD}" > "$HTPASSWD_FILE"
        
        # Save credentials
        cat > "${CONFIG_DIR}/registry/credentials.txt" << EOF
# Docker Registry Credentials
# Generated: $(date)
Username: kingdom
Password: ${REGISTRY_PASSWORD}

# To login:
# docker login ${DOMAIN}:${REGISTRY_PORT} -u kingdom -p ${REGISTRY_PASSWORD}
EOF
        chmod 600 "${CONFIG_DIR}/registry/credentials.txt"
        log_success "Registry authentication configured"
        log_warn "Registry credentials saved to ${CONFIG_DIR}/registry/credentials.txt"
    fi
}

#-------------------------------------------------------------------------------
# Configure CI Runner
#-------------------------------------------------------------------------------
configure_runner() {
    log_section "Configuring CI Runner"
    
    RUNNER_CONFIG="${CONFIG_DIR}/runner/config.json"
    
    if [[ ! -f "$RUNNER_CONFIG" ]]; then
        log_info "Creating CI Runner configuration..."
        cat > "$RUNNER_CONFIG" << EOF
{
  "name": "kingdom-builder",
  "workdir": "${BUILDS_DIR}/workspace",
  "artifacts_dir": "${ARTIFACTS_DIR}",
  "logs_dir": "${BUILDS_DIR}/logs",
  "concurrent_builds": 2,
  "timeout_minutes": 60,
  "cleanup_after_days": 7,
  "docker": {
    "enabled": true,
    "network": "builder-network",
    "registry": "localhost:${REGISTRY_PORT}"
  },
  "notifications": {
    "enabled": false,
    "webhook_url": ""
  }
}
EOF
        log_success "CI Runner configuration created"
    else
        log_info "CI Runner configuration already exists"
    fi
    
    # Create build script template
    if [[ ! -f "${INSTALL_DIR}/scripts/build-template.sh" ]]; then
        cat > "${INSTALL_DIR}/scripts/build-template.sh" << 'EOF'
#!/bin/bash
#===============================================================================
# Build Script Template
# Copy and customize for your project
#===============================================================================

set -euo pipefail

# Build configuration
PROJECT_NAME="${PROJECT_NAME:-myproject}"
BUILD_NUMBER="${BUILD_NUMBER:-0}"
GIT_COMMIT="${GIT_COMMIT:-unknown}"
BUILD_DIR="${BUILD_DIR:-/opt/kingdom/builds/workspace}"
ARTIFACTS_DIR="${ARTIFACTS_DIR:-/opt/kingdom/artifacts}"

echo "=== Building ${PROJECT_NAME} #${BUILD_NUMBER} ==="
echo "Commit: ${GIT_COMMIT}"
echo "Build Dir: ${BUILD_DIR}"

# Clone/update repository
# git clone <repo> ${BUILD_DIR}/${PROJECT_NAME} || git -C ${BUILD_DIR}/${PROJECT_NAME} pull

# Run build commands
# cd ${BUILD_DIR}/${PROJECT_NAME}
# npm install && npm run build
# OR
# cargo build --release
# OR
# docker build -t ${PROJECT_NAME}:${BUILD_NUMBER} .

# Copy artifacts
# cp -r dist/* ${ARTIFACTS_DIR}/releases/${PROJECT_NAME}/${BUILD_NUMBER}/

echo "=== Build Complete ==="
EOF
        chmod +x "${INSTALL_DIR}/scripts/build-template.sh"
        log_success "Build script template created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Webhook Handler
#-------------------------------------------------------------------------------
configure_webhook() {
    log_section "Configuring Webhook Handler"
    
    WEBHOOK_CONFIG="${CONFIG_DIR}/webhook/hooks.json"
    
    if [[ ! -f "$WEBHOOK_CONFIG" ]]; then
        log_info "Creating Webhook configuration..."
        cat > "$WEBHOOK_CONFIG" << EOF
[
  {
    "id": "kingdom-build",
    "execute-command": "${INSTALL_DIR}/scripts/webhook-handler.sh",
    "command-working-directory": "${BUILDS_DIR}/workspace",
    "pass-arguments-to-command": [
      {
        "source": "payload",
        "name": "repository.full_name"
      },
      {
        "source": "payload",
        "name": "ref"
      },
      {
        "source": "payload",
        "name": "after"
      }
    ],
    "trigger-rule": {
      "and": [
        {
          "match": {
            "type": "payload-hmac-sha256",
            "secret": "CHANGE_THIS_SECRET",
            "parameter": {
              "source": "header",
              "name": "X-Hub-Signature-256"
            }
          }
        }
      ]
    }
  }
]
EOF
        log_success "Webhook configuration created"
        log_warn "Remember to update the webhook secret in ${WEBHOOK_CONFIG}"
    fi
    
    # Create webhook handler script
    if [[ ! -f "${INSTALL_DIR}/scripts/webhook-handler.sh" ]]; then
        cat > "${INSTALL_DIR}/scripts/webhook-handler.sh" << 'EOF'
#!/bin/bash
#===============================================================================
# Webhook Handler Script
# Triggered by GitHub/GitLab webhooks
#===============================================================================

set -euo pipefail

REPO_NAME="${1:-unknown}"
REF="${2:-unknown}"
COMMIT="${3:-unknown}"

LOG_DIR="/opt/kingdom/builds/logs"
LOG_FILE="${LOG_DIR}/webhook-$(date +%Y%m%d-%H%M%S).log"

exec > >(tee -a "$LOG_FILE") 2>&1

echo "=== Webhook Received ==="
echo "Repository: ${REPO_NAME}"
echo "Ref: ${REF}"
echo "Commit: ${COMMIT}"
echo "Time: $(date)"

# Extract branch name
BRANCH=$(echo "$REF" | sed 's|refs/heads/||')

# Only build main/master branches by default
if [[ "$BRANCH" != "main" && "$BRANCH" != "master" ]]; then
    echo "Skipping build for branch: ${BRANCH}"
    exit 0
fi

echo "Starting build for ${REPO_NAME}@${BRANCH}..."

# Add your build logic here
# Example:
# cd /opt/kingdom/builds/workspace
# git clone https://github.com/${REPO_NAME}.git || git -C ${REPO_NAME} pull
# cd ${REPO_NAME}
# ./build.sh

echo "=== Webhook Processing Complete ==="
EOF
        chmod +x "${INSTALL_DIR}/scripts/webhook-handler.sh"
        log_success "Webhook handler script created"
    fi
}

#-------------------------------------------------------------------------------
# Builder Node Configuration
#-------------------------------------------------------------------------------
configure_builder() {
    log_section "Configuring Builder Node"
    
    # Copy commands directory and helper scripts
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
export PATH="\${PATH}:${COMMANDS_DIR}:${INSTALL_DIR}/scripts"
export DOCKER_REGISTRY="localhost:${REGISTRY_PORT}"
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
    
    # Create docker-compose.yaml for builder stack
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Builder Node Docker Compose - CI/CD Stack
# Docker Registry + Registry UI + Webhook Handler

version: '3.8'

networks:
  builder-network:
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
      - ${DATA_DIR}/registry:/var/lib/registry
      - ${CONFIG_DIR}/registry/config.yml:/etc/docker/registry/config.yml:ro
    environment:
      REGISTRY_HTTP_ADDR: 0.0.0.0:5000
      REGISTRY_STORAGE_DELETE_ENABLED: "true"
    ports:
      - "127.0.0.1:${REGISTRY_PORT}:5000"
    networks:
      - builder-network

  # Registry UI
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
      - "127.0.0.1:${REGISTRY_UI_PORT}:80"
    networks:
      - builder-network
    depends_on:
      - registry

  # Webhook Handler
  webhook:
    image: almir/webhook:latest
    container_name: webhook
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/webhook:/etc/webhook:ro
      - ${INSTALL_DIR}/scripts:/scripts:ro
      - ${BUILDS_DIR}:/builds
      - ${ARTIFACTS_DIR}:/artifacts
      - /var/run/docker.sock:/var/run/docker.sock
    command: -verbose -hooks=/etc/webhook/hooks.json -hotreload
    ports:
      - "127.0.0.1:${WEBHOOK_PORT}:9000"
    networks:
      - builder-network

  # Build Runner (simple task runner)
  runner:
    image: docker:dind
    container_name: runner
    restart: unless-stopped
    privileged: true
    volumes:
      - ${BUILDS_DIR}/workspace:/workspace
      - ${ARTIFACTS_DIR}:/artifacts
      - ${INSTALL_DIR}/scripts:/scripts:ro
      - ${CONFIG_DIR}/runner:/config:ro
    environment:
      - DOCKER_TLS_CERTDIR=
    networks:
      - builder-network
    depends_on:
      - registry

  # Cleanup job (runs daily)
  cleanup:
    image: alpine:latest
    container_name: cleanup
    restart: "no"
    volumes:
      - ${BUILDS_DIR}:/builds
      - ${ARTIFACTS_DIR}:/artifacts
    command: >
      sh -c "
        echo 'Cleaning up old builds...'
        find /builds/workspace -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true
        find /builds/logs -type f -mtime +30 -delete 2>/dev/null || true
        find /artifacts/snapshots -type f -mtime +14 -delete 2>/dev/null || true
        echo 'Cleanup complete'
      "
    profiles:
      - cleanup
EOF
        log_success "Docker compose configuration created"
    fi
    
    # Create cleanup cron job
    if ! crontab -l 2>/dev/null | grep -q "builder cleanup"; then
        log_info "Setting up cleanup cron job..."
        (crontab -l 2>/dev/null; echo "0 4 * * * cd ${INSTALL_DIR} && docker compose --profile cleanup run --rm cleanup # builder cleanup") | crontab -
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
    echo -e "${ORANGE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${ORANGE}║           Builder Node Bootstrap Complete                   ║${NC}"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${ORANGE}║${NC} Role:       ${BLUE}Builder${NC}"
    echo -e "${ORANGE}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Services:"
    echo -e "${ORANGE}║${NC}   - Nginx:     $(systemctl is-active nginx)"
    echo -e "${ORANGE}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${ORANGE}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${ORANGE}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Builder Stack Ports:"
    echo -e "${ORANGE}║${NC}   - Registry:      ${REGISTRY_PORT}"
    echo -e "${ORANGE}║${NC}   - Registry UI:   ${REGISTRY_UI_PORT}"
    echo -e "${ORANGE}║${NC}   - CI Runner:     ${RUNNER_PORT}"
    echo -e "${ORANGE}║${NC}   - Webhook:       ${WEBHOOK_PORT}"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Next Steps:"
    echo -e "${ORANGE}║${NC}   1. Verify DNS points to this server"
    echo -e "${ORANGE}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${ORANGE}║${NC}   3. Update webhook secret in config"
    echo -e "${ORANGE}║${NC}   4. Start services: systemctl start builder-node"
    echo -e "${ORANGE}║${NC}   5. Check registry credentials in:"
    echo -e "${ORANGE}║${NC}      ${CONFIG_DIR}/registry/credentials.txt"
    echo -e "${ORANGE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${ORANGE}║${NC} Helper Commands (after re-login):"
    echo -e "${ORANGE}║${NC}   - builder-status.sh  - Show builder status"
    echo -e "${ORANGE}║${NC}   - status.sh          - Show node status"
    echo -e "${ORANGE}╚════════════════════════════════════════════════════════════╝${NC}"
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
    create_directories
    configure_registry
    configure_runner
    configure_webhook
    configure_nginx
    setup_ssl
    configure_builder
    create_services
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
