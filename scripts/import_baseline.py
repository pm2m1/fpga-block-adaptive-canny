"""Copy the streaming baseline from the original RAR into this new workspace.

The original project is opened for reading only. Refuse to overwrite any output.
"""
from __future__ import annotations

import csv
import difflib
import hashlib
import subprocess
from pathlib import Path

workspace = Path(__file__).resolve().parents[1]
root = workspace.parent
archive = root / "final project.rar"
project_rel = Path("final project/Hardware-Implementation-of-the-Canny-Edge-Detection-Algorithm-main")
project = root / project_rel
rtl_names = [
    "canny_edge_detect_top.v", "canny_get_grandient.v", "canny_nonLocalMaxValue.v",
    "cordic_pipline.v", "cordic_sqrt.v", "fifo_ram.v", "matrix_generate_3x3.v",
    "vip_gaussian_filter.v", "canny_doubleThreshold.v", "one_column_ram.v",
    "VIP_RGB888_YCbCr444.v",
]
tb_names = ["sim_cmos_tb.sv", "canny_tb.sv", "video_to_pic.sv", "cordic_sqrt_tb.v"]

def sha(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()

def write_new(path: Path, data: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("xb") as stream:
        stream.write(data)

def archive_member(relative: Path) -> bytes:
    result = subprocess.run(
        ["tar", "-xOf", str(archive), str(project_rel / relative).replace("\\", "/")],
        stdout=subprocess.PIPE, stderr=subprocess.PIPE, check=True,
    )
    return result.stdout

for name in ["baseline_original", "rtl", "tb", "models", "images", "scripts", "constraints", "vivado", "reports", "results", "docs", "checkpoints"]:
    (workspace / name).mkdir(exist_ok=True)

hash_rows = []
diff_lines = []
for subdir, names, working_dir in [
    (Path("1.RTL/source"), rtl_names, Path("rtl/baseline")),
    (Path("1.RTL/sim"), tb_names, Path("tb/baseline")),
]:
    for name in names:
        relative = subdir / name
        archived = archive_member(relative)
        extracted = (project / relative).read_bytes()
        write_new(workspace / "baseline_original/archive" / relative, archived)
        write_new(workspace / working_dir / name, archived)
        hash_rows.append((str(relative), sha(archived), sha(extracted), "same" if archived == extracted else "different"))
        if archived != extracted:
            write_new(workspace / "baseline_original/extracted_differences" / relative, extracted)
            old = archived.decode("latin-1").splitlines()
            new = extracted.decode("latin-1").splitlines()
            diff_lines.extend(difflib.unified_diff(old, new, fromfile=f"archive/{relative}", tofile=f"extracted/{relative}", lineterm=""))

for relative, destination in [
    (Path("5.Pic/monkey.bmp"), Path("images/monkey.bmp")),
    (Path("3.Vivado_Project/CannyEdgeDetection.xpr"), Path("baseline_original/archive/CannyEdgeDetection.xpr")),
    (Path("README.md"), Path("baseline_original/archive/README.md")),
]:
    archived = archive_member(relative)
    extracted = (project / relative).read_bytes()
    write_new(workspace / destination, archived)
    hash_rows.append((str(relative), sha(archived), sha(extracted), "same" if archived == extracted else "different"))

with (workspace / "reports/import_hashes.csv").open("x", newline="", encoding="utf-8") as file:
    writer = csv.writer(file)
    writer.writerow(["relative_source_path", "archive_sha256", "extracted_sha256", "comparison"])
    writer.writerows(hash_rows)
write_new(workspace / "reports/archive_extracted_diff.txt", ("\n".join(diff_lines) + "\n").encode("utf-8"))
print(f"Imported {len(rtl_names)} RTL, {len(tb_names)} testbench, one BMP, XPR and README from archive.")
print("Differences:", ", ".join(row[0] for row in hash_rows if row[3] == "different"))
