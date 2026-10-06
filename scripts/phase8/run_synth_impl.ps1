param([ValidatePattern('^run[0-9]+$')][string]$RunTag='run1')
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Missing Vivado: $vivado" }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        if (Test-Path -LiteralPath "vivado/phase8_a100t_$RunTag") {
            throw "Phase 8 $RunTag project exists; refusing overwrite."
        }
        & $vivado -mode batch -source scripts/phase8/create_a100t_project.tcl -nojournal -nolog -tclargs $RunTag 2>&1 |
            Tee-Object -FilePath "reports/phase8_${RunTag}_synth_impl.log"
        if ($LASTEXITCODE -ne 0) { throw 'Phase 8 synthesis/implementation failed.' }
        if (-not (Select-String -Path "reports/phase8_${RunTag}_synth_impl.log" -Pattern '^PHASE8_DONE=PASS$' -Quiet)) {
            throw 'Vivado did not report PHASE8_DONE=PASS.'
        }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
