#!/usr/bin/env python3
"""Decrypt and dump a ``sheet_*`` note chart from a ``.orb`` / ``.acv`` package.

Both song-package kinds are ZIPs whose entries are BFCodec-encrypted with the
``Popn Orbit Note. xjr1300.`` key scheme (see ``tools/chr_dump.py``). The chart
entries are ``sheet_es`` / ``sheet_n`` / ``sheet_h`` / ``sheet_ex``; the two
package kinds carry completely different chart formats:

* **Standard** (``%09d.orb``, parsed by ``NoteMng::InitPlayData`` @ 0x335a4): a
  4-byte header that is a little-endian ``float32`` — the chart's base
  hi-speed / scroll multiplier, stored to the manager's ``m_hiSpeed`` field and
  read back by ``computeScrollY`` (``vldr.32`` @ 0x34d1e) — followed by
  20-byte records: ``uint32 tick`` (+0x0), ``uint32 endTick`` (+0x4, > tick
  for a hold), ``uint8 type`` (+0x8), ``uint16 value`` (+0xc, kind low byte /
  kind-hi high byte), and six position bytes (+0xe..+0x13) that ``MakeNote``
  (@ 0x341a4) scales into the on-screen x / y / x2 / y2 / targetX / targetY
  percentages. Types: 0 note, 1 mark (BGM start), 2 tempo (value = BPM),
  3 end, 4 bar line.

* **Arcade** (``ac%09d.acv``, parsed by ``AcNoteMng::InitPlayData`` @ 0x7a774):
  a stream of 8-byte units — ``uint32 tick`` (+0x0), a pad byte (+0x4, the
  ASCII magic ``E`` in unit 0), ``uint8 type`` (+0x5), ``uint16 value``
  (+0x6). The engine parses every unit including unit 0 (whose type/value are
  a real initial-tempo event) and re-stamps the final unit as the type-6
  terminator. Types the engine handles: 1 tap (lane = value & 0xf), 3 BGM
  start / drift-sync anchor, 4 tempo (value = BPM), 6 end of chart, 10 measure
  boundary, 11 beat boundary. Other types (2, 5, 7, 8, ...) exist in the
  shipped charts but have no handler in this app and are shown as unhandled.

The format is detected from the decrypted payload (arcade magic byte, record
divisibility), with the file extension as a tiebreaker.

Usage::

    tools/sheet_dump.py 000000000.orb n
    tools/sheet_dump.py ac200000008.acv es
    tools/sheet_dump.py ac200000008.acv ex --summary
    tools/sheet_dump.py 000000000.orb h --raw > sheet_h.bin
"""

from __future__ import annotations

import argparse
import hashlib
import struct
import sys
import zipfile
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from chr_dump import KEY_PLAINTEXT, Blowfish, decipher, find_init_inc, load_init_boxes

SUFFIXES = ('es', 'ex', 'h', 'n')

STANDARD_TYPES = {
    0: 'note',
    1: 'mark',
    2: 'tempo',
    3: 'end',
    4: 'bar',
}

ARCADE_TYPES = {
    1: 'tap',
    3: 'bgm-start',
    4: 'tempo',
    6: 'end',
    10: 'measure',
    11: 'beat',
}


def detect_format(path: str, plain: bytes) -> str:
    """Classify the decrypted chart as ``standard`` or ``arcade``."""
    arcade = len(plain) >= 16 and len(plain) % 8 == 0 and plain[4] == ord('E')
    standard = len(plain) >= 24 and (len(plain) - 4) % 20 == 0
    ext = Path(path).suffix.lower()
    if arcade and standard:
        return 'arcade' if ext == '.acv' else 'standard'
    if arcade:
        return 'arcade'
    if standard:
        return 'standard'
    raise ValueError(f'unrecognised chart payload ({len(plain)} bytes, '
                     f'byte[4]=0x{plain[4]:02x} if present)')


def dump_standard(plain: bytes, *, summary_only: bool) -> None:
    """Dump a standard 20-byte-record chart (NoteMng::InitPlayData)."""
    hi_speed = struct.unpack_from('<f', plain, 0)[0]
    count = (len(plain) - 4) // 20
    print(f'standard chart: {len(plain)} bytes, {count} records, '
          f'header hi-speed = {hi_speed:g}')

    types: Counter[int] = Counter()
    notes = holds = bars = 0
    tempos: list[tuple[int, int]] = []
    end_tick = mark_tick = None
    for i in range(count):
        off = 4 + i * 20
        tick, end = struct.unpack_from('<II', plain, off)
        typ = plain[off + 8]
        value = struct.unpack_from('<H', plain, off + 0xc)[0]
        pos = plain[off + 0xe:off + 0x14]
        types[typ] += 1
        if typ == 0:
            notes += 1
            holds += end > tick
        elif typ == 1:
            mark_tick = tick
        elif typ == 2:
            tempos.append((tick, value))
        elif typ == 3:
            end_tick = tick
        elif typ == 4:
            bars += 1
        if summary_only:
            continue
        label = STANDARD_TYPES.get(typ, f'unknown({typ})')
        desc = ''
        if typ == 0:
            kind, kind_hi = value & 0xff, value >> 8
            hold = f' hold-end={end}' if end > tick else ''
            desc = (f' kind={kind} kindHi={kind_hi}{hold}'
                    f' pos%=({pos[0]},{pos[1]}) ({pos[2]},{pos[3]}) target=({pos[4]},{pos[5]})')
        elif typ == 2:
            desc = f' bpm={value}'
        print(f'  [{i:4d}] tick={tick:8d} {label:<7}{desc}')

    print(f'summary: {notes} notes ({holds} holds), {bars} bars, '
          f'{len(tempos)} tempo events, mark tick = {mark_tick}, end tick = {end_tick}')
    if tempos:
        bpm_values = [bpm for _, bpm in tempos]
        changes = ', '.join(f'{bpm} @ {tick}' for tick, bpm in tempos)
        print(f'  bpm {min(bpm_values)}..{max(bpm_values)}: {changes}')
    print(f'  type histogram: {dict(sorted(types.items()))}')


