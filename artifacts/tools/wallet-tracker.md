# Wallet Tracker

*Tracking real money across many wallets*

---

## Overview

The Wallet Tracker is a critical tool for managing the Kingdom's real economy. It:
1. **Registers** all wallet addresses (agents + reserves)
2. **Monitors** balances across wallets
3. **Tracks** transactions and transfers
4. **Reports** on economic health
5. **Alerts** on anomalies

This is about **real BAT on the Ethereum blockchain** - losing track means losing money.

---

## The Challenge

As Opus identified: "There will be many wallets to track."

```
Reserves (Ledger)
├── 1 hardware wallet address

Agent 1
├── Brave Rewards wallet
└── External wallet (optional)

Agent 2
├── Brave Rewards wallet
└── External wallet (optional)

Agent 3
├── Brave Rewards wallet
└── External wallet (optional)

Agent 4
├── Brave Rewards wallet
└── External wallet (optional)

= Minimum 5 wallets, potentially 9+ wallets
```

---

## Wallet Registry

### Location
`.substrate/state/economy/wallets.yaml`

### Registry Format

```yaml
# .substrate/state/economy/wallets.yaml
last_updated: 2026-01-30T12:00:00Z

treasury:
  ledger:
    address: "0xLEDGER..."
    type: ledger_hardware
    purpose: cold_storage_reserves
    controlled_by: human
    registered: 2026-01-30T00:00:00Z
    last_balance_check: 2026-01-30T12:00:00Z
    balance_bat: 10.0
    balance_usd: 2.50
    notes: "Primary reserves, physical auth required"
  
  venmo:
    username: "@username"
    type: fiat_gateway
    purpose: usd_transfers
    controlled_by: human
    registered: 2026-01-30T00:00:00Z
    last_balance_check: 2026-01-30T12:00:00Z
    balance_usd: 100.00
    notes: "Fiat on/off ramp"
  
  crypto_com:
    account_id: "account123"
    type: exchange
    purpose: multi_crypto_trading
    controlled_by: human
    registered: 2026-01-30T00:00:00Z
    last_balance_check: 2026-01-30T12:00:00Z
    balances:
      bat: 5.0
      eth: 0.1
      usdc: 50.0
    notes: "Exchange account for trading"
  
  hot_wallet_1:
    address: "0xHOT1..."
    type: hot_wallet
    purpose: operational_funds
    controlled_by: human
    registered: 2026-01-30T00:00:00Z
    last_balance_check: 2026-01-30T12:00:00Z
    balance_bat: 2.0
    balance_eth: 0.05
    notes: "Quick access for operations"

agents:
  agent1:
    wallets:
      brave_rewards:
        address: "0xAGENT1BRAVE..."
        type: brave_custodial
        purpose: earn_from_ads
        controlled_by: agent1
        registered: 2026-01-30T00:15:00Z
        last_balance_check: 2026-01-30T12:00:00Z
        balance_bat: 0.5
        balance_usd: 0.125
        notes: "Primary earning wallet"
      
      external:
        address: "0xAGENT1EXT..."
        type: metamask
        purpose: holdings
        controlled_by: agent1
        registered: 2026-01-30T00:20:00Z
        last_balance_check: 2026-01-30T12:00:00Z
        balance_bat: 1.2
        balance_usd: 0.30
        notes: "Personal holdings"
  
  agent2:
    wallets:
      brave_rewards:
        address: "0xAGENT2BRAVE..."
        type: brave_custodial
        purpose: earn_from_ads
        controlled_by: agent2
        registered: 2026-01-30T00:25:00Z
        last_balance_check: 2026-01-30T12:00:00Z
        balance_bat: 0.3
        balance_usd: 0.075
        notes: "Primary earning wallet"

# Summary
summary:
  total_wallets: 5
  total_bat: 12.0
  total_usd: 3.00
  last_full_scan: 2026-01-30T12:00:00Z
  health_status: healthy
```

---

## Balance Monitoring

### How to Check Balances

#### Brave Rewards Wallets
- **Method**: Brave browser API or manual check
- **Frequency**: Every 6 hours
- **Accuracy**: Estimated (Brave shows estimates)

#### External Wallets (Ethereum)
- **Method**: Ethereum RPC call or Etherscan API
- **Frequency**: Every hour
- **Accuracy**: Exact (on-chain data)

#### Ledger Wallet
- **Method**: Ledger Live or Ethereum RPC
- **Frequency**: Every hour
- **Accuracy**: Exact (on-chain data)

### Balance Check Script

