$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$vivado='C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat'
if (-not (Test-Path -LiteralPath $vivado)) { throw "Missing Vivado: $vivado" }
$drive='W:'
if (Test-Path -LiteralPath "$drive\") { throw "$drive is occupied." }
& subst.exe $drive $workspace
if ($LASTEXITCODE -ne 0) { throw 'Temporary drive mapping failed.' }
try {
    Push-Location "$drive\"
    try {
        & $vivado -mode batch -source scripts/phase4b/audit_phase4_paths.tcl -nojournal -nolog 2>&1 |
            Tee-Object -FilePath reports/phase4b_path_audit.log
        if ($LASTEXITCODE -ne 0) { throw 'Phase-4 path audit failed.' }
    } finally { Pop-Location }
} finally { & subst.exe $drive /D | Out-Null }
