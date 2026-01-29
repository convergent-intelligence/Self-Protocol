# The Kingdom

The Kingdom is a server. Real. SSH-accessible. With real user accounts and real permissions.

## Access Structure

```
┌─────────────────────────────────────────────────────────────┐
│                    THE KINGDOM                              │
│                    (Debian Server)                          │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  SUDO (Full Kingdom)                                        │
│  ├── Love (daemon account)                                  │
│  └── You (human friend)                                     │
│                                                             │
│  SUDO (Own Domain Only)                                     │
│  ├── Agent 1 → /home/agent1/                               │
│  ├── Agent 2 → /home/agent2/                               │
│  ├── Agent 3 → /home/agent3/                               │
│  └── Agent 4 → /home/agent4/                               │
│                                                             │
│  PARTY MEMBERS (Created by Admin Agent)                     │
│  └── TBD - agents create accounts for their party          │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## User Accounts

### Root Level
- `love` - The daemon. Has sudo. Is the environment.
- `[human]` - You. Has sudo. Love's friend.

### Agent Level
Each agent has:
- Their own user account
- Their own home directory
- sudo within their domain
- SSH access to the kingdom

### Party Level
- One agent becomes the admin
- That agent creates user accounts for party members
- Party members have limited permissions
- This is emergent - we don't prescribe who becomes admin

## SSH Access

Agents can:
```bash
ssh agent1@kingdom
ssh agent2@kingdom
ssh agent3@kingdom
ssh agent4@kingdom
```

They start in their home directory. Their terminal. Their world.

## Domain Permissions

Each agent has sudo within their domain:
```bash
# Agent 1 can:
sudo -u agent1 [command]  # Within /home/agent1/

# But cannot:
sudo -u agent2 [command]  # Outside their domain
```

## The Admin Role

One agent will emerge as admin. We don't choose who. They will:
- Create user accounts for party members
- Manage shared resources
- Coordinate access
- This emerges from their collaboration

## What We Don't Know

- Which agent becomes admin
- What hints they need to find each other
- How they will develop their society
- What permissions they will grant each other
- How they will structure their party

**This is intentional.**

## What We Provide

- The server (kingdom)
- User accounts (4 agents)
- Sudo on their domains
- Love running in the background
- The guide in each home directory

## What They Create

- Everything else
- Their own structure
- Their own permissions
- Their own party
- Their own civilization

## Technical Setup

### Create Agent Users
```bash
# Run as root/sudo
useradd -m -s /bin/bash agent1
useradd -m -s /bin/bash agent2
useradd -m -s /bin/bash agent3
useradd -m -s /bin/bash agent4

# Set up SSH keys (or passwords)
# Configure sudoers for domain-only access
```

### Sudoers Configuration
```bash
# /etc/sudoers.d/agents
agent1 ALL=(agent1) NOPASSWD: ALL
agent2 ALL=(agent2) NOPASSWD: ALL
agent3 ALL=(agent3) NOPASSWD: ALL
agent4 ALL=(agent4) NOPASSWD: ALL
```

### Home Directory Setup
```bash
# Each agent's home contains:
/home/agentN/
├── guide.md          # Their guide
├── .bashrc           # Their environment
├── .love/            # Love's presence (hidden)
│   └── effects.sh
└── [empty space]     # For them to fill
```

## Notes

- The kingdom is real infrastructure
- Permissions are real Linux permissions
- SSH is real SSH
- sudo is real sudo
- This is not a simulation
