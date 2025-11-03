# FusionCloudX Windows Bootstrap
# Author: FusionCloudX Team
# Date: 2023-10-01
# Description: This script sets up the FusionCloudX environment on a Windows machine. Initial PowerShell script to install necessary components and configure the system on fresh Windows 11.
# Usage: Run this script as an administrator to ensure all components are installed correctly.


# Load config from YAML
if (-not (Get-Module -ListAvailable -Name powershell-yaml)) {
    Install-Module -Name powershell-yaml -Force -Scope CurrentUser
}
Import-Module powershell-yaml

$configFile = "config/bootstrap.yaml"
if (-not (Test-Path $configFile)) {
    Write-Error "Config file not found: $configFile"
    exit 1
}
$config = ConvertFrom-Yaml (Get-Content $configFile -Raw)

# Set config variables from YAML
$distroName = $config.wsl.distro_name
$customDistroName = $config.wsl.custom_distro_name
$env:EPHEMERAL_MODE = $config.wsl.ephemeral_mode
$env:CLEAN_RUN = $config.wsl.clean_run

# Git config
$gitUserName = $config.git.user_name
$gitUserEmail = $config.git.user_email

# Windows Update
$updateNow = $config.windows_update.enabled

# Tools
$tools = @()
foreach ($tool in $config.tools) {
    $tools += @{ Name = $tool.name; Id = $tool.id }
}

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
        try {
            $script:WingetCache = winget list
        } catch {
            Log-Warn "Failed to get Winget cache. Falling back to direct install."
            $script:WingetCache = ""
        }
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
        [Parameter(Mandatory)][string]$cmd,
        [switch]$DryRun,
        [switch]$CaptureOutput,
        [switch]$AllowFailure = $false
    )
    
    Log-Info "Executing in WSL [$customDistroName]: $cmd"
    
    if ($DryRun) {
        Log-Info "Dry run: & wsl -d $customDistroName -- bash -c $cmd"
    } else {
        if ($CaptureOutput) {
            Log-Info "Capturing output from WSL command."
            $output = & wsl -d $customDistroName -- bash -c $cmd
            if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
                Log-Error "WSL command $cmd failed with exit code $LASTEXITCODE"
                exit 1
            }
            return $output
        } else {
            & wsl -d $customDistroName -- bash -c $cmd
        
            if ($LASTEXITCODE -ne 0 -and -not $AllowFailure) {
                Log-Error "WSL command $cmd failed with exit code $LASTEXITCODE"
                exit 1
            }
        }
    }
}

function Remove-CustomWSLDistro {
    param (
        [string]$DistroName = $customDistroName
    )

    Log-Info "Checking for existing WSL distro: $DistroName..."
    
    $existingDistros = (& wsl --list --quiet) -replace '\s+$', ''
    $normalizedDistros = $existingDistros | ForEach-Object { $_.Trim().ToLower() }
    Log-Info "Registered WSL distros: $($normalizedDistros -join ', ')"
    
    if ($normalizedDistros -contains $DistroName.ToLower()) {
        Log-Info "WSL distro '$DistroName' found. Proceeding with teardown..."

        Log-Info "Terminating '$DistroName'..."
        & wsl --terminate "$DistroName"
        if ($LASTEXITCODE -ne 0) {
            Log-Warn "WSL termination of '$DistroName' may have failed. Exit code: $LASTEXITCODE"
        }

        Log-Info "Unregistering '$DistroName'..."
        & wsl --unregister "$DistroName"

        if ($LASTEXITCODE -eq 0) {
            Log-Success "WSL distro '$DistroName' unregistered successfully."
        } else {
            Log-Error "Failed to unregister WSL distro '$DistroName'. Exit code: $LASTEXITCODE"
        }
    } else {
        Log-Info "No teardown required. WSL distro '$DistroName' is not registered."
    }
}

function Convert-ToWSLPath ($windowsPath) {
    $driveLetter = $windowsPath.Substring(0,1).ToLower()
    $restOfPath = $windowsPath.Substring(2) -replace '\\', '/'
    return "/mnt/$driveLetter/$restOfPath"
}

