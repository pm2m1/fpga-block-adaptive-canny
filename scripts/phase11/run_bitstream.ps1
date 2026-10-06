param([string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado=& "$PSScriptRoot/resolve_vivado.ps1" -Tool vivado -VivadoBin $VivadoBin
if (Test-Path -LiteralPath (Join-Path $workspace 'results/phase11/canny_nexys_a7.bit')) {
    throw 'Refusing to overwrite existing bitstream'
}
if (Test-Path -LiteralPath 'W:\') {throw 'Temporary W: drive occupied'}
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) {throw 'subst failed'}
try {
  Push-Location 'W:\'
  try {
    & $vivado -mode batch -source scripts/phase11/write_bitstream.tcl 2>&1 |
      Tee-Object -FilePath reports/phase11/phase11_bitstream.log
    if ($LASTEXITCODE -ne 0) {throw 'Bitstream gate/generation failed'}
    if (-not (Select-String -Path reports/phase11/phase11_bitstream.log -Pattern 'PHASE11_BITSTREAM_READY' -Quiet)) {
      throw 'Bitstream completion marker absent'
    }
  } finally {Pop-Location}
} finally {& subst.exe W: /D | Out-Null}
