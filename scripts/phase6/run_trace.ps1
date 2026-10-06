param([ValidateSet('fixed','atomic','multi','trend','isolate')][string]$Suite='fixed')
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python='C:\Program Files\Python312\python.exe'
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
foreach ($tool in @($python,$xvlog,$xelab,$xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing tool: $tool" }
}
Push-Location $workspace
try {
    & $python model/phase6/regression.py --prepare $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Input generation failed.' }
} finally { Pop-Location }
$defines=switch ($Suite) {
    'fixed' {@('-d','PHASE6_FIXED')}
    'atomic' {@('-d','PHASE6_ATOMIC')}
    'multi' {@('-d','PHASE6_MULTI')}
    'trend' {@('-d','PHASE6_TREND')}
    'isolate' {@('-d','PHASE6_ISOLATE')}
}
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog @defines -prj scripts/phase6/files.prj 2>&1 | Tee-Object -FilePath "reports/phase6_${Suite}_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 6 xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase6_trace -s phase6_trace_snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase6_${Suite}_xelab.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 6 xelab failed.' }
        & $xsim phase6_trace_snapshot -tclbatch scripts/phase6/run_trace.tcl 2>&1 | Tee-Object -FilePath "reports/phase6_${Suite}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 6 xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
Push-Location $workspace
try {
    & $python model/phase6/regression.py --compare $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Phase 6 model/RTL comparison failed.' }
} finally { Pop-Location }
