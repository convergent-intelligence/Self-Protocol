# Parallel VM Mesh Simulation

**Simulation-First Strategy: Test everything in Parallels before Day 0 deployment.**

## Philosophy

The Kingdom mesh is too critical to deploy blind. Before any script touches real hardware or production VPS, it runs in a complete 6-VM simulation on a MacBook with Parallels. This ensures:

1. **Scripts are battle-tested** - Every edge case discovered in simulation, not production
2. **Network topology validated** - Mesh communication verified before real deployment
3. **Rollback procedures proven** - Know exactly how to recover before you need to
4. **Identical code paths** - Simulation scripts ARE production scripts

## The 6-VM Mesh

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        PARALLELS VM MESH (MacBook Host)                      │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │  KALI LINUX  │    │  DEBIAN 12   │    │  FEDORA      │                   │
│  │  Guardian    │    │  Core Infra  │    │  Builder     │                   │
│  │  Citadel     │◄──►│  VPS Sim     │◄──►│  Node        │                   │
│  │              │    │              │    │              │                   │
│  │ 192.168.1.10 │    │ 192.168.1.11 │    │ 192.168.1.12 │                   │
│  └──────────────┘    └──────────────┘    └──────────────┘                   │
│         ▲                   ▲                   ▲                            │
│         │                   │                   │                            │
│         ▼                   ▼                   ▼                            │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐                   │
│  │  WINDOWS 11  │    │  macOS VM    │    │  UBUNTU      │                   │
│  │  Lenovo Sim  │    │  Chariot Sim │    │  Flexible    │                   │
│  │  Final Host  │◄──►│  Future Mac  │◄──►│  Role        │                   │
│  │              │    │              │    │              │                   │
│  │ 192.168.1.13 │    │ 192.168.1.14 │    │ 192.168.1.15 │                   │
│  └──────────────┘    └──────────────┘    └──────────────┘                   │
│                                                                              │
└─────────────────────────────────────────────────────────────────────────────┘
```

## Node Roles

| VM | OS | Role | Simulates | Production Target |
|----|-----|------|-----------|-------------------|
| 1 | Kali Linux | Guardian/Citadel | Security node | VPS at mapyourmind.me |
| 2 | Debian 12 | Core Infrastructure | Primary VPS | Production VPS |
| 3 | Fedora | Builder | Build/CI node | Build server |
| 4 | Windows 11 | Lenovo Simulation | Final Windows host | Lenovo laptop |
| 5 | macOS VM | Chariot Simulation | Future Mac hardware | Mac hardware |
| 6 | Ubuntu | Flexible | Various roles | TBD |

## Key Principle: Script Identity

**The scripts that run in simulation are IDENTICAL to production scripts.**

There is no "simulation mode" or "test flag". The same [`guardian-setup-kali.sh`](../guardian-setup-kali.sh) that runs in the Kali VM will run on the production VPS. The same [`debian-node.sh`](../nodes/debian-node.sh) that configures the Debian VM will configure the production Debian server.

This means:
- Bugs found in simulation = bugs prevented in production
- Configuration drift is impossible
- Deployment is just "run the same script on different hardware"

## Workflow

### 1. Setup VMs
Follow [`parallels-setup.md`](./parallels-setup.md) to create all 6 VMs with correct specs.

### 2. Deploy to Simulation
```bash
# Deploy to all VMs in parallel
./deploy-all.sh

# Or deploy to specific nodes
./deploy-all.sh kali debian
```

### 3. Verify Mesh
```bash
# Check status of all nodes
./mesh-status.sh
```

### 4. Test Scenarios
- Node failure recovery
- Network partition handling
- Rolling updates
- Security incident response

### 5. Deploy to Production
Once simulation passes all tests, the same scripts deploy to real hardware:
```bash
# On production VPS
curl -sSL https://raw.githubusercontent.com/vergent/Kingdom/main/bootstrap/guardian-setup-kali.sh | sudo bash
```

## Files in This Directory

| File | Purpose |
|------|---------|
| [`README.md`](./README.md) | This file - overview and philosophy |
| [`parallels-setup.md`](./parallels-setup.md) | VM creation guide with specs |
| [`deploy-all.sh`](./deploy-all.sh) | Orchestrator to deploy to all VMs |
| [`mesh-status.sh`](./mesh-status.sh) | Show status of all 6 nodes |

## Related Scripts

| Script | Purpose |
|--------|---------|
| [`../guardian-setup-kali.sh`](../guardian-setup-kali.sh) | Kali Linux Guardian setup |
| [`../nodes/debian-node.sh`](../nodes/debian-node.sh) | Debian node setup |
| [`../nodes/fedora-node.sh`](../nodes/fedora-node.sh) | Fedora node setup (dnf) |
| [`../nodes/ubuntu-node.sh`](../nodes/ubuntu-node.sh) | Ubuntu node setup |
| [`../nodes/windows-node.ps1`](../nodes/windows-node.ps1) | Windows node setup (PowerShell) |
| [`../nodes/macos-node.sh`](../nodes/macos-node.sh) | macOS node setup |

## Network Configuration

All VMs use a shared network in Parallels:
- Network: `192.168.1.0/24`
- Gateway: `192.168.1.1` (Parallels NAT)
- DNS: `192.168.1.1` or `8.8.8.8`

Each VM has a static IP for predictable mesh communication.

## Day 0 Deployment

When simulation is validated:

1. **Kali Guardian** → Deploy to mapyourmind.me VPS
2. **Debian Core** → Deploy to production VPS
3. **Windows** → Run on actual Lenovo laptop
4. **macOS** → Run on actual Mac hardware (when acquired)
5. **Fedora/Ubuntu** → Deploy as needed

The mesh topology remains identical - only the underlying hardware changes.

---

*"Test in simulation. Deploy with confidence. The Kingdom mesh lives."*
