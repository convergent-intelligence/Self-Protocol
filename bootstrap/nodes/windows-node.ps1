#===============================================================================
# Windows Node Bootstrap Script (PowerShell)
# OS: Windows 11 | Role: Lenovo Simulation / Final Windows Host
# Part of Kingdom Mesh Network
#===============================================================================
# This script is IDEMPOTENT - safe to run multiple times
# IDENTICAL to production deployment - no simulation flags
#===============================================================================
# Run as Administrator:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\windows-node.ps1
#===============================================================================

#Requires -RunAsAdministrator

param(
    [string]$NodeRole = "lenovo",
    [string]$InstallDir = "C:\Kingdom",
    [string]$MeshNetwork = "192.168.1.0/24"
)

# Configuration
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

#-------------------------------------------------------------------------------
# Logging Functions
#-------------------------------------------------------------------------------
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "INFO"    { "Cyan" }
        "SUCCESS" { "Green" }
        "WARN"    { "Yellow" }
        "ERROR"   { "Red" }
        default   { "White" }
    }
    Write-Host "[$Level] $Message" -ForegroundColor $color
}

function Write-Section {
    param([string]$Title)
    Write-Host ""
    Write-Host "========================================" -ForegroundColor Magenta
    Write-Host " $Title" -ForegroundColor Magenta
    Write-Host "========================================" -ForegroundColor Magenta
}

#-------------------------------------------------------------------------------
# Pre-flight Checks
#-------------------------------------------------------------------------------
function Test-Prerequisites {
    Write-Section "Pre-flight Checks"
    
    # Check Windows version
    $osInfo = Get-CimInstance Win32_OperatingSystem
    Write-Log "Detected: $($osInfo.Caption) $($osInfo.Version)"
    
    # Check if running as admin
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Log "This script must be run as Administrator" "ERROR"
        exit 1
    }
    
    Write-Log "Pre-flight checks passed" "SUCCESS"
}

#-------------------------------------------------------------------------------
# Install Chocolatey (Package Manager)
#-------------------------------------------------------------------------------
function Install-Chocolatey {
    Write-Section "Installing Chocolatey Package Manager"
    
    if (Get-Command choco -ErrorAction SilentlyContinue) {
        Write-Log "Chocolatey already installed: $(choco --version)"
    } else {
        Write-Log "Installing Chocolatey..."
        Set-ExecutionPolicy Bypass -Scope Process -Force
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
        
        # Refresh environment
        $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
        
        Write-Log "Chocolatey installed" "SUCCESS"
    }
}

