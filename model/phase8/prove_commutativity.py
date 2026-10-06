"""Directed and randomized NMS/classification commutativity proof tests."""
import random

NEIGHBORS = {1:(3,5), 2:(2,6), 4:(1,7), 8:(0,8)}


def classify(mag, low, high):
    return 2 if mag > high else 1 if mag > low else 0


def nms_mag(magnitudes, direction):
    if direction not in NEIGHBORS:
        return 0
    a, b = NEIGHBORS[direction]
    center = magnitudes[4]
    return center if center > magnitudes[a] and center > magnitudes[b] else 0


def old_order(magnitudes, direction, low, high):
    # Phase 6 zeroes the *entire* packed neighbor path when below LOW.
    classified_mags = [m if classify(m, low, high) else 0 for m in magnitudes]
    center_class = classify(magnitudes[4], low, high)
    return center_class if nms_mag(classified_mags, direction) else 0


def new_order(magnitudes, direction, low, high):
    return classify(nms_mag(magnitudes, direction), low, high)


def main():
    vectors = 0
    special = (0,1,49,50,51,99,100,101,1023,1443,2047)
    for low, high in ((50,100),(25,75),(100,200)):
        for direction in (0,1,2,4,8,15):
            for center in special:
                for a in special:
                    for b in special:
                        values = [0]*9
                        values[4] = center
                        if direction in NEIGHBORS:
                            left, right = NEIGHBORS[direction]
                            values[left], values[right] = a,b
                        assert old_order(values,direction,low,high) == new_order(values,direction,low,high)
                        vectors += 1
        rng = random.Random(0x8CA11E + low)
        for _ in range(100000):
            values = [rng.randrange(2048) for _ in range(9)]
            direction = rng.choice((0,1,2,4,8,15))
            assert old_order(values,direction,low,high) == new_order(values,direction,low,high)
            vectors += 1
    print(f"PHASE8_NMS_COMMUTATIVITY_PASS vectors={vectors} mismatches=0")


if __name__ == "__main__":
    main()
