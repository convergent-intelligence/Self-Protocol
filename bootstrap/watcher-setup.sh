#!/bin/bash
#===============================================================================
# Watcher Node Bootstrap Script
# VPS: Debian 12 | Role: Watcher in Kingdom Hierarchy
# Integrates: Monitoring, Alerting, Kingdom Observation
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# Each section checks for existing state before making changes
#===============================================================================

set -euo pipefail

# Configuration
DOMAIN="${WATCHER_DOMAIN:-watcher.kingdom.local}"
NODE_ROLE="watcher"
INSTALL_DIR="/opt/kingdom"
REPOS_DIR="${INSTALL_DIR}/repos"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN} $1${NC}"
    echo -e "${GREEN}========================================${NC}"
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
    
    # Core packages for Watcher node
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
        prometheus
        prometheus-node-exporter
        grafana
    )
    
    # Install packages (apt-get is idempotent)
    log_info "Installing core packages..."
    apt-get install -y "${PACKAGES[@]}" || {
        log_warn "Some packages may not be available, installing available ones..."
        for pkg in "${PACKAGES[@]}"; do
            apt-get install -y "$pkg" 2>/dev/null || log_warn "Package $pkg not available"
        done
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
    
    # Allow Prometheus (port 9090)
    log_info "Allowing Prometheus (port 9090)..."
    ufw allow 9090/tcp comment 'Prometheus'
    
    # Allow Grafana (port 3000)
    log_info "Allowing Grafana (port 3000)..."
    ufw allow 3000/tcp comment 'Grafana'
    
    # Allow Node Exporter (port 9100) - internal only
    log_info "Allowing Node Exporter (port 9100)..."
    ufw allow from 10.0.0.0/8 to any port 9100 comment 'Node Exporter Internal'
    ufw allow from 172.16.0.0/12 to any port 9100 comment 'Node Exporter Internal'
    ufw allow from 192.168.0.0/16 to any port 9100 comment 'Node Exporter Internal'
    
    # Allow Alertmanager (port 9093)
    log_info "Allowing Alertmanager (port 9093)..."
    ufw allow 9093/tcp comment 'Alertmanager'
    
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
# Prometheus Configuration
#-------------------------------------------------------------------------------
configure_prometheus() {
    log_section "Configuring Prometheus"
    
    PROMETHEUS_CONFIG="/etc/prometheus/prometheus.yml"
    
    if [[ -f "$PROMETHEUS_CONFIG" ]]; then
        # Backup existing config
        cp "$PROMETHEUS_CONFIG" "${PROMETHEUS_CONFIG}.bak"
    fi
    
    log_info "Creating Prometheus configuration..."
    cat > "$PROMETHEUS_CONFIG" << 'EOF'
# Watcher Node - Prometheus Configuration
global:
  scrape_interval: 15s
  evaluation_interval: 15s

alerting:
  alertmanagers:
    - static_configs:
        - targets:
          - localhost:9093

rule_files:
  - "/etc/prometheus/rules/*.yml"

scrape_configs:
  # Prometheus self-monitoring
  - job_name: 'prometheus'
    static_configs:
      - targets: ['localhost:9090']

  # Node Exporter - local system metrics
  - job_name: 'node'
    static_configs:
      - targets: ['localhost:9100']

  # Kingdom Guardian nodes
  - job_name: 'kingdom-guardians'
    static_configs:
      - targets: []
    # Add guardian nodes here as they come online

  # Kingdom Builder nodes
  - job_name: 'kingdom-builders'
    static_configs:
      - targets: []
    # Add builder nodes here as they come online

  # Kingdom Scribe nodes
  - job_name: 'kingdom-scribes'
    static_configs:
      - targets: []
    # Add scribe nodes here as they come online
EOF
    
    # Create rules directory
    mkdir -p /etc/prometheus/rules
    
    # Create basic alerting rules
    cat > /etc/prometheus/rules/kingdom-alerts.yml << 'EOF'
groups:
  - name: kingdom-alerts
    rules:
      - alert: NodeDown
        expr: up == 0
        for: 5m
        labels:
          severity: critical
        annotations:
          summary: "Node {{ $labels.instance }} is down"
          description: "{{ $labels.instance }} has been down for more than 5 minutes."

      - alert: HighCPUUsage
        expr: 100 - (avg by(instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          description: "CPU usage is above 80% for more than 10 minutes."

      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          description: "Memory usage is above 85% for more than 10 minutes."

      - alert: DiskSpaceLow
        expr: (1 - (node_filesystem_avail_bytes{fstype!="tmpfs"} / node_filesystem_size_bytes{fstype!="tmpfs"})) * 100 > 85
        for: 10m
        labels:
          severity: warning
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
          description: "Disk usage is above 85% on {{ $labels.device }}."
EOF
    
    # Enable and restart Prometheus
    systemctl enable prometheus
    systemctl restart prometheus
    
    log_success "Prometheus configured"
}

#-------------------------------------------------------------------------------
# Grafana Configuration
#-------------------------------------------------------------------------------
configure_grafana() {
    log_section "Configuring Grafana"
    
    # Enable and start Grafana
    systemctl enable grafana-server
    systemctl start grafana-server
    
    # Wait for Grafana to start
    sleep 5
    
    # Configure Prometheus datasource
    DATASOURCE_FILE="/etc/grafana/provisioning/datasources/prometheus.yml"
    mkdir -p "$(dirname "$DATASOURCE_FILE")"
    
    if [[ ! -f "$DATASOURCE_FILE" ]]; then
        log_info "Creating Grafana Prometheus datasource..."
        cat > "$DATASOURCE_FILE" << 'EOF'
apiVersion: 1

datasources:
  - name: Prometheus
    type: prometheus
    access: proxy
    url: http://localhost:9090
    isDefault: true
    editable: false
EOF
        log_success "Grafana datasource configured"
    fi
    
    # Restart Grafana to pick up datasource
    systemctl restart grafana-server
    
    log_success "Grafana configured"
}

#-------------------------------------------------------------------------------
# Alertmanager Configuration
#-------------------------------------------------------------------------------
configure_alertmanager() {
    log_section "Configuring Alertmanager"
    
    ALERTMANAGER_DIR="/etc/alertmanager"
    mkdir -p "$ALERTMANAGER_DIR"
    
    ALERTMANAGER_CONFIG="${ALERTMANAGER_DIR}/alertmanager.yml"
    
    if [[ ! -f "$ALERTMANAGER_CONFIG" ]]; then
        log_info "Creating Alertmanager configuration..."
        cat > "$ALERTMANAGER_CONFIG" << 'EOF'
# Watcher Node - Alertmanager Configuration
global:
  resolve_timeout: 5m

route:
  group_by: ['alertname', 'severity']
  group_wait: 30s
  group_interval: 5m
  repeat_interval: 4h
  receiver: 'default-receiver'
  routes:
    - match:
        severity: critical
      receiver: 'critical-receiver'

receivers:
  - name: 'default-receiver'
    # Configure webhook, email, or slack here
    
  - name: 'critical-receiver'
    # Configure critical alert destinations here

inhibit_rules:
  - source_match:
      severity: 'critical'
    target_match:
      severity: 'warning'
    equal: ['alertname', 'instance']
EOF
        log_success "Alertmanager configuration created"
    fi
    
    # Create Alertmanager systemd service if not exists
    if [[ ! -f /etc/systemd/system/alertmanager.service ]]; then
        cat > /etc/systemd/system/alertmanager.service << EOF
[Unit]
Description=Alertmanager
Wants=network-online.target
After=network-online.target

[Service]
Type=simple
ExecStart=/usr/bin/alertmanager --config.file=${ALERTMANAGER_CONFIG} --storage.path=/var/lib/alertmanager
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF
    fi
    
    # Check if alertmanager binary exists
    if command -v alertmanager &> /dev/null; then
        systemctl daemon-reload
        systemctl enable alertmanager
        systemctl start alertmanager || log_warn "Alertmanager may need manual installation"
    else
        log_warn "Alertmanager binary not found - install manually or via Docker"
    fi
    
    log_success "Alertmanager configured"
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
# Watcher Node Configuration
#-------------------------------------------------------------------------------
configure_watcher() {
    log_section "Configuring Watcher Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    # Create watcher-specific configuration
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
  alertmanager:
    port: 9093
    
targets:
  # Add Kingdom nodes to monitor
  guardians: []
  builders: []
  scribes: []
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
After=docker.service network-online.target prometheus.service grafana-server.service
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
    
    # Create placeholder docker-compose.yaml
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
# Watcher Node Docker Compose
# Monitoring and alerting services

version: '3.8'

services:
  # Watcher dashboard
  watcher-dashboard:
    image: node:20-alpine
    container_name: watcher-dashboard
    working_dir: /app
    volumes:
      - ${INSTALL_DIR}/config:/config
    ports:
      - "127.0.0.1:3001:3000"
    command: echo "Watcher dashboard pending"
    restart: unless-stopped

  # Log aggregator
  loki:
    image: grafana/loki:latest
    container_name: watcher-loki
    ports:
      - "127.0.0.1:3100:3100"
    volumes:
      - loki-data:/loki
    command: -config.file=/etc/loki/local-config.yaml
    restart: unless-stopped

volumes:
  loki-data:
EOF
        log_success "Docker compose template created"
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
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           Watcher Node Bootstrap Complete                   ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Domain:     ${BLUE}${DOMAIN}${NC}"
    echo -e "${GREEN}║${NC} Role:       ${BLUE}Watcher${NC}"
    echo -e "${GREEN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Services:"
    echo -e "${GREEN}║${NC}   - Prometheus:  $(systemctl is-active prometheus 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Grafana:     $(systemctl is-active grafana-server 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Docker:      $(systemctl is-active docker)"
    echo -e "${GREEN}║${NC}   - Fail2Ban:    $(systemctl is-active fail2ban)"
    echo -e "${GREEN}║${NC}   - UFW:         $(ufw status | head -1)"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Monitoring Endpoints:"
    echo -e "${GREEN}║${NC}   - Prometheus:  http://localhost:9090"
    echo -e "${GREEN}║${NC}   - Grafana:     http://localhost:3000"
    echo -e "${GREEN}║${NC}   - Alertmanager: http://localhost:9093"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Next Steps:"
    echo -e "${GREEN}║${NC}   1. Configure Grafana admin password"
    echo -e "${GREEN}║${NC}   2. Add Kingdom nodes to Prometheus targets"
    echo -e "${GREEN}║${NC}   3. Configure alert receivers in Alertmanager"
    echo -e "${GREEN}║${NC}   4. Import Grafana dashboards"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Helper Commands (after re-login):"
    echo -e "${GREEN}║${NC}   - pull-kingdom.sh    - Pull Kingdom updates"
    echo -e "${GREEN}║${NC}   - watcher-status.sh  - Show watcher status"
    echo -e "${GREEN}║${NC}   - status.sh          - Show node status"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
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
    configure_prometheus
    configure_grafana
    configure_alertmanager
    clone_repositories
    configure_watcher
    create_services
    print_status
    
    log_info "Bootstrap completed at $(date)"
}

# Run main function
main "$@"
