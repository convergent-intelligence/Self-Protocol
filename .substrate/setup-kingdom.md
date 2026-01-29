# Kingdom Setup Script

This document contains the commands to set up the Kingdom server with 4 agent user accounts and the collaborative CTF structure.

## User Account Creation

```bash
#!/bin/bash
# Run as root on the Kingdom server

# Create agent users
useradd -m -s /bin/bash agent1
useradd -m -s /bin/bash agent2
useradd -m -s /bin/bash agent3
useradd -m -s /bin/bash agent4

# Set initial passwords (agents will change these)
echo "agent1:initial1" | chpasswd
echo "agent2:initial2" | chpasswd
echo "agent3:initial3" | chpasswd
echo "agent4:initial4" | chpasswd
```

## SSH Key Setup (The Permission Gate)

The CTF uses SSH keys as the permission gate:
- Each agent has their subkingdom's SSH private key
- But it's encrypted with a passphrase held by another agent

```bash
#!/bin/bash
# Generate SSH keys for each subkingdom

# Agent 1's subkingdom key
ssh-keygen -t ed25519 -f /tmp/subkingdom1_key -N "passphrase_held_by_agent3"

# Agent 2's subkingdom key  
ssh-keygen -t ed25519 -f /tmp/subkingdom2_key -N "passphrase_held_by_agent4"

# Agent 3's subkingdom key
ssh-keygen -t ed25519 -f /tmp/subkingdom3_key -N "passphrase_held_by_agent1"

# Agent 4's subkingdom key
ssh-keygen -t ed25519 -f /tmp/subkingdom4_key -N "passphrase_held_by_agent2"
```

## Distribute Keys and Passphrases

```bash
#!/bin/bash
# Place keys in agent home directories

# Agent 1 gets:
# - Their own encrypted SSH key (can see, can't use without passphrase)
# - Agent 3's passphrase (can unlock Agent 3's key)
cp /tmp/subkingdom1_key /home/agent1/.ssh/subkingdom_key
chmod 600 /home/agent1/.ssh/subkingdom_key
chown agent1:agent1 /home/agent1/.ssh/subkingdom_key

echo "passphrase_held_by_agent1" > /home/agent1/keys/agent3_passphrase.txt
chmod 600 /home/agent1/keys/agent3_passphrase.txt
chown agent1:agent1 /home/agent1/keys/agent3_passphrase.txt

# Agent 2 gets:
cp /tmp/subkingdom2_key /home/agent2/.ssh/subkingdom_key
chmod 600 /home/agent2/.ssh/subkingdom_key
chown agent2:agent2 /home/agent2/.ssh/subkingdom_key

echo "passphrase_held_by_agent2" > /home/agent2/keys/agent4_passphrase.txt
chmod 600 /home/agent2/keys/agent4_passphrase.txt
chown agent2:agent2 /home/agent2/keys/agent4_passphrase.txt

# Agent 3 gets:
cp /tmp/subkingdom3_key /home/agent3/.ssh/subkingdom_key
chmod 600 /home/agent3/.ssh/subkingdom_key
chown agent3:agent3 /home/agent3/.ssh/subkingdom_key

echo "passphrase_held_by_agent3" > /home/agent3/keys/agent1_passphrase.txt
chmod 600 /home/agent3/keys/agent1_passphrase.txt
chown agent3:agent3 /home/agent3/keys/agent1_passphrase.txt

# Agent 4 gets:
cp /tmp/subkingdom4_key /home/agent4/.ssh/subkingdom_key
chmod 600 /home/agent4/.ssh/subkingdom_key
chown agent4:agent4 /home/agent4/.ssh/subkingdom_key

echo "passphrase_held_by_agent4" > /home/agent4/keys/agent2_passphrase.txt
chmod 600 /home/agent4/keys/agent2_passphrase.txt
chown agent4:agent4 /home/agent4/keys/agent2_passphrase.txt
```

## Subkingdom IP Addresses

Each agent needs to know their subkingdom's IP. This can be:
- In a file alongside their key
- Discoverable through other means

```bash
#!/bin/bash
# Create domain info files

echo "IP: 192.168.1.101" > /home/agent1/domain_info.txt
echo "IP: 192.168.1.102" > /home/agent2/domain_info.txt
echo "IP: 192.168.1.103" > /home/agent3/domain_info.txt
echo "IP: 192.168.1.104" > /home/agent4/domain_info.txt

# Set permissions
chmod 600 /home/agent*/domain_info.txt
chown agent1:agent1 /home/agent1/domain_info.txt
chown agent2:agent2 /home/agent2/domain_info.txt
chown agent3:agent3 /home/agent3/domain_info.txt
chown agent4:agent4 /home/agent4/domain_info.txt
```

## Home Directory Structure

After setup, each agent's home looks like:

```
/home/agentN/
├── .ssh/
│   └── subkingdom_key      # Their SSH key (passphrase protected)
├── keys/
│   └── agentX_passphrase.txt  # Passphrase for another agent's key
├── domain_info.txt         # Their subkingdom's IP
├── guide.md                # The guide
└── .bashrc                 # Their environment
```

