#Requires -Version 5.1
<#
.SYNOPSIS
  One-shot toolchain setup for Forja Windows releases inside a Parallels VM.

.DESCRIPTION
  Installs Chocolatey (if missing), Git, Inno Setup 6, Rust (rustup), Flutter
  stable, and Visual Studio 2022 Build Tools with the VC++ workload — the same
  stack GitHub Actions windows-latest effectively provides for our release.yml.

  Run in an elevated PowerShell inside the Windows 11 VM:
    Set-ExecutionPolicy Bypass -Scope Process -Force
    .\scripts\setup_windows_vm.ps1

  Optional env:
    FORJA_FLUTTER_ROOT  default C:\dev\flutter
    FORJA_SKIP_VS       set to 1 to skip VS Build Tools (install Community manually)

.NOTES
  First run: 30–90+ minutes, needs ~40GB free disk.
#>

$ErrorActionPreference = "Stop"
$FlutterRoot = if ($env:FORJA_FLUTTER_ROOT) { $env:FORJA_FLUTTER_ROOT } else { "C:\dev\flutter" }
$SkipVs = $env:FORJA_SKIP_VS -eq "1"

function Write-Step($msg) { Write-Host "==> $msg" -ForegroundColor Cyan }
function Assert-Admin {
  $id = [Security.Principal.WindowsIdentity]::GetCurrent()
  $p = New-Object Security.Principal.WindowsPrincipal($id)
  if (-not $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    throw "Run this script as Administrator (elevated PowerShell)."
  }
}

function Ensure-Chocolatey {
  if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Chocolatey already installed"
    return
  }
  Write-Step "Install Chocolatey"
  Set-ExecutionPolicy Bypass -Scope Process -Force
  [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
  Invoke-Expression ((New-Object System.Net.WebClient).DownloadString("https://community.chocolatey.org/install.ps1"))
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path", "User")
}

function Ensure-ChocoPackage([string]$Name, [string]$ExtraArgs = "") {
  $installed = choco list --local-only --limit-output | Select-String -SimpleMatch "$Name|"
  if ($installed) {
    Write-Host "choco: $Name already installed"
    return
  }
  Write-Step "choco install $Name"
  if ($ExtraArgs) {
    Invoke-Expression "choco install $Name -y --no-progress $ExtraArgs"
  } else {
    choco install $Name -y --no-progress
  }
}

function Add-UserPath([string]$Dir) {
  if (-not (Test-Path $Dir)) { return }
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -split ";" | Where-Object { $_ -ieq $Dir }) { return }
  [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(";") + ";" + $Dir), "User")
  $env:Path += ";$Dir"
}

Assert-Admin
Ensure-Chocolatey

Write-Step "Core packages (git, innosetup, rustup)"
Ensure-ChocoPackage "git"
Ensure-ChocoPackage "innosetup"
Ensure-ChocoPackage "rustup.install"

if (-not $SkipVs) {
  Write-Step "Visual Studio 2022 Build Tools (VC++ — long install)"
  # Matches what Flutter Windows needs. Re-run is mostly a no-op if already present.
  $vsParams = '--package-parameters "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --norestart"'
  try {
    Ensure-ChocoPackage "visualstudio2022buildtools" $vsParams
  } catch {
    Write-Warning "VS Build Tools via choco failed: $_"
    Write-Warning "Install Visual Studio 2022 Community manually with 'Desktop development with C++', then re-run with FORJA_SKIP_VS=1"
  }
} else {
  Write-Host "Skipping VS Build Tools (FORJA_SKIP_VS=1)"
}

Write-Step "Flutter stable → $FlutterRoot"
if (-not (Test-Path "$FlutterRoot\bin\flutter.bat")) {
  New-Item -ItemType Directory -Force -Path (Split-Path $FlutterRoot) | Out-Null
  if (Test-Path $FlutterRoot) { Remove-Item -Recurse -Force $FlutterRoot }
  git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FlutterRoot
} else {
  Write-Host "Flutter already at $FlutterRoot — running upgrade"
  & "$FlutterRoot\bin\flutter.bat" upgrade --force
}
Add-UserPath "$FlutterRoot\bin"
Add-UserPath "$env:USERPROFILE\.cargo\bin"

# Refresh PATH for this session
$env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
            [Environment]::GetEnvironmentVariable("Path", "User")

Write-Step "flutter config + doctor"
& flutter config --enable-windows-desktop
& flutter doctor -v

$iscc = "${env:ProgramFiles(x86)}\Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
  Write-Warning "ISCC.exe not found at $iscc — Inno Setup may need a new shell / reboot"
} else {
  Write-Host "Inno Setup OK: $iscc"
}

if (Get-Command rustc -ErrorAction SilentlyContinue) {
  Write-Host "Rust OK: $(rustc --version)"
} else {
  Write-Warning "rustc not on PATH yet — open a new terminal or reboot after rustup"
}

Write-Host ""
Write-Host "Setup finished." -ForegroundColor Green
Write-Host "Next:"
Write-Host "  1. Open a NEW PowerShell / Git Bash (PATH refresh)"
Write-Host "  2. cd to the Forja repo (shared folder or C:\dev\Forja clone)"
Write-Host "  3. Copy .env from the Mac into the repo root"
Write-Host "  4. bash ./scripts/build_windows_release.sh <version>"
Write-Host "     e.g. bash ./scripts/build_windows_release.sh 1.2.403"
Write-Host ""
Write-Host "From the Mac (after setup), Parallels build:"
Write-Host "  FORJA_PRL_VM='Windows 11' ./scripts/release_local.sh build-windows v1.2.403"
