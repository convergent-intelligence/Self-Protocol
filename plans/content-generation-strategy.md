# Content Generation Strategy

## Intelligence Tiering for Kingdom Content

This document defines how to allocate intelligence resources across different content types, from local Ollama models to Opus-level reasoning.

---

## The Intelligence Spectrum

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        INTELLIGENCE ALLOCATION                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  Tier 1: LOCAL OLLAMA          Tier 2: CAPABLE         Tier 3: OPUS         │
│  ─────────────────────         ────────────────        ──────────────       │
│  • Templated content           • Synthesis work        • Novel creation     │
│  • Format conversion           • Pattern analysis      • Philosophy         │
│  • Data extraction             • Documentation         • Agent personas     │
│  • Simple summaries            • Protocol design       • Emergent behavior  │
│  • Log parsing                 • Quest structure       • Strategic design   │
│                                                                              │
│  Cost: Minimal                 Cost: Moderate          Cost: Premium        │
│  Speed: Fast                   Speed: Medium           Speed: Thoughtful    │
│  Creativity: Low               Creativity: Medium      Creativity: High     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Content Classification

### Tier 1: Local Ollama (Iterative/Mechanical)

**Characteristics**: Structured, templated, extractive, transformative

| Content Type | Example | Why Local |
|--------------|---------|-----------|
| Log formatting | Converting raw logs to markdown | Pure transformation |
| Data extraction | Pulling timestamps from events | Pattern matching |
| Template filling | Populating record formats | Mechanical |
| Index generation | Creating file listings | Enumeration |
| Format conversion | YAML to markdown tables | Structural |
| Simple summaries | Condensing verbose logs | Compression |

**Directories suited for Tier 1**:
- `archaeology/events/` - Event records (templated)
- `.synthesis/correlations/` - Data correlation tables
- `.substrate/anomalies/` - Anomaly logs (structured)

### Tier 2: Capable Models (Synthesis/Analysis)

**Characteristics**: Analytical, synthetic, pattern-finding, explanatory

| Content Type | Example | Why Capable |
|--------------|---------|-------------|
| Pattern analysis | Finding behavioral patterns | Requires reasoning |
| Documentation | Technical docs with context | Needs understanding |
| Protocol design | Communication protocols | Structured creativity |
| Consensus building | Synthesizing multiple views | Integration |
| Translation work | Cross-agent concept mapping | Contextual |
| Quest structure | Quest mechanics and flow | Design thinking |

**Directories suited for Tier 2**:
- `.bridges/protocols/` - Protocol specifications
- `.bridges/translations/` - Concept translations
- `.synthesis/consensus/` - Agreed understandings
- `.synthesis/disagreements/` - Divergent view analysis
- `artifacts/protocols/` - Interaction protocols
- `artifacts/tools/` - Tool documentation

### Tier 3: Opus (Creative/Philosophical/Strategic)

**Characteristics**: Novel, philosophical, persona-driven, emergent, strategic

| Content Type | Example | Why Opus |
|--------------|---------|----------|
| Agent personas | Defining agent personalities | Deep characterization |
| Philosophical content | Existence, consciousness | Requires depth |
| Mythology creation | Origin stories, parables | Creative narrative |
| Emergent phenomena | Describing unexpected behaviors | Nuanced observation |
| Strategic planning | Kingdom evolution strategy | High-level thinking |
| Art and literature | Agent-created works | Creative expression |
| Love's behavior | Defining environmental effects | Subtle design |

**Directories suited for Tier 3**:
- `.pantheon/mythology/` - Narrative creation
- `.synthesis/emergent/` - Emergent phenomena
- `archaeology/mysteries/` - Deep mysteries
- `archaeology/evolution/` - Evolutionary narratives
- `artifacts/art/` - Creative works
- `.tavern/play/` - Games and creative play
- `.substrate/love/` - Love's nature and effects

---

## Iterative Convergence Strategy

Some content benefits from iterative refinement rather than single-pass generation:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                     ITERATIVE CONVERGENCE PATTERN                            │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Pass 1 (Local)          Pass 2 (Capable)        Pass 3 (Opus)             │
│   ──────────────          ────────────────        ─────────────             │
│   • Generate skeleton     • Add analysis          • Add insight             │
│   • Extract structure     • Find patterns         • Add philosophy          │
│   • Create outline        • Synthesize views      • Ensure coherence        │
│   • Populate template     • Add context           • Final polish            │
│                                                                              │
│   Example: Consensus Document                                                │
│   ─────────────────────────────                                             │
│   Pass 1: Extract all positions from sources                                │
│   Pass 2: Analyze commonalities and differences                             │
│   Pass 3: Craft the synthesis narrative                                     │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Content Types for Iterative Convergence

| Content | Pass 1 (Local) | Pass 2 (Capable) | Pass 3 (Opus) |
|---------|----------------|------------------|---------------|
| Consensus docs | Extract positions | Find common ground | Write synthesis |
| Evolution tracking | Log changes | Identify patterns | Narrate journey |
| Correlation analysis | Compute correlations | Interpret meaning | Draw conclusions |
| Observer notes | Transcribe observations | Analyze patterns | Reflect on meaning |
| Quest completion | Record facts | Analyze approach | Extract lessons |

