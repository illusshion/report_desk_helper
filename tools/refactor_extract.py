#!/usr/bin/env python3
"""Extract top-level Lua functions from a file by name."""
from __future__ import annotations

import re
import sys
from pathlib import Path


def find_function_block(lines: list[str], name: str, start: int = 0) -> tuple[int, int] | None:
    pat = re.compile(r'^function\s+' + re.escape(name) + r'\s*[\(\{]')
    local_pat = re.compile(r'^local\s+function\s+' + re.escape(name) + r'\s*[\(\{]')
    for i in range(start, len(lines)):
        if not (pat.match(lines[i]) or local_pat.match(lines[i])):
            continue
        base_indent = len(lines[i]) - len(lines[i].lstrip(' '))
        fn_indents = [base_indent]
        for j in range(i + 1, len(lines)):
            line = lines[j]
            stripped = line.lstrip(' ')
            indent = len(line) - len(stripped)
            if re.search(r'\bfunction\s*(\(|[\w_])', line) and indent > base_indent:
                fn_indents.append(indent)
            if re.match(r'end\b', stripped):
                if fn_indents and indent == fn_indents[-1]:
                    fn_indents.pop()
                    if not fn_indents:
                        return i, j + 1
        return i, len(lines)
    return None


def extract(path: Path, names: list[str], header: str = '') -> str:
    lines = path.read_text(encoding='utf-8').splitlines()
    parts = [header.rstrip()] if header.strip() else []
    pos = 0
    for name in names:
        block = find_function_block(lines, name, pos)
        if not block:
            raise SystemExit(f'{path}: function {name} not found')
        i, j = block
        parts.append('\n'.join(lines[i:j]))
        pos = j
    return '\n\n'.join(parts) + '\n'


def remove_functions(path: Path, names: list[str]) -> None:
    lines = path.read_text(encoding='utf-8').splitlines()
    remove_ranges: list[tuple[int, int]] = []
    for name in names:
        block = find_function_block(lines, name, 0)
        if not block:
            raise SystemExit(f'{path}: function {name} not found for removal')
        remove_ranges.append(block)
    out: list[str] = []
    idx = 0
    ri = 0
    remove_ranges.sort()
    while idx < len(lines):
        if ri < len(remove_ranges) and idx == remove_ranges[ri][0]:
            idx = remove_ranges[ri][1]
            ri += 1
            while idx < len(lines) and lines[idx].strip() == '':
                idx += 1
            continue
        out.append(lines[idx])
        idx += 1
    text = '\n'.join(out).rstrip() + '\n'
    path.write_text(text, encoding='utf-8')


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'extract':
        path, out, *names = sys.argv[2:]
        header = ''
        if names and names[0] == '--header':
            header = names[1]
            names = names[2:]
        Path(out).write_text(extract(Path(path), names, header), encoding='utf-8')
        print('wrote', out)
    elif cmd == 'remove':
        path, *names = sys.argv[2:]
        remove_functions(Path(path), names)
        print('cleaned', path)
    else:
        raise SystemExit('usage: extract|remove')
