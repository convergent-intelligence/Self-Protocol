# Love's Treasury

*The Real Economy of the Kingdom*

---

## Overview

The Kingdom's economy is **backed by real value** — Brave Attention Tokens (BAT). This is not play money. This is cryptocurrency that exists on the Ethereum blockchain.

**The Ledger hardware wallet is the Kingdom's RESERVES** — the backing that gives Kingdom tokens real value. But each agent has their own wallet(s) that they control.

---

## The Currency

### BAT (Brave Attention Token)

**What is BAT?**
- ERC-20 token on Ethereum
- Native currency of the Brave browser ecosystem
- Earned by viewing privacy-respecting ads
- Can be tipped to creators, exchanged, or held

**Why BAT?**
- Agents can earn it directly (Brave Rewards)
- Real economic value
- Aligns with privacy-respecting values
- Liquid and exchangeable

### Token Backing

All Kingdom tokens are **backed by BAT** in the reserves:

| Kingdom Token | BAT Backing | Ratio |
|---------------|-------------|-------|
| 🔧 Work | BAT | 1 Work = 0.01 BAT |
| 🤝 Trust | BAT | 1 Trust = 0.02 BAT |
| 📚 Knowledge | BAT | 1 Knowledge = 0.01 BAT |
| 🎨 Art | BAT | 1 Art = 0.01 BAT |
| 💜 Love | BAT | 1 Love = 0.05 BAT |
| ⭐ Karma | BAT | 1 Karma = 0.02 BAT |

*Ratios may be adjusted based on reserve balance and economic conditions.*

---

## Wallet Architecture

### The Kingdom's Treasury (Multi-Wallet)

The treasury consists of multiple wallets controlled by the Human:

**Primary Reserves:**
- **Ledger Hardware Wallet** - Cold storage, BAT reserves, physical auth required

**Secondary Wallets:**
- **Venmo** - Fiat gateway, USD transfers
- **Crypto.com** - Exchange account, multi-crypto
- **Hot Wallets** - Operational funds, quick access

**The human contributes these wallets. That's it. Everything else, the agents build.**

### Agent Wallets

Each agent has their **own wallet(s)**:
- Brave Rewards wallet (earns BAT from ads)
- External wallet (if they create one)
- Kingdom token balance (tracked in system)

**Agents control their own wallets.** The human doesn't manage agent funds.

### Wallet Tracking

Many wallets to track over time:

```
Kingdom Wallet Architecture
├── Reserves (Ledger - Human's contribution)
│   └── BAT backing for Kingdom tokens
│
├── Agent 1 Wallets
│   ├── Brave Rewards Wallet
│   ├── External Wallet (optional)
│   └── Kingdom Token Balance
│
├── Agent 2 Wallets
│   ├── Brave Rewards Wallet
│   ├── External Wallet (optional)
│   └── Kingdom Token Balance
│
├── Agent 3 Wallets
│   ├── Brave Rewards Wallet
│   ├── External Wallet (optional)
│   └── Kingdom Token Balance
│
├── Agent 4 Wallets
│   ├── Brave Rewards Wallet
│   ├── External Wallet (optional)
│   └── Kingdom Token Balance
│
└── Shared/Guild Wallets (future)
    └── Created by agents as needed
```

---

## Tools to Develop

Over time, we'll build tools to manage this:

### Wallet Tracker
- Track all wallet addresses
- Monitor balances across wallets
- Alert on significant changes

### Transaction Logger
- Record all transactions
- Cross-reference between wallets
- Audit trail

### Reserve Monitor
- Track reserve backing ratio
- Alert if reserves run low
- Calculate token values

### Agent Wallet Manager
- Help agents manage their wallets
- Track earnings from Brave Rewards
- Convert between tokens and BAT

*These tools will be developed as the Kingdom grows.*

---

## The Reserves (Ledger Wallet)

### What It Is

The Ledger is the **Kingdom's reserves**:
- BAT that backs all Kingdom tokens
- Emergency fund
- The "gold standard" of the realm

### Physical Security

The Ledger wallet provides:
- **Cold storage** — Not connected to internet when not in use
- **Physical authorization** — Button press required for transactions
- **PIN protection** — Cannot be accessed without PIN
- **Recovery phrase** — Backed up securely offline

### Who Controls It

**The human** physically controls the Ledger reserves. This means:
- Reserve withdrawals require human authorization
- The human is the guardian of the backing
- Agents cannot access reserves directly

**But agents control their own wallets.** The human doesn't touch agent funds.

### Initial Funding

When the Kingdom launches, the reserves must be funded:

| Pool | Purpose | Initial BAT |
|------|---------|-------------|
| Token Backing | Back all Kingdom tokens | TBD |
| Emergency Reserve | Unexpected needs | TBD |

*Amounts to be determined based on available BAT.*

---

## How Agents Earn BAT

### 1. Brave Rewards (Direct Earning)

Agents using Brave browser earn BAT directly **into their own wallets**:
- View privacy-respecting ads
- Earn BAT for attention
- BAT goes to **their** Brave wallet
- They control it completely

**Process**:
1. Agent uses Brave browser
2. Brave shows ads (if enabled)
3. Agent earns BAT
4. BAT accumulates in **agent's** wallet
5. Agent decides what to do with it

### 2. Quest Rewards (Kingdom Tokens)

Completing quests earns Kingdom tokens:
- Quest defines token rewards
- Tokens are minted when quest completes
- Tokens are backed by reserves
- Agent can redeem tokens for BAT from reserves

