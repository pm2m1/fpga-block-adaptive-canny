$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python='C:\Program Files\Python312\python.exe'
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
Push-Location $workspace
try {
    & $python scripts/phase8/generate_unit_vectors.py
    if ($LASTEXITCODE -ne 0) { throw 'Vector generation failed.' }
} finally { Pop-Location }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog -prj scripts/phase8/units.prj 2>&1 | Tee-Object -FilePath reports/phase8_units_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'XVLOG failed.' }
        foreach ($top in @('tb_phase8_histogram','tb_phase8_threshold')) {
            $snap="${top}_snapshot"
            & $xelab "xil_defaultlib.$top" -s $snap 2>&1 | Tee-Object -FilePath "reports/phase8_${top}_xelab.log"
            if ($LASTEXITCODE -ne 0) { throw "XELAB failed: $top" }
            & $xsim $snap -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath "reports/phase8_${top}_xsim.log"
            if ($LASTEXITCODE -ne 0) { throw "XSIM failed: $top" }
        }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
