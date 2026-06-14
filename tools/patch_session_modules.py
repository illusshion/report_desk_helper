#!/usr/bin/env python3
"""Remove menu TD code from session; wire menu_block + td_router."""
from __future__ import annotations

import re
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SESSION = ROOT / 'lib' / 'report_desk_spectate_session.lua'

HEADER = '''local menuBlock = require 'report_desk_sp_menu_td_block'
local tdRouter = require 'report_desk_sp_td_router'
'''

DELEGATES = '''
function M.shouldSuppressServerSpMenu()
    return menuBlock.shouldSuppressServerSpMenu()
end

function M.isAwaitingSpectate()
    return menuBlock.isAwaitingSpectate()
end

function M.markAwaitingSpectate(on)
    menuBlock.markAwaitingSpectate(on)
end

function M.tdHooksNeeded()
    return tdRouter.tdHooksNeeded()
end

function M.shouldBlockSpMenuClick(textdrawId)
    return menuBlock.shouldBlockSpMenuClick(textdrawId)
end

function M.isServerSpMenuTextDraw(id, data, text)
    return menuBlock.isServerSpMenuTextDraw(id, data, text)
end

function M.onShowTextDraw(id, data)
    return tdRouter.onShowTextDraw(id, data)
end

function M.onTextDrawSetString(id, text)
    return tdRouter.onTextDrawSetString(id, text)
end

function M.isServerSpSamMenu(menuTitle, x, y, columns)
    return menuBlock.isServerSpSamMenu(menuTitle, x, y, columns)
end

function M.captureServerMenuLayout(x, y, columns, title)
    local menu = package.loaded['report_desk_spectate_menu']
    if menu and menu.applyServerLayout then
        pcall(menu.applyServerLayout, {
            x = tonumber(x),
            y = tonumber(y),
            columns = columns,
            title = title,
        })
    end
end

local function clearMenuColumnState()
    menuBlock.clearMenuColumnState()
end
'''

CONFIGURE_EXTRA = '''
    menuBlock.configure({
        session = session,
        trim = trimFn,
        getSettings = getSettingsFn,
        ensureTdHooks = function()
            if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
        end,
    })
    tdRouter.configure({ menuBlock = menuBlock, getSettings = getSettingsFn })
'''


def drop_function_block(lines: list[str], name: str) -> list[str]:
    from refactor_extract import find_function_block  # type: ignore

    block = find_function_block(lines, name)
    if not block:
        return lines
    i, j = block
    return lines[:i] + lines[j:]


def main() -> None:
    import sys
    sys.path.insert(0, str(ROOT / 'tools'))
    from refactor_extract import find_function_block

    lines = SESSION.read_text(encoding='utf-8').splitlines()
    # insert requires after callHookPrev
    for idx, line in enumerate(lines):
        if line.startswith('local function callHookPrev'):
            end = find_function_block(lines, 'callHookPrev')
            if end:
                insert_at = end[1]
                lines = lines[:insert_at] + HEADER.strip().splitlines() + DELEGATES.strip().splitlines() + lines[insert_at:]
            break

    # remove SP_MENU block through SP_MENU_COLUMN (before OUTBOUND/VEHICLE)
    out = []
    skip = False
    for line in lines:
        if line.startswith('local SP_MENU_MARKERS'):
            skip = True
            continue
        if skip and line.startswith('local VEHICLE_HUD_X_MIN'):
            skip = False
        if skip and line.startswith('local SP_MENU_COLUMN'):
            continue
        if skip:
            continue
        out.append(line)
    lines = out

    # remove blockedSpMenu through onTextDrawSetString function
    for fname in [
        'clearMenuColumnState', 'suppressSpMenuActive', 'normalizeMenuText',
        'tdPosX', 'tdPosY', 'isSpMenuOverlayText', 'isSpMenuNumericText',
        'isBlankButtonText', 'isVehicleHudText', 'isVehicleHudColumnX',
        'isVehicleHudBottomArea', 'isSpMenuColumnX', 'isServerSpMenuText',
        'isLikelyVehicleGaugeText', 'rememberMenuColumn',
        'shouldSuppressServerSpMenu', 'isAwaitingSpectate', 'markAwaitingSpectate',
        'vehicleHudPipelineActive', 'tdHooksNeeded', 'handleVehicleTextDraw',
        'isSpMenuRowY', 'isServerSpMenuTextDrawOnly', 'shouldBlockSpMenuClick',
        'isServerSpMenuTextDraw', 'onShowTextDraw', 'onTextDrawSetString',
    ]:
        # only remove local/old defs not our delegates (function M.xxx that delegate)
        block = find_function_block(lines, fname)
        if not block:
            continue
        i, j = block
        chunk = '\n'.join(lines[i:j])
        if 'menuBlock' in chunk or 'tdRouter' in chunk:
            continue
        lines = lines[:i] + lines[j:]

    # remove blockedSpMenuTdIds line and duplicate local blocked
    lines = [l for l in lines if l.strip() != 'local blockedSpMenuTdIds = {}']

    # remove SAM menu tail functions
    for fname in ['samMenuItemPlain', 'samMenuColumnsMatchSp', 'isServerSpSamMenu', 'captureServerMenuLayout']:
        block = find_function_block(lines, fname)
        if block:
            i, j = block
            chunk = '\n'.join(lines[i:j])
            if 'menuBlock' not in chunk:
                lines = lines[:i] + lines[j:]

    # patch configure
    patched = []
    for i, line in enumerate(lines):
        patched.append(line)
        if line.strip() == 'cbEnsureTdHooks = deps.ensureTdHooks' and CONFIGURE_EXTRA.strip() not in '\n'.join(lines):
            patched.extend(CONFIGURE_EXTRA.strip().splitlines())
    lines = patched

    SESSION.write_text('\n'.join(lines).rstrip() + '\n', encoding='utf-8')
    print('session lines:', len(lines))


if __name__ == '__main__':
    main()
