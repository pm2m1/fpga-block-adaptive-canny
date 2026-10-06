# Resource-Scalable Block-Adaptive Canny Edge Detector on Artix-7

This project implements a block-adaptive Canny edge detector in Verilog for the Xilinx Artix-7 XC7A100T. A streaming Gaussian/Sobel/CORDIC/NMS pipeline feeds local histogram-based adaptive thresholding. Different block sizes, histogram resolutions, and one-, two-, and four-engine configurations were evaluated for edge-map agreement, FPGA resource use, timing, and throughput.

The core accepts an 8-bit grayscale raster and produces a 1-bit edge raster:

```text
Gaussian → Sobel → fixed-point CORDIC → non-maximum suppression
         → block histogram/thresholds → one-pass local weak-edge promotion
```

There are two threshold modes: runtime global LOW/HIGH values, or block-adaptive values from nonzero post-NMS magnitudes. The selected adaptive configuration uses 32×32 blocks, 32 uniform bins and one threshold engine. The histogram selects a bin near the strongest 20% of nonzero candidates; its lower boundary gives HIGH, and LOW is `floor(2 × HIGH / 5)`. Both classification comparisons are strict `>`.

The final board wrapper targets the Nexys A7-100T (`xc7a100tcsg324-1`). It reads a stored 640×480 grayscale image, captures a packed edge frame and serializes a UART packet. It does not include a camera, HDMI or Zynq interface. The hardware's last stage is **one-pass local weak-edge promotion**, not full recursive Canny hysteresis. A recursive 8-connected implementation is retained only as a software reference.

## What was tested

The Python model and RTL matched at intermediate stages, block thresholds and output frames. All three adaptive-engine counts gave the same tested edge results. Replication raised resource use but did not improve the 318,968-cycle frame-start cadence: the shared input front end and ordered output each handle one pixel per clock. E=1 is the final wrapper configuration.

| Check | Status |
| --- | --- |
| Bit-accurate Python reference and RTL core | PASS |
| Frame-border and runtime-threshold regressions | PASS |
| Block-adaptive RTL/model and 1/2/4-engine comparisons | PASS |
| RTL board-wrapper and simulated UART protocol | PASS |
| Post-synthesis functional check | PARTIAL PASS: 2,100 pixels; no full frame |
| Post-route functional simulation | PASS: 307,200 pixels, zero mismatches |
| 100 MHz routed static timing and final DRC | PASS |
| Bitstream generation | PASS |
| Post-route SDF timing simulation | UNRESOLVED: BRAM hold warnings |
| Physical programming, UART capture and power measurement | NOT PERFORMED |

The SDF warnings were not suppressed. Static timing closes at 100 MHz, but the discrepancy remains unresolved ([Phase 11V report](reports/PHASE11V_NO_BOARD_VALIDATION.md)). A physical Nexys A7 was unavailable, so the bitstream was **not run on a board**. No board FPS, physical processing latency or physical power was measured.

## Resource and timing snapshot

| Design | LUT | FF | LUTRAM | BRAM18 equivalents | DSP | Routed WNS at 10 ns |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Adaptive core, E=1 | 3,834 | 3,059 | 645 | 52 | 0 | +0.960 ns |
| Adaptive core, E=2 | 6,058 | 4,252 | 1,285 | 96 | 0 | +0.675 ns |
| Adaptive core, E=4 | 10,299 | 6,627 | 2,565 | 184 | 0 | +0.644 ns |
| Final E=1 board wrapper | 4,063 | 3,299 | 644 | 244 / 270 | 0 | +0.436 ns |

The wrapper's 244 BRAM18 equivalents comprise 160 for the test-image ROM, 32 for the packed output frame and 52 for the algorithm core. Its routed TNS is zero and final DRC reports zero findings. A bitstream was generated, but is not tracked as normal source; the recorded SHA-256 is `c8e04b06d54fa59b0cda3ac7c219da78766021f0e91fa43d4c7b85b5e5d9513d` ([artifact record](reports/phase11v/bitstream_identity.txt)).

The wrapper's simulated processing counter reported 339,885 cycles. Dividing by 100 MHz gives **3.39885 ms analytical processing time**, not measured board latency. The 318,968-cycle core cadence corresponds to a **100 MHz core cadence estimate** of about 313.51 frame-starts/s, not measured camera or board FPS. Vivado's vectorless post-route estimate was 0.103 W static + 0.101 W dynamic = 0.204 W total, with **low confidence** and no physical power measurement.

## Reproducing the checks

Use Windows PowerShell, Python 3 and Vivado 2026.1. Set `VIVADO_BIN` to the Vivado `bin` directory (or pass `-VivadoBin` to final runners). The scripts use a temporary `W:` mapping for the repository path; they refuse to overwrite an existing Vivado project or bitstream. Work from a clean clone for a rebuild.

```powershell
$env:VIVADO_BIN = 'C:\path\to\Vivado\bin'
python scripts/phase11/verify_sync_core.py
python host/phase11/test_protocol.py
python -m model.phase9.tests
python -m model.phase10.tests
python scripts/phase11/generate_assets.py
& scripts/phase11/run_wrapper_sim.ps1 -Test monkey -CaptureUart
& scripts/phase11/run_vivado.ps1
& scripts/phase11/run_bitstream.ps1
```

`run_vivado.ps1` builds the final Tcl project for `xc7a100tcsg324-1`; `run_bitstream.ps1` checks routed timing/DRC before bitstream generation. The [Phase 11 instructions](scripts/phase11/README.md) cover the other patterns and UART packet decoder. [Phase 11V instructions](scripts/phase11v/README.md) cover netlist checks and their known SDF failure. These are no-board workflows unless a physical device is separately available.

The checked-in layout preserves tested paths: `rtl/phase11/` is the final synthesizable source, `model/` the Python reference, `tb/` the testbenches, `scripts/phase11/` the final build flow, `constraints/phase11/` the used-pin XDC, `host/phase11/` the packet decoder, and `results/phase9`/`phase10` plus final reports the main experiments. Older `rtl/phase*` trees are not alternate final tops.

More detail: [architecture](docs/architecture.md), [verification](docs/verification.md), [results](docs/results.md), [limitations](docs/limitations.md), and [references](docs/references.md).
