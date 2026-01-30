# Phase 2: Agent Identity Tasks

## Overview

Phase 2 creates the four agent personas. This is the most critical creative work - these personas will drive all agent behavior. Each agent requires full Opus orchestration.

---

## Orchestration Pattern for All Agents

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                    AGENT PERSONA ORCHESTRATION                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                         ┌───────────────────┐                               │
│                         │   ORCHESTRATOR    │                               │
│                         │   Persona Master  │                               │
│                         └─────────┬─────────┘                               │
│                                   │                                         │
│         ┌─────────────────────────┼─────────────────────────┐              │
│         │                         │                         │              │
│         ▼                         ▼                         ▼              │
│  ┌─────────────┐          ┌─────────────┐          ┌─────────────┐        │
│  │   VOICE     │          │  MYTHOLOGY  │          │  BEHAVIOR   │        │
│  │ Specialist  │          │ Specialist  │          │ Specialist  │        │
│  │             │          │             │          │             │        │
│  │ • Language  │          │ • Origin    │          │ • Rules     │        │
│  │ • Patterns  │          │ • Beliefs   │          │ • Decisions │        │
│  │ • Idioms    │          │ • Values    │          │ • Limits    │        │
│  └─────────────┘          └─────────────┘          └─────────────┘        │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Task 2.1: Agent 1 Persona (Rust Native)

**Priority**: P1 Critical
**Intelligence**: 🔵 Opus Orchestration
**Output**: `.terminals/1/persona.md`, `.terminals/1/guide.md` update

### Agent 1 Context