def dump_arcade(plain: bytes, *, summary_only: bool) -> None:
    """Dump an arcade 8-byte-unit chart (AcNoteMng::InitPlayData)."""
    count = len(plain) // 8
    print(f'arcade chart: {len(plain)} bytes, {count} units (incl. the magic-"E" header unit; '
          f'the engine re-stamps the final unit as the type-6 terminator)')

    types: Counter[int] = Counter()
    lanes: Counter[int] = Counter()
    measures = beats = 0
    tempos: list[tuple[int, int]] = []
    end_tick = bgm_tick = None
    for i in range(count):
        off = i * 8
        tick = struct.unpack_from('<I', plain, off)[0]
        pad, typ = plain[off + 4], plain[off + 5]
        value = struct.unpack_from('<H', plain, off + 6)[0]
        types[typ] += 1
        if typ == 1:
            lanes[value & 0xf] += 1
        elif typ == 3:
            bgm_tick = tick
        elif typ == 4:
            tempos.append((tick, value))
        elif typ == 6:
            end_tick = tick
        elif typ == 10:
            measures += 1
        elif typ == 11:
            beats += 1
        if summary_only:
            continue
        label = ARCADE_TYPES.get(typ, f'unhandled({typ})')
        if typ == 1:
            desc = f' lane={value & 0xf}'
            if value & ~0xf:
                desc += f' value=0x{value:04x}'
        elif typ == 4:
            desc = f' bpm={value}'
        elif value:
            desc = f' value=0x{value:04x}'
        else:
            desc = ''
        head = ' (header)' if i == 0 else ''
        pad_note = f' pad=0x{pad:02x}' if pad and i > 0 else ''
        print(f'  [{i:4d}] tick={tick:8d} {label:<12}{desc}{pad_note}{head}')

    taps = sum(lanes.values())
    print(f'summary: {taps} taps, {measures} measures, {beats} beats, '
          f'{len(tempos)} tempo events, bgm-start tick = {bgm_tick}, end tick = {end_tick}')
    if lanes:
        per_lane = ', '.join(f'{lane}:{n}' for lane, n in sorted(lanes.items()))
        print(f'  taps per lane: {per_lane}')
    if tempos:
        bpm_values = [bpm for _, bpm in tempos]
        changes = ', '.join(f'{bpm} @ {tick}' for tick, bpm in tempos)
        print(f'  bpm {min(bpm_values)}..{max(bpm_values)}: {changes}')
    print(f'  type histogram: {dict(sorted(types.items()))}')


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('package', help='path to the .orb or .acv file')
    ap.add_argument('suffix', choices=SUFFIXES,
                    help='chart difficulty suffix (the sheet_<suffix> ZIP entry)')
    ap.add_argument('--raw', action='store_true',
                    help='write the decrypted chart bytes to stdout verbatim')
    ap.add_argument('--summary', action='store_true', help='print only the summary lines')
    ap.add_argument('--bf-init', help='path to bf_init_bytes.inc (default: alongside the sources)')
    args = ap.parse_args(argv)

    inc = find_init_inc(args.bf_init)
    if not inc.exists():
        print(f'error: cannot find bf_init_bytes.inc at {inc}; pass --bf-init', file=sys.stderr)
        return 2
    bf = Blowfish(load_init_boxes(inc), hashlib.md5(KEY_PLAINTEXT).digest())

    entry = f'sheet_{args.suffix}'
    try:
        with zipfile.ZipFile(args.package) as zf:
            names = zf.namelist()
            if entry not in names:
                sheets = ', '.join(n for n in names if n.startswith('sheet_')) or 'none'
                print(f'error: no "{entry}" in {args.package} (sheets present: {sheets})',
                      file=sys.stderr)
                return 1
            data = zf.read(entry)
    except (OSError, zipfile.BadZipFile) as exc:
        print(f'error: {args.package}: {exc}', file=sys.stderr)
        return 1

    try:
        plain = decipher(bf, data)
    except ValueError as exc:
        print(f'error: {entry}: {exc}', file=sys.stderr)
        return 1

    if args.raw:
        sys.stdout.buffer.write(plain)
        return 0

    try:
        fmt = detect_format(args.package, plain)
    except ValueError as exc:
        print(f'error: {entry}: {exc}', file=sys.stderr)
        return 1
    print(f'{args.package}: {entry} ({len(data)} bytes encrypted)')
    if fmt == 'arcade':
        dump_arcade(plain, summary_only=args.summary)
    else:
        dump_standard(plain, summary_only=args.summary)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
