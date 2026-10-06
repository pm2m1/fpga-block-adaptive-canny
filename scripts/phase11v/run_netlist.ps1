param([ValidateSet('post_synth_func','post_route_func','post_route_timesim')][string]$Variant='post_synth_func',
      [switch]$Smoke,[switch]$Pixels,[switch]$Diagnostic,[string]$VivadoBin)
$ErrorActionPreference='Stop'
$workspace=Split-Path -Parent (Split-Path -Parent $PSScriptRoot)
$xvlog=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool xvlog -VivadoBin $VivadoBin
$xelab=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool xelab -VivadoBin $VivadoBin
$xsim=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool xsim -VivadoBin $VivadoBin
$glbl=& "$PSScriptRoot/../phase11/resolve_vivado.ps1" -Tool glbl -VivadoBin $VivadoBin
if (Test-Path -LiteralPath 'W:\') { throw 'Temporary W: drive occupied' }
& subst.exe W: $workspace
if ($LASTEXITCODE -ne 0) { throw 'subst failed' }
try {
  Push-Location 'W:\'
  try {
    $netlist="results/phase11v/$Variant.v"
    $tb=if ($Variant -eq 'post_route_timesim') {'tb/phase11v/tb_netlist_timing.sv'} elseif ($Pixels) {'tb/phase11v/tb_netlist_pixels.sv'} else {'tb/phase11v/tb_netlist_control.sv'}
    $top=if ($Variant -eq 'post_route_timesim') {'tb_netlist_timing'} elseif ($Pixels) {'tb_netlist_pixels'} else {'tb_netlist_control'}
    $compileArgs=@('-work','xil_defaultlib')
    if ($Diagnostic) { $compileArgs+=@('-d','PHASE11V_DIAGNOSTIC') }
    $compileArgs+=@($netlist,$tb,$glbl)
    & $xvlog @compileArgs 2>&1 | Tee-Object -FilePath "reports/phase11v/${Variant}_xvlog.log"
    if ($LASTEXITCODE -ne 0) { throw 'xvlog failed' }
    $primitiveLibrary=if ($Variant -eq 'post_route_timesim') {'simprims_ver'} else {'unisims_ver'}
    $elab=@("xil_defaultlib.$top",'xil_defaultlib.glbl','-L',$primitiveLibrary,'-L','unimacro_ver','-L','secureip','-s',"phase11v_${Variant}")
    if ($Variant -eq 'post_route_timesim') { $elab+=@('-transport_int_delays','-pulse_r','0','-pulse_int_r','0') }
    & $xelab @elab 2>&1 | Tee-Object -FilePath "reports/phase11v/${Variant}_xelab.log"
    if ($LASTEXITCODE -ne 0) { throw 'xelab failed' }
    $simTcl=if ($Smoke -and $Variant -ne 'post_route_timesim') {'scripts/phase11v/netlist_smoke.tcl'} else {'scripts/phase11v/netlist_run.tcl'}
    & $xsim "phase11v_${Variant}" -tclbatch $simTcl 2>&1 | Tee-Object -FilePath "reports/phase11v/${Variant}_xsim.log"
    if ($LASTEXITCODE -ne 0) { throw 'xsim failed' }
    $marker=if ($Variant -eq 'post_route_timesim') {'PHASE11V_SDF_DIRECTED_PASS'} elseif ($Smoke) {'PHASE11V_NETLIST_STARTUP_SMOKE_COMPLETE'} elseif ($Diagnostic) {'PHASE11V_DIAGNOSTIC_COMPLETE'} elseif ($Pixels) {'PHASE11V_NETLIST_PIXELS_PASS'} else {'PHASE11V_NETLIST_CONTROL_PASS'}
    if (-not (Select-String -Path "reports/phase11v/${Variant}_xsim.log" -Pattern $marker -Quiet)) {throw 'PASS marker absent'}
  } finally { Pop-Location }
} finally { & subst.exe W: /D | Out-Null }
