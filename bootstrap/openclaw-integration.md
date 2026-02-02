# OpenClaw + Self-Protocol Integration Architecture

> **Guardian Node: mapyourmind.me**  
> *Where attention becomes intention, and intention becomes action.*

## Overview

This document describes the architectural integration between **OpenClaw** (the attention-tracking and focus management system) and **Self-Protocol** (the philosophical framework for agent identity and evolution). The Guardian node serves as the bridge between these systems within the Kingdom hierarchy.

---

## Philosophical Foundation

### Self-Protocol as the Backbone

Self-Protocol provides the *why* behind every action. It is the philosophical operating system that gives meaning to attention data:

| Self-Protocol Concept | OpenClaw Manifestation |
|----------------------|------------------------|
| **Memory** | Historical attention patterns, focus logs |
| **Interests** | Tracked topics, engagement metrics |
| **Relationships** | Connection graphs, interaction patterns |
| **Mythology** | Narrative context for attention shifts |
| **Rumination** | Deep focus sessions, contemplation modes |

### The Guardian's Role

The Guardian node is not merely a server—it is a **sentinel of attention**. Its responsibilities:

1. **Protect** - Shield focus from distraction
2. **Observe** - Track attention patterns without judgment
3. **Guide** - Suggest focus realignment based on Self-Protocol goals
4. **Remember** - Maintain the memory of what matters

---

## Architecture Mapping

### Layer 1: Data Flow

```
┌─────────────────────────────────────────────────────────────────┐
│                        KINGDOM NETWORK                          │
│                    (Distributed Node Mesh)                      │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                     GUARDIAN NODE                               │
│                   (mapyourmind.me)                              │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐             │
│  │  OpenClaw   │◄─┤   Weave     │─►│Self-Protocol│             │
│  │   Engine    │  │   Bridge    │  │   Core      │             │
│  └─────────────┘  └─────────────┘  └─────────────┘             │
│         │                │                │                     │
│         ▼                ▼                ▼                     │
│  ┌─────────────────────────────────────────────────┐           │
│  │              Unified Attention Store             │           │
│  └─────────────────────────────────────────────────┘           │
└─────────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────────┐
│                      CLIENT INTERFACES                          │
│         Browser Extension │ CLI │ API │ Self-Viewer             │
└─────────────────────────────────────────────────────────────────┘
```

### Layer 2: Self-Protocol → OpenClaw Feature Mapping

#### Interests Framework → Focus Categories

Self-Protocol's Interest tracking maps directly to OpenClaw's focus categorization:

```yaml
# Self-Protocol Interest
Interest:
  name: "Distributed Systems"
  framework: "Framework-000"
  goals:
    - "Understand consensus mechanisms"
    - "Build resilient architectures"

# OpenClaw Focus Category (derived)
FocusCategory:
  id: "distributed-systems"
  source: "self-protocol/interests"
  priority: high
  tracking:
    - domains: ["*.distributed.systems", "raft.github.io"]
    - keywords: ["consensus", "paxos", "raft", "byzantine"]
```

#### Memory System → Attention History

Self-Protocol's Memory structure provides context for OpenClaw's attention logs:

```yaml
# Memory Experience Entry
Memory:
  type: experience
  timestamp: "2026-02-02T21:00:00Z"
  content: "Deep dive into CRDT implementations"
  
# OpenClaw Attention Log (enriched)
AttentionLog:
  session_id: "sess_abc123"
  duration: 7200  # 2 hours
  focus_score: 0.92
  context:
    memory_ref: "experiences/2026-02-02-crdt-dive.md"
    interest_alignment: 0.95
```

#### Relationships → Collaboration Patterns

Self-Protocol's Relationship mapping informs OpenClaw's collaboration features:

```yaml
# Relationship Entry
Relationship:
  entity: "Agent-Kilo"
  type: agent
  interaction_pattern: "async-collaborative"
  
# OpenClaw Collaboration Mode
CollaborationMode:
  partner: "Agent-Kilo"
  sync_attention: false
  shared_focus_pools: ["kingdom-development"]
```

