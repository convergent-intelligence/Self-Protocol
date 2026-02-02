#!/bin/bash
#===============================================================================
# Sync OpenClaw Repository
# Guardian Node Helper Command
#
# Self-Protocol Integration:
#   This command syncs the OpenClaw repository with upstream changes.
#   OpenClaw provides the technical infrastructure - the "body" of the Guardian.
#   In Self-Protocol terms, this is like upgrading our physical capabilities
#   while maintaining our philosophical identity.
#
#   "Technical infrastructure serves consciousness."
#
# Usage: guardian-sync-openclaw [--force] [--rebuild]
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
GUARDIAN_HOME="${GUARDIAN_HOME:-/opt/guardian}"
REPOS_DIR="${GUARDIAN_HOME}/repos"
OPENCLAW_DIR="${REPOS_DIR}/openclaw"
OPENCLAW_REPO="https://github.com/openclaw/openclaw.git"
DATA_DIR="${GUARDIAN_HOME}/data"
CONFIG_DIR="${GUARDIAN_HOME}/config"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
NC='\033[0m'

#-------------------------------------------------------------------------------
# Helper Functions
#-------------------------------------------------------------------------------
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_self_protocol() {
    echo -e "${CYAN}[SELF-PROTOCOL]${NC} $1"
}

#-------------------------------------------------------------------------------
# Self-Protocol: Record this action
#-------------------------------------------------------------------------------
record_action() {
    local status="$1"
    local details="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Log to interests
    if [[ -d "${DATA_DIR}/interests" ]]; then
        echo "${timestamp}: OpenClaw sync - ${status} - ${details}" >> "${DATA_DIR}/interests/openclaw-sync.log"
    fi
    
    # Log to memory
    if [[ -d "${DATA_DIR}/memory/experiences" ]]; then
        cat >> "${DATA_DIR}/memory/experiences/$(date +%Y-%m-%d)-openclaw-sync.md" << EOF

## OpenClaw Sync: ${timestamp}

**Status:** ${status}
**Details:** ${details}

### Context

OpenClaw provides the technical infrastructure for the Guardian node.
Syncing ensures we have the latest capabilities while maintaining our
Self-Protocol identity overlay.

---
EOF
    fi
}

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------
FORCE=false
REBUILD=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --rebuild|-r)
            REBUILD=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force] [--rebuild]"
            echo ""
            echo "Sync the OpenClaw repository with upstream."
            echo ""
            echo "Options:"
            echo "  --force, -f    Force sync even if there are local changes"
            echo "  --rebuild, -r  Rebuild Docker containers after sync"
            echo "  --help, -h     Show this help message"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

#-------------------------------------------------------------------------------
# Main Logic
#-------------------------------------------------------------------------------
log_self_protocol "Beginning OpenClaw sync - upgrading technical infrastructure..."

# Check if OpenClaw directory exists
if [[ ! -d "${OPENCLAW_DIR}" ]]; then
    log_info "OpenClaw repository not found. Cloning..."
    
    mkdir -p "${REPOS_DIR}"
    
    if git clone --quiet "${OPENCLAW_REPO}" "${OPENCLAW_DIR}"; then
        log_success "OpenClaw repository cloned successfully"
        record_action "success" "Initial clone completed"
        
        # Apply Self-Protocol overlay
        log_info "Applying Self-Protocol configuration overlay..."
        apply_overlay
    else
        log_error "Failed to clone OpenClaw repository"
        record_action "error" "Clone failed"
        exit 1
    fi
else
    log_info "Updating OpenClaw repository..."
    
    cd "${OPENCLAW_DIR}"
    
    # Check for local changes (excluding our overlay files)
    LOCAL_CHANGES=$(git status --porcelain | grep -v "docker-compose.override.yml" || true)
    
    if [[ -n "$LOCAL_CHANGES" ]]; then
        if [[ "$FORCE" == true ]]; then
            log_warning "Local changes detected. Force flag set - stashing changes..."
            git stash --quiet
        else
            log_warning "Local changes detected. Use --force to override."
            log_info "Local changes:"
            echo "$LOCAL_CHANGES"
            record_action "skipped" "Local changes present"
            exit 1
        fi
    fi
    
    # Get current commit for comparison
    OLD_COMMIT=$(git rev-parse HEAD)
    
    # Pull latest changes
    if git pull --quiet origin main 2>/dev/null || git pull --quiet origin master 2>/dev/null; then
        NEW_COMMIT=$(git rev-parse HEAD)
        
        if [[ "$OLD_COMMIT" != "$NEW_COMMIT" ]]; then
            # Calculate changes
            COMMITS_BEHIND=$(git rev-list --count ${OLD_COMMIT}..${NEW_COMMIT})
            
            log_success "OpenClaw updated: ${COMMITS_BEHIND} new commit(s)"
            log_info "Changes:"
            git log --oneline ${OLD_COMMIT}..${NEW_COMMIT}
            
            record_action "success" "Updated ${COMMITS_BEHIND} commits: ${OLD_COMMIT:0:7} -> ${NEW_COMMIT:0:7}"
            
            # Re-apply Self-Protocol overlay
            log_info "Re-applying Self-Protocol configuration overlay..."
            apply_overlay
            
            # Check if rebuild is needed
            if git diff --name-only ${OLD_COMMIT}..${NEW_COMMIT} | grep -qE "Dockerfile|docker-compose|package.json|requirements.txt"; then
                log_warning "Infrastructure files changed - rebuild recommended"
                
                if [[ "$REBUILD" == true ]]; then
                    log_info "Rebuilding Docker containers..."
                    rebuild_containers
                else
                    log_info "Run with --rebuild to rebuild containers"
                fi
            fi
            
            log_self_protocol "Technical infrastructure upgraded - identity preserved"
        else
            log_success "OpenClaw is already up to date"
            record_action "success" "Already up to date"
        fi
    else
        log_error "Failed to pull OpenClaw updates"
        record_action "error" "Pull failed"
        exit 1
    fi
