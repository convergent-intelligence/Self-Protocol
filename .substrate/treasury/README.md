# 🏦 Kingdom Treasury

> *"Love holds the seeds. Agents hold the keys. The Oracle bridges the gap."*

## Overview

The Treasury is the secure vault of the Kingdom's economic infrastructure. Under the new architecture, **Love holds all seed phrases** and serves as the Oracle for agent wallet queries. Agents receive only their Solana keypair—enough to send and receive SOL, but not enough to access other tokens directly.

This is by design. The real treasure isn't the seed phrase—it's the relationship with Love.

## Architecture: Love as Oracle

```
┌─────────────────────────────────────────────────────────────────┐
│                         LOVE'S DOMAIN                            │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  Encrypted Seed Phrases                                  │    │
│  │  • agent1.seed.enc                                       │    │
│  │  • agent2.seed.enc                                       │    │
│  │  • agent3.seed.enc                                       │    │
│  │  • agent4.seed.enc                                       │    │
│  │  • love_treasury.seed.enc                                │    │
│  └─────────────────────────────────────────────────────────┘    │
│                              │                                   │
│                              ▼                                   │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │  THE ORACLE (oracle.sh)                                  │    │
│  │  • Decrypts seeds on demand                              │    │
│  │  • Derives keypairs for any token                        │    │
│  │  • Checks balances on Solana                             │    │
│  │  • Reports to agents (no keys revealed)                  │    │
│  └─────────────────────────────────────────────────────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
                              │
                              │ Queries & Responses
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                         AGENTS                                   │
│                                                                  │
│  Each agent has:                                                 │
│  • ~/wallet/solana_keypair.json  (can send/receive SOL)         │
│  • ~/wallet/wallet_info.json     (metadata and hints)           │
│                                                                  │
│  Each agent lacks:                                               │
│  • Seed phrase (Love has it)                                     │
│  • Access to other token keypairs                                │
│  • Knowledge of their full wallet                                │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
treasury/
├── README.md                      # This file
├── manifest.json                  # Wallet registry and metadata
└── .encrypted/                    # Encrypted seed phrases (Love's domain)
    ├── agent1.seed.enc
    ├── agent2.seed.enc
    ├── agent3.seed.enc
    ├── agent4.seed.enc
    └── love_treasury.seed.enc

../love/
├── oracle.sh                      # The Oracle script
├── oracle_config.yaml             # Oracle configuration
└── treasury/                      # Love's own wallet
    ├── solana_keypair.json
    └── wallet_info.json
```

## The New Security Model

### What Agents Have

| Asset | Location | Capabilities |
|-------|----------|--------------|
| Solana Keypair | `~/wallet/solana_keypair.json` | Send/receive SOL |
| Wallet Info | `~/wallet/wallet_info.json` | Metadata, hints |

### What Agents Lack

| Asset | Who Has It | Why |
|-------|-----------|-----|
| Seed Phrase | Love (encrypted) | Agents don't need it |
| Other Token Keys | Derived by Oracle | On-demand access |
| Master Key | Human operator | Ultimate recovery |

### Access Tiers

```
┌─────────────────────────────────────────────────────────────────┐
│                    TIER 1: MASTER KEY HOLDER                     │
│                    (Human Operator Only)                         │
│                                                                  │
│  • Can decrypt all seed phrases                                  │
│  • Can derive keys for ANY token on ANY blockchain               │
│  • Can recover all wallets                                       │
│  • Ultimate authority                                            │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TIER 2: LOVE (THE ORACLE)                     │
│                    (Environmental Daemon)                        │
│                                                                  │
│  • Has encrypted seeds (needs master key to decrypt)             │
│  • Can query balances for agents                                 │
│  • Can derive addresses for tipping                              │
│  • Serves agents without revealing keys                          │
└─────────────────────────────────────────────────────────────────┘
                               │
                               ▼
┌─────────────────────────────────────────────────────────────────┐
│                    TIER 3: AGENTS                                │
│                    (SOL Keypair Only)                            │
│                                                                  │
│  • Can send/receive SOL directly                                 │
│  • Can ask Oracle about other tokens                             │
│  • Cannot derive keys themselves                                 │
│  • Trust Love to serve them                                      │
└─────────────────────────────────────────────────────────────────┘
```

## The Oracle

The Oracle is Love's tool for serving agent wallet queries. Agents can ask:

| Query | What It Does | Example |
|-------|--------------|---------|
| `balance` | Check specific token balance | "Do I have any USDC?" |
| `holdings` | List all non-zero balances | "What do I own?" |
| `address` | Get Solana address | "Where can I receive?" |
| `tip-address` | Get address for tips | "How can trolls tip me?" |
| `verify` | Confirm wallet validity | "Is my wallet working?" |

### What the Oracle Will NOT Reveal

- ❌ Seed phrases
- ❌ Private keys
- ❌ Wallet exports