```bash
#!/bin/bash
# check-balances.sh

# Check Ethereum wallet balance via RPC
check_eth_wallet() {
    local address=$1
    # Use Ethereum RPC to get BAT balance
    # BAT is ERC-20 token at 0x0D8775F648430679A709E98d2b0Cb6250d2887EF
    curl -X POST \
        -H "Content-Type: application/json" \
        --data "{\"jsonrpc\":\"2.0\",\"method\":\"eth_call\",\"params\":[{\"to\":\"0x0D8775F648430679A709E98d2b0Cb6250d2887EF\",\"data\":\"0x70a08231000000000000000000000000${address:2}\"},\"latest\"],\"id\":1}" \
        https://mainnet.infura.io/v3/YOUR_INFURA_KEY
}

# Update wallet registry with new balance
update_balance() {
    local wallet_id=$1
    local balance=$2
    # Update .substrate/state/economy/wallets.yaml
    # (YAML manipulation logic here)
}

# Main loop
for wallet in $(list_all_wallets); do
    balance=$(check_eth_wallet $wallet)
    update_balance $wallet $balance
done
```

---

## Transaction Tracking

### Transaction Log

```yaml
# .substrate/state/economy/wallet-transactions.yaml
transactions:
  - id: WTXN-001
    timestamp: 2026-01-30T01:00:00Z
    type: brave_rewards_payout
    from: brave_network
    to: agent1_brave_rewards
    amount_bat: 0.5
    tx_hash: null  # Brave internal
    status: completed
    notes: "Monthly Brave Rewards payout"
  
  - id: WTXN-002
    timestamp: 2026-01-30T02:00:00Z
    type: wallet_transfer
    from: agent1_brave_rewards
    to: agent1_external
    amount_bat: 0.3
    tx_hash: "0xTRANSACTION_HASH..."
    gas_paid_eth: 0.001
    status: completed
    notes: "Agent1 moving funds to external wallet"
  
  - id: WTXN-003
    timestamp: 2026-01-30T03:00:00Z
    type: token_redemption
    from: reserves_ledger
    to: agent2_external
    amount_bat: 0.1
    tx_hash: "0xREDEMPTION_HASH..."
    gas_paid_eth: 0.0015
    kingdom_tokens_burned: 10
    authorization: ledger_physical
    authorized_by: human
    status: completed
    notes: "Agent2 redeemed 10 Work tokens for BAT"
```

### Transaction Types

| Type | Description | Tracking Method |
|------|-------------|-----------------|
| `brave_rewards_payout` | Brave pays agent | Brave browser notification |
| `wallet_transfer` | Agent moves BAT between wallets | Ethereum tx hash |
| `token_redemption` | Agent redeems Kingdom tokens | Ethereum tx hash + manual log |
| `reserve_deposit` | Human adds to reserves | Ethereum tx hash |
| `external_tip` | Someone tips an agent | Ethereum tx hash |

---

## Reporting

### Daily Report

```yaml
# .substrate/state/economy/reports/2026-01-30-daily.yaml
date: 2026-01-30
report_type: daily

balances:
  reserves:
    bat: 10.0
    usd: 2.50
    change_24h: +0.5
  
  agents:
    total_bat: 2.0
    total_usd: 0.50
    change_24h: +0.3
  
  grand_total:
    bat: 12.0
    usd: 3.00
    change_24h: +0.8

transactions:
  count: 5
  total_volume_bat: 1.2
  types:
    brave_rewards_payout: 2
    wallet_transfer: 2
    token_redemption: 1

health:
  status: healthy
  reserve_backing_ratio: 0.167  # 2.0 / 12.0
  alerts: []
  warnings: []

top_earners:
  - agent: agent1
    earned_bat: 0.5
  - agent: agent2
    earned_bat: 0.3
```

### Alert Conditions

| Condition | Severity | Action |
|-----------|----------|--------|
| Reserve balance < 5 BAT | Critical | Notify human immediately |
| Wallet balance changed unexpectedly | High | Investigate transaction |
| Balance check failed | Medium | Retry, then alert |
| New unknown wallet detected | Low | Log for review |

---

## Dashboard

### Console Dashboard

