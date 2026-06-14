#!/usr/bin/env python3
"""Batch extract large modules (phase 11) — exact_time split only."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from refactor_extract import extract, remove_functions, find_function_block  # noqa: E402

EXACT = ROOT / 'lib' / 'report_desk_exact_time.lua'

ONLINE_FUNCS = [
    'exactTimePollOnline', 'exactTimeOnPlayerJoin', 'exactTimeOnPlayerQuit',
    'exactTimeRebuildOnline', 'exactTimeFindPlayerByNick', 'exactTimePlayerRow',
]

UI_FUNCS = [
    'exactTimeDrawWindow', 'exactTimeDrawTab', 'exactTimeShouldDraw',
]


def split_file(path: Path, online_name: str, ui_name: str, online: list[str], ui: list[str]) -> None:
    lines = path.read_text(encoding='utf-8').splitlines()
    for funcs, fname, header in [
        (online, online_name, '--[[ Модуль: exact time — online scan. ]]'),
        (ui, ui_name, '--[[ Модуль: exact time — ImGui окно. ]]'),
    ]:
        found = [f for f in funcs if find_function_block(lines, f, 0)]
        if not found:
            print('skip', fname)
            continue
        found.sort(key=lambda n: find_function_block(lines, n, 0)[0])
        body = extract(path, found, '')
        (ROOT / 'lib' / fname).write_text(header + '\n\n' + body, encoding='utf-8', newline='\n')
        remove_functions(path, found)
        lines = path.read_text(encoding='utf-8').splitlines()
        print('wrote', fname, len(found))


def main() -> None:
    if not EXACT.is_file():
        print('no exact_time')
        return
    split_file(
        EXACT,
        'report_desk_exact_time_online.lua',
        'report_desk_exact_time_ui.lua',
        ONLINE_FUNCS,
        UI_FUNCS,
    )
    manifest = ROOT / 'config' / 'report_desk_bundle_manifest.lua'
    m = manifest.read_text(encoding='utf-8')
    ins = """        'report_desk_exact_time_online.lua',
        'report_desk_exact_time_ui.lua',
"""
    if 'report_desk_exact_time_online.lua' not in m:
        m = m.replace("        'report_desk_exact_time.lua',", ins + "        'report_desk_exact_time.lua',")
        manifest.write_text(m, encoding='utf-8', newline='\n')


if __name__ == '__main__':
    main()
