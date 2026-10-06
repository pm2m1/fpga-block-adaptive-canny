# Phase 3 Gaussian integration — PASS

The Phase 2 architecture was grayscale → gradient/Sobel/CORDIC → NMS → threshold/local promotion. Phase 3 is grayscale → **existing Gaussian** → the **unchanged** Phase 2 Canny core. Only `rtl/phase3/canny_edge_detect_gaussian_top.v` is new synthesis RTL. `git diff -- rtl/baseline` was empty before checkpointing; all validated baseline modules remain byte-unchanged.

## Existing Gaussian behavior verified from source

`rtl/baseline/vip_gaussian_filter.v:1-14` accepts `clk`, active-low `rst_n`, 8-bit `per_img_gray`, and `per_frame_vsync/href/clken`; it emits corresponding delayed controls and 8-bit `post_img_gray`. `vip_gaussian_filter.v:44-47` instantiates a fixed-width 640-pixel `matrix_generate_3x3`, which uses two `fifo_ram` line buffers via `one_column_ram` (`matrix_generate_3x3.v:51-54`; `one_column_ram.v:33-53`). The coefficients at `vip_gaussian_filter.v:79-81` are exactly `(1,2,1)`, `(2,4,2)`, `(1,2,1)`, and `sum_gray >> 4` at line 118 divides by 16 with integer truncation. No coefficients or arithmetic changed.

The 3×3 matrix generator registers `vsync/href/clken` through `per_frame_*_r[1:0]` (`matrix_generate_3x3.v:36-48,64-75`) and the Gaussian adds two more control registers (`vip_gaussian_filter.v:94-117`). Thus an input sampled at rising edge *n* appears at the Gaussian control/data output after edge *n+3*: **three full 6 ns clock periods (18 ns) of registered latency**, apart from the spatial two-line window/line-buffer content. The weighted row sums register once at lines 71-83, then their total at lines 85-91, aligning with the delayed controls. Reset is asynchronous active-low for matrix and arithmetic/control registers; line-buffer pointers and contents use initialization instead of a frame reset (`fifo_ram.v:18-31`). `matrix_generate_3x3.v:85-100` zeros window taps when the delayed `href` is low, but there is **no explicit top/left/right/bottom border-valid suppression**. Border numerical behavior and potential prior-frame line-buffer contents remain unproven; this phase preserves them exactly.

`rtl/phase3/canny_edge_detect_gaussian_top.v:21-45` connects Gaussian delayed `vsync/href/clken` and pixel Y directly into the unmodified `canny_edge_detect_top`. RGB conversion is intentionally excluded from the synthesized core: the research core is an 8-bit grayscale accelerator, and this phase isolates Gaussian placement.

## Simulation equivalence

`tb/phase3/tb_phase3_equivalence.sv` uses **one** `sim_cmos` BMP reader and **one** RGB→Y converter. Reference path: Y → external `image_gaussian_filter` → baseline `canny_edge_detect_top`. New path: the same Y → `canny_edge_detect_gaussian_top`, whose Gaussian is internal. No path applies Gaussian twice. At every rising clock after reset, the testbench compares all three output controls cycle-by-cycle, rejects unknown controls, and compares one-bit pixels only when `href && clken` is asserted. Frames close on the output `vsync` falling edge. The paths had naturally identical control/pixel timing, so **testbench alignment delay = 0 clocks** and overall latency difference vs reference = **0 clocks**.

XVLOG **PASS**, XELAB **PASS**, XSIM **PASS**. `reports/phase3_xsim.log:15-16` records **two** complete 640×480 frames. Each compared 307,200 valid pixels, matched 307,200, mismatched 0, and had 0 unknown output pixels. Total: **614,400 compared, 614,400 matched, 0 mismatched**. First mismatch coordinate/time/value: **not applicable**. `results/phase3/outcom.bmp` was produced (921,654 bytes). The run duration was 9 ms; Phase 1's 670×510 slots and half-rate 6 ns clock give a 4.1004 ms nominal frame period. The old Phase 1 scripts and reports were not changed.

## A100T synthesis and resources

Vivado 2026.1 target `xc7a100tcsg324-1`, top `canny_edge_detect_gaussian_top`, 100 MHz core-only XDC. Synthesis **PASS**, 0 errors (`reports/phase3_synth.log`, `phase3_synth_runme.log:449`). `reports/PHASE3_ACTIVE_HIERARCHY.md` and `reports/phase3_utilization_hierarchical.rpt:25-44` prove Gaussian is **reachable** and RGB→YCbCr is **not reachable**.

| Resource / preliminary timing | Phase 2 baseline | Phase 3 + Gaussian | Delta |
|---|---:|---:|---:|
| LUT | 651 | 760 | +109 |
| FF | 799 | 985 | +186 |
| RAMB18 | 6 | 8 | +2 |
| RAMB36 | 0 | 0 | 0 |
| DSP | 1 | 1 | 0 |
| Synthesis WNS @ 10 ns | +2.738 ns | +2.738 ns | 0.000 ns |

Sources: `reports/phase2_utilization.rpt:34-39,77-92`, `reports/phase3_utilization.rpt:34-39,77-92`, and corresponding timing summaries at line 141. The hierarchy attributes approximately 110 LUT/186 FF/two RAMB18 to Gaussian; the top-level delta is 109 LUT because Vivado optimized one LUT across the wrapper boundary. The unchanged WNS is the synthesis-stage worst path, **not** proof of implementation timing closure or a measured Fmax. No board pins or external I/O delays were constrained.

Synthesis warnings: **33**, exactly the same count and types as Phase 2: 19 parameter-to-localparam messages, one 16→22-bit `sqrt_out` mismatch, six undriven FIFO full/empty warnings, six unloaded FIFO-port warnings, and one CORDIC set/reset-priority warning (`reports/phase3_synth_runme.log:53-148,449`; compare `reports/phase2_synth_runme.log:53-144,436`). **No new synthesis warning** was introduced by the Phase 3 wrapper or Gaussian. XELAB likewise retained the existing 17 port-width warnings; no new elaboration warning. DRC has 16 findings vs 14 in Phase 2: the same two expected missing-board-I/O critical warnings, and two additional RAMB18 async-control checks corresponding to the two new Gaussian line buffers (`reports/phase3_drc.rpt:27-38`). These are recorded, not suppressed, and merit review before board implementation; no bitstream was attempted.

Files: `scripts/run_phase3_equivalence.ps1`, `scripts/phase3_files.prj`, `scripts/phase3_run.tcl`, `scripts/run_phase3_synth.ps1`, `scripts/create_phase3_a100t_project.tcl`; full logs `reports/phase3_xvlog.log`, `phase3_xelab.log`, `phase3_xsim.log`, `phase3_synth.log`, `phase3_synth_runme.log`; generated reports `reports/phase3_utilization.rpt`, `phase3_utilization_hierarchical.rpt`, `phase3_timing_summary.rpt`, `phase3_drc.rpt`; checkpoint `results/phase3/canny_a100t_gaussian_synth.dcp`. The generated Vivado project is ignored and reproducible from Tcl.

**Phase 3 proves integration of the existing Gaussian filter into the synthesizable grayscale Canny datapath. It does not validate or repair the existing CORDIC numeric behavior, threshold strategy, hysteresis algorithm, final FPGA timing closure, or physical-board operation.** No Phase 4 work was started.
