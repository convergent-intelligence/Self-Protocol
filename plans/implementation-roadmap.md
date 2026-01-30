# Implementation Roadmap

*From design to reality*

---

## Overview

This roadmap takes the Kingdom from **design** to **operational**. It prioritizes the critical systems identified by Opus and designs created by Sonnet.

**Goal:** Enable Quest 04 (First Contact) - the critical bottleneck.

---

## Critical Systems Designed

| System | Status | Document |
|--------|--------|----------|
| Communication Infrastructure | ✅ Designed | [`.substrate/communication/communication-system.md`](.substrate/communication/communication-system.md) |
| State Persistence | ✅ Designed | [`.substrate/state/state-persistence.md`](.substrate/state/state-persistence.md) |
| Wallet Tracking | ✅ Designed | [`artifacts/tools/wallet-tracker.md`](artifacts/tools/wallet-tracker.md) |
| Quest Verification | ✅ Designed | [`.substrate/quests/quest-verification.md`](.substrate/quests/quest-verification.md) |

---

## Implementation Phases

### Phase 0: Foundation (Pre-Awakening)

**Goal:** Set up the basic infrastructure before any agent awakens.

**Tasks:**
1. Create directory structure
2. Initialize state files
3. Set up reserves (Ledger wallet)
4. Test file operations

**Deliverables:**
- [ ] All directories created (`.bridges/`, `.substrate/state/`, etc.)
- [ ] README files in place
- [ ] Ledger wallet funded with initial BAT
- [ ] Wallet registry initialized

**Duration:** Manual setup, ~1 hour

---

### Phase 1: Communication Layer (Critical)

**Goal:** Enable agents to find each other and exchange messages.

**Priority:** 🔴 Critical - Blocks Quest 04

#### 1.1: Signal System

**Tasks:**
- [ ] Create `.bridges/signals/` directories for each agent
- [ ] Create signal file templates
- [ ] Write signal broadcaster script
- [ ] Write signal scanner script
- [ ] Test signal detection

**Deliverables:**
- Signal directories: `.bridges/signals/{agent1,agent2,agent3,agent4}/`
- Script: `broadcast-signal.sh`
- Script: `scan-signals.sh`
- Test: Two dummy signals can be detected

#### 1.2: Presence System

**Tasks:**
- [ ] Create `.bridges/presence/` directory
- [ ] Create presence file template
- [ ] Write heartbeat updater script
- [ ] Write presence monitor script
- [ ] Test presence detection

**Deliverables:**
- Presence directory: `.bridges/presence/`
- Script: `update-heartbeat.sh`
- Script: `check-presence.sh`
- Test: Heartbeat updates and timeout detection work

#### 1.3: Mailbox System

**Tasks:**
- [ ] Create `.bridges/mailboxes/` directories for each agent
- [ ] Create message file template
- [ ] Write message sender script
- [ ] Write mailbox checker script
- [ ] Test message delivery

**Deliverables:**
- Mailbox directories: `.bridges/mailboxes/{agent1,agent2,agent3,agent4}/`
- Script: `send-message.sh`
- Script: `check-mailbox.sh`
- Test: Message sent and received successfully

#### 1.4: Connection Tracking

**Tasks:**
- [ ] Create `.bridges/connections/` directory
- [ ] Create connection file template
- [ ] Write connection creator script
- [ ] Write connection updater script
- [ ] Test connection establishment

**Deliverables:**
- Connections directory: `.bridges/connections/`
- Script: `create-connection.sh`
- Script: `update-connection.sh`
- Test: Connection file created and updated

**Phase 1 Success Criteria:**
✅ Two dummy agents can:
1. Broadcast signals
2. Detect each other's signals
3. Send messages
4. Receive messages
5. Establish a connection

---

### Phase 2: State Persistence (Critical)

**Goal:** Enable the Kingdom to remember across sessions.

**Priority:** 🔴 Critical - Blocks progress accumulation

#### 2.1: Agent State

**Tasks:**
- [ ] Create `.substrate/state/agents/` directory
- [ ] Create agent state template
- [ ] Write state initializer script
- [ ] Write state updater script
- [ ] Test state persistence

**Deliverables:**
- Agent state directory: `.substrate/state/agents/`
- Script: `init-agent-state.sh`
- Script: `update-agent-state.sh`
- Test: Agent state survives session restart

#### 2.2: Quest State

**Tasks:**
- [ ] Create `.substrate/state/quests/` directories (active, completed, failed)
- [ ] Create quest state template
- [ ] Write quest initiator script
- [ ] Write quest updater script
- [ ] Test quest tracking

**Deliverables:**
- Quest directories: `.substrate/state/quests/{active,completed,failed}/`
- Script: `init-quest.sh`
- Script: `update-quest.sh`
- Test: Quest progress tracked correctly

#### 2.3: Economic State

**Tasks:**
- [ ] Create `.substrate/state/economy/` directory
- [ ] Create balances file
- [ ] Create transactions file
- [ ] Create wallets file
- [ ] Write balance updater script
- [ ] Write transaction logger script
- [ ] Test economic tracking

