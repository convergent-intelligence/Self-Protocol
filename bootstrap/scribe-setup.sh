#!/bin/bash
#===============================================================================
# Scribe Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Scribe in Kingdom Hierarchy
# Purpose: Documentation, knowledge capture, structured logging
# Integrates: Wiki/Docs Platform, Structured Logging, Knowledge Base
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
DOCS_DIR="${INSTALL_DIR}/docs"
KNOWLEDGE_DIR="${INSTALL_DIR}/knowledge"
LOGS_DIR="${INSTALL_DIR}/logs"

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
        sqlite3
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
    
    # Allow Wiki.js (port 3000) - localhost only
    log_info "Allowing Wiki.js (port 3000) from localhost..."
    ufw allow from 127.0.0.1 to any port 3000 proto tcp comment 'Wiki.js Local'
    
    # Allow Log API (port 3100) - internal only
    log_info "Allowing Log API (port 3100) from internal..."
    ufw allow from 10.0.0.0/8 to any port 3100 proto tcp comment 'Log API Internal'
    
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

[wikijs]
enabled = true
port = http,https
filter = wikijs
logpath = /opt/kingdom/logs/wikijs.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Wiki.js filter for Fail2Ban
    if [[ ! -f /etc/fail2ban/filter.d/wikijs.conf ]]; then
        cat > /etc/fail2ban/filter.d/wikijs.conf << 'EOF'
[Definition]
failregex = ^.*Login failed.*ip=<HOST>.*$
            ^.*Authentication failed.*ip=<HOST>.*$
