#!/usr/bin/env python3
"""Collapse excessive blank lines in Lua sources (max 1 blank between blocks)."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def normalize(text: str) -> str:
    lines = text.replace('\r\n', '\n').replace('\r', '\n').split('\n')
    stripped = [line.rstrip() for line in lines]
    # Убрать пустые строки, сохранить только код.
    code = [line for line in stripped if line != '']
    out: list[str] = []
    for i, line in enumerate(code):
        if i > 0:
            prev = code[i - 1]
            need_blank = (
                line.startswith('function ')
                or line.startswith('local function ')
                or (line.startswith('--') and not prev.startswith('--'))
            )
            if need_blank and out and out[-1] != '':
                out.append('')
        out.append(line)
    while out and out[-1] == '':
        out.pop()
    return '\n'.join(out) + '\n'


def main() -> int:
    root = Path(__file__).resolve().parents[1]
    targets = [
        root / 'lib' / 'report_desk_spectate_stats.lua',
        root / 'lib' / 'report_desk_util.lua',
        root / 'lib' / 'report_desk_spectate_session.lua',
    ]
    for path in targets:
        if not path.is_file():
            print(f'SKIP missing: {path}')
            continue
        raw = path.read_bytes()
        for enc in ('utf-8-sig', 'utf-8', 'cp1251'):
            try:
                text = raw.decode(enc)
                break
            except UnicodeDecodeError:
                text = None
        if text is None:
            print(f'FAIL decode: {path}')
            return 1
        before = len(text.splitlines())
        fixed = normalize(text)
        after = len(fixed.splitlines())
        path.write_text(fixed, encoding='utf-8', newline='\n')
        print(f'OK {path.name}: {before} -> {after} lines')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
