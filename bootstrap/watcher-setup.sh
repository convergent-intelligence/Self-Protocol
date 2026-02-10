#!/bin/bash
#===============================================================================
# Watcher Node Bootstrap Script for Kingdom Network
# VPS: Debian 12 | Role: Watcher in Kingdom Hierarchy
# Services: Prometheus, Grafana, Loki (Monitoring Stack via Docker)
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
NODE_ROLE="watcher"
INSTALL_DIR="/opt/kingdom"
DATA_DIR="${INSTALL_DIR}/data"
CONFIG_DIR="${INSTALL_DIR}/config"

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
        python3
        python3-pip
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
    
    # Allow Prometheus (port 9090) - internal only by default
    log_info "Allowing Prometheus (port 9090)..."
    ufw allow 9090/tcp comment 'Prometheus'
    
    # Allow Grafana (port 3000)
    log_info "Allowing Grafana (port 3000)..."
    ufw allow 3000/tcp comment 'Grafana'
    
    # Allow Loki (port 3100) - for log ingestion
    log_info "Allowing Loki (port 3100)..."
    ufw allow 3100/tcp comment 'Loki'
    
    # Allow Node Exporter (port 9100) - for metrics collection
    log_info "Allowing Node Exporter (port 9100)..."
    ufw allow 9100/tcp comment 'Node Exporter'
    
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
    
    # Create Grafana filter
    GRAFANA_FILTER="/etc/fail2ban/filter.d/grafana.conf"
    if [[ ! -f "$GRAFANA_FILTER" ]]; then
        cat > "$GRAFANA_FILTER" << 'EOF'
[Definition]
failregex = ^.*lvl=warn.*msg="Invalid username or password".*remote_addr=<HOST>.*$
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
# SSH Hardening
#-------------------------------------------------------------------------------
harden_ssh() {
    log_section "Hardening SSH Configuration"
    
    SSH_CONFIG="/etc/ssh/sshd_config.d/99-kingdom-hardening.conf"
    
    if [[ ! -f "$SSH_CONFIG" ]]; then
        log_info "Creating SSH hardening configuration..."
        cat > "$SSH_CONFIG" << 'EOF'
# Kingdom Watcher Node SSH Hardening
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
# Watcher Node Directory Structure
#-------------------------------------------------------------------------------
create_directory_structure() {
    log_section "Creating Watcher Node Directory Structure"
    
    # Create main directories
    mkdir -p "${INSTALL_DIR}"
    mkdir -p "${CONFIG_DIR}"
    mkdir -p "${DATA_DIR}"
    mkdir -p "${INSTALL_DIR}/commands"
    mkdir -p "${INSTALL_DIR}/logs"
    
    # Monitoring-specific directories
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
    
    log_success "Directory structure created"
}

#-------------------------------------------------------------------------------
# Prometheus Configuration
#-------------------------------------------------------------------------------
configure_prometheus() {
    log_section "Configuring Prometheus"
    
    PROM_CONFIG="${CONFIG_DIR}/prometheus/prometheus.yml"
    
    if [[ ! -f "$PROM_CONFIG" ]]; then
        log_info "Creating Prometheus configuration..."
        cat > "$PROM_CONFIG" << 'EOF'
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

  # Node Exporter - local metrics
  - job_name: 'node'
    static_configs:
      - targets: ['node-exporter:9100']

  # Grafana metrics
  - job_name: 'grafana'
    static_configs:
      - targets: ['grafana:3000']

  # Loki metrics
  - job_name: 'loki'
    static_configs:
      - targets: ['loki:3100']

  # Kingdom Guardian Node (add when deployed)
  # - job_name: 'guardian'
  #   static_configs:
  #     - targets: ['guardian.kingdom.local:9100']

  # Kingdom Builder Node (add when deployed)
  # - job_name: 'builder'
  #   static_configs:
  #     - targets: ['builder.kingdom.local:9100']

  # Kingdom Scribe Node (add when deployed)
  # - job_name: 'scribe'
  #   static_configs:
  #     - targets: ['scribe.kingdom.local:9100']
EOF
        log_success "Prometheus configuration created"
    else
        log_info "Prometheus configuration already exists"
    fi
    
    # Create alert rules directory and basic rules
    mkdir -p "${CONFIG_DIR}/prometheus/rules"
    
    ALERT_RULES="${CONFIG_DIR}/prometheus/rules/kingdom-alerts.yml"
    if [[ ! -f "$ALERT_RULES" ]]; then
        cat > "$ALERT_RULES" << 'EOF'
# Kingdom Alert Rules
groups:
  - name: kingdom-node-alerts
    rules:
      - alert: NodeDown
        expr: up == 0
        for: 1m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} has been down for more than 1 minute."

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
          description: "Disk usage is above 85%."
EOF
        log_success "Alert rules created"
    fi
}