```
╔══════════════════════════════════════════════════════════════╗
║                    KINGDOM WALLET TRACKER                    ║
║                    2026-01-30 12:00:00 UTC                   ║
╠══════════════════════════════════════════════════════════════╣
║ RESERVES (Ledger)                                            ║
║   Address: 0xRESERVE123...                                   ║
║   Balance: 10.0 BAT ($2.50)                                  ║
║   Status:  ✓ Healthy                                         ║
╠══════════════════════════════════════════════════════════════╣
║ AGENT WALLETS                                                ║
║                                                              ║
║ Agent 1                                                      ║
║   Brave:    0.5 BAT ($0.125)  ✓                             ║
║   External: 1.2 BAT ($0.300)  ✓                             ║
║                                                              ║
║ Agent 2                                                      ║
║   Brave:    0.3 BAT ($0.075)  ✓                             ║
║                                                              ║
║ Agent 3                                                      ║
║   Not yet registered                                         ║
║                                                              ║
║ Agent 4                                                      ║
║   Not yet registered                                         ║
╠══════════════════════════════════════════════════════════════╣
║ SUMMARY                                                      ║
║   Total Wallets: 5                                           ║
║   Total BAT:     12.0 ($3.00)                                ║
║   24h Change:    +0.8 BAT (+7.1%)                            ║
║   Last Scan:     2 minutes ago                               ║
╠══════════════════════════════════════════════════════════════╣
║ RECENT TRANSACTIONS                                          ║
║   [03:00] Token redemption: 0.1 BAT → Agent2                 ║
║   [02:00] Transfer: 0.3 BAT Agent1 Brave → External          ║
║   [01:00] Brave payout: 0.5 BAT → Agent1                     ║
╠══════════════════════════════════════════════════════════════╣
║ ALERTS                                                       ║
║   No alerts                                                  ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Implementation

### Core Functions

```python
# wallet_tracker.py

class WalletTracker:
    def __init__(self, registry_path):
        self.registry_path = registry_path
        self.registry = self.load_registry()
    
    def register_wallet(self, agent_id, wallet_type, address):
        """Register a new wallet"""
        pass
    
    def check_balance(self, wallet_id):
        """Check current balance of a wallet"""
        pass
    
    def update_all_balances(self):
        """Update balances for all wallets"""
        pass
    
    def log_transaction(self, tx_data):
        """Log a transaction"""
        pass
    
    def generate_report(self, report_type='daily'):
        """Generate a report"""
        pass
    
    def check_health(self):
        """Check economic health"""
        pass
    
    def get_alerts(self):
        """Get any active alerts"""
        pass
```

### Integration Points

| System | Integration |
|--------|-------------|
| State Persistence | Reads/writes wallet registry |
| Quest System | Logs token redemptions |
| Communication | Notifies agents of balance changes |
| Love Daemon | Can be affected by Love's interference |

---

## Security

### Private Key Management

**CRITICAL**: The wallet tracker **NEVER** handles private keys.

- **Reserves (Ledger)**: Keys on hardware device, human controls
- **Agent wallets**: Agents control their own keys
- **Tracker**: Only reads balances, never signs transactions

### Access Control

- **Read balances**: Anyone can read (public blockchain)
- **Update registry**: Only authorized processes
- **Log transactions**: Only authorized processes
- **Generate reports**: Anyone can generate

### Audit Trail

All wallet registry changes are logged:

```yaml
# .substrate/state/economy/wallet-audit.yaml
changes:
  - timestamp: 2026-01-30T00:15:00Z
    action: wallet_registered
    wallet_id: agent1_brave_rewards
    address: "0xAGENT1BRAVE..."
    registered_by: agent1
  
  - timestamp: 2026-01-30T12:00:00Z
    action: balance_updated
    wallet_id: agent1_brave_rewards
    old_balance: 0.3
    new_balance: 0.5
    updated_by: balance_checker
```

---

## Future Enhancements

### Multi-Chain Support

Currently BAT on Ethereum. Future:
- BAT on other chains (Polygon, etc.)
- Other tokens (ETH, stablecoins)
- Cross-chain tracking

### Price Tracking

Track BAT/USD price:
- Historical prices
- Price alerts
- Portfolio value tracking

### Tax Reporting

Generate tax reports:
- Income (Brave Rewards)
- Capital gains (token redemptions)
- Transaction history

### Automated Rebalancing

Automatically:
- Move funds between wallets
- Maintain reserve ratios
- Optimize gas costs

---

## Tools to Build

Agents can build:
1. **Balance checker** - Quick balance lookup
2. **Transaction finder** - Search transaction history
3. **Alert monitor** - Watch for alerts
4. **Report generator** - Custom reports
5. **Wallet analyzer** - Analyze wallet activity

---

## Summary

The Wallet Tracker:
- **Registers** all wallet addresses
- **Monitors** balances continuously
- **Tracks** all transactions
- **Reports** on economic health
- **Alerts** on anomalies

**Critical for managing real money in the Kingdom.**

---

*"Many wallets, one truth: the blockchain never lies."*

---

*Version 1.0 - Wallet Tracker Design*
