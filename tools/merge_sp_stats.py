#!/usr/bin/env python3
"""Merge sp_stats ctx + submodules back into single report_desk_spectate_stats.lua."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'

SUBS = [
    'report_desk_sp_stats_cache.lua',
    'report_desk_sp_stats_parse.lua',
    'report_desk_sp_spectate_pending.lua',
    'report_desk_sp_spectate_nav.lua',
    'report_desk_sp_spectate_health.lua',
    'report_desk_sp_input.lua',
    'report_desk_sp_hud_overlay.lua',
]

FACADE = LIB / 'report_desk_spectate_stats.lua'


def extract_loadstring_body(path: Path) -> str:
    text = path.read_text(encoding='utf-8')
    m = re.search(r'loadstring\(\[=\[(.*?)\]=\]', text, re.DOTALL)
    if not m:
        raise SystemExit(f'no loadstring body in {path.name}')
    body = m.group(1).strip()
    # drop duplicate facade chunks erroneously included in input module
    cut = body.find('\nreturn M\n')
    if cut > 0:
        body = body[:cut].strip()
    # dedupe consecutive identical function M.x blocks (input module artifact)
    return body


def extract_ctx_core(path: Path) -> str:
    text = path.read_text(encoding='utf-8')
    # strip ctx wrapper header
    start = text.find('local ctx = {}')
    if start < 0:
        raise SystemExit('ctx header not found')
    # find core after ctx.extend function
    marker = 'function ctx.extend(mod)'
    mstart = text.find(marker)
    if mstart < 0:
        raise SystemExit('ctx.extend not found')
    end_marker = text.find('\n\nlocal M = {}', mstart)
    if end_marker < 0:
        end_marker = text.find('\nlocal M = {}', mstart)
    core_start = text.find('\n', mstart)
    while core_start < len(text) and text[core_start:core_start + 8] != '\nlocal M':
        nxt = text.find('\nlocal M = {}', core_start + 1)
        if nxt < 0:
            break
        core_start = nxt
    core_start = text.find('local M = {}', mstart)
    if core_start < 0:
        raise SystemExit('local M not in ctx')
    bind = text.find('ctx.M = M', core_start)
    if bind < 0:
        raise SystemExit('ctx bind not found')
    core = text[core_start:bind].rstrip()
    # remove ctx.* = assignments block before bind
    bind_block = text[bind:text.find('return ctx', bind)]
    return core, bind_block


def main() -> None:
    ctx_path = LIB / 'report_desk_sp_stats_ctx.lua'
    core, bind_block = extract_ctx_core(ctx_path)
    parts = ['--[[ Модуль: /st stats parse, HUD overlay, spectate health. ]]', core]
    for name in SUBS:
        p = LIB / name
        if p.is_file():
            parts.append('\n\n' + extract_loadstring_body(p))
    # facade-only functions (configure/install/delegates)
    if FACADE.is_file():
        ft = FACADE.read_text(encoding='utf-8')
        if 'ctx.extend' in ft:
            # use existing thin facade functions only
            m = re.search(r'(function M\.configure.*?return M)', ft, re.DOTALL)
            if m:
                parts.append('\n\n' + m.group(1).strip())
    else:
        parts.append('\n\nreturn M')
    if not parts[-1].strip().endswith('return M'):
        parts.append('\nreturn M')
    out = '\n'.join(parts) + '\n'
    # clean duplicate M.install/M.configure from submodule junk
    out = re.sub(r'\nfunction M\.configure\(deps\)[\s\S]*?^end\n(?=function M\.onSpRefresh)', '\n', out, count=1, flags=re.M)
    OUT = LIB / 'report_desk_spectate_stats.lua'
    OUT.write_text(out, encoding='utf-8', newline='\n')
    print('merged', OUT.name, len(out.splitlines()), 'lines')
    for name in ['report_desk_sp_stats_ctx.lua'] + SUBS:
        p = LIB / name
        if p.is_file():
            p.unlink()
            print('removed', name)


if __name__ == '__main__':
    main()