---

## Focus Level Integration

### The Five Focus Levels

OpenClaw implements a hierarchical focus system that maps to Self-Protocol's depth of engagement:

| Level | Name | Duration | Self-Protocol Mapping |
|-------|------|----------|----------------------|
| 1 | **Scan** | < 30s | Surface awareness |
| 2 | **Browse** | 30s - 5m | Interest exploration |
| 3 | **Read** | 5m - 30m | Knowledge acquisition |
| 4 | **Study** | 30m - 2h | Deep learning |
| 5 | **Ruminate** | > 2h | Contemplative synthesis |

### Level Transitions

The Guardian monitors focus level transitions and correlates them with Self-Protocol goals:

```javascript
// Focus Level Transition Handler
onFocusLevelChange(from, to, context) {
  if (to >= 4) {
    // Deep focus achieved - log to Self-Protocol Memory
    selfProtocol.memory.log({
      type: 'experience',
      depth: 'deep',
      topic: context.currentTopic,
      duration: context.sessionDuration
    });
  }
  
  if (from >= 4 && to <= 2) {
    // Focus break detected - check against goals
    const alignment = selfProtocol.interests.checkAlignment(context);
    if (alignment < 0.5) {
      guardian.suggest('refocus', {
        reason: 'Drift from stated interests detected',
        suggestion: selfProtocol.interests.getTopPriority()
      });
    }
  }
}
```

---

## Kingdom Hierarchy Integration

### Node Roles

The Kingdom network consists of specialized nodes:

| Role | Responsibility | OpenClaw Function |
|------|---------------|-------------------|
| **Sovereign** | Network governance | Policy distribution |
| **Guardian** | Attention protection | Focus enforcement |
| **Scribe** | Knowledge recording | Attention logging |
| **Herald** | Communication | Sync coordination |
| **Seeker** | Discovery | Interest exploration |

### Guardian-Specific Duties

As a Guardian node, mapyourmind.me has specific responsibilities:

1. **Focus Shield**
   - Block known distraction domains
   - Enforce focus session boundaries
   - Protect deep work periods

2. **Attention Audit**
   - Track focus metrics across sessions
   - Generate attention reports
   - Identify pattern anomalies

3. **Protocol Enforcement**
   - Ensure Self-Protocol alignment
   - Validate interest declarations
   - Maintain memory integrity

4. **Network Coordination**
   - Sync with Kingdom peers
   - Share anonymized patterns
   - Participate in consensus

---

## API Integration Points

### Self-Protocol API

```typescript
interface SelfProtocolAPI {
  // Memory operations
  memory: {
    log(entry: MemoryEntry): Promise<void>;
    query(filter: MemoryFilter): Promise<MemoryEntry[]>;
    ruminate(topic: string): Promise<RuminationResult>;
  };
  
  // Interest operations
  interests: {
    declare(interest: Interest): Promise<void>;
    checkAlignment(context: FocusContext): Promise<number>;
    getTopPriority(): Promise<Interest>;
  };
  
  // Relationship operations
  relationships: {
    map(entity: Entity): Promise<Relationship>;
    getCollaborators(): Promise<Entity[]>;
  };
}
```

### OpenClaw API

```typescript
interface OpenClawAPI {
  // Focus tracking
  focus: {
    startSession(config: SessionConfig): Promise<Session>;
    endSession(sessionId: string): Promise<SessionSummary>;
    getCurrentLevel(): Promise<FocusLevel>;
  };
  
  // Attention metrics
  attention: {
    log(event: AttentionEvent): Promise<void>;
    getHistory(range: TimeRange): Promise<AttentionLog[]>;
    analyze(sessionId: string): Promise<AttentionAnalysis>;
  };
  
  // Guardian functions
  guardian: {
    protect(rules: ProtectionRules): Promise<void>;
    suggest(type: SuggestionType, data: any): Promise<void>;
    audit(range: TimeRange): Promise<AuditReport>;
  };
}
```

