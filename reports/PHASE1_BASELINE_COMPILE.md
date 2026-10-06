# Phase 1 conventional baseline — PASS (Vivado Simulator 2026.1)

## Historical result before Vivado 2026.1 installation (superseded)

Follow-up discovery confirmed that the failure is not merely an unconfigured PATH: see `reports/PHASE1_TOOL_DISCOVERY.md` for `where.exe`, PowerShell, common-root, registry, version-command and C:/D: search results. The Phase 1 runner was retried and again stopped before compilation. Phase 1 remains FAIL/unproven; Phase 2 has not started.

The working RTL comes byte-for-byte from the archived 11 source modules. `rtl/baseline/canny_get_grandient.v:53` is a comment in that version; the original extracted copy's standalone `-` is retained only in `baseline_original/extracted_differences/`. `tb/baseline/canny_tb.sv` has workspace-relative BMP paths. No architecture or numeric RTL repair has been made.

The reproducible run is `powershell -ExecutionPolicy Bypass -File scripts/run_baseline_sim.ps1` from this workspace. It compiles with `xvlog`, elaborates `canny_tb` with `xelab`, and runs XSim for 9 ms with `scripts/run_baseline_sim.tcl`. The run stays inside this workspace. The 6 ns clock and half-rate pixel enable, together with 670 horizontal × 510 vertical pixel slots, give a 4.1004 ms nominal frame period; 9 ms covers two nominal frames plus reset and pipeline latency (`tb/baseline/canny_tb.sv:18-31`; `tb/baseline/sim_cmos_tb.sv:69-97,100-161`). The input BMP header is valid for the testbench's expected 640×480, 24-bit, offset-54 format.

**Observed:** `xvlog`, `xelab`, `xsim`, and `vivado` are not on PATH, not in the checked `C:\Xilinx\Vivado\2024.1\bin` or `C:\Program Files\AMD\Vivado\2024.1\bin` paths, and no Vivado/Vitis/Icarus/Verilator installation appears in standard installed-program registry entries. Consequently compilation, elaboration, startup X behavior, complete-frame pixel count, and algorithm output remain **untested**. Phase 1 is marked FAIL because its success criteria are unproven; this is an environment blocker, not evidence of an RTL failure. No later architectural phase or A100T synthesis was started.

When XSim is available, rerun the script, preserve `reports/phase1_xvlog.txt`, `phase1_xelab.txt`, `phase1_xsim.txt`, inspect all warnings, verify the BMP pixel count, and update this report to PASS only after every Phase 1 criterion is observed. `reports/PHASE1_WARNINGS.txt` records the present warning status.

## Current Phase 1 result — PASS (Vivado Simulator 2026.1)

The older FAIL/tool-unavailable text above is historical and superseded. This is a verified **simulation baseline**, not numerical Canny correctness, synthesis, or hardware execution.

Workspace: this repository root. Git was clean before this Phase 1 run at `20eece9 Done`. No original extracted source, `.xpr`, archive, or Zynq reference was changed. The working `rtl/baseline/canny_get_grandient.v` SHA256 is `3645FE446DDD182EF7F6D90C0F77F6D505838557F1E7552E523B474EC67B702C`, byte-identical to the archived copy; its extracted standalone `-` is absent.

Toolchain: Vivado Simulator v2026.1. Absolute tools: `C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat`, `C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat`, `C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat`, and `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat`. Vivado itself prints `v2026.1 (64-bit)` for `-version`, though that command returned code 1. The simulator tools' `--version` invocations succeeded. The runner uses absolute paths and a temporary `W:` mapping of this workspace because AMD's batch startup cannot parse the original parent path's parentheses. The mapping is removed afterward; PATH is unchanged.

Reproduce with `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_phase1_xsim.ps1` from this workspace. The Verilog and SystemVerilog source set and ordering are in `scripts/phase1_files.prj`: 11 files under `rtl/baseline/` and `sim_cmos_tb.sv`, `video_to_pic.sv`, `canny_tb.sv` under `tb/baseline/`. Top: `canny_tb`. Snapshot: `canny_tb_snapshot`. No Zynq source was compiled.

| Stage | Result | Evidence |
|---|---|---|
| XVLOG compile | **PASS** | `reports/phase1_xvlog.log`: all 14 source files analyzed, no warnings/errors. |
| XELAB elaboration | **PASS** | `reports/phase1_xelab.log`: snapshot built, 17 warnings, no errors. |
| XSIM simulation | **PASS** | `reports/phase1_xsim.log`: 9 ms run completed, no fatal error/crash. |
| Complete frames | **PASS** | Frame 0: 307,200 active pixels, 35,922 output-bit toggles, 0 unknowns. Frame 1: 307,200 active pixels, 36,422 toggles, 0 unknowns. |
| BMP | **YES** | `results/phase1/outcom.bmp`: 921,654 bytes, `BM` signature, pixel bytes contain both 0 and 255. |

Calculation: `tb/baseline/canny_tb.sv:18-32` specifies 640×480 and a 6 ns clock. `tb/baseline/sim_cmos_tb.sv:69-87` gives 670 horizontal slots, 510 vertical slots, and one pixel-enable per two clocks. Hence one frame is `670 × 510 × 2 × 6 ns = 4.1004 ms`; reset releases after 120 ns. The actual 9 ms simulation covers two output frame boundaries, at approximately 4.100685 and 8.201085 ms. The `time_ns` field in the current monitor display is mislabeled: XSim renders `%t` in picosecond-scaled units, so `4100685000` means approximately 4.100685 ms. This display label does not affect the count. The monitor in `tb/baseline/canny_tb.sv:145-182` samples `posedge cmos_clk` only if both `canny_de` and `canny_hsync` are high, and ends a frame on falling `canny_vsync`; it does not count VCD transitions. The BMP writer selects the first frame (`tb/baseline/video_to_pic.sv:64-71,102-116`). No output pixels were suppressed at the protocol level; border-value correctness is not established.

Warnings: one 16-bit actual versus 22-bit formal `sqrt_out` connection at `rtl/baseline/canny_get_grandient.v:180`; sixteen 32-bit actual versus 6-bit formal `pipline_level` connections at `rtl/baseline/cordic_sqrt.v:42-57`. No compile, elaboration, or runtime errors. CORDIC range/tap/alignment, RGB conversion, thresholds, one-pass hysteresis, Gaussian synthesis hierarchy, and overall algorithm correctness remain unmodified/unproven in this phase.

**Final Phase 1 status: PASS. Phase 2 was not started.**
