"""Prove the Phase 11 core copy differs only in reset sensitivity lists."""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
pairs = [
    ('rtl/baseline/fifo_ram.v', 'fifo_ram.v'),
    ('rtl/baseline/one_column_ram.v', 'one_column_ram.v'),
    ('rtl/phase5b/matrix_generate_3x3_phase5b.v', 'matrix_generate_3x3_phase5b.v'),
    ('rtl/phase5b/vip_gaussian_filter_phase5b.v', 'vip_gaussian_filter_phase5b.v'),
    ('rtl/phase5b/canny_doubleThreshold_phase5b.v', 'canny_doubleThreshold_phase5b.v'),
    ('rtl/phase4b/cordic_gradient_phase4b.v', 'cordic_gradient_phase4b.v'),
    ('rtl/phase8/canny_gradient_raw_phase8.v', 'canny_gradient_raw_phase8.v'),
    ('rtl/phase8/canny_nms_magnitude_phase8.v', 'canny_nms_magnitude_phase8.v'),
    ('rtl/phase9/histogram_unit_phase9.v', 'histogram_unit_phase9.v'),
    ('rtl/phase9/adaptive_threshold_step_phase9.v', 'adaptive_threshold_step_phase9.v'),
    ('rtl/phase10/block_adaptive_engine_phase10.v', 'block_adaptive_engine_phase10.v'),
    ('rtl/phase10/canny_block_adaptive_phase10_top.v', 'canny_block_adaptive_phase10_top.v'),
]
pattern = re.compile(rb'@\s*\(\s*posedge\s+clk\s+or\s+negedge\s+(rst_n|rst_s)\s*\)')
changes = 0
for source, name in pairs:
    original = (root / source).read_bytes()
    expected, count = pattern.subn(b'@(posedge clk)', original)
    actual = (root / 'rtl/phase11/core' / name).read_bytes()
    assert actual == expected, f'unexpected difference in {name}'
    changes += count
assert changes == 19, changes
print(f'PHASE11_SYNC_COPY_PASS modules={len(pairs)} reset_sensitivity_changes={changes} other_byte_changes=0')
