"""Copy verified E=1 core into Phase 11 and change reset sensitivity only.

This intentionally preserves module names/interfaces and every datapath
expression. It refuses to overwrite an existing Phase 11 copy.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
target = root / 'rtl/phase11/core'
sources = [
    'rtl/baseline/fifo_ram.v',
    'rtl/baseline/one_column_ram.v',
    'rtl/phase5b/matrix_generate_3x3_phase5b.v',
    'rtl/phase5b/vip_gaussian_filter_phase5b.v',
    'rtl/phase5b/canny_doubleThreshold_phase5b.v',
    'rtl/phase4b/cordic_gradient_phase4b.v',
    'rtl/phase8/canny_gradient_raw_phase8.v',
    'rtl/phase8/canny_nms_magnitude_phase8.v',
    'rtl/phase9/histogram_unit_phase9.v',
    'rtl/phase9/adaptive_threshold_step_phase9.v',
    'rtl/phase10/block_adaptive_engine_phase10.v',
    'rtl/phase10/canny_block_adaptive_phase10_top.v',
]
pattern = re.compile(r'@\s*\(\s*posedge\s+clk\s+or\s+negedge\s+(rst_n|rst_s)\s*\)')
target.mkdir(parents=True, exist_ok=True)
for src_name in sources:
    src = root / src_name
    dst = target / src.name
    if dst.exists():
        raise SystemExit(f'Refusing to overwrite {dst}')
    # Several imported historic HDL comments are legacy single-byte encoded.
    # Latin-1 round-trips all source bytes while the reset rewrite is ASCII.
    original = src.read_bytes().decode('latin-1')
    updated, count = pattern.subn('@(posedge clk)', original)
    if 'negedge' in updated:
        raise SystemExit(f'Unhandled asynchronous control in {src_name}')
    dst.write_bytes(updated.encode('latin-1'))
    print(f'{src_name} -> {dst.relative_to(root)} synchronous_reset_blocks={count}')
