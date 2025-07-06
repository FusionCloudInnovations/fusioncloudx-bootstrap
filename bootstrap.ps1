# FusionCloudX Windows Bootstrap
# Author: FusionCloudX Team
# Date: 2023-10-01
# Description: This script sets up the FusionCloudX environment on a Windows machine. Initial PowerShell script to install necessary components and configure the system on fresh Windows 11.
# Usage: Run this script as an administrator to ensure all components are installed correctly.

$customDistroName = "Ubuntu-FCX"
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
        Log-Info "[INFO] Gathering list of winget packages..." -ForegroundColor Cyan
        $script:WingetCache = winget list
    }

    if ($script:WingetCache -match [regex]::Escape($WingetId)) {
        Log-Warn "[SKIP] $DisplayName is already installed." -ForegroundColor Yellow
    } else {
        Log-Info "[INFO] Installing $DisplayName..." -ForegroundColor Cyan
        try {
            winget install --id $WingetId -e --silent --accept-source-agreements --accept-package-agreements
            if ($LASTEXITCODE -ne 0) {
                Log-Error "[ERROR] Failed to install $DisplayName. Winget returned exit code $LASTEXITCODE." -ForegroundColor Red
            } else {
                Log-Success "[SUCCESS] $DisplayName installed successfully." -ForegroundColor Green
            }
        } catch {
            Log-Error "[ERROR] Failed to install $DisplayName : $_" -ForegroundColor Red
        }
    }
}

function Invoke-WSLCommand {
    param (
        [string]$cmd,
        [string]$DryRun
    )
    
    $escapedCmd = $cmd.Replace('"', '\"')
    Log-Info "Executing in WSL [$customDistroName]: $cmd"
    
    if ($DryRun) {
        Log-Info "Dry run: & wsl -d $customDistroName -- bash -c `"$escapedCmd`""
    } else {
        & wsl -d $customDistroName -- bash -c "`"$escapedCmd`""
        # $output = & wsl -d $customDistroName -- bash -c "$escapedCmd"
    
        if ($LASTEXITCODE -ne 0) {
            Log-Error "WSL command failed with exit code $LASTEXITCODE"
            exit 1
        }
        
        # return $output
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
Log-Info "Installing Ubuntu WSL distro as $customDistroName..."
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Log-Info "WSL not found. Installing WSL..."
    wsl --install -d Ubuntu --name $customDistroName --no-launch
    wsl --set-default-version 2
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to install WSL. Exit code: $LASTEXITCODE"
    } else {
        Log-Success "WSL distro installed successfully as $customDistroName."
    }
} else {
    Log-Info "WSL is already installed."
}

# ─────────────────────────────────────────────────────────────
# Enable passwordless sudo in WSL ephemeral Ubuntu
# This is necessary for running scripts without needing to enter a password each time.
# ─────────────────────────────────────────────────────────────
$wslSudoConfigPath = "/etc/sudoers.d/wsl"
if (-not (Invoke-WSLCommand test -f $wslSudoConfigPath)) {
    Log-Info "Enabling passwordless sudo in WSL..."
    $user = & wsl -d $customDistroName -- whoami
    wsl -u root bash -c "echo '$user ALL=(ALL) NOPASSWD: ALL' > $wslSudoConfigPath"
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to enable passwordless sudo in WSL. Exit code: $LASTEXITCODE"
    } else {
        Log-Success "Passwordless sudo enabled in WSL."
    }
} else {
    Log-Info "Passwordless sudo already configured in WSL."
}

# ─────────────────────────────────────────────────────────────
# Link Existing Repo Into WSL Instead of Cloning via SSH
# ─────────────────────────────────────────────────────────────
Log-Info "Linking existing Windows repo into WSL..."

$wslMountPath = "/mnt/f/Personal/Repositories/fusioncloudx-bootstrap"
$wslTarget = "/home/fcx/fusioncloudx-bootstrap"

Invoke-WSLCommand "[[ -e '$wslTarget' ]]"
if ($LASTEXITCODE -eq 0) {
    Log-Info "Target directory already exists in WSL. Skipping symlink creation."
} else {
    Log-Info "Target directory does not exist in WSL. Proceeding with symlink creation."
}
Invoke-WSLCommand test -L $wslTarget
if ($LASTEXITCODE -eq 0) {
    Log-Info "Symlink already exists at $wslTarget. Skipping symlink creation."
} else {
    # Create the symlink
    Invoke-WSLCommand ln -s $wslMountPath $wslTarget
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to link Windows repo into WSL. Exit code: $LASTEXITCODE"
        exit 1
    } else {
        Log-Success "Repo linked into WSL successfully."
    }
}

# ─────────────────────────────────────────────────────────────
# COMPLETE
# ─────────────────────────────────────────────────────────────

Log-Success "🎉 FusionCloudX Windows Bootstrap completed!"