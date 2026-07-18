#!/usr/bin/env python3
"""Convert a ``.strings`` localisation table to JSON.

Xcode compiles ``.strings`` files into flat binary plists (a dictionary of
key to localised string), which is what ships in ``PopnRhythmin.app`` and its
bundles (``InfoPlist.strings``, the RewardNetwork ``Error.strings`` and
``Message.strings``, the Settings ``Root.strings``). This tool reads that
form via ``plistlib`` and falls back to parsing the old-style text format
(``"key" = "value";`` with ``/* ... */`` and ``// ...`` comments, UTF-16 or
UTF-8) for uncompiled tables. Output is a JSON object sorted by key.

Usage::

    tools/strings_dump.py Error.strings
    tools/strings_dump.py Error.strings -o error.json
"""

from __future__ import annotations

import argparse
import json
import plistlib
import re
import sys
from typing import Any

TEXT_ENTRY_PATTERN = re.compile(
    r'"((?:[^"\\]|\\.)*)"\s*=\s*"((?:[^"\\]|\\.)*)"\s*;')
COMMENT_PATTERN = re.compile(r'/\*.*?\*/|//[^\n]*', re.DOTALL)
ESCAPE_MAP = {'n': '\n', 't': '\t', 'r': '\r', '"': '"', '\\': '\\'}


def unescape(text: str) -> str:
    return re.sub(r'\\(.)', lambda m: ESCAPE_MAP.get(m.group(1), m.group(1)), text)


def parse_text_strings(data: bytes) -> dict[str, str]:
    if data.startswith(b'\xff\xfe') or data.startswith(b'\xfe\xff'):
        text = data.decode('utf-16')
    else:
        text = data.decode('utf-8')
    text = COMMENT_PATTERN.sub('', text)
    return {unescape(k): unescape(v) for k, v in TEXT_ENTRY_PATTERN.findall(text)}


def convert(path: str) -> dict[str, Any]:
    with open(path, 'rb') as f:
        data = f.read()
    try:
        result = plistlib.loads(data)
    except plistlib.InvalidFileException:
        return parse_text_strings(data)
    if not isinstance(result, dict):
        raise ValueError(f'{path} is a plist but not a dictionary')
    return result


def main(argv: list[str]) -> int:
    ap = argparse.ArgumentParser(description=__doc__.split('\n', 1)[0])
    ap.add_argument('strings', help='path to the .strings file')
    ap.add_argument('-o', '--output', metavar='FILE',
                    help='write JSON to FILE instead of stdout')
    args = ap.parse_args(argv)
    try:
        result = convert(args.strings)
    except (ValueError, UnicodeDecodeError) as e:
        print(f'error: {e}', file=sys.stderr)
        return 1
    text = json.dumps(result, indent=2, sort_keys=True, ensure_ascii=False) + '\n'
    if args.output:
        with open(args.output, 'w', encoding='utf-8') as f:
            f.write(text)
    else:
        sys.stdout.write(text)
    return 0


if __name__ == '__main__':
    sys.exit(main(sys.argv[1:]))
