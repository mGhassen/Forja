#Requires -Version 5.1
# ASCII-only on purpose: Windows PowerShell on UNC shares often misreads UTF-8
# punctuation and breaks parsing.
#
# One-shot toolchain setup for Forja Windows releases (Parallels / bare metal).
# Installs Chocolatey (if missing), Git, Inno Setup 6, Rust (rustup), Flutter
# stable, and Visual Studio 2022 Build Tools with the VC++ workload.
#
# Run in an elevated PowerShell inside Windows:
#   Set-ExecutionPolicy Bypass -Scope Process -Force
#   .\scripts\setup_windows_vm.ps1
#
# Optional env:
#   FORJA_FLUTTER_ROOT  default C:\dev\flutter
#   FORJA_SKIP_VS       set to 1 to skip VS Build Tools
#
# First run: 30-90+ minutes, needs ~40GB free disk.

$ErrorActionPreference = "Stop"
$FlutterRoot = if ($env:FORJA_FLUTTER_ROOT) { $env:FORJA_FLUTTER_ROOT } else { "C:\dev\flutter" }
$SkipVs = $env:FORJA_SKIP_VS -eq "1"

function Write-Step([string]$Msg) {
  Write-Host "==> $Msg" -ForegroundColor Cyan
}

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

function Test-ChocoInstalled([string]$Name) {
  $line = choco list --local-only --limit-output 2>$null | Where-Object { $_ -like "$Name|*" }
  return [bool]$line
}

function Ensure-ChocoPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Name,
    [string[]]$ExtraArgs = @()
  )
  if (Test-ChocoInstalled $Name) {
    Write-Host "choco: $Name already installed"
    return
  }
  Write-Step "choco install $Name"
  $chocoArgs = @("install", $Name, "-y", "--no-progress") + $ExtraArgs
  & choco @chocoArgs
  if ($LASTEXITCODE -ne 0) {
    throw "choco install $Name failed with exit code $LASTEXITCODE"
  }
}

function Add-UserPath([string]$Dir) {
  if (-not (Test-Path $Dir)) { return }
  $userPath = [Environment]::GetEnvironmentVariable("Path", "User")
  if ($userPath -split ";" | Where-Object { $_ -ieq $Dir }) { return }
  [Environment]::SetEnvironmentVariable("Path", ($userPath.TrimEnd(";") + ";" + $Dir), "User")
  $env:Path += ";$Dir"
}

function Refresh-EnvPath {
  $env:Path = [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" +
              [Environment]::GetEnvironmentVariable("Path", "User")
  if (Test-Path "C:\ProgramData\chocolatey\bin") {
    $env:Path = "C:\ProgramData\chocolatey\bin;" + $env:Path
  }
  if (Test-Path "C:\Program Files\Git\cmd") {
    $env:Path = "C:\Program Files\Git\cmd;C:\Program Files\Git\bin;" + $env:Path
  }
  if (Test-Path "$env:USERPROFILE\.cargo\bin") {
    $env:Path = "$env:USERPROFILE\.cargo\bin;" + $env:Path
  }
  if (Get-Command refreshenv -ErrorAction SilentlyContinue) {
    refreshenv | Out-Null
  }
}

function Get-GitExe {
  $candidates = @(
    (Get-Command git -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Source),
    "C:\Program Files\Git\cmd\git.exe",
    "C:\Program Files\Git\bin\git.exe"
  ) | Where-Object { $_ -and (Test-Path $_) }
  if (-not $candidates) {
    throw "git.exe not found. Close this shell, reopen as Admin, re-run the script."
  }
  return $candidates[0]
}

Assert-Admin
Ensure-Chocolatey
Refresh-EnvPath

Write-Step "Core packages (git, innosetup, rustup)"
Ensure-ChocoPackage -Name "git"
Ensure-ChocoPackage -Name "innosetup"
Ensure-ChocoPackage -Name "rustup.install"
Refresh-EnvPath

if (-not $SkipVs) {
  Write-Step "Visual Studio 2022 Build Tools (VC++ - long install)"
  try {
    Ensure-ChocoPackage -Name "visualstudio2022buildtools" -ExtraArgs @(
      "--package-parameters",
      "--add Microsoft.VisualStudio.Workload.VCTools --includeRecommended --passive --norestart"
    )
  } catch {
    Write-Warning "VS Build Tools via choco failed: $_"
    Write-Warning "Install Visual Studio 2022 Community manually with Desktop development with C++, then re-run with FORJA_SKIP_VS=1"
  }
} else {
  Write-Host "Skipping VS Build Tools (FORJA_SKIP_VS=1)"
}

Refresh-EnvPath

Write-Step "Flutter stable -> $FlutterRoot"
$git = Get-GitExe
if (-not (Test-Path "$FlutterRoot\bin\flutter.bat")) {
  New-Item -ItemType Directory -Force -Path (Split-Path $FlutterRoot) | Out-Null
  if (Test-Path $FlutterRoot) { Remove-Item -Recurse -Force $FlutterRoot }
  & $git clone https://github.com/flutter/flutter.git -b stable --depth 1 $FlutterRoot
} else {
  Write-Host "Flutter already at $FlutterRoot - running upgrade"
  & "$FlutterRoot\bin\flutter.bat" upgrade --force
}
Add-UserPath "$FlutterRoot\bin"
Add-UserPath "$env:USERPROFILE\.cargo\bin"
Refresh-EnvPath

Write-Step "flutter config + doctor"
& flutter config --enable-windows-desktop
& flutter doctor -v

$iscc = Join-Path ${env:ProgramFiles(x86)} "Inno Setup 6\ISCC.exe"
if (-not (Test-Path $iscc)) {
  Write-Warning "ISCC.exe not found at $iscc - Inno Setup may need a new shell / reboot"
} else {
  Write-Host "Inno Setup OK: $iscc"
}

if (Get-Command rustc -ErrorAction SilentlyContinue) {
  Write-Host "Rust OK: $(rustc --version)"
} else {
  Write-Warning "rustc not on PATH yet - open a new terminal or reboot after rustup"
}

Write-Host ""
Write-Host "Setup finished." -ForegroundColor Green
Write-Host "Next:"
Write-Host "  1. Open a NEW PowerShell / Git Bash (PATH refresh)"
Write-Host "  2. cd to the Forja repo (shared folder or C:\dev\Forja clone)"
Write-Host "  3. Ensure .env is present in the repo root"
Write-Host "  4. bash ./scripts/build_windows_release.sh <version>"
Write-Host "     e.g. bash ./scripts/build_windows_release.sh 1.2.403"
Write-Host ""
Write-Host "From the Mac (after setup), Parallels build:"
Write-Host '  FORJA_PRL_VM="Windows 11" ./scripts/release_local.sh build-windows v1.2.403'