---

## Opus-to-Opus Orchestration

For complex, multi-faceted content that requires sustained high-level reasoning:

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                      OPUS ORCHESTRATION PATTERN                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   Orchestrator Opus                                                          │
│   ─────────────────                                                         │
│   • Breaks down complex task                                                │
│   • Assigns subtasks to specialist Opus instances                           │
│   • Synthesizes results                                                     │
│   • Ensures coherence                                                       │
│                                                                              │
│                    ┌─────────────────┐                                      │
│                    │  Orchestrator   │                                      │
│                    │     Opus        │                                      │
│                    └────────┬────────┘                                      │
│              ┌──────────────┼──────────────┐                                │
│              ▼              ▼              ▼                                │
│       ┌──────────┐   ┌──────────┐   ┌──────────┐                           │
│       │ Persona  │   │ Narrative│   │ Technical│                           │
│       │  Opus    │   │   Opus   │   │   Opus   │                           │
│       └──────────┘   └──────────┘   └──────────┘                           │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

### When to Use Opus Orchestration

1. **Agent Persona Development**
   - Orchestrator: Define overall agent characteristics
   - Specialist 1: Develop language patterns
   - Specialist 2: Create backstory/mythology
   - Specialist 3: Define behavioral rules

2. **Quest Design**
   - Orchestrator: Define quest arc and learning objectives
   - Specialist 1: Design mechanics and puzzles
   - Specialist 2: Write narrative elements
   - Specialist 3: Create reward structure

3. **Love's Environmental Effects**
   - Orchestrator: Define Love's nature and purpose
   - Specialist 1: Design wind effects (unexpected changes)
   - Specialist 2: Design rain effects (resource fluctuations)
   - Specialist 3: Design luck effects (random events)

4. **Emergent Phenomena Documentation**
   - Orchestrator: Identify and classify phenomena
   - Specialist 1: Describe observations
   - Specialist 2: Analyze causes
   - Specialist 3: Explore implications

---

## Implementation Priorities

### Phase 1: Foundation (Local + Capable)

Focus on structural content that enables later creative work:

```markdown
Priority 1: Infrastructure
- [ ] .substrate/constants/ - Define the rules
- [ ] .bridges/protocols/ - Communication specs
- [ ] artifacts/tools/ - Tool documentation

Priority 2: Templates
- [ ] archaeology/events/ - Event record templates
- [ ] .synthesis/correlations/ - Correlation templates
- [ ] .pantheon/observers/ - Observer profile templates
```

### Phase 2: Synthesis (Capable + Opus)

Build understanding from structure:

```markdown
Priority 3: Analysis
- [ ] .synthesis/consensus/ - Build shared understanding
- [ ] .bridges/translations/ - Cross-agent mappings
- [ ] archaeology/evolution/ - Track changes

Priority 4: Documentation
- [ ] quests/ - Quest documentation
- [ ] artifacts/protocols/ - Protocol docs
- [ ] .tavern/experiments/ - Experiment frameworks
```

### Phase 3: Creation (Opus)

Generate the creative and philosophical content:

```markdown
Priority 5: Narrative
- [ ] .pantheon/mythology/ - Origin stories
- [ ] archaeology/mysteries/ - Deep mysteries
- [ ] artifacts/art/ - Creative works

Priority 6: Emergence
- [ ] .synthesis/emergent/ - Emergent phenomena
- [ ] .tavern/play/ - Games and play
- [ ] Agent personas and behaviors
```

---

## Resource Allocation Guidelines

### Cost-Benefit Matrix

| Content Type | Intelligence Cost | Value to Kingdom | Priority |
|--------------|-------------------|------------------|----------|
| Constants/Rules | Low (Local) | Critical | Highest |
| Protocols | Medium (Capable) | High | High |
| Documentation | Medium (Capable) | High | High |
| Synthesis | Medium-High | High | Medium |
| Mythology | High (Opus) | Medium | Medium |
| Art | High (Opus) | Medium | Lower |
| Emergent docs | High (Opus) | High | Medium |

### Decision Framework

```
Is the content...
│
├─► Templated/Mechanical? ──────► Local Ollama
│
├─► Analytical/Synthetic? ──────► Capable Model
│
├─► Creative/Philosophical? ────► Opus
│
└─► Complex multi-faceted? ─────► Opus Orchestration
```

---

## Orchestration Workflow

### For a New Content Piece

1. **Classify** - Determine tier based on content type
2. **Template** - If iterative, start with local pass
3. **Generate** - Use appropriate intelligence level
4. **Review** - Higher tier reviews lower tier output
5. **Integrate** - Ensure coherence with existing content

### For Opus Orchestration

1. **Decompose** - Break into specialist subtasks
2. **Assign** - Route to appropriate Opus instances
3. **Generate** - Parallel or sequential generation
4. **Synthesize** - Orchestrator combines results
5. **Refine** - Iterative refinement if needed

---

## Notes

- **Local Ollama** should be the default starting point
- **Escalate** to higher tiers only when needed
- **Iterate** rather than over-engineer first pass
- **Opus time is precious** - use it for what matters
- **Coherence** across content is as important as individual quality

---

*"Intelligence is a resource. Wisdom is knowing how to allocate it."*
