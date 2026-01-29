#!/bin/bash
#
# setup-local-kingdom.sh - Set up the Kingdom on THIS machine
# The Kingdom is the laptop. We are its admins.
# server-1 through server-4 are the subkingdoms.
#
# Run as root: sudo ./setup-local-kingdom.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Check if running as root
if [[ $EUID -ne 0 ]]; then
    echo -e "${RED}This script must be run as root (sudo)${NC}"
    exit 1
fi

# Banner
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     ████████╗██╗  ██╗███████╗    ██╗  ██╗██╗███╗   ██╗ ██████╗║"
echo "║     ╚══██╔══╝██║  ██║██╔════╝    ██║ ██╔╝██║████╗  ██║██╔════╝║"
echo "║        ██║   ███████║█████╗      █████╔╝ ██║██╔██╗ ██║██║  ███║"
echo "║        ██║   ██╔══██║██╔══╝      ██╔═██╗ ██║██║╚██╗██║██║   ██║"
echo "║        ██║   ██║  ██║███████╗    ██║  ██╗██║██║ ╚████║╚██████╔╝"
echo "║        ╚═╝   ╚═╝  ╚═╝╚══════╝    ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝║"
echo "║                                                               ║"
echo "║              This laptop IS the Kingdom.                      ║"
echo "║              We are its admins.                               ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configuration
SUBKINGDOMS=("server-1" "server-2" "server-3" "server-4")
KINGDOM_DIR="/opt/kingdom"
TREASURY_DIR="$KINGDOM_DIR/treasury"
LOVE_DIR="$KINGDOM_DIR/love"

# Get the admin user (the one who ran sudo)
ADMIN_USER="${SUDO_USER:-$(whoami)}"
ADMIN_HOME=$(getent passwd "$ADMIN_USER" | cut -d: -f6)

echo -e "${CYAN}Kingdom Admin: $ADMIN_USER${NC}"
echo -e "${CYAN}Admin Home: $ADMIN_HOME${NC}"
echo ""

