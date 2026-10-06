param([ValidateSet(1,2,4)][int]$Engines=1,[ValidateSet('two','isolate')][string]$Suite='two',
      [switch]$DelayedFirst)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
$tag="e${Engines}_${Suite}" + $(if ($DelayedFirst) {'_delayed'} else {''})
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $xvlog -prj scripts/phase10/phase10.prj 2>&1 | Tee-Object -FilePath "reports/phase10/${tag}_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'RTL compile failed' }
        $defines=@()
        if ($Engines -eq 2) { $defines+=@('-d','PHASE10_E2') }
        if ($Engines -eq 4) { $defines+=@('-d','PHASE10_E4') }
        if ($Suite -eq 'isolate') { $defines+=@('-d','PHASE10_ISOLATE') }
        if ($DelayedFirst) { $defines+=@('-d','PHASE10_DELAY_FIRST') }
        & $xvlog @defines -prj scripts/phase10/phase10_tb.prj 2>&1 | Tee-Object -FilePath "reports/phase10/${tag}_tb_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'TB compile failed' }
        $snapshot="phase10_${tag}_snapshot"
        & $xelab xil_defaultlib.tb_phase10 -s $snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase10/${tag}_xelab.log"
        if ($LASTEXITCODE -ne 0) { throw 'Elaboration failed' }
        & $xsim $snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath "reports/phase10/${tag}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'Simulation failed' }
        if (-not (Select-String -Path "reports/phase10/${tag}_xsim.log" -Pattern '^PHASE10_RTL_PASS ' -Quiet)) {
            throw 'Pass marker absent; inspect XSim log'
        }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
