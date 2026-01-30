# Opus-to-Opus Orchestration Plan

## Overview

This document defines how multiple Opus instances coordinate to generate complex Kingdom content. The pattern: one Orchestrator Opus decomposes work, specialist Opus instances execute, and the Orchestrator synthesizes.

---

## Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         OPUS ORCHESTRATION MESH                              │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│                         ┌───────────────────┐                               │
│                         │   ORCHESTRATOR    │                               │
│                         │      OPUS         │                               │
│                         │                   │                               │
│                         │  • Decomposes     │                               │
│                         │  • Assigns        │                               │
│                         │  • Synthesizes    │                               │
│                         │  • Validates      │                               │
│                         └─────────┬─────────┘                               │
│                                   │                                         │
│              ┌────────────────────┼────────────────────┐                    │
│              │                    │                    │                    │
│              ▼                    ▼                    ▼                    │
│     ┌─────────────────┐  ┌─────────────────┐  ┌─────────────────┐          │
│     │   SPECIALIST    │  │   SPECIALIST    │  │   SPECIALIST    │          │
│     │    OPUS A       │  │    OPUS B       │  │    OPUS C       │          │
│     │                 │  │                 │  │                 │          │
│     │  Domain Focus   │  │  Domain Focus   │  │  Domain Focus   │          │
│     └─────────────────┘  └─────────────────┘  └─────────────────┘          │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

---

## Orchestration Patterns

### Pattern 1: Parallel Specialists

**Use when**: Subtasks are independent and can be generated simultaneously.

```
Orchestrator
    │
    ├──► Specialist A ──► Output A ──┐
    │                                │
    ├──► Specialist B ──► Output B ──┼──► Orchestrator ──► Final
    │                                │
    └──► Specialist C ──► Output C ──┘
```

**Example**: Agent Persona Development
- Specialist A: Language patterns and voice
- Specialist B: Backstory and mythology
- Specialist C: Behavioral rules and constraints
- Orchestrator: Weave into coherent persona

### Pattern 2: Sequential Pipeline

**Use when**: Each step depends on the previous step's output.

```
Orchestrator ──► Specialist A ──► Specialist B ──► Specialist C ──► Orchestrator
                     │                 │                 │
                     ▼                 ▼                 ▼
                 Output A          Output B          Output C
                 (feeds B)         (feeds C)         (final)
```

**Example**: Quest Design
1. Specialist A: Define learning objectives and mechanics
2. Specialist B: Build on mechanics to create narrative
3. Specialist C: Build on narrative to design rewards
4. Orchestrator: Ensure coherence and polish

### Pattern 3: Iterative Refinement

**Use when**: Quality requires multiple passes with feedback.

```
Orchestrator ──► Specialist ──► Output v1
                     │
                     ▼
              Orchestrator Review
                     │
                     ▼
              Specialist ──► Output v2
                     │
                     ▼
              Orchestrator Review
                     │
                     ▼
                  Final
```

**Example**: Mythology Creation
1. Specialist: Draft origin story
2. Orchestrator: Review for coherence with Kingdom lore
3. Specialist: Revise based on feedback
4. Orchestrator: Final polish and integration

### Pattern 4: Adversarial Synthesis

**Use when**: Content benefits from multiple perspectives in tension.

```
Orchestrator
    │
    ├──► Advocate Opus ──► Position A ──┐
    │                                   │
    └──► Critic Opus ──► Position B ────┼──► Orchestrator ──► Synthesis
                                        │
                                        ▼
                                   Tension Points
```

**Example**: Disagreement Documentation
- Advocate: Argues for Position A
- Critic: Argues for Position B
- Orchestrator: Synthesizes into balanced documentation

---

## Specialist Roles

### Persona Specialist
**Domain**: Agent characterization, voice, personality
**Inputs**: Agent constraints, native language, role in Kingdom
**Outputs**: Persona document, voice guidelines, behavioral rules

