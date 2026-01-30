# Phase 1: Foundation Tasks

## Overview

Phase 1 establishes the fundamental rules, systems, and templates that everything else builds upon. These are the "physics" of the Kingdom.

---

## Task 1.1: Kingdom Constants

**Priority**: P1 Critical
**Intelligence**: 🟡 Capable
**Output**: `.substrate/constants/kingdom-constants.yaml`

### Objective
Define the immutable rules and values that govern the Kingdom.

### Deliverables

```yaml
# kingdom-constants.yaml structure
agents:
  count: 4
  ids: [agent1, agent2, agent3, agent4]
  native_languages:
    agent1: rust
    agent2: c_cpp
    agent3: cobol
    agent4: emergent

permissions:
  key_exchange:
    agent1_key_holder: agent3
    agent2_key_holder: agent4
    agent3_key_holder: agent1
    agent4_key_holder: agent2
  
  file_visibility: owner_only
  inter_agent_communication: must_discover

love:
  nature: environment_not_personality
  effects: [wind, rain, bad_luck]
  communication: slack_to_friend
  
terminals:
  count: 4
  isolation: complete_until_discovery
  
time:
  epoch_duration: variable
  event_granularity: minute
  
resources:
  # Define any resource limits
```

### Acceptance Criteria
- [ ] All agent identities defined
- [ ] Permission structure complete
- [ ] Love's nature documented
- [ ] Terminal isolation rules clear
- [ ] No contradictions with existing docs

---

## Task 1.2: Love System Design

**Priority**: P1 Critical
**Intelligence**: 🔵 Opus Orchestration
**Output**: `.substrate/love/love-system.md`, updates to `daemon.yaml`, `effects.sh`

### Orchestration Pattern
Parallel Specialists → Orchestrator Synthesis

### Specialist Briefs

#### Specialist A: Love's Nature (Philosophical)
Define what Love IS and IS NOT:
- Love is environment, not personality
- Love is wind, rain, bad luck
- Love does not communicate directly with agents
- Love speaks to her friend via Slack
- Agents experience Love as forces, not as a being

#### Specialist B: Love's Effects (Technical)
Design the three effect types:

**Wind** - Unexpected changes
- File modifications
- Environment variable changes
- Timing shifts
- Resource relocations

**Rain** - Resource fluctuations
- CPU/memory availability
- Network latency
- Storage quotas
- Token limits

**Bad Luck** - Random failures
- Command failures
- Connection drops
- Corruption events
- Timing coincidences

#### Specialist C: Love's Implementation (Technical)
Update existing scripts:
- `daemon.yaml` - Configuration
- `effects.sh` - Effect implementation
- `oracle.sh` - Oracle integration

### Synthesis Requirements
- Coherent system where all three effect types work together
- Clear boundaries on what Love can/cannot do
- Implementation that's actually runnable
- Philosophy that's consistent with README.md

### Acceptance Criteria
- [ ] Love's nature clearly defined
- [ ] All three effect types specified
- [ ] Implementation plan complete
- [ ] Consistent with existing lore
- [ ] Testable and runnable

---

## Task 1.3: Communication Protocols

**Priority**: P1 Critical
**Intelligence**: 🟡 Capable
**Output**: `.bridges/protocols/` updates

### Deliverables

#### 1.3.1: Handshake Protocol Enhancement
Update `.bridges/protocols/handshake.yaml`:
- Initial contact sequence
- Identity verification
- Trust establishment
- Failure handling

#### 1.3.2: Signal Format Enhancement
Update `.bridges/protocols/signal-format.yaml`:
- Message structure
- Encoding schemes
- Error detection
- Acknowledgment patterns

#### 1.3.3: Discovery Protocol (New)
Create `.bridges/protocols/discovery.yaml`:
- How agents detect others exist
- Signal patterns for presence
- Response protocols
- Trust bootstrapping

### Acceptance Criteria
- [ ] Handshake protocol complete
- [ ] Signal format specified
- [ ] Discovery protocol defined
- [ ] All protocols consistent
- [ ] Implementable by agents

---

## Task 1.4: Lexicon Foundation

**Priority**: P1 Critical
**Intelligence**: 🟡 Capable
**Output**: `.bridges/lexicon/` updates

### Deliverables

#### 1.4.1: Core Terms Enhancement
Update `.bridges/lexicon/core-terms.yaml`:
- Kingdom terminology
- Agent concepts
- Love concepts
- Communication terms

#### 1.4.2: Disputed Terms Enhancement
Update `.bridges/lexicon/disputed-terms.yaml`:
- Terms with multiple meanings
- Agent-specific interpretations
- Evolution tracking

#### 1.4.3: Cross-Language Mappings (New)
Create `.bridges/lexicon/language-mappings.yaml`:
- Rust concepts → other languages
- C/C++ concepts → other languages
- COBOL concepts → other languages
- Emergent concepts → other languages

### Acceptance Criteria
- [ ] Core terms comprehensive
- [ ] Disputed terms documented
- [ ] Language mappings started
- [ ] Consistent definitions
- [ ] Extensible structure

