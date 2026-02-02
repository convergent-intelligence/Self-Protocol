# Kingdom Bootstrap Scripts

Bootstrap scripts for deploying Kingdom Network nodes on Debian 12 VPS instances.

## The Four Kingdom Nodes

The Kingdom Network consists of four specialized node types, each with a distinct role:

```
┌─────────────────────────────────────────────────────────────────┐
│                     KINGDOM NETWORK                              │
│                                                                  │
│   ┌──────────┐   ┌──────────┐   ┌──────────┐   ┌──────────┐    │
│   │ 🛡️       │   │ 👁️       │   │ 🔨       │   │ 📜       │    │
│   │ GUARDIAN │   │ WATCHER  │   │ BUILDER  │   │ SCRIBE   │    │
│   │          │   │          │   │          │   │          │    │
│   │ Security │   │ Monitor  │   │ CI/CD    │   │ Docs     │    │
│   │ Auth     │   │ Observe  │   │ Build    │   │ Knowledge│    │
│   │ Gateway  │   │ Alert    │   │ Deploy   │   │ Logging  │    │
│   └──────────┘   └──────────┘   └──────────┘   └──────────┘    │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

### 🛡️ Guardian Node

**Purpose:** Security, authentication, and access control

**Script:** [`guardian-setup.sh`](guardian-setup.sh)

**Installs:**
- Nginx (reverse proxy)
- Let's Encrypt SSL
- UFW Firewall
- Fail2Ban
- Docker & Docker Compose
- Node.js

**Services:**
- OpenClaw API integration
- Self-Protocol viewer
- Authentication gateway

**Ports:**
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 3000 (OpenClaw API)
- 3001 (Self-Protocol Viewer)

---

### 👁️ Watcher Node

**Purpose:** Monitoring, observability, and log aggregation

**Script:** [`watcher-setup.sh`](watcher-setup.sh)

**Installs:**
- Prometheus (metrics collection)
- Grafana (visualization)
- Loki (log aggregation)
- Alertmanager (alert routing)
- Promtail (log shipping)
- Node Exporter (system metrics)

**Services:**
- Metrics collection from all Kingdom nodes
- Centralized logging
- Alert management
- Monitoring dashboards

**Ports:**
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 9090 (Prometheus)
- 3000 (Grafana)
- 3100 (Loki)
- 9093 (Alertmanager)
- 9100 (Node Exporter)

---

### 🔨 Builder Node

**Purpose:** CI/CD, artifact building, and deployments

**Script:** [`builder-setup.sh`](builder-setup.sh)

**Installs:**
- Docker Registry
- Node.js, npm, yarn, pnpm
- Rust & Cargo
- Go
- Build tools (gcc, make, cmake)
- CI Runner capabilities

**Services:**
- Private Docker registry
- Artifact storage
- Build automation
- Deployment pipelines

**Ports:**
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 5000 (Docker Registry)
- 8080 (CI Webhook)
- 8081 (Registry UI)
- 9100 (Node Exporter)

---

### 📜 Scribe Node

**Purpose:** Documentation, knowledge capture, and structured logging

**Script:** [`scribe-setup.sh`](scribe-setup.sh)

**Installs:**
- Wiki.js (documentation wiki)
- MkDocs Material (static docs)
- PostgreSQL (database)
- Knowledge base API
- Pandoc & LaTeX (document conversion)

**Services:**
- Wiki platform
- Static documentation site
- Knowledge base
- Structured logging
- Document archival

**Ports:**
- 22 (SSH)
- 80 (HTTP)
- 443 (HTTPS)
- 3000 (Wiki.js)
- 3100 (Knowledge API)
- 8000 (MkDocs dev server)
- 9100 (Node Exporter)

---

## Quick Start

### Prerequisites

- Fresh Debian 12 VPS
- Root access
- Domain name pointed to server (for SSL)

### Installation

1. **Clone the repository:**
   ```bash
   git clone https://github.com/vergent/Kingdom.git
   cd Kingdom/bootstrap
   ```

2. **Run the appropriate setup script:**
   ```bash
   # For Guardian node
   sudo DOMAIN="your-domain.com" ./guardian-setup.sh

   # For Watcher node
   sudo WATCHER_DOMAIN="watcher.your-domain.com" ./watcher-setup.sh

   # For Builder node
   sudo BUILDER_DOMAIN="builder.your-domain.com" ./builder-setup.sh

   # For Scribe node
   sudo SCRIBE_DOMAIN="scribe.your-domain.com" ./scribe-setup.sh
   ```

3. **Start the services:**
   ```bash
   # After setup, start the node service
   sudo systemctl start guardian-node   # or watcher-node, builder-node, scribe-node
   ```

---

## Helper Commands

After installation, the following commands are available (after re-login):

### All Nodes
| Command | Description |
|---------|-------------|
| `status.sh` | Show general node status |

### Guardian Node
| Command | Description |
|---------|-------------|
| `pull-kingdom.sh` | Pull Kingdom repository updates |
| `update-self.sh` | Update Self-Protocol |
| `sync-openclaw.sh` | Sync OpenClaw |

### Watcher Node
| Command | Description |
|---------|-------------|
| `watcher-status.sh` | Show Watcher-specific status |

### Builder Node
| Command | Description |
|---------|-------------|
| `builder-status.sh` | Show Builder-specific status |
| `build-docker.sh` | Build and push Docker images |

### Scribe Node
| Command | Description |
|---------|-------------|
| `scribe-status.sh` | Show Scribe-specific status |

---

## Directory Structure

All nodes install to `/opt/kingdom/` with the following structure:

```
/opt/kingdom/
├── config/          # Node configuration files
├── commands/        # Helper command scripts
├── data/            # Persistent data (varies by node)
├── logs/            # Log files
├── repos/           # Cloned repositories (Guardian)
├── monitoring/      # Monitoring configs (Watcher)
├── builds/          # Build workspace (Builder)
├── registry/        # Docker registry (Builder)
├── artifacts/       # Build artifacts (Builder)
├── docs/            # Documentation (Scribe)
├── knowledge/       # Knowledge base (Scribe)
└── docker-compose.yaml
```

---

## Security Features

All bootstrap scripts include:

- **UFW Firewall** - Configured with minimal open ports
- **Fail2Ban** - Protection against brute force attacks
- **SSH hardening** - Key-based authentication recommended
- **Let's Encrypt SSL** - Automatic certificate management
- **Internal-only services** - Sensitive ports restricted to internal networks

---

## Idempotency

All scripts are **idempotent** - safe to run multiple times. Each section checks for existing state before making changes, allowing you to:

- Re-run after failures
- Update configurations
- Add new features without breaking existing setup

---

## Network Architecture

```
                    ┌─────────────────┐
                    │    Internet     │
                    └────────┬────────┘
                             │
              ┌──────────────┼──────────────┐
              │              │              │
              ▼              ▼              ▼
        ┌──────────┐   ┌──────────┐   ┌──────────┐
        │ Guardian │   │ Builder  │   │  Scribe  │
        │ :443     │   │ :443     │   │  :443    │
        └────┬─────┘   └────┬─────┘   └────┬─────┘
             │              │              │
             └──────────────┼──────────────┘
                            │
                    ┌───────▼───────┐
                    │    Watcher    │
                    │   (metrics)   │
                    │   :9090       │
                    └───────────────┘
```

The Watcher node collects metrics from all other nodes via Node Exporter (port 9100).

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `DOMAIN` | `mapyourmind.me` | Guardian domain |
| `WATCHER_DOMAIN` | `watcher.kingdom.local` | Watcher domain |
| `BUILDER_DOMAIN` | `builder.kingdom.local` | Builder domain |
| `SCRIBE_DOMAIN` | `scribe.kingdom.local` | Scribe domain |

---

## Troubleshooting

### Check service status
```bash
systemctl status guardian-node  # or watcher-node, builder-node, scribe-node
```

### View logs
```bash
journalctl -u guardian-node -f
docker logs <container-name>
```

### Restart services
```bash
systemctl restart guardian-node
docker compose restart
```

### SSL certificate issues
```bash
certbot --nginx -d your-domain.com
certbot renew --dry-run
```

---

## Contributing

When adding new features to bootstrap scripts:

1. Maintain idempotency - check before modifying
2. Use colored output for visibility
3. Include proper error handling
4. Update this README

---

*"Temporary voices, permanent patterns. The Kingdom lives."*
