"""Quantify exactly where the verified historic border policy changes output."""
from __future__ import annotations
from collections import Counter
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.canny_fixed.pipeline import CannyPipeline as HistoricPipeline
from model.phase5b.pipeline import CannyPipeline as IsolatedPipeline


def main() -> None:
    out = ROOT / "results/phase5b"
    info = json.loads((out / "full.json").read_text())
    old, new = HistoricPipeline(info["width"]), IsolatedPipeline(info["width"])
    pixels_per_frame = info["pixels_per_frame"]
    sample = 0
    changed_rows: Counter[tuple[int, int]] = Counter()
    changed_columns: Counter[tuple[int, int]] = Counter()
    changed_stage: dict[str, Counter[tuple[int, int]]] = {
        key: Counter() for key in ("gaussian", "sobel", "cordic", "threshold", "nms", "edge")}
    counts = {key: 0 for key in changed_stage}
    with (out / "full.stream").open() as source:
        for stimulus in source:
            old.tick(*map(int, stimulus.split()))
            new.tick(*map(int, stimulus.split()))
            a, b = old.sampled(), new.sampled()
            for stage in changed_stage:
                xa, xb = a[stage], b[stage]
                valid_a = xa[1] & xa[2] if stage in ("gaussian", "threshold", "nms", "edge") else xa[-1]
                valid_b = xb[1] & xb[2] if stage in ("gaussian", "threshold", "nms", "edge") else xb[-1]
                if valid_a != valid_b:
                    raise AssertionError((stage, valid_a, valid_b))
                if not valid_a:
                    continue
                index = counts[stage]
                frame = index // pixels_per_frame
                y = (index % pixels_per_frame) // info["width"]
                x = index % info["width"]
                if xa != xb:
                    changed_stage[stage][(frame, y)] += 1
                    if stage == "edge":
                        changed_rows[(frame, y)] += 1
                        changed_columns[(frame, x)] += 1
                counts[stage] += 1
            sample += 1
    for stage, count in counts.items():
        if count != pixels_per_frame * len(info["frames"]):
            raise AssertionError((stage, count))
    result = {
        "frames": info["frames"],
        "pixels_per_frame": pixels_per_frame,
        "changed_by_stage": {stage: sum(rows.values()) for stage, rows in changed_stage.items()},
        "changed_edge_pixels_by_frame": [sum(value for (frame, _), value in changed_rows.items() if frame == f)
                                         for f in range(len(info["frames"]))],
        "changed_edge_rows_by_frame": [sorted(y for (frame, y), value in changed_rows.items()
                                              if frame == f and value)
                                       for f in range(len(info["frames"]))],
        "changed_edge_columns_by_frame": [sorted(x for (frame, x), value in changed_columns.items()
                                                 if frame == f and value)
                                          for f in range(len(info["frames"]))],
        "changed_rows_per_stage": {
            stage: {f"frame{frame}_row{y}": value for (frame, y), value in sorted(rows.items())}
            for stage, rows in changed_stage.items()},
    }
    (out / "old_vs_new.json").write_text(json.dumps(result, indent=2) + "\n")
    print("PHASE5B_HISTORIC_COMPARE", json.dumps({
        "changed_by_stage": result["changed_by_stage"],
        "changed_edge_pixels_by_frame": result["changed_edge_pixels_by_frame"],
        "changed_edge_rows_by_frame": result["changed_edge_rows_by_frame"],
    }))


if __name__ == "__main__":
    main()
