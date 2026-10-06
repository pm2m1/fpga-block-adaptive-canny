"""Run the Phase 4B bit-accurate grayscale model without RTL/XSim.

Example:
  python model/run_canny_model.py --input results/phase5/monkey.mem \
      --output results/phase5/monkey_standalone_edge.png

The input is exactly 640*height hexadecimal 8-bit grayscale values, one per
line, in raster order. This does not perform BMP/RGB conversion.
"""
from __future__ import annotations
import argparse
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from model.canny_fixed.pipeline import CannyPipeline  # noqa: E402
from model.canny_fixed.images import png_gray  # noqa: E402


def run(input_path: Path, output_path: Path, height: int) -> None:
    width = 640  # Active Phase 4B DATA_DEPTH; not a runtime RTL parameter.
    pixels = [int(token, 16) for token in input_path.read_text(
        encoding="ascii").split()]
    if len(pixels) != width * height or any(not 0 <= value <= 255 for value in pixels):
        raise ValueError(f"Expected exactly {width*height} grayscale bytes")
    model = CannyPipeline(width)
    edge = []
    def tick(vs: int, hs: int, de: int, gray: int) -> None:
        model.tick(vs, hs, de, gray)
        out_vs, out_hs, out_de, bit = model.sampled()["edge"]
        if out_hs and out_de:
            edge.append(bit)
    for _ in range(80):
        tick(0, 0, 0, 0)
    for y in range(height):
        for value in pixels[y*width:(y+1)*width]:
            tick(1, 1, 1, value)
        for _ in range(24):
            tick(1, 0, 0, 0)
    for _ in range(128):
        tick(1, 0, 0, 0)
    for _ in range(200):
        tick(0, 0, 0, 0)
    if len(edge) != width * height:
        raise AssertionError(f"Output count {len(edge)} != {width*height}")
    png_gray(output_path, edge, width, height, 1)
    print(f"PHASE5_STANDALONE_MODEL_PASS pixels={len(edge)} output={output_path}")


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--input", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--height", type=int, default=480)
    args = parser.parse_args()
    run(args.input, args.output, args.height)
