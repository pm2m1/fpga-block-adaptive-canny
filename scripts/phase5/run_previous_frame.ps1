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
        New-Item -ItemType Directory -Path results/phase4b -Force | Out-Null
        & $xvlog -prj scripts/phase4b/frame_files.prj 2>&1 |
            Tee-Object -FilePath reports/phase5_prev_frame_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 frame xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase4b_equivalence -s phase5_prev_frame_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase5_prev_frame_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 frame xelab failed.' }
        & $xsim phase5_prev_frame_snapshot -tclbatch scripts/phase4b/frame_run.tcl 2>&1 |
            Tee-Object -FilePath reports/phase5_prev_frame_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 frame xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
$frames=@(Get-Content -LiteralPath (Join-Path $workspace 'reports/phase5_prev_frame_xsim.log') |
          Where-Object {$_ -match '^PHASE4B_FRAME index='})
if ($frames.Count -ne 2) { throw 'No completed Phase-4 frame.' }
foreach ($frame in $frames) {
    if ($frame -notmatch 'valid_pixels=307200 edge_pixels=[1-9]') {
        throw "Phase-4 frame failed validation: $frame"
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'results/phase4b/outcom_phase4b.bmp'))) {
    throw 'Phase-4 output BMP missing.'
}
Write-Output "PHASE4B_FRAME_SMOKE_PASS frames=$($frames.Count)"

if (-not (Get-Content (Join-Path $workspace 'reports/phase5_prev_frame_xsim.log') | Where-Object { $_ -match '^PHASE4B_EQUIVALENCE PASS frames=2 pixels_compared=614400 mismatches=0 unknowns=0 latency_delta=2' })) { throw 'Two-frame equivalence did not PASS.' }
