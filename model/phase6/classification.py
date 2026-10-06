"""Strict-comparison 11-bit Phase 6 class and gradient packing."""


def validate_thresholds(low: int, high: int) -> None:
    if not (0 <= low < high <= 2047):
        raise ValueError(f"invalid threshold pair LOW={low} HIGH={high}; require 0 <= LOW < HIGH <= 2047")


def classify(magnitude: int, direction: int, low: int, high: int) -> int:
    validate_thresholds(low, high)
    if not (0 <= magnitude <= 2047 and 0 <= direction <= 15):
        raise ValueError((magnitude, direction))
    if magnitude > high:
        return (2 << 15) | (direction << 11) | magnitude
    if magnitude > low:
        return (1 << 15) | (direction << 11) | magnitude
    return 0
