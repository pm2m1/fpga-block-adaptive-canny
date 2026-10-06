$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
foreach ($tool in @($xvlog,$xelab,$xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing tool: $tool" }
}
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $xvlog -prj scripts/phase8/fixed_commute.prj 2>&1 | Tee-Object -FilePath 'reports/phase8_fixed_commute_xvlog.log'
        if ($LASTEXITCODE -ne 0) { throw 'Phase 8 XVLOG failed.' }
        & $xelab xil_defaultlib.tb_phase8_fixed_commute -s phase8_fixed_commute_snapshot -debug typical 2>&1 | Tee-Object -FilePath 'reports/phase8_fixed_commute_xelab.log'
        if ($LASTEXITCODE -ne 0) { throw 'Phase 8 XELAB failed.' }
        & $xsim phase8_fixed_commute_snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath 'reports/phase8_fixed_commute_xsim.log'
        if ($LASTEXITCODE -ne 0) { throw 'Phase 8 XSIM failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