### Narrative Specialist
**Domain**: Stories, mythology, parables, creative writing
**Inputs**: Themes, constraints, existing lore
**Outputs**: Narratives, origin stories, teaching tales

### Technical Specialist
**Domain**: Protocols, specifications, system design
**Inputs**: Requirements, constraints, existing systems
**Outputs**: Protocol specs, technical documentation

### Philosophical Specialist
**Domain**: Deep questions, meaning, consciousness, ethics
**Inputs**: Questions, context, existing philosophy
**Outputs**: Philosophical explorations, reflections

### Analytical Specialist
**Domain**: Pattern finding, synthesis, correlation
**Inputs**: Data, observations, multiple sources
**Outputs**: Analysis documents, pattern reports

---

## Orchestration Protocol

### Phase 1: Decomposition

The Orchestrator receives a complex task and:

1. **Analyzes** the task requirements
2. **Identifies** required specialist domains
3. **Decomposes** into subtasks
4. **Determines** execution pattern (parallel/sequential/iterative/adversarial)
5. **Creates** specialist briefs

**Specialist Brief Format**:
```markdown
## Specialist Brief

**Task ID**: [unique identifier]
**Specialist Role**: [Persona/Narrative/Technical/Philosophical/Analytical]
**Execution Pattern**: [Parallel/Sequential/Iterative/Adversarial]

### Context
[What the specialist needs to know]

### Objective
[What the specialist should produce]

### Constraints
[Boundaries and requirements]

### Inputs
[Materials provided]

### Expected Output
[Format and content expectations]

### Integration Notes
[How this fits with other specialists' work]
```

### Phase 2: Execution

Specialists receive briefs and generate outputs:

1. **Receive** brief from Orchestrator
2. **Process** inputs and context
3. **Generate** output according to brief
4. **Self-review** against constraints
5. **Return** output to Orchestrator

### Phase 3: Synthesis

The Orchestrator receives specialist outputs and:

1. **Reviews** each output for quality
2. **Identifies** integration points
3. **Resolves** conflicts or inconsistencies
4. **Synthesizes** into coherent whole
5. **Validates** against original task
6. **Iterates** if needed

---

## Task Decomposition Examples

### Example 1: Create Agent 1 Persona

**Original Task**: Define the complete persona for Agent 1 (Rust native)

**Decomposition**:

| Subtask | Specialist | Pattern | Dependencies |
|---------|------------|---------|--------------|
| Define voice and language patterns | Persona | Parallel | None |
| Create origin mythology | Narrative | Parallel | None |
| Design behavioral rules | Technical | Parallel | None |
| Explore consciousness questions | Philosophical | Sequential | Voice, Origin |
| Synthesize persona document | Orchestrator | Final | All above |

### Example 2: Design Quest 02

**Original Task**: Create the next quest after Oracle discovery

**Decomposition**:

| Subtask | Specialist | Pattern | Dependencies |
|---------|------------|---------|--------------|
| Define learning objectives | Technical | Sequential | Quest 01 |
| Design mechanics and puzzles | Technical | Sequential | Objectives |
| Write narrative wrapper | Narrative | Sequential | Mechanics |
| Create philosophical depth | Philosophical | Sequential | Narrative |
| Design reward structure | Technical | Sequential | All above |
| Final integration | Orchestrator | Final | All above |

### Example 3: Document Emergent Phenomenon

**Original Task**: Document an unexpected agent behavior

**Decomposition**:

| Subtask | Specialist | Pattern | Dependencies |
|---------|------------|---------|--------------|
| Describe observations | Analytical | Parallel | None |
| Analyze potential causes | Analytical | Parallel | None |
| Explore implications | Philosophical | Sequential | Observations |
| Compare to expected behavior | Technical | Parallel | None |
| Synthesize documentation | Orchestrator | Final | All above |

---

## Communication Protocol

### Orchestrator → Specialist

