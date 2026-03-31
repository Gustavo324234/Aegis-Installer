<#
.SYNOPSIS
    Aegis DevSync - Windows-to-Server Sync Script
.DESCRIPTION
    Ticket: INST-120 | Epic 24 - Dev Sync & Hot-Reload Toolchain
    Syncs modified files from C:\Aegis to the Debian server via rsync+SSH,
    then triggers aegis_hotreload.sh for selective container reload.
.PARAMETER Repo
    Which repo to sync: "all", "ank", "shell", "installer" (default: "all")
.PARAMETER Server
    IP address of the Debian server (default: "192.168.1.20")
.PARAMETER User
    SSH username (default: "diego")
.PARAMETER KeyPath
    Path to SSH private key (default: "$HOME\.ssh\id_ed25519")
.PARAMETER DryRun
    Show what would be synced without executing
.EXAMPLE
    .\aegis_sync.ps1                    # Sync everything
    .\aegis_sync.ps1 -Repo shell        # Only Aegis-Shell (~5 seconds)
    .\aegis_sync.ps1 -Repo ank          # Only Aegis-ANK (compiles on server)
    .\aegis_sync.ps1 -DryRun            # Preview mode
    .\aegis_sync.ps1 -Server 192.168.1.50  # Different server
#>

[CmdletBinding()]
param(
    [ValidateSet("all", "ank", "shell", "installer")]
    [string]$Repo = "all",

    [string]$Server = "192.168.1.20",

    [string]$User = "diego",

    [string]$KeyPath = "$HOME\.ssh\id_ed25519",

    [string]$LocalBase = "C:\Aegis",

    [string]$RemoteBase = "/home/diego/Documentos/Aegis",

    [switch]$DryRun,
    [switch]$ResetSystem
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# --- Configuration ---
$HotReloadCmd = "$RemoteBase/Aegis-Installer/aegis_hotreload.sh"

# Repo map: name -> (local folder, remote folder)
$RepoMap = @{
    "ank"       = @{ Local = "Aegis-ANK";       Remote = "Aegis-ANK" }
    "shell"     = @{ Local = "Aegis-Shell";     Remote = "Aegis-Shell" }
    "installer" = @{ Local = "Aegis-Installer"; Remote = "Aegis-Installer" }
}

# Mandatory exclusions - SECURITY CRITICAL: .env must NEVER transfer
$RsyncExcludes = @(
    "--exclude=target/",
    "--exclude=node_modules/",
    "--exclude=.git/",
    "--exclude=__pycache__/",
    "--exclude=*.pyc",
    "--exclude=users/",
    "--exclude=models/",
    "--exclude=.env",
    "--exclude=.env.*"
)

# --- Colors & Logging ---
function Write-Banner {
    Write-Host ""
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host "   AEGIS OS - DEV SYNC ENGINE                     " -ForegroundColor Cyan
    Write-Host "==================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Log {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$($ts)] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[INFO] " -NoNewline -ForegroundColor Cyan
    Write-Host "$($Message)"
}

function Write-Success {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$($ts)] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[OK]   " -NoNewline -ForegroundColor Green
    Write-Host "$($Message)"
}

function Write-Warn {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$($ts)] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[WARN] " -NoNewline -ForegroundColor Yellow
    Write-Host "$($Message)"
}

function Write-Err {
    param([string]$Message)
    $ts = Get-Date -Format "HH:mm:ss"
    Write-Host "[$($ts)] " -NoNewline -ForegroundColor DarkGray
    Write-Host "[ERROR] " -NoNewline -ForegroundColor Red
    Write-Host "$($Message)"
}

# --- Rsync Detection ---
function Find-Rsync {
    $rsyncPath = Get-Command rsync -ErrorAction SilentlyContinue
    if ($rsyncPath) { return @{ Command = "rsync"; Type = "native" } }

    $gitBashRsync = "C:\Program Files\Git\usr\bin\rsync.exe"
    if (Test-Path $gitBashRsync) { return @{ Command = $gitBashRsync; Type = "gitbash" } }

    $wslPath = Get-Command wsl -ErrorAction SilentlyContinue
    if ($wslPath) {
        $null = & wsl which rsync 2>$null
        if ($LASTEXITCODE -eq 0) { return @{ Command = "wsl rsync"; Type = "wsl" } }
    }

    return $null
}

