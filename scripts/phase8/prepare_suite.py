"""Additional full-frame adaptive suites: ten patterns and frame isolation."""
import argparse
import csv
import json
from pathlib import Path
import statistics
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from model.phase8.frontend import Frontend
from model.phase8.block_adaptive import process_frame
from model.canny_fixed.images import synthetic,monkey_gray
from scripts.phase8.prepare_adaptive_oracle import local_edges

OUT=ROOT/'results/phase8'
OUT.mkdir(parents=True,exist_ok=True)


def pattern_stream():
    names=('black','white','impulse','horizontal','vertical','diagonal45',
           'diagonal135','checkerboard','random','monkey')
    frames=[monkey_gray(ROOT/'images/monkey.bmp') if name=='monkey'
            else synthetic(name,480) for name in names]
    path=OUT/'patterns.stream'
    with path.open('w') as h:
        for image in frames:
            h.write('0 0 0 0 50 100\n'*80)
            for y in range(480):
                h.writelines(f'1 1 1 {v} 50 100\n' for v in image[y*640:(y+1)*640])
                h.write('1 0 0 0 50 100\n'*24)
            h.write('1 0 0 0 50 100\n'*128)
            h.write('0 0 0 0 50 100\n'*40)
        h.write('0 0 0 0 50 100\n'*160)
    return path,names


def main(suite):
    if suite=='patterns':stream,names=pattern_stream()
    elif suite=='isolate':
        stream=ROOT/'results/phase6/isolate.stream'
        names=('black','monkey_after_black','white','monkey_after_white')
    else:raise ValueError(suite)
    frontend=Frontend(640)
    mags=[]
    with stream.open() as handle:
        for line in handle:
            vs,hs,de,pixel,_,_=map(int,line.split())
            frontend.tick(vs,hs,de,pixel)
            ov,oh,od,mag=frontend.output
            if oh and od:mags.append(mag)
    expected=len(names)*307200
    if len(mags)!=expected:raise AssertionError((len(mags),expected))
    frames=[mags[i*307200:(i+1)*307200] for i in range(len(names))]
    classes=[];blocks_by_frame=[];high_errors=[];low_errors=[];edge_diff=[];quant_rows=[]
    for frame_id,mag in enumerate(frames):
        blocks,klass,edge=process_frame(mag)
        exact_blocks,_,exact_edge=process_frame(mag,exact=True)
        classes.append(klass);blocks_by_frame.append(blocks)
        high_errors.extend(abs(a.high-b.high) for a,b in zip(blocks,exact_blocks))
        low_errors.extend(abs(a.low-b.low) for a,b in zip(blocks,exact_blocks))
        edge_diff.append(sum(a!=b for a,b in zip(edge,exact_edge)))
        for a,b in zip(blocks,exact_blocks):
            quant_rows.append(dict(frame=frame_id,image=names[frame_id],
                bx=a.bx,by=a.by,nonzero_count=a.nonzero_count,
                high_32bin=a.high,high_exact=b.high,abs_high_error=abs(a.high-b.high),
                low_32bin=a.low,low_exact=b.low,abs_low_error=abs(a.low-b.low)))
    edges=local_edges(classes)
    if suite=='isolate':
        assert frames[1]==frames[3], 'front-end frame isolation failure'
        assert classes[1]==classes[3], 'classification frame isolation failure'
        assert blocks_by_frame[1]==blocks_by_frame[3], 'block threshold isolation failure'
        assert edges[307200:614400]==edges[921600:1228800], 'edge isolation failure'
    for label,values,fmt in (('nms',mags,'03x'),
                             ('classes',(v for frame in classes for v in frame),'x'),
                             ('edges',edges,'x')):
        with (OUT/f'{suite}_{label}.mem').open('w') as h:
            h.writelines(format(v,fmt)+'\n' for v in values)
    with (OUT/f'{suite}_hist.mem').open('w') as h:
        for blocks in blocks_by_frame:
            for block in blocks:
                h.writelines(f'{v:03x}\n' for v in block.histogram)
    with (OUT/f'{suite}_blocks.txt').open('w') as h:
        for frame,blocks in enumerate(blocks_by_frame):
            for block in blocks:
                h.write(f'{frame} {block.bx} {block.by} {block.nonzero_count} '
                        f'{block.selected_bin} {block.high} {block.low} {int(block.active)}\n')
    with (OUT/f'{suite}_quantization.csv').open('w',newline='') as h:
        writer=csv.DictWriter(h,fieldnames=list(quant_rows[0]))
        writer.writeheader();writer.writerows(quant_rows)
    summary={'suite':suite,'images':names,'frames':len(names),
             'blocks':len(names)*300,'samples':expected,
             'mean_abs_high_error':statistics.mean(high_errors),
             'median_abs_high_error':statistics.median(high_errors),
             'max_abs_high_error':max(high_errors),
             'mean_abs_low_error':statistics.mean(low_errors),
             'max_abs_low_error':max(low_errors),
             'edge_differences_32bin_vs_exact':edge_diff,
             'isolation_model_pass':suite=='isolate'}
    (OUT/f'{suite}_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('PHASE8_SUITE_ORACLE_PASS',json.dumps(summary))


if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--suite',choices=('patterns','isolate'),required=True)
    main(parser.parse_args().suite)
