$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $xvlog -prj scripts/phase9/phase9.prj 2>&1 | Tee-Object -FilePath reports/phase9/compile_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase9 XVLOG failed' }
        & $xelab xil_defaultlib.canny_block_adaptive_phase9_top -s phase9_compile_snapshot -debug typical 2>&1 | Tee-Object -FilePath reports/phase9/compile_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase9 XELAB failed' }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
