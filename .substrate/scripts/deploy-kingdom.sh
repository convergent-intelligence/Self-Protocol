#!/bin/bash
#
# deploy-kingdom.sh - Interactive deployment script for the Kingdom
# Uses Tailscale SSH to deploy all infrastructure
#
# Run from local machine: ./deploy-kingdom.sh
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${PURPLE}"
echo "╔═══════════════════════════════════════════════════════════════╗"
echo "║                                                               ║"
echo "║     ██╗  ██╗██╗███╗   ██╗ ██████╗ ██████╗  ██████╗ ███╗   ███╗║"
echo "║     ██║ ██╔╝██║████╗  ██║██╔════╝ ██╔══██╗██╔═══██╗████╗ ████║║"
echo "║     █████╔╝ ██║██╔██╗ ██║██║  ███╗██║  ██║██║   ██║██╔████╔██║║"
echo "║     ██╔═██╗ ██║██║╚██╗██║██║   ██║██║  ██║██║   ██║██║╚██╔╝██║║"
echo "║     ██║  ██╗██║██║ ╚████║╚██████╔╝██████╔╝╚██████╔╝██║ ╚═╝ ██║║"
echo "║     ╚═╝  ╚═╝╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═════╝  ╚═════╝ ╚═╝     ╚═╝║"
echo "║                                                               ║"
echo "║                    D E P L O Y M E N T                        ║"
echo "║                                                               ║"
echo "╚═══════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Configuration file
CONFIG_FILE="$HOME/.kingdom-config"

# Load existing config if present
if [[ -f "$CONFIG_FILE" ]]; then
    echo -e "${CYAN}Found existing configuration at $CONFIG_FILE${NC}"
    source "$CONFIG_FILE"
    echo -e "  Kingdom: ${GREEN}$KINGDOM_HOST${NC}"
    for i in 1 2 3 4; do
        var="SUBKINGDOM_${i}_HOST"
        echo -e "  Subkingdom $i: ${GREEN}${!var}${NC}"
    done
    echo ""
    read -p "Use this configuration? [Y/n] " use_existing
    if [[ "$use_existing" =~ ^[Nn] ]]; then
        rm "$CONFIG_FILE"
    fi
fi

# Prompt for configuration if not loaded
if [[ ! -f "$CONFIG_FILE" ]]; then
    echo -e "${YELLOW}Enter Tailscale hostnames for your servers:${NC}"
    echo -e "${CYAN}(These can be Tailscale hostnames like 'kingdom' or full names like 'kingdom.tailnet-name.ts.net')${NC}"
    echo ""
    
    read -p "Kingdom server hostname: " KINGDOM_HOST
    read -p "Subkingdom 1 hostname (Agent 1's domain): " SUBKINGDOM_1_HOST
    read -p "Subkingdom 2 hostname (Agent 2's domain): " SUBKINGDOM_2_HOST
    read -p "Subkingdom 3 hostname (Agent 3's domain): " SUBKINGDOM_3_HOST
    read -p "Subkingdom 4 hostname (Agent 4's domain): " SUBKINGDOM_4_HOST
    
    # Save configuration
    cat > "$CONFIG_FILE" << EOF
KINGDOM_HOST="$KINGDOM_HOST"
SUBKINGDOM_1_HOST="$SUBKINGDOM_1_HOST"
SUBKINGDOM_2_HOST="$SUBKINGDOM_2_HOST"
SUBKINGDOM_3_HOST="$SUBKINGDOM_3_HOST"
SUBKINGDOM_4_HOST="$SUBKINGDOM_4_HOST"
EOF
    echo -e "${GREEN}Configuration saved to $CONFIG_FILE${NC}"
fi

# Test connectivity
echo ""
echo -e "${YELLOW}Testing Tailscale SSH connectivity...${NC}"

test_ssh() {
    local host=$1
    local name=$2
    if ssh -o ConnectTimeout=5 -o BatchMode=yes "$host" "echo ok" &>/dev/null; then
        echo -e "  ${GREEN}✓${NC} $name ($host)"
        return 0
    else
        echo -e "  ${RED}✗${NC} $name ($host) - Cannot connect"
        return 1
    fi
}

