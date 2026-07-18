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

``--image`` renders a chart as a DDR-style strip chart (fixed-height
measures, columns left to right, one button per tap in its lane, with measure
numbers, beat lines, BPM, and BGM-start markers). Arcade charts read bottom
to top by default — bar 1 sits at the bottom left, matching the game's
downward note fall — with the title block as a footer; standard charts read
top to bottom by default with the title block as a header. ``--top-down``
and ``--bottom-up`` override the direction either way. Arcade charts
use their nine real lanes; standard charts are position-based (osu!-like),
so — as osu!mania does when converting osu! beatmaps — each note's
judge-target x percentage is bucketed into ``--lanes`` columns (default 7),
the button colour cycles with the note kind, holds become long notes, and
the measure grid is synthesised from the tempo map when the chart carries no
bar records. The
header carries the song title and level, read from the package's encrypted
``info`` plist; titles are Japanese, so install a font with Japanese coverage
(for example Noto Sans CJK) for them to render. The renderer needs Pillow,
which is not otherwise a dependency of this tree — install it in a
virtualenv (``python3 -m venv .venv && .venv/bin/pip install Pillow``) and
run the tool with that interpreter. Pass ``--buttons DIR`` pointing at a
directory holding the game's ``login_popn01..05@2x.png`` sprites (01 blue, 02
red, 03 white, 04 yellow, 05 green) to draw taps as real pop'n buttons;
without it taps are flat coloured discs.

Usage::

    tools/sheet_dump.py 000000000.orb n
    tools/sheet_dump.py ac200000008.acv es
    tools/sheet_dump.py ac200000008.acv ex --summary
    tools/sheet_dump.py 000000000.orb h --raw > sheet_h.bin
    .venv/bin/python tools/sheet_dump.py ac200000008.acv h --image chart.png \
        --buttons path/to/converted
