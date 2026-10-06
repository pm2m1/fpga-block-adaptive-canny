# Phase 11V — no-board implementation validation

Status: PARTIAL / INVESTIGATION REQUIRED. The SDF timing simulation reported BRAM hold violations; Phase 11V is **not** an all-tests-PASS checkpoint. This report must not be read as physical FPGA validation.

## Scope and preserved baseline

Physical Nexys A7-100T hardware was unavailable because of project cost. The verified Phase 11 RTL, XDC, Vivado project, routed checkpoint and bitstream were not functionally modified. The source checkpoint is Git `3b960d1`. Phase 11V work is isolated under `tb/phase11v`, `scripts/phase11v`, `results/phase11v`, and `reports/phase11v` (plus this report). The selected algorithm is one engine, 32×32 blocks, 32 uniform histogram bins, one-pass local weak-edge promotion. It is not recursive Canny hysteresis.

## Verification methodology and current results

| Check | Status | Evidence / limitation |
| --- | --- | --- |
| Python golden model and core RTL | PASS in Phase 10/11 | 614,400 pixels, 600 block thresholds, zero mismatches; see `reports/PHASE10_MULTI_ENGINE_SCALING.md` and `reports/PHASE11_FINAL_FPGA_VALIDATION.md`. |
| RTL board wrapper | PASS, rerun in Phase 11V | Monkey, 307,200 input/output pixels, 38,400 packed bytes, zero mismatches/unknowns; `reports/phase11v/cycle_xsim.log`. Phase 11 also tested black, vertical step and checkerboard. |
| Independent cycle-counter check | PASS | Testbench first input clock 100, first output 22,002, last output 339,984: `339984−100+1=339885` processing cycles; first-output latency 21,902 cycles. `tb/phase11v/tb_cycle_counter.sv`, `reports/phase11v/cycle_xsim.log`. Clock indices are testbench-local, not physical measurements. |
| Post-synthesis functional simulation | PARTIAL: directed PASS | Exported and compiled/elaborated from the actual synthesis checkpoint. The 2,100-output-pixel monkey diagnostic found zero mismatches; 23,141 input-ROM samples also matched. XSim took 2 min 8 s. A complete post-synthesis frame was stopped after excessive runtime, so full-frame equality is not claimed. See `reports/phase11v/post_synth_full_attempt_xsim.log` and `reports/phase11v/post_synth_func_xsim.log`. |
| Post-route functional simulation | PASS | Actual routed checkpoint exported to `results/phase11v/post_route_func.v`. The corrected testbench compared the complete monkey frame: 307,200 output pixels and 307,200 input-ROM samples, zero mismatches and zero unknown outputs. XSim runtime 24 min 31 s; `reports/phase11v/post_route_func_xsim.log`. |
| Post-route SDF timing simulation | FAIL / unresolved | Routed slow-corner SDF backannotation succeeded, but XSim reported repeated RAMB36E1 address hold violations before any output pixels were available. The directed run was stopped after roughly 7.8 microseconds of simulated time to avoid an unbounded diagnostic flood. No SDF image result is claimed. See `reports/phase11v/post_route_timesim_xelab.log` and `reports/phase11v/post_route_timesim_xsim.log`. Static timing remains the authoritative frequency-closure test, but this discrepancy needs investigation before claiming SDF validation. |
| Static timing at 100 MHz | PASS for constrained paths | WNS +0.436 ns, TNS 0; WHS +0.034 ns, THS 0. See `reports/phase11v/timing_summary.rpt`. |
| Final routed DRC | PASS | Zero findings; `reports/phase11v/drc.rpt`. |
| Bitstream generation | PASS in Phase 11 | 3,826,006 bytes; SHA-256 `c8e04b06d54fa59b0cda3ac7c219da78766021f0e91fa43d4c7b85b5e5d9513d`; `reports/phase11v/bitstream_identity.txt`. A clean Phase 11V rebuild was not performed. |
| Simulated UART readback | PASS, rerun in Phase 11V | 38,426-byte packet, valid CRC `1c5111bc`, 307,200 reconstructed pixels, zero golden-model mismatches; `results/phase11v/sim_uart_packet.bin`, `reports/phase11v/cycle_xsim.log`. |
| Host corruption rejection | PASS | Seven malformed-packet cases rejected by `scripts/phase11v/test_uart_errors.py`. |
| Vivado power estimate | AVAILABLE, LOW CONFIDENCE | Reused Phase 11 routed vectorless report as `reports/phase11v/phase11v_power.rpt`; no representative matched SAIF. |
| Physical FPGA programming | NOT PERFORMED | Board unavailable. |
| Physical UART capture | NOT PERFORMED | Board unavailable. |
| Physical power measurement | NOT PERFORMED | No board or instrument. |

