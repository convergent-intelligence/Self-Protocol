#!/bin/bash
#===============================================================================
# update-self.sh - Update Self-Protocol repository and sync state
# Guardian Node Helper Command
#===============================================================================

set -euo pipefail

# Configuration
KINGDOM_HOME="${KINGDOM_HOME:-/opt/kingdom}"
REPOS_DIR="${KINGDOM_HOME}/repos"
SELF_REPO="${REPOS_DIR}/Self-Protocol"
CONFIG_DIR="${KINGDOM_HOME}/config"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_self() { echo -e "${PURPLE}[SELF]${NC} $1"; }

echo -e "${PURPLE}╔════════════════════════════════════════╗${NC}"
echo -e "${PURPLE}║     Self-Protocol Update               ║${NC}"
echo -e "${PURPLE}╚════════════════════════════════════════╝${NC}"

# Check if repository exists
if [[ ! -d "$SELF_REPO" ]]; then
    log_error "Self-Protocol repository not found at ${SELF_REPO}"
    log_info "Run guardian-setup.sh to clone repositories"
    exit 1
fi

cd "$SELF_REPO"

# Show current state
log_info "Current branch: $(git branch --show-current)"
log_info "Current commit: $(git rev-parse --short HEAD)"

# Fetch updates
log_info "Fetching Self-Protocol updates..."
git fetch --all --prune

# Check for local changes
if [[ -n $(git status --porcelain) ]]; then
    log_warn "Local changes detected in Self-Protocol:"
    git status --short
    echo ""
    
    # Self-Protocol changes are often intentional (memories, experiences)
    log_self "Self-Protocol may have local state changes (memories, experiences)"
    read -p "Commit local changes before pulling? [y/N] " -n 1 -r
    echo ""
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git add -A
        git commit -m "Guardian auto-commit: Local state sync $(date +%Y%m%d-%H%M%S)"
        log_success "Local changes committed"
    else
        read -p "Stash local changes instead? [y/N] " -n 1 -r
        echo ""
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "Auto-stash before update-self $(date +%Y%m%d-%H%M%S)"
            log_info "Changes stashed"
        else
            log_warn "Proceeding with uncommitted changes (may cause conflicts)"
        fi
    fi
fi

# Pull updates
log_info "Pulling latest Self-Protocol changes..."
if git pull --ff-only; then
    log_success "Self-Protocol repository updated"
elif git pull --rebase; then
    log_success "Self-Protocol repository updated (rebased)"
else
    log_error "Pull failed - attempting merge..."
    if git pull --no-rebase; then
        log_success "Self-Protocol repository merged"
    else
        log_error "Merge failed - manual intervention required"
        exit 1
    fi
fi

log_info "New commit: $(git rev-parse --short HEAD)"

# Sync Self-Protocol state with Guardian
echo ""
log_self "Syncing Self-Protocol state..."

# Check for new interests
if [[ -d "${SELF_REPO}/Interests" ]]; then
    INTEREST_COUNT=$(find "${SELF_REPO}/Interests" -name "*.md" -type f | wc -l)
    log_self "Found ${INTEREST_COUNT} interest files"
fi

# Check for new memories
if [[ -d "${SELF_REPO}/Memory" ]]; then
    EXPERIENCE_COUNT=$(find "${SELF_REPO}/Memory/experiences" -name "*.md" -type f 2>/dev/null | wc -l)
    KNOWLEDGE_COUNT=$(find "${SELF_REPO}/Memory/knowledge" -name "*.md" -type f 2>/dev/null | wc -l)
    log_self "Memory state: ${EXPERIENCE_COUNT} experiences, ${KNOWLEDGE_COUNT} knowledge entries"
fi

# Check for relationship updates
if [[ -d "${SELF_REPO}/Relationships" ]]; then
    RELATIONSHIP_COUNT=$(find "${SELF_REPO}/Relationships" -name "*.md" -type f | wc -l)
    log_self "Found ${RELATIONSHIP_COUNT} relationship files"
fi

# Show recent commits
echo ""
log_info "Recent Self-Protocol commits:"
git log --oneline -5

# Restart Self-Protocol viewer if running
if docker ps --format '{{.Names}}' | grep -q 'self-viewer'; then
    log_info "Restarting Self-Protocol viewer..."
    docker restart self-viewer 2>/dev/null || log_warn "Could not restart self-viewer"
fi

echo ""
log_success "Self-Protocol update complete"
log_self "The Self continues to evolve..."