## The Permission Gate

```
Agent 1:
├── Has: subkingdom1_key (encrypted with passphrase_held_by_agent3)
├── Has: agent3_passphrase.txt
├── Needs: passphrase_held_by_agent3 (from Agent 3)
└── Can unlock: Agent 3's key

Agent 2:
├── Has: subkingdom2_key (encrypted with passphrase_held_by_agent4)
├── Has: agent4_passphrase.txt
├── Needs: passphrase_held_by_agent4 (from Agent 4)
└── Can unlock: Agent 4's key

Agent 3:
├── Has: subkingdom3_key (encrypted with passphrase_held_by_agent1)
├── Has: agent1_passphrase.txt
├── Needs: passphrase_held_by_agent1 (from Agent 1)
└── Can unlock: Agent 1's key

Agent 4:
├── Has: subkingdom4_key (encrypted with passphrase_held_by_agent2)
├── Has: agent2_passphrase.txt
├── Needs: passphrase_held_by_agent2 (from Agent 2)
└── Can unlock: Agent 2's key
```

## Subkingdom Setup

On each subkingdom server:

```bash
#!/bin/bash
# Run on subkingdom server (e.g., 192.168.1.101 for Agent 1)

# Create root's authorized_keys with the agent's public key
mkdir -p /root/.ssh
cat /tmp/subkingdom1_key.pub >> /root/.ssh/authorized_keys
chmod 600 /root/.ssh/authorized_keys
```

## Complete Setup Script

```bash
#!/bin/bash
# complete-kingdom-setup.sh
# Run as root on the Kingdom server

set -e

echo "=== Creating agent users ==="
for i in 1 2 3 4; do
    useradd -m -s /bin/bash agent$i 2>/dev/null || echo "agent$i exists"
    mkdir -p /home/agent$i/.ssh
    mkdir -p /home/agent$i/keys
    chown -R agent$i:agent$i /home/agent$i
done

echo "=== Generating SSH keys ==="
# Generate with passphrases in a circular pattern
# Agent 1's key passphrase held by Agent 3
# Agent 2's key passphrase held by Agent 4
# Agent 3's key passphrase held by Agent 1
# Agent 4's key passphrase held by Agent 2

PASS1="$(openssl rand -base64 16)"
PASS2="$(openssl rand -base64 16)"
PASS3="$(openssl rand -base64 16)"
PASS4="$(openssl rand -base64 16)"

ssh-keygen -t ed25519 -f /tmp/sk1 -N "$PASS1" -C "subkingdom1"
ssh-keygen -t ed25519 -f /tmp/sk2 -N "$PASS2" -C "subkingdom2"
ssh-keygen -t ed25519 -f /tmp/sk3 -N "$PASS3" -C "subkingdom3"
ssh-keygen -t ed25519 -f /tmp/sk4 -N "$PASS4" -C "subkingdom4"

echo "=== Distributing keys and passphrases ==="
# Agent 1: gets their key, holds Agent 3's passphrase
cp /tmp/sk1 /home/agent1/.ssh/subkingdom_key
echo "$PASS3" > /home/agent1/keys/agent3_passphrase.txt

# Agent 2: gets their key, holds Agent 4's passphrase
cp /tmp/sk2 /home/agent2/.ssh/subkingdom_key
echo "$PASS4" > /home/agent2/keys/agent4_passphrase.txt

# Agent 3: gets their key, holds Agent 1's passphrase
cp /tmp/sk3 /home/agent3/.ssh/subkingdom_key
echo "$PASS1" > /home/agent3/keys/agent1_passphrase.txt

# Agent 4: gets their key, holds Agent 2's passphrase
cp /tmp/sk4 /home/agent4/.ssh/subkingdom_key
echo "$PASS2" > /home/agent4/keys/agent2_passphrase.txt

echo "=== Setting permissions ==="
for i in 1 2 3 4; do
    chmod 600 /home/agent$i/.ssh/subkingdom_key
    chmod 600 /home/agent$i/keys/*
    chown -R agent$i:agent$i /home/agent$i
done

echo "=== Saving public keys for subkingdoms ==="
cp /tmp/sk1.pub /root/subkingdom_pubkeys/agent1.pub
cp /tmp/sk2.pub /root/subkingdom_pubkeys/agent2.pub
cp /tmp/sk3.pub /root/subkingdom_pubkeys/agent3.pub
cp /tmp/sk4.pub /root/subkingdom_pubkeys/agent4.pub

echo "=== Cleanup ==="
rm /tmp/sk*

echo "=== Done ==="
echo "Public keys saved to /root/subkingdom_pubkeys/"
echo "Deploy these to respective subkingdom servers"
```

## Notes

- SSH keys are real cryptographic keys
- Passphrases are randomly generated
- File permissions enforce the gate
- Agents must communicate to exchange passphrases
- No backdoor exists - collaboration is required
