# Phase 9 reproduction (PowerShell, from workspace root)

Prerequisites: Vivado/XSim 2026.1 at `C:\AMDDesignTools\2026.1\Vivado\bin`, Python 3.12 at `C:\Program Files\Python312\python.exe`, and the Phase 8 deterministic NMS/test streams. No system PATH change, old Vivado project edit, or bitstream is required. Scripts use a temporary `W:` mapping while each Vivado tool runs, so do not launch two scripts using `W:` simultaneously.

1. Model checks: `& 'C:\Program Files\Python312\python.exe' -m model.phase9.tests`.
2. Common-input software sweep: `& 'C:\Program Files\Python312\python.exe' scripts/phase9/software_sweep.py`. If `results/phase8/patterns_nms.mem` is absent, first run `& 'C:\Program Files\Python312\python.exe' scripts/phase8/prepare_suite.py --suite patterns`.
3. Schedule audit: `& 'C:\Program Files\Python312\python.exe' scripts/phase9/schedule_analysis.py`.
4. All RTL configurations, fixed mode, and isolation: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase9/run_matrix.ps1`.
5. Direct 32×32/32-bin Phase 8 equivalence: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase9/run_phase8_equiv.ps1`.
6. Histogram boundary/overflow tests: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase9/run_hist_units.ps1`.
7. Six A100T synthesis runs and four corner-case routes: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase9/run_synth_matrix.ps1`. Each project is created once; scripts refuse overwrite. To rerun one configuration, use a new project name/workspace copy rather than deleting a completed Vivado project.
8. Collect actual reports: `& 'C:\Program Files\Python312\python.exe' scripts/phase9/collect_results.py`.

`results/phase9/vectors/`, `results/phase9/checkpoints/`, and `vivado/phase9_*/` are generated. The scripts/reports and concise software tables are source-controlled; generated projects and large stimulus vectors are excluded. All RTL pixel comparisons use valid clock-edge samples, not VCD transitions. Output cadence numbers are simulation cycles and 100 MHz analytical conversions, not measured physical-board FPS.