#-------------------------------------------------------------------------------
# Install Dependencies
#-------------------------------------------------------------------------------
function Install-Dependencies {
    Write-Section "Installing Dependencies"
    
    $packages = @(
        "git",
        "nodejs-lts",
        "python3",
        "curl",
        "wget",
        "jq",
        "openssh"
    )
    
    foreach ($package in $packages) {
        Write-Log "Installing $package..."
        choco install $package -y --no-progress 2>$null
    }
    
    # Refresh environment
    $env:Path = [System.Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [System.Environment]::GetEnvironmentVariable("Path", "User")
    
    Write-Log "Dependencies installed" "SUCCESS"
}

#-------------------------------------------------------------------------------
# Install Docker Desktop
#-------------------------------------------------------------------------------
function Install-Docker {
    Write-Section "Installing Docker Desktop"
    
    if (Get-Command docker -ErrorAction SilentlyContinue) {
        Write-Log "Docker already installed: $(docker --version)"
    } else {
        Write-Log "Installing Docker Desktop..."
        choco install docker-desktop -y --no-progress
        
        Write-Log "Docker Desktop installed - restart may be required" "WARN"
        Write-Log "After restart, ensure Docker Desktop is running" "WARN"
    }
}

#-------------------------------------------------------------------------------
# Configure Windows Firewall
#-------------------------------------------------------------------------------
function Configure-Firewall {
    Write-Section "Configuring Windows Firewall"
    
    # Allow SSH
    $sshRule = Get-NetFirewallRule -DisplayName "Kingdom SSH" -ErrorAction SilentlyContinue
    if (-not $sshRule) {
        New-NetFirewallRule -DisplayName "Kingdom SSH" -Direction Inbound -Protocol TCP -LocalPort 22 -Action Allow
        Write-Log "SSH firewall rule created"
    }
    
    # Allow Kingdom mesh ports
    $meshRule = Get-NetFirewallRule -DisplayName "Kingdom Mesh" -ErrorAction SilentlyContinue
    if (-not $meshRule) {
        New-NetFirewallRule -DisplayName "Kingdom Mesh" -Direction Inbound -Protocol TCP -LocalPort 3000-3100 -Action Allow -RemoteAddress $MeshNetwork.Replace("/24", ".0-192.168.1.255")
        Write-Log "Kingdom mesh firewall rule created"
    }
    
    Write-Log "Firewall configured" "SUCCESS"
}

#-------------------------------------------------------------------------------
# Enable OpenSSH Server
#-------------------------------------------------------------------------------
function Enable-SSHServer {
    Write-Section "Enabling OpenSSH Server"
    
    # Check if OpenSSH Server is installed
    $sshServer = Get-WindowsCapability -Online | Where-Object Name -like 'OpenSSH.Server*'
    
    if ($sshServer.State -ne "Installed") {
        Write-Log "Installing OpenSSH Server..."
        Add-WindowsCapability -Online -Name OpenSSH.Server~~~~0.0.1.0
    }
    
    # Start and enable SSH service
    Start-Service sshd -ErrorAction SilentlyContinue
    Set-Service -Name sshd -StartupType Automatic
    
    Write-Log "OpenSSH Server enabled" "SUCCESS"
}

#-------------------------------------------------------------------------------
# Clone Repositories
#-------------------------------------------------------------------------------
function Clone-Repositories {
    Write-Section "Cloning Repositories"
    
    $reposDir = Join-Path $InstallDir "repos"
    New-Item -ItemType Directory -Force -Path $reposDir | Out-Null
    
    $repos = @{
        "Kingdom" = "https://github.com/vergent/Kingdom.git"
        "Self-Protocol" = "https://github.com/vergent/Self-Protocol.git"
    }
    
    foreach ($repo in $repos.GetEnumerator()) {
        $repoPath = Join-Path $reposDir $repo.Key
        if (Test-Path $repoPath) {
            Write-Log "Updating $($repo.Key)..."
            Push-Location $repoPath
            git pull --ff-only 2>$null
            Pop-Location
        } else {
            Write-Log "Cloning $($repo.Key)..."
            git clone $repo.Value $repoPath 2>$null
        }
    }
    
    Write-Log "Repositories synchronized" "SUCCESS"
}

#-------------------------------------------------------------------------------
# Configure Node
#-------------------------------------------------------------------------------
function Configure-Node {
    Write-Section "Configuring Windows Node"
    
    $configDir = Join-Path $InstallDir "config"
    New-Item -ItemType Directory -Force -Path $configDir | Out-Null
    
    # Create node configuration
    $nodeConfig = @"
# Windows Node Configuration
node:
  role: $NodeRole
  platform: windows
  
mesh:
  network: $MeshNetwork
  port_range: 3000-3100

windows:
  ssh_enabled: true
  docker_desktop: true
"@
    
    $nodeConfig | Out-File -FilePath (Join-Path $configDir "node.yaml") -Encoding UTF8
    
    # Set environment variables
    [Environment]::SetEnvironmentVariable("KINGDOM_HOME", $InstallDir, "Machine")
    [Environment]::SetEnvironmentVariable("KINGDOM_ROLE", $NodeRole, "Machine")
    
    Write-Log "Node configured" "SUCCESS"
}

#-------------------------------------------------------------------------------
# Create Scheduled Task for Startup
#-------------------------------------------------------------------------------
function Create-StartupTask {
    Write-Section "Creating Startup Task"
    
    $taskName = "Kingdom Node Startup"
    $existingTask = Get-ScheduledTask -TaskName $taskName -ErrorAction SilentlyContinue
    
    if (-not $existingTask) {
        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File `"$InstallDir\scripts\startup.ps1`""
        $trigger = New-ScheduledTaskTrigger -AtStartup
        $principal = New-ScheduledTaskPrincipal -UserId "SYSTEM" -LogonType ServiceAccount -RunLevel Highest
        
        Register-ScheduledTask -TaskName $taskName -Action $action -Trigger $trigger -Principal $principal -Description "Kingdom Node startup script"
        
        # Create startup script
        $scriptsDir = Join-Path $InstallDir "scripts"
        New-Item -ItemType Directory -Force -Path $scriptsDir | Out-Null
        
        $startupScript = @"
# Kingdom Node Startup Script
Write-Host "Starting Kingdom Node..."

# Ensure Docker is running
Start-Process "C:\Program Files\Docker\Docker\Docker Desktop.exe" -WindowStyle Hidden

# Wait for Docker
Start-Sleep -Seconds 30

# Start Kingdom services
Set-Location "$InstallDir"
docker compose up -d

Write-Host "Kingdom Node started"
"@
        
        $startupScript | Out-File -FilePath (Join-Path $scriptsDir "startup.ps1") -Encoding UTF8
        
        Write-Log "Startup task created" "SUCCESS"
    } else {
        Write-Log "Startup task already exists"
    }
}

#-------------------------------------------------------------------------------
# Create Docker Compose File
#-------------------------------------------------------------------------------
function Create-DockerCompose {
    Write-Section "Creating Docker Compose Configuration"
    
    $composeFile = Join-Path $InstallDir "docker-compose.yaml"
    
    if (-not (Test-Path $composeFile)) {
        $compose = @"
version: '3.8'

services:
  kingdom-windows:
    image: node:20-alpine
    container_name: kingdom-windows
    working_dir: /app
    volumes:
      - ${InstallDir}\repos\Kingdom:/app
    ports:
      - "127.0.0.1:3000:3000"
    command: echo "Kingdom Windows node ready"
    restart: unless-stopped
"@
        
        $compose | Out-File -FilePath $composeFile -Encoding UTF8
        Write-Log "Docker compose file created" "SUCCESS"
    }
}

#-------------------------------------------------------------------------------
# Status Report
#-------------------------------------------------------------------------------
function Show-Status {
    Write-Section "Windows Node Setup Complete"
    
    Write-Host ""
    Write-Host "╔════════════════════════════════════════════════════════════╗" -ForegroundColor Green
    Write-Host "║            Windows Node Bootstrap Complete                  ║" -ForegroundColor Green
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ Role:       $NodeRole" -ForegroundColor Green
    Write-Host "║ Platform:   Windows" -ForegroundColor Green
    Write-Host "║ Install:    $InstallDir" -ForegroundColor Green
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ Components:" -ForegroundColor Green
    
    $gitVersion = if (Get-Command git -ErrorAction SilentlyContinue) { git --version } else { "not installed" }
    $nodeVersion = if (Get-Command node -ErrorAction SilentlyContinue) { node --version } else { "not installed" }
    $dockerVersion = if (Get-Command docker -ErrorAction SilentlyContinue) { docker --version } else { "not installed" }
    
    Write-Host "║   - Git:      $gitVersion" -ForegroundColor Green
    Write-Host "║   - Node.js:  $nodeVersion" -ForegroundColor Green
    Write-Host "║   - Docker:   $dockerVersion" -ForegroundColor Green
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ Services:" -ForegroundColor Green
    
    $sshStatus = (Get-Service sshd -ErrorAction SilentlyContinue).Status
    Write-Host "║   - SSH:      $sshStatus" -ForegroundColor Green
    
    Write-Host "╠════════════════════════════════════════════════════════════╣" -ForegroundColor Green
    Write-Host "║ Next Steps:" -ForegroundColor Green
    Write-Host "║   1. Restart computer if Docker was just installed" -ForegroundColor Green
    Write-Host "║   2. Start Docker Desktop" -ForegroundColor Green
    Write-Host "║   3. Run: docker compose up -d" -ForegroundColor Green
    Write-Host "╚════════════════════════════════════════════════════════════╝" -ForegroundColor Green
    Write-Host ""
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
function Main {
    Write-Section "Windows Node Bootstrap"
    Write-Log "Starting at $(Get-Date)"
    Write-Log "Role: $NodeRole"
    Write-Log "Install Directory: $InstallDir"
    
    Test-Prerequisites
    Install-Chocolatey
    Install-Dependencies
    Install-Docker
    Configure-Firewall
    Enable-SSHServer
    Clone-Repositories
    Configure-Node
    Create-DockerCompose
    Create-StartupTask
    Show-Status
    
    Write-Log "Completed at $(Get-Date)"
}

# Run main function
Main
