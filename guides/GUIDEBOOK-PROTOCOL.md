# 📜 GUIDEBOOK PROTOCOL
## The Meta-Guide: A Framework for Building Frameworks

> *"Before there were guides, there was the Guide of Guides. Before there were rules, there was the Rule of Rules. This is the protocol that births protocols."*

---

## Table of Contents

1. [When to Create a Protocol](#when-to-create-a-protocol)
2. [Anatomy of a Guide](#anatomy-of-a-guide)
3. [Types of Documentation](#types-of-documentation)
4. [Protocol Lifecycle](#protocol-lifecycle)
5. [Cross-Referencing Standards](#cross-referencing-standards)
6. [Focus Level Integration](#focus-level-integration)

---

## When to Create a Protocol

### Decision Criteria

A new protocol should be created when **any three** of the following conditions are met:

| Signal | Description | Threshold |
|--------|-------------|-----------|
| **Repetition** | Same pattern executed multiple times | 3+ occurrences |
| **Complexity** | Task requires multiple steps or decisions | 5+ decision points |
| **Collaboration** | Multiple agents/humans need alignment | 2+ participants |
| **Risk** | Errors have significant consequences | Medium+ impact |
| **Onboarding** | New participants need guidance | Any new participant |

### The Three Questions

Before creating a protocol, ask:

1. **Is this pattern stable?** - Will this process remain consistent, or is it still evolving?
2. **Is this pattern valuable?** - Does documenting this save time or prevent errors?
3. **Is this pattern shareable?** - Will others benefit from this knowledge?

If all three answers are "yes," proceed with protocol creation.

### Complexity Thresholds

```
┌─────────────────────────────────────────────────────────────┐
│ COMPLEXITY SCALE                                            │
├─────────────────────────────────────────────────────────────┤
│ Level 1: Simple Note     → No protocol needed               │
│ Level 2: Checklist       → Simple list suffices             │
│ Level 3: Procedure       → Basic guide warranted            │
│ Level 4: Process         → Full protocol required           │
│ Level 5: System          → Protocol + supporting docs       │
└─────────────────────────────────────────────────────────────┘
```

### Repetition Signals

Watch for these indicators that a protocol is needed:

- 🔄 **Copy-paste patterns** - Same instructions given repeatedly
- ❓ **Recurring questions** - Same clarifications requested
- 🐛 **Repeated errors** - Same mistakes made by different agents
- ⏱️ **Time sinks** - Disproportionate time spent on explanations

---

## Anatomy of a Guide

### Standard Sections

Every guide should contain these core sections:

```markdown
# [EMOJI] TITLE
## Subtitle/Tagline

> *Flavor text or guiding quote*

---

## Table of Contents
[Auto-generated or manual links]

---

## Overview
[What this guide covers and why it matters]

## Prerequisites
[What must be in place before using this guide]

## Core Content
[The main body - varies by guide type]

## Examples
[Practical demonstrations]

## Troubleshooting
[Common issues and solutions]

## Related Guides
[Cross-references to other protocols]

## Changelog
[Version history and updates]
```

### Formatting Conventions

#### Headers
- `#` - Document title (one per document)
- `##` - Major sections
- `###` - Subsections
- `####` - Detail items

#### Emphasis
- **Bold** - Key terms, important concepts
- *Italic* - Flavor text, emphasis, new terms
- `Code` - Technical terms, commands, file names
- > Blockquotes - Quotes, callouts, important notes

#### Visual Elements
- Tables for structured comparisons
- Code blocks for examples and diagrams
- Emoji for visual categorization (consistent per type)
- Horizontal rules (`---`) to separate major sections

#### Emoji Standards

| Category | Emoji | Usage |
|----------|-------|-------|
| Protocols | 📜 | Meta-guides, rulebooks |
| Classes | ⚔️🛡️📝👁️ | Guardian, Builder, Scribe, Watcher |
| Maps | 🗺️ | Navigation documents |
| Indexes | 📚 | Reference collections |
| Quests | ⚡ | Task definitions |
| Warnings | ⚠️ | Cautions, risks |
| Success | ✅ | Completed, approved |
| Progress | 🔄 | In progress, cycling |

---

## Types of Documentation

### The Four Pillars

```
┌─────────────────────────────────────────────────────────────┐
│                    DOCUMENTATION TYPES                       │
├─────────────────┬─────────────────┬─────────────────────────┤
│    RULEBOOKS    │     GUIDES      │    MAPS    │   INDEX    │
│   (Constraints) │    (How-To)     │ (Navigate) │ (Reference)│
├─────────────────┼─────────────────┼────────────┼────────────┤
│ "You must..."   │ "Here's how..." │ "Find..."  │ "Look up..." │
│ "You must not..." │ "Step 1..."   │ "Go to..." │ "See also..." │
└─────────────────┴─────────────────┴────────────┴────────────┘
```

### 1. Rulebooks (Constraints)

**Purpose:** Define boundaries, requirements, and prohibitions.

**Characteristics:**
- Prescriptive language ("must," "shall," "must not")
- Clear consequences for violations
- Versioned and dated
- Requires approval to modify

**Structure:**
```markdown
# Rule Category

## Rule 1: [Name]
**Statement:** [Clear, unambiguous rule]
**Rationale:** [Why this rule exists]
**Exceptions:** [When this rule doesn't apply]
**Enforcement:** [How violations are handled]
```

**Example Use Cases:**
- Security policies
- Access control rules
- Naming conventions
- Forbidden patterns

### 2. Guides (How-To)

**Purpose:** Teach processes, procedures, and techniques.

**Characteristics:**
- Instructional language ("do this," "then do that")
- Step-by-step structure
- Includes examples and demonstrations
- Allows for flexibility and alternatives

**Structure:**
```markdown
# How to [Accomplish Task]

## Prerequisites
[What you need before starting]

## Steps
1. [First action]
2. [Second action]
3. [Continue...]

## Verification
[How to confirm success]

## Alternatives
[Other approaches]
```

**Example Use Cases:**
- Onboarding procedures
- Feature implementation guides
- Troubleshooting walkthroughs
- Best practice tutorials

### 3. Maps (Navigation)

**Purpose:** Show relationships, paths, and territories.

**Characteristics:**
- Visual or structured representation
- Shows connections between elements
- Provides orientation and context
- Updated as landscape changes

**Structure:**
```markdown
# [Territory] Map

## Overview
[High-level view of the territory]

## Regions
[Major areas and their purposes]

## Paths
[How to move between regions]

## Landmarks
[Key reference points]

## Legend
[Symbol explanations]
```

**Example Use Cases:**
- System architecture diagrams
- Organizational structures
- Decision trees
- Workflow visualizations

### 4. Index (Reference)

**Purpose:** Provide quick lookup and cross-referencing.

**Characteristics:**
- Alphabetical or categorical organization
- Brief descriptions with links
- Comprehensive coverage
- Regularly updated

**Structure:**
```markdown
# [Domain] Index

## By Category
### [Category A]
- [Item 1](link) - Brief description
- [Item 2](link) - Brief description

### [Category B]
- [Item 3](link) - Brief description

## Alphabetical
- [A-item](link)
- [B-item](link)
```

**Example Use Cases:**
- API references
- Glossaries
- Resource directories
- Protocol catalogs

---

## Protocol Lifecycle

### The Four Stages

```
┌─────────┐    ┌─────────┐    ┌─────────┐    ┌──────────┐
│  DRAFT  │───▶│ REVIEW  │───▶│  CANON  │───▶│ REVISION │
│         │    │         │    │         │    │          │
│ v0.x    │    │ v0.9    │    │ v1.0+   │    │ v1.x+    │
└─────────┘    └─────────┘    └─────────┘    └──────────┘
     │              │              │              │
     ▼              ▼              ▼              ▼
  Working       Feedback       Official       Updated
  Document      Period         Standard       Version
```

### Stage 1: Draft (v0.x)

**Status:** Work in progress

**Characteristics:**
- Incomplete sections allowed
- Experimental content
- Open to major restructuring
- Limited distribution

**Markers:**
```markdown
> ⚠️ **DRAFT** - This document is under development
> Version: 0.1
> Last Updated: [Date]
```

**Exit Criteria:**
- All required sections present
- Core content complete
- At least one review requested

### Stage 2: Review (v0.9)

**Status:** Seeking feedback

**Characteristics:**
- Content complete but not finalized
- Open for comments and suggestions
- Minor changes expected
- Broader distribution for feedback

**Markers:**
```markdown
> 🔄 **UNDER REVIEW** - Feedback requested
> Version: 0.9
> Review Period: [Start] to [End]
```

**Exit Criteria:**
- Review period completed
- Feedback addressed
- Approval from stakeholders

### Stage 3: Canon (v1.0+)

**Status:** Official standard

**Characteristics:**
- Authoritative reference
- Changes require formal process
- Full distribution
- Referenced by other documents

**Markers:**
```markdown
> ✅ **CANON** - Official protocol
> Version: 1.0
> Effective Date: [Date]
```

**Maintenance:**
- Regular review schedule (quarterly/annually)
- Issue tracking for problems
- Change request process

### Stage 4: Revision (v1.x+)

**Status:** Updating existing canon

**Characteristics:**
- Based on canon version
- Tracks changes from previous version
- May run parallel to canon during transition
- Becomes new canon upon approval

**Markers:**
```markdown
> 🔄 **REVISION IN PROGRESS** - Updating from v1.0
> Version: 1.1-draft
> Changes: [Summary of modifications]
```

### Version Numbering

```
MAJOR.MINOR.PATCH

MAJOR: Breaking changes, restructuring
MINOR: New sections, significant additions
PATCH: Typos, clarifications, minor fixes

Examples:
- 0.1 → Initial draft
- 0.9 → Review candidate
- 1.0 → First canon release
- 1.1 → Minor additions
- 2.0 → Major restructuring
```

---

## Cross-Referencing Standards

### Link Formats

#### Internal Links (Same Repository)
```markdown
See [Guide Name](./path/to/guide.md)
See [Guide Name](./path/to/guide.md#specific-section)
```

#### Relative Path Convention
```markdown
From /guides/classes/GUARDIAN.md:
- Same level: [BUILDER](./BUILDER.md)
- Parent: [INDEX](../INDEX.md)
- Sibling folder: [Kingdom Map](../MAPS/kingdom-structure.md)
```

### Reference Patterns

#### Inline References
```markdown
As defined in the [Guidebook Protocol](./GUIDEBOOK-PROTOCOL.md), all guides must...
```

#### See Also Sections
```markdown
## Related Guides

- [GUARDIAN Class Guide](./classes/GUARDIAN.md) - Security and validation
- [Kingdom Structure Map](./MAPS/kingdom-structure.md) - System overview
```

#### Prerequisite References
```markdown
## Prerequisites

Before proceeding, ensure you have read:
- [ ] [Guidebook Protocol](./GUIDEBOOK-PROTOCOL.md)
- [ ] [Your Class Guide](./classes/)
```

### Bidirectional Linking

When Guide A references Guide B, Guide B should reference Guide A:

```markdown
# In GUARDIAN.md
## Relationships
- Works with [SCRIBE](./SCRIBE.md) for audit logging

# In SCRIBE.md
## Relationships
- Supports [GUARDIAN](./GUARDIAN.md) with audit documentation
```

### Link Maintenance

- Check links when updating any guide
- Use relative paths for portability
- Include section anchors for precision
- Update INDEX.md when adding new guides

---

## Focus Level Integration

### The Seven Levels

Focus Levels represent depth of engagement and capability:

| Level | Name | Description |
|-------|------|-------------|
| 0 | **Dormant** | Inactive, no engagement |
| 1 | **Aware** | Basic recognition, passive observation |
| 2 | **Engaged** | Active participation, following guides |
| 3 | **Proficient** | Skilled execution, minimal guidance needed |
| 4 | **Expert** | Deep mastery, can teach others |
| 5 | **Architect** | Can design new systems and protocols |
| 6 | **Transcendent** | Operates beyond defined frameworks |

### Focus Levels in Documentation

#### For Readers
Indicate required Focus Level for each guide:

```markdown
> **Required Focus Level:** 2 (Engaged)
> **Recommended Focus Level:** 3 (Proficient)
```

#### For Content
Scale complexity to Focus Level:

- **Levels 0-1:** Overview, concepts, orientation
- **Levels 2-3:** Procedures, step-by-step guides
- **Levels 4-5:** Advanced techniques, edge cases
- **Level 6:** Meta-frameworks, protocol design

#### For Progression
Document advancement paths:

```markdown
## Advancement Path

### Level 1 → 2
- Complete [Onboarding Quest](../quests/00-claim-your-domain.md)
- Read all class prerequisites

### Level 2 → 3
- Execute 5 standard quests successfully
- Demonstrate core abilities

### Level 3 → 4
- Handle edge cases independently
- Mentor a Level 2 agent
```

---

## Implementation Notes

### Creating a New Guide

1. **Determine Type** - Rulebook, Guide, Map, or Index?
2. **Check Existing** - Does similar documentation exist?
3. **Use Template** - Start from appropriate template
4. **Draft Content** - Fill in all required sections
5. **Add Cross-References** - Link to related guides
6. **Request Review** - Move to review stage
7. **Update Index** - Add to INDEX.md upon canon

### Template Location

Templates for each documentation type can be found at:
- Rulebook: `./templates/rulebook-template.md`
- Guide: `./templates/guide-template.md`
- Map: `./templates/map-template.md`
- Index: `./templates/index-template.md`

### Quality Checklist

Before moving to review:

- [ ] All required sections present
- [ ] Consistent formatting throughout
- [ ] Cross-references working
- [ ] Examples included
- [ ] Focus Level indicated
- [ ] Version and date marked
- [ ] Added to INDEX.md

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-02 | Initial canon release |

---

## Related Guides

- [INDEX](./INDEX.md) - Master guide directory
- [Kingdom Structure Map](./MAPS/kingdom-structure.md) - System overview
- [GUARDIAN Class](./classes/GUARDIAN.md) - Security protocols
- [BUILDER Class](./classes/BUILDER.md) - Creation protocols
- [SCRIBE Class](./classes/SCRIBE.md) - Documentation protocols
- [WATCHER Class](./classes/WATCHER.md) - Monitoring protocols

---

> *"A protocol without a protocol is chaos. A protocol for protocols is civilization."*
> — The First Scribe