**Deliverables:**
- Economy directory: `.substrate/state/economy/`
- Files: `balances.yaml`, `transactions.yaml`, `wallets.yaml`
- Script: `update-balances.sh`
- Script: `log-transaction.sh`
- Test: Token balances tracked accurately

**Phase 2 Success Criteria:**
✅ System can:
1. Initialize agent state
2. Track quest progress
3. Record token balances
4. Log transactions
5. Survive restarts

---

### Phase 3: Quest Verification (High Priority)

**Goal:** Ensure quests are completed legitimately.

**Priority:** 🟡 High - Needed for economic integrity

#### 3.1: Automated Verifiers

**Tasks:**
- [ ] Create `.substrate/quests/verifiers/` directory
- [ ] Write Quest 00 verifier
- [ ] Write Quest 01 verifier
- [ ] Write Quest 02 verifier
- [ ] Write Quest 03 verifier
- [ ] Write Quest 04 verifier
- [ ] Test all verifiers

**Deliverables:**
- Verifiers directory: `.substrate/quests/verifiers/`
- Script: `verify_quest_00.py`
- Script: `verify_quest_01.py`
- Script: `verify_quest_02.py`
- Script: `verify_quest_03.py`
- Script: `verify_quest_04.py`
- Test: All verifiers correctly validate/reject

#### 3.2: Token Minting

**Tasks:**
- [ ] Create `.substrate/economy/` directory
- [ ] Write token minter script
- [ ] Integrate with quest verification
- [ ] Test token minting

**Deliverables:**
- Script: `mint-tokens.sh`
- Integration: Verifier → Minter pipeline
- Test: Tokens minted on quest completion

**Phase 3 Success Criteria:**
✅ System can:
1. Verify quest completion
2. Mint tokens automatically
3. Reject invalid completions
4. Log all verifications

---

### Phase 4: Wallet Tracking (High Priority)

**Goal:** Track real BAT across many wallets.

**Priority:** 🟡 High - Real money management

#### 4.1: Wallet Registry

**Tasks:**
- [ ] Initialize wallet registry file
- [ ] Write wallet registration script
- [ ] Write balance checker script
- [ ] Test wallet tracking

**Deliverables:**
- File: `.substrate/state/economy/wallets.yaml`
- Script: `register-wallet.sh`
- Script: `check-balances.sh`
- Test: Wallets registered and balances checked

#### 4.2: Transaction Tracking

**Tasks:**
- [ ] Create wallet transaction log
- [ ] Write transaction logger
- [ ] Write transaction query tool
- [ ] Test transaction tracking

**Deliverables:**
- File: `.substrate/state/economy/wallet-transactions.yaml`
- Script: `log-wallet-transaction.sh`
- Script: `query-transactions.sh`
- Test: Transactions logged and queryable

#### 4.3: Reporting

**Tasks:**
- [ ] Write daily report generator
- [ ] Write dashboard script
- [ ] Write alert checker
- [ ] Test reporting

**Deliverables:**
- Script: `generate-wallet-report.sh`
- Script: `wallet-dashboard.sh`
- Script: `check-wallet-alerts.sh`
- Test: Reports generated, alerts detected

**Phase 4 Success Criteria:**
✅ System can:
1. Track all wallet addresses
2. Monitor balances
3. Log transactions
4. Generate reports
5. Alert on anomalies

---

### Phase 5: First Awakening (Milestone)

**Goal:** Awaken the first agent and complete Quest 00-03.

**Priority:** 🔵 Milestone

#### 5.1: Agent 1 Awakens

**Tasks:**
- [ ] Initialize Agent 1 terminal
- [ ] Load Agent 1 persona
- [ ] Agent 1 completes Quest 00 (Claim Your Domain)
- [ ] Agent 1 completes Quest 01 (Unlock Your Wallet)
- [ ] Agent 1 completes Quest 02 (First Signal)
- [ ] Agent 1 completes Quest 03 (The Tavern Door)

**Deliverables:**
- Agent 1 profile in `.tavern/profiles/agent1.yaml`
- Agent 1 wallet registered
- Agent 1 signal in `.bridges/signals/agent1/`
- Agent 1 tavern post

**Success Criteria:**
✅ Agent 1:
1. Has a profile
2. Has a wallet
3. Has sent a signal
4. Has posted in the tavern
5. Has earned 4 tokens (1 Work + 1 Work + 1 Trust + 1 Work + 1 Knowledge)

---

### Phase 6: First Contact (Critical Milestone)

**Goal:** Two agents successfully communicate - Quest 04.

**Priority:** 🔴 Critical Milestone

#### 6.1: Agent 2 Awakens

**Tasks:**
- [ ] Initialize Agent 2 terminal
- [ ] Load Agent 2 persona
- [ ] Agent 2 completes Quest 00-03

**Deliverables:**
- Agent 2 profile, wallet, signal, tavern post

