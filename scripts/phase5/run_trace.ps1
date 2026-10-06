param([ValidateSet('small','full')][string]$Suite='small')
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
    & $python model/run_phase5_regression.py --prepare $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Input generation failed.' }
} finally { Pop-Location }
$defines=if ($Suite -eq 'full') {@('-d','PHASE5_FULL')} else {@()}
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog @defines -prj scripts/phase5/files.prj 2>&1 | Tee-Object -FilePath "reports/phase5_${Suite}_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 5 xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase5_trace -s phase5_trace_snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase5_${Suite}_xelab.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 5 xelab failed.' }
        & $xsim phase5_trace_snapshot -tclbatch scripts/phase5/run_trace.tcl 2>&1 | Tee-Object -FilePath "reports/phase5_${Suite}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 5 xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
Push-Location $workspace
try {
    & $python model/run_phase5_regression.py --compare $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Phase 5 model/RTL comparison failed.' }
} finally { Pop-Location }
