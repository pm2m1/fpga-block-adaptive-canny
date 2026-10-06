"""Directed semantics and exact-rule tests; run with python -m model.phase7.tests."""
from .full_hysteresis import full_hysteresis, one_pass, bounded_from_depth
from itertools import product


def case(rows):
    width = len(rows[0])
    assert all(len(row) == width for row in rows)
    return [dict(zip(".WS", (0, 1, 2)))[v] for row in rows for v in row], width


CASES = {
    "single_strong": ["S...."],
    "isolated_weak": ["W...."],
    "adjacent_weak": ["SW..."],
    "two_weak_chain": ["SWW.."],
    "five_weak_chain": ["SWWWWW."],
    "diagonal_chain": ["S.....", ".W....", "..W...", "...W..", "....W."],
    "branching_chain": ["..W..", ".WW..", "SWW..", ".WW..", "..W.."],
    "connected_loop": ["SWWWW", ".W..W", ".W..W", ".WWWW"],
    "weak_island": ["S.....", "......", "...WW.", "...WW."],
    "two_strong_bridge": ["SWWWWWS"],
}


def render(pixels, width):
    return "/".join("".join(str(v) for v in pixels[y:y+width])
                    for y in range(0, len(pixels), width))


def run():
    rows = []
    for name, image in CASES.items():
        classes, width = case(image)
        local = one_pass(classes, width)
        full, depths, histogram = full_hysteresis(classes, width)
        assert all(not a or b for a, b in zip(local, full)), name
        assert local == bounded_from_depth(depths, 1), name
        rows.append((name, "/".join(image), render(local, width),
                     render(full, width), sum(a != b for a, b in zip(local, full)),
                     max(depths)))
    classes, width = case(["SWWWW"])
    assert render(one_pass(classes, width), width) == "11000"
    assert render(full_hysteresis(classes, width)[0], width) == "11111"
    # Exhaust every 3^9 class window against the *literal* RTL equations
    # search=OR(each_cell[1]); high_low=center[1]|center[0]. This checks
    # the spatial implementation independently of hand-picked maps.
    checked = 0
    for cells in product((0, 1, 2), repeat=9):
        rtl_search = 0
        for klass in cells:
            rtl_search |= (klass >> 1) & 1
        rtl_high_low = (cells[4] >> 1) | (cells[4] & 1)
        rtl_edge = int(bool(rtl_search and rtl_high_low))
        assert one_pass(cells, 3)[4] == rtl_edge, cells
        checked += 1
    assert checked == 19683
    print("PHASE7_DIRECTED_PASS cases=10 rtl_equation_windows=19683 chain=SWWWW local=11000 full=11111")
    return rows


if __name__ == "__main__":
    for item in run():
        print(" | ".join(map(str, item)))
