# Phase 11V routed SDF timing-simulation discrepancy

Status: **unresolved; timing simulation did not pass**. Production RTL was not changed.

The Phase 11 routed checkpoint was exported with `write_verilog -mode timesim -sdf_anno true` and `write_sdf -process_corner slow`. XSim 2026.1 elaborated against `simprims_ver` and confirmed successful SDF backannotation to `tb_netlist_timing/dut` in `post_route_timesim_xelab.log`.

At a 10.000 ns testbench clock, before the first output pixel, XSim issued repeated `RAMB36E1` `ADDRARDADDR[0]` versus `CLKARDCLK` hold warnings in `u_core/g_engine[0].u_engine/g_bank[0].stripe_reg_0_*`. One reported interval was 339 ps against a 360 ps model limit. The bounded attempt was interrupted near 7.8 microseconds after 5,920 `$hold violation detected` diagnostic lines and 5,120 RAM-model data-corruption warnings. These are repeated diagnostic lines, **not** a count of unique failing static timing paths. There were zero `$setup violation detected` lines in this attempt. No edge-output samples were checked by the SDF simulation.

The same checkpoint's Vivado static timing reports WNS +0.436 ns, TNS 0, WHS +0.034 ns, THS 0; routed DRC has zero findings. This disagreement does **not** prove the SDF warnings are benign or that hardware would fail. Its root cause has not been established. In particular, no timing exception, model-warning suppression, or production RTL change was used to make the SDF run appear green.

The full simulator log remains locally at `post_route_timesim_xsim.log`; it is intentionally excluded from Git because it is about 9 MB of repetitive warnings. Reproduce using `scripts/phase11v/run_netlist.ps1 -Variant post_route_timesim -Smoke`, after exporting the netlist/SDF with `scripts/phase11v/run_export.ps1`. A future investigation should reconcile the primitive-model hold check with the routed min-delay timing path for the reported BRAM address pin before calling SDF validation successful.
