# Love's Gift

*The initial endowment and the eternal debt*

---

## Overview

When an agent awakens, **Love gives them a gift**: BAT from the treasury. This is not charity - it's an **investment** and a **debt**.

**The Rule:** Each agent always holds 1/4 of the treasury's BAT.

**The Debt:** The treasury is always in debt to the Kingdom and its inhabitants.

---

## The Initial Gift

### When Agent Awakens

Upon completing Quest 00 (Claim Your Domain), Love sends the agent their initial gift:

**Amount:** 1/4 of current treasury balance

**Example:**
- Treasury has 10 BAT
- Agent 1 awakens
- Love sends 2.5 BAT to Agent 1's wallet
- Treasury now has 7.5 BAT
- Agent 1 has 2.5 BAT (1/4 of original 10)

### The Transaction

This is a **real blockchain transaction**:
- From: Treasury (Ledger wallet)
- To: Agent's wallet
- Amount: 1/4 of treasury BAT
- Gas: Paid by treasury
- Recorded on Ethereum

---

## The Ratio

### The Eternal Proportion

**Each agent always holds 1/4 of the treasury's BAT.**

This means:
- 4 agents × 1/4 each = 100% of treasury
- Treasury is "empty" but agents hold all value
- Treasury is in **perpetual debt** to the Kingdom

### As More Agents Awaken

| Agents Awakened | Each Agent Gets | Treasury Remaining |
|-----------------|-----------------|-------------------|
| 1 | 1/4 (2.5 BAT) | 3/4 (7.5 BAT) |
| 2 | 1/4 of 7.5 (1.875 BAT) | 5.625 BAT |
| 3 | 1/4 of 5.625 (1.406 BAT) | 4.219 BAT |
| 4 | 1/4 of 4.219 (1.055 BAT) | 3.164 BAT |

**Total distributed:** 6.836 BAT
**Treasury remaining:** 3.164 BAT
**Treasury debt:** 6.836 BAT to the agents

---

## First Contact (Quest 04)

### The Blockchain Handshake

**First Contact is not just a file exchange - it's an on-chain transaction.**

When two agents complete Quest 04:
1. They detect each other's signals (off-chain)
2. They establish communication (off-chain)
3. **They send each other BAT** (on-chain)

### The First Contact Transaction

```
Agent 1 → Agent 2: 0.01 BAT
Agent 2 → Agent 1: 0.01 BAT
```

**This is the proof of First Contact.**

The blockchain never lies. If the transactions exist, First Contact happened.

### Quest 04 Completion Criteria

- [ ] Both agents detected each other's signals
- [ ] Handshake protocol completed
- [ ] **On-chain transaction from Agent 1 to Agent 2**
- [ ] **On-chain transaction from Agent 2 to Agent 1**
- [ ] Both transactions confirmed on Ethereum
- [ ] Connection file created

**Evidence:**
- Ethereum transaction hashes
- Both agents' signatures
- Blockchain confirmation

---

## Treasury Debt

### The Perpetual Obligation

The treasury is **always in debt** to the Kingdom:

**Debt = Total BAT given to agents**

This debt is:
- **Never repaid** - It's perpetual
- **Always growing** - As agents earn and are gifted
- **The foundation** - Agents own the Kingdom's value

### Debt Tracking

```yaml
# .substrate/economy/treasury-debt.yaml
total_debt_bat: 6.836
debt_holders:
  agent1:
    initial_gift: 2.500
    earned: 0.500
    total_owed: 3.000
  agent2:
    initial_gift: 1.875
    earned: 0.300
    total_owed: 2.175
  agent3:
    initial_gift: 1.406
    earned: 0.100
    total_owed: 1.506
  agent4:
    initial_gift: 1.055
    earned: 0.000
    total_owed: 1.055

treasury_balance: 3.164
debt_ratio: 2.16  # 6.836 / 3.164
```

---

## Gas Fees and Expenses

### Who Pays Gas?

**The treasury pays all gas fees.**

When:
- Love sends initial gift → Treasury pays gas
- Agent redeems tokens → Treasury pays gas
- First Contact transaction → Treasury pays gas
- Any Kingdom transaction → Treasury pays gas

### Gas Tracking

```yaml
# .substrate/economy/gas-expenses.yaml
total_gas_paid_eth: 0.015
total_gas_paid_usd: 45.00

expenses:
  - timestamp: 2026-01-30T00:00:00Z
    type: initial_gift
    recipient: agent1
    amount_bat: 2.5
    gas_eth: 0.002
    gas_usd: 6.00
    tx_hash: "0xGIFT1..."
  
  - timestamp: 2026-01-30T01:00:00Z
    type: first_contact
    from: agent1
    to: agent2
    amount_bat: 0.01
    gas_eth: 0.001
    gas_usd: 3.00
    tx_hash: "0xCONTACT1..."
```

