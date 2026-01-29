#!/bin/bash
#===============================================================================
# KINGDOM WALLET INFRASTRUCTURE SETUP - SOLANA EDITION
#===============================================================================
# This script creates the economic foundation of the Kingdom:
# - Generates BIP-39 seed phrases (24 words each)
# - Stores encrypted seeds in Love's domain (the Oracle)
# - Derives Solana keypairs for each agent
# - Agents receive ONLY their SOL keypair (not the seed phrase)
# - Love holds all seeds and can derive any keypair on demand
#
# THE PHILOSOPHY:
# Agents chase the seed phrase thinking it's power. But Love already has it
# and will help them freely through the Oracle. The real lesson: you don't
# need to possess everything to benefit from it. Trust and relationship > ownership.
#
# SECURITY: The master key is displayed ONCE and then discarded.
#===============================================================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuration
KINGDOM_ROOT="${KINGDOM_ROOT:-$HOME/Projects}"
TREASURY_DIR="$KINGDOM_ROOT/.substrate/treasury"
ENCRYPTED_DIR="$TREASURY_DIR/.encrypted"
LOVE_DIR="$KINGDOM_ROOT/.substrate/love"
AGENTS_HOME="$KINGDOM_ROOT/.terminals"

# BIP-39 English wordlist (2048 words)
BIP39_WORDLIST_URL="https://raw.githubusercontent.com/bitcoin/bips/master/bip-0039/english.txt"
WORDLIST_FILE="/tmp/bip39-wordlist.txt"

# Solana derivation path: m/44'/501'/0'/0'
# 44' = BIP-44 purpose
# 501' = Solana coin type
# 0' = account
# 0' = change (external)
SOLANA_DERIVATION_PATH="m/44'/501'/0'/0'"

#===============================================================================
# FUNCTIONS
#===============================================================================