## Clock, reset, timing and CDC audit

The first gate-level probe reported a one-pixel output shift because it counted the counter's start-event initialization enable as if it were an image pixel. The exported netlist's `u_core_n_4` drives the pixel-counter clock enable for **both** start initialization and output-valid increments. Filtering that enable until `input_seen` is true removed the offset: the corrected 2,100-pixel directed diagnostic had zero output mismatches and zero input-ROM mismatches over 23,141 source pixels, followed by a clean complete-frame routed-functional run. The post-synthesis directed diagnostic independently matched the same 2,100 outputs and 23,141 inputs. The failed routed probe logs are retained as `reports/phase11v/post_route_full_attempt_xsim.log`, `post_route_posedge_diagnostic.log`, and `post_route_negedge_diagnostic.log`; the corrected short result is `post_route_probe_corrected_diagnostic.log`. This was a **testbench correction only**; no algorithm or production RTL was changed.

The XDC defines the physical clock input `clk100mhz` at E3 with a 10.000 ns period. Vivado reports one `sys_clk_pin` clock and one BUFGCTRL, with no PLL/MMCM or generated clock (`reports/phase11v/timing_summary.rpt`, `reports/phase11v/clock_utilization.rpt`). `rtl/phase11/canny_nexys_a7_phase11_top.v` samples active-low reset into `reset_pipe` and start into `start_pipe` on that clock; the core runs from the same clock. `reports/phase11v/timing_exceptions.rpt` lists no false-path or multicycle exceptions. The routed timing report shows zero `no_clock`, zero `unconstrained_internal_endpoints`, and no timing-loop findings. The worst setup path runs inside adaptive threshold extraction, from `u_core/g_engine[0].u_engine/scan_first_pipe_reg/C` to `.../block_high_reg[1][0][6]/CE`: 9.101 ns data path, 10 logic levels, 3.858 ns logic and 5.243 ns route; `reports/phase11v/top10_setup.rpt`. The worst hold slack is +0.034 ns; `reports/phase11v/top10_hold.rpt`. Clock uncertainty is 0.035 ns.

**External-interface caveat:** `check_timing` reports five inputs without input delay and five outputs without output delay. These are board controls and LED/UART outputs. Thus there are zero unconstrained *internal* endpoints, but the board-interface delay budget is not modeled. `report_cdc` also says ports lacking input-delay constraints are skipped; its empty result is not proof that every asynchronous control transition is risk-free. No exception was added to conceal this.

Vivado's methodology section also lists 78 `SYNTH-6` RAM-timing suboptimality warnings and ten `TIMING-18` missing input/output-delay warnings. These are not DRC violations and do not negate the reported constrained-path WNS, but they limit the strength of a board-interface timing claim. They were not suppressed.

### SDF discrepancy requiring follow-up

`write_verilog -mode timesim -sdf_anno true` and `write_sdf -process_corner slow` were applied to the same routed checkpoint. XSim elaborated the timing netlist against `simprims_ver` and explicitly reported successful SDF backannotation. The 10.000 ns directed test then logged 5,920 `$hold` diagnostic lines (no `$setup` diagnostic lines) and 5,120 RAM model corruption warnings before interruption near 7.8 microseconds. An example is `u_core/g_engine[0].u_engine/g_bank[0].stripe_reg_0_0` on `ADDRARDADDR[0]` relative to `CLKARDCLK`: the RAM model reported a 339 ps hold interval against a 360 ps limit. These repeated lines are not 5,920 independent endpoint failures. Because routed STA reports WHS +0.034 ns / THS 0 and DRC zero, the cause of the simulation/STA discrepancy is **not established**. It may involve SDF/primitive timing-check interpretation, but this report does not dismiss it as harmless or alter design/timing exceptions. The timing simulation did not reach the first edge pixel and is a failed Phase 11V validation item.

## XDC and DRC audit

The eleven used ports are checked by `scripts/phase11v/verify_xdc.py` against Digilent's [Nexys A7-100T master XDC](https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc). All use LVCMOS33. The actual project file is `constraints/phase11/nexys_a7_100t_board.xdc`.

