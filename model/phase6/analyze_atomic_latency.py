"""Measure input-frame-start to prior-frame classification drain in RTL trace."""
from __future__ import annotations
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
out = ROOT / "results/phase6"
starts = []
input_last = None
class_last = None
class_first_next = None
input_pixels = 0
class_pixels = 0
prior_vs = 0
active_transitions = []
prior_active = (50, 100)
external_changes_in_frame0 = []
previous_external = (50, 100)
with (out / "atomic.trace").open() as source:
    for line in source:
        rt = [int(token) for token in line.split()]
        cycle, vs, hs, de = rt[:4]
        external = tuple(rt[5:7])
        active = tuple(rt[7:9])
        if vs and not prior_vs:
            starts.append(cycle)
        if active != prior_active:
            active_transitions.append({"cycle": cycle, "from": prior_active, "to": active})
        if len(starts) == 1 and external != previous_external:
            external_changes_in_frame0.append({"cycle": cycle, "to": external})
        if hs and de:
            if input_pixels == 307199:
                input_last = cycle
            input_pixels += 1
        if rt[22] and rt[23]:
            if class_pixels == 307199:
                class_last = cycle
            if class_pixels == 307200:
                class_first_next = cycle
            class_pixels += 1
        prior_vs, prior_active, previous_external = vs, active, external
if len(starts) != 2 or input_pixels != 614400 or class_pixels != 614400:
    raise AssertionError((starts, input_pixels, class_pixels))
if class_last is None or class_first_next is None or class_last >= starts[1]:
    raise AssertionError((class_last, class_first_next, starts))
if len(active_transitions) != 1 or tuple(active_transitions[0]["to"]) != (100, 200) or active_transitions[0]["cycle"] != starts[1]:
    raise AssertionError(active_transitions)
result = {"input_frame_start_cycles": starts,
          "frame0_last_input_pixel_cycle": input_last,
          "frame0_last_threshold_class_cycle": class_last,
          "frame1_first_threshold_class_cycle": class_first_next,
          "input_to_class_latency_cycles": class_last-input_last,
          "frame0_class_drained_before_next_capture_cycles": starts[1]-class_last,
          "external_changes_during_frame0": external_changes_in_frame0,
          "active_register_transitions": active_transitions}
(out / "atomic_latency.json").write_text(json.dumps(result, indent=2)+"\n")
print("PHASE6_ATOMIC_LATENCY_PASS", json.dumps(result, sort_keys=True))
