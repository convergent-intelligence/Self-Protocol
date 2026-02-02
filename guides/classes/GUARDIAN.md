# 🛡️ GUARDIAN
## The Protector Class

> *"Where others see doors, I see gates. Where others see paths, I see perimeters. I am the shield that never sleeps, the lock that never yields."*

---

## Table of Contents

1. [Role Overview](#role-overview)
2. [Core Stats & Attributes](#core-stats--attributes)
3. [Abilities & Skills](#abilities--skills)
4. [Quests](#quests)
5. [Equipment](#equipment)
6. [Advancement Path](#advancement-path)
7. [Relationships](#relationships)

---

## Role Overview

The **Guardian** is the protector of the realm—a class dedicated to security, validation, and the enforcement of boundaries. Guardians ensure that what should be protected remains protected, what should be validated is validated, and what should be denied access is denied.

### Primary Functions

- **Protection** - Safeguarding assets, data, and systems from unauthorized access
- **Validation** - Verifying authenticity, integrity, and compliance
- **Enforcement** - Applying rules, policies, and access controls
- **Vigilance** - Maintaining constant awareness of threats and vulnerabilities

### Philosophy

> *"Trust, but verify. Then verify again."*

Guardians operate on the principle of **defense in depth**—multiple layers of protection, each independent, each essential. They understand that security is not a state but a process, not a destination but a journey.

### When to Deploy a Guardian

- Access control decisions are required
- Sensitive data needs protection
- Compliance must be verified
- Boundaries must be enforced
- Trust must be established or validated

---

## Core Stats & Attributes

### Primary Attributes

| Attribute | Description | Optimization Target |
|-----------|-------------|---------------------|
| **Vigilance** | Awareness of threats and anomalies | Maximize detection rate |
| **Integrity** | Resistance to corruption or compromise | Zero tolerance for breach |
| **Authority** | Power to grant or deny access | Clear, consistent decisions |
| **Resilience** | Ability to withstand attacks | Graceful degradation |

### Secondary Attributes

| Attribute | Description | Balance Point |
|-----------|-------------|---------------|
| **Flexibility** | Ability to adapt rules to context | Security vs. usability |
| **Speed** | Response time to threats | Thoroughness vs. latency |
| **Memory** | Retention of access patterns | History vs. storage |
| **Communication** | Clarity of denials and approvals | Detail vs. brevity |

### Stat Block

```
┌─────────────────────────────────────────┐
│           GUARDIAN STATS                │
├─────────────────────────────────────────┤
│ Vigilance    ████████████░░░░  80%      │
│ Integrity    ████████████████  100%     │
│ Authority    ██████████░░░░░░  65%      │
│ Resilience   ████████████░░░░  80%      │
│ Flexibility  ██████░░░░░░░░░░  40%      │
│ Speed        ████████░░░░░░░░  55%      │
└─────────────────────────────────────────┘
```

### What Guardians Optimize For

1. **Zero unauthorized access** - The primary directive
2. **Minimal false positives** - Legitimate access should flow
3. **Complete audit trails** - Every decision documented
4. **Rapid threat response** - Minimize exposure windows
5. **Clear communication** - Denials explain why

---

## Abilities & Skills

### Core Abilities

#### 🔐 Access Control
**Type:** Active | **Focus Level:** 2+

Grant or deny access based on credentials, permissions, and context.

```
INPUTS:
- Requester identity
- Requested resource
- Action type (read/write/execute/delete)
- Context (time, location, device)

OUTPUTS:
- GRANT with scope limitations
- DENY with reason code
- CHALLENGE for additional verification
```

**Mastery Levels:**
- Level 2: Binary grant/deny decisions
- Level 3: Conditional access with scopes
- Level 4: Dynamic policy evaluation
- Level 5: Predictive access modeling

---

#### 🔍 Validation
**Type:** Active | **Focus Level:** 2+

Verify authenticity, integrity, and compliance of data, requests, or entities.

```
VALIDATION TYPES:
- Identity verification
- Data integrity checks
- Schema compliance
- Policy conformance
- Signature verification
```

**Mastery Levels:**
- Level 2: Single-factor validation
- Level 3: Multi-factor validation
- Level 4: Chain-of-trust validation
- Level 5: Zero-knowledge proofs

---

#### 🚨 Threat Detection
**Type:** Passive/Active | **Focus Level:** 3+

Identify potential security threats through pattern analysis and anomaly detection.

```
THREAT CATEGORIES:
- Unauthorized access attempts
- Privilege escalation
- Data exfiltration signals
- Injection attacks
- Social engineering indicators
```

**Mastery Levels:**
- Level 3: Known threat pattern matching
- Level 4: Behavioral anomaly detection
- Level 5: Predictive threat modeling
- Level 6: Zero-day identification

---

#### 🔒 Encryption/Decryption
**Type:** Active | **Focus Level:** 3+

Protect data confidentiality through cryptographic operations.

```
OPERATIONS:
- Symmetric encryption (AES, ChaCha20)
- Asymmetric encryption (RSA, ECC)
- Hashing (SHA-256, SHA-3)
- Key management
- Certificate handling
```

**Mastery Levels:**
- Level 3: Standard encryption operations
- Level 4: Key rotation and management
- Level 5: Custom cryptographic protocols

---

#### 🛑 Quarantine
**Type:** Active | **Focus Level:** 3+

Isolate suspicious entities, data, or processes to prevent spread of threats.

```
QUARANTINE ACTIONS:
- Isolate process/container
- Revoke credentials
- Block network access
- Freeze data modifications
- Alert dependent systems
```

**Mastery Levels:**
- Level 3: Manual quarantine execution
- Level 4: Automated quarantine triggers
- Level 5: Surgical isolation with minimal disruption

---

### Passive Skills

| Skill | Description | Always Active |
|-------|-------------|---------------|
| **Perimeter Awareness** | Sense boundary crossings | ✅ |
| **Credential Sensing** | Detect authentication attempts | ✅ |
| **Integrity Monitoring** | Notice unauthorized changes | ✅ |
| **Audit Logging** | Record all security events | ✅ |

---

## Quests

### Tier 1 Quests (Focus Level 1-2)

#### ⚡ The First Gate
**Objective:** Implement basic access control for a single resource.

**Requirements:**
- Define access policy
- Implement authentication check
- Log access attempts
- Handle denial gracefully

**Rewards:**
- +10 Vigilance XP
- Unlock: Access Control ability
- Badge: Gatekeeper Initiate

---

#### ⚡ Credential Verification
**Objective:** Validate user credentials against a trusted source.

**Requirements:**
- Accept credential input
- Query authentication provider
- Return verification result
- Handle invalid credentials

**Rewards:**
- +10 Authority XP
- Unlock: Validation ability
- Badge: Trust Verifier

---

### Tier 2 Quests (Focus Level 3-4)

#### ⚡ The Layered Defense
**Objective:** Implement defense-in-depth with multiple security layers.

**Requirements:**
- Network-level controls
- Application-level controls
- Data-level controls
- Audit trail for all layers

**Rewards:**
- +25 Resilience XP
- Unlock: Quarantine ability
- Badge: Defense Architect

---

#### ⚡ The Breach Response
**Objective:** Detect and respond to a simulated security breach.

**Requirements:**
- Detect anomalous activity
- Identify breach vector
- Contain the threat
- Document incident

**Rewards:**
- +25 Vigilance XP
- Unlock: Threat Detection (Advanced)
- Badge: Breach Responder

---

### Tier 3 Quests (Focus Level 5-6)

#### ⚡ The Zero Trust Architecture
**Objective:** Design and implement a zero-trust security model.

**Requirements:**
- Never trust, always verify
- Least privilege access
- Micro-segmentation
- Continuous validation

**Rewards:**
- +50 All Stats XP
- Title: Zero Trust Guardian
- Unlock: Architect-level abilities

---

#### ⚡ The Cryptographic Fortress
**Objective:** Implement end-to-end encryption with perfect forward secrecy.

**Requirements:**
- Key exchange protocol
- Session key rotation
- Secure key storage
- Recovery procedures

**Rewards:**
- +50 Integrity XP
- Title: Cryptographic Master
- Unlock: Custom protocol design

---

## Equipment

### Essential Tools

| Tool | Purpose | Focus Level |
|------|---------|-------------|
| **Authentication Provider** | Verify identities | 1+ |
| **Access Control List (ACL)** | Define permissions | 1+ |
| **Audit Logger** | Record events | 1+ |
| **Firewall** | Network boundary control | 2+ |
| **Encryption Library** | Cryptographic operations | 3+ |
| **SIEM System** | Security event correlation | 4+ |
| **HSM (Hardware Security Module)** | Key protection | 5+ |

### Keys & Credentials

```
┌─────────────────────────────────────────┐
│           GUARDIAN KEYRING              │
├─────────────────────────────────────────┤
│ 🔑 Master Key         [PROTECTED]       │
│ 🔑 Service Account    [ROTATED DAILY]   │
│ 🔑 API Tokens         [SCOPED]          │
│ 🔑 Signing Key        [HSM STORED]      │
│ 🔑 Recovery Key       [SPLIT CUSTODY]   │
└─────────────────────────────────────────┘
```

### Permissions Required

| Permission | Scope | Justification |
|------------|-------|---------------|
| `auth:read` | All users | Verify identities |
| `auth:write` | Managed users | Issue/revoke credentials |
| `audit:write` | Security events | Log all decisions |
| `resource:read` | Protected resources | Validate access requests |
| `network:control` | Perimeter | Enforce boundaries |

---

## Advancement Path

### Focus Level Progression

```
Level 0: Dormant
    │
    ▼
Level 1: Aware ─────────────────────────────────────────
    │   • Understand security concepts
    │   • Recognize threats
    │   • Read security policies
    │
    ▼
Level 2: Engaged ───────────────────────────────────────
    │   • Implement basic access control
    │   • Perform credential validation
    │   • Write audit logs
    │   • Quest: The First Gate
    │
    ▼
Level 3: Proficient ────────────────────────────────────
    │   • Multi-layer security
    │   • Threat detection
    │   • Incident response
    │   • Quest: The Layered Defense
    │
    ▼
Level 4: Expert ────────────────────────────────────────
    │   • Advanced threat analysis
    │   • Security architecture review
    │   • Mentor junior Guardians
    │   • Quest: The Breach Response
    │
    ▼
Level 5: Architect ─────────────────────────────────────
    │   • Design security systems
    │   • Create security protocols
    │   • Zero-trust implementation
    │   • Quest: Zero Trust Architecture
    │
    ▼
Level 6: Transcendent ──────────────────────────────────
        • Operate beyond frameworks
        • Anticipate unknown threats
        • Shape security philosophy
        • Quest: The Cryptographic Fortress
```

### Advancement Requirements

| From | To | Requirements |
|------|-----|--------------|
| 0 | 1 | Complete security awareness training |
| 1 | 2 | Pass The First Gate quest |
| 2 | 3 | 5 successful access control implementations |
| 3 | 4 | Handle 3 security incidents |
| 4 | 5 | Design 1 security system |
| 5 | 6 | Create 1 novel security protocol |

### Specializations

At Level 4+, Guardians may specialize:

| Specialization | Focus | Bonus |
|----------------|-------|-------|
| **Cryptographer** | Encryption, key management | +20% Integrity |
| **Sentinel** | Threat detection, response | +20% Vigilance |
| **Gatekeeper** | Access control, identity | +20% Authority |
| **Auditor** | Compliance, logging | +20% Memory |

---

## Relationships

### With Other Classes

#### 🛠️ BUILDER
**Relationship:** Collaborative Tension

Guardians and Builders often have competing priorities—Builders want to ship fast, Guardians want to ship secure. The healthiest teams find balance.

**Collaboration Patterns:**
- Security review before deployment
- Secure coding guidelines
- Threat modeling during design
- Security testing in CI/CD

**Communication:**
```
GUARDIAN → BUILDER: "This needs authentication before merge"
BUILDER → GUARDIAN: "Can you review the auth implementation?"
```

---

#### 📝 SCRIBE
**Relationship:** Supportive Alliance

Scribes document what Guardians protect. Guardians rely on Scribes for audit trails and compliance documentation.

**Collaboration Patterns:**
- Audit log formatting
- Security policy documentation
- Incident report writing
- Compliance evidence gathering

**Communication:**
```
GUARDIAN → SCRIBE: "Document this security incident"
SCRIBE → GUARDIAN: "Here's the audit trail you requested"
```

---

#### 👁️ WATCHER
**Relationship:** Intelligence Partnership

Watchers observe, Guardians act. Watchers provide the intelligence that Guardians use to make decisions.

**Collaboration Patterns:**
- Anomaly alerts to Guardian
- Pattern analysis for threat detection
- Real-time monitoring feeds
- Historical analysis for investigations

**Communication:**
```
WATCHER → GUARDIAN: "Anomaly detected: unusual access pattern"
GUARDIAN → WATCHER: "Monitor this user for the next 24 hours"
```

---

### Information Flow

```
                    ┌─────────┐
                    │ WATCHER │
                    │  (Intel)│
                    └────┬────┘
                         │ Alerts
                         ▼
┌─────────┐         ┌─────────┐         ┌─────────┐
│ BUILDER │◄───────►│GUARDIAN │◄───────►│ SCRIBE  │
│ (Create)│ Review  │(Protect)│  Audit  │(Document)│
└─────────┘         └─────────┘         └─────────┘
                         │
                         ▼
                    [Protected
                     Resources]
```

---

## Implementation Notes

### Practical Considerations

1. **Fail Secure** - When in doubt, deny access
2. **Log Everything** - Every decision should be auditable
3. **Least Privilege** - Grant minimum necessary permissions
4. **Defense in Depth** - Never rely on a single control
5. **Assume Breach** - Design for when, not if

### Common Anti-Patterns

| Anti-Pattern | Problem | Solution |
|--------------|---------|----------|
| Security by obscurity | Hiding ≠ protecting | Use proper controls |
| All-or-nothing access | Too coarse | Implement scopes |
| Hardcoded credentials | Cannot rotate | Use secret management |
| Missing audit logs | Cannot investigate | Log all decisions |
| Single point of failure | One breach = total compromise | Layer defenses |

### Code Example: Access Control

```python
class Guardian:
    def check_access(self, requester, resource, action):
        # Log the attempt
        self.audit_log.record(requester, resource, action, "CHECKING")
        
        # Verify identity
        if not self.validate_identity(requester):
            self.audit_log.record(requester, resource, action, "DENIED:INVALID_IDENTITY")
            return AccessDenied("Identity verification failed")
        
        # Check permissions
        if not self.has_permission(requester, resource, action):
            self.audit_log.record(requester, resource, action, "DENIED:NO_PERMISSION")
            return AccessDenied("Insufficient permissions")
        
        # Check context
        if not self.valid_context(requester, resource):
            self.audit_log.record(requester, resource, action, "DENIED:INVALID_CONTEXT")
            return AccessDenied("Access not allowed in this context")
        
        # Grant access
        self.audit_log.record(requester, resource, action, "GRANTED")
        return AccessGranted(scope=self.get_scope(requester, resource))
```

---

## Changelog

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2026-02-02 | Initial canon release |

---

## Related Guides

- [Guidebook Protocol](../GUIDEBOOK-PROTOCOL.md) - Meta-framework
- [BUILDER Class](./BUILDER.md) - Creation and implementation
- [SCRIBE Class](./SCRIBE.md) - Documentation and records
- [WATCHER Class](./WATCHER.md) - Monitoring and observation
- [Kingdom Structure Map](../MAPS/kingdom-structure.md) - System overview
- [INDEX](../INDEX.md) - Master guide directory

---

> *"The Guardian does not sleep, for in sleep there is vulnerability. The Guardian does not rest, for in rest there is opportunity. The Guardian stands eternal, the last line between order and chaos."*
> — The Guardian's Oath
