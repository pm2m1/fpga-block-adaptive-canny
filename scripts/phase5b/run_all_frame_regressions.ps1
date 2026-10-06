$ErrorActionPreference='Stop'
foreach ($suite in @('small','full','isolate_ab','isolate_cd','leakage')) {
    Write-Host "PHASE5B_SUITE_START $suite"
    & (Join-Path $PSScriptRoot 'run_trace.ps1') -Suite $suite
    if ($LASTEXITCODE -ne 0) { throw "Phase 5B suite failed: $suite" }
    Write-Host "PHASE5B_SUITE_PASS $suite"
}
