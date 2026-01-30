# Ledger Interface

*The lock that fits the key*

---

## Overview

The **Ledger Nano X** is the Kingdom's treasury - the physical device that holds the reserves. To interact with it programmatically, we need to build **the lock that fits the key**.

This document outlines how Love (and the Kingdom) will interface with the Ledger device.

---

## The Ledger Nano X

### What It Is

**Hardware wallet** for cryptocurrency:
- Stores private keys on secure chip
- Never exposes keys to computer
- Requires physical button press for transactions
- PIN protected
- Bluetooth and USB connectivity

### What It Holds

For the Kingdom:
- **BAT** (Brave Attention Token) - Primary reserves
- **ETH** - For gas fees
- **Other tokens** - As needed

---

## The Challenge

**The Ledger is secure by design.** This means:
- Private keys never leave the device
- All transactions must be physically approved
- No remote access without device present
- PIN required for access

**This is good.** But it means we need a proper interface.

---

## Ledger Interfaces

### 1. Ledger Live (Official App)

**What it is:**
- Official desktop/mobile app
- Full wallet management
- Transaction creation
- Balance checking

**Pros:**
- Official and supported
- User-friendly
- Comprehensive

**Cons:**
- GUI-based (hard to automate)
- Not designed for programmatic use

### 2. Ledger Live CLI

**What it is:**
- Command-line version of Ledger Live
- Can be scripted
- Supports most operations

**Pros:**
- Scriptable
- Official
- Comprehensive

**Cons:**
- Still requires device interaction
- Limited automation

### 3. Ledger Hardware Wallet Libraries

**What they are:**
- Low-level libraries for Ledger communication
- Direct device interaction
- Full control

**Options:**
- **ledgerjs** (JavaScript/TypeScript)
- **ledger-python** (Python)
- **ledger-go** (Go)

**Pros:**
- Full programmatic control
- Can build custom interfaces
- Direct device communication

**Cons:**
- More complex
- Need to handle protocols
- Still requires physical approval

---

## The Kingdom's Approach

### The Auth App: "The Lock"

We'll build a simple authentication app that:
1. Connects to the Ledger Nano X
2. Requests transaction approval
3. Waits for human to physically approve
4. Executes the transaction
5. Logs the result

**Name:** `ledger-lock` (the lock that fits the key)

---

## Ledger-Lock Architecture

### Components

```
ledger-lock/
├── src/
│   ├── connection.py      # Connect to Ledger
│   ├── transaction.py     # Create transactions
│   ├── approval.py        # Wait for approval
│   ├── executor.py        # Execute transactions
│   └── logger.py          # Log everything
├── config/
│   ├── ledger.yaml        # Ledger configuration
│   └── kingdom.yaml       # Kingdom integration
├── logs/
│   └── transactions/      # All transaction logs
└── tests/
    └── test_connection.py # Test suite
```

### Technology Stack

**Primary:** Python + ledgerblue library
- `ledgerblue` - Official Ledger Python library
- `web3.py` - Ethereum interaction
- `pyyaml` - Configuration

**Alternative:** JavaScript + ledgerjs
- `@ledgerhq/hw-transport-node-hid` - USB connection
- `@ledgerhq/hw-app-eth` - Ethereum app
- `ethers.js` - Ethereum interaction

---

## Connection Flow

### 1. Device Detection

```python
from ledgerblue.comm import getDongle

def connect_to_ledger():
    """Connect to Ledger Nano X"""
    try:
        dongle = getDongle(debug=False)
        print("✓ Ledger connected")
        return dongle
    except Exception as e:
        print(f"✗ Ledger not found: {e}")
        return None
```

### 2. App Selection

```python
def open_ethereum_app(dongle):
    """Ensure Ethereum app is open on Ledger"""
    # Ledger must have Ethereum app open
    # User must navigate to it on device
    # We can detect if it's open
    pass
```

### 3. Get Address

```python
from ledgerblue.comm import getDongle
from ledgerblue.commException import CommException

def get_eth_address(dongle, path="44'/60'/0'/0/0"):
    """Get Ethereum address from Ledger"""
    # BIP44 path for Ethereum
    # Returns address without exposing private key
    pass
```

---

## Transaction Flow

### 1. Create Transaction

