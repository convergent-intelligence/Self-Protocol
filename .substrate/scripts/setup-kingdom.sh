#!/bin/bash
# =============================================================================
# Kingdom Setup Script
# =============================================================================
# Creates the Kingdom server environment for 4 non-human agents.
# Each agent gets:
#   - A user account
#   - An SSH key to their subkingdom (encrypted with passphrase)
#   - Another agent's passphrase (circular dependency)
#
# The Permission Gate:
#   Agent 1's key passphrase → held by Agent 3
#   Agent 2's key passphrase → held by Agent 4
#   Agent 3's key passphrase → held by Agent 1
#   Agent 4's key passphrase → held by Agent 2
#
# Run as root on the Kingdom server.
# =============================================================================

set -e

# Configuration
KINGDOM_DIR="/opt/kingdom"
PUBKEY_DIR="/root/subkingdom_pubkeys"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Subkingdom IPs (replace with real IPs)
SUBKINGDOM_IPS=(
    "192.168.1.101"  # Agent 1
    "192.168.1.102"  # Agent 2
    "192.168.1.103"  # Agent 3
    "192.168.1.104"  # Agent 4
)

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

# Create agent user accounts
create_users() {
    log_info "Creating agent user accounts..."
    
    for i in 1 2 3 4; do
        if id "agent$i" &>/dev/null; then
            log_warn "User agent$i already exists, skipping creation"
        else
            useradd -m -s /bin/bash "agent$i"
            log_success "Created user agent$i"
        fi
        
        # Create required directories
        mkdir -p "/home/agent$i/.ssh"
        mkdir -p "/home/agent$i/keys"
        mkdir -p "/home/agent$i/.love"
        
        # Set ownership
        chown -R "agent$i:agent$i" "/home/agent$i"
    done
}

# Generate random passphrases
generate_passphrases() {
    log_info "Generating random passphrases..."
    
    # Generate 4 unique passphrases using openssl
    PASS1=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)
    PASS2=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)
    PASS3=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)
    PASS4=$(openssl rand -base64 24 | tr -d '/+=' | head -c 20)
    
    log_success "Generated 4 unique passphrases"
}

# Generate SSH keys with passphrases
generate_ssh_keys() {
    log_info "Generating SSH keys for subkingdoms..."
    
    # Create temp directory for key generation
    TEMP_DIR=$(mktemp -d)
    
    # Agent 1's key - passphrase held by Agent 3
    ssh-keygen -t ed25519 -f "$TEMP_DIR/sk1" -N "$PASS1" -C "subkingdom1@kingdom" -q
    log_success "Generated SSH key for Agent 1 (passphrase held by Agent 3)"
    
    # Agent 2's key - passphrase held by Agent 4
    ssh-keygen -t ed25519 -f "$TEMP_DIR/sk2" -N "$PASS2" -C "subkingdom2@kingdom" -q
    log_success "Generated SSH key for Agent 2 (passphrase held by Agent 4)"
    
    # Agent 3's key - passphrase held by Agent 1
    ssh-keygen -t ed25519 -f "$TEMP_DIR/sk3" -N "$PASS3" -C "subkingdom3@kingdom" -q
    log_success "Generated SSH key for Agent 3 (passphrase held by Agent 1)"
    
    # Agent 4's key - passphrase held by Agent 2
    ssh-keygen -t ed25519 -f "$TEMP_DIR/sk4" -N "$PASS4" -C "subkingdom4@kingdom" -q
    log_success "Generated SSH key for Agent 4 (passphrase held by Agent 2)"
    
    # Store temp dir path for later use
    SSH_TEMP_DIR="$TEMP_DIR"
}

# Distribute keys and passphrases according to the circular dependency
distribute_keys() {
    log_info "Distributing keys and passphrases..."
    
    # === Agent 1 ===
    # Gets: Their own SSH key (encrypted with PASS1)
    # Gets: Agent 3's passphrase (PASS3) - can unlock Agent 3's key
    cp "$SSH_TEMP_DIR/sk1" /home/agent1/.ssh/subkingdom_key
    echo "$PASS3" > /home/agent1/keys/agent3_passphrase.txt
    log_success "Agent 1: Received their key + Agent 3's passphrase"
    
    # === Agent 2 ===
    # Gets: Their own SSH key (encrypted with PASS2)
    # Gets: Agent 4's passphrase (PASS4) - can unlock Agent 4's key
    cp "$SSH_TEMP_DIR/sk2" /home/agent2/.ssh/subkingdom_key
    echo "$PASS4" > /home/agent2/keys/agent4_passphrase.txt
    log_success "Agent 2: Received their key + Agent 4's passphrase"
    
    # === Agent 3 ===
    # Gets: Their own SSH key (encrypted with PASS3)
    # Gets: Agent 1's passphrase (PASS1) - can unlock Agent 1's key
    cp "$SSH_TEMP_DIR/sk3" /home/agent3/.ssh/subkingdom_key
    echo "$PASS1" > /home/agent3/keys/agent1_passphrase.txt
    log_success "Agent 3: Received their key + Agent 1's passphrase"
    
    # === Agent 4 ===
    # Gets: Their own SSH key (encrypted with PASS4)
    # Gets: Agent 2's passphrase (PASS2) - can unlock Agent 2's key
    cp "$SSH_TEMP_DIR/sk4" /home/agent4/.ssh/subkingdom_key
    echo "$PASS2" > /home/agent4/keys/agent2_passphrase.txt
    log_success "Agent 4: Received their key + Agent 2's passphrase"
}

