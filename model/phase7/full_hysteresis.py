"""Independent 8-connected flood-fill reference and bounded comparison.

The input is the *post-NMS* class raster: 0=none, 1=weak, 2=strong.
Coordinates are class-map coordinates, not the delayed output sample index
of the production streaming window.
"""
from collections import deque


def _validate(classes, width):
    if width <= 0 or len(classes) % width:
        raise ValueError("nonrectangular class map")
    if any(v not in (0, 1, 2) for v in classes):
        raise ValueError("classes must be 0, 1, or 2")


def _neighbors(index, width, height):
    x, y = index % width, index // width
    for dy in (-1, 0, 1):
        yy = y + dy
        if not 0 <= yy < height:
            continue
        for dx in (-1, 0, 1):
            xx = x + dx
            if (dx or dy) and 0 <= xx < width:
                yield yy * width + xx


def full_hysteresis(classes, width):
    """Return (binary output, BFS depth map, depth histogram).

    All original strong pixels start at depth 0. Each weak pixel gets the
    shortest number of weak-neighbor steps from an original strong pixel.
    Unreachable pixels have depth -1. A deque makes propagation independent
    of raster scanning order.
    """
    _validate(classes, width)
    height = len(classes) // width
    depths = [-1] * len(classes)
    queue = deque()
    for i, klass in enumerate(classes):
        if klass == 2:
            depths[i] = 0
            queue.append(i)
    histogram = [len(queue)]
    while queue:
        source = queue.popleft()
        depth = depths[source] + 1
        for neighbor in _neighbors(source, width, height):
            if classes[neighbor] == 1 and depths[neighbor] < 0:
                depths[neighbor] = depth
                queue.append(neighbor)
                if depth >= len(histogram):
                    histogram.extend([0] * (depth + 1 - len(histogram)))
                histogram[depth] += 1
    return bytearray(d >= 0 for d in depths), depths, histogram


def one_pass(classes, width):
    """Conceptual 3x3 spatial rule from the Phase 6 RTL, no recursion."""
    _validate(classes, width)
    height = len(classes) // width
    result = bytearray(len(classes))
    for i, klass in enumerate(classes):
        if klass == 2:
            result[i] = 1
        elif klass == 1:
            result[i] = int(any(classes[n] == 2 for n in _neighbors(i, width, height)))
    return result


def bounded_from_depth(depths, passes):
    """Synchronous promotion after at most `passes` neighbor iterations."""
    if passes < 0:
        raise ValueError(passes)
    return bytearray(0 <= depth <= passes for depth in depths)
