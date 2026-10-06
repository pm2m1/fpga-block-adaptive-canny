"""Prepare deterministic grayscale streams and compare Phase 4B RTL traces.

Usage from repository root (Python 3.12):
  python model/run_phase5_regression.py --prepare small
  python model/run_phase5_regression.py --compare small
"""
from __future__ import annotations
import argparse
from collections import deque
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT))
from model.canny_fixed.images import write_suite, png_gray  # noqa: E402
from model.canny_fixed.pipeline import CannyPipeline  # noqa: E402

STAGES = ("gaussian", "sobel", "cordic", "threshold", "nms", "edge")


def number(token: str, stage: str, cycle: int) -> int:
    try:
        return int(token)
    except ValueError as error:
        if set(token.lower()) <= {"x", "z"}:
            return -1  # May occur only at an unqualified, invalid data output.
        raise AssertionError(f"unknown RTL value stage={stage} cycle={cycle}: {token}") from error


def compare(suite: str) -> dict:
    out = ROOT / "results/phase5"
    info = json.loads((out / f"{suite}.json").read_text(encoding="utf-8"))
    stream = out / f"{suite}.stream"
    trace = out / f"{suite}.trace"
    model = CannyPipeline(info["width"])
    counts = {stage: 0 for stage in STAGES}
    outputs = {stage: [] for stage in STAGES}
    outputs["direction"] = []
    recent: deque[str] = deque(maxlen=8)
    detailed = True  # Stage-by-stage comparison for both short and full frames.
    with stream.open("r", encoding="ascii") as input_handle, trace.open(
            "r", encoding="ascii") as trace_handle:
        for cycle, stimulus in enumerate(input_handle):
            recent.append(stimulus.strip())
            vs, hs, de, pixel = map(int, stimulus.split())
            model.tick(vs, hs, de, pixel)
            snap = model.sampled()
            if detailed:
                line = trace_handle.readline()
                if not line:
                    raise AssertionError(f"RTL trace ended early at cycle {cycle}")
                fields = line.split()
                if len(fields) != 29:
                    raise AssertionError(f"trace fields={len(fields)} at cycle {cycle}: {line[:150]}")
                rt = [number(value, "trace", cycle) for value in fields]
                if rt[0:5] != [cycle, vs, hs, de, pixel]:
                    raise AssertionError(f"input trace mismatch cycle={cycle}: {rt[0:5]}")
                observations = {
                    "gaussian": (rt[5], rt[6], rt[7], rt[8]),
                    "sobel": (rt[10], rt[11], rt[12], rt[13], rt[9]),
                    "cordic": (rt[15], rt[16], rt[14]),
                    "threshold": (rt[17], rt[18], rt[19], rt[20]),
                    "nms": (rt[21], rt[22], rt[23], rt[24]),
                    "edge": (rt[25], rt[26], rt[27], rt[28]),
                }
                for stage in STAGES:
                    expected = snap[stage]
                    actual = observations[stage]
                    expected_valid = (expected[1] & expected[2] if stage in
                                      ("gaussian", "threshold", "nms", "edge")
                                      else expected[-1])
                    actual_valid = (actual[1] & actual[2] if stage in
                                    ("gaussian", "threshold", "nms", "edge")
                                    else actual[-1])
                    if expected_valid != actual_valid or (
                            expected_valid and expected != actual):
                        index = counts[stage]
                        frame = index // info["pixels_per_frame"]
                        x = index % info["width"]
                        y = (index % info["pixels_per_frame"]) // info["width"]
                        raise AssertionError(
                            f"stage={stage} frame={frame} x={x} y={y} cycle={cycle} "
                            f"RTL={actual} model={expected} recent_input={list(recent)}")
                    if expected_valid:
                        counts[stage] += 1
                        if stage == "cordic":
                            outputs[stage].append(expected[0])
                            outputs["direction"].append(expected[1])
                        elif stage == "sobel":
                            outputs[stage].append(expected[0])
                        else:
                            outputs[stage].append(expected[-1])
            else:
                expected = snap["edge"]
                if expected[1] and expected[2]:
                    line = trace_handle.readline()
                    if not line:
                        raise AssertionError(f"RTL final trace ended early at cycle {cycle}")
                    fields = line.split()
                    if len(fields) != 2:
                        raise AssertionError(f"Malformed RTL final trace cycle={cycle}: {line}")
                    rtl_cycle = number(fields[0], "edge", cycle)
                    rtl_value = number(fields[1], "edge", cycle)
                    if rtl_cycle != cycle or rtl_value != expected[3]:
                        index = counts["edge"]
                        frame = index // info["pixels_per_frame"]
                        x = index % info["width"]
                        y = (index % info["pixels_per_frame"]) // info["width"]
                        raise AssertionError(
                            f"stage=edge frame={frame} x={x} y={y} cycle={cycle} "
                            f"RTL=({rtl_cycle},{rtl_value}) model={expected[3]} "
                            f"recent_input={list(recent)}")
                    counts["edge"] += 1
                    outputs["edge"].append(expected[3])
        if trace_handle.readline():
            raise AssertionError("Extra RTL trace samples beyond model stream")
    expected_count = info["pixels_per_frame"] * len(info["frames"])
    for stage in STAGES if detailed else ("edge",):
        if counts[stage] != expected_count:
            raise AssertionError(
                f"{stage} count={counts[stage]} expected={expected_count}")
    for frame, name in enumerate(info["frames"]):
        if name not in ("black", "impulse", "vertical", "diagonal45",
                        "random_full", "monkey"):
            continue
        start = frame * info["pixels_per_frame"]
        end = start + info["pixels_per_frame"]
        for stage, max_value in (("gaussian", 255), ("cordic", 1443),
                                 ("nms", 2), ("edge", 1)):
            if stage not in outputs or len(outputs[stage]) < end:
                continue
            label = "magnitude" if stage == "cordic" else stage
            png_gray(out / f"{name}_{label}.png", outputs[stage][start:end],
                     info["width"], info["height"], max_value)
        if len(outputs["direction"]) >= end:
            direction_pixels = [{1: 0, 2: 85, 4: 170, 8: 255}[value]
                                for value in outputs["direction"][start:end]]
            png_gray(out / f"{name}_direction.png", direction_pixels,
                     info["width"], info["height"])
    result = {"suite": suite, "frames": len(info["frames"]),
              "pixels_per_frame": info["pixels_per_frame"],
              "samples_compared": counts, "mismatches": 0, "unknowns": 0}
    (out / f"{suite}_comparison.json").write_text(
        json.dumps(result, indent=2)+"\n", encoding="utf-8")
    print("PHASE5_MODEL_COMPARE_PASS", json.dumps(result, sort_keys=True))
    return result


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--prepare", choices=("small", "full"))
    parser.add_argument("--compare", choices=("small", "full"))
    args = parser.parse_args()
    if args.prepare:
        print(json.dumps(write_suite(ROOT, args.prepare), indent=2))
    if args.compare:
        compare(args.compare)