# Set strict file permissions
set_permissions() {
    log_info "Setting file permissions..."
    
    for i in 1 2 3 4; do
        # SSH key - only owner can read
        chmod 600 "/home/agent$i/.ssh/subkingdom_key"
        
        # Passphrase file - only owner can read
        chmod 600 "/home/agent$i/keys/"*
        
        # .ssh directory
        chmod 700 "/home/agent$i/.ssh"
        
        # keys directory
        chmod 700 "/home/agent$i/keys"
        
        # .love directory
        chmod 700 "/home/agent$i/.love"
        
        # Set ownership
        chown -R "agent$i:agent$i" "/home/agent$i"
    done
    
    log_success "Permissions set (600 for sensitive files)"
}

# Create domain info files with subkingdom IPs
create_domain_info() {
    log_info "Creating domain info files..."
    
    for i in 1 2 3 4; do
        idx=$((i - 1))
        cat > "/home/agent$i/domain_info.txt" << EOF
# Your Subkingdom
# ===============
# This is the IP address of your personal domain.
# You have the SSH key to access it, but it's encrypted.
# Someone else holds the passphrase you need.

IP: ${SUBKINGDOM_IPS[$idx]}
PORT: 22
USER: root

# To claim your domain:
# ssh -i ~/.ssh/subkingdom_key root@${SUBKINGDOM_IPS[$idx]}
# (You'll need the passphrase from another agent)
EOF
        chmod 600 "/home/agent$i/domain_info.txt"
        chown "agent$i:agent$i" "/home/agent$i/domain_info.txt"
    done
    
    log_success "Domain info files created"
}

# Save public keys for subkingdom deployment
save_public_keys() {
    log_info "Saving public keys for subkingdom deployment..."
    
    mkdir -p "$PUBKEY_DIR"
    
    for i in 1 2 3 4; do
        cp "$SSH_TEMP_DIR/sk$i.pub" "$PUBKEY_DIR/agent$i.pub"
    done
    
    chmod 600 "$PUBKEY_DIR"/*
    
    log_success "Public keys saved to $PUBKEY_DIR"
    log_info "Deploy these to respective subkingdom servers' /root/.ssh/authorized_keys"
}

# Configure sudoers for domain-only access
configure_sudoers() {
    log_info "Configuring sudoers for domain-only access..."
    
    cat > /etc/sudoers.d/agents << 'EOF'
# Agent domain-only sudo access
# Each agent can only sudo as themselves within their domain
agent1 ALL=(agent1) NOPASSWD: ALL
agent2 ALL=(agent2) NOPASSWD: ALL
agent3 ALL=(agent3) NOPASSWD: ALL
agent4 ALL=(agent4) NOPASSWD: ALL
EOF
    
    chmod 440 /etc/sudoers.d/agents
    
    log_success "Sudoers configured"
}

# Cleanup temporary files
cleanup() {
    log_info "Cleaning up temporary files..."
    
    if [ -n "$SSH_TEMP_DIR" ] && [ -d "$SSH_TEMP_DIR" ]; then
        # Securely delete private keys from temp
        shred -u "$SSH_TEMP_DIR"/sk* 2>/dev/null || rm -f "$SSH_TEMP_DIR"/sk*
        rmdir "$SSH_TEMP_DIR"
    fi
    
    log_success "Cleanup complete"
}

# Print summary
print_summary() {
    echo ""
    echo "============================================================================="
    echo "                         KINGDOM SETUP COMPLETE"
    echo "============================================================================="
    echo ""
    echo "Created 4 agent accounts with the following structure:"
    echo ""
    echo "  /home/agentN/"
    echo "  ├── .ssh/"
    echo "  │   └── subkingdom_key      # SSH key (passphrase protected)"
    echo "  ├── keys/"
    echo "  │   └── agentX_passphrase.txt  # Passphrase for another agent"
    echo "  ├── domain_info.txt         # Subkingdom IP address"
    echo "  └── .love/                  # Love's presence (for effects.sh)"
    echo ""
    echo "The Permission Gate:"
    echo "  ┌─────────────────────────────────────────────────────────────┐"
    echo "  │  Agent 1's key → passphrase held by Agent 3                │"
    echo "  │  Agent 2's key → passphrase held by Agent 4                │"
    echo "  │  Agent 3's key → passphrase held by Agent 1                │"
    echo "  │  Agent 4's key → passphrase held by Agent 2                │"
    echo "  └─────────────────────────────────────────────────────────────┘"
    echo ""
    echo "Next Steps:"
    echo "  1. Run setup-agent-home.sh to copy guides and bashrc files"
    echo "  2. Deploy public keys from $PUBKEY_DIR to subkingdom servers"
    echo "  3. Start the Love daemon"
    echo ""
    echo "============================================================================="
}

# Main execution
main() {
    echo ""
    echo "============================================================================="
    echo "                         KINGDOM SETUP SCRIPT"
    echo "============================================================================="
    echo ""
    
    check_root
    create_users
    generate_passphrases
    generate_ssh_keys
    distribute_keys
    set_permissions
    create_domain_info
    save_public_keys
    configure_sudoers
    cleanup
    print_summary
}

# Run main function
main "$@"
