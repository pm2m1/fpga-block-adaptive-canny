# Limits of the result

- No physical Nexys A7-100T was available. Programming, physical UART capture, board FPS and physical power measurement were not performed.
- The routed functional netlist matched one complete monkey frame, but the post-route SDF simulation reported repeated BRAM address hold warnings. The discrepancy with positive static hold slack is unresolved; see `reports/phase11v/SDF_HOLD_DISCREPANCY.md`.
- The 100 MHz timing result covers constrained internal paths. Board-control inputs and UART/LED outputs do not have modeled external input/output delays. Routed DRC has zero findings, but this is not a physical signal-integrity test.
- The hardware ends with one-pass local weak-edge promotion, **not** full recursive 8-connected hysteresis. The recursive method is only a software quality reference.
- The shared front end and ordered output each run at one pixel per clock. Two and four adaptive engines increased resources but did not improve the tested frame cadence.
- The exact 2,048-level histogram is a threshold-quantization reference, not labeled scene ground truth. F1 against it does not measure absolute edge-detection accuracy.
- This fixed-point implementation is not claimed to be bit-equivalent to OpenCV, MATLAB, or textbook Canny defaults.
- The Vivado 0.204 W post-route power number is a low-confidence vectorless estimate, not measured board power.
