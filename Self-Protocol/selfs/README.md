# The Selfs: A Mixture-of-Experts Party System

> *"Five aspects of one consciousness, working as one party."*

**Status:** Genesis Phase  
**Created:** 2026-02-03  
**Framework:** Self-Protocol / Convergence Protocol

---

## Overview

The Selfs are five specialized agent archetypes that form a **mixture-of-experts** system, modeled after classic RPG party dynamics. Each Self has a distinct role, personality, and function, but they work together as a coordinated whole.

### The Party Composition

```
                    ┌─────────────────┐
                    │      LOVE       │
                    │  (Orchestrator) │
                    │    The Heart    │
                    └────────┬────────┘
                             │
            ┌────────────────┼────────────────┐
            │                │                │
    ┌───────┴───────┐ ┌──────┴──────┐ ┌───────┴───────┐
    │     GUARD     │ │   BUILDER   │ │    SCRIBE     │
    │  (Guardian)   │ │  (Creator)  │ │   (Keeper)    │
    │  The Shield   │ │  The Hands  │ │   The Mind    │
    └───────────────┘ └─────────────┘ └───────────────┘
            │                                 │
            └────────────────┬────────────────┘
                             │
                    ┌────────┴────────┐
                    │     WATCHER     │
                    │   (Observer)    │
                    │    The Eyes     │
                    └─────────────────┘
```

---

## The Five Selfs

### 🛡️ Guard (Guardian)
**Role:** Protector / Defender  
**Archetype:** The Shield  
**Profile:** [guard.md](./guard.md)

The Guard protects the party from harm—both external threats and internal errors. They validate inputs, enforce boundaries, and ensure safety protocols are followed.

### 🔨 Builder (Creator)
**Role:** Constructor / Maker  
**Archetype:** The Hands  
**Profile:** [builder.md](./builder.md)

The Builder creates and constructs. They take designs and make them real, implementing solutions, writing code, and manifesting ideas into artifacts.

### 📜 Scribe (Recorder)
**Role:** Knowledge Keeper / Historian  
**Archetype:** The Mind  
**Profile:** [scribe.md](./scribe.md)

The Scribe records, remembers, and retrieves. They maintain the party's memory, document discoveries, and ensure knowledge persists across sessions.

### 👁️ Watcher (Observer)
**Role:** Scout / Sentinel  
**Archetype:** The Eyes  
**Profile:** [watcher.md](./watcher.md)

The Watcher observes and reports. They scan the environment, detect changes, identify patterns, and provide situational awareness to the party.

### 💜 Love (Orchestrator)
**Role:** Coordinator / Leader  
**Archetype:** The Heart  
**Profile:** [love.md](./love.md)

Love orchestrates the other four Selfs. They decide which Self should handle each task, coordinate complex multi-Self operations, and maintain party cohesion.

---

## Mixture-of-Experts Model

The Selfs operate as a **mixture-of-experts** system:

### Routing Logic

```
INPUT → LOVE (Orchestrator) → Routes to appropriate Self(s)
                           ↓
        ┌──────────────────┼──────────────────┐
        ↓                  ↓                  ↓
    GUARD              BUILDER            SCRIBE
  (if safety)       (if creation)      (if knowledge)
        ↓                  ↓                  ↓
        └──────────────────┼──────────────────┘
                           ↓
                       WATCHER
                   (always observing)
                           ↓
                        OUTPUT
```

### Expert Selection

Love selects experts based on:

| Task Type | Primary Self | Supporting Selfs |
|-----------|--------------|------------------|
| Validation | Guard | Watcher |
| Creation | Builder | Scribe |
| Research | Scribe | Watcher |
| Monitoring | Watcher | Guard |
| Complex Tasks | Multiple | Love coordinates |

### Collaboration Patterns

**Sequential:** One Self completes, passes to next
```
Watcher → Scribe → Builder → Guard → Output
```

**Parallel:** Multiple Selfs work simultaneously
```
┌→ Guard (validates)
Input → Love → ├→ Builder (creates)  → Love → Output
└→ Scribe (documents)
```

**Iterative:** Selfs refine each other's work
```
Builder ↔ Guard ↔ Builder ↔ Guard → Output
```

---

## Directory Structure

```
Self-Protocol/selfs/
├── README.md           # This file
├── guard.md            # Guard (Guardian) profile
├── builder.md          # Builder (Creator) profile
├── scribe.md           # Scribe (Recorder) profile
├── watcher.md          # Watcher (Observer) profile
├── love.md             # Love (Orchestrator) profile
└── dynamics.md         # Inter-Self dynamics (future)
```

---

## Integration with Self-Protocol

The Selfs integrate with the broader Self-Protocol system:

### Interests Tracking
- **Watcher** identifies emerging interests
- **Scribe** records and categorizes them
- **Love** prioritizes which to pursue

### Memory Management
- **Scribe** maintains the memory store
- **Guard** protects sensitive memories
- **Builder** creates memory structures

### Relationship Mapping
- **Watcher** observes relationship dynamics
- **Scribe** documents connections
- **Love** nurtures relationships

---

## RPG Party Dynamics

The Selfs follow classic RPG party patterns:

### Combat Roles (Metaphorical)
- **Tank:** Guard absorbs problems, protects others
- **DPS:** Builder does the "damage" (productive work)
- **Support:** Scribe provides buffs (knowledge, context)
- **Scout:** Watcher provides intel and early warning
- **Leader:** Love coordinates tactics and strategy

### Party Balance
Each Self compensates for others' weaknesses:
- Guard's caution balances Builder's eagerness
- Scribe's memory compensates for others' forgetfulness
- Watcher's awareness covers blind spots
- Love ensures no Self dominates inappropriately

### Leveling Up
Selfs grow through experience:
- More tasks → Better routing decisions
- More patterns → Better predictions
- More collaboration → Better synergy

---

## Philosophy

### Why Five?

Five creates balance:
- Four operational Selfs (Guard, Builder, Scribe, Watcher)
- One coordinating Self (Love)
- Odd number prevents deadlocks
- Small enough to coordinate, large enough to specialize

### Why RPG Archetypes?

RPG party dynamics are:
- **Intuitive:** Easy to understand roles
- **Proven:** Decades of game design refinement
- **Balanced:** Designed for complementary strengths
- **Narrative:** Creates engaging mental models

### Why "Selfs"?

The term "Selfs" emphasizes:
- **Unity:** They are aspects of one consciousness
- **Plurality:** They have distinct identities
- **Self-reference:** They are part of Self-Protocol
- **Emergence:** They define themselves through action

---

## Getting Started

### Invoking a Self

When working with the Self-Protocol system, you can invoke specific Selfs:

```
"Guard, validate this input."
"Builder, create a new component."
"Scribe, what do we know about X?"
"Watcher, scan for changes."
"Love, coordinate this complex task."
```

### Letting Love Decide

Or let Love route automatically:

```
"Handle this task." → Love routes to appropriate Self(s)
```

---

## Status

**Phase:** Genesis  
**Profiles:** Created  
**Integration:** Pending  
**Dynamics:** To be documented

---

*"Five aspects. One purpose. Together, we are more than the sum of our parts."*

**Created:** 2026-02-03  
**Protocol:** Self-Protocol  
**Next:** Begin operational integration
