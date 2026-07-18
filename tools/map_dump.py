#!/usr/bin/env python3
"""Parse a pop'n rhythmin sugoroku ``map_%03d.map`` board file to JSON.

The 27 ``map_XYZ.map`` files in ``PopnRhythmin.app`` hold the sugoroku
(board-game) treasure maps — nine main maps with three sub-maps each, the file
number being ``mainMapId * 10 + subMapId``. They are plain (unencrypted)
little-endian binaries parsed by ``TreasureMap::load`` (Ghidra:
``FUN_000ce340``; original source ``Game/Data/TreasureMap/SugorokuMap.mm``):

* Header, 0x50 bytes: ``uint8[2]`` head, ``int16`` square count at +0x02. The
  parser ignores +0x04..0x50, but the files carry structured fields there: a
  24-byte Shift-JIS main-map title at +0x04, a 40-byte sub-map title at
  +0x1c, and an ``int32`` of unconfirmed meaning at +0x44; this tool decodes
  them.
* Square records at +0x50, stride 0xaa: ``int16`` id, x, y, type, slotId,
  then four neighbour ids (``int16`` back link at +0x0a and three forward
  links at +0x0c/+0x0e/+0x10; negative = none), then ``char[0x98]`` of
  Shift-JIS message text at +0x12 with ``<br>`` as the line break.

Square types (TreasureMap::SquareKind): -1 invalid, 0 start, 1 player start,
2 story message / deactivated bonus, 3 bonus, 4 treasure, 5 sub-map flag,
6 wallpaper piece, 7 music piece, 8 warp (paired by slotId), 9 goal lock,
10 bonus treasure.

By default the parsed board is written to stdout as JSON (keys sorted,
2-space indent): the header bytes, title strings, every square with its
decoded text and neighbour ids, and the deduplicated edge list built the way
``load()`` builds it. ``--ascii`` prints a text board instead, and
``--image OUT.png`` renders a pictorial board — coloured tiles connected by
their edges, with the map title and a legend (needs Pillow; the board grid is
compressed by the common coordinate pitch in both views).

Usage::

    tools/map_dump.py map_000.map > map_000.json
    tools/map_dump.py map_042.map --ascii
    .venv/bin/python tools/map_dump.py map_042.map --image map_042.png
"""

from __future__ import annotations

import argparse
import json
import math
import struct
import subprocess
import sys
from pathlib import Path

HEADER_SIZE = 0x50
RECORD_SIZE = 0xaa
TEXT_OFFSET = 0x12
TEXT_SIZE = 0x98

SQUARE_TYPES = {
    -1: 'invalid',
    0: 'start',
    1: 'player-start',
    2: 'story-message',
    3: 'bonus',
    4: 'treasure',
    5: 'sub-map-flag',
    6: 'wallpaper-piece',
    7: 'music-piece',
    8: 'warp',
    9: 'goal-lock',
    10: 'bonus-treasure',
}

GRID_GLYPHS = {
    0: 'S',
    1: 'P',
    2: 'm',
    3: 'B',
    4: 'T',
    5: 'F',
    6: 'w',
    7: 'n',
    8: 'W',
    9: 'G',
    10: 'X',
}

TYPE_COLORS = {
    0: (90, 200, 90),
    1: (80, 220, 255),
    2: (145, 145, 158),
    3: (250, 200, 30),
    4: (255, 150, 40),
    5: (110, 116, 190),
    6: (190, 110, 220),
    7: (255, 120, 180),
    8: (70, 130, 250),
    9: (170, 60, 60),
    10: (240, 60, 60),
}


def decode_sjis(raw: bytes) -> str:
    """Decode a NUL-terminated Shift-JIS run, mapping <br> to a newline."""
    raw = raw.split(b'\x00', 1)[0]
    return raw.decode('shift_jis', errors='replace').replace('<br>', '\n')


def parse_header_fields(header: bytes) -> tuple[str, str, int]:
    """The structured fields in the header tail TreasureMap::load ignores.

    Observed across all 27 shipped maps: a 24-byte Shift-JIS main-map title at
    +0x04 (NUL-padded but not always terminated — the pop'n music Lapistoria crossover title
    fills it exactly), a 40-byte sub-map title at +0x1c, and an int32 at +0x44
    whose meaning is unconfirmed (1..6 in the shipped files; it is not the
    sub-map ordinal).
    """
    main_title = decode_sjis(header[0x04:0x1c])
    sub_title = decode_sjis(header[0x1c:0x44])
    value = struct.unpack_from('<i', header, 0x44)[0]
    return main_title, sub_title, value


