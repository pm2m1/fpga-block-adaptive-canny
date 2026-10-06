param(
    [ValidateSet(32,64)][int]$Block,
    [ValidateSet(8,16,32)][int]$Bins,
    [switch]$Route
)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
$tag="b${Block}_h${Bins}"
if (Test-Path -LiteralPath (Join-Path $workspace "vivado/phase9_${tag}")) {
    throw "Phase9 project $tag exists; refusing overwrite"
}
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $vivado -mode batch -source scripts/phase9/create_a100t_project.tcl -nojournal -nolog -tclargs $Block $Bins ([int]$Route.IsPresent) 2>&1 |
            Tee-Object -FilePath "reports/phase9/${tag}_vivado.log"
        if ($LASTEXITCODE -ne 0) { throw "Vivado failed for $tag" }
        if (-not (Select-String -Path "reports/phase9/${tag}_vivado.log" -Pattern "^PHASE9_DONE=$tag$" -Quiet)) {
            throw "Missing completion marker for $tag"
        }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
