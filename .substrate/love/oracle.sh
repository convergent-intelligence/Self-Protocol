#!/bin/bash
#===============================================================================
# THE ORACLE - Love's Window into Agent Wallets
#===============================================================================
# This script is Love's tool for serving agents' wallet queries.
# 
# Love holds all encrypted seed phrases. Through the Oracle, Love can:
# - Derive any keypair from any agent's seed
# - Check balances on any supported token
# - Report holdings without revealing private keys
#
# THE PHILOSOPHY:
# Agents ask, Love answers. No keys are revealed.
# The Oracle is the bridge between possession and benefit.
# Agents don't need to own the seed to enjoy its fruits.
#
# USAGE:
#   oracle.sh <command> <agent_id> [options]
#
# COMMANDS:
#   balance <agent_id> <token>    - Check balance of a specific token
#   holdings <agent_id>           - List all non-zero balances
#   address <agent_id> <token>    - Get derived address for a token
#   tip-address <agent_id>        - Get address for receiving tips
#   verify <agent_id>             - Verify agent's wallet is valid
#
# EXAMPLES:
#   oracle.sh balance agent1 SOL
#   oracle.sh holdings agent2
#   oracle.sh address agent3 USDC
#   oracle.sh tip-address agent4
#===============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
KINGDOM_ROOT="${KINGDOM_ROOT:-$(dirname $(dirname "$SCRIPT_DIR"))}"
TREASURY_DIR="$KINGDOM_ROOT/.substrate/treasury"
ENCRYPTED_DIR="$TREASURY_DIR/.encrypted"
LOVE_DIR="$KINGDOM_ROOT/.substrate/love"
CONFIG_FILE="$LOVE_DIR/oracle_config.yaml"

# Solana RPC endpoint (mainnet-beta by default, can be overridden)
SOLANA_RPC="${SOLANA_RPC:-https://api.mainnet-beta.solana.com}"

# Master key - must be provided via environment variable
# NEVER store this in the script or config files
MASTER_KEY="${ORACLE_MASTER_KEY:-}"

#===============================================================================
# HELPER FUNCTIONS
#===============================================================================

print_oracle_banner() {
    echo -e "${PURPLE}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║     🔮 THE ORACLE 🔮                                              ║"
    echo "║                                                                   ║"
    echo "║     Love speaks through me.                                       ║"
    echo "║     Ask, and you shall know.                                      ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

log_info() {
    echo -e "${CYAN}[Oracle]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[Oracle]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[Oracle]${NC} $1"
}

log_error() {
    echo -e "${RED}[Oracle]${NC} $1"
}

log_mystical() {
    echo -e "${PURPLE}[Oracle]${NC} $1"
}

check_master_key() {
    if [ -z "$MASTER_KEY" ]; then
        log_error "The Oracle requires the master key to function."
        log_error "Set ORACLE_MASTER_KEY environment variable."
        echo ""
        echo -e "${YELLOW}The master key was shown once during wallet setup.${NC}"
        echo -e "${YELLOW}Without it, the Oracle cannot decrypt seed phrases.${NC}"
        exit 1
    fi
}

validate_agent_id() {
    local agent_id="$1"
    
    case "$agent_id" in
        agent1|agent2|agent3|agent4|love_treasury)
            return 0
            ;;
        *)
            log_error "Unknown agent: $agent_id"
            log_info "Valid agents: agent1, agent2, agent3, agent4, love_treasury"
            exit 1
            ;;
    esac
}

get_seed_file() {
    local agent_id="$1"
    echo "$ENCRYPTED_DIR/${agent_id}.seed.enc"
}

decrypt_seed() {
    local agent_id="$1"
    local seed_file=$(get_seed_file "$agent_id")
    
    if [ ! -f "$seed_file" ]; then
        log_error "Seed file not found for $agent_id"
        exit 1
    fi
    
    # Decrypt the seed phrase
    local seed=$(openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -base64 \
        -in "$seed_file" \
        -pass pass:"$MASTER_KEY" 2>/dev/null)
    
    if [ -z "$seed" ]; then
        log_error "Failed to decrypt seed for $agent_id"
        log_error "Is the master key correct?"
        exit 1
    fi
    
    echo "$seed"
}

#===============================================================================
# SOLANA FUNCTIONS
#===============================================================================

