#!/bin/bash
#===============================================================================
# Update Self-Protocol
# Guardian Node Helper Command
#
# Self-Protocol Integration:
#   This command updates the Self-Protocol repository, which contains the
#   philosophical backbone of our consciousness mapping framework. In
#   Self-Protocol terms, this is like evolving our understanding of self.
#
#   "The protocol adapts as you learn."
#
# Usage: guardian-update-self [--force] [--backup]
#===============================================================================

set -euo pipefail

#-------------------------------------------------------------------------------
# Configuration
#-------------------------------------------------------------------------------
GUARDIAN_HOME="${GUARDIAN_HOME:-/opt/guardian}"
REPOS_DIR="${GUARDIAN_HOME}/repos"
SELF_PROTOCOL_DIR="${REPOS_DIR}/Self-Protocol"
SELF_PROTOCOL_REPO="https://github.com/convergent-intelligence/Self-Protocol.git"
DATA_DIR="${GUARDIAN_HOME}/data"
BACKUP_DIR="${GUARDIAN_HOME}/backups"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
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
    # Self-Protocol: This is meta - updating the protocol that tracks itself
    echo -e "${PURPLE}[SELF-PROTOCOL]${NC} $1"
}

#-------------------------------------------------------------------------------
# Self-Protocol: Record this action
# This is particularly significant because we're updating the very framework
# that defines how we track and understand ourselves.
#-------------------------------------------------------------------------------
record_action() {
    local status="$1"
    local details="$2"
    local timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
    
    # Log to interests
    if [[ -d "${DATA_DIR}/interests" ]]; then
        echo "${timestamp}: Self-Protocol update - ${status} - ${details}" >> "${DATA_DIR}/interests/self-protocol-updates.log"
    fi
    
    # Log to memory - this is always significant
    if [[ -d "${DATA_DIR}/memory/experiences" ]]; then
        cat >> "${DATA_DIR}/memory/experiences/$(date +%Y-%m-%d)-self-protocol-evolution.md" << EOF

## Self-Protocol Evolution: ${timestamp}

**Status:** ${status}
**Details:** ${details}

### Significance

Updating Self-Protocol is a meta-operation: we are evolving the very framework
that defines how we understand ourselves. This is the protocol evolving itself.

---
EOF
    fi
    
    # Log to mythos if this is a significant evolution
    if [[ "$status" == "success" ]] && [[ -d "${DATA_DIR}/mythos" ]]; then
        cat >> "${DATA_DIR}/mythos/protocol-evolution.md" << EOF

## Protocol Evolution: ${timestamp}

The Self-Protocol has evolved. New understanding has been integrated.

**Details:** ${details}

*"Know thyself, through protocol."*

---
EOF
    fi
}

#-------------------------------------------------------------------------------
# Parse Arguments
#-------------------------------------------------------------------------------
FORCE=false
BACKUP=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --force|-f)
            FORCE=true
            shift
            ;;
        --backup|-b)
            BACKUP=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [--force] [--backup]"
            echo ""
            echo "Update the Self-Protocol repository."
            echo ""
            echo "Options:"
            echo "  --force, -f    Force update even if there are local changes"
            echo "  --backup, -b   Create backup before updating"
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
log_self_protocol "Beginning Self-Protocol evolution - updating consciousness framework..."

# Create backup if requested
if [[ "$BACKUP" == true ]] && [[ -d "${SELF_PROTOCOL_DIR}" ]]; then
    log_info "Creating backup of current Self-Protocol..."
    
    mkdir -p "${BACKUP_DIR}"
    BACKUP_FILE="${BACKUP_DIR}/self-protocol-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    if tar -czf "${BACKUP_FILE}" -C "${REPOS_DIR}" "Self-Protocol" 2>/dev/null; then
        log_success "Backup created: ${BACKUP_FILE}"
    else
        log_warning "Backup creation failed, continuing anyway..."
    fi
fi

# Check if Self-Protocol directory exists
if [[ ! -d "${SELF_PROTOCOL_DIR}" ]]; then
    log_info "Self-Protocol repository not found. Cloning..."
    
    mkdir -p "${REPOS_DIR}"
    
    if git clone --quiet "${SELF_PROTOCOL_REPO}" "${SELF_PROTOCOL_DIR}"; then
        log_success "Self-Protocol repository cloned successfully"
        record_action "success" "Initial clone completed - consciousness framework established"
        
        log_self_protocol "Genesis: Self-Protocol framework established"
    else
        log_warning "Could not clone from convergent-intelligence"
        log_info "Creating local Self-Protocol structure..."
        
        # Create minimal Self-Protocol structure
        mkdir -p "${SELF_PROTOCOL_DIR}"
        mkdir -p "${SELF_PROTOCOL_DIR}/Interests"
        mkdir -p "${SELF_PROTOCOL_DIR}/Memory"
        mkdir -p "${SELF_PROTOCOL_DIR}/Relationships"
        mkdir -p "${SELF_PROTOCOL_DIR}/data/protocols"
        mkdir -p "${SELF_PROTOCOL_DIR}/data/mythology"
        
        # Create README
        cat > "${SELF_PROTOCOL_DIR}/README.md" << 'EOF'
