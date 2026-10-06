"""Deterministic Python-oracle vectors for the standalone RTL classifier."""
from pathlib import Path
from .classification import classify, validate_thresholds

ROOT = Path(__file__).resolve().parents[2]
PAIRS = ((50, 100), (0, 1), (10, 20), (100, 200),
         (500, 1000), (1000, 1500), (1500, 2000))
EXPLICIT = (0, 49, 50, 51, 99, 100, 101, 1023, 1443, 2047)


def generate() -> int:
    out = ROOT / "results/phase6"
    out.mkdir(parents=True, exist_ok=True)
    vectors = []
    for low, high in PAIRS:
        magnitudes = set(EXPLICIT)
        magnitudes.update(v for threshold in (low, high)
                          for v in (threshold-1, threshold, threshold+1)
                          if 0 <= v <= 2047)
        for magnitude in sorted(magnitudes):
            for direction in (1, 2, 4, 8):
                expected = classify(magnitude, direction, low, high)
                vectors.append((magnitude, direction, low, high, expected))
    for low, high in ((0, 0), (100, 50), (2047, 2047), (-1, 1), (1, 2048)):
        try:
            validate_thresholds(low, high)
        except ValueError:
            pass
        else:
            raise AssertionError(f"invalid pair accepted: {(low, high)}")
    (out / "boundary_vectors.txt").write_text(
        "".join(" ".join(map(str, row)) + "\n" for row in vectors), encoding="ascii")
    print(f"PHASE6_BOUNDARY_VECTORS pairs={len(PAIRS)} vectors={len(vectors)} invalid_pairs_rejected=5")
    return len(vectors)


if __name__ == "__main__":
    generate()
