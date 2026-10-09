# Phase 11V post-route SDF investigation

Final status: **UNRESOLVED**. Production RTL, the 10 ns clock, constraints, timing exceptions, and timing-check settings were not changed. No warning was suppressed. No physical board was used.

## Artifact and annotation audit

The current clone contains `results/phase11/canny_nexys_a7_phase11_rev3_routed.dcp` (4,121,141 bytes; SHA-256 `721bff438d9cc2c30664244950843dda8a8ce1f061cf37ca15199fa2d06d5798`). The existing export flow opened it and generated the slow-corner SDF and timing netlist together. The diagnostic flow generated a fast-corner SDF and timing netlist from that same checkpoint. Vivado reported part `xc7a100tcsg324-1`. XSim reported successful SDF annotation to the intended `dut` hierarchy in both cases and no annotation warnings/errors; it did not give an arc-by-arc coverage count. Separately generated helper-module names differ, so the two netlist text files are not byte-identical.

The older `reports/phase11v/bitstream_identity.txt` lists a 4,113,980-byte checkpoint and a bitstream SHA-256 starting `c8e04b06`; the current ignored local files are a 4,121,141-byte checkpoint and a same-size bitstream with SHA-256 starting `95c86a08`. The **current SDF and netlist are traceable to the local checkpoint**, but their linkage to that older bitstream identity record is not established. No bitstream was regenerated.

The identity record was committed in `f603a8f` (2026-10-06). The local ignored checkpoint was last written 2026-10-07 03:09:30; its SHA-256 is `721bff438d9cc2c30664244950843dda8a8ce1f061cf37ca15199fa2d06d5798`. The local bitstream was last written 2026-10-07 03:20:03; its SHA-256 is `95c86a088646865cd0511fc1fe74add9906a648adb460ca1a88d5683d11d86df`. The historical record lists bitstream SHA-256 `c8e04b06d54fa59b0cda3ac7c219da78766021f0e91fa43d4c7b85b5e5d9513d`. Thus the current local files postdate and differ from the recorded historical identity. This investigation does not establish why they were regenerated; it neither overwrites the historical hashes nor claims the current SDF corresponds to the historical bitstream.

## First warning and timeline

The first ten distinct warnings, including complete XSim text, are in [`sdf_debug/first_10_warnings.tsv`](sdf_debug/first_10_warnings.tsv). The first is `RAMB36E1` instance `tb_netlist_timing/dut/u_core/g_engine[0].u_engine/g_bank[0].stripe_reg_0_0`, `ADDRARDADDR[0]` against `CLKARDCLK`, `$setuphold` reporting a **hold** violation at **1,390,667 ps**. XSim gives reference event 1,390,328 ps and data event 1,390,667 ps: 339 ps observed against a 360 ps slow-corner SDF hold limit. The first eight unique instances fire at 1,390,667 ps; the next two entries are the opposite address transition at 1,400,667 ps. All ten are in the bank-0 stripe BRAM family. The 1.5 µs slow/MAX reproduction produced 96 timing-warning lines. A separate interrupted slow/MAX run reached 5.110667 µs and logged 3,440 hold-warning lines. Neither reached a checked output pixel.

| Original timing-bench event | Time |
| --- | ---: |
| Clock period | 10 ns; rising edges at 5 + 10n ns |
| Reset release, falling edge | 120 ns |
| Start assertion, falling edge | 240 ns |
| Start release, falling edge | 290 ns |
| First stripe-BRAM warning | 1,390.667 ns |
| First valid output | Not observed in tested SDF runs |

The original timing bench already changes reset/start on falling edges. The warning is post-start BRAM activity, not a time-zero or reset-edge event. External image pixels are not driven by the testbench; the wrapper generates them internally.

The first enabled BRAM address activity **observed in the available warning trace** is 1,390.667 ns. No pin waveform was captured to prove that this is the very first BRAM activity. Likewise, the timing netlist produced no first active input/output event in the diagnostic interval; these events are recorded as *not observed*, not assigned an estimated time.

