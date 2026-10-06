# Single-engine BRAM ownership and Phase 10 replication estimate

The A100T synthesis reports for all six configurations measured **8 RAMB18E1** in inherited full-frame Gaussian/gradient/NMS/local-promotion line buffers, plus **22 RAMB36E1** in the two 32-row stripe banks or **66 RAMB36E1** in the three 64-row stripe banks. The 8/16/32-bin histograms infer LUTRAM, not BRAM, so bin count does not change stripe BRAM geometry.

Vivado's `xc7a100tcsg324-1` utilization table reports 135 RAMB36 tiles / 270 RAMB18 equivalents. Measured one-engine totals are 52 equivalents (19.26%) for 32-row blocks and 140 equivalents (51.85%) for 64-row blocks. Per adaptive engine, stripe storage is 44 or 132 equivalents respectively. The 8 line-buffer RAMB18s are the *shared full-frame front-end and final window* in the envisaged Phase 10 design, not 8 per engine.

| Block geometry | Shared line-buffer RAMB18eq | Stripe RAMB18eq per engine | 1-engine estimate | 2-engine estimate | 4-engine estimate |
| --- | ---: | ---: | ---: | ---: | ---: |
| 32×32 | 8 | 44 | 52 (19.26%) | 96 (35.56%) | 184 (68.15%) |
| 64×64 | 8 | 132 | 140 (51.85%) | 272 (100.74%; exceeds part) | 536 (198.52%; exceeds part) |

These are architectural **BRAM-only replication estimates**, not implemented 2- or 4-engine designs. They omit any extra input/output queues, banking, scheduler, or merger storage and do not establish throughput scaling. If later engines also duplicate any part of the front-end or use different memory mapping, actual usage will increase. The 64-row two-bank shortcut would reduce memory but is invalid for the tested no-backpressure frame cadence: its first next-frame stripe overwrites a bank still being replayed, as shown in `SCHEDULE_ANALYSIS.md`. The correct three-bank 64-row mapping is therefore the estimate to use.