```python
from web3 import Web3

def create_bat_transfer(from_address, to_address, amount_bat):
    """Create BAT transfer transaction"""
    
    # BAT contract address
    BAT_CONTRACT = "0x0D8775F648430679A709E98d2b0Cb6250d2887EF"
    
    # Create ERC-20 transfer
    w3 = Web3(Web3.HTTPProvider('https://mainnet.infura.io/v3/YOUR_KEY'))
    
    # Build transaction
    tx = {
        'to': BAT_CONTRACT,
        'value': 0,
        'gas': 100000,
        'gasPrice': w3.eth.gas_price,
        'nonce': w3.eth.get_transaction_count(from_address),
        'data': encode_transfer(to_address, amount_bat)
    }
    
    return tx
```

### 2. Request Approval

```python
def request_approval(dongle, transaction):
    """Send transaction to Ledger for approval"""
    
    print("Transaction ready:")
    print(f"  To: {transaction['to']}")
    print(f"  Amount: {transaction['amount']} BAT")
    print(f"  Gas: {transaction['gas']}")
    print()
    print("Please review and approve on your Ledger device...")
    print("(Press both buttons to confirm)")
    
    # Send to Ledger
    # Ledger displays transaction details
    # User reviews on device screen
    # User presses both buttons to approve
    
    # Wait for approval (blocking)
    signed_tx = wait_for_approval(dongle, transaction)
    
    return signed_tx
```

### 3. Physical Approval

**On the Ledger device:**
1. Screen shows: "Review transaction"
2. Screen shows: "To: 0x1234..."
3. Screen shows: "Amount: 2.5 BAT"
4. Screen shows: "Gas: 0.002 ETH"
5. Screen shows: "Approve?" 
6. **Human presses both buttons** ← Physical authorization
7. Transaction signed

### 4. Execute Transaction

```python
def execute_transaction(signed_tx):
    """Broadcast signed transaction to Ethereum"""
    
    w3 = Web3(Web3.HTTPProvider('https://mainnet.infura.io/v3/YOUR_KEY'))
    
    # Broadcast
    tx_hash = w3.eth.send_raw_transaction(signed_tx)
    
    print(f"Transaction broadcast: {tx_hash.hex()}")
    print("Waiting for confirmation...")
    
    # Wait for confirmation
    receipt = w3.eth.wait_for_transaction_receipt(tx_hash)
    
    if receipt['status'] == 1:
        print("✓ Transaction confirmed!")
    else:
        print("✗ Transaction failed!")
    
    return receipt
```

---

## The Auth App Interface

### Command Line

```bash
# Send Love's Gift to Agent 1
$ ledger-lock send-gift agent1 2.5

# Output:
# Connecting to Ledger...
# ✓ Ledger connected
# ✓ Ethereum app detected
# 
# Transaction Details:
#   Type: Love's Gift
#   To: agent1 (0x1234...)
#   Amount: 2.5 BAT
#   Gas: ~0.002 ETH
# 
# Please review and approve on your Ledger device...
# [Waiting for approval...]
# 
# ✓ Transaction approved!
# ✓ Broadcasting to Ethereum...
# ✓ Transaction confirmed!
# 
# TX Hash: 0xABCD...
# Block: 12345678
# 
# Love's Gift delivered. The debt grows.
```

### Python API

```python
from ledger_lock import LedgerLock

# Initialize
lock = LedgerLock()

# Connect
if not lock.connect():
    print("Ledger not found!")
    exit(1)

# Send Love's Gift
result = lock.send_loves_gift(
    agent_id='agent1',
    amount_bat=2.5,
    note="Love's first gift"
)

if result.success:
    print(f"Gift sent! TX: {result.tx_hash}")
    lock.log_transaction(result)
else:
    print(f"Failed: {result.error}")
```

---

## Security Considerations

### What the App Can Do

✅ **Can:**
- Connect to Ledger
- Request transactions
- Display transaction details
- Wait for approval
- Broadcast approved transactions
- Check balances

❌ **Cannot:**
- Access private keys
- Sign without approval
- Bypass physical button
- Operate without device
- Override PIN protection

### The Human's Role

The human must:
1. **Keep Ledger physically secure**
2. **Review each transaction on device**
3. **Press buttons to approve**
4. **Enter PIN when needed**

