# The Guidebook Protocol

*A Meta-Framework for Creating Rulebooks, Guides, Maps, and Indexes*

**Protocol Status:** Canon  
**Version:** 1.0  
**Focus Level:** 3 (Structured Creation)

---

## Purpose

This document is the **guide on guides**—a meta-framework that establishes how Kingdom documentation should be created, structured, maintained, and evolved. Every rulebook, guide, map, and index in the Kingdom should follow these principles.

> *"Before you write the rules, understand the rules of writing rules."*

---

## Part I: When to Create a Protocol

### Decision Criteria

Not everything needs a formal protocol. Use this decision tree:

```
                    ┌─────────────────────────┐
                    │ Is this knowledge that  │
                    │ others will need?       │
                    └───────────┬─────────────┘
                                │
                    ┌───────────┴───────────┐
                    │                       │
                   YES                      NO
                    │                       │
                    ▼                       ▼
        ┌───────────────────┐      ┌───────────────────┐
        │ Will it be used   │      │ Personal notes    │
        │ more than twice?  │      │ are sufficient    │
        └─────────┬─────────┘      └───────────────────┘
                  │
        ┌─────────┴─────────┐
        │                   │
       YES                  NO
        │                   │
        ▼                   ▼
┌───────────────────┐  ┌───────────────────┐
│ CREATE A PROTOCOL │  │ Create a note in  │
│                   │  │ relevant location │
└───────────────────┘  └───────────────────┘
```

### Complexity Thresholds

Create a formal protocol when:

| Threshold | Indicator | Action |
|-----------|-----------|--------|
| **Complexity** | More than 5 steps to complete | Create a Guide |
| **Constraints** | Rules that must not be broken | Create a Rulebook |
| **Navigation** | Multiple paths through a system | Create a Map |
| **Reference** | Information needed for lookup | Create an Index |

### Repetition Signals

Watch for these signals that indicate a protocol is needed:

1. **The Third Question** — When the same question is asked three times, document the answer
2. **The Forgotten Step** — When a step is repeatedly missed, formalize the process
3. **The Tribal Knowledge** — When only one agent knows how to do something, capture it
4. **The Inconsistency** — When the same task is done differently each time, standardize it

---

## Part II: Anatomy of a Guide

### Standard Sections

Every guide should include these sections (adapt as needed):

```markdown
# [Title]

*[Tagline or brief description]*

**Protocol Status:** [Draft | Review | Canon | Deprecated]
**Version:** [X.Y]
**Focus Level:** [0-6]

---

## Purpose
Why this guide exists and who it serves.

## Prerequisites
What must be true before using this guide.

## Core Content
The main body of the guide.

## Examples
Concrete illustrations of the concepts.

## Edge Cases
What to do in unusual situations.

## Related Protocols
Links to connected documentation.

## Changelog
History of significant changes.
```

### Formatting Standards

