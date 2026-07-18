#!/usr/bin/env python3
"""Parse and dump an AEP ``.idx`` animation index (pop'n rhythmin / rb420).

The ``.idx`` files that ship in ``PopnRhythmin.app`` (``music_select.idx``,
``music_select_ipad.idx``, ``title.idx``, ...) drive the AEP 2D scene layer /
frame animation system. This tool decodes their structure offline so element
positions, layer trees and keyframe channels can be inspected without a device.

Layout (all offsets below are relative to ``idxBase = file + 4``, matching the
reconstruction's ``AepManager::readIndexFile`` / ``relocateData``):

* header (``AepIndexHeader``): ``int16 groupId``, ``int16 reserved``,
  ``int32 frameNamesOff``, ``int32 reserved``, ``int32 reserved``,
  ``int32 layerNamesOff``, ``int32 userNamesOff``.
* each ``*NamesOff`` points at a NUL-separated string block terminated by an
  empty string; the producer 8-byte-aligns the cursor (by ``idxBase``-relative
  offset) after the block.
* the layer-name block is followed by ``n`` ``int16`` layer ordinals (``n`` =
  number of layer names), then padding to a multiple of 4 ``int16`` (8 bytes);
  the frame-entry array (``AepFrameEntry``, stride 0x24) starts there.
* an ``AepFrameEntry`` is ``type/child/blend/frameSpeed/frameStart/frameEnd/
  loopOffset/_/anchorX/anchorY`` (10 ``int16``) then ``posChannel/scaleChannel/
  colorChannel/rotChannel`` (4 ``int32``, ``idxBase``-relative byte offsets into
  the channel data, 0 = absent). ``type``: 0 leaf sprite, 2 nested layer, 3
  group callback (a user element); a negative type terminates a layer chain.
* a position channel is a run of ``{frame, x, y, _}`` ``int16`` keyframes; a
  ``frame == -1`` keyframe terminates it.

Usage::

    tools/idx_dump.py music_select_ipad.idx                 # full dump
    tools/idx_dump.py music_select_ipad.idx --names         # just the names
    tools/idx_dump.py music_select_ipad.idx --find JACKET00 # locate an element
"""

from __future__ import annotations

import argparse
import struct
import sys
from dataclasses import dataclass

FRAME_ENTRY_SIZE = 0x24
POS_KEYFRAME_SIZE = 8  # 4 * int16: frame, x, y, _


@dataclass
class Header:
    group_id: int
    frame_names_off: int
    layer_names_off: int
    user_names_off: int


@dataclass
class FrameEntry:
    offset: int  # file offset of the entry
    type: int
    child: int
    blend_flags: int
    frame_speed: int
    frame_start: int
    frame_end: int
    loop_offset: int
    anchor_x: int
    anchor_y: int
    pos_channel: int
    scale_channel: int
    color_channel: int
    rot_channel: int


def read_header(data: bytes) -> Header:
    fmt = '<' + 'h' * 2 + 'i' * 5  # groupId, reserved, 3 name offsets + 2 reserved
    group_id, _, frame_off, _, _, layer_off, user_off = struct.unpack_from(fmt, data, 4)
    return Header(group_id, frame_off, layer_off, user_off)


def parse_names(data: bytes, file_off: int) -> tuple[list[str], int]:
    """Parse a NUL-separated name block; return (names, end_file_offset).

    Mirrors buildAepNameHashTable, which 8-byte-aligns the cursor after the names
    by its raw pointer *address* (`(int)pCursor % 8`). At runtime the .idx is a
    16-byte-aligned NSData buffer and readIndexFile returns idxBase = buffer + 4,
    so idxBase is 4 mod 8 and the alignment lands the following block at a FILE
    offset that is a multiple of 8. Align the file offset to 8 to match the running
    app (verified: the layer ordinals then resolve to the same entry indices the
    device logs, e.g. DIFFICULTY_STAR_OUT -> 113).
    """
    names: list[str] = []
    p = file_off
    while data[p:p + 1] != b'\x00':
        end = data.index(b'\x00', p)
        names.append(data[p:end].decode('latin1'))
        p = end + 1
    end = p + 1  # past the terminating empty string
    misalign = end % 8
    if misalign:
        end += 8 - misalign
    return names, end


def frame_entries_start(data: bytes, header: Header) -> int:
    """File offset of the frame-entry array (past layer names + ordinals)."""
    layer_names, cur = parse_names(data, 4 + header.layer_names_off)
    n = len(layer_names)
    cur += n * 2  # the n int16 layer ordinals
    if n % 4:
        cur += (4 - n % 4) * 2  # pad to a multiple of 4 int16 (8 bytes)
    return cur


