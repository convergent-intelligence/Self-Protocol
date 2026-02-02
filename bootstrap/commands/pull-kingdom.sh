#!/bin/bash
#===============================================================================
# Pull Kingdom Repository
# Guardian Node Helper Command
#
# Self-Protocol Integration:
#   This command syncs the Kingdom repository, which contains the shared
#   knowledge and protocols of the network. In Self-Protocol terms, this is
#   like refreshing our understanding of the collective consciousness.
#
# Usage: guardian-pull-kingdom [--force]
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
GUARDIAN_HOME="${GUARDIAN_HOME:-/opt/guardian}"
REPOS_DIR="${GUARDIAN_HOME}/repos"
KINGDOM_DIR="${REPOS_DIR}/Kingdom"
KINGDOM_REPO="https://github.com/convergent-intelligence/Kingdom.git"
DATA_DIR="${GUARDIAN_HOME}/data"

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
    # Self-Protocol: Log this action as an interest/memory
    echo -e "${CYAN}[SELF-PROTOCOL]${NC} $1"
}

#-------------------------------------------------------------------------------
# Self-Protocol: Record this action
#-------------------------------------------------------------------------------
record_action() {
    local status="$1"
    local details="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Log to interests (what we're paying attention to)
    if [[ -d "${DATA_DIR}/interests" ]]; then
        echo "${timestamp}: Kingdom sync - ${status} - ${details}" >> "${DATA_DIR}/interests/kingdom-sync.log"
    fi
    
    # Log to memory if significant
    if [[ "$status" == "success" ]] || [[ "$status" == "error" ]]; then
        if [[ -d "${DATA_DIR}/memory/experiences" ]]; then
            cat >> "${DATA_DIR}/memory/experiences/$(date +%Y-%m-%d)-kingdom-sync.md" << EOF

## Kingdom Sync: ${timestamp}

**Status:** ${status}
**Details:** ${details}

---
EOF
        fi
    fi
}

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force]"
            echo ""
            echo "Sync the Kingdom repository with upstream."
            echo ""
            echo "Options:"
            echo "  --force, -f    Force sync even if there are local changes"
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
log_self_protocol "Beginning Kingdom sync - refreshing collective knowledge..."

# Check if Kingdom directory exists
if [[ ! -d "${KINGDOM_DIR}" ]]; then
    log_info "Kingdom repository not found. Cloning..."
    
    mkdir -p "${REPOS_DIR}"
    
    if git clone --quiet "${KINGDOM_REPO}" "${KINGDOM_DIR}"; then
        log_success "Kingdom repository cloned successfully"
        record_action "success" "Initial clone completed"
    else
        log_error "Failed to clone Kingdom repository"
        record_action "error" "Clone failed"
        exit 1
    fi
else
    log_info "Updating Kingdom repository..."
    
    cd "${KINGDOM_DIR}"
    
    # Check for local changes
    if [[ -n $(git status --porcelain) ]]; then
        if [[ "$FORCE" == true ]]; then
            log_warning "Local changes detected. Force flag set - stashing changes..."
            git stash --quiet
        else
            log_warning "Local changes detected. Use --force to override."
            log_info "Local changes:"
            git status --short
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
            
            log_success "Kingdom updated: ${COMMITS_BEHIND} new commit(s)"
            log_info "Changes:"
            git log --oneline ${OLD_COMMIT}..${NEW_COMMIT}
            
            record_action "success" "Updated ${COMMITS_BEHIND} commits: ${OLD_COMMIT:0:7} -> ${NEW_COMMIT:0:7}"
            
            # Self-Protocol: This is a significant event - new knowledge acquired
            log_self_protocol "New knowledge acquired from Kingdom network"
        else
            log_success "Kingdom is already up to date"
            record_action "success" "Already up to date"
        fi
    else
        log_error "Failed to pull Kingdom updates"
        record_action "error" "Pull failed"
        exit 1
    fi
fi

# Display current status
log_info "Kingdom Status:"
cd "${KINGDOM_DIR}"
echo "  Branch: $(git branch --show-current)"
echo "  Commit: $(git rev-parse --short HEAD)"
echo "  Date:   $(git log -1 --format=%ci)"

log_self_protocol "Kingdom sync complete - collective knowledge refreshed"
