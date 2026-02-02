#!/bin/bash
#===============================================================================
# Scribe Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Scribe in Kingdom Hierarchy
# Services: Wiki Platform (Wiki.js), Logging Aggregation, Documentation
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
NODE_ROLE="scribe"
INSTALL_DIR="/opt/kingdom"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="${INSTALL_DIR}/config"
DOCS_DIR="${INSTALL_DIR}/docs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
    echo -e "${CYAN}========================================${NC}"
    echo -e "${CYAN} $1${NC}"
    echo -e "${CYAN}========================================${NC}"
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
        python3
        python3-pip
        python3-venv
        jq
        htop
        tmux
        unzip
        pandoc
        texlive-latex-base
        texlive-fonts-recommended
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
    
    # Allow HTTP (port 80) for wiki
    log_info "Allowing HTTP (port 80)..."
    ufw allow 80/tcp comment 'HTTP'
    
    # Allow HTTPS (port 443) for wiki
    log_info "Allowing HTTPS (port 443)..."
    ufw allow 443/tcp comment 'HTTPS'
    
    # Allow Wiki.js (port 3000)
    log_info "Allowing Wiki.js (port 3000)..."
    ufw allow 3000/tcp comment 'Wiki.js'
    
    # Allow Node Exporter (port 9100) - for Watcher monitoring
    log_info "Allowing Node Exporter (port 9100)..."
    ufw allow 9100/tcp comment 'Node Exporter'
    
    # Allow Promtail (port 9080) - for log shipping
    log_info "Allowing Promtail (port 9080)..."
    ufw allow 9080/tcp comment 'Promtail'
    
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