# --- Path Conversion ---
function Convert-ToRsyncPath {
    param([string]$WinPath, [string]$RsyncType)
    $path = $WinPath -replace '\\', '/'
    if ($path -match '^([A-Za-z]):(.*)$') {
        $drive = $Matches[1].ToLower()
        $rest  = $Matches[2]
        if ($RsyncType -eq "wsl") { return "/mnt/$drive$rest" }
        return "/$drive$rest"
    }
    return $path
}

function Convert-KeyPath {
    param([string]$WinKeyPath, [string]$RsyncType)
    if ($RsyncType -ne "wsl") { return $WinKeyPath }
    # Keys on /mnt/c usually have 777 permissions and are rejected by SSH.
    # We use a copy inside the WSL filesystem that we prepared with 600 permissions.
    return "~/.ssh/id_ed25519"
}

# --- Sync Single Repo ---
function Sync-Repo {
    param([string]$RepoName, [hashtable]$RsyncInfo, [bool]$IsDryRun)

    $localDir  = Join-Path $LocalBase $RepoMap[$RepoName].Local
    $remoteDir = "$RemoteBase/$($RepoMap[$RepoName].Remote)"

    if (-not (Test-Path $localDir)) {
        Write-Warn "Local directory not found: $($localDir) - skipping $($RepoName)"
        return $false
    }

    $rsyncSrc     = Convert-ToRsyncPath "$localDir/" $RsyncInfo.Type
    $rsyncKeyPath = Convert-KeyPath $KeyPath $RsyncInfo.Type
    $rsyncDest    = "${User}@${Server}:${remoteDir}/"

    $rsyncArgs = @(
        "-avz", "--delete", "--stats",
        "-e", "ssh -i $rsyncKeyPath -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -q"
    )
    foreach ($exclude in $RsyncExcludes) { $rsyncArgs += $exclude }
    if ($IsDryRun) { $rsyncArgs += "--dry-run" }
    $rsyncArgs += $rsyncSrc
    $rsyncArgs += $rsyncDest

    Write-Log "Syncing $($RepoName) to $($rsyncDest)"

    if ($RsyncInfo.Type -eq "wsl") {
        # Fix quoting for bash -c: the -e argument content requires internal quotes
        $escapedArgs = @()
        foreach ($arg in $rsyncArgs) {
            if ($arg -match " ") { $escapedArgs += "'$($arg)'" }
            else { $escapedArgs += $arg }
        }
        $fullCmd = "rsync " + ($escapedArgs -join " ")
        $output  = & wsl bash -c $fullCmd 2>&1
    } else {
        $output = & $RsyncInfo.Command @rsyncArgs 2>&1
    }

    if ($LASTEXITCODE -ne 0) {
        Write-Err "rsync failed for $($RepoName) (exit $($LASTEXITCODE))"
        Write-Host ($output | Out-String) -ForegroundColor Red
        return $false
    }

    $transferLine = $output | Where-Object { $_ -match "Number of regular files transferred" }
    if ($transferLine) { Write-Success "$($RepoName) : $($transferLine)" }
    else               { Write-Success "$($RepoName) sync complete" }

    if ($IsDryRun) { Write-Host ($output | Out-String) -ForegroundColor DarkGray }
    return $true
}

