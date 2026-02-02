# Parallels VM Setup Guide

Complete guide for creating the 6-VM Kingdom mesh simulation on macOS with Parallels Desktop.

## Prerequisites

- **macOS Host**: MacBook Pro/Air with Apple Silicon or Intel
- **Parallels Desktop**: Version 18+ (Pro or Business recommended for advanced networking)
- **RAM**: Minimum 32GB recommended (64GB ideal for running all 6 VMs)
- **Storage**: 250GB+ free SSD space
- **ISOs**: Download all required OS images before starting

## ISO Downloads

| OS | Download Link | Size |
|----|---------------|------|
| Kali Linux | https://www.kali.org/get-kali/#kali-installer-images | ~3.5GB |
| Debian 12 | https://www.debian.org/download | ~600MB (netinst) |
| Fedora Workstation | https://fedoraproject.org/workstation/download | ~2GB |
| Ubuntu 22.04 LTS | https://ubuntu.com/download/desktop | ~4.5GB |
| Windows 11 | https://www.microsoft.com/software-download/windows11 | ~5GB |
| macOS (Parallels) | Built-in Parallels feature | N/A |

## Network Configuration

### Create Shared Network

1. Open Parallels Desktop → **Preferences** → **Network**
2. Click **+** to add new network
3. Configure:
   - **Name**: `kingdom-mesh`
   - **Type**: Host-Only
   - **Subnet**: `192.168.1.0`
   - **Subnet Mask**: `255.255.255.0`
   - **DHCP**: Disabled (we use static IPs)

### IP Allocation

| VM | Hostname | IP Address | MAC Address (suggested) |
|----|----------|------------|-------------------------|
| Kali Linux | guardian | 192.168.1.10 | 00:1C:42:01:00:10 |
| Debian 12 | core | 192.168.1.11 | 00:1C:42:01:00:11 |
| Fedora | builder | 192.168.1.12 | 00:1C:42:01:00:12 |
| Windows 11 | lenovo | 192.168.1.13 | 00:1C:42:01:00:13 |
| macOS | chariot | 192.168.1.14 | 00:1C:42:01:00:14 |
| Ubuntu | flex | 192.168.1.15 | 00:1C:42:01:00:15 |

---

## VM 1: Kali Linux (Guardian/Citadel)

### Specifications

| Resource | Value | Notes |
|----------|-------|-------|
| **CPU** | 2 cores | Security tools benefit from multi-core |
| **RAM** | 4GB | 8GB if running heavy scans |
| **Disk** | 60GB | Dynamic allocation |
| **Network** | kingdom-mesh | Static IP: 192.168.1.10 |

### Installation Steps

1. **Create VM**
   - File → New → Install Windows or another OS from DVD/image
   - Select Kali ISO
   - Name: `kingdom-guardian`

2. **Configure Hardware**
   - CPU: 2 cores
   - Memory: 4096 MB
   - Hard Disk: 60 GB (expanding)

3. **Network Setup**
   - Hardware → Network → Source: `kingdom-mesh`
   - MAC Address: `00:1C:42:01:00:10`

4. **Install Kali**
   - Choose "Graphical Install"
   - Hostname: `guardian`
   - Domain: `kingdom.local`
   - Create user: `kingdom`
   - Select "large" metapackage for full security tools

5. **Post-Install Static IP**
   ```bash
   sudo nano /etc/network/interfaces
   ```
   ```
   auto eth0
   iface eth0 inet static
       address 192.168.1.10
       netmask 255.255.255.0
       gateway 192.168.1.1
       dns-nameservers 8.8.8.8 8.8.4.4
   ```

6. **Install Parallels Tools**
   - Devices → Install Parallels Tools
   - Follow on-screen instructions

---

## VM 2: Debian 12 (Core Infrastructure)

### Specifications

| Resource | Value | Notes |
|----------|-------|-------|
| **CPU** | 2 cores | Matches typical VPS |
| **RAM** | 4GB | Matches typical VPS |
| **Disk** | 40GB | Matches typical VPS |
| **Network** | kingdom-mesh | Static IP: 192.168.1.11 |

### Installation Steps

1. **Create VM**
   - Select Debian netinst ISO
   - Name: `kingdom-core`

2. **Configure Hardware**
   - CPU: 2 cores
   - Memory: 4096 MB
   - Hard Disk: 40 GB

3. **Network Setup**
   - Hardware → Network → Source: `kingdom-mesh`
   - MAC Address: `00:1C:42:01:00:11`