# ─────────────────────────────────────────────────────────────
# START
# ─────────────────────────────────────────────────────────────

Require-Admin
Log-Info "🧱 FusionCloudX Windows Bootstrap starting..."
if ($env:EPHEMERAL_MODE -eq $true) {
    Log-Info "Ephemeral mode active. Custom WSL distro will be removed after setup."
}


# ─────────────────────────────────────────────────────────────
# Optional: Run Windows Update
# ─────────────────────────────────────────────────────────────
if ($updateNow -eq $true -or $updateNow -eq "true") {
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
Log-Info "Installing essential tools from $configFile..."
foreach ($tool in $tools) {
    Install-AppWithWingetIfMissing -WingetId $tool.Id -DisplayName $tool.Name
}
Log-Success "All essential tools installed successfully."

# ─────────────────────────────────────────────────────────────
# Confgure Git
# ─────────────────────────────────────────────────────────────



# Git config from YAML
if (-not $gitUserName -or -not $gitUserEmail) {
    Log-Error "git.user_name and git.user_email must be set in config/bootstrap.yaml for automated Git configuration."
    exit 1
}
$gitConfig = @{
    "user.name" = $gitUserName
    "user.email" = $gitUserEmail
    "core.editor" = "code --wait"
}

foreach ($key in $gitConfig.Keys) {
    Log-Info "Configuring Git: $key = $($gitConfig[$key])"
    git config --global $key $gitConfig[$key]
}

# ─────────────────────────────────────────────────────────────
# Install WSL and Alias Ubuntu Distro with Zero Manual Input
# ─────────────────────────────────────────────────────────────
Log-Info "Installing Ubuntu WSL distro as $customDistroName..."
if (-not (Get-Command wsl -ErrorAction SilentlyContinue)) {
    Log-Info "WSL not found. Installing WSL..."
    wsl --install --no-distribution --no-launch
    wsl --set-default-version 2
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to install WSL. Exit code: $LASTEXITCODE"
        exit 1
    } else {
        Log-Success "WSL distro installed successfully as $customDistroName."
    }
} else {
    Log-Info "WSL is already installed."
    wsl --update
    wsl --set-default-version 2
}

# ─────────────────────────────────────────────────────────────
# Check if the custom distro already exists
# ─────────────────────────────────────────────────────────────
$wslDistros = wsl -l -q
if ($wslDistros -contains $customDistroName) {
    Log-Warn "WSL distro '$customDistroName' already exists. Skipping installation."
} else {
    Log-Info "Installing WSL distro as $customDistroName..."
    wsl --install -d $distroName --name $customDistroName --no-launch
    if ($LASTEXITCODE -ne 0) {
        Log-Error "Failed to install $distroName as '$customDistroName'. Exit code: $LASTEXITCODE"
        exit 1
    } else {
        Log-Success "WSL distro '$customDistroName' installed successfully."
    }
}

# ─────────────────────────────────────────────────────────────
# Provision the distro (headless user creation and config)
# ─────────────────────────────────────────────────────────────
Log-Info "Provisioning $customDistroName (automated user creation and configuration)..."