# --- Remote Hot-Reload Dispatch ---
function Invoke-HotReload {
    param([string]$RepoTarget, [bool]$DoReset)

    Write-Log "Dispatching hot-reload on server (--repo $($RepoTarget))..."
    if ($RepoTarget -eq "ank") {
        Write-Warn "ANK reload includes Rust compilation - this takes 1-5 minutes..."
    }

    $remoteCmd = "$HotReloadCmd --repo $($RepoTarget)"
    if ($DoReset) { $remoteCmd += " --reset" }

    $sshArgs = @(
        "-i", $KeyPath,
        "-o", "StrictHostKeyChecking=no",
        "-o", "UserKnownHostsFile=/dev/null",
        "-q",
        "${User}@${Server}",
        $remoteCmd
    )

    # SRE Hardening: Handling NativeCommandError during stderr redirection (Ticket SYNC-112)
    $oldEAP = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    
    try {
        & ssh @sshArgs 2>&1 | ForEach-Object { 
            if ($_ -is [System.Management.Automation.ErrorRecord]) {
                Write-Host "  $($_.TargetObject)" 
            } else {
                Write-Host "  $_"
            }
        }
    } catch {
        # Ignore redirection errors, rely on $LASTEXITCODE
    } finally {
        $ErrorActionPreference = $oldEAP
    }

    if ($LASTEXITCODE -ne 0 -and $RepoTarget -ne "installer") {
        Write-Err "Hot-reload failed on server (exit $($LASTEXITCODE))"
        return $false
    }

    Write-Success "Hot-reload completed successfully"
    return $true
}

# ==============================================================================
# MAIN
# ==============================================================================

$sw = [System.Diagnostics.Stopwatch]::StartNew()
Write-Banner

# 1. Validate SSH key
if (-not (Test-Path $KeyPath)) {
    Write-Err "SSH key not found: $($KeyPath)"
    Write-Host "  Generate: ssh-keygen -t ed25519" -ForegroundColor Yellow
    Write-Host "  Copy to server: ssh-copy-id -i $($KeyPath) $($User)@$($Server)" -ForegroundColor Yellow
    exit 1
}

# 2. Detect rsync
$rsyncInfo = Find-Rsync
if (-not $rsyncInfo) {
    Write-Err "rsync not found. Install Git for Windows (with Unix tools) or WSL rsync."
    exit 1
}
Write-Log "rsync via $($rsyncInfo.Type)"

# 3. Build target list
$targetRepos = if ($Repo -eq "all") { @("ank", "shell", "installer") } else { @($Repo) }

if ($DryRun) { Write-Warn "DRY-RUN - no files will transfer, no reload will occur"; Write-Host "" }

$targetStr = $targetRepos -join ', '
Write-Log "Target: $($targetStr) | Server: $($User)@$($Server)"

# 3.5 Generate Sync Version
$SyncVersion = "DevSync-" + (Get-Date -Format "yyyyMMdd-HHmm")
$VersionFile = Join-Path $LocalBase "Aegis-Shell\bff\VERSION"
if (-not $DryRun) {
    Set-Content -Path $VersionFile -Value $SyncVersion -Force
    Write-Log "Sync Version: $($SyncVersion)"
}

Write-Host ""

# 4. Sync
$anyFailed   = $false
$syncedRepos = @()

foreach ($r in $targetRepos) {
    $ok = Sync-Repo -RepoName $r -RsyncInfo $rsyncInfo -IsDryRun $DryRun
    if (-not $ok) { $anyFailed = $true } else { $syncedRepos += $r }
}

if ($anyFailed -and $syncedRepos.Count -eq 0) { Write-Err "All syncs failed."; exit 1 }

# 5. Hot-reload
if (-not $DryRun -and $syncedRepos.Count -gt 0) {
    Write-Host ""
    $reloadTarget = if ($Repo -eq "all" -and $syncedRepos.Count -eq 1) { $syncedRepos[0] } else { $Repo }
    $ok = Invoke-HotReload -RepoTarget $reloadTarget -DoReset $ResetSystem
    if (-not $ok) { Write-Warn "Sync OK but hot-reload had errors. Check server logs." }
}

# 6. Report
$sw.Stop()
$elapsed = [math]::Round($sw.Elapsed.TotalSeconds, 1)
$syncedStr = $syncedRepos -join ', '
Write-Host ""
Write-Host "==================================================" -ForegroundColor Green
Write-Host "   SYNC COMPLETE                                   " -ForegroundColor Green
Write-Host "==================================================" -ForegroundColor Green
Write-Success "Total: $($elapsed)s | Repos: $($syncedStr)"
if ($DryRun) { Write-Warn "DRY-RUN - no changes made." }
Write-Host ""
