#!/usr/bin/env python3
"""Decrypt and dump a pop'n rhythmin ``.chr`` character-data file (rb420).

The downloaded ``chara_%03d.chr`` files (in the app's Application Support
directory) are BFCodec-encrypted JSON describing preferred music / chara sets,
unlock bits, etc. They use the same key scheme as the ``.orb`` song packages:
the obfuscated key (``key[i] + i``) spells ``Popn Orbit Note. xjr1300.``, whose
MD5 is the 16-byte Blowfish key; the payload is CBC-deciphered with a fixed IV
and an 8-byte ``[origLen][paddedLen]`` big-endian length trailer (see
``CharaManager::charaDecodeChr`` / ``BFCodec``).

The Blowfish P/S init boxes are read from the reconstruction's
``Project/System/src/Util/bf_init_bytes.inc`` (found relative to this tool, or
via ``--bf-init``). The decrypted payload is lenient JSON (trailing commas), so
the tool strips those before parsing and pretty-prints; ``--raw`` prints the
decrypted bytes verbatim.

Usage::

    tools/chr_dump.py chara001.chr
    tools/chr_dump.py chara001.chr --raw
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import struct
import sys
from pathlib import Path

MASK = 0xFFFFFFFF
KEY_PLAINTEXT = b'Popn Orbit Note. xjr1300.'
# Fixed CBC IV (Ghidra: the 8-byte constant BFCodec seeds the chain with).
IV = (0xE3, 0x66, 0x31, 0xDA, 0x2C, 0x85, 0xA0, 0x64)


class Blowfish:
    """Minimal Blowfish (ECB block) seeded from the shipped init boxes + key."""

    def __init__(self, init_boxes: list[int], key: bytes):
        self.p = init_boxes[:18]
        self.s = [init_boxes[18 + box * 256:18 + box * 256 + 256] for box in range(4)]
        # Key schedule: XOR the P array with the (cycled) key, then re-encrypt the
        # P and S boxes through the cipher itself.
        j = 0
        for i in range(18):
            word = ((key[j % 16] << 24) | (key[(j + 1) % 16] << 16) | (key[(j + 2) % 16] << 8)
                    | key[(j + 3) % 16])
            self.p[i] ^= word
            j += 4
        left = right = 0
        for i in range(0, 18, 2):
            left, right = self._encrypt(left, right)
            self.p[i], self.p[i + 1] = left, right
        for box in range(4):
            for i in range(0, 256, 2):
                left, right = self._encrypt(left, right)
                self.s[box][i], self.s[box][i + 1] = left, right

    def _f(self, x: int) -> int:
        a, b, c, d = (x >> 24) & 0xFF, (x >> 16) & 0xFF, (x >> 8) & 0xFF, x & 0xFF
        return (((self.s[0][a] + self.s[1][b]) & MASK) ^ ((self.s[2][c] + self.s[3][d]) & MASK)) \
            & MASK

    def _encrypt(self, left: int, right: int) -> tuple[int, int]:
        for i in range(0, 16, 2):
            left ^= self.p[i]
            right = (right ^ self._f(left)) & MASK
            right ^= self.p[i + 1]
            left = (left ^ self._f(right)) & MASK
        left ^= self.p[16]
        right ^= self.p[17]
        return right & MASK, left & MASK  # halves swapped

    def decrypt(self, left: int, right: int) -> tuple[int, int]:
        for i in range(16, 1, -2):
            left ^= self.p[i + 1]
            right = (right ^ self._f(left)) & MASK
            right ^= self.p[i]
            left = (left ^ self._f(right)) & MASK
        left ^= self.p[1]
        right ^= self.p[0]
        return right & MASK, left & MASK


def load_init_boxes(inc_path: Path) -> list[int]:
    """Parse the (18 + 4*256) 32-bit big-endian words from bf_init_bytes.inc."""
    hex_bytes = [int(x, 16) for x in re.findall(r'0x([0-9a-fA-F]{2})', inc_path.read_text())]
    expected = (18 + 4 * 256) * 4
    if len(hex_bytes) != expected:
        raise ValueError(f'{inc_path}: expected {expected} bytes, got {len(hex_bytes)}')
    return [int.from_bytes(bytes(hex_bytes[o:o + 4]), 'big') for o in range(0, len(hex_bytes), 4)]


def decipher(bf: Blowfish, data: bytes) -> bytes:
    """CBC-decipher the BFCodec wire format and strip the length trailer."""
    if len(data) < 8:
        raise ValueError('too short for the 8-byte length trailer')
    body = len(data) - 8
    orig_len = struct.unpack('>I', data[body:body + 4])[0]
    padded_len = struct.unpack('>I', data[len(data) - 4:])[0]
    if padded_len != body or body != ((orig_len + 7) & ~7):
        raise ValueError(f'bad trailer: origLen={orig_len} paddedLen={padded_len} body={body}')
    chain_l = (IV[0] << 24) | (IV[1] << 16) | (IV[2] << 8) | IV[3]
    chain_r = (IV[4] << 24) | (IV[5] << 16) | (IV[6] << 8) | IV[7]
    out = bytearray()
    for off in range(0, body, 8):
        cl, cr = struct.unpack('>II', data[off:off + 8])
        pl, pr = bf.decrypt(cl, cr)
        out += struct.pack('>II', (pl ^ chain_l) & MASK, (pr ^ chain_r) & MASK)
        chain_l, chain_r = cl, cr
    return bytes(out[:orig_len])


def strip_trailing_commas(text: str) -> str:
    """Remove trailing commas before ] or } so the lenient JSON parses."""
    return re.sub(r',(\s*[\]}])', r'\1', text)


def find_init_inc(explicit: str | None) -> Path:
    if explicit:
        return Path(explicit)
    here = Path(__file__).resolve().parent
    candidate = here.parent / 'Project' / 'System' / 'src' / 'Util' / 'bf_init_bytes.inc'
    return candidate


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('chr', help='path to the .chr file')
    ap.add_argument('--raw', action='store_true', help='print the decrypted bytes verbatim')
    ap.add_argument('--bf-init', help='path to bf_init_bytes.inc (default: alongside the sources)')
    args = ap.parse_args(argv)

    inc = find_init_inc(args.bf_init)
    if not inc.exists():
        print(f'error: cannot find bf_init_bytes.inc at {inc}; pass --bf-init', file=sys.stderr)
        return 2
    bf = Blowfish(load_init_boxes(inc), hashlib.md5(KEY_PLAINTEXT).digest())

    data = Path(args.chr).read_bytes()
    try:
        plain = decipher(bf, data)
    except ValueError as exc:
        print(f'error: {args.chr}: {exc}', file=sys.stderr)
        return 1

    if args.raw:
        sys.stdout.buffer.write(plain)
        return 0

    text = plain.decode('utf-8', errors='replace')
    try:
        obj = json.loads(strip_trailing_commas(text))
    except json.JSONDecodeError:
        print(text)
        return 0
    print(json.dumps(obj, indent=2, ensure_ascii=False))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
