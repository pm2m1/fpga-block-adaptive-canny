$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$xvlog = 'C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab = 'C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim = 'C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
foreach ($tool in @($xvlog, $xelab, $xsim)) {
    if (-not (Test-Path -LiteralPath $tool)) { throw "Missing tool: $tool" }
}
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'rtl/phase3/canny_edge_detect_gaussian_top.v'))) {
    throw 'Phase-3 wrapper missing from protected workspace.'
}
$drive = 'W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is already occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary workspace drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        New-Item -ItemType Directory -Path results/phase3 -Force | Out-Null
        & $xvlog -prj scripts/phase3_files.prj 2>&1 |
            Tee-Object -FilePath reports/phase3_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase3_equivalence -s phase3_equivalence_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase3_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 xelab failed.' }
        & $xsim phase3_equivalence_snapshot -tclbatch scripts/phase3_run.tcl 2>&1 |
            Tee-Object -FilePath reports/phase3_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }

$log = Get-Content -LiteralPath (Join-Path $workspace 'reports/phase3_xsim.log')
$frames = @($log | Where-Object { $_ -match '^PHASE3_FRAME index=' })
if ($frames.Count -lt 1) { throw 'No completed Phase-3 frame was observed.' }
foreach ($frame in $frames) {
    if ($frame -notmatch 'pixels_compared=307200 pixels_matching=307200 pixels_mismatching=0 unknown_pixels=0') {
        throw "Phase-3 frame did not pass equivalence: $frame"
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'results/phase3/outcom.bmp'))) {
    throw 'Phase-3 output BMP was not generated.'
}
Write-Output "PHASE3_EQUIVALENCE_PASS frames=$($frames.Count) pixels=$($frames.Count * 307200)"