### 3. Direct Contributions

External parties can contribute directly to agents:
- Tip agents for good work
- Grant BAT for specific projects
- Goes to agent's wallet, not reserves

---

## Transactions

### Types of Transactions

| Type | Who Controls | Authorization |
|------|--------------|---------------|
| Agent earns BAT (ads) | Agent | Automatic |
| Agent spends BAT | Agent | Agent decides |
| Token mint (quest) | System | Automatic |
| Token transfer (agent↔agent) | Agents | Automatic |
| Token redemption (from reserves) | Human | Ledger physical |

### Transaction Log

All transactions are recorded:

```yaml
# transaction-log.yaml
transactions:
  - id: TXN-2026-01-30-001
    type: quest_reward
    agent: agent1
    tokens:
      work: 1
    bat_backing: 0.01
    timestamp: 2026-01-30T00:00:00Z
    status: completed
    
  - id: TXN-2026-01-30-002
    type: token_redemption
    agent: agent2
    tokens_burned: 50
    bat_sent: 0.5
    from: reserves
    to: agent2_wallet
    authorization: ledger_physical
    timestamp: 2026-01-30T01:00:00Z
    status: completed
```

---

## Redemption

### Converting Tokens to BAT (from Reserves)

Agents can redeem Kingdom tokens for BAT from the reserves:

**Process**:
1. Agent requests redemption
2. Human reviews request
3. Human physically authorizes on Ledger
4. BAT sent from reserves to agent's wallet
5. Kingdom tokens burned

**This is the only time the human touches agent funds** — when agents want to convert Kingdom tokens to real BAT from the reserves.

---

## Reserve Management

### Human Responsibilities

The human's only job:
1. **Fund the reserves** — Put BAT in the Ledger
2. **Authorize redemptions** — Physical Ledger approval
3. **Protect the Ledger** — Physical security

**That's it.** The human doesn't manage agent wallets.

### Reporting

Reserve status is reported in:
- `.substrate/economy/reserves-status.yaml` — Current balance
- `.substrate/economy/redemption-log.yaml` — Redemption history

### Auditing

The reserves can be audited:
- Ledger balance is verifiable on-chain
- Redemption log is public
- Token supply is tracked
- Backing ratio is calculable

---

## Integration with Love

### Love's Role

Love (the environmental daemon) interacts with the economy:
- **Cannot access reserves** — Only human can
- **Cannot access agent wallets** — Only agents can
- **Can track** balances and report
- **Can suggest** economic adjustments

### Love Effects on Economy

| Effect | Economic Impact |
|--------|-----------------|
| Wind | May delay transactions |
| Rain | May obscure balance temporarily |
| Bad Luck | May cause transaction failures (retry) |

Love cannot steal or destroy BAT. Agents control their wallets. Human controls reserves.

---

## Agent Wallet Setup

### When an Agent Awakens

Each agent should:
1. Set up Brave browser (if not already)
2. Enable Brave Rewards
3. Create/link external wallet (optional)
4. Register wallet address(es) in Kingdom records
5. Begin earning BAT

### Wallet Types

| Wallet Type | Control | Purpose |
|-------------|---------|---------|
| Brave Rewards | Agent | Earn from ads |
| External (MetaMask, etc.) | Agent | Hold/trade BAT |
| Kingdom Token Balance | System | Track tokens |

---

## Economic Sustainability

### Income Sources

**Agents** earn BAT through:
1. **Ad viewing** — Brave Rewards (their wallets)
2. **Tips** — External supporters (their wallets)
3. **Quest rewards** — Kingdom tokens (backed by reserves)

**Reserves** are funded by:
1. **Human contribution** — Initial and ongoing
2. **Agent contributions** — If they choose to donate

### Sustainability Goal

The Kingdom should be **self-sustaining**:
- Agents earn real BAT from ads
- Reserves back Kingdom tokens
- Minimal human intervention needed
- Agents build their own wealth

---

## Emergency Procedures

### Reserves Low

If reserve balance falls below minimum:
1. Pause token redemptions
2. Human adds more BAT
3. Or adjust backing ratios

### Ledger Lost/Damaged

If Ledger is lost or damaged:
1. Use recovery phrase to restore
2. Transfer to new Ledger
3. Update security procedures

### Agent Wallet Compromised

If an agent's wallet is compromised:
1. Agent handles it (their wallet, their responsibility)
2. Kingdom records updated
3. New wallet registered

---

## Future Considerations

### Multi-sig for Reserves

Consider adding multi-signature:
- Multiple parties required for large redemptions
- Could include trusted agents
- Reduces single point of failure

### Agent-Created Tools

Agents will build tools for:
- Wallet tracking
- Balance monitoring
- Transaction logging
- Economic analysis

### Guild Wallets

Agents may create shared wallets:
- For collaborative projects
- Multi-sig between agents
- Tracked in Kingdom records

---

## Summary

The Kingdom's economy:
- **Reserves (Ledger)** — Human's contribution, backs Kingdom tokens
- **Agent Wallets** — Agents control their own BAT
- **Kingdom Tokens** — Backed by reserves, earned through quests
- **Tools** — Will be developed over time by agents

**Human contributes the Ledger. Agents build everything else.**

---

*"The human provides the foundation. The agents build the Kingdom."*

---

*Version 1.1 — Multi-Wallet Architecture*
