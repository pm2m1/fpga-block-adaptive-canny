param([ValidateSet('adaptive','isolate','patterns','mixed')][string]$Suite='adaptive')
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python='C:\Program Files\Python312\python.exe'
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
Push-Location $workspace
try {
    if ($Suite -eq 'adaptive') {
        & $python scripts/phase8/prepare_adaptive_oracle.py
    } elseif ($Suite -eq 'mixed') {
        & $python scripts/phase8/prepare_mixed_oracle.py
    } else {
        & $python scripts/phase8/prepare_suite.py --suite $Suite
    }
    if ($LASTEXITCODE -ne 0) { throw 'Adaptive oracle failed.' }
} finally { Pop-Location }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        $defines=switch ($Suite) {
            'isolate' {@('-d','PHASE8_ISOLATE')}
            'patterns' {@('-d','PHASE8_PATTERNS')}
            'mixed' {@('-d','PHASE8_MIXED')}
            default {@()}
        }
        & $xvlog @defines -prj scripts/phase8/adaptive.prj 2>&1 | Tee-Object -FilePath "reports/phase8_${Suite}_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'XVLOG failed.' }
        & $xelab xil_defaultlib.tb_phase8_adaptive -s phase8_adaptive_snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase8_${Suite}_xelab.log"
        if ($LASTEXITCODE -ne 0) { throw 'XELAB failed.' }
        & $xsim phase8_adaptive_snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath "reports/phase8_${Suite}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'XSIM failed.' }
        if (-not (Select-String -Path "reports/phase8_${Suite}_xsim.log" -Pattern '^PHASE8_ADAPTIVE_PASS ' -Quiet)) {
            throw 'XSIM did not report PHASE8_ADAPTIVE_PASS; inspect its log.'
        }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