## Corner comparison and routed STA

The original flow writes a **slow-process SDF** and annotates **MAXIMUM**. Its address hold check is 360 ps. The diagnostic writes a **fast-process SDF** from the same checkpoint and annotates **MINIMUM**; that hold check is 183 ps. [AMD's Vivado 2026.1 simulation guide](https://docs.amd.com/r/en-US/ug900-vivado-logic-simulation/Running-Timing-Simulation) recommends slow/MAX for setup and fast/MIN for hold. Thus the original slow/MAX warning and routed fast-corner STA hold slack are **not a like-for-like comparison**. AMD also describes all four corner/column combinations for broader coverage; the original warnings remain documented, not waived.

Path-specific routed STA from the local checkpoint gives:

| Endpoint | Fast hold slack | Slow hold slack | Fast setup slack |
| --- | ---: | ---: | ---: |
| `g_bank[0].stripe_reg_0_0/ADDRARDADDR[0]` | +0.505 ns | +1.189 ns | In diagnostic setup report |
| `g_bank[1].stripe_reg_0_0/ADDRARDADDR[0]` | +0.442 ns | Not queried | +7.560 ns |

The bank-0 source is `fill_x_reg[0]/C`, the destination is the flagged `RAMB36E1/ADDRARDADDR[0]`, and STA checks its `CLKARDCLK` relationship. Design-wide routed STA remains WNS +0.436 ns, TNS 0, WHS +0.034 ns, THS 0, zero failing endpoints and no unconstrained internal endpoints. External I/O delays are not modeled, which is separate from this internal path.

## Experiments and conclusion

| Experiment | Result |
| --- | --- |
| Slow/MAX SDF, original bench, 1.5 µs | 96 BRAM hold-warning lines; no output yet |
| Fast/MIN SDF, original bench, 1.5 µs | Successful annotation, zero timing warnings; no output yet |
| Fast/MIN SDF, original bench, 250.29 µs | Zero timing warnings, but `valid_samples=0`; output check failed |
| Fast/MIN diagnostic bench, reset held until 600 ns; start at 800 ns | Still no input-valid by 10 µs; safe-phase longer reset did not cure startup |
| Fast/MIN diagnostic counter probe | Upper `pre_count` bits first became `X` at 1.080 µs, with no accompanying fast/MIN warning; stream remained inactive |

Fast/MIN removes the observed BRAM warnings **without disabling checks**, but the timing netlist still produces no useful checked output. The first counter-fanin X has now been localized to an SDF-annotated carry-decode LUT; its intra-primitive mechanism is not proven. It would be unsound to call SDF simulation PASS or declare the slow/MAX warnings conclusively benign/vendor-only. The evidence does not justify an RTL edit.

## Counter-X continuation: same timing netlist with and without SDF

I used the same diagnostic testbench, `simprims_ver` timing primitives, and `-transport_int_delays -pulse_r 0 -pulse_int_r 0` elaboration options in both runs. The no-SDF file is a generated copy of `post_route_fast_timesim.v` with **only its one `$sdf_annotate` call replaced by a comment**; it is diagnostic, not a timing-validation run. The fast/MIN run annotated `post_route_fast.sdf` successfully to `tb_netlist_timing_debug/dut`, with no annotation warnings. Both netlists derive from the local routed checkpoint, part `xc7a100tcsg324-1`.

The waveform window is 700–1290 ns: 206.825 ns before the earliest LUT X and 383.175 ns afterward; it also brackets the bit-5 Q X at 1076.648 ns. Raw waveforms are generated/ignored `precount_fast_min_700_1290.vcd` and `precount_no_sdf_700_1290.vcd`; selected transitions are preserved in [`sdf_debug/precount_waveform_evidence.tsv`](sdf_debug/precount_waveform_evidence.tsv). These VCD transitions are not output-pixel counts.

| Event | Fast/MIN time | No-SDF comparison |
| --- | ---: | --- |
| First X in inspected pre-count fan-in: `u_uart_n_9` | 906.825 ns | No counter/control X in 700–1290 ns window |
| Same signal re-enters X with counter bit 4 high | 1066.825 ns | Remains known |
| `pre_count[5]_i_1/O`, the bit-5 D net, enters X | 1067.166 ns | Remains known |
| `pre_count_reg[5]/Q` enters X | 1076.648 ns | Remains known |
| First input-valid | Not observed by 10 µs; original fast/MIN test had none by 250.29 µs | 1645 ns; 812 input-valid samples by 10 µs |
| Checked output pixels | 0 | 0 in the 10 µs diagnostic interval; not a full-frame test |
| Timing warnings in these runs | 0 | 0 |

The earliest captured X in this counter feedback cone is **`u_uart/pre_count[7]_i_5/O`**, exposed as `u_uart_n_9`, at **906.825 ns**. It is a `LUT4` with `INIT=16'h7FFF`, decoding the low four counter bits: `I0=pre_count[2]`, `I1=pre_count[0]`, `I2=pre_count[1]`, `I3=pre_count[3]`. At 906.625 ns the four captured driving register nets are known (`0,0,0,1` in I0–I3 order); the LUT output becomes X 200 ps later. This episode does not corrupt bit 5 while bit 4 is low. At 1066.825 ns the LUT output again becomes X with bit 4 high, then downstream `LUT4 pre_count[5]_i_1/O` becomes X at 1067.166 ns and `FDRE pre_count_reg[5]/Q` becomes X after the next clock. The exact internal LUT/input-pin reason for the persistent X is **unresolved**; an SDF-dependent primitive/interconnect propagation effect is the supported localization, not a proven vendor defect.

The exported bit-5 register is `FDRE pre_count_reg[5]`, `INIT=1'b0`: `C=clk100mhz_IBUF_BUFG`, `CE=pre_count[7]_i_1_n_0`, `D=pre_count[5]_i_1_n_0`, `R=u_gaussian/p_0_in`, `Q=pre_count_reg_n_0_[5]`. In the captured window, GSR is 0, testbench reset and synchronized `rst_n` are 1, `R=0`, `CE=1`, and Q is initially known 0. The same `glbl` has undriven `GWE=Z` in the SDF run, but this is common to the no-SDF setup and did not cause its counter to become X. The testbench reset release at 600 ns, start assertion at 800 ns, and start release at 850 ns all occur on falling clock edges. These observations do not support missing counter initialization, an absent reset, or an external active-edge stimulus race as the first cause.

The SDF contains a `LUT4` delay entry for `u_uart/pre_count[7]_i_5` (`I0`–`I3` to `O`, 45–56 ps, `PATHPULSE=50 ps`) and an `FDRE` entry for `pre_count_reg[5]`. There is no `TIMINGCHECK` on that LUT entry, and XSim logged no fast/MIN timing violation during the short capture. Routed STA on the same checkpoint reports **+0.408 ns fast-corner hold slack** and **+7.614 ns setup slack** to `pre_count_reg[5]/D`; the implicated LUT appears on the setup path. These STA results do not explain the LUT output becoming X in simulation, but they do not indicate a failing counter-register path. See `sdf_debug/precount_bit5_hold.rpt` and `sdf_debug/precount_bit5_setup.rpt`.

An additional diagnostic isolated the counter X to the timing-run **pulse-rejection options**. `xelab -help` reports 100% as the defaults for `-pulse_r` and `-pulse_int_r`; the existing timing flow explicitly sets both to 0%. I elaborated the **same fast/MIN SDF netlist and testbench**, retaining `-transport_int_delays`, but omitting only those two non-default pulse options. The generated/ignored `sdf_debug/precount_fast_min_default_pulse_700_1290.vcd` had no counter/control X; input-valid began at 1645 ns, exactly as in the no-SDF comparison. This is a demonstrated simulation-configuration cause of the startup X, not evidence of an uninitialized hardware counter. The diagnostic does **not** disable timing checks.

However, the default-pulse fast/MIN run then exposed unresolved `RAMB36E1` hold violations once the design reached BRAM activity. The first was at **1,946,617 ps**, `u_core/g_engine[0].u_engine/g_bank[0].stripe_reg_0_0`, `ADDRARDADDR[0]` versus `CLKARDCLK`, `$setuphold`/hold: reference event 1,946,540 ps, data event 1,946,617 ps, 77 ps observed against a 180 ps limit. The 10 µs diagnostic log contains **10,348 timing-violation warning lines**; all are `RAMB36E1` hold warnings, across the stripe-register family (`TChk1340`/`TChk1341`). The model also printed 8,993 `Error: Setup/Hold Violation` detail lines. The raw messages are preserved in ignored `sdf_debug/fast_min_default_pulse_10us.log`; the concise result is [`sdf_debug/default_pulse_diagnostic.tsv`](sdf_debug/default_pulse_diagnostic.tsv). The run had 812 valid input samples and **zero checked output pixels** by 10 µs. No timing warning was suppressed. The earlier 250.29 µs zero-pulse run had no timing warnings only because it never reached useful input/BRAM activity; its zero-warning count cannot be treated as a hold-timing pass.

The minimal *diagnostic* correction is to use XSim's default pulse handling in the SDF flow, which removes the startup X. It does not resolve the BRAM hold-check discrepancy, so no main timing-run script was changed to claim PASS. Production RTL, constraints, clock frequency, and timing checks are unchanged. Extending a run already producing thousands of unresolved hold violations would not establish SDF correctness, so no full-frame SDF claim is made. The passing RTL and post-route functional results remain separate evidence; SDF timing validation remains **UNRESOLVED**.

| Hypothesis | Evidence and present decision |
| --- | --- |
| H1: active-edge testbench race | Against: original and diagnostic reset/start changes occur on falling edges. No external pixel/control update occurs at an active rising edge. |
| H2: reset/start startup race | Against as a complete explanation: extending reset to 600 ns and asserting start at 800 ns did not restore input-valid or prevent the counter X. A finer reset-path/model investigation remains possible. |
| H3: stale/mismatched SDF and netlist | Against for each generated pair: exported together from the same local DCP and annotation succeeded. Separate concern: the local ignored bitstream/checkpoint differs from the older identity record. |
| H4: inferred BRAM initialization/reset model | Not the first counter-X source: the earliest captured X is at a counter carry-decode LUT output, before the first reported BRAM warning. The BRAM hold-warning mechanism remains independently unresolved. |
| H5: vendor primitive/SDF discrepancy | The counter X depends on the explicit zero-pulse-rejection simulator options; default pulse handling removes it. The BRAM hold discrepancy remains unresolved: default-pulse fast/MIN reports violations despite positive routed STA hold slack. This alone does not prove a vendor-model defect. |
| H6: real missed hold path | Not supported by the queried internal path: both bank-0 fast and slow STA hold slacks are positive, and all internal endpoints are constrained. It cannot be dismissed solely from the SDF experiments. |

Post-diagnostic regressions: `verify_sync_core.py` PASS; host protocol test PASS with 307,200 pixels; Phase 11 core regression PASS with 614,400 pixels/600 blocks and zero mismatches; monkey wrapper RTL simulation PASS with 307,200 pixels, zero mismatches/unknowns, and a 38,426-byte simulated UART packet. Prior routed functional simulation, STA, DRC, and bitstream generation remain prior verified results, not new SDF results.

In this continuation, `verify_sync_core.py` and `host/phase11/test_protocol.py` were rerun and passed (the latter reconstructed 307,200 pixels, zero mismatches, and rejected CRC corruption). The core and wrapper regressions above are the prior Phase 11V runs; they were not repeated because no production source, constraint, or normal testbench changed. `git diff --name-only -- rtl constraints scripts/phase11 tb/phase11` is empty. No new functional-regression failure was observed.

Recommended README row: `| Post-route SDF timing simulation | UNRESOLVED: default-pulse fast/MIN removes startup X but reports BRAM hold violations; zero checked output pixels |`.