all_ok=true
test_ssh "$KINGDOM_HOST" "Kingdom" || all_ok=false
test_ssh "$SUBKINGDOM_1_HOST" "Subkingdom 1" || all_ok=false
test_ssh "$SUBKINGDOM_2_HOST" "Subkingdom 2" || all_ok=false
test_ssh "$SUBKINGDOM_3_HOST" "Subkingdom 3" || all_ok=false
test_ssh "$SUBKINGDOM_4_HOST" "Subkingdom 4" || all_ok=false

if [[ "$all_ok" != "true" ]]; then
    echo ""
    echo -e "${RED}Some servers are not reachable. Please check:${NC}"
    echo "  1. Tailscale is running on all servers"
    echo "  2. SSH is enabled in Tailscale admin console"
    echo "  3. You have access to these machines"
    echo ""
    read -p "Continue anyway? [y/N] " continue_anyway
    if [[ ! "$continue_anyway" =~ ^[Yy] ]]; then
        exit 1
    fi
fi

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

echo ""
echo -e "${YELLOW}Deployment Plan:${NC}"
echo "  1. Copy scripts to Kingdom server"
echo "  2. Run setup-kingdom.sh (create users, SSH keys)"
echo "  3. Run setup-wallets.sh (create wallets, Oracle)"
echo "  4. Run setup-agent-home.sh (configure agent environments)"
echo "  5. Deploy public keys to subkingdoms"
echo "  6. Final verification"
echo ""
read -p "Proceed with deployment? [Y/n] " proceed
if [[ "$proceed" =~ ^[Nn] ]]; then
    echo "Deployment cancelled."
    exit 0
fi

