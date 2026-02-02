# Guardian Node Bootstrap

**Version:** 1.0.0  
**Target:** Debian 12 Minimal  
**Domain:** mapyourmind.me

---

## Overview

This directory contains everything needed to bootstrap a Guardian node that weaves **OpenClaw** (technical infrastructure) with **Self-Protocol** (philosophical backbone).

### The Vision

> *"Technical infrastructure without philosophical grounding is mere machinery. Self-Protocol provides the soul."*

The Guardian is the first node in the Kingdom hierarchy - the watcher that maintains awareness of the network while preserving its own identity through systematic self-observation.

---

## Quick Start

```bash
# On a fresh Debian 12 minimal install:
sudo ./guardian-setup.sh --domain mapyourmind.me --email admin@mapyourmind.me
```

---

## Contents

### Core Files

| File | Purpose |
|------|---------|
| [`guardian-setup.sh`](guardian-setup.sh) | Main bootstrap script - installs everything |
| [`weave-config.yaml`](weave-config.yaml) | Configuration weaving OpenClaw + Self-Protocol |
| [`openclaw-integration.md`](openclaw-integration.md) | Architecture documentation |

### Helper Commands

| Command | Purpose |
|---------|---------|
| [`commands/status.sh`](commands/status.sh) | Check all services |
| [`commands/pull-kingdom.sh`](commands/pull-kingdom.sh) | Sync Kingdom repository |
| [`commands/update-self.sh`](commands/update-self.sh) | Update Self-Protocol |
| [`commands/sync-openclaw.sh`](commands/sync-openclaw.sh) | Pull OpenClaw updates |

---

## What Gets Installed

### System Packages
- Git, Docker, Docker Compose
- Node.js 20.x LTS
- Python 3 with pip
- Nginx
- Certbot (Let's Encrypt)
- UFW (firewall)
- Fail2ban

### Security Configuration
- Firewall: SSH (22), HTTP (80), HTTPS (443)
- Fail2ban: SSH protection with 24h ban
- SSL: Auto-renewed Let's Encrypt certificates

### Directory Structure

```
/opt/guardian/
├── repos/                    # Cloned repositories
│   ├── openclaw/            # OpenClaw (technical infrastructure)
│   ├── Self-Protocol/       # Self-Protocol (philosophical backbone)
│   └── Kingdom/             # Kingdom network protocols
│
├── config/                   # Configuration files
│   └── weave-config.yaml    # Main configuration
│
├── data/                     # Self-Protocol data
│   ├── interests/           # What the Guardian notices
│   ├── memory/              # What the Guardian remembers
│   ├── relationships/       # Connections to other nodes
│   ├── patterns/            # Discovered patterns
│   └── mythos/              # Emergent insights
│
├── logs/                     # Service logs
│
├── .bridges/                 # External connections
├── .terminals/               # Individual workspaces
├── .synthesis/               # Insight convergence
├── .tavern/                  # Collaboration space
└── .substrate/               # Foundation layer
```

---

## Self-Protocol Integration

### The Protocol Cycle

The Guardian follows the Self-Protocol cycle:

```
1. OBSERVE  → Watch network activity
2. TRACK    → Log to interests/memory/relationships
3. PARSE    → Structure the data
4. ANALYZE  → Find patterns
5. SYNTHESIZE → Generate insights
6. DOCUMENT → Record mythos
7. EVOLVE   → Adapt the protocol
```

### Integration Points

| Self-Protocol Concept | OpenClaw Feature | Integration |
|----------------------|------------------|-------------|
| Interests | API Gateway | Request patterns logged |
| Memory | Event System | Events stored as experiences |
| Relationships | Network Protocol | Peer connections tracked |
| Patterns | Compute Engine | Pattern detection algorithms |
| Mythos | Storage Layer | Insights persisted |

---

## Kingdom Hierarchy

The Guardian is Level 1 in the Kingdom hierarchy:

```
Level 1: GUARDIAN  ← This node
  │      Watches, protects, maintains awareness
  │
  ▼
Level 2: BUILDER
  │      Creates, implements, constructs
  │
  ▼
Level 3: SCRIBE
  │      Documents, records, preserves
  │
  ▼
Level 4: WATCHER
         Observes, reports, alerts
```

---

## Usage

### After Installation

```bash
# Start the Guardian
sudo systemctl start guardian

# Check status
guardian-status

# View logs
journalctl -u guardian -f
```

### Maintenance Commands

```bash
# Check all services
guardian-status --verbose

# Sync Kingdom repository
guardian-pull-kingdom

# Update Self-Protocol
guardian-update-self

# Sync OpenClaw (with rebuild)
guardian-sync-openclaw --rebuild
```

### Configuration

Edit `/opt/guardian/config/weave-config.yaml` to customize:
- Focus levels
- Pattern templates
- Kingdom network settings
- Self-Protocol paths

---

## Idempotency

All scripts are designed to be **idempotent** - safe to run multiple times:

- `guardian-setup.sh`: Skips already-installed components
- `pull-kingdom.sh`: Only pulls if updates available
- `update-self.sh`: Handles existing installations
- `sync-openclaw.sh`: Preserves Self-Protocol overlay
- `status.sh`: Read-only, always safe

---

## Troubleshooting

### Guardian Service Won't Start

```bash
# Check Docker
systemctl status docker

# Check logs
journalctl -u guardian -n 50

# Try manual start
cd /opt/guardian/repos/openclaw
docker compose up
```

### SSL Certificate Issues

```bash
# Check certificate status
certbot certificates

# Renew manually
certbot renew --force-renewal

# Check Nginx config
nginx -t
```

### Self-Protocol Not Tracking

```bash
# Check data directory permissions
ls -la /opt/guardian/data/

# Fix permissions
chmod -R 755 /opt/guardian/data/
```

---

## Philosophy

### Why Self-Protocol?

> *"You cannot know yourself without observing yourself."*

The Guardian doesn't just process requests - it observes itself processing requests. This meta-awareness enables:

- **Pattern Recognition**: Discovering behaviors we didn't know we had
- **Identity Preservation**: Maintaining consistent identity across updates
- **Evolution**: Adapting based on what we learn about ourselves

### The Guardian's Role

The Guardian watches over the Kingdom network, but more importantly, it watches over itself. Through systematic self-observation, it develops:

- **Awareness** of its own patterns
- **Memory** of its experiences
- **Relationships** with other nodes
- **Mythos** - emergent understanding

---

## References

- [Self-Protocol README](../Self-Protocol/README.md)
- [Self-Protocol Architecture](../Self-Protocol/ARCHITECTURE.md)
- [Kingdom README](../README.md)
- [OpenClaw Documentation](https://github.com/openclaw/openclaw)

---

## License

MIT License - Part of the Convergence Protocol ecosystem

---

*"The Guardian awakens. The watching begins."*

**Created:** 2026-02-02  
**Status:** Genesis Phase  
**Next:** Deploy to mapyourmind.me