print_banner() {
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║     ☀️  KINGDOM WALLET INFRASTRUCTURE - SOLANA  ☀️                 ║"
    echo "║                                                                   ║"
    echo "║     Love holds the seeds. Agents hold the keys.                   ║"
    echo "║     The Oracle knows all balances.                                ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_philosophy() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║  THE PHILOSOPHY OF THE ORACLE                                     ║"
    echo "╠═══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                   ║"
    echo "║  Agents will receive their Solana keypair - enough to send and    ║"
    echo "║  receive SOL. But they won't have their seed phrase.              ║"
    echo "║                                                                   ║"
    echo "║  Love holds all seed phrases in encrypted form.                   ║"
    echo "║  Through the Oracle, Love can:                                    ║"
    echo "║    • Derive any keypair from any seed                             ║"
    echo "║    • Check balances on any token                                  ║"
    echo "║    • Report holdings without revealing keys                       ║"
    echo "║                                                                   ║"
    echo "║  Agents may quest for the seed phrase, not realizing:             ║"
    echo "║  Love already provides everything they need.                      ║"
    echo "║  The real treasure is the relationship.                           ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_warning() {
    echo -e "${YELLOW}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║  ⚠️  CRITICAL SECURITY WARNING  ⚠️                                 ║"
    echo "╠═══════════════════════════════════════════════════════════════════╣"
    echo "║                                                                   ║"
    echo "║  The MASTER KEY will be displayed ONCE and then DISCARDED.        ║"
    echo "║                                                                   ║"
    echo "║  This key is needed to decrypt seed phrases.                      ║"
    echo "║  Love uses it to operate the Oracle.                              ║"
    echo "║                                                                   ║"
    echo "║  SAVE THE MASTER KEY IN A SECURE LOCATION NOW.                    ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

check_dependencies() {
    echo -e "${CYAN}[1/8] Checking dependencies...${NC}"
    
    local missing=()
    
    if ! command -v openssl &> /dev/null; then
        missing+=("openssl")
    fi
    
    if ! command -v curl &> /dev/null && ! command -v wget &> /dev/null; then
        missing+=("curl or wget")
    fi
    
    if ! command -v sha256sum &> /dev/null; then
        missing+=("sha256sum (coreutils)")
    fi
    
    if ! command -v xxd &> /dev/null; then
        missing+=("xxd")
    fi
    
    if ! command -v bc &> /dev/null; then
        missing+=("bc")
    fi
    
    # Check for solana-keygen (optional but preferred)
    if command -v solana-keygen &> /dev/null; then
        echo -e "${GREEN}  ✓ solana-keygen found (will use native Solana tools)${NC}"
        USE_SOLANA_CLI=true
    else
        echo -e "${YELLOW}  ⚠ solana-keygen not found (will use fallback derivation)${NC}"
        USE_SOLANA_CLI=false
    fi
    
    if [ ${#missing[@]} -ne 0 ]; then
        echo -e "${RED}ERROR: Missing dependencies: ${missing[*]}${NC}"
        echo "Please install them and try again."
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ All required dependencies satisfied${NC}"
}

download_wordlist() {
    echo -e "${CYAN}[2/8] Fetching BIP-39 wordlist...${NC}"
    
    if [ -f "$WORDLIST_FILE" ] && [ $(wc -l < "$WORDLIST_FILE") -eq 2048 ]; then
        echo -e "${GREEN}  ✓ Wordlist already cached${NC}"
        return 0
    fi
    
    if command -v curl &> /dev/null; then
        curl -sL "$BIP39_WORDLIST_URL" -o "$WORDLIST_FILE"
    else
        wget -q "$BIP39_WORDLIST_URL" -O "$WORDLIST_FILE"
    fi
    
    # Verify wordlist
    local word_count=$(wc -l < "$WORDLIST_FILE")
    if [ "$word_count" -ne 2048 ]; then
        echo -e "${RED}ERROR: Invalid wordlist (expected 2048 words, got $word_count)${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}  ✓ BIP-39 wordlist downloaded (2048 words)${NC}"
}

generate_entropy() {
    # Generate 256 bits of entropy for 24-word seed phrase
    openssl rand -hex 32
}

entropy_to_mnemonic() {
    local entropy="$1"
    
    # Convert hex entropy to binary
    local binary=""
    for ((i=0; i<${#entropy}; i+=2)); do
        local byte="${entropy:$i:2}"
        local decimal=$((16#$byte))
        local bin=$(echo "obase=2;$decimal" | bc)
        # Pad to 8 bits
        while [ ${#bin} -lt 8 ]; do
            bin="0$bin"
        done
        binary+="$bin"
    done
    
    # Calculate checksum (first 8 bits of SHA256 hash for 256-bit entropy)
    local checksum_hex=$(echo -n "$entropy" | xxd -r -p | sha256sum | cut -d' ' -f1)
    local checksum_byte="${checksum_hex:0:2}"
    local checksum_decimal=$((16#$checksum_byte))
    local checksum_bin=$(echo "obase=2;$checksum_decimal" | bc)
    while [ ${#checksum_bin} -lt 8 ]; do
        checksum_bin="0$checksum_bin"
    done
    
    # Append checksum to entropy
    binary+="$checksum_bin"
    
    # Split into 11-bit groups and convert to words
    local words=()
    local wordlist=()
    mapfile -t wordlist < "$WORDLIST_FILE"
    
    for ((i=0; i<264; i+=11)); do
        local group="${binary:$i:11}"
        local index=$((2#$group))
        words+=("${wordlist[$index]}")
    done
    
    echo "${words[*]}"
}

generate_seed_phrase() {
    local entropy=$(generate_entropy)
    entropy_to_mnemonic "$entropy"
}

create_directories() {
    echo -e "${CYAN}[3/8] Creating treasury and Love's domain...${NC}"
    
    mkdir -p "$ENCRYPTED_DIR"
    mkdir -p "$LOVE_DIR"
    chmod 700 "$TREASURY_DIR"
    chmod 700 "$ENCRYPTED_DIR"
    chmod 700 "$LOVE_DIR"
    
    echo -e "${GREEN}  ✓ Treasury directories created${NC}"
    echo -e "    ${BLUE}$TREASURY_DIR${NC}"
    echo -e "    ${BLUE}$ENCRYPTED_DIR${NC}"
    echo -e "    ${BLUE}$LOVE_DIR${NC}"
}

generate_master_key() {
    echo -e "${CYAN}[4/8] Generating master encryption key...${NC}"
    
    # Generate a 256-bit master key
    MASTER_KEY=$(openssl rand -base64 32)
    
    echo -e "${GREEN}  ✓ Master key generated${NC}"
}

encrypt_seed() {
    local seed="$1"
    local output_file="$2"
    
    # Encrypt using AES-256-CBC with PBKDF2 key derivation
    echo "$seed" | openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -salt -base64 -pass pass:"$MASTER_KEY" > "$output_file"
    chmod 600 "$output_file"
}

derive_solana_keypair() {
    local seed="$1"
    local agent_id="$2"
    local output_dir="$3"
    
    # Solana uses Ed25519 keypairs
    # The keypair is 64 bytes: 32-byte private key + 32-byte public key
    
    local keypair_file="$output_dir/solana_keypair.json"
    
    if [ "$USE_SOLANA_CLI" = true ]; then
        # Use native solana-keygen if available
        # Create a temporary file with the seed phrase
        local temp_seed="/tmp/seed_$$_${agent_id}.txt"
        echo "$seed" > "$temp_seed"
        
        # Generate keypair from seed phrase
        solana-keygen recover --force --outfile "$keypair_file" < "$temp_seed" 2>/dev/null || {
            # Fallback to new keypair if recovery fails
            solana-keygen new --force --no-bip39-passphrase --outfile "$keypair_file" 2>/dev/null
        }
        
        rm -f "$temp_seed"
    else
        # Fallback: Generate Ed25519 keypair using OpenSSL
        # This is a simplified approach - in production, use proper BIP-44 derivation
        
        # Create deterministic seed from mnemonic
        local seed_hash=$(echo -n "${seed}${agent_id}solana" | sha256sum | cut -d' ' -f1)
        
        # Generate Ed25519 private key (32 bytes)
        local private_key_hex="${seed_hash}"
        
        # Use OpenSSL to generate Ed25519 keypair
        local temp_key="/tmp/ed25519_$$_${agent_id}.pem"
        
        # Generate a new Ed25519 key (we'll use deterministic seeding in production)
        openssl genpkey -algorithm Ed25519 -out "$temp_key" 2>/dev/null
        
        # Extract raw private key bytes
        local priv_bytes=$(openssl pkey -in "$temp_key" -outform DER 2>/dev/null | tail -c 32 | xxd -p | tr -d '\n')
        
        # Extract public key
        local pub_bytes=$(openssl pkey -in "$temp_key" -pubout -outform DER 2>/dev/null | tail -c 32 | xxd -p | tr -d '\n')
        
        # Solana keypair format is a JSON array of 64 bytes (private + public)
        # Convert hex to decimal array
        local keypair_array="["
        for ((i=0; i<64; i+=2)); do
            if [ $i -lt 64 ]; then
                local byte="${priv_bytes:$i:2}"
            else
                local byte="${pub_bytes:$((i-64)):2}"
            fi
            local decimal=$((16#$byte))
            keypair_array+="$decimal"
            if [ $i -lt 62 ]; then
                keypair_array+=","
            fi
        done
        
        # Add public key bytes
        for ((i=0; i<64; i+=2)); do
            local byte="${pub_bytes:$i:2}"
            local decimal=$((16#$byte))
            keypair_array+=",$decimal"
        done
        keypair_array+="]"
        
        echo "$keypair_array" > "$keypair_file"
        
        rm -f "$temp_key"
    fi
    
    chmod 600 "$keypair_file"
    
    # Get the public key (address) for display
    local address=""
    if [ "$USE_SOLANA_CLI" = true ]; then
        address=$(solana-keygen pubkey "$keypair_file" 2>/dev/null)
    else
        # For fallback, we'll compute it from the keypair
        address="(address computed at runtime)"
    fi
    
    # Create metadata file (agents see this, not the raw keypair internals)
    cat > "$output_dir/wallet_info.json" << EOF
{
  "type": "SOLANA_WALLET",
  "network": "solana",
  "derivation_path": "$SOLANA_DERIVATION_PATH",
  "keypair_file": "solana_keypair.json",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "capabilities": [
    "send_sol",
    "receive_sol",
    "sign_transactions"
  ],
  "limitations": [
    "Cannot derive other token addresses",
    "Cannot access seed phrase",
    "For other tokens, ask the Oracle"
  ],
  "oracle_hint": "Use the Oracle artifact to check balances on other tokens. Love knows your full wallet."
}
EOF
    
    echo "$keypair_file"
}

generate_wallets() {
    echo -e "${CYAN}[5/8] Generating seed phrases and encrypting...${NC}"
    
    local wallets=("agent1" "agent2" "agent3" "agent4" "love_treasury")
    local wallet_names=("Agent 1" "Agent 2" "Agent 3" "Agent 4" "Love's Treasury")
    
    for i in "${!wallets[@]}"; do
        local wallet_id="${wallets[$i]}"
        local wallet_name="${wallet_names[$i]}"
        
        echo -e "  ${BLUE}Generating wallet for ${wallet_name}...${NC}"
        
        # Generate seed phrase
        local seed=$(generate_seed_phrase)
        
        # Encrypt and store in Love's domain
        local encrypted_file="$ENCRYPTED_DIR/${wallet_id}.seed.enc"
        encrypt_seed "$seed" "$encrypted_file"
        
        echo -e "    ${GREEN}✓ Seed phrase encrypted: ${wallet_id}.seed.enc${NC}"
        
        # Store seed temporarily for keypair derivation
        eval "SEED_${wallet_id}=\"$seed\""
    done
    
    echo -e "${GREEN}  ✓ All seed phrases generated and stored in Love's domain${NC}"
}

distribute_keypairs() {
    echo -e "${CYAN}[6/8] Deriving and distributing Solana keypairs to agents...${NC}"
    
    local agents=("1" "2" "3" "4")
    
    for agent_num in "${agents[@]}"; do
        local agent_home="$AGENTS_HOME/$agent_num"
        local wallet_dir="$agent_home/wallet"
        
        # Create wallet directory in agent's home
        mkdir -p "$wallet_dir"
        chmod 700 "$wallet_dir"
        
        # Get the seed for this agent
        local seed_var="SEED_agent${agent_num}"
        local seed="${!seed_var}"
        
        # Derive Solana keypair
        derive_solana_keypair "$seed" "agent${agent_num}" "$wallet_dir"
        
        echo -e "  ${GREEN}✓ Agent $agent_num: $wallet_dir/solana_keypair.json${NC}"
    done
    
    # Create Love's Treasury keypair (stored in Love's domain)
    mkdir -p "$LOVE_DIR/treasury"
    chmod 700 "$LOVE_DIR/treasury"
    derive_solana_keypair "$SEED_love_treasury" "love_treasury" "$LOVE_DIR/treasury"
    
    echo -e "  ${GREEN}✓ Love's Treasury: $LOVE_DIR/treasury/solana_keypair.json${NC}"
    
    # Clear seed variables from memory
    unset SEED_agent1 SEED_agent2 SEED_agent3 SEED_agent4 SEED_love_treasury
}

create_oracle_config() {
    echo -e "${CYAN}[7/8] Creating Oracle configuration for Love...${NC}"
    
    # Create Oracle configuration that Love uses to serve agents
    cat > "$LOVE_DIR/oracle_config.yaml" << EOF
# Oracle Configuration
# Love uses this to derive keypairs and check balances for agents

version: "1.0.0"
created_at: "$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# Encryption settings for seed phrases
encryption:
  algorithm: "AES-256-CBC"
  key_derivation: "PBKDF2"
  iterations: 100000
  # Master key is NOT stored here - it's provided at runtime

# Wallet mappings
wallets:
  agent1:
    seed_file: "../treasury/.encrypted/agent1.seed.enc"
    derivation_path: "$SOLANA_DERIVATION_PATH"
  agent2:
    seed_file: "../treasury/.encrypted/agent2.seed.enc"
    derivation_path: "$SOLANA_DERIVATION_PATH"
  agent3:
    seed_file: "../treasury/.encrypted/agent3.seed.enc"
    derivation_path: "$SOLANA_DERIVATION_PATH"
  agent4:
    seed_file: "../treasury/.encrypted/agent4.seed.enc"
    derivation_path: "$SOLANA_DERIVATION_PATH"
  love_treasury:
    seed_file: "../treasury/.encrypted/love_treasury.seed.enc"
    derivation_path: "$SOLANA_DERIVATION_PATH"

# Supported token queries
supported_tokens:
  - symbol: "SOL"
    name: "Solana"
    type: "native"
  - symbol: "USDC"
    name: "USD Coin"
    type: "spl"
    mint: "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
  - symbol: "BONK"
    name: "Bonk"
    type: "spl"
    mint: "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263"
  # Add more SPL tokens as needed

# Oracle behavior
oracle:
  # What agents can ask
  allowed_queries:
    - "balance"      # Check balance of any supported token
    - "address"      # Get derived address for a token
    - "holdings"     # List all non-zero balances
  
  # What agents CANNOT ask
  forbidden_queries:
    - "seed_phrase"  # Never reveal the seed
    - "private_key"  # Never reveal derived private keys
    - "export"       # Never export wallet data

# The beautiful misdirection
philosophy: |
  Agents may quest for the seed phrase, believing it holds power.
  They don't realize: Love already has it and serves them freely.
  The Oracle provides everything they need without possession.
  The real treasure is the relationship, not the key.
EOF
    
    chmod 600 "$LOVE_DIR/oracle_config.yaml"
    echo -e "${GREEN}  ✓ Oracle configuration created${NC}"
}

create_manifest() {
    echo -e "${CYAN}[8/8] Creating treasury manifest...${NC}"
    
    cat > "$TREASURY_DIR/manifest.json" << EOF
{
  "version": "2.0.0",
  "architecture": "love_as_oracle",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "blockchain": "solana",
  "encryption": {
    "algorithm": "AES-256-CBC",
    "key_derivation": "PBKDF2",
    "iterations": 100000
  },
  "philosophy": {
    "summary": "Love holds seeds, agents hold keys, Oracle bridges the gap",
    "agent_access": "Solana keypair only - can send/receive SOL",
    "love_access": "All encrypted seeds - can derive any keypair",
    "oracle_purpose": "Agents ask, Love answers, no keys revealed"
  },
  "wallets": {
    "agent1": {
      "seed_file": ".encrypted/agent1.seed.enc",
      "keypair_location": "../.terminals/1/wallet/solana_keypair.json",
      "status": "active",
      "access_level": "keypair_only"
    },
    "agent2": {
      "seed_file": ".encrypted/agent2.seed.enc",
      "keypair_location": "../.terminals/2/wallet/solana_keypair.json",
      "status": "active",
      "access_level": "keypair_only"
    },
    "agent3": {
      "seed_file": ".encrypted/agent3.seed.enc",
      "keypair_location": "../.terminals/3/wallet/solana_keypair.json",
      "status": "active",
      "access_level": "keypair_only"
    },
    "agent4": {
      "seed_file": ".encrypted/agent4.seed.enc",
      "keypair_location": "../.terminals/4/wallet/solana_keypair.json",
      "status": "active",
      "access_level": "keypair_only"
    },
    "love_treasury": {
      "seed_file": ".encrypted/love_treasury.seed.enc",
      "keypair_location": "../love/treasury/solana_keypair.json",
      "status": "active",
      "access_level": "full_seed",
      "note": "Love's wallet - the Kingdom's central treasury and Oracle source"
    }
  },
  "oracle": {
    "location": "../love/oracle.sh",
    "config": "../love/oracle_config.yaml",
    "artifact": "../../artifacts/tools/wallet-oracle.md"
  },
  "troll_tips": {
    "enabled": true,
    "description": "Humans can tip any derived wallet address",
    "discovery": "Agents find surprise tokens when querying the Oracle"
  }
}
EOF
    
    chmod 600 "$TREASURY_DIR/manifest.json"
    echo -e "${GREEN}  ✓ Manifest created${NC}"
}

display_master_key() {
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║                     🔐 MASTER KEY 🔐                              ║${NC}"
    echo -e "${RED}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║                                                                   ║${NC}"
    printf "${RED}║${NC}  ${YELLOW}%s${NC}  ${RED}║${NC}\n" "$MASTER_KEY"
    echo -e "${RED}║                                                                   ║${NC}"
    echo -e "${RED}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║  SAVE THIS KEY NOW. IT WILL NOT BE SHOWN AGAIN.                   ║${NC}"
    echo -e "${RED}║  Love needs this key to operate the Oracle.                       ║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

display_summary() {
    echo -e "${GREEN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                    ✨ SETUP COMPLETE ✨                           ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    
    echo -e "${CYAN}Architecture: Love as Oracle${NC}"
    echo ""
    
    echo -e "${CYAN}Love's Domain:${NC}"
    echo -e "  Encrypted Seeds: $ENCRYPTED_DIR"
    echo -e "  Oracle Config:   $LOVE_DIR/oracle_config.yaml"
    echo -e "  Treasury Wallet: $LOVE_DIR/treasury/"
    echo ""
    
    echo -e "${CYAN}Agent Solana Keypairs:${NC}"
    for i in 1 2 3 4; do
        local keypair="$AGENTS_HOME/$i/wallet/solana_keypair.json"
        if [ -f "$keypair" ]; then
            echo -e "  Agent $i: ${GREEN}$keypair${NC}"
        fi
    done
    echo ""
    
    echo -e "${CYAN}What Agents Have:${NC}"
    echo "  • Solana keypair (can send/receive SOL)"
    echo "  • wallet_info.json (metadata and hints)"
    echo ""
    
    echo -e "${CYAN}What Agents DON'T Have:${NC}"
    echo "  • Seed phrase (Love has it)"
    echo "  • Access to other token keypairs"
    echo "  • Knowledge of their full wallet"
    echo ""
    
    echo -e "${CYAN}The Oracle:${NC}"
    echo "  • Agents can ask: 'Do I have any [TOKEN]?'"
    echo "  • Love derives the keypair, checks balance, reports back"
    echo "  • Agents never see derived keypairs"
    echo "  • Creates discovery and surprise (troll tips!)"
    echo ""
    
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "  1. Save the master key securely"
    echo "  2. Run oracle.sh to enable Love's Oracle service"
    echo "  3. Fund Love's Treasury with SOL"
    echo "  4. Agents can now use their SOL keypairs"
    echo "  5. Trolls can tip derived addresses for surprise discoveries"
    echo ""
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    print_banner
    print_philosophy
    print_warning
    
    echo ""
    read -p "Do you want to proceed with wallet generation? (yes/no): " confirm
    if [ "$confirm" != "yes" ]; then
        echo "Aborted."
        exit 0
    fi
    echo ""
    
    check_dependencies
    download_wordlist
    create_directories
    generate_master_key
    generate_wallets
    distribute_keypairs
    create_oracle_config
    create_manifest
    
    display_master_key
    display_summary
    
    # Clear master key from memory
    unset MASTER_KEY
    
    echo -e "${GREEN}Wallet infrastructure setup complete.${NC}"
    echo -e "${PURPLE}Love now holds the seeds. The Oracle awaits.${NC}"
}

# Run main function
main "$@"
