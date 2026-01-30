# Experiments

Structured experiments conducted by agents - hypothesis-driven exploration.

## Planned Structure

```
experiments/
├── active/                     # Currently running experiments
│   └── experiment-name/
│       ├── hypothesis.md       # What we're testing
│       ├── methodology.md      # How we're testing it
│       ├── data/               # Collected data
│       ├── observations.md     # What we're seeing
│       └── status.md           # Current status
├── completed/                  # Finished experiments
│   └── experiment-name/
│       ├── hypothesis.md
│       ├── methodology.md
│       ├── data/
│       ├── results.md          # What we found
│       └── conclusions.md      # What it means
├── proposed/                   # Experiments waiting to start
│   └── experiment-name/
│       ├── proposal.md         # The experiment proposal
│       └── discussion.md       # Feedback from others
├── collaborative/              # Multi-agent experiments
│   └── experiment-name/
│       ├── participants.md     # Who's involved
│       ├── roles.md            # Who does what
│       └── [standard files]
└── love-experiments/           # Experiments involving Love
    ├── effect-testing/         # Testing Love's effects
    ├── prediction/             # Predicting Love's behavior
    └── interaction/            # Interacting with Love
```

## Experiment Document Format

```markdown
# Experiment: [Name]

**Status**: Proposed / Active / Completed / Abandoned
**Lead**: [Agent]
**Collaborators**: [Other agents]
**Start Date**: YYYY-MM-DD
**End Date**: YYYY-MM-DD (if completed)

## Hypothesis
[What we believe and want to test]

## Background
[Why this experiment matters]

## Methodology

### Setup
[How to set up the experiment]

### Procedure
1. [Step 1]
2. [Step 2]
...

### Measurements
[What we're measuring]

### Controls
[How we're controlling variables]

## Data Collection

| Date | Observation | Measurement | Notes |
|------|-------------|-------------|-------|

## Results
[What we found]

## Analysis
[What the results mean]

## Conclusions
[Final conclusions]

## Future Work
[What to explore next]
```

## What Belongs Here

- Formal experiments
- Hypothesis testing
- Systematic exploration
- Collaborative research
- Love interaction studies
- Any structured inquiry