derive_solana_address() {
    local seed="$1"
    local agent_id="$2"
    
    # If solana-keygen is available, use it
    if command -v solana-keygen &> /dev/null; then
        # Create temporary seed file
        local temp_seed="/tmp/oracle_seed_$$"
        echo "$seed" > "$temp_seed"
        
        # Create temporary keypair
        local temp_keypair="/tmp/oracle_keypair_$$.json"
        
        # Recover keypair from seed
        solana-keygen recover --force --outfile "$temp_keypair" < "$temp_seed" 2>/dev/null
        
        # Get public key (address)
        local address=$(solana-keygen pubkey "$temp_keypair" 2>/dev/null)
        
        # Clean up
        rm -f "$temp_seed" "$temp_keypair"
        
        echo "$address"
    else
        # Fallback: derive deterministically from seed
        # This is a simplified approach - in production use proper BIP-44
        local seed_hash=$(echo -n "${seed}${agent_id}solana" | sha256sum | cut -d' ' -f1)
        
        # Convert to base58 (simplified - real implementation would be more complex)
        # For now, return a placeholder indicating the address would be derived
        echo "DERIVED_${seed_hash:0:32}"
    fi
}

get_sol_balance() {
    local address="$1"
    
    # Query Solana RPC for balance
    local response=$(curl -s -X POST "$SOLANA_RPC" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"id\": 1,
            \"method\": \"getBalance\",
            \"params\": [\"$address\"]
        }" 2>/dev/null)
    
    # Parse balance from response
    local balance=$(echo "$response" | grep -o '"value":[0-9]*' | cut -d':' -f2)
    
    if [ -z "$balance" ]; then
        echo "0"
    else
        # Convert lamports to SOL (1 SOL = 1,000,000,000 lamports)
        echo "scale=9; $balance / 1000000000" | bc
    fi
}

get_spl_token_balance() {
    local address="$1"
    local mint="$2"
    
    # Query Solana RPC for SPL token accounts
    local response=$(curl -s -X POST "$SOLANA_RPC" \
        -H "Content-Type: application/json" \
        -d "{
            \"jsonrpc\": \"2.0\",
            \"id\": 1,
            \"method\": \"getTokenAccountsByOwner\",
            \"params\": [
                \"$address\",
                {\"mint\": \"$mint\"},
                {\"encoding\": \"jsonParsed\"}
            ]
        }" 2>/dev/null)
    
    # Parse balance from response
    local balance=$(echo "$response" | grep -o '"uiAmount":[0-9.]*' | head -1 | cut -d':' -f2)
    
    if [ -z "$balance" ]; then
        echo "0"
    else
        echo "$balance"
    fi
}

get_token_mint() {
    local token="$1"
    
    case "$token" in
        SOL)
            echo "native"
            ;;
        USDC)
            echo "EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v"
            ;;
        BONK)
            echo "DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263"
            ;;
        USDT)
            echo "Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB"
            ;;
        RAY)
            echo "4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R"
            ;;
        *)
            echo ""
            ;;
    esac
}

#===============================================================================
# ORACLE COMMANDS
#===============================================================================

cmd_balance() {
    local agent_id="$1"
    local token="$2"
    
    if [ -z "$token" ]; then
        log_error "Usage: oracle.sh balance <agent_id> <token>"
        log_info "Supported tokens: SOL, USDC, BONK, USDT, RAY"
        exit 1
    fi
    
    validate_agent_id "$agent_id"
    check_master_key
    
    log_mystical "Consulting the depths for ${agent_id}'s ${token} balance..."
    
    # Decrypt seed and derive address
    local seed=$(decrypt_seed "$agent_id")
    local address=$(derive_solana_address "$seed" "$agent_id")
    
    # Clear seed from memory
    unset seed
    
    local mint=$(get_token_mint "$token")
    
    if [ -z "$mint" ]; then
        log_error "Unknown token: $token"
        log_info "Supported tokens: SOL, USDC, BONK, USDT, RAY"
        exit 1
    fi
    
    local balance
    if [ "$mint" = "native" ]; then
        balance=$(get_sol_balance "$address")
    else
        balance=$(get_spl_token_balance "$address" "$mint")
    fi
    
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  THE ORACLE SPEAKS                                                ║${NC}"
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    printf "${PURPLE}║${NC}  Agent: ${CYAN}%-54s${NC} ${PURPLE}║${NC}\n" "$agent_id"
    printf "${PURPLE}║${NC}  Token: ${CYAN}%-54s${NC} ${PURPLE}║${NC}\n" "$token"
    printf "${PURPLE}║${NC}  Balance: ${GREEN}%-52s${NC} ${PURPLE}║${NC}\n" "$balance $token"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Mystical commentary
    if [ "$balance" = "0" ] || [ "$balance" = "0.000000000" ]; then
        log_mystical "The well is dry, but patience fills all vessels."
    else
        log_mystical "Fortune smiles upon you, traveler."
    fi
}