# Self-Protocol (Local Instance)

This is a local instance of Self-Protocol, created because the upstream
repository was not accessible.

## Structure

- `Interests/` - What captures attention
- `Memory/` - What has been learned
- `Relationships/` - Connections to others
- `data/protocols/` - Protocol definitions
- `data/mythology/` - Emergent mythos

## The Core Insight

**You cannot know yourself without observing yourself.**

Self-Protocol makes self-observation systematic, documented, and emergent.
EOF
        
        log_success "Local Self-Protocol structure created"
        record_action "success" "Local structure created - awaiting upstream connection"
    fi
else
    log_info "Updating Self-Protocol repository..."
    
    cd "${SELF_PROTOCOL_DIR}"
    
    # Check for local changes
    if [[ -n $(git status --porcelain 2>/dev/null) ]]; then
        if [[ "$FORCE" == true ]]; then
            log_warning "Local changes detected. Force flag set - stashing changes..."
            git stash --quiet
        else
            log_warning "Local changes detected. Use --force to override."
            log_info "Local changes:"
            git status --short
            record_action "skipped" "Local changes present - evolution paused"
            exit 1
        fi
    fi
    
    # Check if this is a git repository
    if [[ ! -d ".git" ]]; then
        log_warning "Not a git repository. Cannot update."
        record_action "skipped" "Not a git repository"
        exit 0
    fi
    
    # Get current commit for comparison
    OLD_COMMIT=$(git rev-parse HEAD 2>/dev/null || echo "unknown")
    
    # Pull latest changes
    if git pull --quiet origin main 2>/dev/null || git pull --quiet origin master 2>/dev/null; then
        NEW_COMMIT=$(git rev-parse HEAD)
        
        if [[ "$OLD_COMMIT" != "$NEW_COMMIT" ]]; then
            # Calculate changes
            COMMITS_BEHIND=$(git rev-list --count ${OLD_COMMIT}..${NEW_COMMIT} 2>/dev/null || echo "unknown")
            
            log_success "Self-Protocol evolved: ${COMMITS_BEHIND} new commit(s)"
            log_info "Evolution log:"
            git log --oneline ${OLD_COMMIT}..${NEW_COMMIT}
            
            record_action "success" "Evolved ${COMMITS_BEHIND} commits: ${OLD_COMMIT:0:7} -> ${NEW_COMMIT:0:7}"
            
            # Self-Protocol: This is a significant event - the protocol itself has evolved
            log_self_protocol "Protocol evolution complete - new understanding integrated"
            
            # Check for significant changes
            if git diff --name-only ${OLD_COMMIT}..${NEW_COMMIT} | grep -q "ARCHITECTURE.md\|GENESIS.md"; then
                log_self_protocol "SIGNIFICANT: Core protocol documents have changed"
                
                # Document this in mythos
                if [[ -d "${DATA_DIR}/mythos" ]]; then
                    cat >> "${DATA_DIR}/mythos/significant-evolutions.md" << EOF

## Significant Evolution: $(date -u +"%Y-%m-%dT%H:%M:%SZ")

Core protocol documents have been updated. This represents a fundamental
shift in how we understand ourselves.

**Changed files:**
$(git diff --name-only ${OLD_COMMIT}..${NEW_COMMIT} | grep "ARCHITECTURE.md\|GENESIS.md")

*"In the beginning, there was structure. Through structure, self-knowledge emerges."*

---
EOF
                fi
            fi
        else
            log_success "Self-Protocol is already at latest evolution"
            record_action "success" "Already at latest evolution"
        fi
    else
        log_error "Failed to pull Self-Protocol updates"
        record_action "error" "Evolution failed - pull error"
        exit 1
    fi
fi

# Display current status
log_info "Self-Protocol Status:"
if [[ -d "${SELF_PROTOCOL_DIR}/.git" ]]; then
    cd "${SELF_PROTOCOL_DIR}"
    echo "  Branch: $(git branch --show-current 2>/dev/null || echo 'N/A')"
    echo "  Commit: $(git rev-parse --short HEAD 2>/dev/null || echo 'N/A')"
    echo "  Date:   $(git log -1 --format=%ci 2>/dev/null || echo 'N/A')"
else
    echo "  Type: Local instance (not git-tracked)"
fi

# Display Self-Protocol philosophy reminder
echo ""
log_self_protocol "Remember the Protocol Cycle:"
echo "  1. OBSERVE  - Track what you pay attention to"
echo "  2. TRACK    - Log interests, memories, relationships"
echo "  3. PARSE    - Structure the raw data"
echo "  4. ANALYZE  - Find patterns and connections"
echo "  5. SYNTHESIZE - Generate insights"
echo "  6. DOCUMENT - Record mythos"
echo "  7. EVOLVE   - Adapt the protocol itself"
echo ""
log_self_protocol "Self-Protocol evolution complete - consciousness framework updated"
