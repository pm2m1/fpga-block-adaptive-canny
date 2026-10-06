"""Independent schedule and algorithm views for the 32x32/32-bin engine.

The algorithm always delegates to the verified Phase 9 oracle. The timing
model represents one input pixel/clock, ordered one-stripe-at-a-time replay,
and two local banks/engine. Its cycle estimates are analytical; XSim measured
cycle counters, not this model, are authoritative for Phase 10 performance.
"""
from dataclasses import dataclass

from model.phase9.block_adaptive import process_frame
from scripts.phase8.prepare_adaptive_oracle import local_edges

FRAME_W = 640
FRAME_H = 480
STRIPES = 15
STRIPE_PIXELS = 640 * 32
STRIPE_INPUT_CYCLES = 32 * (640 + 24)
FRAME_INPUT_CYCLES = 318968
HIST_ENTRIES = 20 * 32
REPLAY_CYCLES = 32 * 641 - 1


@dataclass(frozen=True)
class Stripe:
    frame: int
    index: int
    engine: int
    bank: int
    fill_start: int
    fill_end: int
    threshold_ready: int
    histogram_clear_end: int
    replay_start: int
    replay_end: int


def algorithm(magnitude_frames: list[list[int]]) -> tuple[list, list[list[int]]]:
    """Return Phase 9 block metadata and exact hardware-semantic edge rasters.

    ENGINE_COUNT is intentionally absent: replication cannot change pixels.
    """
    blocks, classes = [], []
    for frame in magnitude_frames:
        assert len(frame) == FRAME_W * FRAME_H
        frame_blocks, frame_classes, _ = process_frame(frame, 32, 32, edges=False)
        blocks.append(frame_blocks)
        classes.append(frame_classes)
    return blocks, local_edges(classes)


def schedule(engine_count: int, frames: int = 3,
             threshold_delays: dict[int, int] | None = None) -> list[Stripe]:
    if engine_count not in (1, 2, 4):
        raise ValueError('ENGINE_COUNT must be 1, 2, or 4')
    threshold_delays = threshold_delays or {}
    bank_free = [[0, 0] for _ in range(engine_count)]
    scan_free = [0] * engine_count
    replay_free = 0
    rows = []
    for frame in range(frames):
        for stripe in range(STRIPES):
            absolute_stripe = frame * STRIPES + stripe
            engine = stripe % engine_count
            local_stripe = sum(1 for earlier in range(absolute_stripe)
                               if (earlier % STRIPES) % engine_count == engine)
            bank = local_stripe % 2
            fill_start = frame * FRAME_INPUT_CYCLES + stripe * STRIPE_INPUT_CYCLES
            if fill_start < bank_free[engine][bank]:
                raise AssertionError((engine_count, frame, stripe, engine, bank,
                                      fill_start, bank_free[engine][bank]))
            fill_end = fill_start + STRIPE_INPUT_CYCLES
            scan_start = max(fill_end, scan_free[engine])
            ready = scan_start + HIST_ENTRIES + 2 + threshold_delays.get(absolute_stripe, 0)
            clear_end = ready + HIST_ENTRIES
            scan_free[engine] = clear_end
            replay_start = max(ready, replay_free)
            replay_end = replay_start + REPLAY_CYCLES
            replay_free = replay_end
            bank_free[engine][bank] = max(clear_end, replay_end)
            rows.append(Stripe(frame, stripe, engine, bank, fill_start, fill_end,
                               ready, clear_end, replay_start, replay_end))
    assert len(rows) == frames * STRIPES
    assert all(rows[i].replay_start >= rows[i-1].replay_end for i in range(1, len(rows)))
    return rows


def self_test() -> None:
    for engines in (1, 2, 4):
        rows = schedule(engines)
        assert [s.engine for s in rows[:15]] == [i % engines for i in range(15)]
        assert all(sum(s.frame == f for s in rows) == 15 for f in range(3))
        assert all(rows[f*15+1].fill_start - rows[f*15].fill_start ==
                   STRIPE_INPUT_CYCLES for f in range(3))
        print(f'PHASE10_SCHEDULE_PASS engines={engines} stripes={len(rows)} '
              f'first_ready={rows[0].threshold_ready} '
              f'last_ready={rows[14].threshold_ready} '
              f'frame_replay_interval={rows[15].replay_start-rows[0].replay_start}')


if __name__ == '__main__':
    self_test()
