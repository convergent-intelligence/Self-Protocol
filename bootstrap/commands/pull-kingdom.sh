#!/bin/bash
#===============================================================================
# pull-kingdom.sh - Pull latest Kingdom repository updates
# Guardian Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
KINGDOM_REPO="${REPOS_DIR}/Kingdom"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

echo -e "${GREEN}╔════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Kingdom Repository Update          ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════╝${NC}"

# Check if repository exists
if [[ ! -d "$KINGDOM_REPO" ]]; then
    log_error "Kingdom repository not found at ${KINGDOM_REPO}"
    log_info "Run guardian-setup.sh to clone repositories"
    exit 1
fi

cd "$KINGDOM_REPO"

# Show current state
log_info "Current branch: $(git branch --show-current)"
log_info "Current commit: $(git rev-parse --short HEAD)"

# Fetch updates
log_info "Fetching updates..."
git fetch --all --prune

# Check for local changes
if [[ -n $(git status --porcelain) ]]; then
    log_warn "Local changes detected:"
    git status --short
    echo ""
    read -p "Stash local changes and continue? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git stash push -m "Auto-stash before pull-kingdom $(date +%Y%m%d-%H%M%S)"
        log_info "Changes stashed"
    else
        log_warn "Aborting pull"
        exit 0
    fi
fi

# Pull updates
log_info "Pulling latest changes..."
if git pull --ff-only; then
    log_success "Kingdom repository updated"
    log_info "New commit: $(git rev-parse --short HEAD)"
else
    log_warn "Fast-forward not possible, attempting rebase..."
    if git pull --rebase; then
        log_success "Kingdom repository updated (rebased)"
    else
        log_error "Pull failed - manual intervention required"
        exit 1
    fi
fi

# Show recent commits
echo ""
log_info "Recent commits:"
git log --oneline -5

echo ""
log_success "Kingdom pull complete"
