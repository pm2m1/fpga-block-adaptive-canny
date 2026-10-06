$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python='C:\Program Files\Python312\python.exe'
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
Push-Location $workspace
try {
    & $python scripts/phase8/prepare_fixed_oracle.py
    if ($LASTEXITCODE -ne 0) { throw 'Oracle preparation failed.' }
} finally { Pop-Location }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog -prj scripts/phase8/buffered_fixed.prj 2>&1 | Tee-Object -FilePath reports/phase8_buffered_fixed_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'XVLOG failed.' }
        & $xelab xil_defaultlib.tb_phase8_fixed_buffered -s phase8_buffered_fixed_snapshot -debug typical 2>&1 | Tee-Object -FilePath reports/phase8_buffered_fixed_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'XELAB failed.' }
        & $xsim phase8_buffered_fixed_snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath reports/phase8_buffered_fixed_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'XSIM failed.' }
        if (-not (Select-String -Path reports/phase8_buffered_fixed_xsim.log -Pattern '^PHASE8_BUFFERED_FIXED_PASS ' -Quiet)) {
            throw 'XSIM did not report PHASE8_BUFFERED_FIXED_PASS; inspect its log.'
        }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
