param([string]$VivadoBin = $env:VIVADO_BIN)

$ErrorActionPreference = 'Stop'
$workspace = Split-Path -Parent $PSScriptRoot
$reportDir = Join-Path $workspace 'reports'
$resultDir = Join-Path $workspace 'results/phase1'
New-Item -ItemType Directory -Path $resultDir -Force | Out-Null

if (-not $VivadoBin) {
    $command = Get-Command xvlog -ErrorAction SilentlyContinue
    if ($command) { $VivadoBin = Split-Path -Parent $command.Source }
}
if (-not $VivadoBin) {
    foreach ($root in @('C:\Xilinx\Vivado', 'C:\AMD\Vivado', 'D:\Xilinx\Vivado', 'D:\AMD\Vivado', 'C:\Program Files\AMD\Vivado')) {
        if (Test-Path -LiteralPath $root) {
            $versions = Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue | Sort-Object Name -Descending
            foreach ($version in $versions) {
                $candidate = Join-Path $version.FullName 'bin'
                if ((Test-Path -LiteralPath (Join-Path $candidate 'xvlog.bat')) -or
                    (Test-Path -LiteralPath (Join-Path $candidate 'xvlog.exe'))) { $VivadoBin = $candidate; break }
            }
        }
        if ($VivadoBin) { break }
    }
}
if (-not $VivadoBin) {
    throw 'XSim not found; pass -VivadoBin <Vivado/bin> if installed. No compile was attempted.'
}

function Find-Tool([string]$name) {
    foreach ($suffix in @('.bat', '.exe', '')) {
        $path = Join-Path $VivadoBin ($name + $suffix)
        if (Test-Path -LiteralPath $path) { return $path }
    }
    throw "Required XSim tool missing: $name in $VivadoBin"
}

$xvlog = Find-Tool 'xvlog'
$xelab = Find-Tool 'xelab'
$xsim = Find-Tool 'xsim'
$rtl = @(
    'canny_edge_detect_top.v', 'canny_get_grandient.v', 'canny_nonLocalMaxValue.v',
    'cordic_pipline.v', 'cordic_sqrt.v', 'fifo_ram.v', 'matrix_generate_3x3.v',
    'vip_gaussian_filter.v', 'canny_doubleThreshold.v', 'one_column_ram.v',
    'VIP_RGB888_YCbCr444.v'
) | ForEach-Object { Join-Path $workspace "rtl/baseline/$_" }
$testbenches = @('sim_cmos_tb.sv', 'canny_tb.sv', 'video_to_pic.sv') |
    ForEach-Object { Join-Path $workspace "tb/baseline/$_" }

Push-Location $workspace
try {
    & $xvlog -sv @rtl @testbenches 2>&1 | Tee-Object -FilePath (Join-Path $reportDir 'phase1_xvlog.txt')
    if ($LASTEXITCODE -ne 0) { throw "xvlog failed: $LASTEXITCODE" }
    & $xelab canny_tb -s canny_tb_phase1 2>&1 | Tee-Object -FilePath (Join-Path $reportDir 'phase1_xelab.txt')
    if ($LASTEXITCODE -ne 0) { throw "xelab failed: $LASTEXITCODE" }
    & $xsim canny_tb_phase1 -tclbatch (Join-Path $workspace 'scripts/run_baseline_sim.tcl') 2>&1 |
        Tee-Object -FilePath (Join-Path $reportDir 'phase1_xsim.txt')
    if ($LASTEXITCODE -ne 0) { throw "xsim failed: $LASTEXITCODE" }
} finally {
    Pop-Location
}

$bmp = Join-Path $resultDir 'outcom.bmp'
if (-not (Test-Path -LiteralPath $bmp)) { throw 'XSim exited but output BMP was not created.' }
Write-Output "Phase 1 batch completed. Inspect valid pixel count and warnings: $bmp"
