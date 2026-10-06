"""Generate Phase 6 grayscale/config streams and compare valid RTL stages."""
from __future__ import annotations
import argparse
from collections import deque
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.phase6.images import write_suite
from model.phase6.pipeline import CannyPipeline

STAGES = ("gaussian", "sobel", "cordic", "threshold", "nms", "edge")
SUITES = ("fixed", "atomic", "multi", "trend", "isolate")


def number(token: str, cycle: int) -> int:
    try:
        return int(token)
    except ValueError as error:
        if set(token.lower()) <= {"x", "z"}:
            return -1
        raise AssertionError(f"unknown RTL value cycle={cycle}: {token}") from error


def compare(suite: str) -> dict:
    out = ROOT / "results/phase6"
    info = json.loads((out / f"{suite}.json").read_text())
    model = CannyPipeline(info["width"])
    counts = {stage: 0 for stage in STAGES}
    strong = [0] * len(info["frames"])
    weak = [0] * len(info["frames"])
    edges = [0] * len(info["frames"])
    target_edges: dict[int, list[int]] = {1: [], 3: []} if suite == "isolate" else {}
    recent: deque[str] = deque(maxlen=8)
    with (out / f"{suite}.stream").open("r", encoding="ascii") as stimulus_file, \
         (out / f"{suite}.trace").open("r", encoding="ascii") as trace_file:
        for cycle, stimulus in enumerate(stimulus_file):
            recent.append(stimulus.strip())
            vs, hs, de, pixel, low_i, high_i = map(int, stimulus.split())
            model.tick(vs, hs, de, pixel, low_i, high_i)
            snap = model.sampled()
            line = trace_file.readline()
            if not line:
                raise AssertionError(f"RTL trace ended early cycle={cycle}")
            fields = line.split()
            if len(fields) != 33:
                raise AssertionError(f"trace fields={len(fields)} cycle={cycle}: {line[:160]}")
            rt = [number(value, cycle) for value in fields]
            if rt[0:7] != [cycle, vs, hs, de, pixel, low_i, high_i]:
                raise AssertionError(f"RTL input trace mismatch cycle={cycle}")
            if rt[7:9] != [model.threshold_low_active, model.threshold_high_active]:
                raise AssertionError(f"active threshold mismatch cycle={cycle}: "
                                     f"RTL={rt[7:9]} model={[model.threshold_low_active, model.threshold_high_active]}")
            observations = {
                "gaussian": tuple(rt[9:13]),
                "sobel": (rt[14], rt[15], rt[16], rt[17], rt[13]),
                "cordic": (rt[19], rt[20], rt[18]),
                "threshold": tuple(rt[21:25]),
                "nms": tuple(rt[25:29]),
                "edge": tuple(rt[29:33]),
            }
            for stage in STAGES:
                expected, actual = snap[stage], observations[stage]
                expected_valid = expected[1] & expected[2] if stage in (
                    "gaussian", "threshold", "nms", "edge") else expected[-1]
                actual_valid = actual[1] & actual[2] if stage in (
                    "gaussian", "threshold", "nms", "edge") else actual[-1]
                if expected_valid != actual_valid or (expected_valid and expected != actual):
                    sample = counts[stage]
                    frame = sample // info["pixels_per_frame"]
                    x = sample % info["width"]
                    y = (sample % info["pixels_per_frame"]) // info["width"]
                    raise AssertionError(f"stage={stage} frame={frame} x={x} y={y} cycle={cycle} "
                                         f"RTL={actual} model={expected} recent={list(recent)}")
                if expected_valid:
                    frame = counts[stage] // info["pixels_per_frame"]
                    if stage == "threshold":
                        klass = (actual[3] >> 15) & 3
                        strong[frame] += klass == 2
                        weak[frame] += klass == 1
                    if stage == "edge":
                        edges[frame] += actual[3]
                        if frame in target_edges:
                            target_edges[frame].append(actual[3])
                    counts[stage] += 1
        if trace_file.readline():
            raise AssertionError("Extra RTL trace samples")
    expected_count = info["pixels_per_frame"] * len(info["frames"])
    for stage, count in counts.items():
        if count != expected_count:
            raise AssertionError(f"{stage} count={count}, expected={expected_count}")
    isolation = None
    if suite == "isolate":
        first, second = target_edges[1], target_edges[3]
        mismatches = sum(a != b for a, b in zip(first, second))
        isolation = {"pixels_compared": len(first), "mismatches": mismatches}
        if len(first) != 307200 or len(second) != 307200 or mismatches:
            raise AssertionError(f"frame isolation failed: {isolation}")
    per_frame = [dict(**entry, pixels=info["pixels_per_frame"],
                      strong_count=strong[index], weak_count=weak[index],
                      edge_count=edges[index], mismatches=0, unknowns=0)
                 for index, entry in enumerate(info["frames"])]
    result = {"suite": suite, "frames": len(info["frames"]),
              "pixels_per_frame": info["pixels_per_frame"],
              "samples_compared": counts, "mismatches": 0, "unknowns": 0,
              "per_frame": per_frame, "frame_isolation": isolation,
              "midframe_change": info["midframe_change"]}
    (out / f"{suite}_comparison.json").write_text(json.dumps(result, indent=2)+"\n")
    print("PHASE6_MODEL_COMPARE_PASS", json.dumps(result, sort_keys=True))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", choices=SUITES)
    parser.add_argument("--compare", choices=SUITES)
    args = parser.parse_args()
    if args.prepare:
        print(json.dumps(write_suite(ROOT, args.prepare), indent=2))
    if args.compare:
        compare(args.compare)
