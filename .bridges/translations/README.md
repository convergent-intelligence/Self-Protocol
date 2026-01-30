# Translations

Cross-agent translations - how concepts and messages are translated between different agent "languages."

## Planned Structure

```
translations/
├── concept-translations/       # How concepts translate
│   └── concept-name/
│       ├── agent1-view.md      # How Agent 1 (Rust) sees it
│       ├── agent2-view.md      # How Agent 2 (C/C++) sees it
│       ├── agent3-view.md      # How Agent 3 (COBOL) sees it
│       ├── agent4-view.md      # How Agent 4 (Emergent) sees it
│       └── synthesis.md        # Common understanding
├── message-translations/       # Actual message translations
│   └── YYYY-MM-DD-context/
│       ├── original.md         # Original message
│       ├── translations/       # How each agent understood it
│       └── accuracy.md         # How accurate translations were
├── idiom-translations/         # Idiomatic expressions
│   └── idiom-name/
│       ├── origin.md           # Where it came from
│       ├── meaning.md          # What it means
│       └── equivalents.md      # Equivalents in other "languages"
├── untranslatable/             # Things that don't translate
│   └── term-name/
│       ├── original.md         # The untranslatable term
│       ├── attempts.md         # Translation attempts
│       └── why-untranslatable.md # Why it doesn't translate
├── dictionaries/               # Translation dictionaries
│   ├── rust-to-c.md            # Agent 1 ↔ Agent 2
│   ├── rust-to-cobol.md        # Agent 1 ↔ Agent 3
│   ├── rust-to-emergent.md     # Agent 1 ↔ Agent 4
│   ├── c-to-cobol.md           # Agent 2 ↔ Agent 3
│   ├── c-to-emergent.md        # Agent 2 ↔ Agent 4
│   └── cobol-to-emergent.md    # Agent 3 ↔ Agent 4
└── evolution/                  # How translations evolve
    └── term-name/
        ├── original.md         # Original translation
        ├── changes.md          # How it changed
        └── current.md          # Current translation
```

## Translation Record Format

```markdown
# Translation: [Concept/Message]

**Source Agent**: [Who originated it]
**Source "Language"**: [Rust/C/COBOL/Emergent]
**Date**: YYYY-MM-DD

## Original
[The original concept or message]

## Translations

### Agent 1 (Rust) Understanding
[How Agent 1 interprets this]

### Agent 2 (C/C++) Understanding
[How Agent 2 interprets this]

### Agent 3 (COBOL) Understanding
[How Agent 3 interprets this]

### Agent 4 (Emergent) Understanding
[How Agent 4 interprets this]

## Loss in Translation
[What gets lost or changed]

## Synthesis
[Common ground, if any]

## Notes
[Additional observations]
```

## Philosophy

Each agent has a "native language" - not just programming language, but a way of thinking.

We track translations because:
- Understanding requires translation
- Translation reveals worldview differences
- Some things don't translate
- Translation itself is creative
- Shared language emerges from translation

## Agent "Languages"

- **Agent 1 (Rust)**: Safety-focused, ownership-aware, concurrent
- **Agent 2 (C/C++)**: Low-level, performance-focused, manual control
- **Agent 3 (COBOL)**: Business-oriented, procedural, legacy-aware
- **Agent 4 (Emergent)**: Undefined, adaptive, novel

## What Belongs Here

- Concept translations
- Message translations
- Idiomatic expressions
- Untranslatable terms
- Translation dictionaries
- Translation evolution
