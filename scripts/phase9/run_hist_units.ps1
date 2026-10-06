$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog='C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat'
$xelab='C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat'
$xsim='C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat'
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive is occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
    Push-Location 'W:\'
    try {
        & $xvlog rtl/phase9/histogram_unit_phase9.v 2>&1 | Tee-Object -FilePath reports/phase9/hist_units_core_xvlog.log
        if ($LASTEXITCODE -ne 0) { throw 'histogram RTL compile failed' }
        foreach ($block in @(32,64)) {
            foreach ($bins in @(8,16,32)) {
                $tag="b${block}_h${bins}"
                $defines=@()
                if ($block -eq 64) { $defines+=@('-d','PHASE9_B64') }
                if ($bins -eq 8) { $defines+=@('-d','PHASE9_H8') }
                if ($bins -eq 16) { $defines+=@('-d','PHASE9_H16') }
                & $xvlog @defines -sv tb/phase9/tb_phase9_histogram.sv 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_hist_xvlog.log"
                if ($LASTEXITCODE -ne 0) { throw "histogram TB compile failed $tag" }
                $snapshot="phase9_${tag}_hist_snapshot"
                & $xelab work.tb_phase9_histogram -s $snapshot -debug typical 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_hist_xelab.log"
                if ($LASTEXITCODE -ne 0) { throw "histogram TB elaborate failed $tag" }
                & $xsim $snapshot -tclbatch scripts/phase8/run_fixed_commute.tcl 2>&1 | Tee-Object -FilePath "reports/phase9/${tag}_hist_xsim.log"
                if ($LASTEXITCODE -ne 0 -or -not (Select-String -Path "reports/phase9/${tag}_hist_xsim.log" -Pattern '^PHASE9_HISTOGRAM_PASS ' -Quiet)) {
                    throw "histogram unit failed $tag"
                }
            }
        }
    } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
