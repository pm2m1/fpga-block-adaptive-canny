# Phase 3 active synthesis hierarchy

Vivado 2026.1 batch checks in `reports/phase3_synth.log:47-49,518,541,566` confirm part `xc7a100tcsg324-1`, top `canny_edge_detect_gaussian_top`, and synthesis completion. `reports/phase3_utilization_hierarchical.rpt:25-44` proves which modules survive synthesis. The testbench RGB converter is not in `sources_1`; `VIP_RGB888_YCbCr444.v` was listed as a baseline source but its module is not reachable from this grayscale-input top.

```text
canny_edge_detect_gaussian_top                 rtl/phase3/canny_edge_detect_gaussian_top.v:4
├── u_gaussian: image_gaussian_filter         rtl/phase3/canny_edge_detect_gaussian_top.v:21
│   └── u_matrix_generate_3x3                 rtl/baseline/vip_gaussian_filter.v:44-47
│       └── u_one_column_ram                  rtl/baseline/matrix_generate_3x3.v:51-54
│           └── two fifo_ram line buffers     rtl/baseline/one_column_ram.v:33-53
└── u_canny_core: canny_edge_detect_top       rtl/phase3/canny_edge_detect_gaussian_top.v:32
    ├── canny_get_grandient                   rtl/baseline/canny_edge_detect_top.v:30-33
    │   ├── matrix_generate_3x3 / line RAM   rtl/baseline/canny_get_grandient.v:68-71
    │   └── cordic_sqrt                       rtl/baseline/canny_get_grandient.v:170-174
    │       └── cordic_pipline                rtl/baseline/cordic_sqrt.v:42-57
    ├── canny_nonLocalMaxValue                rtl/baseline/canny_edge_detect_top.v:48
    │   └── matrix_generate_3x3 / line RAM   rtl/baseline/canny_nonLocalMaxValue.v:36-39
    └── canny_doubleThreshold                 rtl/baseline/canny_edge_detect_top.v:66-69
        └── matrix_generate_3x3 / line RAM   rtl/baseline/canny_doubleThreshold.v:37-40
```

The hierarchical utilization report retains `u_gaussian` as `image_gaussian_filter` (line 41), including its 3×3 matrix/column RAM (lines 42-44), and all three Canny stages (lines 27-40). `fifo_ram` instances are absorbed into inferred RAM primitives rather than named in that summary: `reports/phase3_synth_runme.log:256-263` lists eight RAMB18E1 arrays, including **two new 640×8 Gaussian line buffers**. The CORDIC wrapper and at least one named pipeline instance survive (hierarchy lines 36-37); this does not resolve the later CORDIC numerical/tap audit.

`VIP_RGB888_YCbCr444` is **not reachable**: the new top receives 8-bit `per_img_y` directly (`rtl/phase3/canny_edge_detect_gaussian_top.v:10`) and instantiates only the Gaussian and baseline Canny core. RGB conversion in `tb/phase3/tb_phase3_equivalence.sv` is stimulus generation, not synthesis logic. The Phase 3 change is only the placement of the pre-existing Gaussian within the synthesizeable hierarchy.
