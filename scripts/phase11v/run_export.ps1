param([string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool vivado -VivadoBin $VivadoBin
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
  Push-Location 'W:\'
  try {
    New-Item -ItemType Directory -Force -Path reports/phase11v,results/phase11v | Out-Null
    & $vivado -mode batch -source scripts/phase11v/export_and_audit.tcl -log reports/phase11v/export_vivado.log -journal reports/phase11v/export_vivado.jou 2>&1 | Tee-Object -FilePath reports/phase11v/export_console.log
    if ($LASTEXITCODE -ne 0) { throw 'Vivado export/audit failed' }
  } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
