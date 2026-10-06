"""Preserve Phase-4 deterministic vectors, adding only a pipeline drain before reset."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
source = ROOT / "results/phase4/cordic_vectors.txt"
destination = ROOT / "results/phase4b/cordic_vectors.txt"
rows = source.read_text(encoding="ascii").splitlines()
first_active = next(i for i, row in enumerate(rows) if row.startswith("1 "))
mid_reset = next(i for i in range(first_active + 1, len(rows)) if rows[i].startswith("0 "))
# The directed region alternates valid/bubbles; its first reset follows all
# directed vectors. Find the run of two reset rows after the first 100 lines.
mid_reset = next(i for i in range(100, len(rows) - 1)
                 if rows[i].startswith("0 ") and rows[i + 1].startswith("0 "))
drain = ["1 0 0 1 1 0 0 1"] * 20
destination.parent.mkdir(parents=True, exist_ok=True)
destination.write_text("\n".join(rows[:mid_reset] + drain + rows[mid_reset:]) + "\n",
                       encoding="ascii")
assert sum(int(r.split()[5]) for r in rows) == sum(
    int(r.split()[5]) for r in destination.read_text(encoding="ascii").splitlines())
print(f"phase4b_vectors={destination} valid_inputs={sum(int(r.split()[5]) for r in rows)}")
