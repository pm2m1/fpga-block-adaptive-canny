$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$xvlog = 'C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab = 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim = 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'

foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing tool: $tool" }
}
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'rtl/baseline/canny_edge_detect_top.v'))) {
    throw 'This script must live in the protected Canny_BlockAdaptive_A100T workspace.'
}

# AMD's 2026.1 batch setup expands the current directory inside CMD parentheses.
# The original directory contains "(2nd sem)", so map only this workspace for
# this process. Never alter the machine PATH or the original project tree.
$drive = 'W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is already occupied; no mapping changed." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary workspace drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        New-Item -ItemType Directory -Path 'reports', 'results/phase1' -Force | Out-Null
        & $xvlog -prj scripts/phase1_files.prj 2>&1 | Tee-Object -FilePath reports/phase1_xvlog.log
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "xvlog failed with exit code $code; see reports/phase1_xvlog.log" }

        & $xelab xil_defaultlib.canny_tb -s canny_tb_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase1_xelab.log
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "xelab failed with exit code $code; see reports/phase1_xelab.log" }

        & $xsim canny_tb_snapshot -tclbatch scripts/phase1_run.tcl 2>&1 |
            Tee-Object -FilePath reports/phase1_xsim.log
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "xsim failed with exit code $code; see reports/phase1_xsim.log" }
    } finally {
        Pop-Location
    }
} finally {
    & subst.exe $drive /D | Out-Null
}
