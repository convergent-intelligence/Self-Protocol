#!/bin/bash
#===============================================================================
# Watcher Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Watcher in Kingdom Hierarchy
# Purpose: Monitoring, observability, log aggregation
# Integrates: Prometheus, Grafana, Loki
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
MONITORING_DIR="${INSTALL_DIR}/monitoring"

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
    
    # Allow Prometheus (port 9090) - internal only by default
    log_info "Allowing Prometheus (port 9090) from internal..."
    ufw allow from 10.0.0.0/8 to any port 9090 proto tcp comment 'Prometheus Internal'
    
    # Allow Grafana (port 3000) - will be proxied through nginx
    log_info "Allowing Grafana (port 3000) from localhost..."
    ufw allow from 127.0.0.1 to any port 3000 proto tcp comment 'Grafana Local'
    
    # Allow Loki (port 3100) - internal only
    log_info "Allowing Loki (port 3100) from internal..."
    ufw allow from 10.0.0.0/8 to any port 3100 proto tcp comment 'Loki Internal'
    
    # Allow Node Exporter (port 9100) - for other nodes to scrape
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

[grafana]
enabled = true
port = http,https
filter = grafana
logpath = /opt/kingdom/data/grafana/log/grafana.log
maxretry = 5
bantime = 1h
EOF
        log_success "Fail2Ban jail configuration created"
    else
        log_info "Fail2Ban jail configuration already exists"
    fi
    
    # Create Grafana filter for Fail2Ban
    if [[ ! -f /etc/fail2ban/filter.d/grafana.conf ]]; then
        cat > /etc/fail2ban/filter.d/grafana.conf << 'EOF'
[Definition]
failregex = ^.*Failed to authenticate user.*client_ip=<HOST>.*$
            ^.*Invalid username or password.*client_ip=<HOST>.*$
