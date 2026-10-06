"""Offline host-protocol self-test; this is not physical-board validation."""
import struct
import zlib
from pathlib import Path
from capture_board_output import HEADER, decode

ROOT = Path(__file__).resolve().parents[2]
payload = (ROOT / 'results/phase11/monkey_golden.bin').read_bytes()
packet = HEADER.pack(b'CNY1', 1, 640, 480, 0, 339885, len(payload), 307200)
packet += payload + struct.pack('<I', zlib.crc32(payload))
result = decode(packet, payload)
assert result['mismatches'] == 0 and result['pixels'] == 307200
try:
    damaged = bytearray(packet)
    damaged[HEADER.size + 5] ^= 1
    decode(bytes(damaged), payload)
except ValueError as exc:
    assert 'CRC mismatch' in str(exc)
else:
    raise AssertionError('corrupted packet was accepted')
print('PHASE11_HOST_PROTOCOL_PASS pixels=307200 mismatches=0 crc_corruption_rejected=1')
