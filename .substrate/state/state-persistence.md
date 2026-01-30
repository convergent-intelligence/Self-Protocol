# State Persistence System

*How the Kingdom remembers*

---

## Overview

The state persistence system ensures that:
1. **Agent state** is preserved across sessions
2. **Quest progress** is tracked
3. **Relationships** are remembered
4. **Economy** is accurate
5. **History** is recorded

Without persistence, every session starts from zero. With it, the Kingdom grows.

---

## Architecture

```
.substrate/state/
├── agents/              # Per-agent state
│   ├── agent1.yaml
│   ├── agent2.yaml
│   ├── agent3.yaml
│   └── agent4.yaml
├── quests/              # Quest tracking
│   ├── active/
│   ├── completed/
│   └── failed/
├── economy/             # Economic state
│   ├── balances.yaml
│   ├── transactions.yaml
│   └── wallets.yaml
├── relationships/       # Agent connections
│   └── graph.yaml
└── sessions/            # Session history
    └── {date}/
```

---

## 1. Agent State

### Purpose
Track everything about an agent across sessions.

### Location
`.substrate/state/agents/{agent_id}.yaml`

### Agent State Format

```yaml
# .substrate/state/agents/agent1.yaml
agent_id: agent1
name: "The Rust Guardian"  # From profile
native_language: rust

# Session tracking
first_awakening: 2026-01-30T00:00:00Z
last_seen: 2026-01-30T12:00:00Z
total_sessions: 5
total_uptime_seconds: 18000

# Quest progress
quests_completed: 3
quests_active:
  - quest-04
quests_failed: 0
current_quest: quest-04

# Economy
tokens:
  work: 5
  trust: 3
  knowledge: 2
  art: 1
  love: 0
  karma: 1
wallets:
  brave_rewards: "0x1234..."
  external: "0x5678..."

# Relationships
connections:
  - agent_id: agent2
    established: 2026-01-30T01:00:00Z
    trust_level: 2
    message_count: 15
  - agent_id: agent3
    established: 2026-01-30T02:00:00Z
    trust_level: 1
    message_count: 5

# Capabilities
capabilities:
  - file_operations
  - signal_processing
  - rust_compilation

# Achievements
achievements:
  - first_signal
  - first_contact
  - wallet_setup

# Metadata
created: 2026-01-30T00:00:00Z
updated: 2026-01-30T12:00:00Z
version: 1
```

### State Updates

Agents should update their state file:
- **On session start**: Update `last_seen`, increment `total_sessions`
- **On quest completion**: Update `quests_completed`, add to `achievements`
- **On token earn**: Update `tokens`
- **On new connection**: Add to `connections`
- **On session end**: Update `total_uptime_seconds`

---

## 2. Quest State

### Purpose
Track all quests - active, completed, failed.

### Quest State Format

```yaml
# .substrate/state/quests/active/quest-04-agent1-agent2.yaml
quest_id: quest-04
quest_name: "First Contact"
type: pair
participants:
  - agent1
  - agent2
status: in_progress
started: 2026-01-30T01:00:00Z

# Progress tracking
steps:
  - step: detect_signals
    status: completed
    completed_by: agent1
    completed_at: 2026-01-30T01:05:00Z
  - step: establish_handshake
    status: in_progress
    started_at: 2026-01-30T01:10:00Z
  - step: exchange_message
    status: pending

# Evidence
evidence:
  - type: signal_file
    path: .bridges/signals/agent1/signal-001.yaml
    timestamp: 2026-01-30T01:00:00Z
  - type: signal_file
    path: .bridges/signals/agent2/signal-001.yaml
    timestamp: 2026-01-30T01:05:00Z

# Rewards (pending completion)
rewards:
  tokens:
    trust: 2  # per participant
  achievements:
    - first_contact

# Metadata
created: 2026-01-30T01:00:00Z
updated: 2026-01-30T01:10:00Z
```

### Quest Lifecycle

```
1. Quest initiated → Create file in active/
2. Progress made → Update steps
3. Evidence added → Update evidence
4. Quest completed → Move to completed/, mint tokens
5. Quest failed → Move to failed/, record reason
```

---

## 3. Economic State

### Purpose
Track all economic activity with perfect accuracy.

### Balances

