$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'run_rtl.ps1'
foreach ($block in @(32,64)) {
    foreach ($bins in @(8,16,32)) {
        & $runner -Block $block -Bins $bins -Suite two
        if ($LASTEXITCODE -ne 0) { throw "adaptive failed block=$block bins=$bins" }
        & $runner -Block $block -Bins $bins -Suite two -Fixed
        if ($LASTEXITCODE -ne 0) { throw "fixed failed block=$block bins=$bins" }
    }
}
foreach ($pair in @(@(32,8),@(32,32),@(64,32))) {
    & $runner -Block $pair[0] -Bins $pair[1] -Suite isolate
    if ($LASTEXITCODE -ne 0) { throw "isolation failed block=$($pair[0]) bins=$($pair[1])" }
}
Write-Host 'PHASE9_RTL_MATRIX_PASS adaptive=6 fixed=6 isolate=3'