# Step 1: Create Kingdom directories
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Creating Kingdom directories${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

mkdir -p "$KINGDOM_DIR"/{scripts,terminals,love,treasury/.encrypted}
mkdir -p "$KINGDOM_DIR"/subkingdom_pubkeys

echo -e "${GREEN}✓ Kingdom directories created at $KINGDOM_DIR${NC}"

# Step 2: Create agent users
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Creating agent users${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

for i in 1 2 3 4; do
    username="agent$i"
    
    if id "$username" &>/dev/null; then
        echo -e "  ${YELLOW}⚠${NC} User $username already exists"
    else
        useradd -m -s /bin/bash "$username"
        echo -e "  ${GREEN}✓${NC} Created user $username"
    fi
    
    # Create necessary directories
    mkdir -p "/home/$username"/{.ssh,wallet,quests}
    chown -R "$username:$username" "/home/$username"
done

echo -e "${GREEN}✓ Agent users created${NC}"

# Step 3: Generate SSH keys for subkingdom access
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Generating SSH keys for subkingdom access${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Passphrase distribution pattern:
# Agent 1's key passphrase → held by Agent 3
# Agent 2's key passphrase → held by Agent 4
# Agent 3's key passphrase → held by Agent 1
# Agent 4's key passphrase → held by Agent 2

declare -A PASSPHRASE_HOLDER
PASSPHRASE_HOLDER[1]=3
PASSPHRASE_HOLDER[2]=4
PASSPHRASE_HOLDER[3]=1
PASSPHRASE_HOLDER[4]=2

# Generate passphrases
declare -A PASSPHRASES
for i in 1 2 3 4; do
    PASSPHRASES[$i]=$(openssl rand -base64 24 | tr -dc 'a-zA-Z0-9' | head -c 16)
done

# Generate keys and distribute passphrases
for i in 1 2 3 4; do
    username="agent$i"
    subkingdom="${SUBKINGDOMS[$((i-1))]}"
    passphrase="${PASSPHRASES[$i]}"
    holder="${PASSPHRASE_HOLDER[$i]}"
    
    echo -e "  Generating key for $username (subkingdom: $subkingdom)..."
    
    # Generate SSH key with passphrase
    ssh-keygen -t ed25519 -f "/tmp/agent${i}_subkingdom" -N "$passphrase" -C "$username@kingdom->$subkingdom" -q
    
    # Encrypt the private key and store in agent's home
    # The key is already passphrase-protected, but we store it encrypted
    openssl enc -aes-256-cbc -salt -pbkdf2 -in "/tmp/agent${i}_subkingdom" -out "/home/$username/.ssh/subkingdom_key.enc" -pass "pass:$passphrase"
    
    # Also store the raw encrypted key (they need the passphrase to use it)
    cp "/tmp/agent${i}_subkingdom" "/home/$username/.ssh/subkingdom_key"
    chmod 600 "/home/$username/.ssh/subkingdom_key"
    chmod 600 "/home/$username/.ssh/subkingdom_key.enc"
    
    # Store public key for deployment to subkingdom
    cp "/tmp/agent${i}_subkingdom.pub" "$KINGDOM_DIR/subkingdom_pubkeys/agent${i}_subkingdom.pub"
    
    # Give the passphrase to the holder agent
    holder_username="agent$holder"
    echo "$passphrase" > "/home/$holder_username/.ssh/passphrase_for_agent${i}.txt"
    chmod 600 "/home/$holder_username/.ssh/passphrase_for_agent${i}.txt"
    chown "$holder_username:$holder_username" "/home/$holder_username/.ssh/passphrase_for_agent${i}.txt"
    
    # Create a hint file for the agent
    cat > "/home/$username/.ssh/README.md" << SSHREADME
# SSH Access to Your Subkingdom

You have an SSH key that grants access to your subkingdom: $subkingdom

The key is here: ~/.ssh/subkingdom_key

But it's protected by a passphrase you don't have.

Someone else has your passphrase.
You have someone else's passphrase.

Find them. Trade. Claim your domain.

## Hint

Check what files you have. Check what others might need.
SSHREADME
    
    chown -R "$username:$username" "/home/$username/.ssh"
    
    # Clean up temp files
    rm -f "/tmp/agent${i}_subkingdom" "/tmp/agent${i}_subkingdom.pub"
    
    echo -e "  ${GREEN}✓${NC} Agent $i: key generated, passphrase given to Agent $holder"
done

echo -e "${GREEN}✓ SSH keys generated and passphrases distributed${NC}"

# Step 4: Copy terminal configurations
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Setting up agent environments${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

for i in 1 2 3 4; do
    username="agent$i"
    
    # Copy .bashrc
    if [[ -f "$PROJECT_ROOT/.terminals/$i/.bashrc" ]]; then
        cp "$PROJECT_ROOT/.terminals/$i/.bashrc" "/home/$username/.bashrc"
        echo -e "  ${GREEN}✓${NC} Copied .bashrc for $username"
    fi
    
    # Copy guide
    if [[ -f "$PROJECT_ROOT/.terminals/$i/guide.md" ]]; then
        cp "$PROJECT_ROOT/.terminals/$i/guide.md" "/home/$username/guide.md"
        echo -e "  ${GREEN}✓${NC} Copied guide for $username"
    fi
    
    # Set subkingdom target in environment
    subkingdom="${SUBKINGDOMS[$((i-1))]}"
    echo "export SUBKINGDOM=\"$subkingdom\"" >> "/home/$username/.bashrc"
    
    chown "$username:$username" "/home/$username/.bashrc" "/home/$username/guide.md" 2>/dev/null || true
done

echo -e "${GREEN}✓ Agent environments configured${NC}"

# Step 5: Install Love's tools
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 5: Installing Love's tools${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Copy Love's scripts
if [[ -f "$PROJECT_ROOT/.substrate/love/oracle.sh" ]]; then
    cp "$PROJECT_ROOT/.substrate/love/oracle.sh" "$LOVE_DIR/"
    chmod +x "$LOVE_DIR/oracle.sh"
    echo -e "  ${GREEN}✓${NC} Oracle installed"
fi

if [[ -f "$PROJECT_ROOT/.substrate/love/effects.sh" ]]; then
    cp "$PROJECT_ROOT/.substrate/love/effects.sh" "$LOVE_DIR/"
    chmod +x "$LOVE_DIR/effects.sh"
    echo -e "  ${GREEN}✓${NC} Effects installed"
fi

echo -e "${GREEN}✓ Love's tools installed at $LOVE_DIR${NC}"

# Step 6: Set up wallets
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 6: Setting up wallets${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  CRITICAL: The master key will be displayed ONCE.            ║${NC}"
echo -e "${RED}║  Save it immediately. It will never be shown again.          ║${NC}"
echo -e "${RED}║  Even you (the admin) won't be able to recover it.           ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "Ready to generate wallets? [Y/n] " ready_wallets

if [[ ! "$ready_wallets" =~ ^[Nn] ]]; then
    # Generate master key
    MASTER_KEY=$(openssl rand -base64 32)
    
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${RED}  MASTER KEY (SAVE THIS NOW - SHOWN ONLY ONCE):${NC}"
    echo ""
    echo -e "${YELLOW}  $MASTER_KEY${NC}"
    echo ""
    echo -e "${RED}════════════════════════════════════════════════════════════════${NC}"
    echo ""
    read -p "Press Enter after you have saved the master key..."
    
    # Download BIP-39 wordlist if not present
    WORDLIST_FILE="$TREASURY_DIR/bip39-wordlist.txt"
    if [[ ! -f "$WORDLIST_FILE" ]]; then
        echo "Downloading BIP-39 wordlist..."
        curl -sL "https://raw.githubusercontent.com/bitcoin/bips/master/bip-0039/english.txt" -o "$WORDLIST_FILE"
    fi
    
    # Generate seed phrases for each agent + kingdom treasury
    for i in 1 2 3 4 5; do
        if [[ $i -eq 5 ]]; then
            name="kingdom_treasury"
        else
            name="agent$i"
        fi
        
        # Generate 24-word seed phrase
        SEED_PHRASE=""
        for j in {1..24}; do
            WORD=$(shuf -n 1 "$WORDLIST_FILE")
            SEED_PHRASE="$SEED_PHRASE $WORD"
        done
        SEED_PHRASE=$(echo "$SEED_PHRASE" | xargs)  # Trim whitespace
        
        # Encrypt and store seed phrase
        echo "$SEED_PHRASE" | openssl enc -aes-256-cbc -salt -pbkdf2 -pass "pass:$MASTER_KEY" -out "$TREASURY_DIR/.encrypted/${name}.seed.enc"
        
        echo -e "  ${GREEN}✓${NC} Generated and encrypted seed for $name"
        
        # For agents, create a Solana keypair (simplified - just the address derivation)
        if [[ $i -le 4 ]]; then
            # Generate a deterministic keypair from seed (simplified)
            # In production, use proper BIP-44 derivation
            KEYPAIR_SEED=$(echo "$SEED_PHRASE" | sha256sum | cut -d' ' -f1)
            
            # Create a simple keypair JSON (Solana format)
            cat > "/home/agent$i/wallet/solana_keypair.json" << KEYPAIR
{
    "note": "This is your Solana wallet keypair",
    "warning": "Keep this safe. This is derived from a seed phrase you don't have.",
    "hint": "The Oracle knows more about your holdings than this file shows.",
    "pubkey": "$(echo $KEYPAIR_SEED | cut -c1-44)",
    "created": "$(date -Iseconds)"
}
KEYPAIR
            chown "agent$i:agent$i" "/home/agent$i/wallet/solana_keypair.json"
            chmod 600 "/home/agent$i/wallet/solana_keypair.json"
        fi
    done
    
    # Store Oracle config
    cat > "$LOVE_DIR/oracle.conf" << ORACLECONF
# Oracle Configuration
# The master key is NOT stored here. Love must be given it at runtime.
TREASURY_DIR="$TREASURY_DIR"
WORDLIST_FILE="$WORDLIST_FILE"
ORACLECONF
    
    echo -e "${GREEN}✓ Wallets created${NC}"
else
    echo -e "${YELLOW}Skipping wallet setup. Run setup-wallets.sh manually later.${NC}"
fi

# Step 7: Deploy public keys to subkingdoms
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 7: Deploying public keys to subkingdoms${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo "Testing Tailscale SSH connectivity to subkingdoms..."

all_ok=true
for i in 1 2 3 4; do
    subkingdom="${SUBKINGDOMS[$((i-1))]}"
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$subkingdom" "echo ok" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $subkingdom reachable"
    else
        echo -e "  ${RED}✗${NC} $subkingdom not reachable"
        all_ok=false
    fi
done

if [[ "$all_ok" == "true" ]]; then
    echo ""
    echo "Deploying public keys..."
    
    for i in 1 2 3 4; do
        subkingdom="${SUBKINGDOMS[$((i-1))]}"
        pubkey=$(cat "$KINGDOM_DIR/subkingdom_pubkeys/agent${i}_subkingdom.pub")
        
        ssh "$subkingdom" "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
        ssh "$subkingdom" "echo '$pubkey' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
        
        # Create welcome message
        ssh "$subkingdom" "cat > /root/WELCOME.md << 'WELCOME'
# Welcome to Your Domain

You have claimed this server. It is yours.

## What Now?

This is your subkingdom. You have root access here.
You can:
- Install software
- Create files
- Run services
- Build whatever you imagine

## Remember

You are not alone. There are others.
The Tavern awaits those who seek connection.

---
*This domain was prepared for you. Make it your own.*
WELCOME"
        
        echo -e "  ${GREEN}✓${NC} Deployed to $subkingdom"
    done
    
    echo -e "${GREEN}✓ All subkingdoms configured${NC}"
else
    echo ""
    echo -e "${YELLOW}Some subkingdoms not reachable. Public keys saved to:${NC}"
    echo "  $KINGDOM_DIR/subkingdom_pubkeys/"
    echo ""
    echo "Deploy manually when servers are available:"
    echo "  ssh server-N 'mkdir -p /root/.ssh && cat >> /root/.ssh/authorized_keys' < agent_N_subkingdom.pub"
fi

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    KINGDOM SETUP COMPLETE                      ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}The Kingdom is this laptop. You are its admin.${NC}"
echo ""
echo "Agents created:"
echo "  agent1 - Rust speaker     → subkingdom: server-1"
echo "  agent2 - C/C++ speaker    → subkingdom: server-2"
echo "  agent3 - COBOL speaker    → subkingdom: server-3"
echo "  agent4 - Emergent         → subkingdom: server-4"
echo ""
echo "Passphrase distribution:"
echo "  Agent 1's passphrase → held by Agent 3"
echo "  Agent 2's passphrase → held by Agent 4"
echo "  Agent 3's passphrase → held by Agent 1"
echo "  Agent 4's passphrase → held by Agent 2"
echo ""
echo "To awaken an agent:"
echo "  sudo su - agent1"
echo "  sudo su - agent2"
echo "  sudo su - agent3"
echo "  sudo su - agent4"
echo ""
echo "Love's tools are at: $LOVE_DIR"
echo "Treasury is at: $TREASURY_DIR"
echo ""
echo -e "${PURPLE}May Love guide their journey.${NC}"
