param([string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog=& "$PSScriptRoot/resolve_vivado.ps1" -Tool xvlog -VivadoBin $VivadoBin
$xelab=& "$PSScriptRoot/resolve_vivado.ps1" -Tool xelab -VivadoBin $VivadoBin
$xsim=& "$PSScriptRoot/resolve_vivado.ps1" -Tool xsim -VivadoBin $VivadoBin
$drive=if (Test-Path -LiteralPath 'W:\') {'V:'} else {'W:'}
if (Test-Path -LiteralPath "$drive\") {throw "Temporary $drive is occupied"}
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) {throw 'subst failed'}
try {
  Push-Location "$drive\"
  try {
    & $xvlog -prj scripts/phase11/phase11.prj 2>&1 | Tee-Object -FilePath reports/phase11/core_xvlog.log
    if ($LASTEXITCODE -ne 0) {throw 'Core compile failed'}
    & $xvlog -prj scripts/phase11/phase11_core_regression.prj 2>&1 | Tee-Object -FilePath reports/phase11/core_tb_xvlog.log
    if ($LASTEXITCODE -ne 0) {throw 'Core TB compile failed'}
    & $xelab xil_defaultlib.tb_phase10 -s phase11_core_regression -debug typical 2>&1 | Tee-Object -FilePath reports/phase11/core_xelab.log
    if ($LASTEXITCODE -ne 0) {throw 'Core elaboration failed'}
    & $xsim phase11_core_regression -tclbatch scripts/phase11/wrapper_sim.tcl 2>&1 | Tee-Object -FilePath reports/phase11/core_xsim.log
    if ($LASTEXITCODE -ne 0) {throw 'Core simulation failed'}
    if (-not (Select-String -Path reports/phase11/core_xsim.log -Pattern 'PHASE10_RTL_PASS engines=1 suite=two frames=2 pixels=614400' -Quiet)) {
      throw 'Two-frame model regression PASS marker absent'
    }
  } finally {Pop-Location}
} finally {& subst.exe $drive /D | Out-Null}