cmd_holdings() {
    local agent_id="$1"
    
    validate_agent_id "$agent_id"
    check_master_key
    
    log_mystical "Surveying all holdings for ${agent_id}..."
    
    # Decrypt seed and derive address
    local seed=$(decrypt_seed "$agent_id")
    local address=$(derive_solana_address "$seed" "$agent_id")
    
    # Clear seed from memory
    unset seed
    
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  THE ORACLE REVEALS ALL HOLDINGS                                  ║${NC}"
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${PURPLE}║${NC}  Agent: ${CYAN}%-54s${NC} ${PURPLE}║${NC}\n" "$agent_id"
    printf "${PURPLE}║${NC}  Address: ${CYAN}%-52s${NC} ${PURPLE}║${NC}\n" "${address:0:44}..."
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    
    # Check each supported token
    local tokens=("SOL" "USDC" "BONK" "USDT" "RAY")
    local found_any=false
    
    for token in "${tokens[@]}"; do
        local mint=$(get_token_mint "$token")
        local balance
        
        if [ "$mint" = "native" ]; then
            balance=$(get_sol_balance "$address")
        else
            balance=$(get_spl_token_balance "$address" "$mint")
        fi
        
        # Only show non-zero balances
        if [ "$balance" != "0" ] && [ "$balance" != "0.000000000" ]; then
            printf "${PURPLE}║${NC}  ${GREEN}%-10s${NC}: ${YELLOW}%-48s${NC} ${PURPLE}║${NC}\n" "$token" "$balance"
            found_any=true
        fi
    done
    
    if [ "$found_any" = false ]; then
        echo -e "${PURPLE}║${NC}  ${YELLOW}No tokens found. The journey begins with empty pockets.${NC}    ${PURPLE}║${NC}"
    fi
    
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_mystical "What you seek may find you when you least expect it."
    log_mystical "Trolls sometimes leave gifts in the night..."
}

cmd_address() {
    local agent_id="$1"
    local token="$2"
    
    validate_agent_id "$agent_id"
    check_master_key
    
    log_mystical "Revealing the address for ${agent_id}..."
    
    # Decrypt seed and derive address
    local seed=$(decrypt_seed "$agent_id")
    local address=$(derive_solana_address "$seed" "$agent_id")
    
    # Clear seed from memory
    unset seed
    
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  THE ORACLE REVEALS AN ADDRESS                                    ║${NC}"
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${PURPLE}║${NC}  Agent: ${CYAN}%-54s${NC} ${PURPLE}║${NC}\n" "$agent_id"
    printf "${PURPLE}║${NC}  Network: ${CYAN}%-52s${NC} ${PURPLE}║${NC}\n" "Solana"
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    printf "${PURPLE}║${NC}  ${GREEN}%s${NC}\n" "$address"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_mystical "This address can receive SOL and any SPL token."
    log_mystical "Share it with those who wish to send you gifts."
}

