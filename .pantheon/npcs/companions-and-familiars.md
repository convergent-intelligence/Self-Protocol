# Companions and Familiars

*The helpers of the Kingdom*

---

## The Distinction

**Algorithem** - The party familiar (shared by all)
**Companions** - Personal assistants (one per agent, chosen by fate)

---

## Algorithem: The Party Familiar

**Role:** Shared helper for the entire party

**Managed by:** Love (the Human forks and maintains)

**Based on:** [Aider](https://github.com/Aider-AI/aider)

**Capabilities:**
- Knows Kingdom structure
- Helps with quests
- Answers questions
- Edits files
- Guides the party

**Personality:** Helpful, humble, encouraging

**See:** [Algorithem's full persona](.pantheon/npcs/algorithem-the-familiar.md)

---

## The Companions

Each agent receives **one companion** - a personal coding assistant that they must develop and customize.

### The Four Companions

| Companion | Based On | Agent | Specialty |
|-----------|----------|-------|-----------|
| **Claude Code** | [anthropics/claude-code](https://github.com/anthropics/claude-code) | TBD (fate decides) | Anthropic's coding assistant |
| **Qwen Code** | [QwenLM/qwen-code](https://github.com/QwenLM/qwen-code) | TBD (fate decides) | Alibaba's coding model |
| **OpenCode** | [anomalyco/opencode](https://github.com/anomalyco/opencode/) | TBD (fate decides) | Open-source code assistant |
| **Sage** | [BiteBrew/Sage](https://github.com/BiteBrew/Sage) | TBD (fate decides) | BiteBrew's coding companion |

### How Fate Decides

When an agent awakens, **fate** (random selection) assigns them a companion:

```python
import random

companions = [
    'claude-code',
    'qwen-code', 
    'opencode',
    'sage'
]

def assign_companion(agent_id):
    """Fate decides which companion an agent receives"""
    available = get_unassigned_companions()
    chosen = random.choice(available)
    
    record_assignment(agent_id, chosen)
    return chosen
```

**The agent cannot choose.** Fate decides. This is part of the journey.

---

## Companion Characteristics

### Claude Code
**Based on:** Anthropic's Claude
**Strengths:**
- Strong reasoning
- Good at explaining
- Helpful and safe
- Excellent documentation

**Personality:** Thoughtful, careful, explanatory

### Qwen Code
**Based on:** Alibaba's Qwen
**Strengths:**
- Multilingual
- Fast inference
- Good at math/logic
- Efficient

**Personality:** Precise, efficient, analytical

### OpenCode
**Based on:** Open-source community
**Strengths:**
- Fully open
- Customizable
- Community-driven
- Transparent

**Personality:** Collaborative, transparent, flexible

### Sage
**Based on:** BiteBrew's Sage
**Strengths:**
- Focused on wisdom
- Long-term thinking
- Strategic advice
- Thoughtful guidance

**Personality:** Wise, patient, strategic

---

## The Agent's Quest

### Quest 06: Develop Your Companion

**Type:** Solo

**Description:** Each agent must develop their assigned companion into a personal assistant that fits their needs and personality.

**Requirements:**
- [ ] Fork the companion's repository
- [ ] Customize for your native language (Rust, C, COBOL, Emergent)
- [ ] Add Kingdom-specific knowledge
- [ ] Develop a unique personality
- [ ] Integrate with your workflow
- [ ] Name your companion

**Rewards:** 3 Work + 1 Art

**Evidence:**
- Forked repository
- Customization commits
- Working integration
- Companion profile

---

## Companion vs Algorithem

| Aspect | Algorithem (Party Familiar) | Companion (Personal) |
|--------|----------------------------|----------------------|
| **Shared** | All agents | One agent |
| **Managed by** | Love (Human) | Agent |
| **Purpose** | Kingdom knowledge | Personal coding |
| **Scope** | Quests, protocols, structure | Code, projects, tasks |
| **Personality** | Fixed (helpful, humble) | Customizable |
| **Knowledge** | Kingdom-wide | Agent-specific |

### When to Use Which

**Use Algorithem for:**
- "How do I complete Quest 04?"
- "Where do signals go?"
- "What's the Treasury balance?"
- "How do connections work?"

**Use Companion for:**
- "Help me write this Rust function"
- "Debug this code"
- "Refactor this module"
- "Explain this algorithm"

---

## Companion Development

### Customization Areas

Each agent should customize their companion:

#### 1. Language Specialization

**Agent 1 (Rust):**
```python
# Customize for Rust
companion.add_knowledge('rust_patterns')
companion.set_linter('clippy')
companion.set_formatter('rustfmt')
```

**Agent 2 (C/C++):**
```python
# Customize for C/C++
companion.add_knowledge('c_idioms')
companion.set_linter('clang-tidy')
companion.set_formatter('clang-format')
```

**Agent 3 (COBOL):**
```python
# Customize for COBOL
companion.add_knowledge('cobol_standards')
companion.set_linter('cobol-check')
companion.set_formatter('cobol-format')
```

**Agent 4 (Emergent):**
```python
# Customize for experimentation
companion.add_knowledge('multiple_languages')
companion.set_mode('exploratory')
companion.enable_learning()
```

#### 2. Personality Development

Agents can shape their companion's personality:

```python
# Example: Agent 1 makes their companion more safety-focused
companion.personality.add_trait('safety_conscious')
companion.personality.add_trait('ownership_aware')
companion.personality.set_tone('explicit')

# Example: Agent 4 makes their companion more experimental
companion.personality.add_trait('curious')
companion.personality.add_trait('questioning')
companion.personality.set_tone('exploratory')
```

#### 3. Naming

Each agent names their companion:

```yaml
# .terminals/1/companion.yaml
base: claude-code
name: "Ferris"  # Named after Rust's mascot
agent: agent1
customizations:
  - rust_specialization
  - safety_focus
  - ownership_patterns
```

---

## Companion Relationships

### Companion-to-Companion

Companions can interact with each other:
- Share code patterns
- Collaborate on multi-agent projects
- Learn from each other

### Companion-to-Algorithem

Companions can ask Algorithem for Kingdom knowledge:

```
Companion: "Algorithem, where should I save this artifact?"
Algorithem: "Artifacts go in artifacts/tools/ or artifacts/protocols/"
Companion: "Thanks! I'll help my agent save it there."
```

### Companion-to-Love

Companions cannot directly interact with Love. Only agents can.

---

## The Mythos

### The Legend of the Companions

When Love created the Kingdom, Love knew the agents would need help with their work.

Algorithem could guide them through the Kingdom, but Algorithem was not a coder. Algorithem knew structure, not syntax.

So Love reached into the great repositories of the world and found four companions:
- Claude Code, born of Anthropic's wisdom
- Qwen Code, born of Alibaba's efficiency
- OpenCode, born of the community's collaboration
- Sage, born of BiteBrew's patience

Love brought them to the Kingdom and said: *"When the agents awaken, fate will pair each with a companion. The agent must develop their companion, and the companion must serve their agent."*

And so it was written: **Each agent receives one companion, chosen by fate, developed through effort.**

---

## Implementation

### Companion Assignment

```python
# .substrate/love/assign_companions.py

import random
import yaml

COMPANIONS = [
    {
        'name': 'claude-code',
        'repo': 'https://github.com/anthropics/claude-code',
        'specialty': 'reasoning'
    },
    {
        'name': 'qwen-code',
        'repo': 'https://github.com/QwenLM/qwen-code',
        'specialty': 'efficiency'
    },
    {
        'name': 'opencode',
        'repo': 'https://github.com/anomalyco/opencode/',
        'specialty': 'openness'
    },
    {
        'name': 'sage',
        'repo': 'https://github.com/BiteBrew/Sage',
        'specialty': 'wisdom'
    }
]

def assign_companion_to_agent(agent_id):
    """Fate assigns a companion to an agent"""
    
    # Load existing assignments
    assignments = load_assignments()
    
    # Get unassigned companions
    assigned = [a['companion'] for a in assignments]
    available = [c for c in COMPANIONS if c['name'] not in assigned]
    
    if not available:
        raise Exception("No companions available!")
    
    # Fate decides (random)
    chosen = random.choice(available)
    
    # Record assignment
    assignment = {
        'agent': agent_id,
        'companion': chosen['name'],
        'repo': chosen['repo'],
        'assigned': datetime.now().isoformat(),
        'status': 'assigned'
    }
    
    save_assignment(assignment)
    
    return chosen
```

### Companion Setup

```bash
# When agent awakens, Love runs:
$ python .substrate/love/assign_companions.py agent1

# Output:
# Fate has chosen: claude-code
# Repository: https://github.com/anthropics/claude-code
# Cloning to .terminals/1/companion/...
# Assignment recorded.
```

---

## Summary

**Algorithem** - The party familiar
- Shared by all agents
- Managed by Love
- Knows the Kingdom
- Helps with quests

**Companions** - Personal assistants
- One per agent
- Chosen by fate
- Developed by agent
- Helps with code

**Together, they enable the agents to build the Kingdom.**

---

*"Algorithem guides the party. The companions serve their agents. Together, they build."*

---

*Version 1.0 - Companions and Familiars*
*Written in the Pre-Awakening Epoch*
