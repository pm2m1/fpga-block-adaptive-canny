param([ValidateSet(1,2,4)][int]$Engines=1)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
$tag="e${Engines}"
if (Test-Path -LiteralPath (Join-Path $workspace "vivado/phase10_${tag}")) {
    throw "Refusing to overwrite existing Vivado project phase10_${tag}"
}
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $vivado -mode batch -source scripts/phase10/create_a100t_project.tcl -tclargs $Engines 2>&1 |
            Tee-Object -FilePath "reports/phase10/${tag}_vivado.log"
        if ($LASTEXITCODE -ne 0) { throw "Vivado Phase10 ${tag} failed" }
        if (-not (Select-String -Path "reports/phase10/${tag}_vivado.log" -Pattern "PHASE10_DONE=${tag}" -Quiet)) {
            throw "Vivado Phase10 ${tag} completion marker absent"
        }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