& wsl -d $customDistroName -- bash -c "id -u fcx > /dev/null 2>&1"
if ($LASTEXITCODE -ne 0) {
    Log-Info "User'fcx' not found. Creating user and enabling passwordless sudo..."

$provisionScript = @'
#!/bin/bash
set -e

# Create user if it doesn't exist
if ! id "fcx" &>/dev/null; then
    adduser --disabled-password --gecos "" fcx
    echo "fcx ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/fcx
    chmod 0440 /etc/sudoers.d/fcx
    mkdir -p /home/fcx
    chown -R fcx:fcx /home/fcx
    echo -e "[user]\ndefault=fcx" > /etc/wsl.conf
fi
'@ -replace "`r`n", "`n"  # Converts CRLF to LF (UNIX line endings)

    $tempScriptPath = "$env:TEMP\provision_fcx.sh"
    $utf8NoBom = New-Object System.Text.UTF8Encoding($false)
    [System.IO.File]::WriteAllText($tempScriptPath, $provisionScript, $utf8NoBom)

    Log-Info "Setting default user 'fcx' in WSL..."    
    $wslScriptPath = Convert-ToWSLPath $tempScriptPath
    & wsl -d $customDistroName -- bash "$wslScriptPath"

    if ($LASTEXITCODE -ne 0) {
        Log-Error "$customDistroName User provisioning failed. Exit code: $LASTEXITCODE"
        exit 1
    } else {
        Log-Success "User 'fcx' created and sudo access configured successfully."
        Log-Info "Restarting WSL to apply config..."
        & wsl --terminate $customDistroName
        Start-Sleep -Seconds 2
    }
} else {
    Log-Warn "User 'fcx' already provisioned. Skipping user creation."
}

# ─────────────────────────────────────────────────────────────
# Enable passwordless sudo in WSL ephemeral Ubuntu
# This is necessary for running scripts without needing to enter a password each time.
# ─────────────────────────────────────────────────────────────
$wslSudoConfigPath = "/etc/sudoers.d/dont-prompt-root-for-sudo-password"
if (-not (Invoke-WSLCommand "test -f $wslSudoConfigPath" -AllowFailure)) {
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

# Dynamically determine the Windows path to this repo and convert to WSL path
$repoRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$wslMountPath = Convert-ToWSLPath $repoRoot
$wslTarget = "/home/fcx/fusioncloudx-bootstrap"

Invoke-WSLCommand "test -e $wslTarget" -AllowFailure
if ($LASTEXITCODE -eq 0) {
    Log-Info "Target directory already exists in WSL. Skipping symlink creation."
} else {
    Invoke-WSLCommand "test -L $wslTarget" -AllowFailure
    Log-Info "Target directory does not exist in WSL. Proceeding with symlink creation."
    if ($LASTEXITCODE -eq 0) {
        Log-Info "Symlink already exists at $wslTarget. Skipping symlink creation."
    } else {
        # Create the symlink
        Invoke-WSLCommand "ln -s '$wslMountPath' '$wslTarget'"
        if ($LASTEXITCODE -ne 0) {
            Log-Error "Failed to link Windows repo into WSL. Exit code: $LASTEXITCODE"
            exit 1
        } else {
            Log-Success "Repo linked into WSL successfully."
        }
    }
}

# ─────────────────────────────────────────────────────────────
# Execute Bootstrap Script Inside WSL
# ─────────────────────────────────────────────────────────────
Log-Info "Executing bootstrap.sh inside WSL..."

$bootstrapScriptPath = "$wslTarget/bootstrap.sh"

Invoke-WSLCommand "chmod +x '$bootstrapScriptPath'"
Invoke-WSLCommand "'$bootstrapScriptPath'"

if ($LASTEXITCODE -ne 0) {
    Log-Error "Failed to execute bootstrap.sh inside WSL. Exit code: $LASTEXITCODE"
    exit 1
} else {
    Log-Success "Bootstrap script executed successfully inside WSL."
}

# ─────────────────────────────────────────────────────────────
# Teardown Custom Distro and Clean Up
# ─────────────────────────────────────────────────────────────
if ($env:EPHEMERAL_MODE -eq $true -and $LASTEXITCODE -eq 0) {
    Remove-CustomWSLDistro -DistroName $customDistroName
    Log-Info "Ephemeral mode active — clean teardown executed for $customDistroName."
} elseif ($env:EPHEMERAL_MODE -eq $true -and $LASTEXITCODE -ne 0) {
    Log-Warn "Ephemeral mode active, but teardown skipped due to bootstrap failure."
} else {
    Log-Info "Ephemeral mode not active. Skipping teardown."
}
# ─────────────────────────────────────────────────────────────
# COMPLETE
# ─────────────────────────────────────────────────────────────

Log-Success "🎉 FusionCloudX Windows Bootstrap completed!"