$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $xvlog -prj scripts/phase9/phase9.prj 2>&1 | Tee-Object -FilePath reports/phase9/phase8_equiv_core_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase9 core XVLOG failed' }
        & $xvlog -prj scripts/phase9/phase8_equiv.prj 2>&1 | Tee-Object -FilePath reports/phase9/phase8_equiv_tb_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Equiv TB XVLOG failed' }
        & $xelab xil_defaultlib.tb_phase9_phase8_equiv -s phase9_phase8_equiv_snapshot -debug typical 2>&1 | Tee-Object -FilePath reports/phase9/phase8_equiv_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Equiv XELAB failed' }
        & $xsim phase9_phase8_equiv_snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath reports/phase9/phase8_equiv_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Equiv XSIM failed' }
        if (-not (Select-String -Path reports/phase9/phase8_equiv_xsim.log -Pattern '^PHASE9_PHASE8_EQUIV_PASS ' -Quiet)) {
            throw 'Equiv pass marker missing'
        }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
