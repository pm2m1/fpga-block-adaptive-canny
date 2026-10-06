$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Missing Vivado: $vivado" }
$unit=Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4_cordic_xsim.log')
if (-not ($unit | Where-Object {$_ -match '^PHASE4_CORDIC_UNIT_TEST PASS '})) { throw 'CORDIC unit gate not passed.' }
$frame=@(Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4_frame_xsim.log') |
         Where-Object {$_ -match '^PHASE4_FRAME index=.*valid_pixels=307200 unknown_pixels=0 edge_pixels=[1-9]'})
if ($frame.Count -lt 1) { throw 'Frame smoke gate not passed.' }
$regression=@(Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4_phase3_regression_xsim.log') |
              Where-Object {$_ -match '^PHASE3_FRAME index=.*pixels_compared=307200 pixels_matching=307200 pixels_mismatching=0 unknown_pixels=0'})
if ($regression.Count -lt 1) { throw 'Phase-3 regression gate not passed.' }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        if (Test-Path -LiteralPath 'vivado/phase4_a100t_cordic_fixed') {
            throw 'Phase-4 project exists; refusing overwrite.'
        }
        & $vivado -mode batch -source scripts/phase4/create_a100t_project.tcl -nojournal -nolog 2>&1 |
            Tee-Object -FilePath reports/phase4_synth.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 synthesis failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
