# Phase 11 — final Nexys A7 build and validation boundary

**Status: BITSTREAM READY; PHYSICAL BOARD VALIDATION PENDING.** Vivado 2026.1 generated a bitstream for `xc7a100tcsg324-1`. Vivado Hardware Manager found **zero JTAG targets** on this computer on 2026-10-06 (`reports/phase11/phase11_hardware_detection.log`). Nothing was programmed and no physical output, hardware cycles, UART time, or board power was measured.

## Final architecture and selection

The final algorithm setting is **one adaptive engine, 32×32 blocks, 32 uniform bins**. This is the verified Phase 10 E=1 architecture: 8-bit grayscale → shared Gaussian → Sobel → corrected 16-stage CORDIC → global NMS → block-local histogram/thresholding → raster replay → one-pass local weak-edge promotion → binary edge. The histogram counts only nonzero 11-bit post-NMS magnitudes, with `bin=magnitude>>6`, descending high-tail selection at `5*cumulative >= N`, `HIGH=max(1,bin<<6)`, `LOW=floor(2*HIGH/5)`, and strict `>` classification. Hardware does **not** perform recursive Canny hysteresis. Phase 10 E=2 and E=4 were algorithmically identical but all three had the same simulated 318,968-cycle output-frame-start cadence and 298,115-cycle adaptive service interval; replication spent additional resources without throughput benefit under the shared one-pixel/clock interface (`reports/PHASE10_MULTI_ENGINE_SCALING.md`).

`rtl/phase11/canny_nexys_a7_phase11_top.v` adds a single-shot Nexys wrapper: one 307,200-byte 8-bit grayscale ROM, procedural pixel patterns, the E=1 core, one 38,400-byte packed edge frame BRAM, cycle counters, status LEDs, and USB-UART transmitter. It needs no camera, HDMI, DDR, Ethernet, Zynq, or RGB conversion. The monkey ROM is generated once by `scripts/phase11/generate_assets.py` from `images/monkey.bmp` with the verified conversion `Y=(77R+150G+29B)>>8`; `images/phase11/monkey_gray.mem` has exactly 307,200 entries. The other test images are generated from x/y counters rather than additional full-frame ROMs. Output bytes are raster-order, first pixel in bit 7.

The 22-byte UART header has `CNY1`, version 1, little-endian width=640 and height=480, test ID, 32-bit first-input-to-last-output processing cycles, payload bytes=38,400, and valid pixels=307,200. It is followed by 38,400 packed bytes and a little-endian IEEE reflected CRC32 of the payload. `host/phase11/capture_board_output.py` checks the complete packet, CRC, count, and every edge bit against the matching Python golden bytes; it reports a first mismatch coordinate. The FPGA divider 868 at 100 MHz transmits at approximately 115,207 baud, compatible with host 115,200 baud. **UART transfer time is separate from image processing.**

## Protected-source changes and verification

No verified tree (`rtl/baseline`, `phase3`, `phase4`, `phase4b`, `phase5b`, `phase6`, `phase8`, `phase9`, `phase10`) was edited. The Phase 11 core copies in `rtl/phase11/core/` preserve module names, interfaces, datapath expressions, coefficients, thresholds, and window semantics; `scripts/phase11/import_sync_core.py` documents the sole mechanical change: 19 asynchronous-reset sensitivity lists become synchronous clocked resets. The board wrapper's BRAM address counters also reset synchronously, and BRAM arrays are never physically reset. This addresses the inherited REQP-1839/1840 unsafe asynchronous-control findings. A two-frame Phase 10 model regression of the copied core passed **614,400 edge pixels and 600 block thresholds with zero mismatches/unknowns** (`reports/phase11/core_xsim.log`).

The final wrapper was simulated with monkey, black, vertical step, and checkerboard inputs. Each had **307,200 valid input pixels, 307,200 valid output pixels, 38,400 packed output bytes, zero byte/bit mismatches against the independently generated Python model, and zero unknown outputs** (`reports/phase11/wrapper_*_xsim.log`). The accelerated-UART test emitted all **38,426 packet bytes**; the host decoder validated CRC32 `1c5111bc` and all 307,200 monkey edges (`results/phase11/sim_uart_packet.bin`). An offline protocol test also rejected a corrupted payload (`host/phase11/test_protocol.py`). These are **simulation** results, not physical captures.

The wrapper's simulated first valid output was 21,902 cycles after first valid input. Its first-valid-input-to-last-valid-output processing interval was **339,885 clock cycles**, or **3.39885 ms at an assumed 100 MHz**. The one-engine continuous core's previously tested frame-start cadence was 318,968 cycles, giving an analytical **313.51 frames/s core-cadence estimate**, not a measured camera or board FPS. A full UART packet needs about **3.3354 s analytically** at the nominal divider; this is neither part of processing time nor a physical transfer measurement.

## Board constraints, implementation, and DRC

