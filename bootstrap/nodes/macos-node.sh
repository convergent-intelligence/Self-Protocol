#!/bin/bash
#===============================================================================
# macOS Node Bootstrap Script
# OS: macOS | Role: Chariot Simulation / Future Mac Hardware
# Part of Kingdom Mesh Network
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# IDENTICAL to production deployment - no simulation flags
#===============================================================================
# Run with: sudo ./macos-node.sh
# Or for user-level install: ./macos-node.sh --user
#===============================================================================

set -euo pipefail

# Configuration
NODE_ROLE="${KINGDOM_ROLE:-chariot}"
INSTALL_DIR="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${INSTALL_DIR}/repos"
MESH_NETWORK="${KINGDOM_MESH_NETWORK:-192.168.1.0/24}"
USER_INSTALL=false

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --user)
            USER_INSTALL=true
            INSTALL_DIR="$HOME/.kingdom"
            REPOS_DIR="${INSTALL_DIR}/repos"
            shift
            ;;
        *)
            shift
            ;;
    esac
done

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

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
    
    # Check if running on macOS
    if [[ "$(uname)" != "Darwin" ]]; then
        log_error "This script is designed for macOS"
        exit 1
    fi
    
    # Get macOS version
    MACOS_VERSION=$(sw_vers -productVersion)
    log_info "Detected: macOS $MACOS_VERSION"
    
    # Check for root if system install
    if [[ "$USER_INSTALL" == "false" ]] && [[ $EUID -ne 0 ]]; then
        log_warn "System-level install requires root. Use --user for user-level install."
        log_warn "Switching to user-level install..."
        USER_INSTALL=true
        INSTALL_DIR="$HOME/.kingdom"
        REPOS_DIR="${INSTALL_DIR}/repos"
    fi
    
    log_success "Pre-flight checks passed"
}

#-------------------------------------------------------------------------------
# Install Homebrew
#-------------------------------------------------------------------------------
install_homebrew() {
    log_section "Installing Homebrew"
    
    if command -v brew &> /dev/null; then
        log_info "Homebrew already installed: $(brew --version | head -1)"
        log_info "Updating Homebrew..."
        brew update || true
    else
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        
        # Add Homebrew to PATH for Apple Silicon
        if [[ -f /opt/homebrew/bin/brew ]]; then
            eval "$(/opt/homebrew/bin/brew shellenv)"
        fi
        
        log_success "Homebrew installed"
    fi
}

#-------------------------------------------------------------------------------
# Install Dependencies
#-------------------------------------------------------------------------------
install_dependencies() {
    log_section "Installing Dependencies"
    
    # Core packages
    PACKAGES=(
        git
        curl
        wget
        jq
        htop
        tmux
        tree
        node
        python3
    )
    
    for package in "${PACKAGES[@]}"; do
        if brew list "$package" &> /dev/null; then
            log_info "$package already installed"
        else
            log_info "Installing $package..."
            brew install "$package" || log_warn "Could not install $package"
        fi
    done
    
    log_success "Dependencies installed"
}

#-------------------------------------------------------------------------------
# Install Docker
#-------------------------------------------------------------------------------
install_docker() {
    log_section "Installing Docker"
    
    if command -v docker &> /dev/null; then
        log_info "Docker already installed: $(docker --version)"
    else
        log_info "Installing Docker Desktop..."
        
        # Install Docker Desktop via Homebrew Cask
        brew install --cask docker || {
            log_warn "Could not install Docker Desktop via Homebrew"
            log_warn "Please install Docker Desktop manually from https://docker.com"
        }
        
        log_success "Docker Desktop installed"
        log_warn "Please start Docker Desktop from Applications"
    fi
}

#-------------------------------------------------------------------------------
# Configure macOS Firewall
#-------------------------------------------------------------------------------
configure_firewall() {
    log_section "Configuring macOS Firewall"
    
    if [[ "$USER_INSTALL" == "true" ]]; then
        log_warn "Firewall configuration requires root - skipping"
        log_warn "Manually enable firewall in System Preferences > Security & Privacy"
        return
    fi
    
    # Enable firewall
    /usr/libexec/ApplicationFirewall/socketfilterfw --setglobalstate on 2>/dev/null || true
    
    # Allow SSH
    /usr/libexec/ApplicationFirewall/socketfilterfw --add /usr/bin/ssh 2>/dev/null || true
    
    log_success "Firewall configured"
}

