"""Python model unit tests, including 1024-sample and bin boundaries."""
import random
from .block_adaptive import select_thresholds, exact_thresholds, process_frame


def main():
    empty = [0]*32
    assert select_thresholds(empty,0) == (0,0,0,False)
    for value in (1,63,64,65,127,128,2047):
        hist = [0]*32
        hist[value>>6] = 1024
        selected, high, low, active = select_thresholds(hist,1024)
        assert (selected,high,low,active) == (value>>6,max(1,(value>>6)<<6),
                                                (2*max(1,(value>>6)<<6))//5,True)
    rng = random.Random(0x810032)
    for _ in range(1000):
        values = [rng.randrange(2048) for _ in range(1024)]
        hist = [0]*32
        exact = [0]*2048
        for v in values:
            if v:
                hist[v>>6] += 1
                exact[v] += 1
        count = sum(hist)
        assert count <= 1024 and max(hist) <= 1024
        assert select_thresholds(hist,count)[3]
        assert exact_thresholds(exact,count)[2]
    blank = [0]*(640*480)
    blocks, classes, edge = process_frame(blank)
    assert len(blocks)==300 and not any(classes) and not any(edge)
    assert all(not b.active and b.nonzero_count==0 for b in blocks)
    print("PHASE8_PYTHON_MODEL_PASS randomized_blocks=1000 frame_blocks=300")


if __name__ == "__main__":
    main()
