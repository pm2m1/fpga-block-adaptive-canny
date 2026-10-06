# Phase 11 reproducibility (Vivado 2026.1, Windows)

Run all commands from the repository root in PowerShell. Set `VIVADO_BIN` to the local Vivado 2026.1 `bin` directory, or pass `-VivadoBin` to a runner; if neither is set, the runner checks for `vivado.bat` on PATH. The scripts temporarily map the workspace to `W:` (or `V:` for simulation while `W:` is busy). They do not change system PATH or any historic project. A clean checkout already contains the Phase 11 synchronous-reset copies; `import_sync_core.py` documents their provenance and deliberately refuses to overwrite them.

```powershell
python scripts/phase11/generate_assets.py
python scripts/phase11/verify_sync_core.py
python host/phase11/test_protocol.py
& scripts/phase11/run_core_regression.ps1
& scripts/phase11/run_wrapper_sim.ps1 -Test monkey -CaptureUart
& scripts/phase11/run_wrapper_sim.ps1 -Test black
& scripts/phase11/run_wrapper_sim.ps1 -Test vertical
& scripts/phase11/run_wrapper_sim.ps1 -Test checkerboard
python host/phase11/capture_board_output.py --packet results/phase11/sim_uart_packet.bin --output results/phase11/sim_uart_reconstruction.png
& scripts/phase11/run_vivado.ps1
& scripts/phase11/run_bitstream.ps1
& scripts/phase11/run_detect_hardware.ps1
```

`run_vivado.ps1` creates `vivado/phase11_board_rev3/`, synthesizes, routes, checks timing/DRC, writes a routed checkpoint, and generates a **vectorless post-route power estimate**. `run_bitstream.ps1` independently checks routed timing and zero DRC violations before writing `results/phase11/canny_nexys_a7.bit`. These scripts refuse to overwrite an existing project or bitstream; for a fresh reproduction use a clean clone/workspace, not destructive cleanup of this one. The `rev1`/`rev2` directories and reports in the development workspace are preserved diagnostic iterations, not production files.

The production wrapper is `rtl/phase11/canny_nexys_a7_phase11_top.v`, part `xc7a100tcsg324-1`, clock 100 MHz from Nexys A7 pin E3. It uses the single-engine Phase 10 algorithm with 32×32 blocks and 32 bins. The copy under `rtl/phase11/core/` changes only asynchronous reset sensitivity to synchronous reset for BRAM-control safety; the two-frame 614,400-pixel model regression remains exact. The input ROM is `images/phase11/monkey_gray.mem`, generated from the existing BMP as `Y=(77R+150G+29B)>>8`, one top-down raster byte per pixel. Procedural selector on SW[2:0]: 0 monkey, 1 black, 2 white, 3 vertical step, 4 horizontal step, 5 checkerboard. Press CPU_RESETN, release it, set switches, then press BTNC to start. LEDs 0–3 indicate non-idle, done, UART transmission, and error respectively. One frame is processed per start/reset sequence.

The output frame is 38,400 bytes, raster order, first edge pixel in each byte's bit 7. USB-UART transmits a 38,426-byte 8-N-1 packet at nominal 115,200 baud: ASCII `CNY1`, version byte 1, little-endian width/height, test ID, 32-bit processing cycle count, 32-bit payload length, 32-bit valid-pixel count, packed payload, then little-endian IEEE reflected CRC32 of the payload. UART transfer time is **not** processing time. Open the host receiver first, then press BTNC:

```powershell
& scripts/phase11/run_program_hardware.ps1
python host/phase11/capture_board_output.py --port COM3 --save-packet results/phase11/physical_packet.bin --output results/phase11/physical_edge.png
```

Replace `COM3` with the actual Nexys USB-UART port. `run_program_hardware.ps1` requires exactly one JTAG target with one XC7A100T. It is not run automatically after bitstream generation. The capture command checks sync, metadata, exact byte/pixel count, CRC32, and every edge bit against `results/phase11/<test>_golden.bin`; zero mismatches are required for board PASS. The physical board was **not detected** in the present run (`reports/phase11/phase11_hardware_detection.log`), so board programming/capture remain pending.

Pin assignments in `constraints/phase11/nexys_a7_100t_board.xdc` are transcribed for used ports only from [Digilent's Nexys-A7-100T master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc); configuration-bank voltage follows Digilent's board schematic. No camera, HDMI, DDR, Zynq, or board-measured power is involved. The vectorless power report has **Low** confidence because no representative SAIF was available; the attempted all-signal XSim SAIF run was aborted after excessive runtime and is not a numerical result.