4. **Install Debian**
   - Choose "Install" (text mode is fine)
   - Hostname: `core`
   - Domain: `kingdom.local`
   - Root password: Set strong password
   - Create user: `kingdom`
   - Partitioning: Guided - use entire disk
   - Software: SSH server, standard system utilities (no desktop)

5. **Post-Install Static IP**
   ```bash
   sudo nano /etc/network/interfaces
   ```
   ```
   auto enp0s5
   iface enp0s5 inet static
       address 192.168.1.11
       netmask 255.255.255.0
       gateway 192.168.1.1
       dns-nameservers 8.8.8.8 8.8.4.4
   ```

---

## VM 3: Fedora (Builder Node)

### Specifications

| Resource | Value | Notes |
|----------|-------|-------|
| **CPU** | 4 cores | Build performance |
| **RAM** | 8GB | Compilation needs RAM |
| **Disk** | 80GB | Build artifacts |
| **Network** | kingdom-mesh | Static IP: 192.168.1.12 |

### Installation Steps

1. **Create VM**
   - Select Fedora Workstation ISO
   - Name: `kingdom-builder`

2. **Configure Hardware**
   - CPU: 4 cores
   - Memory: 8192 MB
   - Hard Disk: 80 GB

3. **Network Setup**
   - Hardware → Network → Source: `kingdom-mesh`
   - MAC Address: `00:1C:42:01:00:12`

4. **Install Fedora**
   - Use Anaconda installer
   - Hostname: `builder`
   - Create user: `kingdom`
   - Select "Minimal Install" or "Workstation"

5. **Post-Install Static IP**
   ```bash
   sudo nmcli con mod "Wired connection 1" \
       ipv4.addresses 192.168.1.12/24 \
       ipv4.gateway 192.168.1.1 \
       ipv4.dns "8.8.8.8 8.8.4.4" \
       ipv4.method manual
   sudo nmcli con up "Wired connection 1"
   ```

---

## VM 4: Windows 11 (Lenovo Simulation)

### Specifications

| Resource | Value | Notes |
|----------|-------|-------|
| **CPU** | 4 cores | Windows needs resources |
| **RAM** | 8GB | Windows minimum |
| **Disk** | 100GB | Windows + apps |
| **Network** | kingdom-mesh | Static IP: 192.168.1.13 |
| **TPM** | Enabled | Windows 11 requirement |

### Installation Steps

1. **Create VM**
   - Select Windows 11 ISO
   - Name: `kingdom-lenovo`
   - Parallels will auto-configure for Windows 11

2. **Configure Hardware**
   - CPU: 4 cores
   - Memory: 8192 MB
   - Hard Disk: 100 GB
   - TPM: Enabled (Parallels handles this)

3. **Network Setup**
   - Hardware → Network → Source: `kingdom-mesh`
   - MAC Address: `00:1C:42:01:00:13`

4. **Install Windows 11**
   - Follow standard Windows installation
   - Create local account: `kingdom`
   - Skip Microsoft account (use offline account)

5. **Post-Install Static IP**
   - Settings → Network & Internet → Ethernet → Edit
   - IP assignment: Manual
   - IPv4: On
   - IP address: `192.168.1.13`
   - Subnet mask: `255.255.255.0`
   - Gateway: `192.168.1.1`
   - Preferred DNS: `8.8.8.8`

6. **Enable PowerShell Remoting**
   ```powershell
   Enable-PSRemoting -Force
   Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force
   ```

---

## VM 5: macOS (Chariot Simulation)

### Specifications

| Resource | Value | Notes |
|----------|-------|-------|
| **CPU** | 4 cores | macOS needs resources |
| **RAM** | 8GB | macOS minimum |
| **Disk** | 80GB | macOS + Xcode |
| **Network** | kingdom-mesh | Static IP: 192.168.1.14 |

### Installation Steps

1. **Create VM**
   - File → New → Download macOS
   - Parallels will download and install automatically
   - Name: `kingdom-chariot`

2. **Configure Hardware**
   - CPU: 4 cores
   - Memory: 8192 MB
   - Hard Disk: 80 GB

3. **Network Setup**
   - Hardware → Network → Source: `kingdom-mesh`
   - MAC Address: `00:1C:42:01:00:14`

4. **Install macOS**
   - Follow Parallels automated installation
   - Create user: `kingdom`