#-------------------------------------------------------------------------------
# Grafana Configuration
#-------------------------------------------------------------------------------
configure_grafana() {
    log_section "Configuring Grafana"
    
    # Grafana datasources provisioning
    DATASOURCES="${CONFIG_DIR}/grafana/provisioning/datasources/datasources.yml"
    
    if [[ ! -f "$DATASOURCES" ]]; then
        log_info "Creating Grafana datasources configuration..."
        cat > "$DATASOURCES" << 'EOF'
# Grafana Datasources for Kingdom Watcher
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
        log_success "Grafana datasources configured"
    fi
    
    # Grafana dashboards provisioning
    DASHBOARDS="${CONFIG_DIR}/grafana/provisioning/dashboards/dashboards.yml"
    
    if [[ ! -f "$DASHBOARDS" ]]; then
        cat > "$DASHBOARDS" << 'EOF'
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
        log_success "Grafana dashboard provisioning configured"
    fi
    
    # Create Kingdom overview dashboard
    mkdir -p "${CONFIG_DIR}/grafana/dashboards"
    KINGDOM_DASHBOARD="${CONFIG_DIR}/grafana/dashboards/kingdom-overview.json"
    
    if [[ ! -f "$KINGDOM_DASHBOARD" ]]; then
        cat > "$KINGDOM_DASHBOARD" << 'EOF'
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
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "red", "value": 0}
            ]
          },
          "unit": "short"
        }
      },
      "gridPos": {"h": 4, "w": 6, "x": 0, "y": 0},
      "id": 1,
      "options": {
        "colorMode": "value",
        "graphMode": "none",
        "justifyMode": "auto",
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "textMode": "auto"
      },
      "title": "Nodes Up",
      "type": "stat",
      "targets": [
        {
          "expr": "count(up == 1)",
          "refId": "A"
        }
      ]
    },
    {
      "datasource": {
        "type": "prometheus",
        "uid": "prometheus"
      },
      "fieldConfig": {
        "defaults": {
          "mappings": [],
          "thresholds": {
            "mode": "absolute",
            "steps": [
              {"color": "green", "value": null},
              {"color": "yellow", "value": 50},
              {"color": "red", "value": 80}
            ]
          },
          "unit": "percent"
        }
      },
      "gridPos": {"h": 8, "w": 12, "x": 0, "y": 4},
      "id": 2,
      "options": {
        "orientation": "auto",
        "reduceOptions": {
          "calcs": ["lastNotNull"],
          "fields": "",
          "values": false
        },
        "showThresholdLabels": false,
        "showThresholdMarkers": true
      },
      "title": "CPU Usage by Node",
      "type": "gauge",
      "targets": [
        {
          "expr": "100 - (avg by(instance) (rate(node_cpu_seconds_total{mode=\"idle\"}[5m])) * 100)",
          "legendFormat": "{{instance}}",
          "refId": "A"
        }
      ]
    }
  ],
  "refresh": "30s",
  "schemaVersion": 38,
  "style": "dark",
  "tags": ["kingdom"],
  "templating": {"list": []},
  "time": {"from": "now-1h", "to": "now"},
  "timepicker": {},
  "timezone": "",
  "title": "Kingdom Overview",
  "uid": "kingdom-overview",
  "version": 1,
  "weekStart": ""
}
EOF
        log_success "Kingdom overview dashboard created"
    fi
}

#-------------------------------------------------------------------------------
# Loki Configuration
#-------------------------------------------------------------------------------
configure_loki() {
    log_section "Configuring Loki"
    
    LOKI_CONFIG="${CONFIG_DIR}/loki/loki-config.yml"
    
    if [[ ! -f "$LOKI_CONFIG" ]]; then
        log_info "Creating Loki configuration..."
        cat > "$LOKI_CONFIG" << 'EOF'
# Loki Configuration for Kingdom Watcher
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
  retention_period: 720h
  enforce_metric_name: false
  reject_old_samples: true
  reject_old_samples_max_age: 168h
  max_cache_freshness_per_query: 10m
  split_queries_by_interval: 15m
EOF
        log_success "Loki configuration created"
    else
        log_info "Loki configuration already exists"
    fi
}

