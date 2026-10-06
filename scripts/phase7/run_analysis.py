"""Compare Phase 6 post-NMS class maps against exact 8-connectivity.

Usage from repository root: python scripts/phase7/run_analysis.py
Uses existing Phase 6 RTL traces that were verified sample-by-sample against
the Phase 6 bit-accurate Python pipeline. Regenerating them is documented in
reports/PHASE6_RUNTIME_THRESHOLDS.md. Synthetic cases run the same model.
"""
from __future__ import annotations
import csv
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.canny_fixed.images import WIDTH, SMALL_HEIGHT, png_gray, synthetic, monkey_gray
from model.phase6.pipeline import CannyPipeline
from model.phase7.full_hysteresis import full_hysteresis, one_pass, bounded_from_depth
from model.phase7.tests import run as directed_tests

OUT = ROOT / "results/phase7"
OUT.mkdir(parents=True, exist_ok=True)


def trace_maps(suite: str, select: set[str]):
    """Extract valid NMS class samples only, not VCD transitions/trace rows."""
    info = json.loads((ROOT / f"results/phase6/{suite}.json").read_text())
    expected = info["pixels_per_frame"]
    maps = {f["name"]: bytearray() for f in info["frames"] if f["name"] in select}
    count = 0
    with (ROOT / f"results/phase6/{suite}.trace").open() as handle:
        for line in handle:
            fields = line.split()
            if len(fields) != 33:
                raise AssertionError("malformed Phase 6 trace")
            if fields[26] == "1" and fields[27] == "1":
                frame = count // expected
                name = info["frames"][frame]["name"]
                if name in maps:
                    klass = int(fields[28])
                    if klass not in (0, 1, 2):
                        raise AssertionError((suite, name, klass))
                    maps[name].append(klass)
                count += 1
    assert count == expected * len(info["frames"]), (suite, count)
    assert all(len(v) == expected for v in maps.values())
    return maps


def synthetic_nms(name: str, low: int, high: int):
    image = synthetic(name, SMALL_HEIGHT)
    model = CannyPipeline(WIDTH)
    classes = bytearray()
    def sample(vs, hs, de, value):
        model.tick(vs, hs, de, value, low, high)
        out_vs, out_hs, out_de, klass = model.sampled()["nms"]
        if out_hs and out_de:
            classes.append(klass)
    for _ in range(80):
        sample(0, 0, 0, 0)
    for y in range(SMALL_HEIGHT):
        for value in image[y*WIDTH:(y+1)*WIDTH]:
            sample(1, 1, 1, value)
        for _ in range(24):
            sample(1, 0, 0, 0)
    for _ in range(128):
        sample(1, 0, 0, 0)
    for _ in range(160):
        sample(0, 0, 0, 0)
    assert len(classes) == WIDTH * SMALL_HEIGHT, (name, len(classes))
    return image, classes


def analyze(name, image, classes, width, height, low, high, visualize=False):
    assert len(classes) == width * height
    local = one_pass(classes, width)
    full, depths, hist = full_hysteresis(classes, width)
    assert local == bounded_from_depth(depths, 1), name
    diff = bytearray(a != b for a, b in zip(local, full))
    local_only = sum(a and not b for a, b in zip(local, full))
    recursive_only = sum(b and not a for a, b in zip(local, full))
    assert local_only == 0, name
    strong = classes.count(2)
    weak = classes.count(1)
    edge_full = sum(full)
    row = dict(image=name, width=width, height=height, low=low, high=high,
               strong_pixels=strong, weak_pixels=weak,
               one_pass_edges=sum(local), recursive_edges=edge_full,
               differing_pixels=sum(diff), one_pass_only=local_only,
               recursive_only=recursive_only,
               difference_fraction=sum(diff)/len(classes),
               recursive_recovery_fraction=(recursive_only/edge_full if edge_full else 0),
               max_depth=max(depths),
               bounded_1_missing=sum(d > 1 for d in depths),
               bounded_2_missing=sum(d > 2 for d in depths),
               bounded_4_missing=sum(d > 4 for d in depths),
               bounded_8_missing=sum(d > 8 for d in depths))
    (OUT / f"{name}_{low}_{high}_depth.json").write_text(
        json.dumps({"depth_0_is_original_strong": True,
                    "counts_by_depth": hist,
                    "unreachable_weak": weak - sum(hist[1:])}, indent=2)+"\n")
    if visualize:
        prefix = OUT / f"{name}_{low}_{high}"
        png_gray(Path(str(prefix)+"_input.png"), image, width, height)
        png_gray(Path(str(prefix)+"_nms_class.png"), classes, width, height, 2)
        png_gray(Path(str(prefix)+"_onepass.png"), local, width, height, 1)
        png_gray(Path(str(prefix)+"_recursive.png"), full, width, height, 1)
        png_gray(Path(str(prefix)+"_difference.png"), diff, width, height, 1)
    return row


def main():
    directed = directed_tests()
    with (OUT / "directed_tests.csv").open("w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(("case", "class_map", "one_pass", "recursive", "differing", "max_depth"))
        writer.writerows(directed)
    rows = []
    monkey = monkey_gray(ROOT / "images/monkey.bmp")
    maps = trace_maps("multi", {"monkey_25_75", "monkey_50_100", "monkey_100_200"})
    for low, high in ((25,75),(50,100),(100,200)):
        classes = maps[f"monkey_{low}_{high}"]
        rows.append(analyze("monkey", monkey, classes, WIDTH, 480,
                            low, high, visualize=(low, high)==(50,100)))
    random_image = synthetic("random", 480)
    random_map = trace_maps("fixed", {"random"})["random"]
    rows.append(analyze("random", random_image, random_map, WIDTH, 480,
                        50, 100, visualize=True))
    for name in ("vertical", "horizontal", "diagonal45", "diagonal135", "checkerboard"):
        image, classes = synthetic_nms(name, 50, 100)
        rows.append(analyze(name, image, classes, WIDTH, SMALL_HEIGHT,
                            50, 100, visualize=name in ("diagonal45", "checkerboard")))
    with (OUT / "image_metrics.csv").open("w", newline="") as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)
    summary = {"pairs": len(rows),
               "total_pixels": sum(r["width"]*r["height"] for r in rows),
               "total_differing": sum(r["differing_pixels"] for r in rows),
               "max_depth": max(r["max_depth"] for r in rows),
               "full_frame_pairs": sum(r["height"]==480 for r in rows),
               "source": "Phase 6 RTL traces already verified against bit-accurate Python; synthetic maps from Phase 6 Python model",
               "natural_images_available": ["monkey.bmp"]}
    (OUT / "summary.json").write_text(json.dumps(summary, indent=2)+"\n")
    print("PHASE7_ANALYSIS_PASS", json.dumps(summary))


if __name__ == "__main__":
    main()