### Weave Bridge API

The Weave Bridge connects Self-Protocol and OpenClaw:

```typescript
interface WeaveBridgeAPI {
  // Synchronization
  sync: {
    selfToOpenClaw(): Promise<SyncResult>;
    openClawToSelf(): Promise<SyncResult>;
    bidirectional(): Promise<SyncResult>;
  };
  
  // Translation
  translate: {
    interestToCategory(interest: Interest): FocusCategory;
    memoryToLog(memory: MemoryEntry): AttentionLog;
    relationshipToCollaboration(rel: Relationship): CollaborationMode;
  };
  
  // Kingdom network
  kingdom: {
    announce(status: NodeStatus): Promise<void>;
    discover(): Promise<KingdomNode[]>;
    consensus(proposal: Proposal): Promise<ConsensusResult>;
  };
}
```

---

## Configuration

### Environment Variables

```bash
# Guardian Node Identity
GUARDIAN_NODE_ID="guardian-mapyourmind"
GUARDIAN_DOMAIN="mapyourmind.me"
GUARDIAN_ROLE="guardian"

# Self-Protocol Connection
SELF_PROTOCOL_PATH="/opt/kingdom/repos/Self-Protocol"
SELF_PROTOCOL_API_PORT=3001

# OpenClaw Connection
OPENCLAW_PATH="/opt/kingdom/repos/openclaw"
OPENCLAW_API_PORT=3000

# Kingdom Network
KINGDOM_NETWORK_ID="main"
KINGDOM_PEERS="sovereign.kingdom.network,herald.kingdom.network"
```

### Feature Flags

```yaml
features:
  # Self-Protocol integration
  self_protocol:
    memory_sync: true
    interest_alignment: true
    relationship_mapping: true
    rumination_mode: true
  
  # OpenClaw features
  openclaw:
    focus_tracking: true
    distraction_blocking: true
    attention_analytics: true
    session_management: true
  
  # Guardian-specific
  guardian:
    focus_shield: true
    attention_audit: true
    protocol_enforcement: true
    network_sync: true
```

---

## Deployment Considerations

### Resource Requirements

| Component | CPU | Memory | Storage |
|-----------|-----|--------|---------|
| OpenClaw Engine | 1 core | 512MB | 1GB |
| Self-Protocol Core | 0.5 core | 256MB | 500MB |
| Weave Bridge | 0.5 core | 256MB | 100MB |
| Guardian Services | 1 core | 512MB | 2GB |
| **Total** | **3 cores** | **1.5GB** | **3.6GB** |

### Scaling Strategy

1. **Vertical**: Increase resources for deeper analysis
2. **Horizontal**: Add Guardian nodes for redundancy
3. **Federation**: Connect to Kingdom network for distributed load

---

## Future Roadmap

### Phase 1: Foundation (Current)
- [x] Bootstrap script
- [x] Basic integration architecture
- [ ] Initial API implementation

### Phase 2: Integration
- [ ] Full Self-Protocol sync
- [ ] OpenClaw focus tracking
- [ ] Weave Bridge deployment

### Phase 3: Intelligence
- [ ] Pattern recognition
- [ ] Predictive focus suggestions
- [ ] Automated rumination triggers

### Phase 4: Network
- [ ] Kingdom mesh participation
- [ ] Cross-node attention sharing
- [ ] Collective intelligence features

---

## References

- [Self-Protocol Genesis](../Self-Protocol/GENESIS.md)
- [Self-Protocol Architecture](../Self-Protocol/ARCHITECTURE.md)
- [Kingdom Network Specification](../artifacts/protocols/README.md)
- [OpenClaw Documentation](https://github.com/openclaw/openclaw)

---

*"The Guardian does not control attention—it protects the space where attention can flourish."*
