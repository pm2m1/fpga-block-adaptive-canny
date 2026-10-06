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
        New-Item -ItemType Directory -Path results/phase4 -Force | Out-Null
        & $xvlog -prj scripts/phase4/frame_files.prj 2>&1 |
            Tee-Object -FilePath reports/phase4_frame_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 frame xvlog failed.' }
        & $xelab xil_defaultlib.tb_phase4_frame -s phase4_frame_snapshot -debug typical 2>&1 |
            Tee-Object -FilePath reports/phase4_frame_xelab.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 frame xelab failed.' }
        & $xsim phase4_frame_snapshot -tclbatch scripts/phase4/frame_run.tcl 2>&1 |
            Tee-Object -FilePath reports/phase4_frame_xsim.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 frame xsim failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
$frames=@(Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4_frame_xsim.log') |
          Where-Object {$_ -match '^PHASE4_FRAME index='})
if ($frames.Count -lt 1) { throw 'No completed Phase-4 frame.' }
foreach ($frame in $frames) {
    if ($frame -notmatch 'valid_pixels=307200 unknown_pixels=0 edge_pixels=[1-9]') {
        throw "Phase-4 frame failed validation: $frame"
    }
}
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'results/phase4/outcom_phase4.bmp'))) {
    throw 'Phase-4 output BMP missing.'
}
Write-Output "PHASE4_FRAME_SMOKE_PASS frames=$($frames.Count)"
