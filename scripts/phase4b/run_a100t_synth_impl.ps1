$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Missing Vivado: $vivado" }
$unit=Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4b_cordic_xsim.log')
if (-not ($unit | Where-Object {$_ -match '^PHASE4B_CORDIC_UNIT_TEST PASS vectors_tested=16144 mismatches=0 unknown_outputs=0'})) { throw 'Phase-4B CORDIC unit gate not passed.' }
$frame=Get-Content -LiteralPath (Join-Path $workspace 'reports/phase4b_frame_xsim.log')
if (-not ($frame | Where-Object {$_ -match '^PHASE4B_EQUIVALENCE PASS frames=2 pixels_compared=614400 mismatches=0 unknowns=0 latency_delta=2'})) { throw 'Phase-4B equivalence gate not passed.' }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        if (Test-Path -LiteralPath 'vivado/phase4b_a100t_timing_run1') {
            throw 'Phase-4B project exists; refusing overwrite.'
        }
        & $vivado -mode batch -source scripts/phase4b/create_a100t_project.tcl -nojournal -nolog 2>&1 |
            Tee-Object -FilePath reports/phase4b_synth_impl.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4B synthesis or implementation failed; inspect reports.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
