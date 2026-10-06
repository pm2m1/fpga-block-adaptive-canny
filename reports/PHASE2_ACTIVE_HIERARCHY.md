# Phase 2: active A100T synthesis hierarchy

Vivado 2026.1 created the project from `scripts/create_phase2_a100t_project.tcl`. The batch log `reports/phase2_synth.log` prints `PHASE2_PROJECT_PART=xc7a100tcsg324-1`, `PHASE2_SYNTH_TOP=canny_edge_detect_top`, and the same values after `open_run synth_1`. The synthesized hierarchy is recorded independently in `reports/phase2_utilization_hierarchical.rpt:25-39`. These are synthesis observations, not just project-directory assumptions.

All 11 `rtl/baseline/*.v` files listed in the Tcl were added to `sources_1`; none of the three `tb/baseline/*.sv` files were added. Including a file does **not** make its module reachable. The project `.xpr` is generated in `vivado/phase2_a100t_baseline/` and can be reconstructed by rerunning the Tcl; neither historic `.xpr` was opened or imported.

| Question | Answer | Evidence |
|---|---|---|
| Synthesis top `canny_edge_detect_top`? | **Yes** | Batch part/top checks; hierarchy report line 25; `rtl/baseline/canny_edge_detect_top.v:1`. |
| Part exactly `xc7a100tcsg324-1`? | **Yes** | Batch checks before and after synthesis; utilization report device header. |
| `canny_get_grandient` present? | **Yes** | Top instantiation `rtl/baseline/canny_edge_detect_top.v:30-33`; hierarchy report line 33. |
| `cordic_sqrt` present? | **Yes** | `rtl/baseline/canny_get_grandient.v:170-174`; hierarchy report line 35. |
| `cordic_pipline` present? | **Yes** | `rtl/baseline/cordic_sqrt.v:42-57`; hierarchy report line 36 retains an instance. Other RTL stage instances may be optimized/flattened; the hierarchy report alone does not prove all 16 survive independently. |
| `canny_nonLocalMaxValue` present? | **Yes** | Top instantiation `rtl/baseline/canny_edge_detect_top.v:48`; hierarchy report line 27. |
| `canny_doubleThreshold` present? | **Yes** | Top instantiation `rtl/baseline/canny_edge_detect_top.v:66-69`; hierarchy report line 32. |
| `matrix_generate_3x3` present? | **Yes** | Instantiated at `rtl/baseline/canny_get_grandient.v:68-71`, `canny_nonLocalMaxValue.v:36-39`, and `canny_doubleThreshold.v:37-40`; hierarchy report lines 28, 37. |
| Line buffers present? | **Yes** | `rtl/baseline/matrix_generate_3x3.v:51-54` instantiates `one_column_ram`; `rtl/baseline/one_column_ram.v:33-53` instantiates `fifo_ram`. Hierarchy report retains `one_column_ram`; synthesis log `reports/phase2_synth_runme.log:250-255` maps six `fifo_buffer_reg` arrays to RAMB18E1. `fifo_ram` hierarchy is absorbed into RAM primitives, not absent from the datapath. |
| `image_gaussian_filter` reachable? | **No** | Its file `vip_gaussian_filter.v` is in `sources_1`, but the top's only direct instances are gradient, NMS, threshold (`rtl/baseline/canny_edge_detect_top.v:30-69`), and no Gaussian instance appears in `reports/phase2_utilization_hierarchical.rpt:25-39`. |
| `VIP_RGB888_YCbCr444` reachable? | **No** | Its file is in `sources_1`, but it is not instantiated below the top or listed in the synthesized hierarchy. The top takes 8-bit grayscale `per_img_y` directly (`rtl/baseline/canny_edge_detect_top.v:12`). |

Active RTL path: grayscale input → `canny_get_grandient` (3×3 matrix/line buffers and `cordic_sqrt`/`cordic_pipline`) → `canny_nonLocalMaxValue` (3×3 matrix/line buffers) → `canny_doubleThreshold` (3×3 matrix/line buffers) → one-bit output. The six inferred RAMB18E1 line buffers are 2 × (640×8), 2 × (640×16), and 2 × (640×2) in `reports/phase2_synth_runme.log:250-255`. This is the conventional streaming core only; the Gaussian and RGB modules are project-listed but unused in this synthesis top.
