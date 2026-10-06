"""Diagnose an exported-netlist testbench sampling offset from logged bits."""
from pathlib import Path
import argparse
import re

root = Path(__file__).resolve().parents[2]
ap = argparse.ArgumentParser()
ap.add_argument('log', nargs='?', type=Path,
                default=root / 'reports/phase11v/post_route_func_xsim.log')
args = ap.parse_args()
log = args.log.read_text(encoding='utf-16')
rows = [(int(n), int(g), int(e)) for n, g, e in
        re.findall(r'NETLIST_SAMPLE n=(\d+) got=([01]) expected=([01])', log)]
if not rows:
    raise SystemExit('no diagnostic samples')
gold = {n: e for n, _, e in rows}
for offset in range(-4, 5):
    pairs = [(g, gold[n - offset]) for n, g, _ in rows if n - offset in gold]
    errors = sum(a != b for a, b in pairs)
    print(f'observed[n] vs expected[n-{offset}]: pairs={len(pairs)} errors={errors}')