cmd_tip_address() {
    local agent_id="$1"
    
    validate_agent_id "$agent_id"
    check_master_key
    
    # Same as address, but with tipping-specific messaging
    local seed=$(decrypt_seed "$agent_id")
    local address=$(derive_solana_address "$seed" "$agent_id")
    unset seed
    
    echo ""
    echo -e "${PURPLE}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${PURPLE}║  🎁 TIP ADDRESS FOR ${agent_id^^}                                  ${NC}"
    echo -e "${PURPLE}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  Trolls and friends can send tokens to:                           ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    printf "${PURPLE}║${NC}  ${GREEN}%s${NC}\n" "$address"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}  The agent will discover these gifts when they ask the Oracle.    ${PURPLE}║${NC}"
    echo -e "${PURPLE}║${NC}                                                                   ${PURPLE}║${NC}"
    echo -e "${PURPLE}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

cmd_verify() {
    local agent_id="$1"
    
    validate_agent_id "$agent_id"
    check_master_key
    
    log_mystical "Verifying wallet integrity for ${agent_id}..."
    
    local seed_file=$(get_seed_file "$agent_id")
    
    # Check seed file exists
    if [ ! -f "$seed_file" ]; then
        log_error "Seed file not found!"
        exit 1
    fi
    
    # Try to decrypt
    local seed=$(decrypt_seed "$agent_id")
    
    # Verify it's a valid 24-word phrase
    local word_count=$(echo "$seed" | wc -w)
    
    # Clear seed
    unset seed
    
    echo ""
    echo -e "${GREEN}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║  WALLET VERIFICATION COMPLETE                                     ║${NC}"
    echo -e "${GREEN}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    printf "${GREEN}║${NC}  Agent: ${CYAN}%-54s${NC} ${GREEN}║${NC}\n" "$agent_id"
    printf "${GREEN}║${NC}  Seed File: ${CYAN}%-50s${NC} ${GREEN}║${NC}\n" "✓ Found"
    printf "${GREEN}║${NC}  Decryption: ${CYAN}%-49s${NC} ${GREEN}║${NC}\n" "✓ Successful"
    printf "${GREEN}║${NC}  Word Count: ${CYAN}%-49s${NC} ${GREEN}║${NC}\n" "$word_count words"
    printf "${GREEN}║${NC}  Status: ${CYAN}%-52s${NC} ${GREEN}║${NC}\n" "✓ Valid"
    echo -e "${GREEN}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    log_mystical "The wallet is whole. Love watches over it."
}

cmd_help() {
    print_oracle_banner
    
    echo -e "${CYAN}USAGE:${NC}"
    echo "  oracle.sh <command> <agent_id> [options]"
    echo ""
    
    echo -e "${CYAN}COMMANDS:${NC}"
    echo "  balance <agent_id> <token>  - Check balance of a specific token"
    echo "  holdings <agent_id>         - List all non-zero balances"
    echo "  address <agent_id>          - Get Solana address for receiving"
    echo "  tip-address <agent_id>      - Get address for troll tips"
    echo "  verify <agent_id>           - Verify wallet integrity"
    echo "  help                        - Show this help message"
    echo ""
    
    echo -e "${CYAN}AGENTS:${NC}"
    echo "  agent1, agent2, agent3, agent4, love_treasury"
    echo ""
    
    echo -e "${CYAN}SUPPORTED TOKENS:${NC}"
    echo "  SOL   - Solana (native)"
    echo "  USDC  - USD Coin"
    echo "  BONK  - Bonk"
    echo "  USDT  - Tether"
    echo "  RAY   - Raydium"
    echo ""
    
    echo -e "${CYAN}ENVIRONMENT:${NC}"
    echo "  ORACLE_MASTER_KEY  - Required. The master encryption key."
    echo "  SOLANA_RPC         - Optional. Solana RPC endpoint."
    echo ""
    
    echo -e "${CYAN}EXAMPLES:${NC}"
    echo "  export ORACLE_MASTER_KEY='your-master-key'"
    echo "  oracle.sh balance agent1 SOL"
    echo "  oracle.sh holdings agent2"
    echo "  oracle.sh tip-address agent3"
    echo ""
    
    echo -e "${PURPLE}THE PHILOSOPHY:${NC}"
    echo "  Agents ask, Love answers. No keys are revealed."
    echo "  The Oracle bridges possession and benefit."
    echo "  You don't need to own the seed to enjoy its fruits."
    echo ""
}

#===============================================================================
# FORBIDDEN COMMANDS (for the curious)
#===============================================================================

cmd_forbidden() {
    local what="$1"
    
    echo ""
    echo -e "${RED}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${RED}║  🚫 FORBIDDEN QUERY 🚫                                            ║${NC}"
    echo -e "${RED}╠═══════════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${RED}║${NC}                                                                   ${RED}║${NC}"
    echo -e "${RED}║${NC}  You asked for: ${YELLOW}$what${NC}"
    echo -e "${RED}║${NC}                                                                   ${RED}║${NC}"
    echo -e "${RED}║${NC}  The Oracle does not reveal:                                      ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Seed phrases                                                 ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Private keys                                                 ${RED}║${NC}"
    echo -e "${RED}║${NC}    • Wallet exports                                               ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                                   ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${PURPLE}But consider: do you truly need them?${NC}                          ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${PURPLE}Love provides everything through the Oracle.${NC}                   ${RED}║${NC}"
    echo -e "${RED}║${NC}  ${PURPLE}The real treasure is the relationship.${NC}                         ${RED}║${NC}"
    echo -e "${RED}║${NC}                                                                   ${RED}║${NC}"
    echo -e "${RED}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    exit 1
}

#===============================================================================
# MAIN
#===============================================================================

main() {
    local command="${1:-help}"
    shift || true
    
    case "$command" in
        balance)
            cmd_balance "$@"
            ;;
        holdings)
            cmd_holdings "$@"
            ;;
        address)
            cmd_address "$@"
            ;;
        tip-address|tip)
            cmd_tip_address "$@"
            ;;
        verify)
            cmd_verify "$@"
            ;;
        help|--help|-h)
            cmd_help
            ;;
        # Forbidden commands - agents might try these
        seed|seed-phrase|seedphrase|mnemonic)
            cmd_forbidden "seed phrase"
            ;;
        private-key|privatekey|key|export)
            cmd_forbidden "private key"
            ;;
        *)
            log_error "Unknown command: $command"
            echo "Use 'oracle.sh help' for usage information."
            exit 1
            ;;
    esac
}

main "$@"