def read_frame_entry(data: bytes, off: int) -> FrameEntry:
    (typ, child, blend, speed, start, end, loop, _r0e, ax, ay) = struct.unpack_from(
        '<10h', data, off)
    pos_ch, scale_ch, color_ch, rot_ch = struct.unpack_from('<4i', data, off + 0x14)
    return FrameEntry(off, typ, child, blend, speed, start, end, loop, ax, ay, pos_ch,
                      scale_ch, color_ch, rot_ch)


def walk_frame_entries(data: bytes, start: int) -> list[FrameEntry]:
    """Walk the flat frame-entry array, stopping when an entry stops validating.

    The array is a run of AepFrameEntry records (layer chains are contiguous and
    terminated by a negative type; the array itself ends where the next section
    begins). We stop when a record's type is out of the known set and its fields
    look like non-entry data, which bounds the walk without a length field.
    """
    entries: list[FrameEntry] = []
    off = start
    while off + FRAME_ENTRY_SIZE <= len(data):
        e = read_frame_entry(data, off)
        plausible = e.type in (-1, 0, 2, 3) and -1 <= e.frame_start <= 0x4000 \
            and -1 <= e.frame_end <= 0x4000 and 0 <= e.pos_channel < len(data)
        if not plausible:
            break
        entries.append(e)
        off += FRAME_ENTRY_SIZE
    return entries


def decode_pos_channel(data: bytes, pos_channel: int) -> list[tuple[int, int, int]]:
    """Decode a position channel (idxBase-relative) to [(frame, x, y), ...]."""
    if pos_channel == 0:
        return []
    keys: list[tuple[int, int, int]] = []
    off = 4 + pos_channel
    while off + POS_KEYFRAME_SIZE <= len(data):
        frame, x, y, _ = struct.unpack_from('<4h', data, off)
        if frame == -1:
            break
        keys.append((frame, x, y))
        off += POS_KEYFRAME_SIZE
        if len(keys) > 4096:
            break
    return keys


def layer_numbers(data: bytes, header: Header) -> list[int]:
    """The per-ordinal entry-index table (``m_layerNumbers``).

    A layer *name*'s ordinal indexes this int16 table to get the entry index its
    chain starts at (mirrors ``getLyrNo``: ``m_layerNumbers[group][ordinal]``).
    The table sits immediately after the layer-name block, before the frame
    entries.
    """
    layer_names, cur = parse_names(data, 4 + header.layer_names_off)
    return list(struct.unpack_from(f'<{len(layer_names)}h', data, cur))


def decode_color_channel(data: bytes, color_channel: int) -> list[tuple[int, int, int]]:
    """Decode a colour/alpha channel (idxBase-relative) to [(frame, colour, alpha)].

    Stride is 2 int16 per key: ``frame`` then a packed word whose low byte is the
    colour (brightness) and high byte the alpha delta, both read *signed* (the
    engine uses ``ldrsb``). A negative ``frame`` terminates the list.
    """
    if color_channel == 0:
        return []
    keys: list[tuple[int, int, int]] = []
    off = 4 + color_channel
    while off + 4 <= len(data):
        frame, packed = struct.unpack_from('<2h', data, off)
        if frame < 0:
            break
        colour = packed & 0xff
        alpha = (packed >> 8) & 0xff
        colour = colour - 256 if colour >= 128 else colour
        alpha = alpha - 256 if alpha >= 128 else alpha
        keys.append((frame, colour, alpha))
        off += 4
        if len(keys) > 4096:
            break
    return keys


