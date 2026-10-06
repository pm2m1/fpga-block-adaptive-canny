"""Deterministic 640x480 grayscale streams with explicit threshold ports."""
from __future__ import annotations
import json
from pathlib import Path
from model.canny_fixed.images import WIDTH, FULL_HEIGHT, RANDOM_SEED, monkey_gray, synthetic


def write_suite(root: Path, suite: str) -> dict:
    out = root / "results/phase6"
    out.mkdir(parents=True, exist_ok=True)
    monkey = monkey_gray(root / "images/monkey.bmp")
    random_image = synthetic("random", FULL_HEIGHT)
    if suite == "fixed":
        frames = [("random", random_image, 50, 100), ("monkey", monkey, 50, 100)]
    elif suite == "atomic":
        frames = [("random_midchange", random_image, 50, 100),
                  ("monkey_new_thresholds", monkey, 100, 200)]
    elif suite == "multi":
        pairs = ((10, 20), (25, 75), (50, 100), (100, 200),
                 (300, 600), (700, 1200))
        frames = [(f"monkey_{low}_{high}", monkey, low, high)
                  for low, high in pairs]
    elif suite == "trend":
        pairs = ((20, 40), (50, 100), (100, 200), (200, 400))
        frames = [(f"monkey_{low}_{high}", monkey, low, high)
                  for low, high in pairs]
    elif suite == "isolate":
        frames = [("black", synthetic("black", FULL_HEIGHT), 50, 100),
                  ("target_after_black", monkey, 50, 100),
                  ("white", synthetic("white", FULL_HEIGHT), 50, 100),
                  ("target_after_white", monkey, 50, 100)]
    else:
        raise ValueError(suite)
    stream = out / f"{suite}.stream"
    with stream.open("w", encoding="ascii", newline="\n") as handle:
        def blank(vs: int, cycles: int, low: int, high: int) -> None:
            handle.write(f"{vs} 0 0 0 {low} {high}\n" * cycles)
        for index, (name, image, low, high) in enumerate(frames):
            blank(0, 80, low, high)
            for y in range(FULL_HEIGHT):
                port_low, port_high = (100, 200) if suite == "atomic" and index == 0 and y >= 240 else (low, high)
                for value in image[y*WIDTH:(y+1)*WIDTH]:
                    handle.write(f"1 1 1 {value} {port_low} {port_high}\n")
                blank(1, 24, port_low, port_high)
            blank(1, 128, port_low, port_high)
            blank(0, 40, port_low, port_high)
        blank(0, 160, *frames[-1][2:4])
    result = {
        "suite": suite, "width": WIDTH, "height": FULL_HEIGHT,
        "pixels_per_frame": WIDTH*FULL_HEIGHT,
        "frames": [{"name": name, "low_at_start": low, "high_at_start": high}
                   for name, _, low, high in frames],
        "midframe_change": {"frame": 0, "row": 240, "new_low": 100, "new_high": 200}
                           if suite == "atomic" else None,
        "random_seed": RANDOM_SEED,
        "stream": str(stream.relative_to(root)).replace("\\", "/"),
    }
    (out / f"{suite}.json").write_text(json.dumps(result, indent=2)+"\n")
    return result
