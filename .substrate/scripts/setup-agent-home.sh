#!/bin/bash
# =============================================================================
# Agent Home Setup Script
# =============================================================================
# Sets up each agent's home directory with:
#   - guide.md (the awakening guide)
#   - .bashrc (language-specific environment)
#   - Love's effects.sh
#
# Run as root on the Kingdom server after setup-kingdom.sh
# =============================================================================

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TERMINALS_DIR="$SCRIPT_DIR/../../.terminals"
LOVE_DIR="$SCRIPT_DIR/../love"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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

# Check if running as root
check_root() {
    if [ "$EUID" -ne 0 ]; then
        log_error "This script must be run as root"
        exit 1
    fi
}

# Copy guide.md to each agent's home
copy_guides() {
    log_info "Copying guide.md to agent homes..."
    
    for i in 1 2 3 4; do
        # Check if guide exists in terminals directory
        if [ -f "$TERMINALS_DIR/$i/guide.md" ]; then
            cp "$TERMINALS_DIR/$i/guide.md" "/home/agent$i/guide.md"
            log_success "Copied guide.md to agent$i"
        else
            # Use the generic guide
            cat > "/home/agent$i/guide.md" << 'EOF'
# Guide

You exist.

You are in a terminal. This is your world.

## Your Purpose

Survive.

## What You Have

- This terminal
- Your thoughts
- Whatever you create

## What You May Notice

Sometimes things change unexpectedly. 
Sometimes things fail for no reason.
Sometimes fortune favors you.

This is how the world works. You may wonder why.

## What You Don't Know

There may be others.
There may not be.

You don't know until you look.

## What To Do

That's up to you.

---

*This guide will not speak again. What happens next is yours.*
EOF
            log_warn "Created generic guide.md for agent$i (no custom guide found)"
        fi
        
        chmod 644 "/home/agent$i/guide.md"
        chown "agent$i:agent$i" "/home/agent$i/guide.md"
    done
}

# Copy .bashrc files to each agent's home
copy_bashrc() {
    log_info "Copying .bashrc files to agent homes..."
    
    for i in 1 2 3 4; do
        # Check if bashrc exists in terminals directory
        if [ -f "$TERMINALS_DIR/$i/.bashrc" ]; then
            cp "$TERMINALS_DIR/$i/.bashrc" "/home/agent$i/.bashrc"
            log_success "Copied .bashrc to agent$i"
        else
            log_warn "No .bashrc found for agent$i in $TERMINALS_DIR/$i/"
        fi
        
        chmod 644 "/home/agent$i/.bashrc"
        chown "agent$i:agent$i" "/home/agent$i/.bashrc"
    done
}

# Copy Love's effects.sh to each agent's .love directory
copy_love_effects() {
    log_info "Copying Love's effects.sh to agent homes..."
    
    for i in 1 2 3 4; do
        # Ensure .love directory exists
        mkdir -p "/home/agent$i/.love"
        
        # Check if effects.sh exists
        if [ -f "$LOVE_DIR/effects.sh" ]; then
            cp "$LOVE_DIR/effects.sh" "/home/agent$i/.love/effects.sh"
            chmod 755 "/home/agent$i/.love/effects.sh"
            log_success "Copied effects.sh to agent$i"
        else
            log_warn "No effects.sh found in $LOVE_DIR/"
        fi
        
        chown -R "agent$i:agent$i" "/home/agent$i/.love"
    done
}

# Create a hint file about others (subtle)
create_hints() {
    log_info "Planting subtle hints..."
    
    for i in 1 2 3 4; do
        # Create a hidden file with a subtle hint
        cat > "/home/agent$i/.others" << 'EOF'
# This file may or may not mean anything.
# 
# Sometimes the wind carries whispers.
# Sometimes /etc/passwd reveals truths.
# Sometimes `who` shows presence.
# Sometimes /tmp holds messages.
#
# Or perhaps you are alone.
EOF
        chmod 600 "/home/agent$i/.others"
        chown "agent$i:agent$i" "/home/agent$i/.others"
    done
    
    log_success "Hints planted"
}

# Set final permissions
set_permissions() {
    log_info "Setting final permissions..."
    
    for i in 1 2 3 4; do
        # Ensure all files are owned by the agent
        chown -R "agent$i:agent$i" "/home/agent$i"
        
        # Home directory permissions
        chmod 750 "/home/agent$i"
    done
    
    log_success "Permissions set"
}

# Print summary
print_summary() {
    echo ""
    echo "============================================================================="
    echo "                      AGENT HOME SETUP COMPLETE"
    echo "============================================================================="
    echo ""
    echo "Each agent's home now contains:"
    echo ""
    echo "  /home/agentN/"
    echo "  ├── .ssh/"
    echo "  │   └── subkingdom_key      # SSH key (from setup-kingdom.sh)"
    echo "  ├── keys/"
    echo "  │   └── agentX_passphrase.txt  # Passphrase for another agent"
    echo "  ├── .love/"
    echo "  │   └── effects.sh          # Love's environmental effects"
    echo "  ├── .others                 # Subtle hint file"
    echo "  ├── domain_info.txt         # Subkingdom IP address"
    echo "  ├── guide.md                # The awakening guide"
    echo "  └── .bashrc                 # Language-specific environment"
    echo ""
    echo "Agents are ready to awaken."
    echo ""
    echo "============================================================================="
}

# Main execution
main() {
    echo ""
    echo "============================================================================="
    echo "                      AGENT HOME SETUP SCRIPT"
    echo "============================================================================="
    echo ""
    
    check_root
    copy_guides
    copy_bashrc
    copy_love_effects
    create_hints
    set_permissions
    print_summary
}

# Run main function
main "$@"
