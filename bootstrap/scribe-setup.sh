#!/bin/bash
#===============================================================================
# Scribe Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Scribe in Kingdom Hierarchy
# Purpose: Documentation, knowledge capture, logging
# Installs: Wiki/docs platform (Outline or BookStack), structured logging
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
DOMAIN="${SCRIBE_DOMAIN:-scribe.kingdom.local}"
NODE_ROLE="scribe"
INSTALL_DIR="/opt/kingdom"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="${INSTALL_DIR}/config"
DOCS_DIR="${INSTALL_DIR}/docs"
LOGS_DIR="${INSTALL_DIR}/logs"

# Ports
BOOKSTACK_PORT=8080
MINIO_PORT=9000
MINIO_CONSOLE_PORT=9001
POSTGRES_PORT=5432

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
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
        certbot
        python3-certbot-nginx
        nginx
        python3
        python3-pip
        python3-venv
        jq
        htop
        tmux
        # Documentation tools
        pandoc
        texlive-latex-base
        texlive-fonts-recommended
        # Search and indexing
        meilisearch
    )
    
    # Install packages (apt-get is idempotent)
    log_info "Installing core packages..."
    apt-get install -y "${PACKAGES[@]}" 2>/dev/null || {
        # meilisearch might not be in default repos, install separately
        log_warn "Some packages not available, installing core packages..."
        apt-get install -y git curl wget gnupg ca-certificates apt-transport-https \
            software-properties-common ufw fail2ban certbot python3-certbot-nginx \
            nginx python3 python3-pip python3-venv jq htop tmux pandoc \
            texlive-latex-base texlive-fonts-recommended
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
    
    # Allow HTTP (port 80) for Let's Encrypt and redirects
    log_info "Allowing HTTP (port 80)..."
    ufw allow 80/tcp comment 'HTTP'
    
    # Allow HTTPS (port 443) for secure traffic
    log_info "Allowing HTTPS (port 443)..."
    ufw allow 443/tcp comment 'HTTPS'
    
    # Scribe-specific ports (internal only recommended)
    log_info "Allowing BookStack (port ${BOOKSTACK_PORT})..."
    ufw allow ${BOOKSTACK_PORT}/tcp comment 'BookStack'
    
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

[bookstack]
enabled = true
port = http,https
filter = bookstack
logpath = /opt/kingdom/data/bookstack/logs/*.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create BookStack filter if it doesn't exist
    if [[ ! -f /etc/fail2ban/filter.d/bookstack.conf ]]; then
        cat > /etc/fail2ban/filter.d/bookstack.conf << 'EOF'
[Definition]
failregex = ^.*Failed login attempt.*from <HOST>.*$
            ^.*Invalid credentials.*from <HOST>.*$
ignoreregex =
EOF
        log_success "BookStack fail2ban filter created"
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
# Scribe Node - ${DOMAIN}
# Initial HTTP configuration (SSL will be added by Certbot)

# Increase client body size for document uploads
client_max_body_size 100M;

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Root location - Scribe dashboard
    location / {
        root /var/www/${DOMAIN};
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # BookStack wiki proxy
    location /wiki/ {
        proxy_pass http://127.0.0.1:${BOOKSTACK_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_set_header X-Forwarded-Host \$host;
        proxy_redirect off;
        client_max_body_size 100M;
    }
    
    # Static documentation
    location /docs/ {
        alias ${DOCS_DIR}/static/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
    
    # Kingdom logs viewer
    location /logs/ {
        alias ${LOGS_DIR}/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
        # Restrict to specific file types
        location ~ \.(log|txt|json)$ {
            add_header Content-Type text/plain;
        }
    }
    
    # API for log ingestion
    location /api/logs {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header Content-Type application/json;
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
    <title>Scribe Node - ${DOMAIN}</title>
    <style>
        body { font-family: system-ui; background: #0a0a0a; color: #e0e0e0; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { color: #8b5cf6; }
        .status { color: #22c55e; }
        .links { margin-top: 2rem; }
        .links a { color: #a78bfa; margin: 0 1rem; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
        .quote { font-style: italic; color: #9ca3af; margin-top: 2rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📜 Scribe Node</h1>
        <p class="status">Node Status: Initializing</p>
        <p>Domain: ${DOMAIN}</p>
        <p>Role: Scribe in Kingdom Hierarchy</p>
        <div class="links">
            <a href="/wiki/">Wiki</a>
            <a href="/docs/">Documentation</a>
            <a href="/logs/">Logs</a>
        </div>
        <p class="quote">"The Scribe records all. The Kingdom remembers."</p>
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
    mkdir -p "${DOCS_DIR}"
    mkdir -p "${LOGS_DIR}"
    
    # Scribe-specific directories
    mkdir -p "${DATA_DIR}/bookstack"
    mkdir -p "${DATA_DIR}/bookstack/logs"
    mkdir -p "${DATA_DIR}/bookstack/uploads"
    mkdir -p "${DATA_DIR}/postgres"
    mkdir -p "${DATA_DIR}/minio"
    mkdir -p "${CONFIG_DIR}/bookstack"
    mkdir -p "${DOCS_DIR}/static"
    mkdir -p "${DOCS_DIR}/templates"
    mkdir -p "${DOCS_DIR}/generated"
    mkdir -p "${LOGS_DIR}/kingdom"
    mkdir -p "${LOGS_DIR}/archive"
    
    # Create log receiver directory
    mkdir -p "${INSTALL_DIR}/log-receiver"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Configure BookStack
#-------------------------------------------------------------------------------
configure_bookstack() {
    log_section "Configuring BookStack"
    
    # Generate secrets if not exists
    SECRETS_FILE="${CONFIG_DIR}/bookstack/secrets.env"
    
    if [[ ! -f "$SECRETS_FILE" ]]; then
        log_info "Generating BookStack secrets..."
        
        APP_KEY=$(openssl rand -base64 32)
        DB_PASSWORD=$(openssl rand -base64 16)
        
        cat > "$SECRETS_FILE" << EOF
# BookStack Secrets - Generated $(date)
# DO NOT COMMIT THIS FILE

APP_KEY=base64:${APP_KEY}
DB_PASSWORD=${DB_PASSWORD}
EOF
        chmod 600 "$SECRETS_FILE"
        log_success "BookStack secrets generated"
    fi
    
    # Source secrets
    source "$SECRETS_FILE"
    
    # Create BookStack environment file
    BOOKSTACK_ENV="${CONFIG_DIR}/bookstack/.env"
    
    if [[ ! -f "$BOOKSTACK_ENV" ]]; then
        log_info "Creating BookStack configuration..."
        cat > "$BOOKSTACK_ENV" << EOF
# BookStack Configuration for Kingdom Scribe Node
APP_NAME="Kingdom Scribe"
APP_ENV=production
APP_DEBUG=false
APP_KEY=${APP_KEY}
APP_URL=http://${DOMAIN}/wiki

# Database
DB_CONNECTION=mysql
DB_HOST=mariadb
DB_PORT=3306
DB_DATABASE=bookstack
DB_USERNAME=bookstack
DB_PASSWORD=${DB_PASSWORD}

# Mail (configure as needed)
MAIL_DRIVER=log
MAIL_FROM_NAME="Kingdom Scribe"
MAIL_FROM=scribe@${DOMAIN}

# Storage
STORAGE_TYPE=local
STORAGE_IMAGE_TYPE=local

# Authentication
AUTH_METHOD=standard

# Session
SESSION_LIFETIME=120
SESSION_SECURE_COOKIE=false

# Logging
LOG_CHANNEL=daily
LOG_LEVEL=info
EOF
        chmod 600 "$BOOKSTACK_ENV"
        log_success "BookStack configuration created"
    else
        log_info "BookStack configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Configure Log Receiver
#-------------------------------------------------------------------------------
configure_log_receiver() {
    log_section "Configuring Log Receiver"
    
    # Create simple log receiver script
    LOG_RECEIVER="${INSTALL_DIR}/log-receiver/receiver.py"
    
    if [[ ! -f "$LOG_RECEIVER" ]]; then
        log_info "Creating log receiver..."
        cat > "$LOG_RECEIVER" << 'EOF'
#!/usr/bin/env python3
"""
Kingdom Log Receiver
Receives logs from other Kingdom nodes and stores them
"""

import json
import os
from datetime import datetime
from http.server import HTTPServer, BaseHTTPRequestHandler
from pathlib import Path

LOGS_DIR = os.environ.get('LOGS_DIR', '/opt/kingdom/logs/kingdom')

class LogHandler(BaseHTTPRequestHandler):
    def do_POST(self):
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length)
        
        try:
            log_entry = json.loads(body)
            self.store_log(log_entry)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(b'{"status": "ok"}')
        except Exception as e:
            self.send_response(400)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({"error": str(e)}).encode())
    
    def store_log(self, entry):
        node = entry.get('node', 'unknown')
        level = entry.get('level', 'info')
        message = entry.get('message', '')
        timestamp = entry.get('timestamp', datetime.utcnow().isoformat())
        
        # Create node-specific log directory
        node_dir = Path(LOGS_DIR) / node
        node_dir.mkdir(parents=True, exist_ok=True)
        
        # Write to daily log file
        date_str = datetime.utcnow().strftime('%Y-%m-%d')
        log_file = node_dir / f"{date_str}.log"
        
        log_line = json.dumps({
            'timestamp': timestamp,
            'level': level,
            'message': message,
            'metadata': entry.get('metadata', {})
        })
        
        with open(log_file, 'a') as f:
            f.write(log_line + '\n')
    
    def log_message(self, format, *args):
        # Suppress default logging
        pass

def main():
    port = int(os.environ.get('PORT', 8081))
    server = HTTPServer(('0.0.0.0', port), LogHandler)
    print(f"Kingdom Log Receiver listening on port {port}")
    server.serve_forever()

if __name__ == '__main__':
    main()
EOF
        chmod +x "$LOG_RECEIVER"
        log_success "Log receiver created"
    fi
    
    # Create log receiver requirements
    if [[ ! -f "${INSTALL_DIR}/log-receiver/requirements.txt" ]]; then
        cat > "${INSTALL_DIR}/log-receiver/requirements.txt" << 'EOF'
# No external dependencies - uses stdlib only
EOF
    fi
}

#-------------------------------------------------------------------------------
# Configure Documentation Templates
#-------------------------------------------------------------------------------
configure_doc_templates() {
    log_section "Configuring Documentation Templates"
    
    # Create ADR (Architecture Decision Record) template
    if [[ ! -f "${DOCS_DIR}/templates/adr-template.md" ]]; then
        cat > "${DOCS_DIR}/templates/adr-template.md" << 'EOF'
# ADR-{NUMBER}: {TITLE}

## Status
{Proposed | Accepted | Deprecated | Superseded}

## Context
What is the issue that we're seeing that is motivating this decision or change?

## Decision
What is the change that we're proposing and/or doing?

## Consequences
What becomes easier or more difficult to do because of this change?

## References
- Related ADRs
- External documentation
- Discussion links

---
*Recorded by Kingdom Scribe on {DATE}*
EOF
        log_success "ADR template created"
    fi
    
    # Create incident report template
    if [[ ! -f "${DOCS_DIR}/templates/incident-template.md" ]]; then
        cat > "${DOCS_DIR}/templates/incident-template.md" << 'EOF'
# Incident Report: {TITLE}

## Summary
| Field | Value |
|-------|-------|
| Date | {DATE} |
| Duration | {DURATION} |
| Severity | {P1/P2/P3/P4} |
| Affected Systems | {SYSTEMS} |
| Status | {Investigating/Identified/Monitoring/Resolved} |

## Timeline
- **{TIME}** - {EVENT}

## Root Cause
{Description of what caused the incident}

## Resolution
{What was done to resolve the incident}

## Action Items
- [ ] {Action item 1}
- [ ] {Action item 2}

## Lessons Learned
{What we learned from this incident}

---
*Documented by Kingdom Scribe*
EOF
        log_success "Incident template created"
    fi
    
    # Create runbook template
    if [[ ! -f "${DOCS_DIR}/templates/runbook-template.md" ]]; then
        cat > "${DOCS_DIR}/templates/runbook-template.md" << 'EOF'
# Runbook: {TITLE}

## Overview
{Brief description of what this runbook covers}

## Prerequisites
- {Prerequisite 1}
- {Prerequisite 2}

## Procedure

### Step 1: {Step Title}
```bash
# Commands to execute
```

### Step 2: {Step Title}
```bash
# Commands to execute
```

## Verification
How to verify the procedure was successful:
```bash
# Verification commands
```

## Rollback
If something goes wrong:
```bash
# Rollback commands
```

## Related Documentation
- {Link 1}
- {Link 2}

---
*Maintained by Kingdom Scribe*
EOF
        log_success "Runbook template created"
    fi
}

#-------------------------------------------------------------------------------
# Scribe Node Configuration
#-------------------------------------------------------------------------------
configure_scribe() {
    log_section "Configuring Scribe Node"
    
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
# Kingdom Scribe Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export PATH="\${PATH}:${COMMANDS_DIR}"
export DOCS_DIR="${DOCS_DIR}"
export LOGS_DIR="${LOGS_DIR}"
EOF
        log_success "Kingdom environment configured"
    fi
    
    log_success "Scribe node configured"
}

#-------------------------------------------------------------------------------
# Create Systemd Services
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Systemd Services"
    
    # Scribe Node Service
    if [[ ! -f /etc/systemd/system/scribe-node.service ]]; then
        cat > /etc/systemd/system/scribe-node.service << EOF
[Unit]
Description=Scribe Node - Kingdom Network
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
    
    # Source secrets for docker-compose
    source "${CONFIG_DIR}/bookstack/secrets.env" 2>/dev/null || true
    
    # Create docker-compose.yaml for scribe stack
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Scribe Node Docker Compose - Documentation Stack
# BookStack + MariaDB + Log Receiver

version: '3.8'

networks:
  scribe-network:
    driver: bridge

volumes:
  mariadb_data:
  bookstack_data:

services:
  # MariaDB Database
  mariadb:
    image: mariadb:10.11
    container_name: mariadb
    restart: unless-stopped
    environment:
      MYSQL_ROOT_PASSWORD: ${DB_PASSWORD:-changeme}
      MYSQL_DATABASE: bookstack
      MYSQL_USER: bookstack
      MYSQL_PASSWORD: ${DB_PASSWORD:-changeme}
    volumes:
      - ${DATA_DIR}/mariadb:/var/lib/mysql
    networks:
      - scribe-network
    healthcheck:
      test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
      interval: 10s
      timeout: 5s
      retries: 5

  # BookStack Wiki
  bookstack:
    image: lscr.io/linuxserver/bookstack:latest
    container_name: bookstack
    restart: unless-stopped
    environment:
      - PUID=1000
      - PGID=1000
      - APP_URL=http://${DOMAIN}/wiki
      - DB_HOST=mariadb
      - DB_PORT=3306
      - DB_USER=bookstack
      - DB_PASS=${DB_PASSWORD:-changeme}
      - DB_DATABASE=bookstack
    volumes:
      - ${DATA_DIR}/bookstack:/config
    ports:
      - "127.0.0.1:${BOOKSTACK_PORT}:80"
    networks:
      - scribe-network
    depends_on:
      mariadb:
        condition: service_healthy

  # Log Receiver
  log-receiver:
    image: python:3.11-slim
    container_name: log-receiver
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${INSTALL_DIR}/log-receiver:/app:ro
      - ${LOGS_DIR}:/logs
    environment:
      - LOGS_DIR=/logs/kingdom
      - PORT=8081
    command: python /app/receiver.py
    ports:
      - "127.0.0.1:8081:8081"
    networks:
      - scribe-network

  # Log Rotation (runs daily)
  log-rotation:
    image: alpine:latest
    container_name: log-rotation
    restart: "no"
    volumes:
      - ${LOGS_DIR}:/logs
    command: >
      sh -c "
        echo 'Rotating and archiving old logs...'
        find /logs/kingdom -name '*.log' -mtime +30 -exec gzip {} \;
        find /logs/kingdom -name '*.log.gz' -mtime +90 -exec mv {} /logs/archive/ \;
        find /logs/archive -name '*.log.gz' -mtime +365 -delete
        echo 'Log rotation complete'
      "
    profiles:
      - maintenance

  # Documentation Generator (on-demand)
  doc-generator:
    image: pandoc/latex:latest
    container_name: doc-generator
    restart: "no"
    volumes:
      - ${DOCS_DIR}:/docs
    working_dir: /docs
    command: echo "Use: docker compose run doc-generator pandoc input.md -o output.pdf"
    profiles:
      - tools
EOF
        log_success "Docker compose configuration created"
    fi
    
    # Create log rotation cron job
    if ! crontab -l 2>/dev/null | grep -q "scribe log-rotation"; then
        log_info "Setting up log rotation cron job..."
        (crontab -l 2>/dev/null; echo "0 2 * * * cd ${INSTALL_DIR} && docker compose --profile maintenance run --rm log-rotation # scribe log-rotation") | crontab -
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Create Initial Documentation
#-------------------------------------------------------------------------------
create_initial_docs() {
    log_section "Creating Initial Documentation"
    
    # Create Kingdom overview document
    if [[ ! -f "${DOCS_DIR}/static/kingdom-overview.md" ]]; then
        cat > "${DOCS_DIR}/static/kingdom-overview.md" << 'EOF'
# Kingdom Network Overview

## The Four Nodes

The Kingdom Network consists of four specialized nodes, each with a distinct role:

### 🛡️ Guardian
- **Purpose**: Security, authentication, access control
- **Domain**: mapyourmind.me
- **Responsibilities**:
  - SSL/TLS termination
  - User authentication
  - API gateway
  - Security monitoring

### 👁️ Watcher
- **Purpose**: Monitoring, observability, alerting
- **Stack**: Prometheus, Grafana, Loki
- **Responsibilities**:
  - Metrics collection
  - Log aggregation
  - Alert management
  - Dashboard visualization

### 🔨 Builder
- **Purpose**: CI/CD, artifact management, deployments
- **Stack**: Docker Registry, Webhook handlers
- **Responsibilities**:
  - Container builds
  - Artifact storage
  - Deployment automation
  - Build orchestration

### 📜 Scribe
- **Purpose**: Documentation, knowledge capture, logging
- **Stack**: BookStack, Log receiver
- **Responsibilities**:
  - Wiki/documentation
  - Log archival
  - Knowledge management
  - Incident documentation

## Network Topology

```
                    ┌─────────────┐
                    │   Guardian  │
                    │  (Gateway)  │
                    └──────┬──────┘
                           │
           ┌───────────────┼───────────────┐
           │               │               │
    ┌──────┴──────┐ ┌──────┴──────┐ ┌──────┴──────┐
    │   Watcher   │ │   Builder   │ │   Scribe    │
    │ (Observes)  │ │  (Creates)  │ │  (Records)  │
    └─────────────┘ └─────────────┘ └─────────────┘
```

## Communication

- All nodes report metrics to **Watcher**
- All nodes send logs to **Scribe**
- **Builder** deploys to all nodes
- **Guardian** authenticates all external access

---
*Maintained by Kingdom Scribe*
EOF
        log_success "Kingdom overview document created"
    fi
    
    # Create index page for static docs
    if [[ ! -f "${DOCS_DIR}/static/index.html" ]]; then
        cat > "${DOCS_DIR}/static/index.html" << 'EOF'
<!DOCTYPE html>
<html>
<head>
    <title>Kingdom Documentation</title>
    <style>
        body { font-family: system-ui; background: #1a1a2e; color: #e0e0e0; 
               max-width: 800px; margin: 0 auto; padding: 2rem; }
        h1 { color: #8b5cf6; }
        a { color: #a78bfa; }
        .doc-list { list-style: none; padding: 0; }
        .doc-list li { padding: 0.5rem 0; border-bottom: 1px solid #333; }
    </style>
</head>
<body>
    <h1>📜 Kingdom Documentation</h1>
    <p>Static documentation for the Kingdom Network</p>
    <ul class="doc-list">
        <li><a href="kingdom-overview.md">Kingdom Overview</a></li>
    </ul>
    <p><a href="/wiki/">→ Go to Wiki</a></p>
</body>
</html>
EOF
        log_success "Documentation index created"
    fi
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Scribe Node Setup Complete"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║           Scribe Node Bootstrap Complete                    ║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${PURPLE}║${NC} Role:       ${BLUE}Scribe${NC}"
    echo -e "${PURPLE}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Services:"
    echo -e "${PURPLE}║${NC}   - Nginx:     $(systemctl is-active nginx)"
    echo -e "${PURPLE}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${PURPLE}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${PURPLE}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Scribe Stack Ports:"
    echo -e "${PURPLE}║${NC}   - BookStack:     ${BOOKSTACK_PORT}"
    echo -e "${PURPLE}║${NC}   - Log Receiver:  8081"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Next Steps:"
    echo -e "${PURPLE}║${NC}   1. Verify DNS points to this server"
    echo -e "${PURPLE}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${PURPLE}║${NC}   3. Start services: systemctl start scribe-node"
    echo -e "${PURPLE}║${NC}   4. Access Wiki: http://${DOMAIN}/wiki/"
    echo -e "${PURPLE}║${NC}   5. Default BookStack login: admin@admin.com / password"
    echo -e "${PURPLE}║${NC}      (Change immediately after first login!)"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Helper Commands (after re-login):"
    echo -e "${PURPLE}║${NC}   - scribe-status.sh  - Show scribe status"
    echo -e "${PURPLE}║${NC}   - status.sh         - Show node status"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Scribe Node Bootstrap - ${DOMAIN}"
    log_info "Starting bootstrap at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    configure_firewall
    configure_fail2ban
    create_directories
    configure_bookstack
    configure_log_receiver
    configure_doc_templates
    configure_nginx
    setup_ssl
    configure_scribe
    create_services
    create_initial_docs
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