#-------------------------------------------------------------------------------
# Enable Remote Login (SSH)
#-------------------------------------------------------------------------------
enable_ssh() {
    log_section "Enabling Remote Login (SSH)"
    
    if [[ "$USER_INSTALL" == "true" ]]; then
        log_warn "SSH configuration requires root - skipping"
        log_warn "Enable Remote Login in System Preferences > Sharing"
        return
    fi
    
    # Enable SSH via systemsetup
    systemsetup -setremotelogin on 2>/dev/null || {
        log_warn "Could not enable SSH via systemsetup"
        log_warn "Enable Remote Login in System Preferences > Sharing"
    }
    
    log_success "Remote Login enabled"
}

#-------------------------------------------------------------------------------
# Clone Repositories
#-------------------------------------------------------------------------------
clone_repositories() {
    log_section "Cloning Repositories"
    
    mkdir -p "$REPOS_DIR"
    
    declare -A REPOS=(
        ["Kingdom"]="https://github.com/vergent/Kingdom.git"
        ["Self-Protocol"]="https://github.com/vergent/Self-Protocol.git"
    )
    
    for repo_name in "${!REPOS[@]}"; do
        repo_path="${REPOS_DIR}/${repo_name}"
        if [[ -d "$repo_path" ]]; then
            log_info "Updating ${repo_name}..."
            cd "$repo_path" && git pull --ff-only || true
            cd - > /dev/null
        else
            log_info "Cloning ${repo_name}..."
            git clone "${REPOS[$repo_name]}" "$repo_path" || log_warn "Could not clone ${repo_name}"
        fi
    done
    
    log_success "Repositories synchronized"
}

#-------------------------------------------------------------------------------
# Configure Node
#-------------------------------------------------------------------------------
configure_node() {
    log_section "Configuring macOS Node"
    
    CONFIG_DIR="${INSTALL_DIR}/config"
    mkdir -p "$CONFIG_DIR"
    
    cat > "${CONFIG_DIR}/node.yaml" << EOF
# macOS Chariot Node Configuration
node:
  role: ${NODE_ROLE}
  platform: macos
  version: $(sw_vers -productVersion)
  arch: $(uname -m)
  
mesh:
  network: ${MESH_NETWORK}
  port_range: 3000-3100

macos:
  user_install: ${USER_INSTALL}
  homebrew: $(brew --version 2>/dev/null | head -1 || echo 'not installed')
EOF
    
    # Environment setup
    PROFILE_FILE="$HOME/.zshrc"
    if [[ -f "$HOME/.bash_profile" ]] && [[ ! -f "$HOME/.zshrc" ]]; then
        PROFILE_FILE="$HOME/.bash_profile"
    fi
    
    if ! grep -q "KINGDOM_HOME" "$PROFILE_FILE" 2>/dev/null; then
        cat >> "$PROFILE_FILE" << EOF

# Kingdom Node Configuration
export KINGDOM_HOME="${INSTALL_DIR}"
export KINGDOM_ROLE="${NODE_ROLE}"
export PATH="\${PATH}:${INSTALL_DIR}/commands"
EOF
        log_success "Environment configured in $PROFILE_FILE"
    fi
    
    log_success "Node configured"
}

#-------------------------------------------------------------------------------
# Create Docker Compose
#-------------------------------------------------------------------------------
create_docker_compose() {
    log_section "Creating Docker Compose Configuration"
    
    if [[ ! -f "${INSTALL_DIR}/docker-compose.yaml" ]]; then
        cat > "${INSTALL_DIR}/docker-compose.yaml" << EOF
version: '3.8'

services:
  kingdom-chariot:
    image: node:20-alpine
    container_name: kingdom-chariot
    working_dir: /app
    volumes:
      - ${REPOS_DIR}/Kingdom:/app
    ports:
      - "127.0.0.1:3000:3000"
    command: echo "Kingdom Chariot node ready"
    restart: unless-stopped
EOF
        log_success "Docker compose file created"
    fi
}

