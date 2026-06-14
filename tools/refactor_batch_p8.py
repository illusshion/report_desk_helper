#!/usr/bin/env python3
"""Batch extract hooks.lua (phase 8)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from refactor_extract import extract, remove_functions, find_function_block  # noqa: E402

HOOKS = ROOT / 'lib' / 'report_desk_hooks.lua'

INGEST = ['deskOnServerMessage']
SP_REFRESH = ['installDeskSpRefreshHooks']


def main() -> None:
    lines = HOOKS.read_text(encoding='utf-8').splitlines()
    sp_header = '''--[[ Модуль: хуки refresh SP (vehicle sync → stats/HUD). ]]
local spSessionMod
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

local vehicleHudMod
local function vehicleHud()
    if not vehicleHudMod then
        vehicleHudMod = require 'report_desk_sp_vehicle_hud'
    end
    return vehicleHudMod
end

'''
    for names, fname, header in [
        (INGEST, 'report_desk_hooks_ingest.lua', '--[[ Модуль: входящие SAMP-сообщения и ingest. ]]'),
        (SP_REFRESH, 'report_desk_hooks_sp_refresh.lua', sp_header + '--[[ Модуль: хуки refresh SP. ]]'),
    ]:
        found = [n for n in names if find_function_block(lines, n, 0)]
        if not found:
            continue
        body = extract(HOOKS, found, '')
        (ROOT / 'lib' / fname).write_text(header + '\n\n' + body, encoding='utf-8', newline='\n')
        remove_functions(HOOKS, found)
        print('wrote', fname)

    manifest = ROOT / 'config' / 'report_desk_bundle_manifest.lua'
    m = manifest.read_text(encoding='utf-8')
    if 'report_desk_hooks_ingest.lua' not in m:
        m = m.replace(
            "        'report_desk_hooks_outbound.lua',",
            "        'report_desk_hooks_ingest.lua',\n        'report_desk_hooks_sp_refresh.lua',\n        'report_desk_hooks_outbound.lua',",
        )
        manifest.write_text(m, encoding='utf-8', newline='\n')
    print('hooks lines', len(HOOKS.read_text(encoding='utf-8').splitlines()))


if __name__ == '__main__':
    main()
