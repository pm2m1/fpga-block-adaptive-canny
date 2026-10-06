"""Generate two-frame random/monkey or four-frame isolation RTL oracles."""
import argparse
from pathlib import Path
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from model.phase9.block_adaptive import process_frame,fixed_frame
from scripts.phase8.prepare_adaptive_oracle import local_edges


def main(size,bins,suite):
    source=ROOT/'results/phase8'/('isolate_nms.mem' if suite=='isolate' else 'adaptive_nms.mem')
    count=4 if suite=='isolate' else 2
    out=ROOT/'results/phase9/vectors'
    out.mkdir(parents=True,exist_ok=True)
    prefix=out/f'b{size}_h{bins}_{suite}'
    mags=[int(line.strip(),16) for line in source.open()]
    assert len(mags)==count*307200,(source,len(mags))
    class_frames=[];fixed_class_frames=[]
    block_rows=[];histogram=[]
    for frame in range(count):
        raster=mags[frame*307200:(frame+1)*307200]
        blocks,klass,_=process_frame(raster,size,bins,edges=False)
        fk,_=fixed_frame(raster)
        class_frames.append(klass);fixed_class_frames.append(fk)
        for block in blocks:
            block_rows.append((frame,block.bx,block.by,block.pixels,block.nonzero,
                               block.bin_index,block.high,block.low,int(block.active)))
            histogram.extend(block.histogram)
    classes=(v for frame in class_frames for v in frame)
    fixed_classes=(v for frame in fixed_class_frames for v in frame)
    edges=local_edges(class_frames)
    fixed_edges=local_edges(fixed_class_frames)
    for name,data,fmt in (('classes',classes,'x'),('edges',edges,'x'),
                          ('fixed_classes',fixed_classes,'x'),
                          ('fixed_edges',fixed_edges,'x'),('hist',histogram,'04x')):
        with (Path(str(prefix)+'_'+name+'.mem')).open('w') as handle:
            handle.writelines(format(v,fmt)+'\n' for v in data)
    with (Path(str(prefix)+'_blocks.txt')).open('w') as handle:
        for row in block_rows:handle.write(' '.join(map(str,row))+'\n')
    print(f'PHASE9_ORACLE_PASS size={size} bins={bins} suite={suite} '
          f'frames={count} pixels={count*307200} blocks={len(block_rows)}')


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--block',type=int,choices=(32,64),required=True)
    parser.add_argument('--bins',type=int,choices=(8,16,32),required=True)
    parser.add_argument('--suite',choices=('two','isolate'),default='two')
    args=parser.parse_args()
    main(args.block,args.bins,args.suite)