ignoreregex =
EOF
        log_success "Wiki.js Fail2Ban filter created"
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
# Documentation and Knowledge Gateway

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
    
    # Wiki.js proxy
    location /wiki/ {
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
    
    # Static documentation (MkDocs/Docusaurus output)
    location /docs/ {
        alias ${DOCS_DIR}/site/;
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # Knowledge base API
    location /api/knowledge/ {
        proxy_pass http://127.0.0.1:3100/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Log ingestion endpoint
    location /api/logs/ {
        proxy_pass http://127.0.0.1:3100/logs/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Archives and exports
    location /archives/ {
        alias ${KNOWLEDGE_DIR}/archives/;
        autoindex on;
        autoindex_exact_size off;
        autoindex_localtime on;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "Scribe Node OK\\n";
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
    <title>Scribe Node - Kingdom Network</title>
    <style>
        body { font-family: system-ui; background: #0a0a0a; color: #e0e0e0; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { color: #8b5cf6; }
        .status { color: #22c55e; }
        .links { margin-top: 2rem; }
        .links a { color: #8b5cf6; margin: 0 1rem; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
        .quote { font-style: italic; color: #9ca3af; margin-top: 2rem; }
    </style>
</head>
<body>
    <div class="container">
        <h1>📜 Scribe Node</h1>
        <p class="status">Node Status: Active</p>
        <p>Role: Scribe in Kingdom Hierarchy</p>
        <p>Purpose: Documentation, Knowledge Capture, Logging</p>
        <div class="links">
            <a href="/wiki/">Wiki</a>
            <a href="/docs/">Documentation</a>
            <a href="/archives/">Archives</a>
        </div>
        <p class="quote">"What is written remains. What is remembered, lives."</p>
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
    mkdir -p "${DOCS_DIR}"
    mkdir -p "${KNOWLEDGE_DIR}"
    mkdir -p "${LOGS_DIR}"
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/commands"
    
    # Documentation-specific directories
    mkdir -p "${DOCS_DIR}/source"
    mkdir -p "${DOCS_DIR}/site"
    mkdir -p "${DOCS_DIR}/templates"
    mkdir -p "${KNOWLEDGE_DIR}/entries"
    mkdir -p "${KNOWLEDGE_DIR}/archives"
    mkdir -p "${KNOWLEDGE_DIR}/indexes"
    mkdir -p "${DATA_DIR}/wikijs"
    mkdir -p "${DATA_DIR}/postgres"
    mkdir -p "${LOGS_DIR}/structured"
    mkdir -p "${LOGS_DIR}/raw"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Configure Wiki.js
#-------------------------------------------------------------------------------
configure_wikijs() {
    log_section "Configuring Wiki.js"
    
    WIKIJS_CONFIG="${INSTALL_DIR}/config/wikijs.yml"
    
    if [[ ! -f "$WIKIJS_CONFIG" ]]; then
        log_info "Creating Wiki.js configuration..."
        cat > "$WIKIJS_CONFIG" << EOF
# Wiki.js Configuration for Kingdom Scribe Node
port: 3000
bindIP: 0.0.0.0

db:
  type: postgres
  host: postgres
  port: 5432
  user: wikijs
  pass: kingdom-wikijs-password
  db: wikijs

# Logging
logLevel: info

# Offline mode (no telemetry)
offline: true

# Data paths
dataPath: /wiki/data
EOF
        log_success "Wiki.js configuration created"
    else
        log_info "Wiki.js configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Configure MkDocs
#-------------------------------------------------------------------------------
configure_mkdocs() {
    log_section "Configuring MkDocs"
    
    MKDOCS_CONFIG="${DOCS_DIR}/mkdocs.yml"
    
    if [[ ! -f "$MKDOCS_CONFIG" ]]; then
        log_info "Creating MkDocs configuration..."
        cat > "$MKDOCS_CONFIG" << EOF
# MkDocs Configuration for Kingdom Documentation
site_name: Kingdom Documentation
site_description: Official documentation for the Kingdom Network
site_author: Kingdom Scribe

# Repository
repo_name: vergent/Kingdom
repo_url: https://github.com/vergent/Kingdom

# Theme
theme:
  name: material
  palette:
    - scheme: slate
      primary: deep purple
      accent: purple
      toggle:
        icon: material/brightness-4
        name: Switch to light mode
    - scheme: default
      primary: deep purple
      accent: purple
      toggle:
        icon: material/brightness-7
        name: Switch to dark mode
  features:
    - navigation.tabs
    - navigation.sections
    - navigation.expand
    - search.suggest
    - search.highlight
    - content.code.copy

# Extensions
markdown_extensions:
  - pymdownx.highlight:
      anchor_linenums: true
  - pymdownx.superfences
  - pymdownx.tabbed:
      alternate_style: true
  - admonition
  - pymdownx.details
  - attr_list
  - md_in_html
  - tables

# Navigation
nav:
  - Home: index.md
  - Getting Started:
    - Overview: getting-started/overview.md
    - Installation: getting-started/installation.md
  - Architecture:
    - Kingdom Nodes: architecture/nodes.md
    - Guardian: architecture/guardian.md
    - Watcher: architecture/watcher.md
    - Builder: architecture/builder.md
    - Scribe: architecture/scribe.md
  - Operations:
    - Deployment: operations/deployment.md
    - Monitoring: operations/monitoring.md
    - Maintenance: operations/maintenance.md
  - API Reference:
    - Overview: api/overview.md

# Plugins
plugins:
  - search
  - git-revision-date-localized:
      enable_creation_date: true
EOF
        log_success "MkDocs configuration created"
    else
        log_info "MkDocs configuration already exists"
    fi
    
    # Create initial documentation structure
    mkdir -p "${DOCS_DIR}/source/getting-started"
    mkdir -p "${DOCS_DIR}/source/architecture"
    mkdir -p "${DOCS_DIR}/source/operations"
    mkdir -p "${DOCS_DIR}/source/api"
    
    # Create index page
    if [[ ! -f "${DOCS_DIR}/source/index.md" ]]; then
        cat > "${DOCS_DIR}/source/index.md" << 'EOF'
# Kingdom Documentation

Welcome to the Kingdom Network documentation.

## Overview

The Kingdom Network is a distributed infrastructure for orchestrating intelligence. It consists of four primary node types:

- **Guardian** - Security, authentication, and access control
- **Watcher** - Monitoring, observability, and alerting
- **Builder** - CI/CD, artifact building, and deployments
- **Scribe** - Documentation, knowledge capture, and logging

## Quick Links

- [Getting Started](getting-started/overview.md)
- [Architecture Overview](architecture/nodes.md)
- [Operations Guide](operations/deployment.md)

## The Kingdom Philosophy

> "Temporary voices, permanent patterns. The Kingdom lives."

This documentation is maintained by the Scribe node, preserving knowledge for all who seek it.
EOF
        log_success "Initial documentation created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Knowledge Base
#-------------------------------------------------------------------------------
configure_knowledge_base() {
    log_section "Configuring Knowledge Base"
    
    KB_CONFIG="${INSTALL_DIR}/config/knowledge-base.yaml"
    
    if [[ ! -f "$KB_CONFIG" ]]; then
        log_info "Creating Knowledge Base configuration..."
        cat > "$KB_CONFIG" << EOF
# Knowledge Base Configuration for Kingdom Scribe Node
knowledge_base:
  name: Kingdom Knowledge
  version: 1.0.0
  
storage:
  type: filesystem
  path: ${KNOWLEDGE_DIR}
  
indexing:
  enabled: true
  full_text: true
  tags: true
  
categories:
  - name: architecture
    description: System architecture and design
  - name: operations
    description: Operational procedures and runbooks
  - name: incidents
    description: Incident reports and post-mortems
  - name: decisions
    description: Architecture decision records (ADRs)
  - name: mythology
    description: Kingdom lore and mythology
  
retention:
  entries: forever
  logs: 90d
  archives: forever
  
export:
  formats:
    - markdown
    - pdf
    - html
EOF
        log_success "Knowledge Base configuration created"
    else
        log_info "Knowledge Base configuration already exists"
    fi
    
    # Create knowledge entry template
    TEMPLATE_DIR="${KNOWLEDGE_DIR}/templates"
    mkdir -p "$TEMPLATE_DIR"
    
    if [[ ! -f "${TEMPLATE_DIR}/entry.md" ]]; then
        cat > "${TEMPLATE_DIR}/entry.md" << 'EOF'
---
title: {{ title }}
category: {{ category }}
tags: []
created: {{ date }}
updated: {{ date }}
author: scribe
---

# {{ title }}

## Summary

Brief summary of this knowledge entry.

## Details

Detailed information goes here.

## Related

- Link to related entries

## References

- External references
EOF
        log_success "Knowledge entry template created"
    fi
    
    # Create ADR template
    if [[ ! -f "${TEMPLATE_DIR}/adr.md" ]]; then
        cat > "${TEMPLATE_DIR}/adr.md" << 'EOF'
---
title: "ADR-{{ number }}: {{ title }}"
category: decisions
status: proposed  # proposed, accepted, deprecated, superseded
created: {{ date }}
updated: {{ date }}
---

# ADR-{{ number }}: {{ title }}

## Status

{{ status }}

## Context

What is the issue that we're seeing that is motivating this decision or change?

## Decision

What is the change that we're proposing and/or doing?

## Consequences

What becomes easier or more difficult to do because of this change?

## Alternatives Considered

What other options were considered?
EOF
        log_success "ADR template created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Structured Logging
#-------------------------------------------------------------------------------
configure_logging() {
    log_section "Configuring Structured Logging"
    
    LOG_CONFIG="${INSTALL_DIR}/config/logging.yaml"
    
    if [[ ! -f "$LOG_CONFIG" ]]; then
        log_info "Creating logging configuration..."
        cat > "$LOG_CONFIG" << EOF
# Structured Logging Configuration for Kingdom Scribe Node
logging:
  level: info
  format: json
  
outputs:
  - type: file
    path: ${LOGS_DIR}/structured/kingdom.log
    rotation:
      max_size: 100M
      max_files: 10
      compress: true
      
  - type: stdout
    format: pretty
    
sources:
  - name: guardian
    type: http
    endpoint: /api/logs/guardian
  - name: watcher
    type: http
    endpoint: /api/logs/watcher
  - name: builder
    type: http
    endpoint: /api/logs/builder
  - name: scribe
    type: local
    path: ${LOGS_DIR}/raw
    
processing:
  parse_json: true
  extract_timestamp: true
  enrich:
    - node_role
    - hostname
    
retention:
  hot: 7d
  warm: 30d
  cold: 90d
  archive: 365d
EOF
        log_success "Logging configuration created"
    else
        log_info "Logging configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Configure Scribe Node
#-------------------------------------------------------------------------------
configure_scribe() {
    log_section "Configuring Scribe Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    # Create scribe node configuration
    if [[ ! -f "${CONFIG_DIR}/scribe.yaml" ]]; then
        cat > "${CONFIG_DIR}/scribe.yaml" << EOF
# Scribe Node Configuration
node:
  role: scribe
  domain: ${DOMAIN}
  
wiki:
  type: wikijs
  port: 3000
  
documentation:
  type: mkdocs
  source: ${DOCS_DIR}/source
  output: ${DOCS_DIR}/site
  
knowledge:
  path: ${KNOWLEDGE_DIR}
  index: ${KNOWLEDGE_DIR}/indexes
  
logging:
  structured: ${LOGS_DIR}/structured
  raw: ${LOGS_DIR}/raw
  api_port: 3100
EOF
        log_success "Scribe configuration created"
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
# Kingdom Scribe Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="scribe"
export PATH="\${PATH}:${COMMANDS_DIR}"
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
Description=Scribe Node - Kingdom Network Documentation
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
    
    # Create docker-compose.yaml for documentation stack
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Scribe Node Docker Compose - Documentation Stack
version: '3.8'

networks:
  scribe:
    driver: bridge

volumes:
  postgres_data:
  wikijs_data:

services:
  # PostgreSQL for Wiki.js
  postgres:
    image: postgres:15-alpine
    container_name: postgres
    restart: unless-stopped
    environment:
      POSTGRES_DB: wikijs
      POSTGRES_USER: wikijs
      POSTGRES_PASSWORD: kingdom-wikijs-password
    volumes:
      - ${DATA_DIR}/postgres:/var/lib/postgresql/data
    networks:
      - scribe
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U wikijs"]
      interval: 10s
      timeout: 5s
      retries: 5

  # Wiki.js - Documentation Wiki
  wikijs:
    image: ghcr.io/requarks/wiki:2
    container_name: wikijs
    restart: unless-stopped
    environment:
      DB_TYPE: postgres
      DB_HOST: postgres
      DB_PORT: 5432
      DB_USER: wikijs
      DB_PASS: kingdom-wikijs-password
      DB_NAME: wikijs
    volumes:
      - ${DATA_DIR}/wikijs:/wiki/data
    ports:
      - "127.0.0.1:3000:3000"
    networks:
      - scribe
    depends_on:
      postgres:
        condition: service_healthy

  # MkDocs - Static Documentation Builder
  mkdocs:
    image: squidfunk/mkdocs-material:latest
    container_name: mkdocs
    restart: unless-stopped
    volumes:
      - ${DOCS_DIR}:/docs
    working_dir: /docs
    command: serve --dev-addr=0.0.0.0:8000
    ports:
      - "127.0.0.1:8000:8000"
    networks:
      - scribe

  # Knowledge API - Custom knowledge base service
  knowledge-api:
    image: node:20-alpine
    container_name: knowledge-api
    restart: unless-stopped
    working_dir: /app
    volumes:
      - ${KNOWLEDGE_DIR}:/knowledge
      - ${LOGS_DIR}:/logs
      - ${INSTALL_DIR}/config:/config:ro
    environment:
      - KINGDOM_ROLE=scribe
      - KNOWLEDGE_DIR=/knowledge
      - LOGS_DIR=/logs
    ports:
      - "127.0.0.1:3100:3100"
    networks:
      - scribe
    command: >
      sh -c "echo 'Knowledge API placeholder - configure your knowledge service' && 
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
      - scribe
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
    echo -e "${PURPLE}║${NC} Documentation Stack:"
    echo -e "${PURPLE}║${NC}   - Wiki.js:      http://localhost:3000"
    echo -e "${PURPLE}║${NC}   - MkDocs:       http://localhost:8000"
    echo -e "${PURPLE}║${NC}   - Knowledge API: http://localhost:3100"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Next Steps:"
    echo -e "${PURPLE}║${NC}   1. Verify DNS points to this server"
    echo -e "${PURPLE}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${PURPLE}║${NC}   3. Start services: systemctl start scribe-node"
    echo -e "${PURPLE}║${NC}   4. Access Wiki.js: https://${DOMAIN}/wiki/"
    echo -e "${PURPLE}║${NC}   5. Complete Wiki.js setup wizard"
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
    install_nodejs
    configure_firewall
    configure_fail2ban
    create_directories
    configure_wikijs
    configure_mkdocs
    configure_knowledge_base
    configure_logging
    configure_nginx
    setup_ssl
    configure_scribe
    create_services
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
