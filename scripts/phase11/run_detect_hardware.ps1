param([string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado=& "$PSScriptRoot/resolve_vivado.ps1" -Tool vivado -VivadoBin $VivadoBin
if (Test-Path -LiteralPath 'W:\') {throw 'Temporary W: drive occupied'}
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) {throw 'subst failed'}
try {
  Push-Location 'W:\'
  try {
    & $vivado -mode batch -source scripts/phase11/detect_hardware.tcl 2>&1 |
      Tee-Object -FilePath reports/phase11/phase11_hardware_detection.log
    if ($LASTEXITCODE -ne 0) {throw 'Hardware discovery command failed'}
  } finally {Pop-Location}
} finally {& subst.exe W: /D | Out-Null}
