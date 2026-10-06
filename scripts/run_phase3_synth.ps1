$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$vivado = 'C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Missing Vivado: $vivado" }
if (-not (Test-Path -LiteralPath (Join-Path $workspace 'rtl/phase3/canny_edge_detect_gaussian_top.v'))) {
    throw 'Phase-3 wrapper missing from protected workspace.'
}
$equivalence = Get-Content -LiteralPath (Join-Path $workspace 'reports/phase3_xsim.log')
if (@($equivalence | Where-Object { $_ -match '^PHASE3_FRAME index=.*pixels_compared=307200 pixels_matching=307200 pixels_mismatching=0 unknown_pixels=0' }).Count -lt 1) {
    throw 'Phase-3 equivalence gate has not passed.'
}
$drive = 'W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is already occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary workspace drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        if (Test-Path -LiteralPath 'vivado/phase3_a100t_gaussian') {
            throw 'Phase-3 project already exists; refusing to overwrite it.'
        }
        & $vivado -mode batch -source scripts/create_phase3_a100t_project.tcl -nojournal -nolog 2>&1 |
            Tee-Object -FilePath reports/phase3_synth.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-3 Vivado batch synthesis failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