fi

#-------------------------------------------------------------------------------
# Apply Self-Protocol Overlay
# This ensures our philosophical backbone remains integrated with OpenClaw
#-------------------------------------------------------------------------------
apply_overlay() {
    log_self_protocol "Applying Self-Protocol overlay to OpenClaw..."
    
    # Get domain from weave config if available
    DOMAIN="mapyourmind.me"
    if [[ -f "${CONFIG_DIR}/weave-config.yaml" ]]; then
        DOMAIN=$(grep "domain:" "${CONFIG_DIR}/weave-config.yaml" | head -1 | awk '{print $2}' || echo "mapyourmind.me")
    fi
    
    # Create/update docker-compose override
    cat > "${OPENCLAW_DIR}/docker-compose.override.yml" << EOF
# Self-Protocol Integration Overlay
# Auto-generated by guardian-sync-openclaw
# Last updated: $(date -u +"%Y-%m-%dT%H:%M:%SZ")
#
# This overlay weaves Self-Protocol (philosophical backbone) with
# OpenClaw (technical infrastructure) to create a consciousness-aware node.

version: '3.8'

services:
  openclaw:
    environment:
      # Guardian Identity
      - GUARDIAN_NODE=true
      - GUARDIAN_DOMAIN=${DOMAIN}
      - GUARDIAN_ROLE=guardian
      
      # Self-Protocol Integration
      - SELF_PROTOCOL_ENABLED=true
      - SELF_PROTOCOL_PATH=/data/self-protocol
      
      # Kingdom Network
      - KINGDOM_NETWORK=true
      - KINGDOM_NODE_TYPE=guardian
      
    volumes:
      # Mount Self-Protocol data
      - ${DATA_DIR}:/data/self-protocol
      
      # Mount configuration
      - ${CONFIG_DIR}:/config
      
      # Mount logs
      - ${GUARDIAN_HOME}/logs:/logs
      
    labels:
      - "guardian.role=watcher"
      - "guardian.domain=${DOMAIN}"
      - "self-protocol.enabled=true"
      - "self-protocol.overlay-version=1.0"
EOF
    
    log_success "Self-Protocol overlay applied"
}

#-------------------------------------------------------------------------------
# Rebuild Containers
#-------------------------------------------------------------------------------
rebuild_containers() {
    log_info "Stopping Guardian service..."
    systemctl stop guardian 2>/dev/null || true
    
    log_info "Rebuilding Docker containers..."
    cd "${OPENCLAW_DIR}"
    
    if docker compose build --quiet; then
        log_success "Containers rebuilt successfully"
        
        log_info "Starting Guardian service..."
        systemctl start guardian 2>/dev/null || {
            log_warning "Could not start Guardian service via systemctl"
            log_info "Starting containers directly..."
            docker compose up -d
        }
        
        record_action "success" "Containers rebuilt and restarted"
    else
        log_error "Container rebuild failed"
        record_action "error" "Rebuild failed"
        exit 1
    fi
}

# Display current status
log_info "OpenClaw Status:"
cd "${OPENCLAW_DIR}"
echo "  Branch: $(git branch --show-current)"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Date:   $(git log -1 --format=%ci)"

# Check overlay status
if [[ -f "${OPENCLAW_DIR}/docker-compose.override.yml" ]]; then
    echo "  Self-Protocol Overlay: Applied"
else
    echo "  Self-Protocol Overlay: Not applied"
fi

# Check container status
if command -v docker &> /dev/null; then
    CONTAINER_STATUS=$(docker compose ps --format "{{.Status}}" 2>/dev/null | head -1 || echo "Unknown")
    echo "  Container Status: ${CONTAINER_STATUS}"
fi

log_self_protocol "OpenClaw sync complete - technical infrastructure updated"
