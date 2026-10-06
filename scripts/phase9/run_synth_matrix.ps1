$ErrorActionPreference='Stop'
$runner=Join-Path $PSScriptRoot 'run_synth.ps1'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
foreach ($block in @(32,64)) {
    foreach ($bins in @(8,16,32)) {
        # Route the four corner configurations. All six receive synthesis.
        $route=($bins -eq 8 -or $bins -eq 32)
        $tag="b${block}_h${bins}"
        $required=Join-Path $workspace "reports/phase9/${tag}_timing_$(if ($route) {'route'} else {'synth'}).rpt"
        if (Test-Path -LiteralPath $required) {
            Write-Host "PHASE9_SYNTH_EXISTING $tag report=$required"
            continue
        }
        & $runner -Block $block -Bins $bins -Route:$route
        if ($LASTEXITCODE -ne 0) { throw "Vivado failed block=$block bins=$bins" }
    }
}
Write-Host 'PHASE9_SYNTH_MATRIX_DONE configurations=6 routed=4'
