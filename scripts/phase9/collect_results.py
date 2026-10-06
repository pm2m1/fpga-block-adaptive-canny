"""Collect actual Vivado/XSim results; never fabricate missing values."""
import csv
from pathlib import Path
import re

ROOT=Path(__file__).resolve().parents[2]
REPORTS=ROOT/'reports/phase9'
OUT=ROOT/'results/phase9/hardware_results.csv'


def read_text(path):
    raw=path.read_bytes()
    return raw.decode('utf-16') if raw.startswith((b'\xff\xfe',b'\xfe\xff')) else raw.decode('utf-8',errors='replace')


def utilization(path):
    if not path.exists():return {}
    patterns={
        'lut':r'^\|\s*Slice LUTs\*?\s*\|\s*(\d+)',
        'ff':r'^\|\s*Slice Registers\s*\|\s*(\d+)',
        'lutram':r'^\|\s*LUT as Memory\s*\|\s*(\d+)',
        'ramb18':r'^\|\s*RAMB18\s*\|\s*(\d+)',
        'ramb36':r'^\|\s*RAMB36/FIFO\*?\s*\|\s*(\d+)',
        'dsp':r'^\|\s*DSPs\s*\|\s*(\d+)',
    }
    content=read_text(path)
    return {key:int(m.group(1)) for key,pattern in patterns.items()
            if (m:=re.search(pattern,content,re.MULTILINE))}


def timing(path):
    if not path.exists():return ('','')
    text=read_text(path)
    match=re.search(r'WNS\(ns\)\s+TNS\(ns\).*?\r?\n\s*[- ]+\r?\n\s*(-?\d+\.\d+)\s+(-?\d+\.\d+)',
                    text,re.DOTALL)
    return match.groups() if match else ('','')


def cadence(tag):
    path=REPORTS/f'{tag}_two_adaptive_xsim.log'
    if not path.exists():return ''
    m=re.search(r'^PHASE9_RTL_PASS .*?frame_interval=(\d+)',
                read_text(path),re.MULTILINE)
    return int(m.group(1)) if m else ''


def main():
    rows=[]
    for size in (32,64):
        for bins in (8,16,32):
            tag=f'b{size}_h{bins}'
            util=utilization(REPORTS/f'{tag}_utilization.rpt')
            synth_wns,synth_tns=timing(REPORTS/f'{tag}_timing_synth.rpt')
            route_wns,route_tns=timing(REPORTS/f'{tag}_timing_route.rpt')
            cycles=cadence(tag)
            row=dict(block_size=size,bins=bins,blocks_per_frame=300 if size==32 else 80,
                     lut=util.get('lut',''),ff=util.get('ff',''),
                     lutram=util.get('lutram',''),ramb18=util.get('ramb18',''),
                     ramb36=util.get('ramb36',''),dsp=util.get('dsp',''),
                     bram18_equiv=(util['ramb18']+2*util['ramb36']) if
                     'ramb18' in util and 'ramb36' in util else '',
                     bram_percent=(100*(util['ramb18']+2*util['ramb36'])/270) if
                     'ramb18' in util and 'ramb36' in util else '',
                     synth_wns=synth_wns,synth_tns=synth_tns,
                     route_wns=route_wns,route_tns=route_tns,
                     frame_interval_cycles=cycles,
                     core_cadence_fps=(100_000_000/cycles) if cycles else '',
                     cycles_per_pixel=(cycles/307200) if cycles else '')
            rows.append(row)
    OUT.parent.mkdir(parents=True,exist_ok=True)
    with OUT.open('w',newline='') as handle:
        writer=csv.DictWriter(handle,fieldnames=list(rows[0]))
        writer.writeheader();writer.writerows(rows)
    for row in rows:print('PHASE9_HARDWARE',row)


if __name__=='__main__':main()
