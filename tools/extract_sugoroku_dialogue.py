#!/usr/bin/env python3
"""Extract the sugoroku board character-message dialogue pools from a PopnRhythmin
app binary into the runtime asset file that the reconstruction loads at play time
(Project/Game/Data/TreasureMap/TreasureMap.mm -> getCharacterAssetName /
ensureCharacterMessagePools).

The dialogue itself is copyrighted game content and is NOT shipped with this source.
Run this against your own copy of the app binary to regenerate the asset:

    python3 tools/extract_sugoroku_dialogue.py <PopnRhythmin binary> [out.bin]

Default output: sugoroku_chara_msg.bin (drop it into the app bundle so
[NSBundle pathForResource:@"sugoroku_chara_msg" ofType:@"bin"] finds it).

Output format (little-endian), matching the loader's parser exactly: for each of the
6 pools, in the fixed order below, an int32 entry-count followed by `count` records of
{int32 byteLen, byteLen raw UTF-8 bytes} (no trailing NUL).

Pool pointer tables are absolute VA pointer arrays in the binary's __const; each entry
points at a NUL-terminated UTF-8 string in __cstring. Addresses are the Ghidra VAs at
image base 0x00004000.
"""
import os
import struct
import sys

# (pointer-table VA, entry count) in the order getCharacterAssetName expects.
POOLS = [
    (0x1335c8, 41),  # kCharGroup6Slot0
    (0x13366c, 35),  # kCharGroup6Slot1
    (0x1336f8, 47),  # kCharGroup6Slot2  (wac)
    (0x1337b4, 64),  # kCharGroup8Slot0
    (0x1338b4, 72),  # kCharGroup8Slot1  (TOMOSUKE)
    (0x1339d4, 71),  # kCharGroup8Slot2
]

DEFAULT_OUT = "sugoroku_chara_msg.bin"

CPU_TYPE_ARM = 12
MH_MAGIC = 0xFEEDFACE          # 32-bit, little-endian host order
MH_CIGAM = 0xCEFAEDFE
FAT_MAGIC = 0xCAFEBABE
FAT_CIGAM = 0xBEBAFECA
LC_SEGMENT = 0x1


def u32le(b, o):
    return struct.unpack_from("<I", b, o)[0]


def select_thin(data):
    """Return the bytes of a 32-bit Mach-O image, unwrapping a fat binary and
    selecting the 32-bit ARM slice if present."""
    magic = struct.unpack_from(">I", data, 0)[0]
    if magic in (FAT_MAGIC, FAT_CIGAM):
        nfat = struct.unpack_from(">I", data, 4)[0]
        off = 8
        chosen = None
        for _ in range(nfat):
            cputype, _sub, foff, fsize, _align = struct.unpack_from(">iIIII", data, off)
            off += 20
            if cputype == CPU_TYPE_ARM:
                chosen = (foff, fsize)
        if chosen is None:
            sys.exit("error: no 32-bit ARM slice in fat binary")
        return data[chosen[0]:chosen[0] + chosen[1]]
    return data


def parse_segments(image):
    """Return [(vmaddr, vmsize, fileoff, filesize), ...] from LC_SEGMENT commands."""
    magic = u32le(image, 0)
    if magic not in (MH_MAGIC, MH_CIGAM):
        sys.exit("error: not a 32-bit Mach-O (magic 0x%08x); this build is armv7/32-bit" % magic)
    ncmds = u32le(image, 16)
    off = 28  # sizeof(struct mach_header)
    segs = []
    for _ in range(ncmds):
        cmd, cmdsize = struct.unpack_from("<II", image, off)
        if cmd == LC_SEGMENT:
            vmaddr, vmsize, fileoff, filesize = struct.unpack_from("<IIII", image, off + 24)
            segs.append((vmaddr, vmsize, fileoff, filesize))
        if cmdsize == 0:
            break
        off += cmdsize
    return segs


def va_to_off(segs, va):
    for vmaddr, vmsize, fileoff, filesize in segs:
        if vmaddr <= va < vmaddr + vmsize:
            delta = va - vmaddr
            if delta < filesize:
                return fileoff + delta
            return None  # zero-fill / bss region, not backed by file
    return None


def read_cstr(image, off):
    end = image.index(b"\x00", off)
    return image[off:end]


def main():
    if len(sys.argv) < 2:
        sys.exit("usage: extract_sugoroku_dialogue.py <PopnRhythmin binary> [out.bin]")
    binpath = sys.argv[1]
    outpath = sys.argv[2] if len(sys.argv) > 2 else DEFAULT_OUT

    with open(binpath, "rb") as fh:
        image = select_thin(fh.read())
    segs = parse_segments(image)

    out = bytearray()
    total_strings = 0
    total_bytes = 0
    bad_utf8 = 0
    for va, count in POOLS:
        toff = va_to_off(segs, va)
        if toff is None:
            sys.exit("error: pointer table VA 0x%x not found in any segment" % va)
        out += struct.pack("<i", count)
        for i in range(count):
            ptr = u32le(image, toff + i * 4)
            soff = va_to_off(segs, ptr)
            if soff is None:
                sys.exit("error: pool 0x%x entry %d -> VA 0x%x not in file" % (va, i, ptr))
            s = read_cstr(image, soff)
            try:
                s.decode("utf-8")
            except UnicodeDecodeError:
                bad_utf8 += 1
            out += struct.pack("<i", len(s)) + s
            total_strings += 1
            total_bytes += len(s)

    with open(outpath, "wb") as fh:
        fh.write(out)

    # Report metrics only -- never the dialogue text itself.
    print("image slice: %d bytes, %d segments" % (len(image), len(segs)))
    print("pools: %d  strings: %d  content: %d bytes  file: %d bytes"
          % (len(POOLS), total_strings, total_bytes, len(out)))
    if bad_utf8:
        print("warning: %d strings did not decode as UTF-8 (unexpected)" % bad_utf8)
    expected = sum(c for _, c in POOLS)
    if total_strings != expected:
        sys.exit("error: extracted %d strings, expected %d" % (total_strings, expected))
    print("wrote %s" % os.path.abspath(outpath))


if __name__ == "__main__":
    main()
