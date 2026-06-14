#!/usr/bin/env python3
"""Split report_desk_spectate_stats.lua — submodules extend shared ctx via setfenv."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))

STATS = ROOT / 'lib' / 'report_desk_spectate_stats.lua'
LIB = ROOT / 'lib'

MODULES: dict[str, tuple[str, list[str]]] = {
    'report_desk_sp_stats_cache.lua': (
        '--[[ Модуль: кеш stats entry, hasStats/hasFullStats. ]]',
        [
            'nickColorFor', 'getTargetId', 'getLastSubject', 'getMyPlayerId', 'getMaxPlayerId',
            'hasStats', 'hasFullStats', 'resolveSpectateTargetPed', 'syncFromSession',
            'getEntry', 'formatCompact', 'pingColor', 'refreshLivePing',
        ],
    ),
    'report_desk_sp_stats_parse.lua': (
        '--[[ Модуль: парс /st dialog и chat stats. ]]',
        [
            'cancelPendingSt', 'parseSpServerLine', 'parseDialogText', 'requestStats',
            'maybeAutoRequest', 'autoRequestIfEnabled', 'onServerMessage',
            'dialogLooksLikePlayerStats', 'shouldInterceptStatsDialog', 'onShowDialog',
            'markPendingSt', 'hasPendingSt',
        ],
    ),
    'report_desk_sp_spectate_pending.lua': (
        '--[[ Модуль: pending /sp, reject server line. ]]',
        [
            'markPendingSpCommand', 'cancelPendingSp', 'hasPendingSp', 'tickPendingSp',
        ],
    ),
    'report_desk_sp_spectate_nav.lua': (
        '--[[ Модуль: nearby ring, stepSpectate, trail. ]]',
        [
            'isSpectateCandidate', 'getNearbySpectateList', 'findSpatialNearbySpectateId',
            'findAdjacentSpectateId', 'stepSpectate',
        ],
    ),
    'report_desk_sp_spectate_health.lua': (
        '--[[ Модуль: tickSpectateHealth, orphan exit. ]]',
        [
            'forceExitSpectate', 'tickSpectateHealth', 'setSpectateTarget', 'clearSpectateTarget',
            'notifyTargetQuit', 'isSpectating', 'shouldBlockSpectateOff', 'onTogglePlayerSpectating',
            'onSpCommandOff',
        ],
    ),
    'report_desk_sp_input.lua': (
        '--[[ Модуль: WM, camera, consume menu keys. ]]',
        [
            'isGameTextInputActive', 'frameWantsCursor', 'handleSpectateWindowMessage',
            'maintainCamera', 'consumeSpectateMenuKey', 'installInputHooks', 'ensureInputHooks',
            'uninstallSpSpectateOverlayFrame', 'uninstallWmHandler', 'uninstallSpectatePlayerHook',
            'ensureSpectatePlayerHook', 'wantsHudInput', 'wantsSpMenuInput', 'wantsVehicleHudInput',
            'wantsKeysHudInput', 'isKeysHudDragActive', 'isHudDragActive',
        ],
    ),
    'report_desk_sp_hud_overlay.lua': (
        '--[[ Модуль: ImGui stats HUD (drawOverlay, drag, persist). ]]',
        [
            'persistHudEnabled', 'shouldPersistHud', 'snapshotPersistHud', 'getHudDisplayId',
            'isHudActive', 'shouldShowHud', 'drawStatRow', 'wantedColor', 'drawWantedRow',
            'drawWarnsRow', 'drawOverlay', 'drawOverlayImpl', 'isHudHovered', 'resetHudDrag',
            'resetSpHudPointers', 'updateHudHoverRect',
        ],
    ),
}

FACADE_M = [
    'configure', 'install', 'flushOutbound', 'hasOutboundPending',
    'drawSpMenu', 'drawVehicleHud', 'shouldShowVehicleHud', 'drawKeysHud',
    'shouldShowKeysHud', 'onSpRefreshEnterVehicle', 'onSpRefreshExitVehicle',
    'onSpRefreshSetInterior', 'onSpRefreshVehicleSync', 'onSpRefreshPassengerSync',
    'onSpRefreshPlayerSync', 'onSpRefreshSpectatePlayer', 'onSpRefreshSpectateVehicle',
    'onSpRefreshStreamIn',
]

SUBMODULE_LOAD_ORDER = [
    'report_desk_sp_stats_cache',
    'report_desk_sp_stats_parse',
    'report_desk_sp_spectate_pending',
    'report_desk_sp_spectate_nav',
    'report_desk_sp_spectate_health',
    'report_desk_sp_input',
    'report_desk_sp_hud_overlay',
]


def find_m_function_block(lines: list[str], name: str, start: int = 0) -> tuple[int, int] | None:
    pat = re.compile(r'^function\s+M\.' + re.escape(name) + r'\s*[\(\{]')
    for i in range(start, len(lines)):
        if not pat.match(lines[i]):
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


def extract_m_blocks(lines: list[str], names: list[str]) -> tuple[str, list[tuple[int, int]]]:
    parts: list[str] = []
    ranges: list[tuple[int, int]] = []
    for name in names:
        b = find_m_function_block(lines, name, 0)
        if not b:
            raise SystemExit(f'M.{name} not found')
        ranges.append(b)
        parts.append('\n'.join(lines[b[0]:b[1]]))
    return '\n\n'.join(parts) + '\n', ranges


def remove_ranges(lines: list[str], ranges: list[tuple[int, int]]) -> list[str]:
    remove = sorted(ranges)
    out: list[str] = []
    idx = 0
    ri = 0
    while idx < len(lines):
        if ri < len(remove) and idx == remove[ri][0]:
            idx = remove[ri][1]
            ri += 1
            while idx < len(lines) and lines[idx].strip() == '':
                idx += 1
            continue
        out.append(lines[idx])
        idx += 1
    return out


def wrap_submodule(header: str, body: str) -> str:
    return f'''{header}
return function(ctx)
    local M = ctx.M
    local env = ctx.env()
    local fn, err = loadstring([=[
{body.rstrip()}
]=], '@sp_stats_sub')
    if not fn then error(err) end
    setfenv(fn, env)
    fn()
end
'''


def collect_ctx_exports(core_lines: list[str]) -> list[str]:
    names: list[str] = []
    skip = {'M', 'ctx', 'imgui', 'specSession', 'spUi', 'specMenuMod', 'spTheme', 'vehicleHud',
            'keysHud', 'specCamera', 'spRefresh', 'wmDispatchCached'}
    for line in core_lines:
        m = re.match(r'^local function (\w+)', line)
        if m and m.group(1) not in skip:
            names.append(m.group(1))
            continue
        m = re.match(r'^local ([A-Za-z_]\w*)\s*=', line)
        if m and m.group(1) not in skip:
            names.append(m.group(1))
    return list(dict.fromkeys(names))


def wrap_ctx(core: str) -> str:
    core_lines = core.splitlines()
    exports = collect_ctx_exports(core_lines)
    bind = '\n'.join(f'ctx.{n} = {n}' for n in exports)
    return '''--[[ Модуль: общий контекст spectate stats (state, deps, setfenv). ]]
local ctx = {}
ctx.M = {}

function ctx.env()
    return setmetatable({}, {
        __index = function(_, k)
            local v = ctx[k]
            if v ~= nil then return v end
            if ctx.M[k] ~= nil then return ctx.M[k] end
            return _G[k]
        end,
        __newindex = function(_, k, v)
            ctx[k] = v
        end,
    })
end

function ctx.extend(mod)
    if type(mod) == 'function' then
        mod(ctx)
    end
end

''' + core + bind + '''

ctx.M = M
return ctx
'''


def wrap_facade(facade_body: str) -> str:
    loads = '\n'.join(f"ctx.extend(require '{n}')" for n in SUBMODULE_LOAD_ORDER)
    return f'''--[[ Модуль: spectate stats — тонкий фасад (/st, SP HUD). ]]
local ctx = require 'report_desk_sp_stats_ctx'
local M = ctx.M

{loads}

{facade_body.rstrip()}

return M
'''


def update_bundle_preload() -> None:
    ps1 = ROOT / 'tools' / 'bundle_report_desk.ps1'
    text = ps1.read_text(encoding='utf-8')
    if 'report_desk_sp_stats_ctx' in text:
        return
    preload = '''    @{ Name = 'report_desk_sp_stats_ctx'; File = 'report_desk_sp_stats_ctx.lua' },
    @{ Name = 'report_desk_sp_stats_cache'; File = 'report_desk_sp_stats_cache.lua' },
    @{ Name = 'report_desk_sp_stats_parse'; File = 'report_desk_sp_stats_parse.lua' },
    @{ Name = 'report_desk_sp_spectate_pending'; File = 'report_desk_sp_spectate_pending.lua' },
    @{ Name = 'report_desk_sp_spectate_nav'; File = 'report_desk_sp_spectate_nav.lua' },
    @{ Name = 'report_desk_sp_spectate_health'; File = 'report_desk_sp_spectate_health.lua' },
    @{ Name = 'report_desk_sp_input'; File = 'report_desk_sp_input.lua' },
    @{ Name = 'report_desk_sp_hud_overlay'; File = 'report_desk_sp_hud_overlay.lua' },
'''
    text = text.replace(
        "@{ Name = 'report_desk_spectate_stats'; File = 'report_desk_spectate_stats.lua' },",
        preload + "    @{ Name = 'report_desk_spectate_stats'; File = 'report_desk_spectate_stats.lua' },",
    )
    bundle_inputs = '''    'report_desk_sp_stats_ctx.lua',
    'report_desk_sp_stats_cache.lua',
    'report_desk_sp_stats_parse.lua',
    'report_desk_sp_spectate_pending.lua',
    'report_desk_sp_spectate_nav.lua',
    'report_desk_sp_spectate_health.lua',
    'report_desk_sp_input.lua',
    'report_desk_sp_hud_overlay.lua',
'''
    text = text.replace(
        "    'report_desk_spectate_stats.lua',",
        bundle_inputs + "    'report_desk_spectate_stats.lua',",
    )
    ps1.write_text(text, encoding='utf-8', newline='\n')
    print('updated bundle_report_desk.ps1')


def main() -> None:
    lines = STATS.read_text(encoding='utf-8').splitlines()
    all_remove: list[tuple[int, int]] = []
    all_m: set[str] = set()
    for _, (_, names) in MODULES.items():
        all_m.update(names)
    all_m.update(FACADE_M)

    for fname, (header, names) in MODULES.items():
        body, ranges = extract_m_blocks(lines, names)
        all_remove.extend(ranges)
        out = wrap_submodule(header, body)
        (LIB / fname).write_text(out, encoding='utf-8', newline='\n')
        print('wrote', fname, len(out.splitlines()), 'lines')

    facade_body, facade_ranges = extract_m_blocks(lines, FACADE_M)
    all_remove.extend(facade_ranges)

    core_lines = remove_ranges(lines, all_remove)
    while core_lines and core_lines[-1].strip() in ('return M', ''):
        core_lines.pop()
    # drop module header duplicate if present
    if core_lines and core_lines[0].startswith('--[['):
        pass
    core = '\n'.join(core_lines).rstrip() + '\n'
    (LIB / 'report_desk_sp_stats_ctx.lua').write_text(wrap_ctx(core), encoding='utf-8', newline='\n')
    print('wrote ctx', len(wrap_ctx(core).splitlines()), 'lines')

    STATS.write_text(wrap_facade(facade_body), encoding='utf-8', newline='\n')
    print('facade', len(wrap_facade(facade_body).splitlines()), 'lines')
    update_bundle_preload()


if __name__ == '__main__':
    main()
