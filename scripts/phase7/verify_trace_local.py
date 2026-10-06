"""Replay actual Phase 6 NMS RTL trace into the cycle-exact local model."""
from pathlib import Path
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT))
from model.canny_fixed.hysteresis_local import LocalPromotion
from model.phase5b.window import Matrix3x3Phase5B


def main():
    local = LocalPromotion(640)
    local.matrix = Matrix3x3Phase5B(640, 2)
    count = 0
    old_nms = (0, 0, 0, 0)
    with (ROOT / "results/phase6/fixed.trace").open() as handle:
        for cycle, line in enumerate(handle):
            columns = line.split()
            if len(columns) != 33:
                raise AssertionError((cycle, len(columns)))
            nms = tuple(map(int, columns[25:29]))
            # All RTL stage flops sample the *previous* cycle's NMS outputs.
            local.tick(*old_nms)
            old_nms = nms
            actual = tuple(map(int, columns[29:33]))
            expected = local.outputs
            if actual[:3] != expected[:3]:
                raise AssertionError((cycle, "controls", actual, expected))
            if actual[1] and actual[2]:
                if actual[3] != expected[3]:
                    raise AssertionError((cycle, "pixel", actual, expected))
                count += 1
    assert count == 614400, count
    print(f"PHASE7_LOCAL_RTL_REPLAY_PASS valid_pixels={count} mismatches=0")


if __name__ == "__main__":
    main()