"""

from __future__ import annotations

import argparse
import bisect
import hashlib
import math
import plistlib
import struct
import subprocess
import sys
import zipfile
from collections import Counter
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))

from chr_dump import KEY_PLAINTEXT, Blowfish, decipher, find_init_inc, load_init_boxes

SUFFIXES = ('es', 'ex', 'h', 'n')

# The difficulty-level key each sheet suffix maps to in the "info" plist (the
# arcade info carries all four; the standard .orb info has no Easy).
SUFFIX_LEVEL_KEYS = {'es': 'Easy', 'ex': 'Ex', 'h': 'Hyper', 'n': 'Normal'}

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


def parse_arcade_units(plain: bytes) -> list[tuple[int, int, int, int]]:
    """Split the decrypted arcade payload into (tick, pad, type, value) units."""
    return [(struct.unpack_from('<I', plain, off)[0], plain[off + 4], plain[off + 5],
             struct.unpack_from('<H', plain, off + 6)[0])
            for off in range(0, len(plain) - 7, 8)]


def dump_arcade(plain: bytes, *, summary_only: bool) -> None:
    """Dump an arcade 8-byte-unit chart (AcNoteMng::InitPlayData)."""
    units = parse_arcade_units(plain)
    print(f'arcade chart: {len(plain)} bytes, {len(units)} units (incl. the magic-"E" header '
          f'unit; the engine re-stamps the final unit as the type-6 terminator)')

    types: Counter[int] = Counter()
    lanes: Counter[int] = Counter()
    measures = beats = 0
    tempos: list[tuple[int, int]] = []
    end_tick = bgm_tick = None
    for i, (tick, pad, typ, value) in enumerate(units):
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


# Lane -> login_popn sprite number (01 blue, 02 red, 03 white, 04 yellow, and
# 05 green); the nine pop'n buttons run white, yellow, green, blue, red, blue,
# green, yellow, white from left to right.
LANE_SPRITES = (3, 4, 5, 1, 2, 1, 5, 4, 3)
# Standard-chart note kinds cycle through the five buttons in the pop'n
# white/yellow/green/blue/red order.
KIND_SPRITES = (3, 4, 5, 1, 2)
# Flat fallback colours per sprite number for when the sprites are unavailable.
SPRITE_COLORS = {
    1: (70, 130, 250),
    2: (240, 60, 60),
    3: (235, 235, 235),
    4: (250, 200, 30),
    5: (90, 200, 90),
}


def render_strip_image(out_path: str, *, notes: list[tuple[int, int, int, int]], lane_count: int,
                       measure_ticks: list[int], beat_ticks: list[int],
                       tempos: list[tuple[int, int]], bgm_ticks: list[int], end_ticks: list[int],
                       source: str, title: str | None = None, artist: str | None = None,
                       level: int | None = None, buttons_dir: str | None = None,
                       beat_px: int = 48, measures_per_column: int = 16,
                       top_down: bool = False) -> int:
    """Render a chart as a DDR-style strip image (needs Pillow).

    Measures are fixed-height boxes wrapped into columns left to right; each
    note in `notes` is (tick, endTick, lane, sprite number) and is drawn as a
    pop'n button in its lane, with a long-note body when endTick > tick. Beat
    lines, measure numbers, BPM, and BGM-start markers are included.
    """
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print('error: --image needs Pillow; install it in a virtualenv '
              '(python3 -m venv .venv && .venv/bin/pip install Pillow) and run this tool '
              'with that interpreter', file=sys.stderr)
        return 2

    if not measure_ticks:
        print('error: chart has no measure grid to lay out against', file=sys.stderr)
        return 1

    # Fractional-measure mapping: each measure is one layout unit regardless of
    # its tick span, so BPM changes do not distort the grid (the DDR-chart
    # convention). Ticks past the final measure line extrapolate with the
    # median measure length.
    diffs = sorted(b - a for a, b in zip(measure_ticks, measure_ticks[1:]) if b > a)
    last_len = diffs[len(diffs) // 2] if diffs else 2000

    def tick_pos(tick: int) -> float:
        i = bisect.bisect_right(measure_ticks, tick) - 1
        if i < 0:
            return 0.0
        start = measure_ticks[i]
        length = measure_ticks[i + 1] - start if i + 1 < len(measure_ticks) else last_len
        frac = (tick - start) / length if length > 0 else 0.0
        return i + frac

    last_tick = max([end for _, end, _, _ in notes] + end_ticks + [measure_ticks[-1]])
    total_measures = int(tick_pos(last_tick)) + 1

    lane_px = 26
    note_w, note_h = 24, 22
    strip_w = lane_px * lane_count
    measure_px = beat_px * 4
    gutter, gap, margin, header = 46, 26, 24, 84
    cols = math.ceil(total_measures / measures_per_column)
    col_h = measures_per_column * measure_px
    width = margin * 2 + cols * (gutter + strip_w) + (cols - 1) * gap
    height = margin * 2 + header + col_h
    # The title block is a header when reading top-down and a footer in the
    # default bottom-up mode (where bar 1 sits at the bottom left).
    top = margin + (header if top_down else 0)
    img = Image.new('RGB', (width, height), (24, 24, 32))
    draw = ImageDraw.Draw(img)

    # Prefer a system font with Japanese coverage for the title header (song
    # names are Japanese); fontconfig picks the best match, and the built-in
    # bitmap font is the last resort.
    def load_font(size: int):
        try:
            best = subprocess.run(['fc-match', '-f', '%{file}', ':lang=ja'],
                                  capture_output=True, text=True, check=False)
            if best.stdout.strip():
                return ImageFont.truetype(best.stdout.strip(), size)
        except (OSError, ValueError):
            pass
        return ImageFont.load_default()

    font = load_font(14)
    sub_font = load_font(15)
    header_font = load_font(21)

    sprites: dict[int, object] | None = None
    if buttons_dir is not None:
        sprite_dir = Path(buttons_dir)
        try:
            sprites = {}
            for num in sorted(SPRITE_COLORS):
                sprite = Image.open(sprite_dir / f'login_popn{num:02d}@2x.png').convert('RGBA')
                sprites[num] = sprite.resize((note_w, note_h), Image.LANCZOS)
        except OSError as exc:
            print(f'error: cannot load button sprites from {sprite_dir}: {exc}', file=sys.stderr)
            return 1

    def place(tick: int) -> tuple[int, int]:
        pos = min(tick_pos(tick), float(total_measures))
        col = min(int(pos // measures_per_column), cols - 1)
        col_measures = min(measures_per_column, total_measures - col * measures_per_column)
        rel = min(pos - col * measures_per_column, float(col_measures))
        x0 = margin + col * (gutter + strip_w + gap) + gutter
        # Bottom-up (the default) mirrors the game: notes fall downward, so the
        # chart reads from the bottom of each column towards the top, and a
        # partial final column is bottom-aligned so bar 1 of every column sits
        # on the common bottom line.
        y = top + rel * measure_px if top_down else top + col_h - rel * measure_px
        return x0, round(y)

    # Column frames: lane separators, measure lines, and measure numbers.
    line, dim = (150, 150, 165), (58, 58, 72)
    for col in range(cols):
        x0 = margin + col * (gutter + strip_w + gap) + gutter
        col_measures = min(measures_per_column, total_measures - col * measures_per_column)
        if top_down:
            frame_top = top
            frame_bottom = top + col_measures * measure_px
        else:
            frame_top = top + col_h - col_measures * measure_px
            frame_bottom = top + col_h
        for lane in range(1, lane_count):
            draw.line([(x0 + lane * lane_px, frame_top), (x0 + lane * lane_px, frame_bottom)],
                      fill=(40, 40, 52))
        for m in range(col_measures + 1):
            y = frame_top + m * measure_px
            draw.line([(x0, y), (x0 + strip_w, y)], fill=line)
        for m in range(col_measures):
            text = str(col * measures_per_column + m + 1)
            text_w = draw.textlength(text, font=font)
            if top_down:
                y = frame_top + m * measure_px + 3
            else:
                y = frame_bottom - m * measure_px - 20
            draw.text((x0 - 8 - text_w, y), text, fill=(170, 170, 185), font=font)
        draw.rectangle([x0, frame_top, x0 + strip_w, frame_bottom], outline=line)

    measure_set = set(measure_ticks)
    for t in beat_ticks:
        if t in measure_set:
            continue
        x0, y = place(t)
        draw.line([(x0 + 1, y), (x0 + strip_w - 1, y)], fill=dim)

    for t, bpm in tempos:
        x0, y = place(t)
        draw.line([(x0, y), (x0 + strip_w, y)], fill=(255, 90, 210), width=2)
        draw.text((x0 + strip_w + 4, y - 8), str(bpm), fill=(255, 90, 210), font=font)
    for t in bgm_ticks:
        x0, y = place(t)
        draw.line([(x0, y), (x0 + strip_w, y)], fill=(80, 220, 255), width=2)

    def draw_button(cx: int, y: int, sprite_num: int) -> None:
        if sprites:
            sprite = sprites[sprite_num]
            img.paste(sprite, (cx - note_w // 2, y - note_h // 2), sprite)
        else:
            draw.ellipse([cx - 10, y - 9, cx + 10, y + 9], fill=SPRITE_COLORS[sprite_num],
                         outline=(0, 0, 0))

    hold_count = 0
    for t, end, lane, sprite_num in notes:
        if lane >= lane_count:
            continue
        x0, y = place(t)
        cx = x0 + lane * lane_px + lane_px // 2
        if end > t:
            # A long note: a dimmed body bar from head to tail with a button on
            # each end (the osu!mania hold-note look).
            hold_count += 1
            _, y_end = place(end)
            body = tuple(c // 2 for c in SPRITE_COLORS[sprite_num])
            draw.rectangle([cx - 6, min(y, y_end), cx + 6, max(y, y_end)], fill=body)
            draw_button(cx, y_end, sprite_num)
        draw_button(cx, y, sprite_num)

    bpm_values = [bpm for _, bpm in tempos]
    bpm_text = '?' if not bpm_values else (
        str(bpm_values[0]) if min(bpm_values) == max(bpm_values) else
        f'{min(bpm_values)}-{max(bpm_values)}')
    text_y = margin if top_down else top + col_h + 10
    if title:
        draw.text((margin, text_y), title, fill=(235, 235, 245), font=header_font)
        text_y += 30
    if artist:
        draw.text((margin, text_y), artist, fill=(190, 190, 205), font=sub_font)
        text_y += 24
    stats = [f'BPM: {bpm_text}']
    if level:
        stats.append(f'Level: {level}')
    stats.append(f'Taps: {len(notes)}')
    if hold_count:
        stats.append(f'Holds: {hold_count}')
    stats.append(f'Measures: {total_measures}')
    draw.text((margin, text_y), '    '.join(stats), fill=(220, 220, 230), font=sub_font)

    source_w = draw.textlength(source, font=font)
    draw.text((width - margin - source_w, height - margin + 3), source,
              fill=(140, 140, 155), font=font)

    img.save(out_path)
    print(f'wrote {out_path} ({width}x{height}, {cols} columns of '
          f'{measures_per_column} measures)')
    return 0


def render_arcade_image(plain: bytes, out_path: str, **options) -> int:
    """Prepare an arcade chart for the strip renderer (lane = value & 0xf)."""
    units = parse_arcade_units(plain)
    notes = [(t, t, v & 0xf, LANE_SPRITES[v & 0xf])
             for t, _, ty, v in units if ty == 1 and (v & 0xf) < 9]
    if not any(ty == 10 for _, _, ty, _ in units):
        print('error: chart has no measure (type 10) events to lay out against', file=sys.stderr)
        return 1
    return render_strip_image(out_path, notes=notes, lane_count=9,
                              measure_ticks=sorted({t for t, _, ty, _ in units if ty == 10}),
                              beat_ticks=sorted({t for t, _, ty, _ in units if ty == 11}),
                              tempos=[(t, v) for t, _, ty, v in units if ty == 4],
                              bgm_ticks=[t for t, _, ty, _ in units if ty == 3],
                              end_ticks=[t for t, _, ty, _ in units if ty == 6], **options)


def render_standard_image(plain: bytes, out_path: str, *, lanes: int = 7, **options) -> int:
    """Prepare a standard chart for the strip renderer, osu!mania style.

    The standard game is position-based (notes carry on-screen percentages
    rather than lanes), so — like osu!mania's conversion of osu! beatmaps —
    the judge-target x percentage is bucketed into `lanes` columns. The button
    colour cycles with the note kind, and a hold (endTick > tick) becomes a
    long note. The measure grid comes from the chart's bar records when it has
    any, and is otherwise synthesised from the tempo map (ticks are
    milliseconds; a 4/4 measure is 240000 / BPM ticks).
    """
    count = (len(plain) - 4) // 20
    notes = []
    tempos: list[tuple[int, int]] = []
    bars: list[int] = []
    bgm_ticks: list[int] = []
    end_ticks: list[int] = []
    for i in range(count):
        off = 4 + i * 20
        tick, end = struct.unpack_from('<II', plain, off)
        typ = plain[off + 8]
        if typ == 0:
            kind = struct.unpack_from('<H', plain, off + 0xc)[0] & 0xff
            target_x = plain[off + 0x12]
            lane = min(lanes - 1, target_x * lanes // 100)
            notes.append((tick, max(end, tick), lane, KIND_SPRITES[kind % 5]))
        elif typ == 1:
            bgm_ticks.append(tick)
        elif typ == 2:
            tempos.append((tick, struct.unpack_from('<H', plain, off + 0xc)[0]))
        elif typ == 3:
            end_ticks.append(tick)
        elif typ == 4:
            bars.append(tick)

    last_tick = max(end_ticks + [end for _, end, _, _ in notes] + [0])
    if bars:
        measure_ticks = sorted(set(bars))
    else:
        measure_ticks = []
        events = sorted(tempos) + [(last_tick, 0)]
        for (seg_tick, bpm), (seg_end, _) in zip(events, events[1:]):
            if bpm <= 0:
                continue
            measure_len = 240000.0 / bpm
            k = 0
            while seg_tick + k * measure_len < seg_end and len(measure_ticks) < 100000:
                measure_ticks.append(round(seg_tick + k * measure_len))
                k += 1
    if not measure_ticks:
        print('error: chart has no bar records and no usable tempo map', file=sys.stderr)
        return 1
    # Beat lines: subdivide each measure into quarters.
    beat_ticks = [round(a + (b - a) * q / 4)
                  for a, b in zip(measure_ticks, measure_ticks[1:]) for q in (1, 2, 3)]
    return render_strip_image(out_path, notes=notes, lane_count=lanes,
                              measure_ticks=measure_ticks, beat_ticks=beat_ticks, tempos=tempos,
                              bgm_ticks=bgm_ticks, end_ticks=end_ticks, **options)


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('package', help='path to the .orb or .acv file')
    ap.add_argument('suffix', choices=SUFFIXES,
                    help='chart difficulty suffix (the sheet_<suffix> ZIP entry)')
    ap.add_argument('--raw', action='store_true',
                    help='write the decrypted chart bytes to stdout verbatim')
    ap.add_argument('--summary', action='store_true', help='print only the summary lines')
    ap.add_argument('--bf-init', help='path to bf_init_bytes.inc (default: alongside the sources)')
    ap.add_argument('--image', metavar='PNG',
                    help='render an arcade chart as a DDR-style strip image (needs Pillow)')
    ap.add_argument('--buttons', metavar='DIR',
                    help='directory containing the login_popn01..05@2x.png button sprites to '
                         'draw taps with (default: flat coloured discs)')
    direction = ap.add_mutually_exclusive_group()
    direction.add_argument('--top-down', action='store_true',
                           help='read each column top to bottom (the default for standard .orb '
                                'charts)')
    direction.add_argument('--bottom-up', action='store_true',
                           help='read each column bottom to top (the default for arcade .acv '
                                'charts, matching the downward note fall)')
    ap.add_argument('--lanes', type=int, default=7, metavar='N',
                    help='column count for standard (.orb) chart images; the judge-target x '
                         'percentage is bucketed into N lanes, osu!mania style (default: 7)')
    args = ap.parse_args(argv)

    inc = find_init_inc(args.bf_init)
    if not inc.exists():
        print(f'error: cannot find bf_init_bytes.inc at {inc}; pass --bf-init', file=sys.stderr)
        return 2
    bf = Blowfish(load_init_boxes(inc), hashlib.md5(KEY_PLAINTEXT).digest())

    entry = f'sheet_{args.suffix}'
    info = None
    try:
        with zipfile.ZipFile(args.package) as zf:
            names = zf.namelist()
            if entry not in names:
                sheets = ', '.join(n for n in names if n.startswith('sheet_')) or 'none'
                print(f'error: no "{entry}" in {args.package} (sheets present: {sheets})',
                      file=sys.stderr)
                return 1
            data = zf.read(entry)
            # The song metadata lives in the encrypted "info" entry, a plist
            # (MusicName, GenreName or ArtistName, and the difficulty levels).
            if 'info' in names:
                try:
                    info = plistlib.loads(decipher(bf, zf.read('info')))
                except (ValueError, plistlib.InvalidFileException):
                    info = None
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
    title = artist = level = None
    if isinstance(info, dict):
        title = info.get('MusicName')
        # The arcade info has no ArtistName; the genre is the marquee line.
        artist = info.get('ArtistName') or info.get('GenreName')
        level = info.get(SUFFIX_LEVEL_KEYS[args.suffix])
    if args.image:
        options = {
            'source': f'{Path(args.package).name} {entry}',
            'title': title,
            'artist': artist,
            'level': level,
            'buttons_dir': args.buttons,
        }
        if fmt == 'arcade':
            # Arcade reads bottom-up by default (notes fall downward in-game).
            return render_arcade_image(plain, args.image, top_down=args.top_down, **options)
        # The standard osu!-like mode reads top-down by default.
        return render_standard_image(plain, args.image, lanes=args.lanes,
                                     top_down=not args.bottom_up, **options)
    print(f'{args.package}: {entry} ({len(data)} bytes encrypted)')
    if title:
        extra = info.get('GenreName') if fmt == 'arcade' else info.get('ArtistName')
        extra_text = f' ({extra})' if extra and extra != title else ''
        level_text = f', lv {level}' if level else ''
        print(f'title: {title}{extra_text}{level_text}')
    if fmt == 'arcade':
        dump_arcade(plain, summary_only=args.summary)
    else:
        dump_standard(plain, summary_only=args.summary)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