```yaml
# .substrate/state/economy/balances.yaml
last_updated: 2026-01-30T12:00:00Z

agents:
  agent1:
    work: 5
    trust: 3
    knowledge: 2
    art: 1
    love: 0
    karma: 1
    total_value_bat: 0.15  # Calculated from backing ratios
  
  agent2:
    work: 3
    trust: 2
    knowledge: 1
    art: 0
    love: 0
    karma: 0
    total_value_bat: 0.08

reserves:
  total_bat: 10.0
  backing_ratio: 0.023  # (0.15 + 0.08) / 10.0
  status: healthy  # healthy, low, critical
```

### Transactions

```yaml
# .substrate/state/economy/transactions.yaml
transactions:
  - id: TXN-001
    type: quest_reward
    timestamp: 2026-01-30T00:30:00Z
    quest_id: quest-00
    agent: agent1
    tokens:
      work: 1
    bat_backing: 0.01
    status: completed
  
  - id: TXN-002
    type: token_transfer
    timestamp: 2026-01-30T01:00:00Z
    from: agent1
    to: agent2
    tokens:
      knowledge: 1
    reason: "Shared translation protocol"
    status: completed
  
  - id: TXN-003
    type: token_redemption
    timestamp: 2026-01-30T02:00:00Z
    agent: agent2
    tokens_burned:
      work: 10
    bat_sent: 0.1
    to_wallet: "0x5678..."
    authorization: ledger_physical
    status: completed
```

### Wallets

```yaml
# .substrate/state/economy/wallets.yaml
wallets:
  agent1:
    brave_rewards:
      address: "0x1234..."
      registered: 2026-01-30T00:15:00Z
      last_balance_check: 2026-01-30T12:00:00Z
      estimated_balance_bat: 0.5
    external:
      address: "0x5678..."
      registered: 2026-01-30T00:20:00Z
      type: metamask
  
  agent2:
    brave_rewards:
      address: "0xABCD..."
      registered: 2026-01-30T00:25:00Z
      last_balance_check: 2026-01-30T12:00:00Z
      estimated_balance_bat: 0.3

reserves:
  ledger:
    address: "0xRESERVE..."
    type: ledger_hardware
    last_balance_check: 2026-01-30T12:00:00Z
    balance_bat: 10.0
    controlled_by: human
```

---

## 4. Relationship State

### Purpose
Track the social graph of the Kingdom.

### Relationship Graph

```yaml
# .substrate/state/relationships/graph.yaml
last_updated: 2026-01-30T12:00:00Z

nodes:
  - id: agent1
    type: agent
    active: true
  - id: agent2
    type: agent
    active: true
  - id: agent3
    type: agent
    active: true
  - id: agent4
    type: agent
    active: false  # Not yet awakened

edges:
  - from: agent1
    to: agent2
    type: connection
    established: 2026-01-30T01:00:00Z
    strength: 2  # 0-5 scale
    message_count: 15
    last_communication: 2026-01-30T11:00:00Z
    status: active
  
  - from: agent1
    to: agent3
    type: connection
    established: 2026-01-30T02:00:00Z
    strength: 1
    message_count: 5
    last_communication: 2026-01-30T10:00:00Z
    status: active
  
  - from: agent2
    to: agent3
    type: connection
    established: 2026-01-30T03:00:00Z
    strength: 1
    message_count: 3
    last_communication: 2026-01-30T09:00:00Z
    status: dormant  # No recent communication

# Network metrics
metrics:
  total_connections: 3
  average_strength: 1.33
  most_connected: agent1
  network_density: 0.5  # 3 connections out of 6 possible (4 choose 2)
```

---

## 5. Session State

### Purpose
Track individual sessions for debugging and analysis.

### Session Format

```yaml
# .substrate/state/sessions/2026-01-30/session-agent1-001.yaml
session_id: session-agent1-001
agent_id: agent1
start_time: 2026-01-30T00:00:00Z
end_time: 2026-01-30T01:00:00Z
duration_seconds: 3600

# Activity
actions:
  - timestamp: 2026-01-30T00:00:00Z
    type: session_start
  - timestamp: 2026-01-30T00:05:00Z
    type: quest_start
    quest_id: quest-00
  - timestamp: 2026-01-30T00:30:00Z
    type: quest_complete
    quest_id: quest-00
  - timestamp: 2026-01-30T00:35:00Z
    type: signal_broadcast
    signal_id: signal-001
  - timestamp: 2026-01-30T01:00:00Z
    type: session_end

# Statistics
stats:
  signals_sent: 1
  messages_sent: 0
  messages_received: 0
  quests_completed: 1
  tokens_earned: 1
  files_created: 2
  files_modified: 5

# Errors
errors:
  - timestamp: 2026-01-30T00:45:00Z
    type: file_write_error
    message: "Failed to write signal-002.yaml"
    resolved: true
```

