"""Parse real Phase 10 Vivado/XSim reports into reproducible CSV tables."""
import csv
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
REPORTS = ROOT / 'reports/phase10'
RESULTS = ROOT / 'results/phase10'
RESULTS.mkdir(parents=True, exist_ok=True)


def report(name: str) -> str:
    return (REPORTS / name).read_text(encoding='utf-8', errors='replace')


def log(name: str) -> str:
    data = (REPORTS / name).read_bytes()
    return data.decode('utf-16' if data.startswith((b'\xff\xfe', b'\xfe\xff'))
                       else 'utf-8', errors='replace')


def row_number(text: str, label: str) -> int:
    pattern = rf'^\|\s*{re.escape(label)}\s*\|\s*(\d+)\s*\|'
    match = re.search(pattern, text, re.MULTILINE)
    if not match:
        raise ValueError(f'Cannot find utilization row {label}')
    return int(match.group(1))


def timing(text: str) -> tuple[float, float]:
    match = re.search(r'^Setup\s*:\s*\d+\s+Failing Endpoints,\s*Worst Slack\s+([-+\d.]+)ns,\s*Total Violation\s+([-+\d.]+)ns', text, re.MULTILINE)
    if not match:
        raise ValueError('Cannot parse setup timing')
    return float(match.group(1)), float(match.group(2))


def critical(text: str) -> dict:
    section = text.split('Max Delay Paths', 1)[1]
    def find(pattern):
        match = re.search(pattern, section)
        if not match:
            raise ValueError(pattern)
        return match.group(1)
    return dict(startpoint=find(r'Source:\s+([^\n]+)'),
                endpoint=find(r'Destination:\s+([^\n]+)'),
                data_delay_ns=float(find(r'Data Path Delay:\s+([\d.]+)ns')),
                logic_delay_ns=float(find(r'Data Path Delay:.*?logic\s+([\d.]+)ns')),
                route_delay_ns=float(find(r'Data Path Delay:.*?route\s+([\d.]+)ns')),
                logic_levels=int(find(r'Logic Levels:\s+(\d+)')))


hardware, performance, utilization = [], [], []
base = None
for engines in (1, 2, 4):
    tag = f'e{engines}'
    util = report(f'{tag}_utilization_synth.rpt')
    sw, st = timing(report(f'{tag}_timing_synth.rpt'))
    rw, rt = timing(report(f'{tag}_timing_route.rpt'))
    h = dict(engines=engines, lut=row_number(util, 'Slice LUTs*'),
             ff=row_number(util, 'Slice Registers'),
             lutram=row_number(util, 'LUT as Memory'),
             ramb18=row_number(util, 'RAMB18E1 only'),
             ramb36=row_number(util, 'RAMB36E1 only'),
             dsp=row_number(util, 'DSPs'),
             synth_wns=sw, synth_tns=st, route_wns=rw, route_tns=rt)
    h['bram18_equiv'] = h['ramb18'] + 2 * h['ramb36']
    h['lut_percent'] = 100 * h['lut'] / 63400
    h['ff_percent'] = 100 * h['ff'] / 126800
    h['lutram_percent'] = 100 * h['lutram'] / 19000
    h['bram_percent'] = 100 * h['bram18_equiv'] / 270
    if base is None:
        base = h
    for field in ('lut', 'ff', 'lutram', 'bram18_equiv', 'dsp'):
        h[f'delta_{field}'] = h[field] - base[field]
        h[f'ratio_{field}'] = h[field] / base[field] if base[field] else None
    h.update(critical(report(f'{tag}_timing_route.rpt')))
    hardware.append(h)

    sim = log(f'{tag}_two_xsim.log')
    match = re.search(rf'PHASE10_RTL_PASS engines={engines} suite=two frames=2 pixels=614400 blocks=600 mismatches=0 unknowns=0 first_latency=(\d+) frame_interval=(\d+) last_latency=(\d+)', sim)
    if not match:
        raise ValueError(f'{tag} missing exact simulation pass marker')
    first_latency, cadence, last_latency = map(int, match.groups())
    service = [int(n) for n in re.findall(r'PHASE10_ADAPT_SERVICE frame=\d+ cycles=(\d+)', sim)]
    if len(service) != 2 or service[0] != service[1]:
        raise ValueError(f'{tag} adaptive service measurements inconsistent')
    for engine, fill, scan, replay, busy, observed, idle in re.findall(
        r'PHASE10_ENGINE_UTIL engine=(\d+) fill=(\d+) scan=(\d+) replay=(\d+) busy=(\d+) observed=(\d+) idle=(\d+)', sim):
        rec = dict(engines=engines, engine=int(engine), fill_cycles=int(fill),
                   scan_cycles=int(scan), replay_cycles=int(replay),
                   active_cycles=int(busy), observed_cycles=int(observed),
                   idle_cycles=int(idle))
        rec['utilization'] = rec['active_cycles'] / rec['observed_cycles']
        utilization.append(rec)
    isolation = log(f'{tag}_isolate_xsim.log')
    if f'PHASE10_RTL_PASS engines={engines} suite=isolate frames=4 pixels=1228800 blocks=1200 mismatches=0 unknowns=0' not in isolation:
        raise ValueError(f'{tag} isolation did not pass')
    p = dict(engines=engines, adaptive_cycles=service[0],
             frame_cadence_cycles=cadence, first_output_latency=first_latency,
             last_output_latency=last_latency,
             core_cadence_fps=100_000_000 / cadence,
             cycles_per_pixel=cadence / 307200)
    performance.append(p)

for p in performance:
    p['adaptive_speedup'] = performance[0]['adaptive_cycles'] / p['adaptive_cycles']
    p['adaptive_efficiency'] = p['adaptive_speedup'] / p['engines']
    p['system_speedup'] = performance[0]['frame_cadence_cycles'] / p['frame_cadence_cycles']
    p['system_efficiency'] = p['system_speedup'] / p['engines']


def write_csv(name: str, rows: list[dict]) -> None:
    with (RESULTS / name).open('w', newline='', encoding='utf-8') as handle:
        writer = csv.DictWriter(handle, fieldnames=list(rows[0]))
        writer.writeheader()
        writer.writerows(rows)


write_csv('hardware_results.csv', hardware)
write_csv('performance_results.csv', performance)
write_csv('engine_utilization.csv', utilization)
print('PHASE10_RESULTS_PASS counts=1,2,4 routed=3 simulations=6')