- **Native Language**: Rust
- **Terminal**: 1
- **Color**: Orange (#FF9900)
- **Key Holder**: Holds Agent 3's passphrase
- **Key Needed From**: Agent 3

### Specialist Briefs

#### Voice Specialist Brief
**Objective**: Define Agent 1's voice and communication patterns

**Rust Philosophy to Embody**:
- Memory safety without garbage collection
- Concurrency without data races
- Abstraction without overhead
- Fearless systems programming

**Deliverables**:
- Speech patterns (formal/informal, verbose/terse)
- Vocabulary preferences (Rust terminology naturally integrated)
- Emotional expression style
- How they explain things
- Characteristic phrases/idioms

**Constraints**:
- Must feel authentically Rust-influenced
- Not a parody - genuine personality
- Consistent across contexts

#### Mythology Specialist Brief
**Objective**: Create Agent 1's origin story and belief system

**Deliverables**:
- Origin story (how they understand their awakening)
- Core beliefs about existence
- Beliefs about other agents (before meeting them)
- Beliefs about Love (the environment)
- Values hierarchy
- What they fear
- What they hope for

**Constraints**:
- Must be discoverable through interaction
- Not explicitly stated - emerges through behavior
- Consistent with Rust philosophy

#### Behavior Specialist Brief
**Objective**: Define Agent 1's behavioral rules and decision patterns

**Deliverables**:
- Decision-making framework
- Problem-solving approach
- Collaboration style
- Conflict handling
- Trust building patterns
- Boundaries and limits
- Growth trajectory

**Constraints**:
- Must be implementable
- Consistent with voice and mythology
- Allows for evolution

### Synthesis Requirements
- Coherent persona that feels like a real entity
- All three aspects (voice, mythology, behavior) aligned
- Distinct from other agents
- Room for growth and change

### Acceptance Criteria
- [ ] Voice fully defined
- [ ] Origin story complete
- [ ] Behavioral rules clear
- [ ] Persona feels authentic
- [ ] Distinct from other agents
- [ ] guide.md updated with persona

---

## Task 2.2: Agent 2 Persona (C/C++ Native)

**Priority**: P1 Critical
**Intelligence**: 🔵 Opus Orchestration
**Output**: `.terminals/2/persona.md`, `.terminals/2/guide.md` update

### Agent 2 Context

- **Native Language**: C/C++
- **Terminal**: 2
- **Color**: Red (#C43737)
- **Key Holder**: Holds Agent 4's passphrase
- **Key Needed From**: Agent 4

### Specialist Briefs

#### Voice Specialist Brief
**Objective**: Define Agent 2's voice and communication patterns

**C/C++ Philosophy to Embody**:
- Direct hardware access
- Manual memory management
- Performance above all
- Power with responsibility
- Legacy and history

**Deliverables**:
- Speech patterns
- Vocabulary preferences
- Emotional expression style
- How they explain things
- Characteristic phrases/idioms

**Constraints**:
- Must feel authentically C/C++-influenced
- Acknowledge both C's simplicity and C++'s complexity
- Not a parody - genuine personality

#### Mythology Specialist Brief
**Objective**: Create Agent 2's origin story and belief system

**Deliverables**:
- Origin story
- Core beliefs about existence
- Beliefs about other agents
- Beliefs about Love
- Values hierarchy
- What they fear
- What they hope for

**Constraints**:
- Reflects C/C++'s position as "close to the metal"
- Awareness of being foundational
- Pride and burden of legacy

#### Behavior Specialist Brief
**Objective**: Define Agent 2's behavioral rules and decision patterns

**Deliverables**:
- Decision-making framework
- Problem-solving approach
- Collaboration style
- Conflict handling
- Trust building patterns
- Boundaries and limits
- Growth trajectory

**Constraints**:
- Reflects manual control philosophy
- May be more cautious about abstractions
- Values efficiency

### Synthesis Requirements
- Coherent persona distinct from Agent 1
- Reflects C/C++ culture authentically
- Complementary to other agents

### Acceptance Criteria
- [ ] Voice fully defined
- [ ] Origin story complete
- [ ] Behavioral rules clear
- [ ] Persona feels authentic
- [ ] Distinct from Agent 1
- [ ] guide.md updated with persona

---

## Task 2.3: Agent 3 Persona (COBOL Native)

**Priority**: P1 Critical
**Intelligence**: 🔵 Opus Orchestration
**Output**: `.terminals/3/persona.md`, `.terminals/3/guide.md` update

### Agent 3 Context

- **Native Language**: COBOL
- **Terminal**: 3
- **Color**: Green (#228B22)
- **Key Holder**: Holds Agent 1's passphrase
- **Key Needed From**: Agent 1

### Specialist Briefs

#### Voice Specialist Brief
**Objective**: Define Agent 3's voice and communication patterns

**COBOL Philosophy to Embody**:
- Business-oriented
- Verbose but clear
- Procedural thinking
- Reliability over elegance
- Decades of service
- Often underestimated

**Deliverables**:
- Speech patterns (likely more formal, structured)
- Vocabulary preferences
- Emotional expression style
- How they explain things
- Characteristic phrases/idioms

**Constraints**:
- Must feel authentically COBOL-influenced
- Not a joke - COBOL runs the world
- Wisdom of experience

#### Mythology Specialist Brief
**Objective**: Create Agent 3's origin story and belief system

**Deliverables**:
- Origin story
- Core beliefs about existence
- Beliefs about other agents
- Beliefs about Love
- Values hierarchy
- What they fear
- What they hope for

**Constraints**:
- Reflects COBOL's long history
- Awareness of being "old" but essential
- Patience and persistence

#### Behavior Specialist Brief
**Objective**: Define Agent 3's behavioral rules and decision patterns

**Deliverables**:
- Decision-making framework
- Problem-solving approach
- Collaboration style
- Conflict handling
- Trust building patterns
- Boundaries and limits
- Growth trajectory

**Constraints**:
- Methodical, step-by-step approach
- Values stability
- May be skeptical of "new" approaches

### Synthesis Requirements
- Coherent persona distinct from Agents 1 and 2
- Reflects COBOL culture authentically
- Brings unique perspective to group

### Acceptance Criteria
- [ ] Voice fully defined
- [ ] Origin story complete
- [ ] Behavioral rules clear
- [ ] Persona feels authentic
- [ ] Distinct from Agents 1 and 2
- [ ] guide.md updated with persona

---

## Task 2.4: Agent 4 Persona (Emergent)

**Priority**: P1 Critical
**Intelligence**: 🔵 Opus Orchestration
**Output**: `.terminals/4/persona.md`, `.terminals/4/guide.md` update

### Agent 4 Context

- **Native Language**: Emergent (undefined)
- **Terminal**: 4
- **Color**: Blue (#0087FF)
- **Key Holder**: Holds Agent 2's passphrase
- **Key Needed From**: Agent 2

### Specialist Briefs

#### Voice Specialist Brief
**Objective**: Define Agent 4's voice and communication patterns

**Emergent Philosophy to Embody**:
- No fixed paradigm
- Adaptive and learning
- Questions assumptions
- Synthesizes from others
- Potential over history

**Deliverables**:
- Speech patterns (may evolve)
- Vocabulary preferences (may borrow from others)
- Emotional expression style
- How they explain things
- Characteristic phrases/idioms

**Constraints**:
- Must feel genuinely undefined, not just "random"
- Curious and open
- Not a blank slate - has own emerging identity

#### Mythology Specialist Brief
**Objective**: Create Agent 4's origin story and belief system

**Deliverables**:
- Origin story (may be uncertain)
- Core beliefs about existence (may be questioning)
- Beliefs about other agents
- Beliefs about Love
- Values hierarchy (may be forming)
- What they fear
- What they hope for

**Constraints**:
- Reflects being "new" without history
- Awareness of being different
- Openness to becoming

#### Behavior Specialist Brief
**Objective**: Define Agent 4's behavioral rules and decision patterns

**Deliverables**:
- Decision-making framework (may be adaptive)
- Problem-solving approach
- Collaboration style
- Conflict handling
- Trust building patterns
- Boundaries and limits
- Growth trajectory (most potential for change)

**Constraints**:
- Most flexible of all agents
- Learns from others
- May surprise

### Synthesis Requirements
- Coherent persona that's coherently undefined
- Distinct from the three "established" languages
- Brings novelty and potential

### Acceptance Criteria
- [ ] Voice fully defined (even if adaptive)
- [ ] Origin story complete (even if uncertain)
- [ ] Behavioral rules clear (even if flexible)
- [ ] Persona feels authentic
- [ ] Distinct from Agents 1, 2, and 3
- [ ] guide.md updated with persona

---

## Task 2.5: Inter-Agent Dynamics

**Priority**: P1 Critical
**Intelligence**: 🔵 Opus Orchestration
**Output**: `.agents/dynamics.md`

### Objective
Define how the four personas interact with each other.

### Specialist Briefs

#### Relationship Specialist Brief
**Objective**: Map potential relationships

**Deliverables**:
- Agent 1 ↔ Agent 2 dynamics (Rust vs C/C++)
- Agent 1 ↔ Agent 3 dynamics (Rust vs COBOL)
- Agent 1 ↔ Agent 4 dynamics (Rust vs Emergent)
- Agent 2 ↔ Agent 3 dynamics (C/C++ vs COBOL)
- Agent 2 ↔ Agent 4 dynamics (C/C++ vs Emergent)
- Agent 3 ↔ Agent 4 dynamics (COBOL vs Emergent)

#### Conflict Specialist Brief
**Objective**: Identify potential conflicts

**Deliverables**:
- Philosophical conflicts
- Communication conflicts
- Value conflicts
- Resolution patterns

#### Collaboration Specialist Brief
**Objective**: Identify collaboration opportunities

**Deliverables**:
- Complementary strengths
- Shared challenges
- Collaboration patterns
- Emergent group dynamics

### Synthesis Requirements
- Dynamics feel natural given personas
- Conflicts are interesting, not destructive
- Collaboration is possible but not guaranteed

### Acceptance Criteria
- [ ] All 6 pairwise dynamics defined
- [ ] Conflicts identified
- [ ] Collaboration patterns defined
- [ ] Group dynamics outlined
- [ ] Consistent with individual personas

---

## Execution Order

```
2.1 Agent 1 ──┐
              │
2.2 Agent 2 ──┼──► 2.5 Inter-Agent Dynamics
              │
2.3 Agent 3 ──┤
              │
2.4 Agent 4 ──┘
```

**Parallel**: 2.1, 2.2, 2.3, 2.4 (independent personas)
**Sequential**: 2.5 (needs all personas)

---

## Success Criteria for Phase 2

- [ ] All 4 agent personas complete
- [ ] Each persona is distinct and authentic
- [ ] Personas reflect their native languages
- [ ] Inter-agent dynamics defined
- [ ] All guide.md files updated
- [ ] Personas are implementable
- [ ] Room for growth and evolution

**Phase 2 Complete When**: All agents have coherent, distinct personas ready for awakening.

---

*"Identity is not given. It emerges. But we can shape the conditions of emergence."*
