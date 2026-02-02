#!/bin/bash
#===============================================================================
# Guardian Node Bootstrap Script for Kali Linux
# VPS: Kali Linux | Role: Guardian/Citadel in Kingdom Hierarchy
# Integrates: OpenClaw, Self-Protocol, Kingdom
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================
# Adapted from guardian-setup.sh for Kali Linux specifics:
# - Security tools pre-installed
# - Different default packages
# - Kali-specific repositories
#===============================================================================

set -euo pipefail

# Configuration
DOMAIN="${KINGDOM_DOMAIN:-mapyourmind.me}"
NODE_ROLE="guardian"
NODE_TYPE="citadel"
INSTALL_DIR="/opt/kingdom"
REPOS_DIR="${INSTALL_DIR}/repos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
    echo -e "${PURPLE}========================================${NC}"
    echo -e "${PURPLE} $1${NC}"
    echo -e "${PURPLE}========================================${NC}"
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
    
    # Check Kali Linux
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        if [[ "$ID" != "kali" ]]; then
            log_warn "This script is designed for Kali Linux. Current: $ID"
            log_warn "Proceeding anyway - some features may not work as expected"
        else
            log_info "Detected Kali Linux: $VERSION"
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
    
    # Kali already has many security tools, but we need infrastructure packages
    # Note: Many packages like curl, wget, git are pre-installed on Kali
    PACKAGES=(
        # Core utilities (may already exist)
        git
        curl
        wget
        gnupg
        ca-certificates
        apt-transport-https
        software-properties-common
        
        # Firewall and security (Kali has different defaults)
        ufw
        fail2ban
        
        # Web server and SSL
        nginx
        certbot
        python3-certbot-nginx
        
        # Development
        python3
        python3-pip
        python3-venv
        nodejs
        npm
        
        # Utilities
        jq
        htop
        tmux
        tree
        
        # Kali-specific security tools we want to ensure
        nmap
        netcat-openbsd
        tcpdump
        wireshark-common
    )
    
    # Install packages (apt-get is idempotent)
    log_info "Installing core packages..."
    apt-get install -y "${PACKAGES[@]}" 2>/dev/null || {
        log_warn "Some packages may have failed - continuing with available packages"
    }
    
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
        
        # Kali is Debian-based, use Debian repository
        # Add Docker's official GPG key
        install -m 0755 -d /etc/apt/keyrings
        curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc
        chmod a+r /etc/apt/keyrings/docker.asc
        
        # Kali is based on Debian testing, use bookworm (stable) for Docker
        echo \
          "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
          bookworm stable" | \
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
# Node.js Version Check/Upgrade
#-------------------------------------------------------------------------------
ensure_nodejs() {
    log_section "Ensuring Node.js Version"
    
    # Kali may have an older Node.js, check version
    if command -v node &> /dev/null; then
        NODE_VERSION=$(node --version | cut -d'v' -f2 | cut -d'.' -f1)
        if [[ "$NODE_VERSION" -lt 18 ]]; then
            log_warn "Node.js version too old ($NODE_VERSION), upgrading..."
            
            # Install Node.js 20.x LTS via NodeSource
            curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
            apt-get install -y nodejs
        else
            log_info "Node.js version acceptable: $(node --version)"
        fi
    else
        log_info "Installing Node.js LTS..."
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    fi
    
    # Update npm
    npm install -g npm@latest 2>/dev/null || true
    
    log_success "Node.js setup complete: $(node --version)"
}