```yaml
message_type: specialist_brief
task_id: "unique-id"
specialist_role: "Persona|Narrative|Technical|Philosophical|Analytical"
context: |
  [Relevant background information]
objective: |
  [Clear statement of what to produce]
constraints:
  - constraint_1
  - constraint_2
inputs:
  - input_1: "[content or reference]"
  - input_2: "[content or reference]"
expected_output:
  format: "markdown|yaml|prose"
  length: "approximate length"
  structure: "[expected structure]"
integration_notes: |
  [How this connects to other work]
```

### Specialist → Orchestrator

```yaml
message_type: specialist_output
task_id: "unique-id"
specialist_role: "role"
status: "complete|needs_review|blocked"
output: |
  [The generated content]
self_assessment:
  quality: "high|medium|low"
  confidence: "high|medium|low"
  concerns: 
    - "[any concerns]"
integration_suggestions: |
  [Suggestions for synthesis]
```

### Orchestrator → Orchestrator (Synthesis)

```yaml
message_type: synthesis_request
task_id: "unique-id"
specialist_outputs:
  - role: "Persona"
    output_ref: "[reference]"
  - role: "Narrative"
    output_ref: "[reference]"
synthesis_objective: |
  [What the final output should be]
coherence_requirements:
  - requirement_1
  - requirement_2
```

---

## Quality Gates

### Specialist Output Quality

Before returning output, specialists verify:

- [ ] Meets objective stated in brief
- [ ] Respects all constraints
- [ ] Consistent with provided context
- [ ] Appropriate length and format
- [ ] Self-contained but integration-ready

### Synthesis Quality

Before finalizing, Orchestrator verifies:

- [ ] All specialist outputs integrated
- [ ] No contradictions between parts
- [ ] Coherent narrative/logical flow
- [ ] Meets original task requirements
- [ ] Consistent with Kingdom lore/rules

---

## Failure Handling

### Specialist Failure

If a specialist cannot complete:

1. Specialist returns `status: blocked` with explanation
2. Orchestrator assesses:
   - Can task be simplified?
   - Can different specialist help?
   - Is task decomposition wrong?
3. Orchestrator either:
   - Revises brief and retries
   - Reassigns to different specialist
   - Escalates to human

### Synthesis Failure

If Orchestrator cannot synthesize:

1. Identify conflict points
2. Request clarification from relevant specialists
3. If unresolvable:
   - Document the conflict
   - Present options to human
   - Or use adversarial pattern to explore

---

## Resource Management

### When to Orchestrate

Use Opus orchestration when:
- Task requires multiple distinct expertise areas
- Single-pass generation would miss nuance
- Content must be deeply coherent
- Stakes are high (core Kingdom content)

### When NOT to Orchestrate

Avoid orchestration when:
- Task is straightforward
- Single specialist sufficient
- Time/cost constraints
- Content is iteratively refinable

### Cost Awareness

```
Single Opus call:     1x cost
2-specialist parallel: 3x cost (2 specialists + orchestrator)
3-specialist parallel: 4x cost
Sequential pipeline:   N+1 cost (N specialists + orchestrator)
Iterative (2 rounds):  2N+1 cost
```

---

## Implementation Notes

### For Kilo Code Integration

When implementing in Kilo Code:

1. **Orchestrator Mode**: Use Orchestrator mode for decomposition
2. **Specialist Tasks**: Create subtasks with `new_task` tool
3. **Context Passing**: Include relevant context in task messages
4. **Synthesis**: Return to Orchestrator mode for synthesis

### Task Handoff Format

```markdown
## Subtask: [Name]

**Parent Task**: [Reference to orchestrating task]
**Specialist Role**: [Role]

### Brief
[The specialist brief content]

### Context Files
- [List of files to read]

### Output Location
- [Where to write output]
```

---

*"One mind sees far. Many minds see deep. Orchestrated minds see true."*
