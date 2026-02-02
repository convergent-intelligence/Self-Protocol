#!/bin/bash
#===============================================================================
# Watcher Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Watcher in Kingdom Hierarchy
# Purpose: Monitoring, observability, log aggregation
# Installs: Prometheus, Grafana, Loki stack via Docker
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
DOMAIN="${WATCHER_DOMAIN:-watcher.kingdom.local}"
NODE_ROLE="watcher"
INSTALL_DIR="/opt/kingdom"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="${INSTALL_DIR}/config"

# Ports
PROMETHEUS_PORT=9090
GRAFANA_PORT=3000
LOKI_PORT=3100
ALERTMANAGER_PORT=9093

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
        jq
        htop
        tmux
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
    
    # Allow HTTP (port 80) for Let's Encrypt and redirects
    log_info "Allowing HTTP (port 80)..."
    ufw allow 80/tcp comment 'HTTP'
    
    # Allow HTTPS (port 443) for secure traffic
    log_info "Allowing HTTPS (port 443)..."
    ufw allow 443/tcp comment 'HTTPS'
    
    # Watcher-specific ports (internal network only recommended)
    log_info "Allowing Prometheus (port ${PROMETHEUS_PORT})..."
    ufw allow ${PROMETHEUS_PORT}/tcp comment 'Prometheus'
    
    log_info "Allowing Grafana (port ${GRAFANA_PORT})..."
    ufw allow ${GRAFANA_PORT}/tcp comment 'Grafana'
    
    log_info "Allowing Loki (port ${LOKI_PORT})..."
    ufw allow ${LOKI_PORT}/tcp comment 'Loki'
    
    log_info "Allowing Alertmanager (port ${ALERTMANAGER_PORT})..."
    ufw allow ${ALERTMANAGER_PORT}/tcp comment 'Alertmanager'
    
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

[grafana]
enabled = true
port = 3000
filter = grafana
logpath = /opt/kingdom/data/grafana/log/grafana.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Grafana filter if it doesn't exist
    if [[ ! -f /etc/fail2ban/filter.d/grafana.conf ]]; then
        cat > /etc/fail2ban/filter.d/grafana.conf << 'EOF'
[Definition]
failregex = ^.*Failed to authenticate user.*client_ip=<HOST>.*$
            ^.*Invalid username or password.*client_ip=<HOST>.*$
ignoreregex =
EOF
        log_success "Grafana fail2ban filter created"
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
# Watcher Node - ${DOMAIN}
# Initial HTTP configuration (SSL will be added by Certbot)