#-------------------------------------------------------------------------------
# Alertmanager Configuration
#-------------------------------------------------------------------------------
configure_alertmanager() {
    log_section "Configuring Alertmanager"
    
    ALERTMANAGER_CONFIG="${CONFIG_DIR}/alertmanager/alertmanager.yml"
    
    if [[ ! -f "$ALERTMANAGER_CONFIG" ]]; then
        log_info "Creating Alertmanager configuration..."
        cat > "$ALERTMANAGER_CONFIG" << 'EOF'
# Alertmanager Configuration for Kingdom Watcher
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 10s
  group_interval: 10s
  repeat_interval: 1h
  receiver: 'kingdom-alerts'
  routes:
    - match:
        severity: critical
      receiver: 'kingdom-critical'

receivers:
  - name: 'kingdom-alerts'
    # Configure webhook, email, or Slack here
    # webhook_configs:
    #   - url: 'http://guardian:3000/api/alerts'

  - name: 'kingdom-critical'
    # Critical alerts - add PagerDuty, SMS, etc.

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
# Docker Compose Setup
#-------------------------------------------------------------------------------
create_docker_compose() {
    log_section "Creating Docker Compose Configuration"
    
    COMPOSE_FILE="${INSTALL_DIR}/docker-compose.yaml"
    
    if [[ ! -f "$COMPOSE_FILE" ]]; then
        log_info "Creating Docker Compose file..."
        cat > "$COMPOSE_FILE" << EOF
# Watcher Node Docker Compose - Kingdom Monitoring Stack
version: '3.8'

networks:
  kingdom-monitoring:
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
      - ${CONFIG_DIR}/prometheus/prometheus.yml:/etc/prometheus/prometheus.yml:ro
      - ${CONFIG_DIR}/prometheus/rules:/etc/prometheus/rules:ro
      - prometheus_data:/prometheus
    command:
      - '--config.file=/etc/prometheus/prometheus.yml'
      - '--storage.tsdb.path=/prometheus'
      - '--web.console.libraries=/etc/prometheus/console_libraries'
      - '--web.console.templates=/etc/prometheus/consoles'
      - '--storage.tsdb.retention.time=30d'
      - '--web.enable-lifecycle'
    ports:
      - "9090:9090"
    networks:
      - kingdom-monitoring

  # Grafana - Visualization
  grafana:
    image: grafana/grafana:latest
    container_name: grafana
    restart: unless-stopped
    volumes:
      - grafana_data:/var/lib/grafana
      - ${CONFIG_DIR}/grafana/provisioning:/etc/grafana/provisioning:ro
      - ${CONFIG_DIR}/grafana/dashboards:/var/lib/grafana/dashboards:ro
      - ${DATA_DIR}/grafana/log:/var/log/grafana
    environment:
      - GF_SECURITY_ADMIN_USER=admin
      - GF_SECURITY_ADMIN_PASSWORD=kingdom-watcher-admin
      - GF_USERS_ALLOW_SIGN_UP=false
      - GF_SERVER_ROOT_URL=http://localhost:3000
      - GF_LOG_MODE=file
      - GF_LOG_FILE_PATH=/var/log/grafana/grafana.log
    ports:
      - "3000:3000"
    networks:
      - kingdom-monitoring
    depends_on:
      - prometheus
      - loki

  # Loki - Log Aggregation
  loki:
    image: grafana/loki:latest
    container_name: loki
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/loki/loki-config.yml:/etc/loki/local-config.yaml:ro
      - loki_data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    ports:
      - "3100:3100"
    networks:
      - kingdom-monitoring

  # Promtail - Log Collector (for local logs)
  promtail:
    image: grafana/promtail:latest
    container_name: promtail
    restart: unless-stopped
    volumes:
      - /var/log:/var/log:ro
      - ${CONFIG_DIR}/promtail:/etc/promtail:ro
    command: -config.file=/etc/promtail/promtail-config.yml
    networks:
      - kingdom-monitoring
    depends_on:
      - loki

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
      - '--path.rootfs=/rootfs'
      - '--path.sysfs=/host/sys'
      - '--collector.filesystem.mount-points-exclude=^/(sys|proc|dev|host|etc)($$|/)'
    ports:
      - "9100:9100"
    networks:
      - kingdom-monitoring

  # Alertmanager - Alert Routing
  alertmanager:
    image: prom/alertmanager:latest
    container_name: alertmanager
    restart: unless-stopped
    volumes:
      - ${CONFIG_DIR}/alertmanager/alertmanager.yml:/etc/alertmanager/alertmanager.yml:ro
      - alertmanager_data:/alertmanager
    command:
      - '--config.file=/etc/alertmanager/alertmanager.yml'
      - '--storage.path=/alertmanager'
    ports:
      - "9093:9093"
    networks:
      - kingdom-monitoring
EOF
        log_success "Docker Compose file created"
    else
        log_info "Docker Compose file already exists"
    fi
    
    # Create Promtail configuration
    mkdir -p "${CONFIG_DIR}/promtail"
    PROMTAIL_CONFIG="${CONFIG_DIR}/promtail/promtail-config.yml"
    
    if [[ ! -f "$PROMTAIL_CONFIG" ]]; then
        cat > "$PROMTAIL_CONFIG" << 'EOF'
# Promtail Configuration for Kingdom Watcher
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
          __path__: /var/log/kingdom/*.log
EOF
        log_success "Promtail configuration created"
    fi
}

#-------------------------------------------------------------------------------
# Create Systemd Service
#-------------------------------------------------------------------------------
create_services() {
    log_section "Creating Systemd Services"
    
    # Watcher Node Service
    if [[ ! -f /etc/systemd/system/watcher-node.service ]]; then
        cat > /etc/systemd/system/watcher-node.service << EOF
[Unit]
Description=Watcher Node - Kingdom Monitoring Stack
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
    
    systemctl daemon-reload
    log_success "Systemd services configured"
}

#-------------------------------------------------------------------------------
# Configure Watcher Node
#-------------------------------------------------------------------------------
configure_watcher() {
    log_section "Configuring Watcher Node"
    
    # Copy helper commands
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    COMMANDS_DIR="${INSTALL_DIR}/commands"
    
    if [[ -d "${SCRIPT_DIR}/commands" ]]; then
        cp "${SCRIPT_DIR}/commands/watcher-status.sh" "$COMMANDS_DIR/" 2>/dev/null || true
        chmod +x "$COMMANDS_DIR/"*.sh 2>/dev/null || true
        log_success "Helper commands installed to ${COMMANDS_DIR}"
    fi
    
    # Add commands to PATH via profile.d
    if [[ ! -f /etc/profile.d/kingdom.sh ]]; then
        cat > /etc/profile.d/kingdom.sh << EOF
# Kingdom Watcher Node - Path additions
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="${NODE_ROLE}"
export PATH="\${PATH}:${COMMANDS_DIR}"
EOF
        log_success "Kingdom environment configured"
    fi
    
    # Create log directory
    mkdir -p /var/log/kingdom
    
    log_success "Watcher node configured"
}

#-------------------------------------------------------------------------------
# Final Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "Watcher Node Setup Complete"
    
    echo ""
    echo -e "${PURPLE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║           Watcher Node Bootstrap Complete                   ║${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Role:       ${BLUE}Watcher (Monitoring)${NC}"
    echo -e "${PURPLE}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Services:"
    echo -e "${PURPLE}║${NC}   - Docker:    $(systemctl is-active docker)"
    echo -e "${PURPLE}║${NC}   - Fail2Ban:  $(systemctl is-active fail2ban)"
    echo -e "${PURPLE}║${NC}   - UFW:       $(ufw status | head -1)"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Monitoring Stack (after start):"
    echo -e "${PURPLE}║${NC}   - Prometheus:    http://localhost:9090"
    echo -e "${PURPLE}║${NC}   - Grafana:       http://localhost:3000"
    echo -e "${PURPLE}║${NC}   - Loki:          http://localhost:3100"
    echo -e "${PURPLE}║${NC}   - Alertmanager:  http://localhost:9093"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Default Grafana Credentials:"
    echo -e "${PURPLE}║${NC}   - Username: admin"
    echo -e "${PURPLE}║${NC}   - Password: kingdom-watcher-admin"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Next Steps:"
    echo -e "${PURPLE}║${NC}   1. Start services: systemctl start watcher-node"
    echo -e "${PURPLE}║${NC}   2. Change Grafana admin password"
    echo -e "${PURPLE}║${NC}   3. Add Kingdom nodes to Prometheus targets"
    echo -e "${PURPLE}║${NC}   4. Configure alert receivers"
    echo -e "${PURPLE}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC} Helper Commands (after re-login):"
    echo -e "${PURPLE}║${NC}   - watcher-status.sh  - Show monitoring status"
    echo -e "${PURPLE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main Execution
#-------------------------------------------------------------------------------
main() {
    log_section "Watcher Node Bootstrap - Kingdom Monitoring"
    log_info "Starting bootstrap at $(date)"
    
    preflight_checks
    install_dependencies
    install_docker
    configure_firewall
    configure_fail2ban
    harden_ssh
    create_directory_structure
    configure_prometheus
    configure_grafana
    configure_loki
    configure_alertmanager
    create_docker_compose
    create_services
    configure_watcher
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