`constraints/phase11/nexys_a7_100t_board.xdc` assigns only used ports: E3 100 MHz clock; C12 reset; N17 start; J15/L16/M13 selector; D4 USB-UART transmit; H17/K15/J13/N14 LEDs, all LVCMOS33. The pin map is transcribed from [Digilent's Nexys A7-100T master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc); Digilent's [board schematic](https://digilent.com/reference/_media/reference/programmable-logic/nexys-a7/nexys-a7-sch.pdf) and 3.3 V configuration-bank usage support `CFGBVS=VCCO`, `CONFIG_VOLTAGE=3.3`. No unconstrained used I/O remains.

The final `rev3` project Tcl targets `xc7a100tcsg324-1` and passed synthesis and routing at **10.000 ns**: synthesis WNS **+1.850 ns**, TNS 0; post-route WNS **+0.436 ns**, TNS 0 (`reports/phase11/phase11_rev3_timing_*.rpt`). Both synthesis and route DRC reports show **zero findings**. The independent bitstream gate reran routed timing/DRC and reported zero DRC errors before `write_bitstream`. Prior diagnostic rev1/rev2 builds retained REQP/CFGBVS findings; they are not the production bitstream. The final bitstream is `results/phase11/canny_nexys_a7.bit`, SHA-256 `c8e04b06d54fa59b0cda3ac7c219da78766021f0e91fa43d4c7b85b5e5d9513d`, and routed checkpoint is `results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp`. Both are generated locally and ignored by Git, reproducible by the batch scripts. No physical board operation is inferred from their existence.

## Final resource and power results

Resources below are **synthesis** counts for consistency; WNS is **post-route**. LUTRAM is a subset of LUTs, not additive. The final wrapper row includes image ROM and output frame RAM and must not be compared as pure algorithm-core area. `results/phase11/final_benchmarks.csv` holds the machine-readable table.

| Design | LUT | FF | LUTRAM | RAMB18eq | DSP | Routed WNS |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Phase 6 global thresholds | 1,670 | 1,861 | — | 8 | 0 | +0.792 ns |
| Phase 9 adaptive E=1 | 3,824 | 3,055 | 645 | 52 | 0 | +0.947 ns |
| Phase 10 adaptive E=1 | 3,834 | 3,059 | 645 | 52 | 0 | +0.960 ns |
| Phase 10 adaptive E=2 | 6,058 | 4,252 | 1,285 | 96 | 0 | +0.675 ns |
| Phase 10 adaptive E=4 | 10,299 | 6,627 | 2,565 | 184 | 0 | +0.644 ns |
| **Phase 11 board wrapper** | **4,063** | **3,299** | **644** | **244** | **0** | **+0.436 ns** |

The final wrapper specifically uses **8 RAMB18 and 118 RAMB36**, i.e. `8+2×118=244` of Vivado's **270 RAMB18-equivalent** XC7A100T capacity (**90.37%**). Routed fabric counts are 3,965 LUT and 3,299 FF. The input/output frame stores account for the large BRAM increase over the 52-equivalent algorithm core; high BRAM occupancy limits future wrapper expansion even though E=1 logic is modest.

The Vivado **post-route vectorless estimate** is static **0.103 W**, dynamic **0.101 W**, total **0.204 W** (`reports/phase11/phase11_rev3_power_vectorless.rpt`). Vivado labels confidence **Low** because I/O and internal activity are insufficiently specified. An all-signal XSim SAIF attempt was aborted after excessive runtime and produced no usable activity file, so there is no workload-annotated power claim. **Physical board power was not measured.**

## Quality and scientific claim boundary

Phase 9's ten-image 32×32/32-bin aggregate agreement with the exact **per-block 2,048-level histogram** oracle was F1 **0.7900**, with **43,256** different pixels; aggregate mean absolute HIGH error was **5.625** including empty/simple blocks, while the earlier random-plus-monkey subset mean was **26.42**, maximum **63**. These measure reduced-bin approximation, **not** ground-truth edge quality. Phase 7's full recursive 8-connected hysteresis remains a separate software connectivity reference; the hardware intentionally uses one-pass local weak-edge promotion (`reports/PHASE7_HYSTERESIS_DECISION.md`). There is no claim of textbook/OpenCV equivalence, new Gaussian/Sobel/CORDIC invention, Xu-style 32 independent Canny pipelines, four-pixel/clock throughput, or 4× scaling.

Supported conclusion: a bit-accurate, synchronous-reset **E=1 block-adaptive thresholding core** with 32×32 blocks and 32 bins fits and routes on XC7A100T at 100 MHz, and a self-contained Nexys A7 bitstream/serial validation wrapper is ready. Replicating adaptive engines alone did not increase simulated end-to-end cadence under this one-pixel/clock interface. **Physical board correctness, measured FPS, and measured power remain unverified until an actual Nexys A7 is connected, programmed, and its UART payload numerically compared.**
