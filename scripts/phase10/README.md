# Phase 10 reproduction (PowerShell from workspace root)

Use Vivado/XSim 2026.1 installed at `C:\AMDDesignTools\2026.1\Vivado\bin` and Python 3.12 at `C:\Program Files\Python312\python.exe`. Scripts invoke absolute tool paths and temporarily map this workspace to `W:`; run only **one Vivado/XSim script at a time**. They never edit an older project. Phase 9 vector oracles in `results/phase9/vectors/` are generated dependencies; if absent, run `& 'C:\Program Files\Python312\python.exe' scripts/phase9/prepare_rtl_oracle.py --block 32 --bins 32 --suite two` and repeat with `--suite isolate`.

1. Python architecture checks: `& 'C:\Program Files\Python312\python.exe' -m model.phase10.tests`.
2. Normal 1/2/4 RTL and direct Phase 9 comparison: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase10/run_rtl.ps1 -Engines 1 -Suite two`, then repeat with `-Engines 2` and `-Engines 4`.
3. Frame-isolation regression: repeat the three commands with `-Suite isolate`.
4. Directed out-of-order completion/grant test: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase10/run_rtl.ps1 -Engines 2 -Suite two -DelayedFirst`. This testbench-only hold changes transient timing; do not use it for normal cadence metrics.
5. Synthesis **and route** for E=1/2/4: `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase10/run_synth.ps1 -Engines 1`, then 2, then 4. Project creation refuses to overwrite an existing `vivado/phase10_e*/` directory. Preserve completed projects and use a fresh workspace copy/project name for a rerun; do not delete caches to force it.
6. Collect evidence tables: `& 'C:\Program Files\Python312\python.exe' scripts/phase10/collect_results.py`.

Simulation compares valid clock-edge pixels, classes, and thresholds to the Phase 9 model. The source uses one shared post-NMS stream. `results/phase10/checkpoints/` and `vivado/phase10_*/` are generated/ignored; report logs and concise CSVs are tracked. No bitstream, board pins, implementation beyond route, or physical measurement is included.