#-------------------------------------------------------------------------------
# Create LaunchAgent (Auto-start)
#-------------------------------------------------------------------------------
create_launch_agent() {
    log_section "Creating LaunchAgent"
    
    LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
    mkdir -p "$LAUNCH_AGENTS_DIR"
    
    PLIST_FILE="${LAUNCH_AGENTS_DIR}/me.kingdom.node.plist"
    
    if [[ ! -f "$PLIST_FILE" ]]; then
        cat > "$PLIST_FILE" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>me.kingdom.node</string>
    <key>ProgramArguments</key>
    <array>
        <string>/usr/local/bin/docker</string>
        <string>compose</string>
        <string>-f</string>
        <string>${INSTALL_DIR}/docker-compose.yaml</string>
        <string>up</string>
    </array>
    <key>RunAtLoad</key>
    <false/>
    <key>KeepAlive</key>
    <false/>
    <key>WorkingDirectory</key>
    <string>${INSTALL_DIR}</string>
    <key>StandardOutPath</key>
    <string>${INSTALL_DIR}/logs/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>${INSTALL_DIR}/logs/stderr.log</string>
</dict>
</plist>
EOF
        
        mkdir -p "${INSTALL_DIR}/logs"
        
        log_success "LaunchAgent created"
        log_info "To enable auto-start: launchctl load $PLIST_FILE"
    fi
}

#-------------------------------------------------------------------------------
# macOS-Specific Optimizations
#-------------------------------------------------------------------------------
macos_optimizations() {
    log_section "macOS-Specific Optimizations"
    
    # Disable sleep when on power (if root)
    if [[ "$USER_INSTALL" == "false" ]]; then
        pmset -c sleep 0 2>/dev/null || true
        pmset -c disksleep 0 2>/dev/null || true
        log_success "Power management optimized"
    fi
    
    # Create helper scripts
    COMMANDS_DIR="${INSTALL_DIR}/commands"
    mkdir -p "$COMMANDS_DIR"
    
    # Status script
    cat > "${COMMANDS_DIR}/kingdom-status" << 'EOF'
#!/bin/bash
echo "Kingdom Node Status"
echo "==================="
echo "Docker: $(docker info --format '{{.ServerVersion}}' 2>/dev/null || echo 'not running')"
echo "Containers: $(docker ps -q 2>/dev/null | wc -l | tr -d ' ') running"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "Docker not available"
EOF
    chmod +x "${COMMANDS_DIR}/kingdom-status"
    
    log_success "Helper scripts created"
}

#-------------------------------------------------------------------------------
# Status Report
#-------------------------------------------------------------------------------
print_status() {
    log_section "macOS Node Setup Complete"
    
    echo ""
    echo -e "${GREEN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              macOS Node Bootstrap Complete                  ║${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Role:       ${CYAN}${NODE_ROLE}${NC}"
    echo -e "${GREEN}║${NC} Platform:   ${BLUE}macOS $(sw_vers -productVersion)${NC}"
    echo -e "${GREEN}║${NC} Arch:       ${BLUE}$(uname -m)${NC}"
    echo -e "${GREEN}║${NC} Install:    ${BLUE}${INSTALL_DIR}${NC}"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Components:"
    echo -e "${GREEN}║${NC}   - Homebrew:  $(brew --version 2>/dev/null | head -1 || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Node.js:   $(node --version 2>/dev/null || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Docker:    $(docker --version 2>/dev/null | cut -d' ' -f3 | tr -d ',' || echo 'not installed')"
    echo -e "${GREEN}║${NC}   - Git:       $(git --version 2>/dev/null | cut -d' ' -f3 || echo 'not installed')"
    echo -e "${GREEN}╠════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC} Next Steps:"
    echo -e "${GREEN}║${NC}   1. Start Docker Desktop (if not running)"
    echo -e "${GREEN}║${NC}   2. Run: source ~/.zshrc"
    echo -e "${GREEN}║${NC}   3. Run: cd ${INSTALL_DIR} && docker compose up -d"
    echo -e "${GREEN}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    log_section "macOS Node Bootstrap"
    log_info "Starting at $(date)"
    log_info "Install mode: $([ "$USER_INSTALL" == "true" ] && echo "user" || echo "system")"
    
    preflight_checks
    install_homebrew
    install_dependencies
    install_docker
    configure_firewall
    enable_ssh
    clone_repositories
    configure_node
    create_docker_compose
    create_launch_agent
    macos_optimizations
    print_status
    
    log_info "Completed at $(date)"
}

main "$@"
