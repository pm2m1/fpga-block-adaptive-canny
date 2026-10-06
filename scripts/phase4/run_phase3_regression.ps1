$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        # These are the untouched Phase-3 source list, testbench, and run Tcl.
        & $xvlog -prj scripts/phase3_files.prj 2>&1 |
            Tee-Object -FilePath reports/phase4_phase3_regression_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 regression xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase3_equivalence -s phase4_phase3_regression_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase4_phase3_regression_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 regression xelab failed.' }
        & $xsim phase4_phase3_regression_snapshot -tclbatch scripts/phase3_run.tcl 2>&1 |
            Tee-Object -FilePath reports/phase4_phase3_regression_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 regression xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
$frames=@(Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4_phase3_regression_xsim.log') |
          Where-Object {$_ -match '^PHASE3_FRAME index='})
if ($frames.Count -lt 1) { throw 'No completed Phase-3 regression frame.' }
foreach ($frame in $frames) {
    if ($frame -notmatch 'pixels_compared=307200 pixels_matching=307200 pixels_mismatching=0 unknown_pixels=0') {
        throw "Phase-3 regression mismatch: $frame"
    }
}
Write-Output "PHASE3_REGRESSION_PASS frames=$($frames.Count)"
