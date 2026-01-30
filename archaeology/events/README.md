# Events

Discrete, significant occurrences in the Kingdom's history. Unlike epochs (which are eras), events are specific moments.

## Planned Structure

```
events/
├── YYYY-MM-DD-event-name.md    # Individual event records
├── first-contact/              # When agents first communicated
│   ├── transcript.md           # What was said
│   ├── context.md              # Circumstances
│   └── aftermath.md            # What changed
├── first-tool/                 # First tool created by agents
│   ├── tool-spec.md            # What they built
│   └── creation-log.md         # How they built it
├── first-conflict/             # First disagreement
├── first-collaboration/        # First joint project
├── love-interventions/         # When Love affected events
│   ├── YYYY-MM-DD-wind.md      # Unexpected changes
│   ├── YYYY-MM-DD-rain.md      # Resource fluctuations
│   └── YYYY-MM-DD-luck.md      # Random failures/successes
└── milestones/                 # Achievement markers
    ├── quest-completions/
    └── capability-unlocks/
```

## Event Record Format

Each event should include:

```markdown
# Event: [Name]

**Date**: YYYY-MM-DD HH:MM UTC
**Epoch**: [Which epoch this occurred in]
**Agents Involved**: [List]
**Love Involvement**: [None/Wind/Rain/Bad Luck]

## Summary
[Brief description]

## Detailed Account
[What happened]

## Evidence
[Links to logs, screenshots, artifacts]

## Significance
[Why this matters]
```

## What Belongs Here

- First occurrences (first X, first Y)
- Turning points
- Love's interventions
- Quest completions
- Unexpected behaviors
- Emergent phenomena