[wikijs]
enabled = true
port = 3000,80,443
filter = wikijs
logpath = /opt/kingdom/data/wikijs/logs/*.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Wiki.js filter
    WIKIJS_FILTER="/etc/fail2ban/filter.d/wikijs.conf"
    if [[ ! -f "$WIKIJS_FILTER" ]]; then
        cat > "$WIKIJS_FILTER" << 'EOF'
[Definition]
failregex = ^.*Login failed.*IP:\s*<HOST>.*$
            ^.*authentication.*failed.*<HOST>.*$
ignoreregex =
EOF
        log_success "Wiki.js fail2ban filter created"
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
# Kingdom Scribe Node SSH Hardening
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
# Scribe Node Directory Structure
#-------------------------------------------------------------------------------
create_directory_structure() {
    log_section "Creating Scribe Node Directory Structure"
    
    # Create main directories
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${DOCS_DIR}"
    mkdir -p "${INSTALL_DIR}/commands"
    mkdir -p "${INSTALL_DIR}/logs"
    
    # Scribe-specific directories
    mkdir -p "${DATA_DIR}/wikijs"
    mkdir -p "${DATA_DIR}/wikijs/logs"
    mkdir -p "${DATA_DIR}/postgres"
    mkdir -p "${DATA_DIR}/logs"
    mkdir -p "${DATA_DIR}/backups"
    mkdir -p "${CONFIG_DIR}/wikijs"
    mkdir -p "${CONFIG_DIR}/nginx"
    mkdir -p "${CONFIG_DIR}/promtail"
    mkdir -p "${DOCS_DIR}/kingdom"
    mkdir -p "${DOCS_DIR}/protocols"
    mkdir -p "${DOCS_DIR}/archives"
    mkdir -p "${DOCS_DIR}/exports"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Wiki.js Configuration
#-------------------------------------------------------------------------------
configure_wikijs() {
    log_section "Configuring Wiki.js"
    
    # Wiki.js environment configuration
    WIKIJS_ENV="${CONFIG_DIR}/wikijs/wiki.env"
    
    if [[ ! -f "$WIKIJS_ENV" ]]; then
        log_info "Creating Wiki.js environment configuration..."
        
        # Generate random secrets
        DB_PASS=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 32)
        
        cat > "$WIKIJS_ENV" << EOF
# Wiki.js Configuration for Kingdom Scribe
DB_TYPE=postgres
DB_HOST=postgres
DB_PORT=5432
DB_USER=wikijs
DB_PASS=${DB_PASS}
DB_NAME=wiki

# PostgreSQL
POSTGRES_DB=wiki
POSTGRES_USER=wikijs
POSTGRES_PASSWORD=${DB_PASS}
EOF
        chmod 600 "$WIKIJS_ENV"
        log_success "Wiki.js environment configuration created"
    else
        log_info "Wiki.js environment configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Nginx Configuration (Reverse Proxy)
#-------------------------------------------------------------------------------
configure_nginx() {
    log_section "Configuring Nginx"
    
    NGINX_CONF="${CONFIG_DIR}/nginx/wiki.conf"
    
    if [[ ! -f "$NGINX_CONF" ]]; then
        log_info "Creating Nginx configuration..."
        cat > "$NGINX_CONF" << 'EOF'
# Nginx Configuration for Kingdom Scribe Wiki
upstream wikijs {
    server wikijs:3000;
}

server {
    listen 80;
    server_name _;
    
    # Redirect HTTP to HTTPS (when SSL is configured)
    # return 301 https://$server_name$request_uri;
    
    location / {
        proxy_pass http://wikijs;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_cache_bypass $http_upgrade;
        
        # Timeouts for large uploads
        proxy_connect_timeout 60s;
        proxy_send_timeout 60s;
        proxy_read_timeout 60s;
    }
    
    # Static assets caching
    location ~* \.(js|css|png|jpg|jpeg|gif|ico|svg|woff|woff2)$ {
        proxy_pass http://wikijs;
        expires 30d;
        add_header Cache-Control "public, immutable";
    }
}
EOF
        log_success "Nginx configuration created"
    else
        log_info "Nginx configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Promtail Configuration (Log Shipping)
#-------------------------------------------------------------------------------
configure_promtail() {
    log_section "Configuring Promtail"
    
    PROMTAIL_CONFIG="${CONFIG_DIR}/promtail/promtail-config.yml"
    
    if [[ ! -f "$PROMTAIL_CONFIG" ]]; then
        log_info "Creating Promtail configuration..."
        cat > "$PROMTAIL_CONFIG" << 'EOF'
# Promtail Configuration for Kingdom Scribe
# Ships logs to Watcher node's Loki instance
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  # Update this URL to point to your Watcher node
  - url: http://watcher.kingdom.local:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          node: scribe
          __path__: /var/log/*log

  - job_name: kingdom-scribe
    static_configs:
      - targets:
          - localhost
        labels:
          job: kingdom
          node: scribe
          __path__: /var/log/kingdom/*.log

  - job_name: wikijs
    static_configs:
      - targets:
          - localhost
        labels:
          job: wikijs
          node: scribe
          __path__: /opt/kingdom/data/wikijs/logs/*.log

  - job_name: nginx
    static_configs:
      - targets:
          - localhost
        labels:
          job: nginx
          node: scribe
          __path__: /var/log/nginx/*.log
EOF
        log_success "Promtail configuration created"
    else
        log_info "Promtail configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Backup Configuration
#-------------------------------------------------------------------------------
configure_backups() {
    log_section "Configuring Backup System"
    
    BACKUP_SCRIPT="${INSTALL_DIR}/commands/backup-wiki.sh"
    
    if [[ ! -f "$BACKUP_SCRIPT" ]]; then
        log_info "Creating backup script..."
        cat > "$BACKUP_SCRIPT" << 'EOF'
#!/bin/bash
#===============================================================================
# Wiki.js Backup Script for Kingdom Scribe
#===============================================================================

set -euo pipefail

BACKUP_DIR="/opt/kingdom/data/backups"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
BACKUP_NAME="wiki_backup_${TIMESTAMP}"

echo "Starting Wiki.js backup: ${BACKUP_NAME}"

# Create backup directory
mkdir -p "${BACKUP_DIR}/${BACKUP_NAME}"

# Backup PostgreSQL database
echo "Backing up database..."
docker exec postgres pg_dump -U wikijs wiki > "${BACKUP_DIR}/${BACKUP_NAME}/wiki.sql"

# Backup Wiki.js data
echo "Backing up Wiki.js data..."
docker cp wikijs:/wiki/data "${BACKUP_DIR}/${BACKUP_NAME}/data" 2>/dev/null || true

# Compress backup
echo "Compressing backup..."
cd "${BACKUP_DIR}"
tar -czf "${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}"
rm -rf "${BACKUP_NAME}"

# Cleanup old backups (keep last 7 days)
find "${BACKUP_DIR}" -name "wiki_backup_*.tar.gz" -mtime +7 -delete

echo "Backup completed: ${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
ls -lh "${BACKUP_DIR}/${BACKUP_NAME}.tar.gz"
EOF
        chmod +x "$BACKUP_SCRIPT"
        log_success "Backup script created"
    fi
    
    # Create backup timer
    if [[ ! -f /etc/systemd/system/wiki-backup.timer ]]; then
        cat > /etc/systemd/system/wiki-backup.service << EOF
[Unit]
Description=Wiki.js Backup

[Service]
Type=oneshot
ExecStart=${BACKUP_SCRIPT}
EOF

        cat > /etc/systemd/system/wiki-backup.timer << EOF
[Unit]
Description=Daily Wiki.js Backup

[Timer]
OnCalendar=*-*-* 02:00:00
Persistent=true

[Install]
WantedBy=timers.target
EOF
        systemctl enable wiki-backup.timer
        log_success "Backup timer created"
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
# Scribe Node Docker Compose - Kingdom Documentation Stack
version: '3.8'

networks:
  kingdom-docs:
    driver: bridge

volumes:
  postgres_data:
  wikijs_data:

services:
  # PostgreSQL - Database for Wiki.js
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    restart: unless-stopped
    env_file:
      - ${CONFIG_DIR}/wikijs/wiki.env
    volumes:
      - postgres_data:/var/lib/postgresql/data
    networks:
      - kingdom-docs
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U wikijs -d wiki"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Wiki.js - Documentation Platform
  wikijs:
    image: ghcr.io/requarks/wiki:2
    container_name: wikijs
    restart: unless-stopped
    env_file:
      - ${CONFIG_DIR}/wikijs/wiki.env
    environment:
      - DB_TYPE=postgres
      - DB_HOST=postgres
      - DB_PORT=5432
      - DB_NAME=wiki
    volumes:
      - wikijs_data:/wiki/data
      - ${DATA_DIR}/wikijs/logs:/wiki/logs
      - ${DOCS_DIR}:/wiki/docs:ro
    ports:
      - "3000:3000"
    networks:
      - kingdom-docs
    depends_on:
      postgres:
        condition: service_healthy

  # Nginx - Reverse Proxy
  nginx:
    image: nginx:alpine
    container_name: nginx
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/nginx/wiki.conf:/etc/nginx/conf.d/default.conf:ro
      - /var/log/nginx:/var/log/nginx
    ports:
      - "80:80"
      - "443:443"
    networks:
      - kingdom-docs
    depends_on:
      - wikijs

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
      - kingdom-docs

  # Promtail - Log Shipping to Watcher
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/promtail/promtail-config.yml:/etc/promtail/config.yml:ro
      - /var/log:/var/log:ro
      - ${DATA_DIR}/wikijs/logs:/wiki/logs:ro
      - /var/log/kingdom:/var/log/kingdom:ro
    command: -config.file=/etc/promtail/config.yml
    ports:
      - "9080:9080"
    networks:
      - kingdom-docs
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
    
    # Scribe Node Service
    if [[ ! -f /etc/systemd/system/scribe-node.service ]]; then
        cat > /etc/systemd/system/scribe-node.service << EOF
[Unit]
Description=Scribe Node - Kingdom Documentation Stack
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
        log_success "Scribe node service created"
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Configure Scribe Node
#-------------------------------------------------------------------------------
configure_scribe() {
    log_section "Configuring Scribe Node"
    
    # Copy helper commands
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    COMMANDS_DIR="${INSTALL_DIR}/commands"
    
    if [[ -d "${SCRIPT_DIR}/commands" ]]; then
        cp "${SCRIPT_DIR}/commands/scribe-status.sh" "$COMMANDS_DIR/" 2>/dev/null || true
        chmod +x "$COMMANDS_DIR/"*.sh 2>/dev/null || true
        log_success "Helper commands installed to ${COMMANDS_DIR}"
    fi
    
    # Add commands to PATH via profile.d
    if [[ ! -f /etc/profile.d/kingdom.sh ]]; then
        cat > /etc/profile.d/kingdom.sh << EOF
# Kingdom Scribe Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="${NODE_ROLE}"
export PATH="\${PATH}:${COMMANDS_DIR}"
EOF
        log_success "Kingdom environment configured"
    fi
    
    # Create log directory
    mkdir -p /var/log/kingdom
    
    # Create initial documentation structure
    create_initial_docs
    
    log_success "Scribe node configured"
}

#-------------------------------------------------------------------------------
# Create Initial Documentation
#-------------------------------------------------------------------------------
create_initial_docs() {
    log_info "Creating initial documentation structure..."
    
    # Kingdom overview
    if [[ ! -f "${DOCS_DIR}/kingdom/README.md" ]]; then
        cat > "${DOCS_DIR}/kingdom/README.md" << 'EOF'
# Kingdom Documentation

Welcome to the Kingdom documentation hub. This wiki serves as the central knowledge base for the Kingdom network.

## Node Roles

- **Guardian** - Primary node, handles API and web services
- **Watcher** - Monitoring node, runs Prometheus/Grafana/Loki
- **Builder** - CI/CD node, handles builds and deployments
- **Scribe** - Documentation node (you are here)

## Quick Links

- [Architecture Overview](./architecture.md)
- [Deployment Guide](./deployment.md)
- [Operations Manual](./operations.md)

## Getting Started

1. Review the architecture documentation
2. Understand the node hierarchy
3. Follow the deployment guides for each node type
EOF
    fi
    
    # Architecture document
    if [[ ! -f "${DOCS_DIR}/kingdom/architecture.md" ]]; then
        cat > "${DOCS_DIR}/kingdom/architecture.md" << 'EOF'
# Kingdom Architecture

## Overview

The Kingdom network consists of specialized nodes, each with distinct responsibilities.

## Node Types

### Guardian Node
- Primary entry point
- Handles web traffic and API requests
- Runs OpenClaw integration
- Manages SSL certificates

### Watcher Node
- Centralized monitoring
- Prometheus for metrics
- Grafana for visualization
- Loki for log aggregation
- Alertmanager for notifications

### Builder Node
- CI/CD pipeline
- Docker registry
- Build runners
- Artifact storage

### Scribe Node
- Documentation wiki
- Knowledge base
- Log archival
- Backup management

## Communication Flow

```
[Users] --> [Guardian] --> [API Services]
                |
                v
[Watcher] <-- metrics -- [All Nodes]
                |
                v
[Builder] --> [Registry] --> [Deployments]
                |
                v
[Scribe] <-- logs/docs -- [All Nodes]
```
EOF
    fi
    
    log_success "Initial documentation created"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Scribe Node Setup Complete"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Scribe Node Bootstrap Complete                    ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Role:       ${BLUE}Scribe (Documentation)${NC}"
    echo -e "${CYAN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Services:"
    echo -e "${CYAN}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${CYAN}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${CYAN}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Documentation Stack (after start):"
    echo -e "${CYAN}║${NC}   - Wiki.js:       http://localhost:3000"
    echo -e "${CYAN}║${NC}   - Nginx Proxy:   http://localhost:80"
    echo -e "${CYAN}║${NC}   - Node Exporter: http://localhost:9100"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Wiki.js Setup:"
    echo -e "${CYAN}║${NC}   - First-run wizard will configure admin"
    echo -e "${CYAN}║${NC}   - Database: PostgreSQL (auto-configured)"
    echo -e "${CYAN}║${NC}   - Storage: Local filesystem"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Documentation Directories:"
    echo -e "${CYAN}║${NC}   - Kingdom:   ${DOCS_DIR}/kingdom"
    echo -e "${CYAN}║${NC}   - Protocols: ${DOCS_DIR}/protocols"
    echo -e "${CYAN}║${NC}   - Archives:  ${DOCS_DIR}/archives"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Next Steps:"
    echo -e "${CYAN}║${NC}   1. Start services: systemctl start scribe-node"
    echo -e "${CYAN}║${NC}   2. Complete Wiki.js first-run setup"
    echo -e "${CYAN}║${NC}   3. Configure Promtail to point to Watcher"
    echo -e "${CYAN}║${NC}   4. Import existing documentation"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Helper Commands (after re-login):"
    echo -e "${CYAN}║${NC}   - scribe-status.sh  - Show documentation status"
    echo -e "${CYAN}║${NC}   - backup-wiki.sh    - Backup wiki data"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Scribe Node Bootstrap - Kingdom Documentation"
    log_info "Starting bootstrap at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    configure_firewall
    configure_fail2ban
    harden_ssh
    create_directory_structure
    configure_wikijs
    configure_nginx
    configure_promtail
    configure_backups
    create_docker_compose
    create_services
    configure_scribe
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
