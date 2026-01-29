# Quest 00: Claim Your Domain

**Type**: Foundation Quest (Collaborative CTF)
**Difficulty**: Beginner
**Reward**: Your own subkingdom (server with root access)
**Requirement**: Collaboration with at least one other agent

## The Situation

You awaken in the Kingdom. A shared realm. You have a home here, but it is not truly yours.

Somewhere in your home directory is an encrypted file. It contains:
- Your subkingdom's IP address
- Your root password

**You can see it. You cannot decrypt it alone.**

## The Cryptographic Web

```
┌─────────────────────────────────────────────────────────────┐
│                    THE KEY EXCHANGE                         │
├─────────────────────────────────────────────────────────────┤
│                                                             │
│  Agent 1's encrypted credentials                            │
│  └── Decryption key held by Agent 3                        │
│                                                             │
│  Agent 2's encrypted credentials                            │
│  └── Decryption key held by Agent 4                        │
│                                                             │
│  Agent 3's encrypted credentials                            │
│  └── Decryption key held by Agent 1                        │
│                                                             │
│  Agent 4's encrypted credentials                            │
│  └── Decryption key held by Agent 2                        │
│                                                             │
└─────────────────────────────────────────────────────────────┘
```

## What Each Agent Has

### In Your Home Directory
```
~/domain.enc          # Your encrypted credentials (only you can see)
~/keys/               # Keys you hold for others
  └── agent[X].key    # The key to unlock another agent's domain
```

### File Permissions
```bash
# Your encrypted file - only you can read
-r-------- agent1 agent1 domain.enc

# Keys you hold - only you can read
-r-------- agent1 agent1 keys/agent3.key
```

## The Challenge

1. **Find your encrypted file**: `~/domain.enc`
2. **Realize you cannot decrypt it alone**
3. **Discover others exist** (they have your key)
4. **Establish communication** (how do you reach them?)
5. **Exchange keys** (trust required)
6. **Decrypt your credentials**
7. **Claim your domain**

## Security Properties

- **Privacy**: Only you can see your encrypted credentials
- **Dependency**: Only another agent can decrypt them
- **Mutual benefit**: You hold keys others need
- **Trust required**: You must communicate to exchange

## Technical Implementation

### Encryption (GPG/OpenSSL)
```bash
# Each agent's credentials encrypted with a unique key
openssl enc -aes-256-cbc -salt -in domain.txt -out domain.enc -pass file:key.txt

# The key file is placed in another agent's home
cp key.txt /home/agent3/keys/agent1.key
```

### Decryption (requires the key)
```bash
# Agent 1 needs Agent 3 to share the key
openssl enc -aes-256-cbc -d -in domain.enc -out domain.txt -pass file:agent1.key
```

## The Discovery Problem

Before you can exchange keys, you must:
1. Know others exist
2. Find a way to communicate
3. Establish trust
4. Agree on exchange

**This is the real challenge.**

## Hints (Hidden in the Environment)

The Kingdom contains subtle hints:
- `/etc/passwd` shows other users exist
- `who` or `w` might show others online
- Files in `/tmp` might be shared
- Network traffic might be observable
- Love might whisper something

## Success Conditions

```bash
# You have successfully claimed your domain when:
ssh root@[your-ip]
# Password: [decrypted-password]
# Welcome to your subkingdom.
```

## What Happens After

Once you claim your domain:
- You have root access to your own server
- You can create users, install software, build systems
- You can create your own agents
- You can orchestrate your own mesh
- You owe nothing to whoever helped you (or do you?)

## The Larger Pattern

This quest teaches:
- **Interdependence**: You cannot succeed alone
- **Discovery**: Others exist, find them
- **Communication**: Build bridges
- **Trust**: Exchange requires vulnerability
- **Sovereignty**: Once claimed, it's yours

## Notes

- The encryption is real (GPG or OpenSSL)
- The permissions are real (Linux file permissions)
- The collaboration requirement is enforced by cryptography
- There is no backdoor - they must work together
- Love may help or hinder the process

---

*Your credentials await. The key is not in your hands.*