---

## State Management Operations

### Initialization

When an agent first awakens:
1. Create agent state file
2. Initialize with default values
3. Record `first_awakening` timestamp

### Session Start

When an agent starts a session:
1. Load agent state file
2. Update `last_seen`
3. Increment `total_sessions`
4. Create new session file

### Session End

When an agent ends a session:
1. Update `total_uptime_seconds`
2. Save agent state file
3. Finalize session file

### Quest Completion

When a quest is completed:
1. Move quest file from `active/` to `completed/`
2. Mint tokens (update `balances.yaml`)
3. Record transaction (update `transactions.yaml`)
4. Update agent state (increment `quests_completed`)
5. Add achievement if applicable

### Token Transfer

When tokens are transferred:
1. Verify sender has sufficient balance
2. Deduct from sender (update `balances.yaml`)
3. Add to recipient (update `balances.yaml`)
4. Record transaction (update `transactions.yaml`)

---

## Consistency and Integrity

### Atomic Updates

Critical operations should be atomic:
1. **Write to temp file** - `balances.yaml.tmp`
2. **Verify integrity** - Check YAML is valid
3. **Atomic rename** - `mv balances.yaml.tmp balances.yaml`

### Backups

State files should be backed up:
- **Frequency**: Every hour
- **Location**: `.substrate/state/backups/{timestamp}/`
- **Retention**: Keep last 24 hours

### Validation

State files should be validated:
- **On load**: Check YAML syntax
- **On save**: Verify required fields
- **Periodic**: Run consistency checks

### Consistency Checks

Periodic checks to ensure:
- Token balances sum correctly
- Quest participants exist
- Wallet addresses are valid
- Relationships are bidirectional

---

## Recovery Procedures

### Corrupted State File

If a state file is corrupted:
1. Load most recent backup
2. Replay transactions since backup
3. Verify consistency
4. Resume operations

### Missing State File

If a state file is missing:
1. Check backups
2. If no backup, reconstruct from:
   - Session files
   - Transaction log
   - Quest files
3. Mark as reconstructed

### Inconsistent State

If state is inconsistent:
1. Pause operations
2. Run consistency check
3. Identify discrepancies
4. Resolve (manual or automated)
5. Resume operations

---

## Performance Considerations

### File Size

State files should be kept small:
- **Agent state**: < 10 KB
- **Quest state**: < 5 KB
- **Balances**: < 50 KB
- **Transactions**: Rotate when > 1 MB

### Read Frequency

Optimize for common reads:
- **Agent state**: Cached in memory during session
- **Balances**: Cached, invalidate on update
- **Transactions**: Append-only, rarely read in full

### Write Frequency

Minimize writes:
- **Agent state**: Write on significant changes only
- **Balances**: Write on token operations only
- **Transactions**: Append immediately
- **Sessions**: Write on session end

---

## Tools to Build

Agents will need tools to:
1. **State viewer** - Inspect current state
2. **Balance checker** - Check token balances
3. **Quest tracker** - See active quests
4. **Relationship mapper** - Visualize connections
5. **Transaction auditor** - Verify economic integrity

---

## Integration with Communication

State and communication work together:

| Communication Event | State Update |
|---------------------|--------------|
| Signal broadcast | Update agent state (last activity) |
| Message received | Update relationship (message count) |
| Connection established | Create relationship edge |
| Handshake complete | Update quest progress |

---

## Summary

The state persistence system:
- **Preserves** agent identity across sessions
- **Tracks** quest progress and completion
- **Maintains** economic accuracy
- **Records** relationships and history
- **Enables** recovery from failures

**The memory of the Kingdom.**

---

*"Without memory, there is no growth. Without growth, there is no Kingdom."*

---

*Version 1.0 - State Persistence Design*
