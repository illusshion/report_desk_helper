#!/usr/bin/env python3
import re
import pathlib

root = pathlib.Path(__file__).resolve().parents[1] / 'lib'
files = [
    'report_desk_sp_menu_td_block.lua',
    'report_desk_sp_stats_ctx.lua',
    'report_desk_spectate_stats.lua',
    'report_desk_sp_spectate_pending.lua',
]

def scan(path: pathlib.Path) -> None:
    text = path.read_bytes()
    try:
        s = text.decode('utf-8')
    except UnicodeDecodeError:
        s = text.decode('latin-1')
    for i, line in enumerate(s.splitlines(), 1):
        if line.strip().startswith('--'):
            continue
        for m in re.finditer(r"'([^'\\]|\\.)*'", line):
            inner = m.group(0)[1:-1]
            j = 0
            while j < len(inner):
                if inner[j] != '\\':
                    j += 1
                    continue
                if j + 1 >= len(inner):
                    print(f'{path.name}:{i}: trailing backslash in {m.group(0)!r}')
                    break
                c = inner[j + 1]
                if c in 'abfnrtv\\"\'':
                    j += 2
                    continue
                if c == 'x':
                    hx = inner[j + 2:j + 4]
                    if len(hx) < 2 or not all(x in '0123456789abcdefABCDEF' for x in hx):
                        print(f'{path.name}:{i}: bad \\x in {m.group(0)!r}')
                    j += 4
                    continue
                if c.isdigit():
                    k = j + 1
                    while k < len(inner) and k < j + 4 and inner[k].isdigit():
                        k += 1
                    j = k
                    continue
                print(f'{path.name}:{i}: invalid \\{c} in {m.group(0)!r} | line={line.strip()!r}')

for name in files:
    p = root / name
    if p.is_file():
        scan(p)