def deduplicate_edges(squares: list[dict]) -> list[list[int]]:
    """The forward-link edge list, deduplicated in the way TreasureMap::load
    builds it (a link is skipped when the reverse edge is already recorded)."""
    known = set()
    edges = []
    ids = {s['id'] for s in squares}
    for s in squares:
        for link in s['links']:
            if link not in ids or (link, s['id']) in known:
                continue
            known.add((s['id'], link))
            edges.append([s['id'], link])
    return edges


def parse_map(path: str) -> dict:
    """Parse a map file into a JSON-ready dict; raises ValueError on a bad file."""
    data = Path(path).read_bytes()
    if len(data) < HEADER_SIZE + RECORD_SIZE:
        raise ValueError(f'too short for a map file ({len(data)} bytes)')
    head0, head1, count = struct.unpack_from('<BBh', data, 0)
    expected = HEADER_SIZE + count * RECORD_SIZE
    if count <= 0 or len(data) < expected:
        raise ValueError(f'bad square count {count} for file size {len(data)} (need {expected})')

    squares = []
    for i in range(count):
        rec = data[HEADER_SIZE + i * RECORD_SIZE:HEADER_SIZE + (i + 1) * RECORD_SIZE]
        sid, x, y, typ, slot, back, l0, l1, l2 = struct.unpack_from('<9h', rec, 0)
        squares.append({
            'back': back if back >= 0 else None,
            'id': sid,
            'links': [link for link in (l0, l1, l2) if link >= 0],
            'slot': slot,
            'text': decode_sjis(rec[TEXT_OFFSET:TEXT_OFFSET + TEXT_SIZE]),
            'type': typ,
            'type_name': SQUARE_TYPES.get(typ, f'unknown({typ})'),
            'x': x,
            'y': y,
        })

    type_counts: dict[str, int] = {}
    for s in squares:
        type_counts[s['type_name']] = type_counts.get(s['type_name'], 0) + 1
    main_title, sub_title, header_value = parse_header_fields(data[:HEADER_SIZE])
    return {
        'edges': deduplicate_edges(squares),
        'file': Path(path).name,
        'head': [head0, head1],
        'header_value': header_value,
        'main_title': main_title,
        'square_count': count,
        'squares': squares,
        'sub_title': sub_title,
        'trailing_bytes': len(data) - expected,
        'type_counts': type_counts,
    }


def coordinate_step(values: list[int]) -> int:
    """The GCD of the deltas between sorted unique coordinates (grid pitch)."""
    step = 0
    for a, b in zip(values, values[1:]):
        step = math.gcd(step, b - a)
    return step or 1


