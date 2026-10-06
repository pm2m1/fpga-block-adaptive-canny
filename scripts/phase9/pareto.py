"""Multiobjective dominance using measured quality, area, and cadence only."""
import csv
from pathlib import Path

ROOT=Path(__file__).resolve().parents[2]
SOFT=ROOT/'results/phase9/software_sweep.csv'
HARD=ROOT/'results/phase9/hardware_results.csv'
OUT=ROOT/'results/phase9/pareto.csv'


def main():
    with SOFT.open(newline='') as h:soft={(r['block_size'],r['bins']):r for r in csv.DictReader(h)}
    with HARD.open(newline='') as h:hard={(r['block_size'],r['bins']):r for r in csv.DictReader(h)}
    rows=[]
    for key,s in soft.items():
        h=hard[key]
        if any(not h[v] for v in ('lut','ff','lutram','bram18_equiv',
                                  'dsp','frame_interval_cycles')):
            rows.append(dict(block_size=key[0],bins=key[1],quality_f1=s['f1'],
                             dominated_by='UNKNOWN_MISSING_HARDWARE_METRICS',
                             route_timing=h['route_wns'] or 'NOT_ROUTED'))
            continue
        this=(float(s['f1']),)+tuple(float(h[v]) for v in
                  ('lut','ff','lutram','bram18_equiv','dsp','frame_interval_cycles'))
        dominators=[]
        for other,os in soft.items():
            if other==key:continue
            oh=hard[other]
            if any(not oh[v] for v in ('lut','ff','lutram','bram18_equiv',
                                       'dsp','frame_interval_cycles')):continue
            cand=(float(os['f1']),)+tuple(float(oh[v]) for v in
                 ('lut','ff','lutram','bram18_equiv','dsp','frame_interval_cycles'))
            if cand[0]>=this[0] and all(a<=b for a,b in zip(cand[1:],this[1:])) and cand!=this:
                dominators.append(f'{other[0]}x{other[0]}/{other[1]}')
        rows.append(dict(block_size=key[0],bins=key[1],quality_f1=s['f1'],
                         dominated_by=';'.join(dominators) if dominators else 'PARETO',
                         route_timing=h['route_wns'] or 'NOT_ROUTED'))
    with OUT.open('w',newline='') as h:
        writer=csv.DictWriter(h,fieldnames=list(rows[0]))
        writer.writeheader();writer.writerows(rows)
    for row in rows:print('PHASE9_PARETO',row)


if __name__=='__main__':main()
