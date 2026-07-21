# Copy MSVC CRT DLLs next to forja.exe (app-local).
# Called from bundle_windows_msvc_crt.sh. Args: <ReleaseDir>
param(
  [Parameter(Mandatory = $true)]
  [string]$ReleaseDir
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path -LiteralPath $ReleaseDir -PathType Container)) {
  Write-Error "missing Windows release dir: $ReleaseDir"
}

$roots = @(
  ${env:ProgramFiles},
  ${env:ProgramFiles(x86)}
) | Where-Object { $_ -and (Test-Path $_) }

$candidates = @()
foreach ($root in $roots) {
  $vsRoot = Join-Path $root "Microsoft Visual Studio"
  if (-not (Test-Path $vsRoot)) { continue }
  $candidates += Get-ChildItem -Path $vsRoot -Recurse -Filter "msvcp140.dll" -ErrorAction SilentlyContinue |
    Where-Object { $_.DirectoryName -match '\\x64\\Microsoft\.VC\d+\.CRT$' }
}

if ($candidates.Count -eq 0) {
  Write-Error "No x64 Microsoft.VC*.CRT folder with msvcp140.dll under Visual Studio installs"
}

$crtDir = ($candidates | Sort-Object FullName -Descending | Select-Object -First 1).DirectoryName
Write-Host "Using CRT: $crtDir"
Copy-Item -Path (Join-Path $crtDir "*.dll") -Destination $ReleaseDir -Force

Get-ChildItem -Path $ReleaseDir -Filter "msvcp140*.dll" | ForEach-Object { Write-Host "bundled $($_.Name)" }
Get-ChildItem -Path $ReleaseDir -Filter "vcruntime140*.dll" | ForEach-Object { Write-Host "bundled $($_.Name)" }

foreach ($name in @("msvcp140.dll", "vcruntime140.dll")) {
  if (-not (Test-Path (Join-Path $ReleaseDir $name))) {
    Write-Error "$name missing in $ReleaseDir after copy"
  }
}