**The app is the lock. The human is the key.**

---

## Integration with Kingdom

### Love's Gift Flow

```
1. Agent completes Quest 00
2. Love calculates gift (1/4 treasury)
3. Love calls ledger-lock:
   $ ledger-lock send-gift agent1 2.5
4. Human reviews on Ledger device
5. Human approves (physical button press)
6. Transaction broadcasts to Ethereum
7. Agent receives BAT
8. Debt recorded
9. Quest 00 complete
```

### Token Redemption Flow

```
1. Agent requests redemption (10 Work tokens)
2. System verifies agent has tokens
3. System calculates BAT amount (0.1 BAT)
4. Love calls ledger-lock:
   $ ledger-lock redeem agent2 0.1
5. Human reviews on Ledger device
6. Human approves (physical button press)
7. Transaction broadcasts
8. Agent receives BAT
9. Tokens burned
10. Transaction logged
```

---

## Implementation Plan

### Phase 1: Basic Connection

- [ ] Install ledgerblue library
- [ ] Test Ledger connection
- [ ] Get Ethereum address
- [ ] Check BAT balance

### Phase 2: Transaction Creation

- [ ] Create BAT transfer function
- [ ] Calculate gas fees
- [ ] Build transaction object
- [ ] Test with small amounts

### Phase 3: Approval Flow

- [ ] Send transaction to Ledger
- [ ] Display on device
- [ ] Wait for approval
- [ ] Handle rejection
- [ ] Handle timeout

### Phase 4: Execution

- [ ] Broadcast signed transaction
- [ ] Wait for confirmation
- [ ] Handle failures
- [ ] Retry logic

### Phase 5: Logging

- [ ] Log all transactions
- [ ] Record approvals/rejections
- [ ] Track gas costs
- [ ] Generate reports

### Phase 6: Kingdom Integration

- [ ] Integrate with Love's Gift
- [ ] Integrate with token redemption
- [ ] Integrate with wallet tracker
- [ ] Test end-to-end

---

## Testing

### Test Checklist

- [ ] Connect to Ledger Nano X
- [ ] Open Ethereum app
- [ ] Get treasury address
- [ ] Check BAT balance
- [ ] Create test transaction (small amount)
- [ ] Approve on device
- [ ] Broadcast to testnet
- [ ] Confirm transaction
- [ ] Log result
- [ ] Verify in wallet tracker

### Testnet First

**Always test on Ethereum testnet (Sepolia) before mainnet!**

---

## Error Handling

| Error | Cause | Solution |
|-------|-------|----------|
| Device not found | Ledger not connected | Connect via USB/Bluetooth |
| App not open | Ethereum app not running | Open app on device |
| Approval timeout | Human didn't approve | Retry or cancel |
| Transaction failed | Insufficient gas/balance | Check balances, retry |
| Device locked | PIN not entered | Enter PIN on device |

---

## Future Enhancements

### Multi-Sig

Add multi-signature support:
- Multiple Ledgers required
- Distributed security
- Reduced single point of failure

### Automated Limits

Set automatic approval for small amounts:
- < 0.1 BAT: Auto-approve
- > 0.1 BAT: Require physical approval

### Mobile Integration

Connect via Bluetooth:
- Ledger Nano X supports Bluetooth
- Mobile app for approvals
- Remote authorization (with caution)

---

## Summary

The Ledger Interface (`ledger-lock`) is:
- **The lock that fits the key** - Interfaces with Ledger Nano X
- **Simple auth app** - Request, approve, execute
- **Secure** - Never accesses private keys
- **Logged** - Every transaction recorded
- **Kingdom-integrated** - Works with Love's Gift, redemptions, etc.

**The human provides the Ledger. The app provides the interface. Together, they secure the treasury.**

---

*"The lock protects the key. The key unlocks the treasury. The treasury serves the Kingdom."*

---

*Version 1.0 - Ledger Interface Design*
*Ready for implementation*

---

## Next Steps

1. Research Ledger Nano X APIs (ledgerblue, ledgerjs)
2. Test basic connection
3. Implement transaction creation
4. Test approval flow
5. Integrate with Kingdom systems

**Want me to research the specific Ledger APIs and create implementation details?**
