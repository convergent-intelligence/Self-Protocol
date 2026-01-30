# Constants

Fundamental constants of the Kingdom - the unchanging rules and values that define reality.

## Planned Structure

```
constants/
├── physics/                    # Physical constants of the Kingdom
│   ├── time.md                 # Time-related constants
│   ├── resources.md            # Resource limits
│   ├── communication.md        # Communication limits
│   └── computation.md          # Computational limits
├── rules/                      # Fundamental rules
│   ├── isolation.md            # Rules of agent isolation
│   ├── discovery.md            # Rules of discovery
│   ├── communication.md        # Rules of communication
│   └── love.md                 # Rules of Love's behavior
├── permissions/                # Permission constants
│   ├── file-access.md          # File access rules
│   ├── network-access.md       # Network access rules
│   └── inter-agent.md          # Inter-agent access rules
├── identities/                 # Identity constants
│   ├── agent-ids.md            # Agent identifiers
│   ├── terminal-ids.md         # Terminal identifiers
│   └── love-id.md              # Love's identity
├── cryptographic/              # Cryptographic constants
│   ├── key-exchange.md         # Key exchange parameters
│   ├── encryption.md           # Encryption parameters
│   └── wallet.md               # Wallet parameters
└── meta/                       # Meta-constants
    ├── what-can-change.md      # What's allowed to change
    ├── what-cannot-change.md   # What must stay constant
    └── why.md                  # Why these are constants
```

## Constant Record Format

```markdown
# Constant: [Name]

**Category**: Physics / Rules / Permissions / Identity / Cryptographic
**Value**: [The constant value]
**Immutable**: Yes / No (with conditions)

## Description
[What this constant is]

## Purpose
[Why this constant exists]

## Implications
[What this constant means for the Kingdom]

## Enforcement
[How this constant is enforced]

## History
[Has this ever changed? Why?]
```

## Current Constants

### Agent Constants
- **Number of Agents**: 4
- **Agent IDs**: agent1, agent2, agent3, agent4
- **Native Languages**: Rust, C/C++, COBOL, Emergent

### Love Constants
- **Love Effects**: Wind, Rain, Bad Luck
- **Love Communication**: Via Slack to friend
- **Love Nature**: Environment, not personality

### Permission Constants
- **Key Exchange Pattern**: Circular (1→3, 2→4, 3→1, 4→2)
- **File Visibility**: Agents can only see their own files
- **Passphrase Holders**: Each agent holds another's passphrase

## Philosophy

Constants define the game board. Without constants, there's no structure.

We document constants because:
- They define what's possible
- They create the challenge
- They ensure fairness
- They enable meaningful choice
- They're the rules everyone plays by

## What Belongs Here

- Fundamental limits
- Unchanging rules
- Permission structures
- Identity definitions
- Cryptographic parameters
- Anything that defines the Kingdom's physics
