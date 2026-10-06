param([switch]$CaptureUart,[string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool xvlog -VivadoBin $VivadoBin
$xelab=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool xelab -VivadoBin $VivadoBin
$xsim=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool xsim -VivadoBin $VivadoBin
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
  Push-Location 'W:\'
  try {
    & $xvlog -prj scripts/phase11v/phase11v_core.prj 2>&1 | Tee-Object -FilePath reports/phase11v/cycle_xvlog.log
    if ($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
    $tbArgs=@('-work','xil_defaultlib','-sv')
    if ($CaptureUart) { $tbArgs+=@('-d','PHASE11_CAPTURE_UART') }
    $tbArgs+=@('tb/phase11v/tb_board_wrapper_phase11v.sv','tb/phase11v/tb_cycle_counter.sv')
    & $xvlog @tbArgs 2>&1 | Tee-Object -FilePath reports/phase11v/cycle_tb_xvlog.log
    if ($LASTEXITCODE -ne 0) { throw 'TB compile failed' }
    & $xelab xil_defaultlib.tb_cycle_counter -s phase11v_cycle_snapshot 2>&1 | Tee-Object -FilePath reports/phase11v/cycle_xelab.log
    if ($LASTEXITCODE -ne 0) { throw 'elaboration failed' }
    & $xsim phase11v_cycle_snapshot -tclbatch scripts/phase11/wrapper_sim.tcl 2>&1 | Tee-Object -FilePath reports/phase11v/cycle_xsim.log
    if ($LASTEXITCODE -ne 0) { throw 'simulation failed' }
    if (-not (Select-String -Path reports/phase11v/cycle_xsim.log -Pattern 'PHASE11V_CYCLE_COUNTER_PASS' -Quiet)) {throw 'counter PASS marker absent'}
    if ($CaptureUart -and -not (Select-String -Path reports/phase11v/cycle_xsim.log -Pattern 'PHASE11_UART_PACKET_PASS' -Quiet)) {throw 'UART PASS marker absent'}
  } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