| Port | Pin | Board function |
| --- | --- | --- |
| `clk100mhz` | E3 | 100 MHz oscillator |
| `cpu_resetn` | C12 | CPU reset button |
| `start_btn` | N17 | Center button |
| `test_sel[0..2]` | J15, L16, M13 | Switches 0–2 |
| `uart_tx_o` | D4 | FPGA TX to USB-UART host RX |
| `led[0..3]` | H17, K15, J13, N14 | LEDs 0–3 |

The XDC specifies `CFGBVS=VCCO` and `CONFIG_VOLTAGE=3.3`; used pins are assigned, with no UCIO/NSTD or CFGBVS findings. Routed DRC has zero findings. No physical signal-integrity claim follows.

## Memory utilization

Actual routed hierarchy (`reports/phase11v/utilization_hierarchical.rpt`) uses 8 RAMB18 and 118 RAMB36 = 244 RAMB18-equivalents, or 90.37% of the XC7A100T's 270 equivalents. Vivado cell-name audit (`reports/phase11v/bram_cells.txt`) separates 80 RAMB36 for the input image ROM (160 equivalents), 16 RAMB36 for the packed output edge buffer (32 equivalents), and 22 RAMB36 plus 8 RAMB18 for the Canny core (52 equivalents). Therefore the *board-demo storage* adds 192 equivalents; the pure adaptive algorithm is not a 244-equivalent design. The hierarchy report attributes the 22 RAMB36 and 8 RAMB18 to `u_core` and its descendants.

## UART and cycle interpretation

The Phase 11V simulation serialized the board-wrapper output at testbench-accelerated `UART_DIV=2`; it did **not** communicate with a physical UART. `host/phase11/capture_board_output.py` decoded sync `CNY1`, version 1, 640×480, monkey test ID, 339,885 processing cycles, 38,400 packed payload bytes, 307,200 pixels, and CRC `1c5111bc`. The simulated bytes match the Python golden output exactly. At the implemented 100 MHz clock, `339885/100000000 = 3.39885 ms` is an **analytical processing time derived from a simulated hardware counter**. The separate nominal physical-UART transfer estimate at divider 868 is `38426×10×868/100000000 = 3.335377 s`; it is not processing latency and was not measured on hardware. The Phase 10 318,968-cycle core cadence corresponds analytically to 313.511 frames/s at 100 MHz, but the Phase 11 wrapper is single-shot and no board FPS was measured.

## Power analysis

The available Vivado *post-route vectorless estimate* is device static 0.103 W, dynamic 0.101 W, total on-chip 0.204 W, **Low** confidence (`reports/phase11v/phase11v_power.rpt`). Dynamic categories: clocks 0.018 W, slice logic 0.011 W, signals 0.012 W, BRAM 0.059 W, I/O 0.001 W (rounding applies). The report explicitly says no simulation activity file was matched. The earlier full-signal SAIF attempt was prohibitively slow; no credible image-activity SAIF was produced in Phase 11V. Thus this estimate was **not** improved to realistic-activity confidence and is not measured board power.

## Bitstream and reproducibility

The existing Phase 11 bitstream `results/phase11/canny_nexys_a7.bit` and routed checkpoint were verified present and hashed in Phase 11V. `scripts/phase11/create_and_route.tcl` and `scripts/phase11/README.md` remain the original build recipe. Phase 11V re-opened the actual synthesis and routed checkpoints read-only, exported simulation netlists and SDF, and reran timing, clock, DRC and hierarchy reports via `scripts/phase11v/export_and_audit.tcl`. It did not rerun synthesis, placement, route or bitstream generation in a clean generated project. A different future bitstream hash would not alone imply functional difference.

## Final claim boundary

Supported: the design was synthesized, placed and routed for `xc7a100tcsg324-1` and met the 100 MHz **constrained internal-path** timing requirement; a Nexys A7-100T bitstream was generated; the wrapper and UART packet were verified in RTL simulation against the bit-accurate software reference; routed DRC is clear. Subject to the completion status above, netlist simulation evidence must be stated separately. The board was not available, programmed, observed over UART, or power-measured. No claim of measured 313 FPS, 0.204 W board power, recursive hardware hysteresis, or physical board validation is supported.

Earlier controlled experiments support a narrower research conclusion: Phase 9's 32×32/32-bin configuration achieved F1 0.7900 against the exact per-block histogram **quantization reference**, not against a scene-segmentation ground truth; Phase 10's one-, two-, and four-engine versions had identical measured simulation frame-start cadence of 318,968 cycles while replication increased resource use. This supports E=1 for the current one-pixel-per-clock shared interface. These results do not establish physical throughput. The full recursive 8-connected hysteresis output remains a Phase 7 software quality reference; hardware still uses one-pass local weak-edge promotion.
