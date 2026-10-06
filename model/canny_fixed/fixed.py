"""Explicit hardware-width helpers; Python integers otherwise have unlimited width."""

def unsigned(value: int, width: int) -> int:
    return value & ((1 << width) - 1)


def signed(value: int, width: int) -> int:
    value = unsigned(value, width)
    sign_bit = 1 << (width - 1)
    return value - (1 << width) if value & sign_bit else value


def saturate_unsigned(value: int, width: int) -> int:
    return max(0, min(value, (1 << width) - 1))