server {
    listen 80;
    listen [::]:80;
    server_name ${DOMAIN};
    
    # Let's Encrypt challenge location
    location /.well-known/acme-challenge/ {
        root /var/www/html;
    }
    
    # Root location - Watcher dashboard
    location / {
        root /var/www/${DOMAIN};
        index index.html;
        try_files \$uri \$uri/ =404;
    }
    
    # Grafana proxy
    location /grafana/ {
        proxy_pass http://127.0.0.1:${GRAFANA_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
    }
    
    # Prometheus proxy
    location /prometheus/ {
        proxy_pass http://127.0.0.1:${PROMETHEUS_PORT}/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
    }
    
    # Alertmanager proxy
    location /alertmanager/ {
        proxy_pass http://127.0.0.1:${ALERTMANAGER_PORT}/;
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
    
    # Create placeholder index
    if [[ ! -f "/var/www/${DOMAIN}/index.html" ]]; then
        cat > "/var/www/${DOMAIN}/index.html" << EOF
<!DOCTYPE html>
<html>
<head>
    <title>Watcher Node - ${DOMAIN}</title>
    <style>
        body { font-family: system-ui; background: #0a0a0a; color: #e0e0e0; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { color: #3b82f6; }
        .status { color: #22c55e; }
        .links { margin-top: 2rem; }
        .links a { color: #60a5fa; margin: 0 1rem; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>👁️ Watcher Node</h1>
        <p class="status">Node Status: Initializing</p>
        <p>Domain: ${DOMAIN}</p>
        <p>Role: Watcher in Kingdom Hierarchy</p>
        <div class="links">
            <a href="/grafana/">Grafana</a>
            <a href="/prometheus/">Prometheus</a>
            <a href="/alertmanager/">Alertmanager</a>
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
    
    # Watcher-specific directories
    mkdir -p "${DATA_DIR}/prometheus"
    mkdir -p "${DATA_DIR}/grafana"
    mkdir -p "${DATA_DIR}/grafana/log"
    mkdir -p "${DATA_DIR}/loki"
    mkdir -p "${DATA_DIR}/alertmanager"
    mkdir -p "${CONFIG_DIR}/prometheus"
    mkdir -p "${CONFIG_DIR}/grafana/provisioning/datasources"
    mkdir -p "${CONFIG_DIR}/grafana/provisioning/dashboards"
    mkdir -p "${CONFIG_DIR}/loki"
    mkdir -p "${CONFIG_DIR}/alertmanager"
    
    # Set permissions for Grafana (runs as user 472)
    chown -R 472:472 "${DATA_DIR}/grafana"
    
    # Set permissions for Prometheus (runs as user 65534/nobody)
    chown -R 65534:65534 "${DATA_DIR}/prometheus"
    
    # Set permissions for Loki
    chown -R 10001:10001 "${DATA_DIR}/loki"
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Configure Prometheus
#-------------------------------------------------------------------------------
configure_prometheus() {
    log_section "Configuring Prometheus"
    
    PROMETHEUS_CONFIG="${CONFIG_DIR}/prometheus/prometheus.yml"
    
    if [[ ! -f "$PROMETHEUS_CONFIG" ]]; then
        log_info "Creating Prometheus configuration..."
        cat > "$PROMETHEUS_CONFIG" << 'EOF'
# Prometheus Configuration for Kingdom Watcher Node
global:
  scrape_interval: 15s
  evaluation_interval: 15s
  external_labels:
    monitor: 'kingdom-watcher'

# Alertmanager configuration
alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - alertmanager:9093

# Rule files
rule_files:
  - /etc/prometheus/rules/*.yml

# Scrape configurations
scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']
        labels:
          node: 'watcher'

  # Node exporter (if installed on targets)
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          node: 'watcher'
      # Add other Kingdom nodes here:
      # - targets: ['guardian:9100']
      #   labels:
      #     node: 'guardian'
      # - targets: ['builder:9100']
      #   labels:
      #     node: 'builder'
      # - targets: ['scribe:9100']
      #   labels:
      #     node: 'scribe'

  # Docker containers
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
        labels:
          node: 'watcher'

  # Grafana
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']
        labels:
          node: 'watcher'

  # Loki
  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']
        labels:
          node: 'watcher'
EOF
        log_success "Prometheus configuration created"
    else
        log_info "Prometheus configuration already exists"
    fi
    
    # Create alert rules directory and basic rules
    mkdir -p "${CONFIG_DIR}/prometheus/rules"
    
    if [[ ! -f "${CONFIG_DIR}/prometheus/rules/kingdom.yml" ]]; then
        cat > "${CONFIG_DIR}/prometheus/rules/kingdom.yml" << 'EOF'
# Kingdom Alert Rules
groups:
  - name: kingdom_alerts
    rules:
      - alert: NodeDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 90% on {{ $labels.instance }}"

      - alert: HighDiskUsage
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High disk usage on {{ $labels.instance }}"
          description: "Disk usage is above 85% on {{ $labels.instance }}"

      - alert: ContainerDown
        expr: absent(container_last_seen{name=~".+"})
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container {{ $labels.name }} has been down for more than 1 minute."
EOF
        log_success "Prometheus alert rules created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Grafana
#-------------------------------------------------------------------------------
configure_grafana() {
    log_section "Configuring Grafana"
    
    # Grafana datasource provisioning
    DATASOURCE_CONFIG="${CONFIG_DIR}/grafana/provisioning/datasources/datasources.yml"
    
    if [[ ! -f "$DATASOURCE_CONFIG" ]]; then
        log_info "Creating Grafana datasource configuration..."
        cat > "$DATASOURCE_CONFIG" << 'EOF'
# Grafana Datasource Provisioning
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://prometheus:9090
    isDefault: true
    editable: false

  - name: Loki
    type: loki
    access: proxy
    url: http://loki:3100
    editable: false
EOF
        log_success "Grafana datasource configuration created"
    fi
    
    # Grafana dashboard provisioning
    DASHBOARD_CONFIG="${CONFIG_DIR}/grafana/provisioning/dashboards/dashboards.yml"
    
    if [[ ! -f "$DASHBOARD_CONFIG" ]]; then
        log_info "Creating Grafana dashboard configuration..."
        cat > "$DASHBOARD_CONFIG" << 'EOF'
# Grafana Dashboard Provisioning
apiVersion: 1

providers:
  - name: 'Kingdom Dashboards'
    orgId: 1
    folder: 'Kingdom'
    type: file
    disableDeletion: false
    editable: true
    options:
      path: /var/lib/grafana/dashboards
EOF
        log_success "Grafana dashboard configuration created"
    fi
    
    # Create dashboards directory
    mkdir -p "${DATA_DIR}/grafana/dashboards"
    
    # Create Kingdom overview dashboard
    if [[ ! -f "${DATA_DIR}/grafana/dashboards/kingdom-overview.json" ]]; then
        cat > "${DATA_DIR}/grafana/dashboards/kingdom-overview.json" << 'EOF'
{
  "annotations": {
    "list": []
  },
  "editable": true,
  "fiscalYearStartMonth": 0,
  "graphTooltip": 0,
  "id": null,
  "links": [],
  "liveNow": false,
  "panels": [
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "red", "value": 0}
            ]
          }
        },
        "overrides": []
      },
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "count(up == 1)",
          "refId": "A"
        }
      ],
      "title": "Nodes Online",
      "type": "stat"
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "color": {
            "mode": "palette-classic"
          },
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 70},
              {"color": "red", "value": 90}
            ]
          },
          "unit": "percent"
        },
        "overrides": []
      },
      "gridPos": {"h": 4, "w": 6, "x": 6, "y": 0},
      "id": 2,
      "options": {
        "colorMode": "value",
        "graphMode": "area",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "pluginVersion": "10.0.0",
      "targets": [
        {
          "expr": "(1 - avg(rate(node_cpu_seconds_total{mode=\"idle\"}[5m]))) * 100",
          "refId": "A"
        }
      ],
      "title": "Average CPU Usage",
      "type": "stat"
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["kingdom"],
  "templating": {
    "list": []
  },
  "time": {
    "from": "now-1h",
    "to": "now"
  },
  "timepicker": {},
  "timezone": "",
  "title": "Kingdom Overview",
  "uid": "kingdom-overview",
  "version": 1,
  "weekStart": ""
}
EOF
        chown 472:472 "${DATA_DIR}/grafana/dashboards/kingdom-overview.json"
        log_success "Kingdom overview dashboard created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Loki
#-------------------------------------------------------------------------------
configure_loki() {
    log_section "Configuring Loki"
    
    LOKI_CONFIG="${CONFIG_DIR}/loki/loki-config.yml"
    
    if [[ ! -f "$LOKI_CONFIG" ]]; then
        log_info "Creating Loki configuration..."
        cat > "$LOKI_CONFIG" << 'EOF'
# Loki Configuration for Kingdom Watcher Node
auth_enabled: false

server:
  http_listen_port: 3100
  grpc_listen_port: 9096

common:
  instance_addr: 127.0.0.1
  path_prefix: /loki
  storage:
    filesystem:
      chunks_directory: /loki/chunks
      rules_directory: /loki/rules
  replication_factor: 1
  ring:
    kvstore:
      store: inmemory

query_range:
  results_cache:
    cache:
      embedded_cache:
        enabled: true
        max_size_mb: 100

schema_config:
  configs:
    - from: 2020-10-24
      store: boltdb-shipper
      object_store: filesystem
      schema: v11
      index:
        prefix: index_
        period: 24h

ruler:
  alertmanager_url: http://alertmanager:9093

limits_config:
  retention_period: 744h  # 31 days
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_entries_limit_per_query: 5000

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 744h
EOF
        log_success "Loki configuration created"
    else
        log_info "Loki configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Configure Alertmanager
#-------------------------------------------------------------------------------
configure_alertmanager() {
    log_section "Configuring Alertmanager"
    
    ALERTMANAGER_CONFIG="${CONFIG_DIR}/alertmanager/alertmanager.yml"
    
    if [[ ! -f "$ALERTMANAGER_CONFIG" ]]; then
        log_info "Creating Alertmanager configuration..."
        cat > "$ALERTMANAGER_CONFIG" << 'EOF'
# Alertmanager Configuration for Kingdom Watcher Node
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-receiver'
      continue: true

receivers:
  - name: 'default-receiver'
    # Configure webhook, email, slack, etc. as needed
    # webhook_configs:
    #   - url: 'http://localhost:5001/webhook'

  - name: 'critical-receiver'
    # Configure critical alert destinations
    # slack_configs:
    #   - api_url: 'https://hooks.slack.com/services/...'
    #     channel: '#alerts'

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF
        log_success "Alertmanager configuration created"
    else
        log_info "Alertmanager configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Watcher Node Configuration
#-------------------------------------------------------------------------------
configure_watcher() {
    log_section "Configuring Watcher Node"
    
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
# Kingdom Watcher Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export PATH="\${PATH}:${COMMANDS_DIR}"
EOF
        log_success "Kingdom environment configured"
    fi
    
    log_success "Watcher node configured"
}

#-------------------------------------------------------------------------------
# Create Systemd Services
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Systemd Services"
    
    # Watcher Node Service
    if [[ ! -f /etc/systemd/system/watcher-node.service ]]; then
        cat > /etc/systemd/system/watcher-node.service << EOF
[Unit]
Description=Watcher Node - Kingdom Network
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
        log_success "Watcher node service created"
    fi
    
    # Create docker-compose.yaml for monitoring stack
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Watcher Node Docker Compose - Monitoring Stack
# Prometheus + Grafana + Loki + Alertmanager

version: '3.8'

networks:
  monitoring:
    driver: bridge

volumes:
  prometheus_data:
  grafana_data:
  loki_data:
  alertmanager_data:

services:
  # Prometheus - Metrics collection
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${CONFIG_DIR}/prometheus/rules:/etc/prometheus/rules:ro
      - ${DATA_DIR}/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
      - '--web.external-url=/prometheus/'
    ports:
      - "127.0.0.1:${PROMETHEUS_PORT}:9090"
    networks:
      - monitoring

  # Grafana - Visualization
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/grafana:/var/lib/grafana
      - ${CONFIG_DIR}/grafana/provisioning:/etc/grafana/provisioning:ro
      - ${DATA_DIR}/grafana/dashboards:/var/lib/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=kingdom_watcher_admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=%(protocol)s://%(domain)s/grafana/
      - GF_SERVER_SERVE_FROM_SUB_PATH=true
      - GF_LOG_MODE=file
      - GF_LOG_FILE_PATH=/var/lib/grafana/log/grafana.log
    ports:
      - "127.0.0.1:${GRAFANA_PORT}:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

  # Loki - Log aggregation
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - ${DATA_DIR}/loki:/loki
    command: -config.file=/etc/loki/local-config.yaml
    ports:
      - "127.0.0.1:${LOKI_PORT}:3100"
    networks:
      - monitoring

  # Promtail - Log shipping (optional, for local logs)
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - ${CONFIG_DIR}/promtail:/etc/promtail:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
    depends_on:
      - loki

  # Alertmanager - Alert routing
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ${DATA_DIR}/alertmanager:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
      - '--web.external-url=/alertmanager/'
    ports:
      - "127.0.0.1:${ALERTMANAGER_PORT}:9093"
    networks:
      - monitoring

  # Node Exporter - System metrics
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
      - "127.0.0.1:9100:9100"
    networks:
      - monitoring
EOF
        log_success "Docker compose configuration created"
    fi
    
    # Create Promtail config
    mkdir -p "${CONFIG_DIR}/promtail"
    if [[ ! -f "${CONFIG_DIR}/promtail/config.yml" ]]; then
        cat > "${CONFIG_DIR}/promtail/config.yml" << 'EOF'
server:
  http_listen_port: 9080
  grpc_listen_port: 0

positions:
  filename: /tmp/positions.yaml

clients:
  - url: http://loki:3100/loki/api/v1/push

scrape_configs:
  - job_name: system
    static_configs:
      - targets:
          - localhost
        labels:
          job: varlogs
          __path__: /var/log/*log

  - job_name: kingdom
    static_configs:
      - targets:
          - localhost
        labels:
          job: kingdom
          __path__: /opt/kingdom/**/*log
EOF
        log_success "Promtail configuration created"
    fi
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Watcher Node Setup Complete"
    
    echo ""
    echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║           Watcher Node Bootstrap Complete                   ║${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${CYAN}║${NC} Role:       ${BLUE}Watcher${NC}"
    echo -e "${CYAN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Services:"
    echo -e "${CYAN}║${NC}   - Nginx:     $(systemctl is-active nginx)"
    echo -e "${CYAN}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${CYAN}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${CYAN}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Monitoring Stack Ports:"
    echo -e "${CYAN}║${NC}   - Prometheus:    ${PROMETHEUS_PORT}"
    echo -e "${CYAN}║${NC}   - Grafana:       ${GRAFANA_PORT}"
    echo -e "${CYAN}║${NC}   - Loki:          ${LOKI_PORT}"
    echo -e "${CYAN}║${NC}   - Alertmanager:  ${ALERTMANAGER_PORT}"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Next Steps:"
    echo -e "${CYAN}║${NC}   1. Verify DNS points to this server"
    echo -e "${CYAN}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${CYAN}║${NC}   3. Start services: systemctl start watcher-node"
    echo -e "${CYAN}║${NC}   4. Access Grafana: http://${DOMAIN}/grafana/"
    echo -e "${CYAN}║${NC}   5. Default Grafana login: admin / kingdom_watcher_admin"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Helper Commands (after re-login):"
    echo -e "${CYAN}║${NC}   - watcher-status.sh  - Show watcher status"
    echo -e "${CYAN}║${NC}   - status.sh          - Show node status"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Watcher Node Bootstrap - ${DOMAIN}"
    log_info "Starting bootstrap at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    configure_firewall
    configure_fail2ban
    create_directories
    configure_prometheus
    configure_grafana
    configure_loki
    configure_alertmanager
    configure_nginx
    setup_ssl
    configure_watcher
    create_services
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
