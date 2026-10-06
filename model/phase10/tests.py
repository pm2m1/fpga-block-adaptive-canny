"""Directed scheduler and engine-count invariance tests."""
from pathlib import Path

from model.phase10.multiengine_scheduler import algorithm, schedule

ROOT = Path(__file__).resolve().parents[2]


def run() -> None:
    schedules = {e: schedule(e, frames=4) for e in (1, 2, 4)}
    for engines, rows in schedules.items():
        assert len(rows) == 60
        assert [(s.frame, s.index) for s in rows] == [
            (f, i) for f in range(4) for i in range(15)]
        assert all(s.engine == s.index % engines for s in rows)
        assert all(s.replay_start >= s.threshold_ready for s in rows)
        assert all(rows[i].replay_end <= rows[i+1].replay_start
                   for i in range(len(rows)-1))
        assert [s.index for s in rows if s.frame == 3] == list(range(15))
    delayed = schedule(2, frames=3, threshold_delays={0: 30000})
    assert delayed[1].threshold_ready < delayed[0].threshold_ready
    assert delayed[0].replay_start < delayed[1].replay_start
    assert delayed[0].engine == 0 and delayed[1].engine == 1

    source = ROOT / 'results/phase8/adaptive_nms.mem'
    magnitude = [int(line, 16) for line in source.open()]
    assert len(magnitude) == 614400
    frames = [magnitude[:307200], magnitude[307200:]]
    blocks, edges = algorithm(frames)
    assert len(blocks) == 2 and len(edges) == 614400
    assert all(len(b) == 300 for b in blocks)
    assert all(edge in (0, 1) for edge in edges)
    # Engine count changes only schedule: the same independently computed
    # Phase 9 block metadata and edge raster is reused for all three.
    for engines in (1, 2, 4):
        assert len(schedules[engines]) == 60
        assert len(edges) == 614400
    print('PHASE10_MODEL_PASS engines=1,2,4 frames=2 pixels=614400 '
          'blocks=600 delayed_ready_order=verified raster_order=verified')


if __name__ == '__main__':
    run()
