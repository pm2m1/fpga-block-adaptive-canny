"""Make exact Phase 8 adaptive oracles from shared grayscale stimulus."""
from pathlib import Path
import csv
import json
import statistics
import sys

ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT))
from model.phase8.frontend import Frontend
from model.phase8.block_adaptive import process_frame
from model.canny_fixed.hysteresis_local import LocalPromotion
from model.phase5b.window import Matrix3x3Phase5B

OUT=ROOT/'results/phase8'
OUT.mkdir(parents=True,exist_ok=True)


def nms_frames():
    frontend=Frontend(640)
    magnitudes=[]
    with (ROOT/'results/phase6/fixed.stream').open() as handle:
        for line in handle:
            vs,hs,de,pixel,_,_=map(int,line.split())
            frontend.tick(vs,hs,de,pixel)
            out_vs,out_hs,out_de,mag=frontend.output
            if out_hs and out_de:
                magnitudes.append(mag)
    if len(magnitudes)!=614400:
        raise AssertionError(f'NMS samples={len(magnitudes)}')
    return [magnitudes[:307200],magnitudes[307200:]]


def local_edges(classes):
    local=LocalPromotion(640)
    local.matrix=Matrix3x3Phase5B(640,2)
    result=[]
    def tick(vs,hs,de,klass):
        local.tick(vs,hs,de,klass)
        ov,oh,od,edge=local.outputs
        if oh and od:result.append(edge)
    for frame in classes:
        for row in range(480):
            for value in frame[row*640:(row+1)*640]:
                tick(1,1,1,value)
            tick(1,0,0,0)
        for _ in range(160):tick(0,0,0,0)
    if len(result)!=307200*len(classes):
        raise AssertionError(f'local edges={len(result)}')
    return result


def main():
    frames=nms_frames()
    block_tables=[]
    class_frames=[]
    edge_diff=[]
    threshold_errors=[]
    low_errors=[]
    quant_rows=[]
    for frame,mag in enumerate(frames):
        blocks,classes,spatial_edge=process_frame(mag)
        exact_blocks,exact_classes,exact_spatial_edge=process_frame(mag,exact=True)
        class_frames.append(classes)
        threshold_errors.extend(abs(a.high-b.high) for a,b in zip(blocks,exact_blocks))
        low_errors.extend(abs(a.low-b.low) for a,b in zip(blocks,exact_blocks))
        edge_diff.append(sum(a!=b for a,b in zip(spatial_edge,exact_spatial_edge)))
        for a,b in zip(blocks,exact_blocks):
            quant_rows.append(dict(frame=frame,image=('random','monkey')[frame],
                bx=a.bx,by=a.by,nonzero_count=a.nonzero_count,
                high_32bin=a.high,high_exact=b.high,abs_high_error=abs(a.high-b.high),
                low_32bin=a.low,low_exact=b.low,abs_low_error=abs(a.low-b.low)))
        block_tables.append(blocks)
        assert len(blocks)==300 and len(classes)==307200
    edges=local_edges(class_frames)
    with (OUT/'adaptive_nms.mem').open('w') as h:
        for frame in frames:
            h.writelines(f'{v:03x}\n' for v in frame)
    with (OUT/'adaptive_classes.mem').open('w') as h:
        for frame in class_frames:
            h.writelines(f'{v:x}\n' for v in frame)
    with (OUT/'adaptive_edges.mem').open('w') as h:
        h.writelines(f'{v:x}\n' for v in edges)
    with (OUT/'adaptive_blocks.txt').open('w') as h:
        for frame,blocks in enumerate(block_tables):
            for block in blocks:
                h.write(f'{frame} {block.bx} {block.by} {block.nonzero_count} '
                        f'{block.selected_bin} {block.high} {block.low} {int(block.active)}\n')
    with (OUT/'adaptive_hist.mem').open('w') as h:
        for blocks in block_tables:
            for by in range(15):
                for bx in range(20):
                    h.writelines(f'{v:03x}\n' for v in blocks[by*20+bx].histogram)
    with (OUT/'adaptive_quantization.csv').open('w',newline='') as h:
        writer=csv.DictWriter(h,fieldnames=list(quant_rows[0]))
        writer.writeheader();writer.writerows(quant_rows)
    summary={
        'frames':2,'pixels_per_frame':307200,'blocks_per_frame':300,
        'quantization_high_mean_abs':statistics.mean(threshold_errors),
        'quantization_high_median_abs':statistics.median(threshold_errors),
        'quantization_high_max_abs':max(threshold_errors),
        'quantization_low_mean_abs':statistics.mean(low_errors),
        'quantization_low_max_abs':max(low_errors),
        'spatial_edge_differences_32bin_vs_exact':edge_diff,
        'images':['random','monkey'],
    }
    (OUT/'adaptive_oracle_summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print('PHASE8_ADAPTIVE_ORACLE_PASS',json.dumps(summary))


if __name__=='__main__':main()