5. **Post-Install Static IP**
   - System Preferences → Network → Ethernet
   - Configure IPv4: Manually
   - IP Address: `192.168.1.14`
   - Subnet Mask: `255.255.255.0`
   - Router: `192.168.1.1`
   - DNS Server: `8.8.8.8`

6. **Enable Remote Login**
   - System Preferences → Sharing → Remote Login: On

---

## VM 6: Ubuntu (Flexible Role)

### Specifications

| Resource | Value | Notes |
|----------|-------|-------|
| **CPU** | 2 cores | General purpose |
| **RAM** | 4GB | General purpose |
| **Disk** | 50GB | General purpose |
| **Network** | kingdom-mesh | Static IP: 192.168.1.15 |

### Installation Steps

1. **Create VM**
   - Select Ubuntu ISO
   - Name: `kingdom-flex`

2. **Configure Hardware**
   - CPU: 2 cores
   - Memory: 4096 MB
   - Hard Disk: 50 GB

3. **Network Setup**
   - Hardware → Network → Source: `kingdom-mesh`
   - MAC Address: `00:1C:42:01:00:15`

4. **Install Ubuntu**
   - Choose "Minimal installation"
   - Hostname: `flex`
   - Create user: `kingdom`

5. **Post-Install Static IP**
   ```bash
   sudo nano /etc/netplan/01-netcfg.yaml
   ```
   ```yaml
   network:
     version: 2
     ethernets:
       enp0s5:
         addresses:
           - 192.168.1.15/24
         gateway4: 192.168.1.1
         nameservers:
           addresses: [8.8.8.8, 8.8.4.4]
   ```
   ```bash
   sudo netplan apply
   ```

---

## SSH Key Distribution

After all VMs are installed, distribute SSH keys for passwordless access:

### On macOS Host

```bash
# Generate key if not exists
ssh-keygen -t ed25519 -C "kingdom-mesh"

# Copy to all Linux VMs
ssh-copy-id kingdom@192.168.1.10  # Kali
ssh-copy-id kingdom@192.168.1.11  # Debian
ssh-copy-id kingdom@192.168.1.12  # Fedora
ssh-copy-id kingdom@192.168.1.14  # macOS VM
ssh-copy-id kingdom@192.168.1.15  # Ubuntu
```

### SSH Config

Add to `~/.ssh/config` on host:

```
Host guardian
    HostName 192.168.1.10
    User kingdom

Host core
    HostName 192.168.1.11
    User kingdom

Host builder
    HostName 192.168.1.12
    User kingdom

Host lenovo
    HostName 192.168.1.13
    User kingdom

Host chariot
    HostName 192.168.1.14
    User kingdom

Host flex
    HostName 192.168.1.15
    User kingdom
```

---

## Verification

After setup, verify all VMs can communicate:

```bash
# From host, ping all VMs
for ip in 10 11 12 13 14 15; do
    ping -c 1 192.168.1.$ip && echo "192.168.1.$ip OK" || echo "192.168.1.$ip FAILED"
done

# From any Linux VM, ping others
for ip in 10 11 12 13 14 15; do
    ping -c 1 192.168.1.$ip
done
```

---

## Resource Summary

| VM | CPU | RAM | Disk | Total |
|----|-----|-----|------|-------|
| Kali | 2 | 4GB | 60GB | |
| Debian | 2 | 4GB | 40GB | |
| Fedora | 4 | 8GB | 80GB | |
| Windows | 4 | 8GB | 100GB | |
| macOS | 4 | 8GB | 80GB | |
| Ubuntu | 2 | 4GB | 50GB | |
| **Total** | **18** | **36GB** | **410GB** | |

**Note**: Not all VMs need to run simultaneously. For testing specific scenarios, run only the relevant VMs.

---

## Snapshots

Create snapshots at key points:

1. **Post-Install**: Clean OS installation
2. **Post-Network**: Static IP configured
3. **Post-Bootstrap**: After running node setup scripts
4. **Pre-Test**: Before running destructive tests

```bash
# Parallels CLI for snapshots
prlctl snapshot kingdom-guardian -n "post-install"
prlctl snapshot kingdom-core -n "post-install"
# ... etc
```

---

## Next Steps

Once all VMs are configured:

1. Run [`deploy-all.sh`](./deploy-all.sh) to bootstrap all nodes
2. Run [`mesh-status.sh`](./mesh-status.sh) to verify mesh health
3. Test failure scenarios
4. Validate deployment scripts work identically to production

---

*"Six VMs. One mesh. Zero surprises in production."*