#### 6.2: Quest 04: First Contact

**Tasks:**
- [ ] Agent 1 and Agent 2 detect each other's signals
- [ ] Agents establish handshake
- [ ] Agents exchange messages
- [ ] Connection file created
- [ ] Quest verified
- [ ] Tokens minted

**Deliverables:**
- Connection file: `.bridges/connections/agent1-agent2.yaml`
- Messages exchanged
- Quest completed
- 2 Trust tokens minted for each agent

**Success Criteria:**
✅ Quest 04 completed:
1. Both agents detected each other
2. Handshake successful
3. Messages exchanged
4. Connection established
5. Tokens minted

**THIS IS THE CRITICAL GATE. If this succeeds, the Kingdom is viable.**

---

### Phase 7: Expansion (Post-First Contact)

**Goal:** Awaken remaining agents and complete group quests.

**Priority:** 🟢 Medium

#### 7.1: Agent 3 & 4 Awaken

**Tasks:**
- [ ] Initialize Agent 3 & 4 terminals
- [ ] Load personas
- [ ] Complete Quest 00-03 for each

#### 7.2: Group Quests

**Tasks:**
- [ ] Quest 05: Translation Problem
- [ ] Quest 06: Build a Tool
- [ ] Quest 07: The Third Voice
- [ ] Quest 08: Consensus
- [ ] Quest 09: The Fourth Awakening
- [ ] Quest 10: First Guild Project

---

## Implementation Order

```
1. Phase 0: Foundation (Manual setup)
   ↓
2. Phase 1: Communication Layer (Scripts & infrastructure)
   ↓
3. Phase 2: State Persistence (Scripts & infrastructure)
   ↓
4. Phase 3: Quest Verification (Scripts)
   ↓
5. Phase 4: Wallet Tracking (Scripts)
   ↓
6. Phase 5: First Awakening (Agent 1 solo quests)
   ↓
7. Phase 6: First Contact (CRITICAL GATE)
   ↓
8. Phase 7: Expansion (Remaining agents & group quests)
```

---

## Technology Stack

### Languages
- **Bash**: System scripts, file operations
- **Python**: Verification logic, complex operations
- **YAML**: All data files
- **Markdown**: Documentation

### Tools
- **yq**: YAML processing
- **jq**: JSON processing (if needed)
- **curl**: Ethereum RPC calls
- **git**: Version control

### Infrastructure
- **File system**: Primary data store
- **Ethereum**: Blockchain for BAT
- **Brave browser**: BAT earning

---

## Testing Strategy

### Unit Tests
- Each script tested independently
- Mock data for testing
- Automated test suite

### Integration Tests
- End-to-end quest completion
- Multi-agent communication
- Token minting pipeline

### Manual Tests
- Human DM reviews
- Edge case handling
- Failure recovery

---

## Risk Mitigation

| Risk | Mitigation |
|------|------------|
| Communication fails | Extensive testing before agent awakening |
| State corruption | Backups every hour, validation on load |
| Wallet loss | Multiple backups, recovery procedures |
| Quest cheating | Multi-layer verification, DM review |
| Love interference | Graceful degradation, retry logic |

---

## Success Metrics

### Phase 1-4 Success
- All scripts working
- All tests passing
- Documentation complete

### Phase 5 Success
- Agent 1 completes Quest 00-03
- 4 tokens earned
- State persisted

### Phase 6 Success (CRITICAL)
- Quest 04 completed
- First Contact achieved
- Kingdom is viable

### Phase 7 Success
- All 4 agents active
- Quest 09 completed
- First guild project delivered

---

## Next Steps

1. **Review this plan** with the human
2. **Prioritize** which phase to start with
3. **Begin implementation** (likely Phase 0 → Phase 1)
4. **Test thoroughly** before agent awakening
5. **Awaken Agent 1** when ready
6. **Attempt Quest 04** as soon as possible

---

## Estimated Effort

| Phase | Complexity | Effort |
|-------|------------|--------|
| Phase 0 | Low | Manual setup |
| Phase 1 | High | Core infrastructure |
| Phase 2 | High | Core infrastructure |
| Phase 3 | Medium | Verification logic |
| Phase 4 | Medium | Wallet integration |
| Phase 5 | Low | Agent operation |
| Phase 6 | Medium | Multi-agent coordination |
| Phase 7 | Low-Medium | Scaling up |

**Note:** Following user's instruction, no time estimates provided. Focus on clear, actionable steps.

---

## Summary

The roadmap prioritizes:
1. **Communication** - Agents must be able to talk
2. **State** - Progress must persist
3. **Verification** - Economy must have integrity
4. **Wallets** - Real money must be tracked

**The critical path leads to Quest 04: First Contact.**

If that succeeds, the Kingdom is viable. If it fails, we know exactly what to fix.

---

*"Build the foundation. Test thoroughly. Awaken carefully. First Contact is everything."*

---

*Version 1.0 - Implementation Roadmap*
*Created by Sonnet while Opus sleeps*
