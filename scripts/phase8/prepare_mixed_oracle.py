"""Frame 0 fixed with a mid-frame port change; frame 1 adaptive."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'results/phase8'
def lines(path):
    with path.open() as handle:return handle.readlines()
fixed_class=lines(OUT/'fixed_classes.mem')
fixed_edge=lines(OUT/'fixed_edges.mem')
adapt_class=lines(OUT/'adaptive_classes.mem')
adapt_edge=lines(OUT/'adaptive_edges.mem')
assert len(fixed_class)==len(adapt_class)==len(fixed_edge)==len(adapt_edge)==614400
(OUT/'mixed_classes.mem').write_text(''.join(fixed_class[:307200]+adapt_class[307200:]))
(OUT/'mixed_edges.mem').write_text(''.join(fixed_edge[:307200]+adapt_edge[307200:]))
for name in ('nms.mem','hist.mem','blocks.txt'):
    (OUT/f'mixed_{name}').write_bytes((OUT/f'adaptive_{name}').read_bytes())
print('PHASE8_MIXED_ORACLE_PASS frames=2 pixels=614400 frame0=fixed frame1=adaptive')
