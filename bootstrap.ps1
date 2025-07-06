# FusionCloudX Windows Bootstrap
# Author: FusionCloudX Team
# Date: 2023-10-01
# Description: This script sets up the FusionCloudX environment on a Windows machine. Initial PowerShell script to install necessary components and configure the system on fresh Windows 11.
# Usage: Run this script as an administrator to ensure all components are installed correctly.

# ─────────────────────────────────────────────────────────────
# FUNCTIONS
# ─────────────────────────────────────────────────────────────

function Log {
    param ([string]$level, [string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "[$timestamp][$level] $message"
}

function Log-Info { Log "INFO" $args[0] }
function Log-Success { Log "SUCCESS" $args[0] }
function Log-Warn { Log "WARN" $args[0] }
function Log-Error { Log "ERROR" $args[0] }

function Require-Admin {
    if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
        Log-Error "This script must be run as Administrator."
        exit 1
    }
}

function Install-ModuleIfNeeded {
    param (
        [string]$moduleName,
        [switch]$force
    )
    if (-not (Get-Module -ListAvailable -Name $moduleName)) {
        Log-Info "Installing module: $moduleName"
        Install-Module -Name $moduleName -Force:$force -Scope CurrentUser
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to install module: $moduleName"
            exit 1
        }
    } else {
        Log-Info "Module $moduleName is already installed."
    }
}

function Install-AppWithWingetIfMissing {
    param(
        [Parameter(Mandatory = $true)][string]$WingetId,
        [string]$DisplayName = $WingetId
    )

    #Cache winget list once for performance
    if (-not $script:WingetCache) {
        Write-Host "[INFO] Gathering list of winget packages..." -ForegroundColor Cyan
        $script:WingetCache = winget list
    }

    if ($script:WingetCache -match [regex]::Escape($WingetId)) {
        Write-Host "[SKIP] $DisplayName is already installed." -ForegroundColor Yellow
    } else {
        Write-Host "[INFO] Installing $DisplayName..." -ForegroundColor Cyan
        try {
            winget install --id $WingetId -e --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Write-Host "[ERROR] Failed to install $DisplayName. Winget returned exit code $LASTEXITCODE." -ForegroundColor Red
            } else {
                Write-Host "[SUCCESS] $DisplayName installed successfully." -ForegroundColor Green
            }
        } catch {
            Write-Host "[ERROR] Failed to install $DisplayName : $_" -ForegroundColor Red
        }
    }
}


# ─────────────────────────────────────────────────────────────
# START
# ─────────────────────────────────────────────────────────────

Require-Admin
Log-Info "🧱 FusionCloudX Windows Bootstrap starting..."

# ─────────────────────────────────────────────────────────────
# Optional: Run Windows Update
# ─────────────────────────────────────────────────────────────
$updateNow = $true

if ($updateNow) {
    Install-ModuleIfNeeded -moduleName "PSWindowsUpdate" -force:$true
    Import-Module PSWindowsUpdate
    Log-Info "Checking for Windows updates..."
    $updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot 
    if ($updates) {
        Log-Info "Installing Windows updates..."
        $updates | Install-WindowsUpdate -AcceptAll -IgnoreReboot -Verbose
        Log-Success "Windows updates installed successfully."
    } else {
        Log-Info "No updates available."
    }
}

# ─────────────────────────────────────────────────────────────
# Ensure Winget is installed
# ─────────────────────────────────────────────────────────────
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Log-Info "Winget not found. Installing Winget..."
    $wingetUrl = "https://aka.ms/getwinget"
    $wingetInstaller = "$env:TEMP\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe.msixbundle"
    Invoke-WebRequest -Uri $wingetUrl -OutFile $wingetInstaller
    Add-AppxPackage -Path $wingetInstaller
    Log-Success "Winget installed successfully."
} else {
    Log-Info "Winget is already installed."
}

# ─────────────────────────────────────────────────────────────
# Install essential tools
# ─────────────────────────────────────────────────────────────
$tools = @(
    @{ Name = "Git"; Id = "Git.Git"; },
    @{ Name = "Microsoft.WindowsTerminal"; Id = "Microsoft.WindowsTerminal"; },
    @{ Name = "PowerShell 7-x64 "; Id = "Microsoft.PowerShell"; },
    @{ Name = "Canonical.Ubuntu"; Id = "Canonical.Ubuntu"; },
    @{ Name = "7-Zip"; Id = "7zip.7zip"; }
)

Log-Info "Installing essential tools..."
foreach ($tool in $tools) {
    Install-AppWithWingetIfMissing -WingetId $tool.Id -DisplayName $tool.Name
}

Log-Success "All essential tools installed successfully."

# ─────────────────────────────────────────────────────────────
# Confgure Git
# ─────────────────────────────────────────────────────────────
$gitConfig = @{
    "user.name" = "Branden Miller"
    "user.email" = "76793954+thisisbramiller@users.noreply.github.com"
    "core.editor" = "code --wait"
}

