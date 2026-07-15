#!/usr/bin/env python3
"""Generate PROGRESS.md: per-file @complete verification coverage.

Scans the reconstruction sources under Project/ and reports, per file, the
number of function/method definitions and how many carry a verified
``@complete`` Doxygen tag. Output is a Markdown table sorted by percent
descending.

Definition counting is approximate: Objective-C ``-``/``+`` method definitions
in implementation files, ``Class::method`` definitions, and inline definitions
in headers. Run from the repository root:

    python3 tools/gen_progress.py
"""

from __future__ import annotations

import glob
import os
import re

ROOT = 'Project'
EXTS = ('*.mm', '*.cpp', '*.m', '*.h', '*.c')
IMPL_EXTS = ('.mm', '.cpp', '.m', '.c')
# Reconstructed third-party sources that are also tracked for verification.
EXTRA_GLOBS = ('3rdparty/ziparchive/UnZipArchive.*',)

_OBJC_DEF = re.compile(r'^[-+]\s*\(')
_CXX_MEMBER = re.compile(r'^[A-Za-z_][\w\s:<>\*&,]*::~?[\w]+\s*\(')
_FREE_DEF = re.compile(r'^(?:static\s+|inline\s+|virtual\s+)*[A-Za-z_][\w:<>\*&\s]*\s[\*&]?\b([A-Za-z_]\w*)\s*\(')
_KEYWORDS = {'if', 'for', 'while', 'switch', 'return', 'else', 'catch', 'do', 'case'}
# Explicitly-inlined helpers are de-inlined reconstruction conveniences, not real
# binary functions, so they are excluded from the coverage denominator. In-class
# header definitions (implicitly inline, no keyword) are still counted.
_INLINE = re.compile(r'\b(?:inline|always_inline)\b')
# A counted function must map to a real binary function, i.e. carry a Ghidra
# address citation in its doc-comment block: the `@ghidraAddress 0x...` tag
# (preferred going forward) or any legacy `0x...` address in the comment.
_ADDR = re.compile(r'@ghidraAddress\s+0x[0-9a-fA-F]+|0x[0-9a-fA-F]{3,}|\bFUN_[0-9a-fA-F]{6,}')
_COMMENT_PREFIXES = ('//', '*', '/*', '*/')


_COMPLETE = re.compile(r'@complete\b')


def _doc_block_matches(lines: list[str], def_line: int, pattern: re.Pattern) -> bool:
    """True if ``pattern`` appears on the definition line or its doc-comment block."""
    if pattern.search(lines[def_line]):
        return True
    i = def_line - 1
    scanned = 0
    while i >= 0 and scanned < 25:
        stripped = lines[i].strip()
        if stripped == '':
            i -= 1
            scanned += 1
            continue
        if stripped.startswith(_COMMENT_PREFIXES):
            if pattern.search(lines[i]):
                return True
            i -= 1
            scanned += 1
            continue
        break  # hit code (previous def's body / a declaration): stop
    return False


def _is_definition(lines: list[str], i: int, is_impl: bool) -> bool:
    line = lines[i]
    if _INLINE.search(line):
        return False
    if is_impl and _OBJC_DEF.match(line):
        return True
    if _CXX_MEMBER.match(line) and not line.rstrip().endswith(';'):
        return True
    if not is_impl:
        stripped = line.strip()
        if stripped.startswith(_COMMENT_PREFIXES):
            return False
        match = _FREE_DEF.match(line)
        has_body = '{' in line or (i + 1 < len(lines) and lines[i + 1].strip().startswith('{'))
        if match and match.group(1) not in _KEYWORDS and has_body and not stripped.endswith(';'):
            return True
    return False


def scan(path: str) -> tuple[int, int]:
    """Return (addressed_definition_count, complete_count) for one source file.

    Only non-inline definitions carrying a Ghidra address citation are counted:
    every real reconstructed function maps to a binary address, so the address is
    the invariant that qualifies a function for the coverage denominator.
    """
    try:
        lines = open(path, encoding='utf-8', errors='replace').read().splitlines()
    except OSError:
        return (0, 0)
    is_impl = path.endswith(IMPL_EXTS)
    defs = complete = 0
    for i in range(len(lines)):
        if not _is_definition(lines, i, is_impl):
            continue
        if not _doc_block_matches(lines, i, _ADDR):
            continue  # no Ghidra address -> not a counted binary function
        defs += 1
        if _doc_block_matches(lines, i, _COMPLETE):
            complete += 1
    return (defs, complete)


def main() -> None:
    files = {p for ext in EXTS for p in glob.glob(os.path.join(ROOT, '**', ext), recursive=True)}
    for pattern in EXTRA_GLOBS:
        files.update(glob.glob(pattern, recursive=True))
    files = sorted(files)
    rows = []
    total_defs = total_complete = 0
    for path in files:
        defs, complete = scan(path)
        if defs == 0 and complete == 0:
            continue
        rows.append((path, defs, complete))
        total_defs += defs
        total_complete += complete

    def percent_value(complete: int, defs: int) -> float:
        return 100 * complete / defs if defs else -1.0

    def percent(complete: int, defs: int) -> str:
        return f'{100 * complete / defs:.0f}%' if defs else '—'

    rows.sort(key=lambda r: (-percent_value(r[2], r[1]), r[0]))
    out = [
        '# Reconstruction verification progress',
        '',
        'Percent of function/method definitions per file carrying a verified `@complete` Doxygen tag.',
        'Counts are approximate (ObjC `-/+` methods, `Class::method` definitions, and inline header',
        'definitions). Regenerate with `python3 tools/gen_progress.py`. Sorted by percent descending.',
        '',
        f'**Overall: {total_complete}/{total_defs} ({percent(total_complete, total_defs)}) '
        'definitions verified `@complete`.**',
        '',
        '| File | Defs | @complete | % |',
        '| --- | ---: | ---: | ---: |',
    ]
    out += [f'| `{path}` | {defs} | {complete} | {percent(complete, defs)} |' for path, defs, complete in rows]
    open('PROGRESS.md', 'w').write('\n'.join(out) + '\n')


if __name__ == '__main__':
    main()
