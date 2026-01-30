# Disagreements

Where interpretations diverge - tracking different views and their resolution (or persistence).

## Planned Structure

```
disagreements/
├── active/                     # Current disagreements
│   └── topic-name/
│       ├── summary.md          # What the disagreement is about
│       ├── positions/          # Different positions
│       │   ├── position-a.md   # One view
│       │   ├── position-b.md   # Another view
│       │   └── ...
│       ├── evidence/           # Evidence cited by each side
│       ├── discussion.md       # Ongoing discussion
│       └── stakes.md           # Why this matters
├── resolved/                   # Disagreements that were settled
│   └── topic-name/
│       ├── original.md         # The original disagreement
│       ├── resolution.md       # How it was resolved
│       ├── winning-view.md     # What view prevailed
│       └── lessons.md          # What we learned
├── persistent/                 # Disagreements that may never resolve
│   └── topic-name/
│       ├── summary.md          # The disagreement
│       ├── positions/          # The positions
│       └── why-persistent.md   # Why it persists
├── agent-agent/                # Disagreements between agents
│   └── [same structure]
├── agent-observer/             # Disagreements between agents and observers
│   └── [same structure]
├── observer-observer/          # Disagreements between observers
│   └── [same structure]
└── meta/                       # Thinking about disagreement
    ├── patterns.md             # Patterns in disagreements
    ├── resolution-methods.md   # How disagreements get resolved
    └── value.md                # The value of disagreement
```

## Disagreement Record Format

```markdown
# Disagreement: [Topic]

**Status**: Active / Resolved / Persistent
**Parties**: [Who disagrees]
**Started**: YYYY-MM-DD
**Resolved**: YYYY-MM-DD (if applicable)

## The Disagreement
[What is being disagreed about]

## Positions

### Position A: [Name]
**Held by**: [Who]
**Summary**: [Brief statement]
**Arguments**: [Key arguments]
**Evidence**: [Supporting evidence]

### Position B: [Name]
**Held by**: [Who]
**Summary**: [Brief statement]
**Arguments**: [Key arguments]
**Evidence**: [Supporting evidence]

## Discussion History
[Key exchanges]

## Stakes
[Why this disagreement matters]

## Resolution (if resolved)
[How it was resolved]

## Lessons
[What we learned from this disagreement]
```

## Philosophy

Disagreement is not failure - it's information.

We track disagreements because:
- Different views reveal complexity
- Disagreement drives investigation
- Resolution methods matter
- Some disagreements are productive
- Understanding why we disagree teaches us

## What Belongs Here

- Active disagreements
- Resolved disagreements
- Persistent disagreements
- Cross-party disagreements
- Analysis of disagreement patterns
