#!/bin/bash
#===============================================================================
# sync-openclaw.sh - Sync OpenClaw repository and rebuild if needed
# Guardian Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
OPENCLAW_REPO="${REPOS_DIR}/openclaw"
CONFIG_DIR="${KINGDOM_HOME}/config"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
CYAN='\033[0;36m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_claw() { echo -e "${CYAN}[CLAW]${NC} $1"; }

echo -e "${CYAN}╔════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║     OpenClaw Sync                      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════╝${NC}"

# Check if repository exists
if [[ ! -d "$OPENCLAW_REPO" ]]; then
    log_error "OpenClaw repository not found at ${OPENCLAW_REPO}"
    log_info "Run guardian-setup.sh to clone repositories"
    exit 1
fi

cd "$OPENCLAW_REPO"

# Store current commit for comparison
PREV_COMMIT=$(git rev-parse HEAD)

# Show current state
log_info "Current branch: $(git branch --show-current)"
log_info "Current commit: $(git rev-parse --short HEAD)"

# Fetch updates
log_info "Fetching OpenClaw updates..."
git fetch --all --prune

# Check for local changes
if [[ -n $(git status --porcelain) ]]; then
    log_warn "Local changes detected:"
    git status --short
    echo ""
    read -p "Stash local changes and continue? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "Auto-stash before sync-openclaw $(date +%Y%m%d-%H%M%S)"
        log_info "Changes stashed"
    else
        log_warn "Aborting sync"
        exit 0
    fi
fi

# Pull updates
log_info "Pulling latest OpenClaw changes..."
if git pull --ff-only; then
    log_success "OpenClaw repository updated"
elif git pull --rebase; then
    log_success "OpenClaw repository updated (rebased)"
else
    log_error "Pull failed - manual intervention required"
    exit 1
fi

NEW_COMMIT=$(git rev-parse HEAD)
log_info "New commit: $(git rev-parse --short HEAD)"

# Check if rebuild is needed
REBUILD_NEEDED=false
if [[ "$PREV_COMMIT" != "$NEW_COMMIT" ]]; then
    log_claw "Changes detected, checking if rebuild is needed..."
    
    # Check for changes in key files
    CHANGED_FILES=$(git diff --name-only "$PREV_COMMIT" "$NEW_COMMIT")
    
    if echo "$CHANGED_FILES" | grep -qE '(package\.json|Dockerfile|docker-compose|\.lock)'; then
        log_claw "Dependency or Docker changes detected"
        REBUILD_NEEDED=true
    fi
    
    if echo "$CHANGED_FILES" | grep -qE '\.(ts|js|tsx|jsx)$'; then
        log_claw "Source code changes detected"
        REBUILD_NEEDED=true
    fi
fi

# Rebuild if needed
if [[ "$REBUILD_NEEDED" == "true" ]]; then
    echo ""
    log_claw "Rebuild recommended due to code changes"
    read -p "Rebuild OpenClaw containers? [Y/n] " -n 1 -r
    echo ""
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        log_info "Rebuilding OpenClaw..."
        
        # Check for docker-compose file
        if [[ -f "docker-compose.yaml" ]] || [[ -f "docker-compose.yml" ]]; then
            docker compose build --no-cache
            log_success "OpenClaw containers rebuilt"
            
            # Restart if running
            if docker compose ps --services --filter "status=running" | grep -q .; then
                log_info "Restarting OpenClaw services..."
                docker compose down
                docker compose up -d
                log_success "OpenClaw services restarted"
            fi
        elif [[ -f "Dockerfile" ]]; then
            docker build -t openclaw:latest .
            log_success "OpenClaw image rebuilt"
        else
            log_warn "No Docker configuration found, skipping rebuild"
            
            # Try npm install if package.json exists
            if [[ -f "package.json" ]]; then
                log_info "Running npm install..."
                npm install
                log_success "Dependencies installed"
            fi
        fi
    fi
else
    log_claw "No rebuild needed"
fi

# Sync configuration
echo ""
log_claw "Syncing OpenClaw configuration..."

# Copy weave config if it exists
if [[ -f "${CONFIG_DIR}/weave-config.yaml" ]]; then
    # Check if OpenClaw has a config directory
    if [[ -d "${OPENCLAW_REPO}/config" ]]; then
        cp "${CONFIG_DIR}/weave-config.yaml" "${OPENCLAW_REPO}/config/"
        log_success "Weave configuration synced to OpenClaw"
    fi
fi

# Show recent commits
echo ""
log_info "Recent OpenClaw commits:"
git log --oneline -5

# Show changed files if any
if [[ "$PREV_COMMIT" != "$NEW_COMMIT" ]]; then
    echo ""
    log_info "Files changed since last sync:"
    git diff --stat "$PREV_COMMIT" "$NEW_COMMIT" | tail -10
fi

# Restart guardian-api if running
if docker ps --format '{{.Names}}' | grep -q 'guardian-api'; then
    log_info "Restarting guardian-api container..."
    docker restart guardian-api 2>/dev/null || log_warn "Could not restart guardian-api"
fi

echo ""
log_success "OpenClaw sync complete"
log_claw "Attention tracking systems aligned"
