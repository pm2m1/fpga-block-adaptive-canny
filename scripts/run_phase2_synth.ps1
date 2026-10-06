$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Missing Vivado: $vivado" }
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'rtl/baseline/canny_edge_detect_top.v'))) {
    throw 'This script must live in the protected Canny_BlockAdaptive_A100T workspace.'
}
$drive = 'W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is already occupied; no mapping changed." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary workspace drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        if (Test-Path -LiteralPath 'vivado/phase2_a100t_baseline') {
            throw 'Phase-2 project directory already exists; refusing to overwrite it.'
        }
        & $vivado -mode batch -source scripts/create_phase2_a100t_project.tcl -nojournal -nolog 2>&1 |
            Tee-Object -FilePath reports/phase2_synth.log
        $code = $LASTEXITCODE
        if ($code -ne 0) { throw "Vivado batch failed with exit code $code; inspect reports/phase2_synth.log" }
    } finally {
        Pop-Location
    }
} finally {
    & subst.exe $drive /D | Out-Null
}