def board_cells(squares: list[dict]) -> tuple[dict[int, tuple[int, int]], int, int]:
    """Compressed (column, row) per square id, plus the board dimensions."""
    xs = sorted({s['x'] for s in squares})
    ys = sorted({s['y'] for s in squares})
    step_x, step_y = coordinate_step(xs), coordinate_step(ys)
    cells = {s['id']: ((s['x'] - xs[0]) // step_x, (s['y'] - ys[0]) // step_y) for s in squares}
    return cells, (xs[-1] - xs[0]) // step_x + 1, (ys[-1] - ys[0]) // step_y + 1


def render_ascii(parsed: dict) -> list[str]:
    """A text board: type glyphs at each tile, edges as dashes and bars."""
    squares = parsed['squares']
    cells, cols, lines = board_cells(squares)
    rows = [[' '] * (cols * 4) for _ in range(lines * 2)]
    for s in squares:
        cx, cy = cells[s['id']]
        rows[cy * 2][cx * 4] = GRID_GLYPHS.get(s['type'], '?')
    for a, b in parsed['edges']:
        (ax, ay), (bx, by) = cells[a], cells[b]
        if ay == by and ax != bx:
            left, right = sorted((ax, bx))
            for col in range(left * 4 + 1, right * 4):
                rows[ay * 2][col] = '-'
        elif ax == bx and ay != by:
            top, bottom = sorted((ay, by))
            for row in range(top * 2 + 1, bottom * 2):
                rows[row][ax * 4] = '|'
    return [''.join(r).rstrip() for r in rows if ''.join(r).strip()]


def render_image(parsed: dict, out_path: str, scale: float = 2.0) -> int:
    """Render the board as a PNG: coloured tiles joined by their edges."""
    try:
        from PIL import Image, ImageDraw, ImageFont
    except ImportError:
        print('error: --image needs Pillow; install it in a virtualenv '
              '(python3 -m venv .venv && .venv/bin/pip install Pillow) and run this tool '
              'with that interpreter', file=sys.stderr)
        return 2

    def px(base: int) -> int:
        return max(1, round(base * scale))

    # Prefer a system font with Japanese coverage (the titles are Japanese);
    # fontconfig picks the best match, with the built-in bitmap font as the
    # last resort.
    def load_font(size: int):
        try:
            best = subprocess.run(['fc-match', '-f', '%{file}', ':lang=ja'],
                                  capture_output=True, text=True, check=False)
            if best.stdout.strip():
                return ImageFont.truetype(best.stdout.strip(), size)
        except (OSError, ValueError):
            pass
        return ImageFont.load_default()

    squares = parsed['squares']
    cells, cols, lines = board_cells(squares)
    pitch, radius = px(76), px(24)
    margin, header = px(36), px(64)
    title_font = load_font(px(22))
    tile_font = load_font(px(18))
    small_font = load_font(px(12))

    # The image must be wide enough for the board AND the text: the title and
    # stats lines set a minimum width, and the legend wraps to however many
    # lines fit that width (narrow boards used to clip both).
    title = ' — '.join(t for t in (parsed['main_title'], parsed['sub_title']) if t.strip())
    title = title or parsed['file']
    stats = (f'{parsed["file"]}   {parsed["square_count"]} squares   '
             f'{len(parsed["edges"])} edges')
    board_w = margin * 2 + (cols - 1) * pitch + radius * 2
    width = max(board_w, margin * 2 + round(title_font.getlength(title)),
                margin * 2 + round(small_font.getlength(stats)))

    legend_lines: list[str] = []
    current = ''
    for item in (f'{GRID_GLYPHS[t]}={SQUARE_TYPES[t]}' for t in sorted(GRID_GLYPHS)):
        candidate = f'{current}   {item}' if current else item
        if current and small_font.getlength(candidate) > width - margin * 2:
            legend_lines.append(current)
            current = item
        else:
            current = candidate
    if current:
        legend_lines.append(current)
    line_height = px(18)
    footer = line_height * len(legend_lines) + px(16)

    height = margin * 2 + header + footer + (lines - 1) * pitch + radius * 2
    img = Image.new('RGB', (width, height), (24, 24, 32))
    draw = ImageDraw.Draw(img)
    board_x = margin + (width - board_w) // 2  # centre a narrow board under the text

    def centre(square_id: int) -> tuple[int, int]:
        cx, cy = cells[square_id]
        return (board_x + radius + cx * pitch, margin + header + radius + cy * pitch)

    for a, b in parsed['edges']:
        draw.line([centre(a), centre(b)], fill=(95, 95, 112), width=px(4))

    for s in squares:
        x, y = centre(s['id'])
        color = TYPE_COLORS.get(s['type'], (200, 200, 200))
        draw.ellipse([x - radius, y - radius, x + radius, y + radius], fill=color,
                     outline=(15, 15, 20), width=px(2))
        glyph = GRID_GLYPHS.get(s['type'], '?')
        if s['type'] == 8:  # A warp shows its pair slot so partners can be matched.
            glyph = f'W{s["slot"]}'
        glyph_w = draw.textlength(glyph, font=tile_font)
        draw.text((x - glyph_w / 2, y - px(11)), glyph, fill=(15, 15, 20), font=tile_font)

    draw.text((margin, margin - px(8)), title, fill=(235, 235, 245), font=title_font)
    draw.text((margin, margin + px(22)), stats, fill=(180, 180, 195), font=small_font)
    legend_y = height - margin - line_height * len(legend_lines)
    for i, legend_line in enumerate(legend_lines):
        draw.text((margin, legend_y + i * line_height), legend_line, fill=(150, 150, 165),
                  font=small_font)

    img.save(out_path)
    print(f'wrote {out_path} ({width}x{height})', file=sys.stderr)
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('map', help='path to the map_XXX.map file')
    ap.add_argument('--ascii', action='store_true',
                    help='print a text board instead of the default JSON')
    ap.add_argument('--image', metavar='PNG',
                    help='render the board as a PNG image (needs Pillow)')
    ap.add_argument('--scale', type=float, default=2.0,
                    help='geometry multiplier for --image (default: 2.0)')
    args = ap.parse_args(argv)

    try:
        parsed = parse_map(args.map)
    except (OSError, ValueError) as exc:
        print(f'error: {args.map}: {exc}', file=sys.stderr)
        return 1

    if args.image:
        return render_image(parsed, args.image, scale=args.scale)
    if args.ascii:
        title = ' / '.join(t for t in (parsed['main_title'], parsed['sub_title']) if t.strip())
        print(f'{parsed["file"]}: {parsed["square_count"]} squares, '
              f'{len(parsed["edges"])} edges — {title}')
        for row in render_ascii(parsed):
            print(f'  {row}')
        return 0
    print(json.dumps(parsed, ensure_ascii=False, indent=2, sort_keys=True))
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
