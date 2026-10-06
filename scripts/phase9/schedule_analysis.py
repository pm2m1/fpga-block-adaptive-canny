"""Analytical stripe schedule, independent of the Canny front-end latency.

Uses the tested 640 active + 24 blank clocks per line. No vertical blank is
assumed, which is stricter than the Phase 8 stimulus and exposes frame-wrap
bank hazards. One scan/clear engine and one raster replay engine are modeled.
"""
from math import ceil


def schedule(block, bins, banks, frames=3):
    assert block in (32, 64) and bins in (8, 16, 32)
    stripes = ceil(480 / block)
    columns = 640 // block
    entries = columns * bins
    bank_free = [0] * banks
    scan_free = replay_free = 0
    input_cycle = 0
    records = []
    for stripe_id in range(frames * stripes):
        local_id = stripe_id % stripes
        rows = min(block, 480-local_id*block)
        bank = stripe_id % banks
        fill_start = input_cycle
        if fill_start < bank_free[bank]:
            return False, dict(stripe=stripe_id, bank=bank, fill_start=fill_start,
                               bank_free=bank_free[bank], deficit=bank_free[bank]-fill_start), records
        fill_end = fill_start + rows * (640+24)
        scan_start = max(fill_end, scan_free)
        threshold_ready = scan_start + entries + 2  # launch + bins + drain
        scan_free = threshold_ready + entries  # synchronous clear
        replay_start = max(threshold_ready, replay_free)
        replay_end = replay_start + rows*641 - 1
        replay_free = replay_end
        bank_free[bank] = max(scan_free, replay_end)
        records.append(dict(stripe=stripe_id, rows=rows, bank=bank,
                            fill_start=fill_start, fill_end=fill_end,
                            threshold_ready=threshold_ready,
                            scan_clear_end=scan_free, replay_start=replay_start,
                            replay_end=replay_end, bank_free=bank_free[bank]))
        input_cycle = fill_end
    return True, None, records


if __name__ == '__main__':
    for block in (32, 64):
        for bins in (8, 16, 32):
            for banks in (2, 3):
                safe, collision, records = schedule(block, bins, banks)
                print(f'block={block} bins={bins} banks={banks} safe={safe} '
                      f'collision={collision}')
                if block == 64 and banks == 2:
                    assert not safe and collision['stripe'] == 8
                if banks == 3:
                    assert safe