ignoreregex =
EOF
        log_success "Grafana Fail2Ban filter created"
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
# Monitoring and Observability Gateway

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
    
    # Prometheus proxy (protected)
    location /prometheus/ {
        proxy_pass http://127.0.0.1:9090/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        # Basic auth recommended for production
        # auth_basic "Prometheus";
        # auth_basic_user_file /etc/nginx/.htpasswd;
    }
    
    # Loki push endpoint (for log ingestion)
    location /loki/ {
        proxy_pass http://127.0.0.1:3100/;
        proxy_http_version 1.1;
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
    }
    
    # Health check endpoint
    location /health {
        access_log off;
        return 200 "Watcher Node OK\\n";
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
    <title>Watcher Node - Kingdom Network</title>
    <style>
        body { font-family: system-ui; background: #0a0a0a; color: #e0e0e0; 
               display: flex; justify-content: center; align-items: center; 
               min-height: 100vh; margin: 0; }
        .container { text-align: center; padding: 2rem; }
        h1 { color: #06b6d4; }
        .status { color: #22c55e; }
        .links { margin-top: 2rem; }
        .links a { color: #06b6d4; margin: 0 1rem; text-decoration: none; }
        .links a:hover { text-decoration: underline; }
    </style>
</head>
<body>
    <div class="container">
        <h1>👁️ Watcher Node</h1>
        <p class="status">Node Status: Active</p>
        <p>Role: Watcher in Kingdom Hierarchy</p>
        <p>Purpose: Monitoring, Observability, Log Aggregation</p>
        <div class="links">
            <a href="/grafana/">Grafana Dashboards</a>
            <a href="/prometheus/">Prometheus Metrics</a>
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
    mkdir -p "${MONITORING_DIR}"
    mkdir -p "${INSTALL_DIR}/config"
    mkdir -p "${INSTALL_DIR}/commands"
    mkdir -p "${INSTALL_DIR}/logs"
    
    # Monitoring-specific directories
    mkdir -p "${DATA_DIR}/prometheus"
    mkdir -p "${DATA_DIR}/grafana"
    mkdir -p "${DATA_DIR}/grafana/log"
    mkdir -p "${DATA_DIR}/loki"
    mkdir -p "${DATA_DIR}/alertmanager"
    mkdir -p "${MONITORING_DIR}/rules"
    mkdir -p "${MONITORING_DIR}/dashboards"
    
    # Set permissions
    chown -R 65534:65534 "${DATA_DIR}/prometheus"  # nobody user for Prometheus
    chown -R 472:472 "${DATA_DIR}/grafana"          # grafana user
    chown -R 10001:10001 "${DATA_DIR}/loki"         # loki user
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Configure Prometheus
#-------------------------------------------------------------------------------
configure_prometheus() {
    log_section "Configuring Prometheus"
    
    PROMETHEUS_CONFIG="${MONITORING_DIR}/prometheus.yml"
    
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

  # Node Exporter - local
  - job_name: 'node-exporter'
    static_configs:
      - targets: ['localhost:9100']
        labels:
          node: 'watcher'

  # Kingdom Guardian Node
  - job_name: 'guardian'
    static_configs:
      - targets: ['guardian.kingdom.local:9100']
        labels:
          node: 'guardian'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):\d+'
        replacement: '${1}'

  # Kingdom Builder Node
  - job_name: 'builder'
    static_configs:
      - targets: ['builder.kingdom.local:9100']
        labels:
          node: 'builder'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):\d+'
        replacement: '${1}'

  # Kingdom Scribe Node
  - job_name: 'scribe'
    static_configs:
      - targets: ['scribe.kingdom.local:9100']
        labels:
          node: 'scribe'
    relabel_configs:
      - source_labels: [__address__]
        target_label: instance
        regex: '([^:]+):\d+'
        replacement: '${1}'

  # Docker containers
  - job_name: 'docker'
    static_configs:
      - targets: ['localhost:9323']
        labels:
          node: 'watcher'

  # Grafana
  - job_name: 'grafana'
    static_configs:
      - targets: ['localhost:3000']
        labels:
          node: 'watcher'

  # Loki
  - job_name: 'loki'
    static_configs:
      - targets: ['localhost:3100']
        labels:
          node: 'watcher'
EOF
        log_success "Prometheus configuration created"
    else
        log_info "Prometheus configuration already exists"
    fi
    
    # Create alert rules
    ALERT_RULES="${MONITORING_DIR}/rules/kingdom-alerts.yml"
    if [[ ! -f "$ALERT_RULES" ]]; then
        log_info "Creating alert rules..."
        cat > "$ALERT_RULES" << 'EOF'
# Kingdom Alert Rules
groups:
  - name: kingdom-nodes
    rules:
      - alert: NodeDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "{{ $labels.job }} node has been down for more than 1 minute."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 5 minutes."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 5 minutes."

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk usage is above 85% on {{ $labels.mountpoint }}."

      - alert: DiskSpaceCritical
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 95
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Critical disk space on {{ $labels.instance }}"
          description: "Disk usage is above 95% on {{ $labels.mountpoint }}."

  - name: kingdom-services
    rules:
      - alert: ContainerDown
        expr: absent(container_last_seen{name=~".+"})
        for: 1m
        labels:
          severity: warning
        annotations:
          summary: "Container {{ $labels.name }} is down"
          description: "Container has been down for more than 1 minute."

      - alert: HighContainerCPU
        expr: rate(container_cpu_usage_seconds_total[5m]) * 100 > 80
        for: 5m
        labels:
          severity: warning
        annotations:
          summary: "High CPU in container {{ $labels.name }}"
          description: "Container CPU usage is above 80%."
EOF
        log_success "Alert rules created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Grafana
#-------------------------------------------------------------------------------
configure_grafana() {
    log_section "Configuring Grafana"
    
    GRAFANA_CONFIG="${MONITORING_DIR}/grafana.ini"
    
    if [[ ! -f "$GRAFANA_CONFIG" ]]; then
        log_info "Creating Grafana configuration..."
        cat > "$GRAFANA_CONFIG" << EOF
# Grafana Configuration for Kingdom Watcher Node
[server]
protocol = http
http_port = 3000
domain = ${DOMAIN}
root_url = %(protocol)s://%(domain)s/grafana/
serve_from_sub_path = true

[database]
type = sqlite3
path = /var/lib/grafana/grafana.db

[security]
admin_user = admin
admin_password = kingdom-watcher-admin
secret_key = kingdom-watcher-secret-key-change-me

[users]
allow_sign_up = false
auto_assign_org = true
auto_assign_org_role = Viewer

[auth.anonymous]
enabled = false

[log]
mode = file
level = info

[log.file]
log_rotate = true
max_lines = 1000000
max_size_shift = 28
daily_rotate = true
max_days = 7

[alerting]
enabled = true
execute_alerts = true

[unified_alerting]
enabled = true

[feature_toggles]
enable = publicDashboards
EOF
        log_success "Grafana configuration created"
    else
        log_info "Grafana configuration already exists"
    fi
    
    # Create datasource provisioning
    DATASOURCE_DIR="${MONITORING_DIR}/provisioning/datasources"
    mkdir -p "$DATASOURCE_DIR"
    
    if [[ ! -f "${DATASOURCE_DIR}/datasources.yml" ]]; then
        log_info "Creating Grafana datasource provisioning..."
        cat > "${DATASOURCE_DIR}/datasources.yml" << 'EOF'
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
    jsonData:
      maxLines: 1000
EOF
        log_success "Grafana datasource provisioning created"
    fi
    
    # Create dashboard provisioning
    DASHBOARD_DIR="${MONITORING_DIR}/provisioning/dashboards"
    mkdir -p "$DASHBOARD_DIR"
    
    if [[ ! -f "${DASHBOARD_DIR}/dashboards.yml" ]]; then
        log_info "Creating Grafana dashboard provisioning..."
        cat > "${DASHBOARD_DIR}/dashboards.yml" << 'EOF'
# Grafana Dashboard Provisioning
apiVersion: 1

providers:
  - name: 'Kingdom Dashboards'
    orgId: 1
    folder: 'Kingdom'
    folderUid: 'kingdom'
    type: file
    disableDeletion: false
    updateIntervalSeconds: 30
    allowUiUpdates: true
    options:
      path: /etc/grafana/dashboards
EOF
        log_success "Grafana dashboard provisioning created"
    fi
}

#-------------------------------------------------------------------------------
# Configure Loki
#-------------------------------------------------------------------------------
configure_loki() {
    log_section "Configuring Loki"
    
    LOKI_CONFIG="${MONITORING_DIR}/loki-config.yml"
    
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
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  ingestion_rate_mb: 16
  ingestion_burst_size_mb: 24

chunk_store_config:
  max_look_back_period: 0s

table_manager:
  retention_deletes_enabled: true
  retention_period: 720h
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
    
    ALERTMANAGER_CONFIG="${MONITORING_DIR}/alertmanager.yml"
    
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
    # Configure webhook, email, or Slack here
    # webhook_configs:
    #   - url: 'http://localhost:5001/webhook'

  - name: 'critical-receiver'
    # Configure critical alert destinations
    # slack_configs:
    #   - api_url: 'https://hooks.slack.com/services/xxx'
    #     channel: '#kingdom-alerts'

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
# Configure Watcher Node
#-------------------------------------------------------------------------------
configure_watcher() {
    log_section "Configuring Watcher Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    # Create watcher node configuration
    if [[ ! -f "${CONFIG_DIR}/watcher.yaml" ]]; then
        cat > "${CONFIG_DIR}/watcher.yaml" << EOF
# Watcher Node Configuration
node:
  role: watcher
  domain: ${DOMAIN}
  
monitoring:
  prometheus:
    port: 9090
    retention: 15d
  grafana:
    port: 3000
    admin_user: admin
  loki:
    port: 3100
    retention: 30d
  alertmanager:
    port: 9093

targets:
  - name: guardian
    host: guardian.kingdom.local
    port: 9100
  - name: builder
    host: builder.kingdom.local
    port: 9100
  - name: scribe
    host: scribe.kingdom.local
    port: 9100
EOF
        log_success "Watcher configuration created"
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
# Kingdom Watcher Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="watcher"
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
Description=Watcher Node - Kingdom Network Monitoring
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
  # Prometheus - Metrics Collection
  prometheus:
    image: prom/prometheus:latest
    container_name: prometheus
    restart: unless-stopped
    volumes:
      - ${MONITORING_DIR}/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${MONITORING_DIR}/rules:/etc/prometheus/rules:ro
      - ${DATA_DIR}/prometheus:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--storage.tsdb.retention.time=15d'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--web.enable-lifecycle'
    ports:
      - "127.0.0.1:9090:9090"
    networks:
      - monitoring

  # Grafana - Visualization
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - ${DATA_DIR}/grafana:/var/lib/grafana
      - ${MONITORING_DIR}/grafana.ini:/etc/grafana/grafana.ini:ro
      - ${MONITORING_DIR}/provisioning:/etc/grafana/provisioning:ro
      - ${MONITORING_DIR}/dashboards:/etc/grafana/dashboards:ro
    environment:
      - GF_SECURITY_ADMIN_PASSWORD=kingdom-watcher-admin
      - GF_USERS_ALLOW_SIGN_UP=false
    ports:
      - "127.0.0.1:3000:3000"
    networks:
      - monitoring
    depends_on:
      - prometheus

  # Loki - Log Aggregation
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - ${MONITORING_DIR}/loki-config.yml:/etc/loki/local-config.yaml:ro
      - ${DATA_DIR}/loki:/loki
    command: -config.file=/etc/loki/local-config.yaml
    ports:
      - "127.0.0.1:3100:3100"
    networks:
      - monitoring

  # Promtail - Log Shipping (local)
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - ${INSTALL_DIR}/logs:/kingdom/logs:ro
      - ${MONITORING_DIR}/promtail-config.yml:/etc/promtail/config.yml:ro
    command: -config.file=/etc/promtail/config.yml
    networks:
      - monitoring
    depends_on:
      - loki

  # Alertmanager - Alert Routing
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ${MONITORING_DIR}/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - ${DATA_DIR}/alertmanager:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "127.0.0.1:9093:9093"
    networks:
      - monitoring

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
      - monitoring
EOF
        log_success "Docker compose configuration created"
    fi
    
    # Create Promtail configuration
    if [[ ! -f "${MONITORING_DIR}/promtail-config.yml" ]]; then
        cat > "${MONITORING_DIR}/promtail-config.yml" << 'EOF'
# Promtail Configuration
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
          node: watcher
          __path__: /var/log/*log

  - job_name: kingdom
    static_configs:
      - targets:
          - localhost
        labels:
          job: kingdom
          node: watcher
          __path__: /kingdom/logs/*.log
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
    echo -e "${CYAN}║${NC} Monitoring Stack:"
    echo -e "${CYAN}║${NC}   - Prometheus: http://localhost:9090"
    echo -e "${CYAN}║${NC}   - Grafana:    http://localhost:3000"
    echo -e "${CYAN}║${NC}   - Loki:       http://localhost:3100"
    echo -e "${CYAN}║${NC}   - Alertmanager: http://localhost:9093"
    echo -e "${CYAN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Next Steps:"
    echo -e "${CYAN}║${NC}   1. Verify DNS points to this server"
    echo -e "${CYAN}║${NC}   2. Run: certbot --nginx -d ${DOMAIN}"
    echo -e "${CYAN}║${NC}   3. Start services: systemctl start watcher-node"
    echo -e "${CYAN}║${NC}   4. Access Grafana: https://${DOMAIN}/grafana/"
    echo -e "${CYAN}║${NC}   5. Default Grafana login: admin / kingdom-watcher-admin"
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
