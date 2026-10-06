param(
    [ValidateSet(32,64)][int]$Block=32,
    [ValidateSet(8,16,32)][int]$Bins=32,
    [ValidateSet('two','isolate')][string]$Suite='two',
    [switch]$Fixed
)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$python='C:\Program Files\Python312\python.exe'
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
Push-Location $workspace
try {
    & $python scripts/phase9/prepare_rtl_oracle.py --block $Block --bins $Bins --suite $Suite
    if ($LASTEXITCODE -ne 0) { throw 'Oracle generation failed' }
} finally { Pop-Location }
$tag="b${Block}_h${Bins}_${Suite}_" + $(if ($Fixed) {'fixed'} else {'adaptive'})
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $xvlog -prj scripts/phase9/phase9.prj 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'RTL XVLOG failed' }
        $defines=@()
        if ($Block -eq 64) { $defines+=@('-d','PHASE9_B64') }
        if ($Bins -eq 8) { $defines+=@('-d','PHASE9_H8') }
        if ($Bins -eq 16) { $defines+=@('-d','PHASE9_H16') }
        if ($Suite -eq 'isolate') { $defines+=@('-d','PHASE9_ISOLATE') }
        if ($Fixed) { $defines+=@('-d','PHASE9_FIXED') }
        & $xvlog @defines -prj scripts/phase9/phase9_tb.prj 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_tb_xvlog.log"
        if ($LASTEXITCODE -ne 0) { throw 'TB XVLOG failed' }
        $snapshot="phase9_${tag}_snapshot"
        & $xelab xil_defaultlib.tb_phase9 -s $snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_xelab.log"
        if ($LASTEXITCODE -ne 0) { throw 'XELAB failed' }
        & $xsim $snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_xsim.log"
        if ($LASTEXITCODE -ne 0) { throw 'XSIM failed' }
        if (-not (Select-String -Path "reports/phase9/${tag}_xsim.log" -Pattern '^PHASE9_RTL_PASS ' -Quiet)) {
            throw 'Missing Phase9 pass marker; inspect XSim log'
        }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
