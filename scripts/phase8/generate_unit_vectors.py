"""Generate deterministic histogram and threshold-unit RTL oracle vectors."""
import random
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from model.phase8.block_adaptive import select_thresholds


def main():
    out=ROOT/'results/phase8'
    out.mkdir(parents=True,exist_ok=True)
    rng=random.Random(0x8A100)
    boundaries=[0,1,63,64,65,127,128,255,256,511,512,1023,1024,1983,1984,2047]
    cases=[
        [0]*1024,
        [1]*1024,
        [2047]*1024,
        [((b<<6)+1) for b in range(32)]+[0]*992,
        (boundaries*64)[:1024],
        [64]*1024,
        [rng.randrange(2048) for _ in range(1024)],
        [1 if i%2 else 2047 for i in range(1024)],
        [0]*1000+[1]*24,
        [((i*37)%2048) for i in range(1024)],
    ]
    with (out/'hist_magnitudes.txt').open('w') as handle:
        for values in cases:
            handle.writelines(f'{v}\n' for v in values)
    with (out/'hist_expected.txt').open('w') as handle:
        for case,values in enumerate(cases):
            hist=[0]*32
            for value in values:
                if value:hist[value>>6]+=1
            block=case%20
            handle.write(f'{block} {sum(hist)} '+ ' '.join(map(str,hist))+'\n')
    synthetic=[]
    synthetic.append([0]*32)
    for bin_id,n in ((0,1),(0,1024),(31,1),(31,1024)):
        h=[0]*32;h[bin_id]=n;synthetic.append(h)
    h=[32]*32;synthetic.append(h) # equal distribution, N=1024
    for count in (204,205,206):
        h=[0]*32;h[31]=count;h[2]=1024-count;synthetic.append(h)
    for _ in range(100):
        h=[0]*32
        for _ in range(rng.randrange(1025)):
            h[rng.randrange(32)]+=1
        synthetic.append(h)
    with (out/'threshold_vectors.txt').open('w') as handle:
        for h in synthetic:
            n=sum(h);b,hi,lo,active=select_thresholds(h,n)
            handle.write(f'{n} {b} {hi} {lo} {int(active)} '+
                         ' '.join(map(str,h))+'\n')
    print(f'PHASE8_UNIT_VECTORS histogram_cases={len(cases)} threshold_cases={len(synthetic)}')


if __name__=='__main__':main()
