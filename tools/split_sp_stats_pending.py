#!/usr/bin/env python3
"""Split spectate_stats: ctx + pending submodule (no setfenv)."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'
STATS = LIB / 'report_desk_spectate_stats.lua'
CTX = LIB / 'report_desk_sp_stats_ctx.lua'
PENDING = LIB / 'report_desk_sp_spectate_pending.lua'

PENDING_FNS = [
    'markPendingSpCommand',
    'cancelPendingSp',
    'hasPendingSp',
    'tickPendingSp',
]

HOTFIX = '''
function M.isHudDragActive()
    return state.hudDrag.active
end

function M.wantsHudInput()
    if type(_G.deskSpectateOverlayInputAllowed) == 'function' and not _G.deskSpectateOverlayInputAllowed() then
        return state.hudDrag.active == true
    end
    if state.hudDrag.active then return true end
    if state.hudHovered then return true end
    local r = state.hudRect
    if not r then return false end
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin then return pin(r) end
    local ok, io = pcall(imgui.GetIO)
    if not ok or not io or not io.MousePos then return false end
    local mp = io.MousePos
    return mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1
end
'''


def find_m_block(lines: list[str], name: str) -> tuple[int, int] | None:
    pat = re.compile(r'^function\s+M\.' + re.escape(name) + r'\s*[\(\{]')
    for i, line in enumerate(lines):
        if not pat.match(line):
            continue
        base_indent = len(line) - len(line.lstrip(' '))
        fn_indents = [base_indent]
        for j in range(i + 1, len(lines)):
            ln = lines[j]
            stripped = ln.lstrip(' ')
            indent = len(ln) - len(stripped)
            if re.search(r'\bfunction\s*(\(|[\w_])', ln) and indent > base_indent:
                fn_indents.append(indent)
            if re.match(r'end\b', stripped):
                if fn_indents and indent == fn_indents[-1]:
                    fn_indents.pop()
                    if not fn_indents:
                        return i, j + 1
        return i, len(lines)
    return None


def collect_ctx_exports(core_lines: list[str]) -> list[str]:
    names: list[str] = []
    skip = {
        'M', 'ctx', 'imgui', 'specSession', 'spUi', 'specMenuMod', 'spTheme',
        'vehicleHud', 'keysHud', 'specCamera', 'spRefresh', 'wmDispatchCached',
    }
    for line in core_lines:
        m = re.match(r'^local function (\w+)', line)
        if m and m.group(1) not in skip:
            names.append(m.group(1))
            continue
        m = re.match(r'^local ([A-Za-z_]\w*)\s*=', line)
        if m and m.group(1) not in skip:
            names.append(m.group(1))
    return list(dict.fromkeys(names))


def main() -> None:
    text = STATS.read_text(encoding='utf-8')
    lines = text.splitlines(keepends=True)
    if lines and not lines[-1].endswith('\n'):
        lines[-1] += '\n'

    # extract pending blocks
    pending_parts: list[str] = []
    pending_ranges: list[tuple[int, int]] = []
    for name in PENDING_FNS:
        b = find_m_block([l.rstrip('\n') for l in lines], name)
        if not b:
            raise SystemExit(f'M.{name} not found')
        pending_ranges.append(b)
        pending_parts.append(''.join(lines[b[0]:b[1]]).rstrip())

    # remove pending from core (reverse order to keep indices)
    core_lines = list(lines)
    for start, end in sorted(pending_ranges, key=lambda x: x[0], reverse=True):
        del core_lines[start:end]
        # trim trailing blank lines after removal
        while start < len(core_lines) and core_lines[start].strip() == '':
            del core_lines[start]

    core_text = ''.join(core_lines)

    # strip return M from core (ctx returns ctx)
    core_text = re.sub(r'\nreturn M\s*\n?$', '\n', core_text.rstrip()) + '\n'

    # insert hotfix before updateHudHoverRect
    marker = 'function M.updateHudHoverRect'
    if HOTFIX.strip() not in core_text and marker in core_text:
        idx = core_text.index(marker)
        core_text = core_text[:idx] + HOTFIX + '\n' + core_text[idx:]
    elif 'function M.isHudDragActive' not in core_text:
        raise SystemExit('hotfix insert failed')

    # replace module header and local M = {}
    core_text = core_text.replace(
        '--[[ Модуль: /st stats parse, HUD overlay, spectate health. ]]\nlocal M = {}\n',
        '',
        1,
    )
    if core_text.startswith('local M = {}\n'):
        core_text = core_text[len('local M = {}\n'):]

    ctx_header = '''--[[ Модуль: общий контекст spectate stats (state, deps, helpers). ]]
local ctx = {}
ctx.M = {}
local M = ctx.M

function ctx.extend(mod)
    if type(mod) == 'function' then
        mod(ctx)
    end
end

'''
    core_lines_list = core_text.splitlines()
    exports = collect_ctx_exports(core_lines_list)
    bind = '\n'.join(f'ctx.{n} = {n}' for n in exports)
    ctx_body = ctx_header + core_text.rstrip() + '\n\n' + bind + '\n\nctx.M = M\nreturn ctx\n'

    pending_body = '''--[[ Модуль: pending /sp handshake. ]]
return function(ctx)
    local M = ctx.M
    local state = ctx.state
    local trim = ctx.trim
    local clearPendingSt = ctx.clearPendingSt
    local specPlayerActive = ctx.specPlayerActive
    local PENDING_SP_SEC = ctx.PENDING_SP_SEC
    local specSession = ctx.specSession
    local spUi = ctx.spUi
    local vehicleHud = ctx.vehicleHud
    local keysHud = ctx.keysHud
    local spRefresh = ctx.spRefresh
    local inputDeps = ctx.inputDeps
    local sampIsPlayerConnected = ctx.sampIsPlayerConnected
    local sampGetPlayerNickname = ctx.sampGetPlayerNickname

''' + '\n\n'.join(pending_parts) + '\nend\n'

    facade = '''--[[ Модуль: /st stats parse, HUD overlay, spectate health (facade). ]]
local ctx = require 'report_desk_sp_stats_ctx'
ctx.extend(require 'report_desk_sp_spectate_pending')
return ctx.M
'''

    CTX.write_text(ctx_body, encoding='utf-8', newline='\n')
    PENDING.write_text(pending_body, encoding='utf-8', newline='\n')
    STATS.write_text(facade, encoding='utf-8', newline='\n')

    print(f'ctx: {len(ctx_body.splitlines())} lines')
    print(f'pending: {len(pending_body.splitlines())} lines')
    print(f'facade: {len(facade.splitlines())} lines')
    print(f'ctx exports: {len(exports)}')


if __name__ == '__main__':
    main()
