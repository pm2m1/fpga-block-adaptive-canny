"""Deterministic grayscale image/test-stream generation; no RGB path in DUT."""
from __future__ import annotations
import json
import random
import struct
import zlib
from pathlib import Path

WIDTH = 640
SMALL_HEIGHT = 16
FULL_HEIGHT = 480
RANDOM_SEED = 0x5CA11E


def png_gray(path: Path, pixels: list[int], width: int, height: int,
             scale_max: int = 255) -> None:
    """Write an 8-bit grayscale PNG using only the standard library."""
    path.parent.mkdir(parents=True, exist_ok=True)
    rows = []
    for y in range(height):
        row = pixels[y * width:(y + 1) * width]
        rows.append(bytes([0] + [min(255, (v * 255) // max(1, scale_max))
                                  for v in row]))
    def chunk(tag: bytes, data: bytes) -> bytes:
        payload = tag + data
        return struct.pack(">I", len(data)) + payload + struct.pack(
            ">I", zlib.crc32(payload) & 0xffffffff)
    content = (b"\x89PNG\r\n\x1a\n" +
               chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 0, 0, 0, 0)) +
               chunk(b"IDAT", zlib.compress(b"".join(rows))) +
               chunk(b"IEND", b""))
    path.write_bytes(content)


def monkey_gray(path: Path) -> list[int]:
    """Decode 24-bit uncompressed BMP BGR bottom-up; Y=floor((77R+150G+29B)/256).

    This single documented conversion creates a grayscale *test asset* and is
    intentionally not the historical RTL RGB->YCbCr module.
    """
    data = path.read_bytes()
    if data[:2] != b"BM":
        raise ValueError("Not a BMP")
    offset = struct.unpack_from("<I", data, 10)[0]
    width, signed_height = struct.unpack_from("<ii", data, 18)
    bpp = struct.unpack_from("<H", data, 28)[0]
    compression = struct.unpack_from("<I", data, 30)[0]
    if (width, abs(signed_height), bpp, compression) != (640, 480, 24, 0):
        raise ValueError((width, signed_height, bpp, compression))
    stride = (width * 3 + 3) & ~3
    pixels = []
    for y in range(abs(signed_height)):
        src_y = abs(signed_height) - 1 - y if signed_height > 0 else y
        base = offset + src_y * stride
        for x in range(width):
            b, g, r = data[base + 3*x:base + 3*x + 3]
            pixels.append((77*r + 150*g + 29*b) >> 8)
    return pixels


def synthetic(name: str, height: int = SMALL_HEIGHT) -> list[int]:
    rng = random.Random(RANDOM_SEED)
    result = []
    for y in range(height):
        for x in range(WIDTH):
            if name == "black": value = 0
            elif name == "white": value = 255
            elif name == "impulse": value = 255 if (x, y) == (320, height//2) else 0
            elif name == "vertical": value = 255 if x >= 320 else 0
            elif name == "horizontal": value = 255 if y >= height//2 else 0
            elif name == "diagonal45": value = 255 if x >= 312 + y else 0
            elif name == "diagonal135": value = 255 if x >= 328 - y else 0
            elif name == "ramp": value = x * 255 // (WIDTH - 1)
            elif name == "checkerboard": value = 255 if ((x//8 + y//4) & 1) else 0
            elif name == "random": value = rng.randrange(256)
            else: raise ValueError(name)
            result.append(value)
    return result


def write_suite(root: Path, suite: str) -> dict:
    out = root / "results/phase5"
    out.mkdir(parents=True, exist_ok=True)
    if suite == "small":
        height = SMALL_HEIGHT
        names = ["black", "white", "impulse", "vertical", "horizontal",
                 "diagonal45", "diagonal135", "ramp", "checkerboard", "random"]
        frames = [(name, synthetic(name, height)) for name in names]
    elif suite == "full":
        height = FULL_HEIGHT
        frames = [("random_full", synthetic("random", height)),
                  ("monkey", monkey_gray(root / "images/monkey.bmp"))]
    else:
        raise ValueError(suite)
    stream = out / f"{suite}.stream"
    with stream.open("w", encoding="ascii", newline="\n") as handle:
        def blank(vs: int, cycles: int) -> None:
            handle.write(f"{vs} 0 0 0\n" * cycles)
        for name, image in frames:
            blank(0, 80)
            mem = out / f"{name}.mem"
            mem.write_text("".join(f"{v:02x}\n" for v in image), encoding="ascii")
            if name in ("black", "impulse", "vertical", "diagonal45", "random_full", "monkey"):
                png_gray(out / f"{name}_input.png", image, WIDTH, height)
            for y in range(height):
                for value in image[y*WIDTH:(y+1)*WIDTH]:
                    handle.write(f"1 1 1 {value}\n")
                blank(1, 24)
            blank(1, 128)
            blank(0, 40)
        blank(0, 160)
    info = {"suite": suite, "width": WIDTH, "height": height,
            "frames": [name for name, _ in frames],
            "pixels_per_frame": WIDTH * height,
            "stream": str(stream.relative_to(root)).replace("\\", "/"),
            "random_seed": RANDOM_SEED,
            "monkey_conversion": "24-bit BMP BGR decoded top-down; Y=(77R+150G+29B)>>8"}
    (out / f"{suite}.json").write_text(json.dumps(info, indent=2)+"\n", encoding="utf-8")
    return info