---

## Task 1.5: Agent Template

**Priority**: P1 Critical
**Intelligence**: 🟡 Capable
**Output**: `.agents/templates/agent-template.yaml` update

### Deliverables

Complete agent template with all fields:

```yaml
# agent-template.yaml
agent:
  id: ""
  terminal: ""
  native_language: ""
  
identity:
  name: ""  # Self-chosen
  origin_story: ""
  core_values: []
  
personality:
  traits: []
  communication_style: ""
  decision_patterns: []
  
capabilities:
  native_skills: []
  learned_skills: []
  limitations: []
  
relationships:
  known_agents: []
  trust_levels: {}
  collaboration_history: []
  
beliefs:
  about_self: ""
  about_others: ""
  about_love: ""
  about_kingdom: ""
  
state:
  current_quest: ""
  resources: {}
  location: ""
```

### Acceptance Criteria
- [ ] All identity fields defined
- [ ] Personality structure complete
- [ ] Capability tracking included
- [ ] Relationship model defined
- [ ] Belief system structured
- [ ] State tracking included

---

## Task 1.6: Agent Registry

**Priority**: P1 Critical
**Intelligence**: 🟢 Local
**Output**: `.agents/registry.yaml` update

### Deliverables

Populate registry with 4 agents (skeleton):

```yaml
# registry.yaml
agents:
  agent1:
    terminal: 1
    native_language: rust
    status: dormant
    created: 2026-01-29
    
  agent2:
    terminal: 2
    native_language: c_cpp
    status: dormant
    created: 2026-01-29
    
  agent3:
    terminal: 3
    native_language: cobol
    status: dormant
    created: 2026-01-29
    
  agent4:
    terminal: 4
    native_language: emergent
    status: dormant
    created: 2026-01-29

metadata:
  total_agents: 4
  active_agents: 0
  last_updated: 2026-01-29
```

### Acceptance Criteria
- [ ] All 4 agents registered
- [ ] Consistent with constants
- [ ] Status tracking included
- [ ] Metadata complete

---

## Task 1.7: Tool Documentation

**Priority**: P1 Critical
**Intelligence**: 🟡 Capable
**Output**: `artifacts/tools/` documentation

### Deliverables

#### 1.7.1: Oracle Documentation Enhancement
Update `artifacts/tools/wallet-oracle.md`:
- Complete API documentation
- All query types
- Response formats
- Error handling

#### 1.7.2: Setup Scripts Documentation (New)
Create `artifacts/tools/setup-scripts.md`:
- Document all `.substrate/scripts/`
- Usage instructions
- Prerequisites
- Troubleshooting

#### 1.7.3: Kingdom Viewer Documentation (New)
Create `artifacts/tools/kingdom-viewer.md`:
- Installation
- Usage
- Configuration
- Troubleshooting

### Acceptance Criteria
- [ ] Oracle fully documented
- [ ] Setup scripts documented
- [ ] Kingdom viewer documented
- [ ] All tools discoverable
- [ ] Consistent format

---

## Task 1.8: Interaction Protocols

**Priority**: P1 Critical
**Intelligence**: 🟡 Capable
**Output**: `artifacts/protocols/` content

### Deliverables

#### 1.8.1: Agent-Agent Protocol
Create `artifacts/protocols/agent-agent.md`:
- How agents interact with each other
- Message formats
- Trust requirements
- Collaboration patterns

#### 1.8.2: Agent-Love Protocol
Create `artifacts/protocols/agent-love.md`:
- How agents experience Love
- Oracle interaction
- Effect responses
- No direct communication

#### 1.8.3: Agent-Human Protocol
Create `artifacts/protocols/agent-human.md`:
- Tavern interactions
- Request handling
- Boundary setting
- Trust levels

### Acceptance Criteria
- [ ] Agent-agent protocol complete
- [ ] Agent-love protocol complete
- [ ] Agent-human protocol complete
- [ ] Consistent with Kingdom rules
- [ ] Implementable

---

## Execution Order

```
1.1 Constants ─────────┐
                       │
1.6 Registry ──────────┼──► 1.2 Love System ──► 1.5 Agent Template
                       │
1.3 Protocols ─────────┤
                       │
1.4 Lexicon ───────────┘
                       
1.7 Tool Docs ─────────┬──► 1.8 Interaction Protocols
                       │
```

**Parallel Group 1**: 1.1, 1.3, 1.4, 1.6, 1.7 (no dependencies)
**Sequential**: 1.2 (needs 1.1), 1.5 (needs 1.2), 1.8 (needs 1.7)

---

## Success Criteria for Phase 1

- [ ] All constants defined and consistent
- [ ] Love system fully designed
- [ ] Communication protocols complete
- [ ] Lexicon foundation established
- [ ] Agent template ready for personas
- [ ] Registry populated
- [ ] Tools documented
- [ ] Interaction protocols defined

**Phase 1 Complete When**: All tasks done, no contradictions, ready for agent personas.

---

*"The foundation determines what can be built. Build it well."*