foreach ($key in $gitConfig.Keys) {
    Log-Info "Configuring Git: $key = $($gitConfig[$key])"
    git config --global $key $gitConfig[$key]
}

# ─────────────────────────────────────────────────────────────
# Install WSL and ephemeral Ubuntu
# ─────────────────────────────────────────────────────────────
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Log-Info "WSL not found. Installing WSL..."
    wsl --install --no-distribution --no-launch
    wsl --set-default-version 2
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to install WSL. Exit code: $LASTEXITCODE"
    } else {
        Log-Success "WSL installed successfully."
    }
} else {
    Log-Info "WSL is already installed."
}

# Set Ubuntu as the default WSL distribution
$ubuntuDistro = "Ubuntu"
$wslDistros = wsl -l -q
if ($wslDistros -contains $ubuntuDistro) {
    Log-Info "Setting $ubuntuDistro as the default WSL distribution..."
    wsl --set-default $ubuntuDistro
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to set $ubuntuDistro as default WSL distribution. Exit code: $LASTEXITCODE"
    } else {
        Log-Success "$ubuntuDistro set as the default WSL distribution."
    }
} else {
    Log-Warn "$ubuntuDistro not found in WSL distributions."
}

# ─────────────────────────────────────────────────────────────
# Enable passwordless sudo in WSL ephemeral Ubuntu
# This is necessary for running scripts without needing to enter a password each time.
# ─────────────────────────────────────────────────────────────
$wslSudoConfigPath = "/etc/sudoers.d/wsl"
if (-not (wsl test -f $wslSudoConfigPath)) {
    Log-Info "Enabling passwordless sudo in WSL..."
    wsl -u root bash -c "echo '$(wsl whoami) ALL=(ALL) NOPASSWD: ALL' > $wslSudoConfigPath"
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to enable passwordless sudo in WSL. Exit code: $LASTEXITCODE"
    } else {
        Log-Success "Passwordless sudo enabled in WSL."
    }
} else {
    Log-Info "Passwordless sudo already configured in WSL."
}

# ─────────────────────────────────────────────────────────────
# SSH Host Key Fingerprinting Pre Trust (Security)
# ─────────────────────────────────────────────────────────────
Log-Info "Pre-trusting GitHub SSH host key fingerprint..."

wsl bash -c "ssh-keyscan github.com >> ~/.ssh/known_hosts"
if ($LASTEXITCODE -ne 0) {
    Log-Error "Failed to pre-trust GitHub SSH host key. Exit code: $LASTEXITCODE"
} else {
    Log-Success "GitHub SSH host key fingerprint added to known_hosts."
}

# ─────────────────────────────────────────────────────────────
# Ensure GitHub SSH key is imported in WSL via ssh-import-id skip if already imported
# ─────────────────────────────────────────────────────────────
$githubUsername = "thisisbramiller"

Log-Info "Ensuring ssh-import-id is installed in WSL..."

if (-not (wsl bash -c "command -v ssh-import-id")) {
    Log-Info "ssh-import-id not found in WSL. Installing..."
    wsl sudo apt-get update -y
    wsl sudo apt-get install -y ssh-import-id
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to install ssh-import-id. Exit code: $LASTEXITCODE"
        exit 1
    }
    Log-Success "ssh-import-id installed successfully in WSL."
} else {
    Log-Info "ssh-import-id is already installed in WSL."
}

# Import GitHub key in WSL if not already present
Log-Info "Ensuring SSH keys are imported from GitHub user: $githubUsername"
wsl ssh-import-id gh:$githubUsername
if ($LASTEXITCODE -ne 0) {
    Log-Error "Failed to import SSH keys for GitHub user: $githubUsername. Exit code: $LASTEXITCODE"
    exit 1
} else {
    Log-Success "SSH keys ensured for GitHub user: $githubUsername (imported or already present)."
}

# ─────────────────────────────────────────────────────────────
# Clone the FusionCloudX bootstrap repository inside WSL and launch bootstrap.sh
# ─────────────────────────────────────────────────────────────
$repoUrl = "git@github.com:FusionCloudX/fusioncloudx-bootstrap.git"
$clonePath = "/home/$(wsl whoami)/fusioncloudx-bootstrap"

if (-not (Test-Path -Path $clonePath)) {
    Log-Info "Cloning FusionCloudX bootstrap repository into WSL..."
    wsl git clone $repoUrl $clonePath
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to clone repository. Exit code: $LASTEXITCODE"
    } else {
        Log-Success "Repository cloned successfully to $clonePath."
    }
} else {
    Log-Info "FusionCloudX bootstrap repository already exists in WSL at $clonePath."
}

# ─────────────────────────────────────────────────────────────
# COMPLETE
# ─────────────────────────────────────────────────────────────

Log-Success "🎉 FusionCloudX Windows Bootstrap completed!"