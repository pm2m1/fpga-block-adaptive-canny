"""Generate the one board ROM and Phase 11 bit-accurate output oracles.

No RGB conversion is implemented in the FPGA. This repeats the single,
documented Phase 5 grayscale conversion and reuses the verified Phase 8/9
software front end, block thresholding, and causal one-pass promotion.
"""
from hashlib import sha256
import json
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.canny_fixed.images import monkey_gray, synthetic, png_gray
from model.phase8.frontend import Frontend
from model.phase9.block_adaptive import process_frame
from scripts.phase8.prepare_adaptive_oracle import local_edges

WIDTH, HEIGHT = 640, 480
TESTS = ('monkey', 'black', 'white', 'vertical', 'horizontal', 'checkerboard')
ROM = ROOT / 'images/phase11/monkey_gray.mem'
OUT = ROOT / 'results/phase11'


def expected_edges(image: list[int]) -> tuple[list[int], list]:
    assert len(image) == WIDTH * HEIGHT
    frontend = Frontend(WIDTH)
    nms = []
    def tick(vs: int, hs: int, de: int, pixel: int) -> None:
        frontend.tick(vs, hs, de, pixel)
        _, oh, od, mag = frontend.output
        if oh and od:
            nms.append(mag)
    for _ in range(80):
        tick(0, 0, 0, 0)
    for row in range(HEIGHT):
        for pixel in image[row*WIDTH:(row+1)*WIDTH]:
            tick(1, 1, 1, pixel)
        for _ in range(24):
            tick(1, 0, 0, 0)
    for _ in range(128):
        tick(1, 0, 0, 0)
    for _ in range(200):
        tick(0, 0, 0, 0)
    if len(nms) != WIDTH * HEIGHT:
        raise AssertionError(f'post-NMS count={len(nms)}')
    blocks, klass, _ = process_frame(nms, 32, 32, edges=False)
    assert len(blocks) == 300
    edge = local_edges([klass])
    assert len(edge) == WIDTH * HEIGHT
    return edge, blocks


def pack_edges(edge: list[int]) -> bytes:
    assert len(edge) == WIDTH * HEIGHT and len(edge) % 8 == 0
    return bytes(sum(edge[i+j] << (7-j) for j in range(8))
                 for i in range(0, len(edge), 8))


def main() -> None:
    ROM.parent.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)
    monkey = monkey_gray(ROOT / 'images/monkey.bmp')
    ROM.write_text(''.join(f'{p:02x}\n' for p in monkey), encoding='ascii')
    manifest = {'width': WIDTH, 'height': HEIGHT,
                'source_bmp': 'images/monkey.bmp',
                'conversion': '24-bit BMP BGR decoded top-down; Y=(77R+150G+29B)>>8',
                'rom_sha256': sha256(ROM.read_bytes()).hexdigest(),
                'rom_pixels': len(monkey),
                'output_packing': 'raster order; first pixel in byte bit 7 (MSB)',
                'tests': []}
    for test_id, name in enumerate(TESTS):
        image = monkey if name == 'monkey' else synthetic(name, HEIGHT)
        edge, blocks = expected_edges(image)
        packet = pack_edges(edge)
        path = OUT / f'{name}_golden.bin'
        path.write_bytes(packet)
        (OUT / f'{name}_golden.mem').write_text(
            ''.join(f'{byte:02x}\n' for byte in packet), encoding='ascii')
        png_gray(OUT / f'{name}_golden.png', edge, WIDTH, HEIGHT, scale_max=1)
        manifest['tests'].append(dict(id=test_id, name=name, pixels=len(edge),
            blocks=len(blocks), edge_pixels=sum(edge), golden_bytes=len(packet),
            golden_sha256=sha256(packet).hexdigest()))
        print(f'PHASE11_ASSET_PASS test={name} pixels={len(edge)} '
              f'blocks={len(blocks)} bytes={len(packet)} edges={sum(edge)}')
    (OUT / 'assets.json').write_text(json.dumps(manifest, indent=2)+'\n', encoding='utf-8')


if __name__ == '__main__':
    main()
