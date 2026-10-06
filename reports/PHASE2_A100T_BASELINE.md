# Phase 2: A100T conventional Canny baseline — PASS

Vivado version: **2026.1**. Target part: **`xc7a100tcsg324-1`** (Artix-7 XC7A100T, Nexys A7-100T target). Synthesis top: **`canny_edge_detect_top`**. Clock assumption: **10.000 ns / 100 MHz** on actual top port `clk`, from `constraints/phase2_core_timing.xdc`. The synthesis project was created wholly from `scripts/create_phase2_a100t_project.tcl` via `scripts/run_phase2_synth.ps1`, using `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat` and a temporary `W:` workspace mapping. The original RTL, archives, extracted projects, historic `.xpr` files, and Zynq reference remain untouched. Phase 1 checkpoint `65ef3ef` was clean before this run.

Synthesis: **PASS**, `synth_design Complete!`, 0 errors and 0 synthesis critical warnings (`reports/phase2_synth_runme.log:436`). No implementation or bitstream was run. The part and top were checked in Tcl both before and after opening the synthesized run (`reports/phase2_synth.log`).

| Synthesized resource | Used | Available | Device share | Source |
|---|---:|---:|---:|---|
| Slice LUTs total | 651 | 63,400 | 1.03% | `reports/phase2_utilization.rpt:34` |
| LUT as logic | 647 | 63,400 | 1.02% | line 35 |
| LUT as memory/SRL | 4 | 19,000 | 0.02% | lines 36-38 |
| Flip-flops | 799 | 126,800 | 0.63% | line 39 |
| Block RAM tiles | 3 | 135 | 2.22% | line 77 |
| RAMB36 | 0 | 135 | 0% | line 78 |
| RAMB18 | 6 | 270 | 2.22% | line 79 |
| DSP48E1 | 1 | 240 | 0.42% | lines 91-92 |
| BUFGCTRL | 1 | 32 | 3.13% | line 124 |
| Bonded IOB | 17 | 210 | 8.10% | line 102 |

Six line-buffer RAM arrays were inferred as RAMB18E1: two 640×8, two 640×16, two 640×2 (`reports/phase2_synth_runme.log:250-255`). This confirms baseline BRAM use; no throughput or power was measured.

Timing: requested period **10.000 ns**, synthesized-netlist setup **WNS +2.738 ns**, **TNS 0.000 ns**, zero failing setup endpoints (`reports/phase2_timing_summary.rpt:139-165,215-230`). This is preliminary synthesis timing only, **not placed-and-routed timing closure or measured Fmax**. The core-only XDC assigns no package pins or I/O standards and specifies no external input/output delays. Unconstrained I/O paths and board effects must be addressed later. The DRC reports 14 findings: two expected **critical warnings** (`NSTD-1` unspecified I/O standard and `UCIO-1` unconstrained package pins, each covering all 17 logical ports), plus 12 warnings concerning configuration voltage, DSP pipelining/asynchronous-reset optimizations, and RAMB asynchronous-control checks (`reports/phase2_drc.rpt:23-43`). Their severities were not suppressed; they prohibit a safe bitstream as-is, which is intentional for this core-only phase.

Synthesis recorded **33 warnings** (complete text in `reports/phase2_synth_runme.log`): 19 parameters converted to localparams (including two thresholds and 17 CORDIC constants), one 16-vs-22-bit `sqrt_out` mismatch at `rtl/baseline/canny_get_grandient.v:180`, six undriven `fifo_ram` full/empty flags across parameterized variants at `rtl/baseline/fifo_ram.v:10,14`, one equal-priority set/reset warning at `rtl/baseline/cordic_pipline.v:30`, and six unloaded/unconnected full/empty ports. These warnings were preserved, not fixed or suppressed. The most important algorithm/data risks remain the CORDIC width/truncation and control-alignment concerns; Phase 2 makes no numerical-correctness claim.

Active synthesis hierarchy is detailed in `reports/PHASE2_ACTIVE_HIERARCHY.md` and `reports/phase2_utilization_hierarchical.rpt`. `canny_get_grandient`, `cordic_sqrt`, `cordic_pipline`, `canny_nonLocalMaxValue`, `canny_doubleThreshold`, 3×3 matrix generators, and line buffers are reachable. `vip_gaussian_filter.v` and `VIP_RGB888_YCbCr444.v` are included as files but their modules are **not reachable** from the grayscale synthesis top. Simulation-only modules were not added to `sources_1`.

Known algorithm limitations intentionally still present: Gaussian absent from synthesis hierarchy; fixed thresholds; one-pass local strong-neighbor edge promotion rather than full connected hysteresis; CORDIC width/range and iteration/tap concerns; magnitude truncation concern; possible CORDIC/control latency misalignment; border behavior not numerically proven. None were changed in Phase 2.

Artifacts: `reports/phase2_synth.log`, `reports/phase2_synth_runme.log`, `reports/phase2_utilization.rpt`, `reports/phase2_utilization_hierarchical.rpt`, `reports/phase2_timing_summary.rpt`, `reports/phase2_drc.rpt`, and `results/phase2/canny_a100t_baseline_synth.dcp`. The generated project is under `vivado/phase2_a100t_baseline/` and ignored by Git; it can be recreated from the Tcl/PowerShell scripts. The DCP is small enough to keep as an intentional Phase 2 checkpoint.

**Phase 2 establishes A100T synthesis feasibility only. It does not establish numerical correctness, final timing closure, board operation, real-time FPS, power, or research novelty.** Phase 3 was not started.