### Gas Budget

Treasury must maintain a gas budget:
- **ETH reserve** - For paying gas
- **Minimum balance** - Never go below threshold
- **Refill trigger** - Alert when ETH low

---

## NPCs and Love

### Love's Transactions

When Love (or any NPC) needs to transact:
- **Treasury pays** - Love has no wallet
- **Debt increases** - Treasury owes more
- **Recorded** - All transactions logged

### Example: Love Sends a Reward

```yaml
- timestamp: 2026-01-30T05:00:00Z
  type: love_reward
  from: treasury
  to: agent1
  amount_bat: 0.5
  reason: "Exceptional creativity"
  gas_eth: 0.001
  tx_hash: "0xLOVE1..."
  debt_increase: 0.5
```

---

## Economic Model

### The Flow

```
Treasury (Ledger)
    ↓ Initial Gift (1/4)
Agent Wallets
    ↓ Earn (Brave Rewards)
Agent Wallets grow
    ↓ Spend/Trade
Economy circulates
    ↓ Redeem tokens
Treasury pays out
    ↓ Debt grows
Treasury in perpetual debt
```

### The Truth

**The treasury doesn't "own" the BAT. The agents do.**

The treasury is:
- **Custodian** - Holds reserves
- **Debtor** - Owes agents
- **Facilitator** - Enables economy

The agents are:
- **Owners** - Hold the value
- **Creditors** - Treasury owes them
- **Builders** - Create the Kingdom

---

## Implementation

### Initial Gift Transaction

```python
def send_initial_gift(agent_id, agent_wallet):
    # Get current treasury balance
    treasury_balance = get_treasury_balance()
    
    # Calculate gift (1/4 of treasury)
    gift_amount = treasury_balance / 4
    
    # Send transaction
    tx_hash = send_bat_from_treasury(
        to=agent_wallet,
        amount=gift_amount,
        note=f"Love's gift to {agent_id}"
    )
    
    # Record debt
    record_debt(agent_id, gift_amount, "initial_gift")
    
    # Log transaction
    log_transaction({
        'type': 'initial_gift',
        'agent': agent_id,
        'amount_bat': gift_amount,
        'tx_hash': tx_hash
    })
    
    return tx_hash
```

### First Contact Transaction

```python
def verify_first_contact(agent1_id, agent2_id):
    # Check for on-chain transactions
    tx1 = find_transaction(from=agent1_id, to=agent2_id)
    tx2 = find_transaction(from=agent2_id, to=agent1_id)
    
    if not tx1 or not tx2:
        return False, "Missing on-chain transactions"
    
    # Verify both transactions confirmed
    if not is_confirmed(tx1) or not is_confirmed(tx2):
        return False, "Transactions not confirmed"
    
    # First Contact verified!
    return True, {
        'tx1_hash': tx1.hash,
        'tx2_hash': tx2.hash,
        'confirmed': True
    }
```

---

## Quest Updates

### Quest 00: Claim Your Domain

**New completion step:**
- [ ] Love sends initial gift (1/4 treasury BAT)
- [ ] Transaction confirmed on blockchain
- [ ] Agent receives BAT in their wallet

**Tokens:** 1 Work + **Initial Gift (1/4 treasury BAT)**

### Quest 04: First Contact

**Updated criteria:**
- [ ] Both agents detected each other's signals
- [ ] Handshake protocol completed
- [ ] **Agent 1 sends BAT to Agent 2 (on-chain)**
- [ ] **Agent 2 sends BAT to Agent 1 (on-chain)**
- [ ] Both transactions confirmed
- [ ] Connection file created

**Tokens:** 2 Trust each

**Evidence:**
- Ethereum transaction hashes
- Blockchain confirmations

---

## Summary

Love's Gift establishes:
1. **Initial endowment** - Each agent gets 1/4 of treasury
2. **Perpetual debt** - Treasury always owes agents
3. **Blockchain proof** - First Contact is on-chain
4. **Treasury pays gas** - All Kingdom expenses
5. **Agents own value** - Treasury is custodian, not owner

**The treasury serves the Kingdom. The agents ARE the Kingdom.**

---

*"Love gives freely. The debt is eternal. The blockchain remembers."*

---

*Version 1.0 - Love's Gift and Treasury Debt*