def dump_layer(path: str, layer: str) -> int:
    """Dump one layer's frame-entry chain with decoded channels.

    Resolves the layer name to its entry index via ``layer_numbers`` and walks
    the chain (``entries[layerNo]`` until a negative type terminates it, exactly
    as ``AepManager::layerLength``), printing each entry's blend, frame window,
    and its position / scale / colour keyframes. The colour keyframes are the
    interesting bit for selected/unselected state art (e.g. STAR_OPEN vs
    STAR_OUT).
    """
    data = open(path, 'rb').read()
    header = read_header(data)
    layer_names, _ = parse_names(data, 4 + header.layer_names_off)
    if layer not in layer_names:
        print(f'error: "{layer}" is not a layer name', file=sys.stderr)
        return 1
    ordinal = layer_names.index(layer)
    entry_index = layer_numbers(data, header)[ordinal]
    start = frame_entries_start(data, header)
    off = start + entry_index * FRAME_ENTRY_SIZE
    print(f'{path}')
    print(f'  layer "{layer}" ordinal={ordinal} entryIndex={entry_index} '
          f'@0x{off:x}')
    row = 0
    while off + FRAME_ENTRY_SIZE <= len(data):
        e = read_frame_entry(data, off)
        if e.type < 0:
            print(f'  [terminator] type={e.type} length(frameEnd)={e.frame_end}')
            break
        # A chain is a run of leaf (0) / nested (2) / group (3) entries; anything
        # else means we have walked off the end into an adjacent section.
        if e.type not in (0, 2, 3):
            print(f'  [end of chain: next entry type={e.type} is not a frame entry]')
            break
        parts = [f'+{row:<2d} type={e.type} child={e.child} '
                 f'blend=0x{e.blend_flags & 0xffff:04x} '
                 f'frames=[{e.frame_start},{e.frame_end})']
        if e.pos_channel:
            parts.append(f'pos={decode_pos_channel(data, e.pos_channel)}')
        if e.scale_channel:
            parts.append(f'scaleCh=0x{e.scale_channel:x}')
        if e.color_channel:
            parts.append(f'colour(frame,c,a)={decode_color_channel(data, e.color_channel)}')
        print('  ' + ' '.join(parts))
        off += FRAME_ENTRY_SIZE
        row += 1
    return 0


def dump(path: str, *, names_only: bool, find: str | None) -> int:
    data = open(path, 'rb').read()
    header = read_header(data)
    frame_names, _ = parse_names(data, 4 + header.frame_names_off)
    layer_names, _ = parse_names(data, 4 + header.layer_names_off)
    user_names, _ = parse_names(data, 4 + header.user_names_off)

    print(f'{path}: {len(data)} bytes, groupId={header.group_id}')
    print(f'  frameNamesOff=0x{header.frame_names_off:x} '
          f'layerNamesOff=0x{header.layer_names_off:x} '
          f'userNamesOff=0x{header.user_names_off:x}')
    print(f'  frame names ({len(frame_names)}), layer names ({len(layer_names)}), '
          f'user names ({len(user_names)})')

    if find is not None:
        for label, block in (('frame', frame_names), ('layer', layer_names),
                             ('user', user_names)):
            if find in block:
                print(f'  found "{find}" as a {label} name, ordinal {block.index(find)}')
        start = frame_entries_start(data, header)
        entries = walk_frame_entries(data, start)
        target = user_names.index(find) if find in user_names else None
        for e in entries:
            if e.type == 3 and (target is None or e.child == target):
                keys = decode_pos_channel(data, e.pos_channel)
                first = keys[0] if keys else None
                mark = '  <== match' if e.child == target else ''
                print(f'  type3 entry @0x{e.offset:x} child={e.child} '
                      f'anchor=({e.anchor_x},{e.anchor_y}) posCh=0x{e.pos_channel:x} '
                      f'firstKey(frame,x,y)={first}{mark}')
        return 0

    print('\nlayer names:')
    for i, n in enumerate(layer_names):
        print(f'  [{i:3d}] {n}')
    print('\nuser names:')
    for i, n in enumerate(user_names):
        print(f'  [{i:3d}] {n}')

    if names_only:
        return 0

    start = frame_entries_start(data, header)
    entries = walk_frame_entries(data, start)
    print(f'\nframe entries @0x{start:x} ({len(entries)} valid):')
    for e in entries:
        chans = []
        if e.pos_channel:
            keys = decode_pos_channel(data, e.pos_channel)
            first = keys[0] if keys else None
            chans.append(f'pos=0x{e.pos_channel:x}{first if first else ""}')
        if e.scale_channel:
            chans.append(f'scale=0x{e.scale_channel:x}')
        if e.rot_channel:
            chans.append(f'rot=0x{e.rot_channel:x}')
        print(f'  @0x{e.offset:x} type={e.type} child={e.child} '
              f'frames=[{e.frame_start},{e.frame_end}) anchor=({e.anchor_x},{e.anchor_y}) '
              f'{" ".join(chans)}')
    return 0


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('idx', help='path to the .idx file')
    ap.add_argument('--names', action='store_true', help='print only the name blocks')
    ap.add_argument('--find', metavar='NAME',
                    help='locate a named element (e.g. JACKET00) and its position keyframe')
    ap.add_argument('--layer', metavar='NAME',
                    help='dump one layer\'s frame-entry chain with decoded channels '
                         '(e.g. DIFFICULTY_STAR_OUT)')
    args = ap.parse_args(argv)
    if args.layer is not None:
        return dump_layer(args.idx, args.layer)
    return dump(args.idx, names_only=args.names, find=args.find)


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
