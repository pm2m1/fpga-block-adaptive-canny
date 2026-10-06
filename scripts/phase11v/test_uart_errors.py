"""Offline corruption tests for the simulated Phase 11 packet."""
from pathlib import Path
import struct
import sys

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'host' / 'phase11'))
from capture_board_output import HEADER, decode  # noqa: E402

packet = (ROOT / 'results/phase11v/sim_uart_packet.bin').read_bytes()
golden = (ROOT / 'results/phase11/monkey_golden.bin').read_bytes()
assert decode(packet, golden)['mismatches'] == 0

cases = {}
damaged = bytearray(packet)
damaged[HEADER.size + 17] ^= 0x80
cases['payload_flip'] = bytes(damaged)
damaged = bytearray(packet)
damaged[-1] ^= 0x80
cases['crc_flip'] = bytes(damaged)
cases['truncated_header'] = packet[:10]
cases['truncated_payload'] = packet[:-100]
damaged = bytearray(packet)
struct.pack_into('<I', damaged, 14, 38399)
cases['wrong_payload_length'] = bytes(damaged)
cases['wrong_sync'] = b'BAD!' + packet[4:]
damaged = bytearray(packet)
damaged[4] = 2
cases['wrong_version'] = bytes(damaged)

for name, data in cases.items():
    try:
        decode(data, golden)
    except ValueError as exc:
        print(f'REJECTED {name}: {exc}')
    else:
        raise AssertionError(f'{name} incorrectly accepted')
print(f'PHASE11V_UART_ERROR_TEST_PASS cases={len(cases)}')
