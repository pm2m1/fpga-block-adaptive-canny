param([ValidateSet('monkey','black','white','vertical','horizontal','checkerboard')][string]$Test='monkey',
      [switch]$CaptureUart,[switch]$Saif,[string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog=& "$PSScriptRoot/resolve_vivado.ps1" -Tool xvlog -VivadoBin $VivadoBin
$xelab=& "$PSScriptRoot/resolve_vivado.ps1" -Tool xelab -VivadoBin $VivadoBin
$xsim=& "$PSScriptRoot/resolve_vivado.ps1" -Tool xsim -VivadoBin $VivadoBin
$drive=if (Test-Path -LiteralPath 'W:\') {'V:'} else {'W:'}
if (Test-Path -LiteralPath "$drive\") { throw "Temporary $drive drive is occupied" }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location "$drive\"
    try {
        New-Item -ItemType Directory -Force -Path reports/phase11 | Out-Null
        & $xvlog -prj scripts/phase11/phase11.prj 2>&1 | Tee-Object -FilePath reports/phase11/wrapper_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'compile failed' }
        $define="PHASE11_$($Test.ToUpperInvariant())"
        $defines=@('-d',$define)
        if ($CaptureUart) { $defines+=@('-d','PHASE11_CAPTURE_UART') }
        & $xvlog @defines -prj scripts/phase11/phase11_tb.prj 2>&1 | Tee-Object -FilePath reports/phase11/wrapper_tb_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'testbench compile failed' }
        & $xelab xil_defaultlib.tb_board_wrapper -s phase11_wrapper_snapshot -debug typical 2>&1 | Tee-Object -FilePath reports/phase11/wrapper_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'elaboration failed' }
        $simTcl=if ($Saif) {'scripts/phase11/wrapper_saif.tcl'} else {'scripts/phase11/wrapper_sim.tcl'}
        & $xsim phase11_wrapper_snapshot -tclbatch $simTcl 2>&1 | Tee-Object -FilePath "reports/phase11/wrapper_${Test}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'simulation failed' }
        if (-not (Select-String -Path "reports/phase11/wrapper_${Test}_xsim.log" -Pattern 'PHASE11_WRAPPER_PASS' -Quiet)) { throw 'PASS marker absent' }
        if ($CaptureUart -and -not (Select-String -Path "reports/phase11/wrapper_${Test}_xsim.log" -Pattern 'PHASE11_UART_PACKET_PASS' -Quiet)) {throw 'UART packet marker absent'}
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
