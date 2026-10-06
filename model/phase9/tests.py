"""Run with: python -m model.phase9.tests"""
from pathlib import Path
import random

from model.phase8.block_adaptive import process_frame as phase8_frame
from model.phase9.block_adaptive import WIDTH, HEIGHT, geometry, counter_width, process_frame, select


def main():
    assert geometry(32) == (20, 15)
    assert geometry(64) == (10, 8)
    assert counter_width(32) == 11 and counter_width(64) == 13
    blank = [0] * (WIDTH*HEIGHT)
    for size in (32, 64):
        for bins in (8, 16, 32):
            blocks, classes, edges = process_frame(blank, size, bins)
            assert len(blocks) == (300 if size == 32 else 80)
            assert not any(classes) and not any(edges)
            assert all(not b.active and b.nonzero == 0 for b in blocks)
            if size == 64:
                assert all(b.pixels == 2048 for b in blocks[-10:])
                assert all(b.pixels == 4096 for b in blocks[:-10])
    values = [0] * (WIDTH*HEIGHT)
    rng = random.Random(0x59A100)
    for i in range(len(values)):
        values[i] = rng.randrange(2048) if i % 3 else 0
    old, old_classes, old_edges = phase8_frame(values)
    new, new_classes, new_edges = process_frame(values, 32, 32)
    assert new_classes == old_classes and new_edges == old_edges
    assert all((a.bx, a.by, a.nonzero, a.histogram, a.bin_index, a.high,
                a.low, a.active) ==
               (b.bx, b.by, b.nonzero_count, b.histogram, b.selected_bin,
                b.high, b.low, b.active) for a, b in zip(new, old))
    for size in (32, 64):
        for bins in (8, 16, 32, 2048):
            blocks, _, _ = process_frame(values, size, bins)
            assert sum(b.pixels for b in blocks) == WIDTH*HEIGHT
            assert all(sum(b.histogram) == b.nonzero for b in blocks)
            assert all(b.nonzero <= b.pixels for b in blocks)
    assert select([0]*7+[1024], 8)[1] == 7 << 8
    print('PHASE9_MODEL_TEST_PASS configurations=6 partial_row=32 phase8_equivalence=307200')


if __name__ == '__main__':
    main()
