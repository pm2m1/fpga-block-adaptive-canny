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
        if (Test-Path -LiteralPath 'vivado/phase6_a100t') {
            throw 'Phase-6 project exists; refusing overwrite.'
        }
        & $vivado -mode batch -source scripts/phase6/create_a100t_project.tcl -nojournal -nolog 2>&1 |
            Tee-Object -FilePath reports/phase6_synth_impl.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-6 synthesis or implementation failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
