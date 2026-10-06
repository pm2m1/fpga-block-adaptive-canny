"""Summarize measured Gaussian border samples from the Phase 5 RTL trace."""
from pathlib import Path

root = Path(__file__).resolve().parents[2]
trace = root / "results/phase5/small.trace"
report = root / "reports/phase5_border_observations.txt"
selected_frames = {1: "white_after_black", 2: "impulse_after_white"}
selected_y = {0, 1, 2, 3, 15}
selected_x = {0, 1, 2, 3, 100, 639}
lines = ["Gaussian output at protocol-associated coordinate (x,y).",
         "Frames are consecutive with no RAM pointer reset.",
         "The listed values are direct post-edge RTL observations, not assumed padding."]
sample_index = 0
with trace.open("r", encoding="ascii") as handle:
    for row in handle:
        tokens = row.split()
        if int(tokens[6]) and int(tokens[7]):
            frame = sample_index // (640 * 16)
            within = sample_index % (640 * 16)
            y, x = divmod(within, 640)
            if frame in selected_frames and y in selected_y and x in selected_x:
                lines.append(f"{selected_frames[frame]} frame={frame} x={x} y={y} "
                             f"gaussian={tokens[8]}")
            sample_index += 1
assert sample_index == 10 * 640 * 16
report.write_text("\n".join(lines) + "\n", encoding="utf-8")
print(f"border_observations={report} samples={sample_index}")
