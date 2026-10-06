param([string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado=& "$PSScriptRoot/resolve_vivado.ps1" -Tool vivado -VivadoBin $VivadoBin
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'results/phase11/canny_nexys_a7.bit'))) {
    throw 'Bitstream missing'
}
if (Test-Path -LiteralPath 'W:\') {throw 'Temporary W: drive occupied'}
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) {throw 'subst failed'}
try {
  Push-Location 'W:\'
  try {
    & $vivado -mode batch -source scripts/phase11/program_hardware.tcl 2>&1 |
      Tee-Object -FilePath reports/phase11/phase11_program_hardware.log
    if ($LASTEXITCODE -ne 0) {throw 'Board programming failed'}
    if (-not (Select-String -Path reports/phase11/phase11_program_hardware.log -Pattern 'PHASE11_PROGRAMMED_DEVICE=' -Quiet)) {
      throw 'Programming completion marker absent'
    }
  } finally {Pop-Location}
} finally {& subst.exe W: /D | Out-Null}
