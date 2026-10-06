$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python='C:\Program Files\Python312\python.exe'
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
Push-Location $workspace
try {
    & $python -m model.phase6.boundary_vectors 2>&1 | Tee-Object -FilePath reports/phase6_boundary_python.log
    if ($LASTEXITCODE -ne 0) { throw 'Boundary vector generation failed.' }
} finally { Pop-Location }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog -prj scripts/phase6/boundary_files.prj 2>&1 | Tee-Object -FilePath reports/phase6_boundary_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Boundary xvlog failed.' }
        & $xelab xil_defaultlib.tb_threshold_phase6 -s phase6_boundary_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase6_boundary_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Boundary xelab failed.' }
        & $xsim phase6_boundary_snapshot -tclbatch scripts/phase6/run_trace.tcl 2>&1 |
            Tee-Object -FilePath reports/phase6_boundary_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Boundary xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