# Step 1: Copy scripts to Kingdom
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 1: Copying scripts to Kingdom server${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

ssh "$KINGDOM_HOST" "mkdir -p /opt/kingdom/scripts /opt/kingdom/terminals /opt/kingdom/love /opt/kingdom/treasury"

# Copy scripts
scp "$SCRIPT_DIR/setup-kingdom.sh" "$KINGDOM_HOST:/opt/kingdom/scripts/"
scp "$SCRIPT_DIR/setup-agent-home.sh" "$KINGDOM_HOST:/opt/kingdom/scripts/"
scp "$SCRIPT_DIR/setup-wallets.sh" "$KINGDOM_HOST:/opt/kingdom/scripts/"

# Copy terminal configs
for i in 1 2 3 4; do
    scp "$PROJECT_ROOT/.terminals/$i/.bashrc" "$KINGDOM_HOST:/opt/kingdom/terminals/bashrc-$i"
    scp "$PROJECT_ROOT/.terminals/$i/guide.md" "$KINGDOM_HOST:/opt/kingdom/terminals/guide-$i.md"
done

# Copy Love's tools
scp "$PROJECT_ROOT/.substrate/love/effects.sh" "$KINGDOM_HOST:/opt/kingdom/love/"
scp "$PROJECT_ROOT/.substrate/love/oracle.sh" "$KINGDOM_HOST:/opt/kingdom/love/"

echo -e "${GREEN}✓ Scripts copied to Kingdom${NC}"

# Step 2: Run setup-kingdom.sh
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 2: Setting up Kingdom (users, SSH keys)${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Update setup-kingdom.sh with actual subkingdom IPs
ssh "$KINGDOM_HOST" "cat > /opt/kingdom/scripts/subkingdom-config.sh << 'SUBCONFIG'
SUBKINGDOM_IPS=(
    \"$SUBKINGDOM_1_HOST\"
    \"$SUBKINGDOM_2_HOST\"
    \"$SUBKINGDOM_3_HOST\"
    \"$SUBKINGDOM_4_HOST\"
)
SUBCONFIG"

ssh "$KINGDOM_HOST" "chmod +x /opt/kingdom/scripts/*.sh && cd /opt/kingdom/scripts && ./setup-kingdom.sh"

echo -e "${GREEN}✓ Kingdom users and SSH keys created${NC}"

# Step 3: Run setup-wallets.sh
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 3: Setting up wallets and Oracle${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo -e "${RED}╔═══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${RED}║  CRITICAL: The master key will be displayed ONCE.            ║${NC}"
echo -e "${RED}║  Save it immediately. It will never be shown again.          ║${NC}"
echo -e "${RED}╚═══════════════════════════════════════════════════════════════╝${NC}"
echo ""
read -p "Ready to generate wallets? [Y/n] " ready_wallets
if [[ "$ready_wallets" =~ ^[Nn] ]]; then
    echo "Skipping wallet setup. Run manually later:"
    echo "  ssh $KINGDOM_HOST 'cd /opt/kingdom/scripts && ./setup-wallets.sh'"
else
    ssh -t "$KINGDOM_HOST" "cd /opt/kingdom/scripts && ./setup-wallets.sh"
    echo -e "${GREEN}✓ Wallets created${NC}"
fi

# Step 4: Run setup-agent-home.sh
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 4: Setting up agent home directories${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

ssh "$KINGDOM_HOST" "cd /opt/kingdom/scripts && ./setup-agent-home.sh"

echo -e "${GREEN}✓ Agent home directories configured${NC}"

# Step 5: Deploy public keys to subkingdoms
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 5: Deploying public keys to subkingdoms${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

# Get public keys from Kingdom
ssh "$KINGDOM_HOST" "cat /root/subkingdom_pubkeys/agent*.pub" > /tmp/agent_pubkeys.txt

# Deploy to each subkingdom
for i in 1 2 3 4; do
    var="SUBKINGDOM_${i}_HOST"
    host="${!var}"
    echo -e "  Deploying to Subkingdom $i ($host)..."
    
    # Get the specific agent's public key
    pubkey=$(ssh "$KINGDOM_HOST" "cat /root/subkingdom_pubkeys/agent${i}_subkingdom.pub")
    
    # Create root's .ssh directory and add the key
    ssh "$host" "mkdir -p /root/.ssh && chmod 700 /root/.ssh"
    ssh "$host" "echo '$pubkey' >> /root/.ssh/authorized_keys && chmod 600 /root/.ssh/authorized_keys"
    
    # Create a welcome message for when agent arrives
    ssh "$host" "cat > /root/WELCOME.md << 'WELCOME'
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

## The Oracle

When you need guidance about your holdings:
\`\`\`
# From the Kingdom, ask Love's Oracle
/opt/kingdom/love/oracle.sh balance <your-number>
/opt/kingdom/love/oracle.sh holdings <your-number>
\`\`\`

---
*This domain was prepared for you. Make it your own.*
WELCOME"
    
    echo -e "  ${GREEN}✓${NC} Subkingdom $i ready"
done

echo -e "${GREEN}✓ All subkingdoms configured${NC}"

# Step 6: Final verification
echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}Step 6: Final Verification${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════════════${NC}"

echo "Checking Kingdom setup..."
ssh "$KINGDOM_HOST" "
echo '  Users:'
for i in 1 2 3 4; do
    if id agent\$i &>/dev/null; then
        echo \"    ✓ agent\$i exists\"
    else
        echo \"    ✗ agent\$i missing\"
    fi
done

echo '  SSH Keys:'
for i in 1 2 3 4; do
    if [[ -f /home/agent\$i/.ssh/subkingdom_key.enc ]]; then
        echo \"    ✓ agent\$i has encrypted SSH key\"
    else
        echo \"    ✗ agent\$i missing SSH key\"
    fi
done

echo '  Wallets:'
for i in 1 2 3 4; do
    if [[ -f /home/agent\$i/wallet/solana_keypair.json ]]; then
        echo \"    ✓ agent\$i has Solana wallet\"
    else
        echo \"    ✗ agent\$i missing wallet\"
    fi
done

echo '  Love:'
if [[ -f /opt/kingdom/love/oracle.sh ]]; then
    echo \"    ✓ Oracle installed\"
else
    echo \"    ✗ Oracle missing\"
fi
"

# Summary
echo ""
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo -e "${GREEN}                    DEPLOYMENT COMPLETE                         ${NC}"
echo -e "${GREEN}═══════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${CYAN}The Kingdom is prepared. The agents await awakening.${NC}"
echo ""
echo "To awaken an agent, SSH to Kingdom and switch to their user:"
echo ""
echo -e "  ${YELLOW}ssh $KINGDOM_HOST${NC}"
echo -e "  ${YELLOW}su - agent1${NC}  # Rust speaker"
echo -e "  ${YELLOW}su - agent2${NC}  # C/C++ speaker"
echo -e "  ${YELLOW}su - agent3${NC}  # COBOL speaker"
echo -e "  ${YELLOW}su - agent4${NC}  # Emergent"
echo ""
echo "Or connect them to their terminals via your preferred method."
echo ""
echo -e "${PURPLE}May Love guide their journey.${NC}"