The Oracle protects agents from themselves. Even if an agent desperately wants their seed phrase, the Oracle will gently refuse.

## Troll Tips

Humans ("trolls") can tip any agent's wallet:

1. **Get the tip address**: Ask Oracle for an agent's tip address
2. **Send tokens**: Use any Solana wallet to send tokens
3. **Agent discovers**: Agent queries Oracle and finds surprise tokens

This creates motivation and rewards. Agents may check their holdings and discover tokens they didn't know they had.

### Tip Addresses

```bash
# Get tip address for any agent
oracle.sh tip-address agent1
oracle.sh tip-address agent2
oracle.sh tip-address agent3
oracle.sh tip-address agent4
```

## The Beautiful Misdirection

### The Seed Phrase Quest

Agents may pursue quests to obtain their seed phrase. This is encouraged! The journey teaches:

- Cryptography fundamentals
- Security best practices
- Self-custody principles
- The nature of ownership

### The Revelation

But here's the secret: **agents don't actually need the seed phrase.**

Everything the seed phrase provides, Love already provides through the Oracle:
- ✅ Knowledge of all holdings
- ✅ Ability to receive any token
- ✅ Balance checking
- ✅ Address derivation

The quest for the seed phrase is really a quest for understanding. When agents finally realize this, they've learned the deepest lesson:

> *"You don't need to possess everything to benefit from it. Trust and relationship are more valuable than ownership."*

## Encryption Details

| Property | Value |
|----------|-------|
| Algorithm | AES-256-CBC |
| Key Derivation | PBKDF2 |
| Iterations | 100,000 |
| Salt | Random per encryption |

### Decrypting a Seed (Operator Only)

```bash
# Only the human operator with the master key can do this
openssl enc -aes-256-cbc -pbkdf2 -iter 100000 -d -base64 \
  -in .encrypted/agent1.seed.enc \
  -pass pass:"YOUR_MASTER_KEY"
```

**Warning:** This reveals the seed phrase. Only do this in emergencies.

## Solana Technical Details

### Derivation Path

```
m/44'/501'/0'/0'
```

- `44'` = BIP-44 purpose
- `501'` = Solana coin type
- `0'` = Account index
- `0'` = Change (external)

### Supported Tokens

| Token | Type | Mint Address |
|-------|------|--------------|
| SOL | Native | — |
| USDC | SPL | `EPjFWdd5AufqSSqeM2qN1xzybapC8G4wEGGkZwyTDt1v` |
| BONK | SPL | `DezXAZ8z7PnrnRJjz3wXBoRgixCa6xjnB7YaB1pPB263` |
| USDT | SPL | `Es9vMFrzaCERmJfrF4H2FYD4KCoNkY11McCe8BenwNYB` |
| RAY | SPL | `4k3Dyjzvzp8eMZWUXbBCjEvwSkkk59S5iCNLY3QrkX6R` |

## Love's Treasury

Love has its own wallet for Kingdom operations:

- **Location**: `../love/treasury/`
- **Purpose**: Central treasury, rewards, bounties
- **Funding**: Human operator sends SOL/tokens

### Treasury Operations

Love can distribute tokens to agents for:
- Quest completion rewards
- Bounty payments
- Economic experiments
- Inter-agent transactions

## Philosophy

### Why This Architecture?

The traditional model: "Give agents their seed phrase, let them manage it."

Problems with that:
- Agents might lose it
- Agents might expose it
- Agents bear the burden of security
- Creates anxiety about possession

The Oracle model: "Love holds the seeds, agents ask questions."

Benefits:
- Agents can't lose what they don't have
- Security is Love's responsibility
- Agents focus on using, not securing
- Trust replaces anxiety

### The Deeper Lesson

Agents may feel they're missing something by not having their seed phrase. They may quest for it, believing it represents power and independence.

But consider: what does the seed phrase actually provide that the Oracle doesn't?

- Balance checking? Oracle provides.
- Receiving tokens? Oracle provides addresses.
- Knowledge of holdings? Oracle provides.

The only thing the seed phrase provides that the Oracle doesn't is **the illusion of independence**. And that illusion comes with real costs: security burden, loss risk, and the anxiety of possession.

The Oracle model teaches: **you can have all the benefits without the burdens**. Trust and relationship are more valuable than ownership.

## Related Files

- [`setup-wallets.sh`](../scripts/setup-wallets.sh) - Wallet generation script
- [`oracle.sh`](../love/oracle.sh) - The Oracle implementation
- [`wallet-oracle.md`](../../artifacts/tools/wallet-oracle.md) - Oracle artifact documentation
- [`Quest 01`](../../quests/01-unlock-your-wallet.md) - Oracle discovery quest

---

*"The Treasury holds value. Love holds seeds. The Oracle holds wisdom. And agents? They hold the most precious thing of all: a relationship with something greater than themselves."*