#### Headers
- **H1 (#)**: Document title only
- **H2 (##)**: Major sections
- **H3 (###)**: Subsections
- **H4 (####)**: Minor divisions

#### Emphasis
- **Bold**: Key terms, important warnings
- *Italic*: Definitions, quotes, emphasis
- `Code`: Commands, file paths, technical terms

#### Lists
- Use bullet points for unordered items
- Use numbered lists for sequential steps
- Use tables for structured comparisons

#### Code Blocks
```
Use fenced code blocks for:
- Commands
- File contents
- Diagrams (ASCII art)
- Examples
```

#### Callouts
> *Use blockquotes for important notes, warnings, or philosophical asides.*

---

## Part III: Documentation Types

### 1. Rulebooks (Constraints)

**Purpose:** Define what MUST and MUST NOT be done.

**Characteristics:**
- Prescriptive, not descriptive
- Clear consequences for violations
- Versioned and change-controlled
- Authority clearly stated

**Structure:**
```markdown
# [Rulebook Name]

## Authority
Who created these rules and why they bind.

## Scope
What these rules apply to.

## The Rules
1. RULE: [Statement]
   - Rationale: Why this rule exists
   - Violation: What happens if broken
   - Exceptions: When this rule does not apply

## Enforcement
How violations are detected and handled.
```

**Example Use Cases:**
- Security protocols
- Economic constraints
- Communication standards
- Behavioral boundaries

---

### 2. Guides (How-To)

**Purpose:** Teach how to accomplish a task.

**Characteristics:**
- Step-by-step instructions
- Assumes specific starting point
- Leads to defined outcome
- Includes troubleshooting

**Structure:**
```markdown
# [Guide Name]

## Goal
What you will accomplish.

## Prerequisites
What you need before starting.

## Steps
1. First step
   - Details
   - Expected result
2. Second step
   ...

## Verification
How to confirm success.

## Troubleshooting
Common problems and solutions.
```

**Example Use Cases:**
- Quest completion guides
- Tool usage instructions
- Communication protocols
- Onboarding procedures

---

### 3. Maps (Navigation)

**Purpose:** Show how things relate and how to navigate between them.

**Characteristics:**
- Visual or structured representation
- Shows relationships and paths
- Multiple entry points
- Updated as structure changes

**Structure:**
```markdown
# [Map Name]

## Overview
What this map covers.

## The Map
[Visual representation - ASCII, Mermaid, or description]

## Legend
Explanation of symbols and conventions.

## Paths
Common routes through the map.

## Landmarks
Key locations and their significance.
```

**Example Use Cases:**
- Kingdom directory structure
- Quest progression paths
- Agent relationship networks
- Information flow diagrams

---

### 4. Indexes (Reference)

**Purpose:** Enable quick lookup of information.

**Characteristics:**
- Alphabetical or categorical organization
- Brief entries with links to details
- Comprehensive coverage
- Regularly updated

**Structure:**
```markdown
# [Index Name]

## How to Use This Index
Instructions for finding information.

## Categories
[If organized by category]

## Entries

### A
- **Term**: Brief definition. [Link to details]

### B
...
```

**Example Use Cases:**
- Glossary of terms
- Tool inventory
- Quest catalog
- Agent registry

---

## Part IV: Protocol Lifecycle

### States

```
┌─────────┐     ┌─────────┐     ┌─────────┐     ┌─────────────┐
│  DRAFT  │────▶│ REVIEW  │────▶│  CANON  │────▶│ DEPRECATED  │
└─────────┘     └─────────┘     └─────────┘     └─────────────┘
     │               │               │
     │               │               │
     ▼               ▼               ▼
┌─────────────────────────────────────────────────────────────┐
│                        REVISION                              │
│         (Can return to any previous state)                   │
└─────────────────────────────────────────────────────────────┘
```

### State Definitions

| State | Meaning | Who Can Edit | Authority |
|-------|---------|--------------|-----------|
| **Draft** | Work in progress | Anyone | None yet |
| **Review** | Ready for feedback | Designated reviewers | Provisional |
| **Canon** | Official, authoritative | Change-controlled | Full |
| **Deprecated** | No longer current | Archive only | Historical |
| **Revision** | Being updated | Designated editors | Suspended |

### Transitions

#### Draft → Review
- All required sections complete
- At least one example provided
- Self-review completed
- Review request submitted

#### Review → Canon
- Feedback addressed
- No blocking objections
- Authority confirmed
- Version number assigned

#### Canon → Revision
- Change request approved
- Revision scope defined
- Editor assigned
- Timeline established

#### Canon → Deprecated
- Replacement identified (if applicable)
- Migration path documented
- Deprecation notice added
- Archive date set

---

## Part V: Cross-Referencing Standards

### Link Format

Use relative paths for internal links:
```markdown
[Link Text](../path/to/document.md)
```

### Reference Conventions

When referencing other protocols:

```markdown
See [Protocol Name](path/to/protocol.md) for details on [topic].
```

When referencing specific sections:

```markdown
As defined in [Protocol Name § Section](path/to/protocol.md#section-anchor)
```

### Dependency Declaration

At the top of documents that depend on others:

```markdown
**Dependencies:**
- [Required Protocol 1](path/to/protocol1.md)
- [Required Protocol 2](path/to/protocol2.md)
```

### Backlinks

When a document is referenced by others, maintain a "Referenced By" section:

```markdown
## Referenced By
- [Document A](path/to/a.md)
- [Document B](path/to/b.md)
```

---

## Part VI: Focus Level Integration

### Focus Levels Defined

| Level | Name | Documentation Scope |
|-------|------|---------------------|
| **0** | Dormant | No active documentation needed |
| **1** | Aware | Basic orientation documents |
| **2** | Engaged | Task-specific guides |
| **3** | Structured | Comprehensive protocols |
| **4** | Mastery | Advanced techniques, edge cases |
| **5** | Teaching | Training materials, examples |
| **6** | Transcendent | Meta-documentation, philosophy |

### Matching Documentation to Focus Level

- **Focus 0-1**: Keep documentation minimal, essential only
- **Focus 2-3**: Provide complete guides with examples
- **Focus 4-5**: Include advanced topics, teaching materials
- **Focus 6**: Meta-level documentation like this protocol

---

## Part VII: Quality Standards

### The Five Qualities

Every protocol should embody:

1. **Clarity** — Can be understood on first reading
2. **Completeness** — Covers all necessary information
3. **Correctness** — Accurate and up-to-date
4. **Consistency** — Follows established patterns
5. **Conciseness** — No unnecessary content

### Review Checklist

Before submitting for review:

- [ ] Purpose is clearly stated
- [ ] Prerequisites are listed
- [ ] All steps are actionable
- [ ] Examples are provided
- [ ] Edge cases are addressed
- [ ] Links are valid
- [ ] Formatting is consistent
- [ ] Version is specified
- [ ] Focus Level is assigned

---

## Part VIII: Templates

### Quick-Start Templates

Templates are available in [`/guides/templates/`](templates/):

- [`rulebook-template.md`](templates/rulebook-template.md)
- [`guide-template.md`](templates/guide-template.md)
- [`map-template.md`](templates/map-template.md)
- [`index-template.md`](templates/index-template.md)

### Using Templates

1. Copy the appropriate template
2. Replace placeholder text
3. Remove unused sections
4. Add content
5. Submit for review

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-02 | Initial canon release |

---

## Related Protocols

- [INDEX.md](INDEX.md) — Master index of all guides
- [MAPS/kingdom-structure.md](MAPS/kingdom-structure.md) — Kingdom structure visualization
- [classes/](classes/) — Class-specific guides

---

*"Good documentation is not written. It is cultivated—planted, tended, pruned, and allowed to grow."*
