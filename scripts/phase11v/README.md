# Phase 11V reproducibility (no physical board)

Run from the repository root in PowerShell. Set `VIVADO_BIN` to the local Vivado 2026.1 `bin` directory, or pass `-VivadoBin`; the runners locate their scripts relative to the repository and use a temporary `W:` mapping for parent paths containing parentheses. Do not run two `W:`-mapping scripts concurrently. No Phase 11 RTL or historic project is edited.

```powershell
git status --short
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase11v/audit_artifacts.ps1
python scripts/phase11v/verify_xdc.py
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase11v/run_export.ps1
```

`run_export.ps1` opens the existing synthesis and routed checkpoints and writes generated simulation netlists/SDF plus timing, DRC, clock, CDC, and memory-attribution reports into Phase 11V only. It does not synthesize, implement, or regenerate the bitstream.

RTL wrapper plus independent clock-counter check and fresh simulated UART packet:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase11v/run_cycle_counter.ps1 -CaptureUart
python host/phase11/capture_board_output.py --packet results/phase11v/sim_uart_packet.bin --output results/phase11v/sim_uart_decoded.png
python scripts/phase11v/test_uart_errors.py
```

For exported netlist simulations (the full-frame runs can be very slow):

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase11v/run_netlist.ps1 -Variant post_synth_func -Smoke
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase11v/run_netlist.ps1 -Variant post_route_func -Pixels
powershell -NoProfile -ExecutionPolicy Bypass -File scripts/phase11v/run_netlist.ps1 -Variant post_route_timesim -Smoke
```

For functional variants, `-Smoke` runs only 25 microseconds and checks startup control for X values; it is **not** a full-frame image comparison. `-Pixels` uses the output pixel-counter enable in the exported netlist and compares each valid output bit to `results/phase11/monkey_golden.mem`. The timing variant uses a separate black-pattern testbench with a 250-microsecond limit; `-Smoke` does not shorten it. It uses the exported routed SDF at maximum delays. Verify the elaboration log confirms SDF annotation, then inspect the simulator log for timing violations before claiming a PASS. The present Phase 11V timing simulation is **FAIL/unresolved** because of repeated BRAM hold warnings; rerunning is expected to reproduce them. Preserve all logs under `reports/phase11v/`.

The original Phase 11 project can be rebuilt using `scripts/phase11/README.md`; Phase 11V does not itself create a new bitstream. No hardware-programming or physical-UART instructions are given here because the board was unavailable.
