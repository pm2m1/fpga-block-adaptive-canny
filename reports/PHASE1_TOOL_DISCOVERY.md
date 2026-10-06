# Phase 1 Vivado/XSim tool discovery

## Current discovery (2026-10-03): READY

The previous **BLOCKED — Vivado/XSim not found** finding below is historical and superseded. Vivado 2026.1 is now installed. All four tools were invoked successfully by absolute path, without depending on or permanently changing PATH:

| Tool | Absolute path | Version result |
|---|---|---|
| Vivado | `C:\AMDDesignTools\2026.1\Vivado\bin\vivado.bat` | `vivado v2026.1 (64-bit)`; `-version` printed the version but returned exit code 1 |
| XVLOG | `C:\AMDDesignTools\2026.1\Vivado\bin\xvlog.bat` | `Vivado Simulator v2026.1`, exit code 0 |
| XELAB | `C:\AMDDesignTools\2026.1\Vivado\bin\xelab.bat` | `Vivado Simulator v2026.1`, exit code 0 |
| XSIM | `C:\AMDDesignTools\2026.1\Vivado\bin\xsim.bat` | `Vivado Simulator v2026.1`, exit code 0 |

**PATH was not used.** The AMD 2026.1 Windows batch startup fails when its current directory includes the original `2nd year(2nd sem)` path; `setupEnv.bat` expands that path inside CMD parentheses. `scripts/run_phase1_xsim.ps1` temporarily maps only this protected workspace to `W:` for the tool process and removes the mapping afterward. This avoids modifying AMD installation files, system PATH, or any original project file. The recommended invocation is `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_phase1_xsim.ps1` from this protected workspace.

## Historical discovery before Vivado 2026.1 installation (superseded)

Result on this Windows machine: **no usable Vivado/XSim installation was detected on the accessible C: and D: drives**. This is a discovery result, not proof that the historic project was never run with Vivado. Phase 1 remains **FAIL / untested** because compilation, elaboration, and simulation could not start. No install, uninstall, upgrade, system PATH change, or Phase 2 action was performed.

| Requested field | Finding |
|---|---|
| Vivado installed | **NO usable installation detected** on accessible C:/D: |
| Detected version | **None currently runnable.** Historic original-project `3.Vivado_Project/vivado.log:2` reports Vivado 2024.1, and registry has 2024.1 DocNav/Information Center entries; these do not establish a present simulator installation. |
| Actual executable paths | None found for `vivado`, `xvlog`, `xelab`, `xsim` by PATH or named install roots. Full-drive searches found neither `vivado.bat`, `xvlog.bat`, `vivado.exe`, nor `xsim.exe` on C: or D:. |
| Was PATH the problem? | **No evidence of a PATH-only problem.** PATH has no Xilinx/Vivado/Vitis entry, but the expected installation roots and full-drive executable searches also found no tool binaries. |
| `xvlog` found | **NO** (`where.exe`, `Get-Command`, four named roots, C:/D: `xvlog.bat` search). |
| `xelab` found | **NO** (`where.exe`, `Get-Command`, four named roots; no Vivado bin directory located). |
| `xsim` found | **NO** (`where.exe`, `Get-Command`, four named roots, C:/D: `xsim.exe` search). |
| Recommended invocation | If a Vivado installation is supplied later, run `powershell -NoProfile -ExecutionPolicy Bypass -File scripts/run_baseline_sim.ps1 -VivadoBin 'C:\path\to\Vivado\bin'` from this workspace. This uses explicit paths for `xvlog`, `xelab`, and `xsim`; no permanent PATH change. If only `vivado` is available or direct XSim fails, use a project-local `vivado -mode batch -source <Phase-1-only Tcl>` flow after locating its real executable; this conditional fallback was not run because no Vivado executable exists locally. |

## Checks performed

1. `where.exe vivado`, `where.exe xvlog`, `where.exe xelab`, `where.exe xsim`: each returned “Could not find files for the given pattern(s).” PowerShell `Get-Command <name> -ErrorAction SilentlyContinue` returned no command for all four.
2. Explicit checks of `C:\Xilinx\Vivado`, `C:\AMD\Vivado`, `D:\Xilinx\Vivado`, and `D:\AMD\Vivado`: all four roots absent. At each 2024.1 path, `bin\vivado.bat`, `bin\xvlog.bat`, `bin\xelab.bat`, `bin\xsim.bat`, and `settings64.bat` were absent.
3. Checked standard Program Files/AppData candidates and uninstall registry. `C:\Program Files\AMD` exists without Vivado; AppData AMD entries are graphics-driver caches. `AppData\Roaming\Xilinx\Vivado` contains user-profile data, not a found executable. Registry lists “Xilinx DocNav (C:\Xilinx)” and “Xilinx Information Center (C:\Xilinx)” 2024.1 plus a cable driver pointing at a now-absent `C:\Xilinx\Vivado\2024.1` path. No Vivado/Vitis toolchain entry was found.
4. `where.exe /R C:\ vivado.bat`, `xvlog.bat`, `vivado.exe`, `xsim.exe` and the same four searches on D: all completed with no match. C: and D: are the two mounted filesystem drives.
5. Attempted `vivado -version`, `xvlog --version`, `xelab --version`, and `xsim --version`; each failed with PowerShell `CommandNotFoundException`, so no current version can be verified.
6. Retried `scripts/run_baseline_sim.ps1` after extending its search to the named C:/D: roots and `.bat`/`.exe` variants. It stopped before compilation with “XSim not found”; no xvlog/xelab/xsim log or output BMP was produced.

No source RTL or testbench was altered during this discovery. The updated runner and this report are inside `Canny_BlockAdaptive_A100T` only.
