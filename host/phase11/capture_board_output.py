"""Capture and numerically verify the Phase 11 USB-UART packet.

Wire format: CNY1, version 1, width/height uint16 LE, test ID uint8,
processing cycles uint32 LE, payload bytes uint32 LE, valid pixels uint32 LE,
packed MSB-first raster edge payload, payload CRC32 uint32 LE.
"""
import argparse
from pathlib import Path
import struct
import sys
import zlib

ROOT = Path(__file__).resolve().parents[2]
MAGIC = b'CNY1'
HEADER = struct.Struct('<4sBHHBIII')
TESTS = ('monkey', 'black', 'white', 'vertical', 'horizontal', 'checkerboard')


def decode(packet: bytes, golden: bytes | None = None) -> dict:
    if len(packet) < HEADER.size + 4:
        raise ValueError('truncated header')
    magic, version, width, height, test_id, cycles, count, pixels = HEADER.unpack_from(packet)
    if magic != MAGIC or version != 1:
        raise ValueError('bad sync/version')
    if (width, height, pixels, count) != (640, 480, 307200, 38400):
        raise ValueError(f'bad dimensions/count: {width}x{height}, {pixels} pixels, {count} bytes')
    if test_id >= len(TESTS):
        raise ValueError(f'bad test ID {test_id}')
    if len(packet) != HEADER.size + count + 4:
        raise ValueError(f'packet length {len(packet)}; expected {HEADER.size + count + 4}')
    payload = packet[HEADER.size:HEADER.size + count]
    crc_rx, = struct.unpack_from('<I', packet, HEADER.size + count)
    crc_calc = zlib.crc32(payload)
    if crc_rx != crc_calc:
        raise ValueError(f'CRC mismatch received={crc_rx:08x} calculated={crc_calc:08x}')
    mismatch = 0
    first = None
    if golden is not None:
        if len(golden) != count:
            raise ValueError('golden output has wrong length')
        for byte_i, (actual, expected) in enumerate(zip(payload, golden)):
            diff = actual ^ expected
            mismatch += diff.bit_count()
            if first is None and diff:
                for bit_i in range(8):
                    if diff & (1 << (7-bit_i)):
                        n = byte_i * 8 + bit_i
                        first = (n % width, n // width)
                        break
    return dict(test=TESTS[test_id], pixels=pixels, payload_bytes=count,
                processing_cycles=cycles, processing_ms=cycles / 100000,
                crc=f'{crc_rx:08x}', mismatches=mismatch, first_mismatch=first,
                payload=payload)


def save_png(payload: bytes, path: Path) -> None:
    from PIL import Image
    raw = bytes(255 if byte & (1 << (7-bit)) else 0
                for byte in payload for bit in range(8))
    image = Image.frombytes('L', (640, 480), raw)
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path)


def read_serial(port: str, timeout: float) -> bytes:
    try:
        import serial
    except ImportError as exc:
        raise RuntimeError('Install pyserial to capture a physical board') from exc
    # FPGA divider 868 gives 115207 baud; standard 115200 is 0.006% away.
    with serial.Serial(port, baudrate=115200, timeout=timeout) as dev:
        window = bytearray()
        while True:
            byte = dev.read(1)
            if not byte:
                raise TimeoutError('UART synchronization timeout')
            window += byte
            if len(window) > 4:
                del window[0]
            if window == MAGIC:
                break
        rest = dev.read(HEADER.size - 4)
        if len(rest) != HEADER.size - 4:
            raise TimeoutError('truncated UART header')
        header = MAGIC + rest
        _, _, _, _, _, _, count, _ = HEADER.unpack(header)
        if count != 38400:
            raise ValueError(f'unexpected payload length {count}')
        data = dev.read(count + 4)
        if len(data) != count + 4:
            raise TimeoutError(f'truncated UART payload {len(data)}/{count + 4}')
        return header + data


def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__)
    source = ap.add_mutually_exclusive_group(required=True)
    source.add_argument('--port', help='physical Nexys A7 USB-UART COM port')
    source.add_argument('--packet', type=Path, help='captured binary packet for offline verification')
    ap.add_argument('--timeout', type=float, default=20.0)
    ap.add_argument('--golden-dir', type=Path, default=ROOT / 'results/phase11')
    ap.add_argument('--output', type=Path, default=ROOT / 'results/phase11/board_capture.png')
    ap.add_argument('--save-packet', type=Path)
    args = ap.parse_args()
    packet = args.packet.read_bytes() if args.packet else read_serial(args.port, args.timeout)
    preliminary = decode(packet)
    golden = (args.golden_dir / f'{preliminary["test"]}_golden.bin').read_bytes()
    info = decode(packet, golden)
    save_png(info['payload'], args.output)
    if args.save_packet:
        args.save_packet.parent.mkdir(parents=True, exist_ok=True)
        args.save_packet.write_bytes(packet)
    for key, value in info.items():
        if key != 'payload':
            print(f'{key}={value}')
    print(f'checksum=PASS pixels_compared={info["pixels"]} status={"PASS" if info["mismatches"] == 0 else "FAIL"}')
    return 0 if info['mismatches'] == 0 else 1


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (ValueError, TimeoutError, RuntimeError, OSError) as error:
        print(f'BOARD_CAPTURE_FAIL: {error}', file=sys.stderr)
        sys.exit(2)
