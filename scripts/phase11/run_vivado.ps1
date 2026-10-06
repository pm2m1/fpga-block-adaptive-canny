param([string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado=& "$PSScriptRoot/resolve_vivado.ps1" -Tool vivado -VivadoBin $VivadoBin
if (Test-Path -LiteralPath (Join-Path $workspace 'vivado/phase11_board_rev3')) {
    throw 'Refusing to overwrite existing Phase 11 Vivado project'
}
if (Test-Path -LiteralPath 'W:\') {throw 'Temporary W: drive is occupied'}
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) {throw 'subst failed'}
try {
  Push-Location 'W:\'
  try {
    New-Item -ItemType Directory -Force -Path reports/phase11 | Out-Null
    & $vivado -mode batch -source scripts/phase11/create_and_route.tcl 2>&1 |
      Tee-Object -FilePath reports/phase11/phase11_rev3_vivado.log
    if ($LASTEXITCODE -ne 0) {throw 'Vivado failed'}
    if (-not (Select-String -Path reports/phase11/phase11_rev3_vivado.log -Pattern 'PHASE11_ROUTE_DONE' -Quiet)) {
      throw 'Route completion marker absent'
    }
  } finally {Pop-Location}
} finally {& subst.exe W: /D | Out-Null}
