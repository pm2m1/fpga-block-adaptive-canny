"""Phase 9 software-only 2x3 sweep on common Phase 8 NMS rasters."""
import csv
import json
import math
from pathlib import Path
import statistics
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.phase9.block_adaptive import WIDTH, HEIGHT, process_frame, fixed_frame
from scripts.phase8.prepare_adaptive_oracle import local_edges

SOURCE = ROOT / 'results/phase8/patterns_nms.mem'
OUT = ROOT / 'results/phase9'
NAMES = ('black', 'white', 'impulse', 'horizontal', 'vertical',
         'diagonal45', 'diagonal135', 'checkerboard', 'random', 'monkey')


def agreement(approx, exact):
    common = sum(bool(a) and bool(e) for a, e in zip(approx, exact))
    ap = sum(bool(v) for v in approx)
    ex = sum(bool(v) for v in exact)
    precision = common / ap if ap else float(ex == 0)
    recall = common / ex if ex else float(ap == 0)
    f1 = 2 * precision * recall / (precision + recall) if precision + recall else 0.0
    return dict(common=common, approximation_only=ap-common,
                exact_only=ex-common, precision=precision, recall=recall,
                f1=f1, mismatches=ap+ex-2*common,
                mismatch_fraction=(ap+ex-2*common)/(WIDTH*HEIGHT))


def quantile95(values):
    ordered = sorted(values)
    return ordered[math.ceil(.95 * len(ordered)) - 1]


def write_csv(path, rows):
    with path.open('w', newline='') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