#-------------------------------------------------------------------------------
# Firewall Configuration (UFW)
#-------------------------------------------------------------------------------
configure_firewall() {
    log_section "Configuring Firewall (UFW)"
    
    # Kali doesn't enable UFW by default - we want it for Guardian role
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
    
    # Kingdom mesh ports (internal communication)
    log_info "Allowing Kingdom mesh ports..."
    ufw allow from 192.168.1.0/24 to any port 3000:3100 proto tcp comment 'Kingdom Mesh'
    
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

# Guardian-specific: aggressive protection
[nginx-badbots]
enabled = true
port = http,https
filter = nginx-badbots
logpath = /var/log/nginx/access.log
maxretry = 1
bantime = 1w
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
# Nginx Configuration
#-------------------------------------------------------------------------------
configure_nginx() {
    log_section "Configuring Nginx"
    
    NGINX_CONF="/etc/nginx/sites-available/${DOMAIN}"
    
    # Create initial HTTP-only config (for Let's Encrypt)
    if [[ ! -f "$NGINX_CONF" ]]; then
        log_info "Creating Nginx configuration for ${DOMAIN}..."
        cat > "$NGINX_CONF" << EOF
# Guardian/Citadel Node - ${DOMAIN}
# Kali Linux Security Node
# Initial HTTP configuration (SSL will be added by Certbot)

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN} www.${DOMAIN};
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "strict-origin-when-cross-origin" always;
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Root location - will serve Guardian interface
    location / {
        root /var/www/${DOMAIN};
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # API proxy to OpenClaw
    location /api/ {
        proxy_pass http://127.0.0.1:3000/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Self-Protocol viewer
    location /self/ {
        proxy_pass http://127.0.0.1:3001/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Kingdom mesh status endpoint
    location /mesh/ {
        proxy_pass http://127.0.0.1:3002/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
}
EOF
        log_success "Nginx configuration created"
    else
        log_info "Nginx configuration already exists"
    fi
    
    # Create web root directory
    mkdir -p "/var/www/${DOMAIN}"
    
    # Create Guardian-specific placeholder index
    if [[ ! -f "/var/www/${DOMAIN}/index.html" ]]; then
        cat > "/var/www/${DOMAIN}/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Guardian Citadel - ${DOMAIN}</title>
    <style>
        body { 
            font-family: 'Courier New', monospace; 
            background: #0a0a0a; 
            color: #00ff00; 
            display: flex; 
            justify-content: center; 
            align-items: center; 
            min-height: 100vh; 
            margin: 0;
        }
        .container { 
            text-align: center; 
            padding: 2rem;
            border: 1px solid #00ff00;
            background: rgba(0, 255, 0, 0.05);
        }
        h1 { color: #00ff00; text-shadow: 0 0 10px #00ff00; }
        .status { color: #00ff00; }
        .role { color: #ff6600; }
        pre {
            text-align: left;
            font-size: 0.8em;
            color: #666;
        }
    </style>
</head>
<body>
    <div class="container">
        <pre>
   _____ _   _          _____  _____ _____          _   _ 
  / ____| | | |   /\   |  __ \|  __ \_   _|   /\   | \ | |
 | |  __| | | |  /  \  | |__) | |  | || |    /  \  |  \| |
 | | |_ | | | | / /\ \ |  _  /| |  | || |   / /\ \ | . \` |
 | |__| | |_| |/ ____ \| | \ \| |__| || |_ / ____ \| |\  |
  \_____|\___//_/    \_\_|  \_\_____/_____/_/    \_\_| \_|
        </pre>
        <h1>🛡️ Guardian Citadel</h1>
        <p class="status">Node Status: Initializing</p>
        <p>Domain: ${DOMAIN}</p>
        <p class="role">Role: Guardian/Citadel in Kingdom Hierarchy</p>
        <p>Platform: Kali Linux</p>
        <p style="color: #666; font-size: 0.8em;">Security perimeter active</p>
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
            -d "www.${DOMAIN}" \
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
# Repository Cloning
#-------------------------------------------------------------------------------
clone_repositories() {
    log_section "Cloning Repositories"
    
    # Create installation directory
    mkdir -p "$REPOS_DIR"
    
    # Repository definitions: name -> URL
    declare -A REPOS=(
        ["openclaw"]="https://github.com/openclaw/openclaw.git"
        ["Self-Protocol"]="https://github.com/vergent/Self-Protocol.git"
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
# Guardian Node Configuration
#-------------------------------------------------------------------------------
configure_guardian() {
    log_section "Configuring Guardian/Citadel Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    # Create Guardian-specific configuration
    cat > "${CONFIG_DIR}/guardian.yaml" << EOF
# Guardian/Citadel Node Configuration
# Generated by guardian-setup-kali.sh

node:
  role: guardian
  type: citadel
  domain: ${DOMAIN}
  platform: kali

mesh:
  network: 192.168.1.0/24
  port_range: 3000-3100
  
security:
  firewall: ufw
  ids: fail2ban
  ssl: letsencrypt
  
services:
  api_port: 3000
  self_viewer_port: 3001
  mesh_status_port: 3002
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
# Kingdom Guardian/Citadel Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="guardian"
export KINGDOM_TYPE="citadel"
export PATH="\${PATH}:${COMMANDS_DIR}"
EOF
        log_success "Kingdom environment configured"
    fi
    
    log_success "Guardian/Citadel node configured"
}

#-------------------------------------------------------------------------------
# Create Systemd Services
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Systemd Services"
    
    # Guardian Node Service
    if [[ ! -f /etc/systemd/system/guardian-node.service ]]; then
        cat > /etc/systemd/system/guardian-node.service << EOF
[Unit]
Description=Guardian/Citadel Node - Kingdom Network
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
        log_success "Guardian node service created"
    fi
    
    # Create placeholder docker-compose.yaml
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Guardian/Citadel Node Docker Compose
# Kali Linux Security Node

version: '3.8'

services:
  # OpenClaw API
  guardian-api:
    image: node:20-alpine
    container_name: guardian-api
    working_dir: /app
    volumes:
      - ${REPOS_DIR}/openclaw:/app
      - ${INSTALL_DIR}/config:/config
    ports:
      - "127.0.0.1:3000:3000"
    command: echo "OpenClaw integration pending"
    restart: unless-stopped

  # Self-Protocol Viewer
  self-viewer:
    image: node:20-alpine
    container_name: self-viewer
    working_dir: /app
    volumes:
      - ${REPOS_DIR}/Self-Protocol:/app
    ports:
      - "127.0.0.1:3001:3000"
    command: echo "Self-Protocol viewer pending"
    restart: unless-stopped

  # Mesh Status Service
  mesh-status:
    image: node:20-alpine
    container_name: mesh-status
    working_dir: /app
    ports:
      - "127.0.0.1:3002:3000"
    command: echo "Mesh status service pending"
    restart: unless-stopped
EOF
        log_success "Docker compose template created"
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Kali-Specific Security Hardening
#-------------------------------------------------------------------------------
harden_kali() {
    log_section "Kali-Specific Security Hardening"
    
    # Disable unnecessary services that Kali enables by default
    SERVICES_TO_DISABLE=(
        "apache2"
        "postgresql"
        "mysql"
    )
    
    for service in "${SERVICES_TO_DISABLE[@]}"; do
        if systemctl is-enabled "$service" 2>/dev/null; then
            log_info "Disabling unnecessary service: $service"
            systemctl disable "$service" 2>/dev/null || true
            systemctl stop "$service" 2>/dev/null || true
        fi
    done
    
    # Configure SSH hardening
    SSH_CONFIG="/etc/ssh/sshd_config.d/kingdom-hardening.conf"
    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_info "Applying SSH hardening..."
        cat > "$SSH_CONFIG" << 'EOF'
# Kingdom Guardian SSH Hardening
PermitRootLogin prohibit-password
PasswordAuthentication no
PubkeyAuthentication yes
MaxAuthTries 3
ClientAliveInterval 300
ClientAliveCountMax 2
EOF
        systemctl reload sshd 2>/dev/null || true
        log_success "SSH hardening applied"
    fi
    
    # Set up automatic security updates
    if [[ ! -f /etc/apt/apt.conf.d/50unattended-upgrades ]]; then
        apt-get install -y unattended-upgrades
        dpkg-reconfigure -plow unattended-upgrades
    fi
    
    log_success "Kali security hardening complete"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Guardian/Citadel Node Setup Complete"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║       Guardian/Citadel Node Bootstrap Complete             ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${GREEN}║${NC} Role:       ${PURPLE}Guardian/Citadel${NC}"
    echo -e "${GREEN}║${NC} Platform:   ${BLUE}Kali Linux${NC}"
    echo -e "${GREEN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Services:"
    echo -e "${GREEN}║${NC}   - Nginx:     $(systemctl is-active nginx 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - Docker:    $(systemctl is-active docker 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban 2>/dev/null || echo 'unknown')"
    echo -e "${GREEN}║${NC}   - UFW:       $(ufw status 2>/dev/null | head -1 || echo 'unknown')"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Security Tools (Kali Pre-installed):"
    echo -e "${GREEN}║${NC}   - nmap:      $(command -v nmap &>/dev/null && echo 'available' || echo 'missing')"
    echo -e "${GREEN}║${NC}   - netcat:    $(command -v nc &>/dev/null && echo 'available' || echo 'missing')"
    echo -e "${GREEN}║${NC}   - tcpdump:   $(command -v tcpdump &>/dev/null && echo 'available' || echo 'missing')"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Next Steps:"
    echo -e "${GREEN}║${NC}   1. Verify DNS points to this server"
    echo -e "${GREEN}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${GREEN}║${NC}   3. Configure OpenClaw integration"
    echo -e "${GREEN}║${NC}   4. Start services: systemctl start guardian-node"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Helper Commands (after re-login):"
    echo -e "${GREEN}║${NC}   - pull-kingdom.sh    - Pull Kingdom updates"
    echo -e "${GREEN}║${NC}   - update-self.sh     - Update Self-Protocol"
    echo -e "${GREEN}║${NC}   - sync-openclaw.sh   - Sync OpenClaw"
    echo -e "${GREEN}║${NC}   - status.sh          - Show node status"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Guardian/Citadel Node Bootstrap - Kali Linux"
    log_info "Starting bootstrap at $(date)"
    log_info "Domain: ${DOMAIN}"
    
    preflight_checks
    install_dependencies
    install_docker
    ensure_nodejs
    configure_firewall
    configure_fail2ban
    configure_nginx
    setup_ssl
    clone_repositories
    configure_guardian
    create_services
    harden_kali
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
