$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python = 'C:\Program Files\Python312\python.exe'
$xvlog = 'C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab = 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim = 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
foreach ($tool in @($python,$xvlog,$xelab,$xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing tool: $tool" }
}
& $python (Join-Path $workspace 'model/cordic_reference.py') --vectors
if ($LASTEXITCODE -ne 0) { throw 'Vector generation failed.' }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog -prj scripts/phase4/cordic_files.prj 2>&1 |
            Tee-Object -FilePath reports/phase4_cordic_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 CORDIC xvlog failed.' }
        & $xelab xil_defaultlib.tb_cordic_phase4 -s phase4_cordic_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase4_cordic_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 CORDIC xelab failed.' }
        & $xsim phase4_cordic_snapshot -tclbatch scripts/phase4/cordic_run.tcl 2>&1 |
            Tee-Object -FilePath reports/phase4_cordic_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 CORDIC xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
$log = Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4_cordic_xsim.log')
if (-not ($log | Where-Object { $_ -match '^PHASE4_CORDIC_UNIT_TEST PASS ' })) {
    throw 'Unit test did not print PASS.'
}