def main():
    if not SOURCE.exists():
        raise SystemExit('Generate Phase 8 patterns_nms.mem with scripts/phase8/prepare_suite.py --suite patterns')
    OUT.mkdir(parents=True, exist_ok=True)
    image_rows, block_rows, effect_rows, recon_rows = [], [], [], []
    aggregate = {(size, bins): dict(errors=[], signed=[], common=0, approx_only=0,
                                    exact_only=0, mismatches=0, pixels=0,
                                    nonzero_blocks=0, blocks=0)
                 for size in (32, 64) for bins in (8, 16, 32)}
    with SOURCE.open() as handle:
        for image in NAMES:
            mags = [int(handle.readline().strip(), 16) for _ in range(WIDTH*HEIGHT)]
            if len(mags) != WIDTH*HEIGHT:
                raise AssertionError('short NMS frame')
            fixed_classes, _ = fixed_frame(mags)
            fixed_edges = local_edges([fixed_classes])
            exact_by_size = {}
            for size in (32,64):
                exact_blocks, exact_classes, _ = process_frame(mags,size,2048,edges=False)
                exact_by_size[size] = (exact_blocks,exact_classes,local_edges([exact_classes]))
            effect = agreement(exact_by_size[32][2], exact_by_size[64][2])
            effect_rows.append(dict(image=image, block32_exact_edges=sum(exact_by_size[32][2]),
                                    block64_exact_edges=sum(exact_by_size[64][2]), **effect))
            for size in (32, 64):
                exact_blocks, _, exact_edges = exact_by_size[size]
                fixed_metric = agreement(fixed_edges, exact_edges)
                for bins in (8, 16, 32):
                    blocks, classes, _ = process_frame(mags, size, bins,edges=False)
                    edge=local_edges([classes])
                    metric = agreement(edge, exact_edges)
                    shift = 11-(bins.bit_length()-1)
                    signed = [a.high-e.high for a, e in zip(blocks, exact_blocks)]
                    absolute = [abs(d) for d in signed]
                    highs = [b.high for b in blocks]
                    lows = [b.low for b in blocks]
                    n_empty = sum(b.nonzero == 0 for b in blocks)
                    row = dict(image=image, block_size=size, bins=bins,
                               blocks=len(blocks), fixed_edges=sum(fixed_edges),
                               approx_edges=sum(edge), exact_edges=sum(exact_edges),
                               mean_abs_high=statistics.mean(absolute),
                               median_abs_high=statistics.median(absolute),
                               p95_abs_high=quantile95(absolute),
                               max_abs_high=max(absolute),
                               mean_signed_high=statistics.mean(signed),
                               mean_high=statistics.mean(highs), min_high=min(highs),
                               max_high=max(highs), std_high=statistics.pstdev(highs),
                               mean_low=statistics.mean(lows), min_low=min(lows),
                               max_low=max(lows), empty_blocks=n_empty,
                               empty_fraction=n_empty/len(blocks),
                               high_zero_blocks=sum(v == 0 for v in highs),
                               high_max_bin_blocks=sum(v == ((bins-1)<<shift) for v in highs),
                               fixed_vs_exact_common=fixed_metric['common'],
                               fixed_vs_exact_precision=fixed_metric['precision'],
                               fixed_vs_exact_recall=fixed_metric['recall'],
                               fixed_vs_exact_f1=fixed_metric['f1'],
                               fixed_vs_exact_mismatches=fixed_metric['mismatches'],
                               **metric)
                    image_rows.append(row)
                    agg = aggregate[(size, bins)]
                    agg['errors'].extend(absolute)
                    agg['signed'].extend(signed)
                    agg['common'] += metric['common']
                    agg['approx_only'] += metric['approximation_only']
                    agg['exact_only'] += metric['exact_only']
                    agg['mismatches'] += metric['mismatches']
                    agg['pixels'] += WIDTH*HEIGHT
                    agg['nonzero_blocks'] += len(blocks)-n_empty
                    agg['blocks'] += len(blocks)
                    for a, e in zip(blocks, exact_blocks):
                        block_rows.append(dict(image=image, block_size=size, bins=bins,
                                               bx=a.bx, by=a.by, pixels=a.pixels,
                                               nonzero=a.nonzero, selected_bin=a.bin_index,
                                               high=a.high, exact_high=e.high,
                                               signed_high_error=a.high-e.high,
                                               absolute_high_error=abs(a.high-e.high),
                                               low=a.low, exact_low=e.low))
                        if a.active:
                            low_boundary=a.bin_index << shift
                            for method, reconstructed in (
                                ('lower', max(1, low_boundary)),
                                ('midpoint', low_boundary+(1 << (shift-1))),
                                ('upper', low_boundary+(1 << shift)-1)):
                                recon_rows.append(dict(image=image, block_size=size,
                                                       bins=bins, method=method,
                                                       signed_error=reconstructed-e.high,
                                                       absolute_error=abs(reconstructed-e.high)))
            print('PHASE9_SOFTWARE_IMAGE', image, flush=True)
        if handle.readline():
            raise AssertionError('extra NMS samples')
    summary = []
    for (size, bins), a in aggregate.items():
        ap = a['common']+a['approx_only']
        ex = a['common']+a['exact_only']
        precision = a['common']/ap if ap else float(ex == 0)
        recall = a['common']/ex if ex else float(ap == 0)
        f1 = 2*precision*recall/(precision+recall) if precision+recall else 0.0
        summary.append(dict(block_size=size, bins=bins, blocks_per_frame=300 if size==32 else 80,
                            total_blocks=a['blocks'], nonzero_blocks=a['nonzero_blocks'],
                            mean_abs_high=statistics.mean(a['errors']),
                            median_abs_high=statistics.median(a['errors']),
                            p95_abs_high=quantile95(a['errors']),
                            max_abs_high=max(a['errors']),
                            mean_signed_high=statistics.mean(a['signed']),
                            common=a['common'], approximation_only=a['approx_only'],
                            exact_only=a['exact_only'], precision=precision, recall=recall,
                            f1=f1, mismatches=a['mismatches'],
                            mismatch_fraction=a['mismatches']/a['pixels']))
    write_csv(OUT/'software_sweep.csv', summary)
    write_csv(OUT/'image_metrics.csv', image_rows)
    write_csv(OUT/'block_thresholds.csv', block_rows)
    write_csv(OUT/'block_size_effect.csv', effect_rows)
    write_csv(OUT/'reconstruction_analysis.csv', recon_rows)
    (OUT/'software_summary.json').write_text(json.dumps(summary, indent=2)+'\n')
    print('PHASE9_SOFTWARE_SWEEP_PASS configurations=6 images=10', flush=True)


if __name__ == '__main__':
    main()
