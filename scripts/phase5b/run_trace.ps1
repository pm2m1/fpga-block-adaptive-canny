param([ValidateSet('small','full','isolate_ab','isolate_cd','leakage')][string]$Suite='small')
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
    & $python model/phase5b/regression.py --prepare $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Input generation failed.' }
} finally { Pop-Location }
$defines=switch ($Suite) {
    'full' {@('-d','PHASE5B_FULL')}
    'isolate_ab' {@('-d','PHASE5B_ISOLATE_AB')}
    'isolate_cd' {@('-d','PHASE5B_ISOLATE_CD')}
    'leakage' {@('-d','PHASE5B_LEAKAGE')}
    default {@()}
}
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog @defines -prj scripts/phase5b/files.prj 2>&1 | Tee-Object -FilePath "reports/phase5b_${Suite}_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 5 xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase5b_trace -s phase5b_trace_snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase5b_${Suite}_xelab.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 5 xelab failed.' }
        & $xsim phase5b_trace_snapshot -tclbatch scripts/phase5b/run_trace.tcl 2>&1 | Tee-Object -FilePath "reports/phase5b_${Suite}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 5 xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
Push-Location $workspace
try {
    & $python model/phase5b/regression.py --compare $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Phase 5 model/RTL comparison failed.' }
} finally { Pop-Location }
