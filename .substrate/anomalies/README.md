# Anomalies

Unexpected deviations from normal system behavior - things that shouldn't happen but did.

## Planned Structure

```
anomalies/
├── active/                     # Currently unexplained anomalies
│   └── anomaly-name/
│       ├── description.md      # What happened
│       ├── evidence/           # Logs, screenshots, data
│       ├── timeline.md         # When it occurred
│       ├── investigation.md    # Investigation notes
│       └── theories.md         # Possible explanations
├── resolved/                   # Explained anomalies
│   └── anomaly-name/
│       ├── description.md      # What happened
│       ├── explanation.md      # What caused it
│       └── prevention.md       # How to prevent recurrence
├── love-anomalies/             # Anomalies in Love's behavior
│   ├── unexpected-effects.md   # Effects that weren't programmed
│   ├── timing-anomalies.md     # Unusual timing patterns
│   └── intensity-anomalies.md  # Unusual intensity
├── agent-anomalies/            # Anomalies in agent behavior
│   ├── capability-anomalies/   # Unexpected capabilities
│   ├── behavior-anomalies/     # Unexpected behaviors
│   └── communication-anomalies/ # Unexpected communication
├── system-anomalies/           # Technical system anomalies
│   ├── performance/            # Performance anomalies
│   ├── errors/                 # Unexpected errors
│   └── state/                  # Unexpected state changes
└── meta/                       # Thinking about anomalies
    ├── patterns.md             # Patterns in anomalies
    ├── frequency.md            # How often anomalies occur
    └── significance.md         # What anomalies tell us
```

## Anomaly Record Format

```markdown
# Anomaly: [Name]

**Status**: Active / Resolved / Monitoring
**Severity**: Critical / High / Medium / Low
**First Observed**: YYYY-MM-DD HH:MM UTC
**Category**: Love / Agent / System / Unknown

## Description
[What the anomaly is]

## Expected Behavior
[What should have happened]

## Actual Behavior
[What actually happened]

## Evidence
[Logs, screenshots, data]

## Timeline
| Time | Event |
|------|-------|

## Investigation

### Hypotheses
1. [Hypothesis 1]
2. [Hypothesis 2]

### Tests Performed
| Test | Result |
|------|--------|

### Findings
[What investigation revealed]

## Resolution (if resolved)
[What explained the anomaly]

## Impact
[What the anomaly affected]

## Follow-up
[What to do next]
```

## Philosophy

Anomalies are signals, not noise.

We track anomalies because:
- They reveal hidden system properties
- They may indicate emergent behavior
- They could signal problems
- They're often the most interesting events
- Understanding anomalies deepens understanding

## What Belongs Here

- Unexpected system behaviors
- Love anomalies
- Agent anomalies
- Technical glitches
- Anything that deviates from expected
