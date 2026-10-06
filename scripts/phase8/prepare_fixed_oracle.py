"""Extract ordered Phase 6 valid samples (not transition rows) for comparison."""
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
OUT=ROOT/'results/phase8'
OUT.mkdir(parents=True,exist_ok=True)
classes=[]
edges=[]
with (ROOT/'results/phase6/fixed.trace').open() as handle:
    for line in handle:
        fields=line.split()
        if len(fields)!=33:raise AssertionError(len(fields))
        if fields[26]=='1' and fields[27]=='1':
            classes.append(int(fields[28]))
        if fields[30]=='1' and fields[31]=='1':
            edges.append(int(fields[32]))
assert len(classes)==len(edges)==614400
(OUT/'fixed_classes.mem').write_text(''.join(f'{v:x}\n' for v in classes))
(OUT/'fixed_edges.mem').write_text(''.join(f'{v:x}\n' for v in edges))
print('PHASE8_FIXED_ORACLE_PASS samples=614400')
