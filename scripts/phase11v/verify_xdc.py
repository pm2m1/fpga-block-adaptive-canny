"""Check Phase 11 used pins against Digilent Nexys-A7-100T-Master.xdc.

Reference: https://github.com/Digilent/digilent-xdc/blob/master/Nexys-A7-100T-Master.xdc
The authoritative map was inspected on 2026-10-06; this script is offline.
"""
from pathlib import Path
import re

root = Path(__file__).resolve().parents[2]
xdc = (root / 'constraints/phase11/nexys_a7_100t_board.xdc').read_text()
expected = {
    'clk100mhz': ('E3', '100 MHz oscillator'),
    'cpu_resetn': ('C12', 'CPU reset button'),
    'start_btn': ('N17', 'center button'),
    'test_sel[0]': ('J15', 'switch 0'),
    'test_sel[1]': ('L16', 'switch 1'),
    'test_sel[2]': ('M13', 'switch 2'),
    'uart_tx_o': ('D4', 'USB-UART host RX'),
    'led[0]': ('H17', 'LED 0'),
    'led[1]': ('K15', 'LED 1'),
    'led[2]': ('J13', 'LED 2'),
    'led[3]': ('N14', 'LED 3'),
}
pattern = re.compile(r'set_property -dict \{PACKAGE_PIN (\w+) IOSTANDARD (\w+)\} '
                     r'\[get_ports (.+)\]')
found = {}
for pin, standard, raw_port in pattern.findall(xdc):
    port = raw_port.strip('{}')
    if port in found:
        raise AssertionError(f'duplicate XDC port {port}')
    found[port] = (pin, standard)
assert set(found) == set(expected), f'ports: missing {set(expected)-set(found)}, extra {set(found)-set(expected)}'
assert len(set(pin for pin, _ in found.values())) == len(found), 'duplicate FPGA pin'
for port, (pin, function) in expected.items():
    actual = found[port]
    assert actual == (pin, 'LVCMOS33'), f'{port}: expected {(pin, "LVCMOS33")}, got {actual}'
    print(f'{port},{pin},LVCMOS33,{function}')
assert 'create_clock -add -name sys_clk_pin -period 10.000' in xdc
assert 'set_property CFGBVS VCCO' in xdc
assert 'set_property CONFIG_VOLTAGE 3.3' in xdc
print(f'PHASE11V_XDC_AUDIT_PASS ports={len(found)} clock_ns=10.000')
