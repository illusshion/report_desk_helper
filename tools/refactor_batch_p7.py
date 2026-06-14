#!/usr/bin/env python3
"""Batch extract util.lua (phase 7)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from refactor_extract import extract, remove_functions  # noqa: E402

UTIL = ROOT / 'lib' / 'report_desk_util.lua'

GAME_FUNCS = [
    'deskAutoReplyAllowed', 'deskAdminPlayerPaused', 'deskTickAdminPauseState',
    'deskGameMenuOpen', 'deskSampInGame',
]

DEDUP_FUNCS = [
    'chatLineSeenKey', 'markChatLineSeen', 'seedSeenChatLines', 'pruneChatSeenDeferred',
    'isDuplicateIngest', 'markIngestDedup', 'isReportLineConsumed', 'markReportLineConsumed',
    'markChatLineSeen', 'normalizeChatLine', 'chatLineAgeSeconds',
]

CACHE_FUNCS = [
    'invalidateUiCaches', 'markUiCacheDirty', 'invalidateFilterCache',
    'bumpThreadStructRev', 'bumpThreadMsgRev', 'syncThreadCount', 'rebuildNickIndex',
    'getFilterListSig', 'getFilteredThreadKeys',
]


def main() -> None:
    from refactor_extract import find_function_block, remove_functions
    # dedup list has duplicates - use unique
    dedup = list(dict.fromkeys([
        'normalizeChatLine', 'chatLineSeenKey', 'markChatLineSeen', 'seedSeenChatLines',
        'pruneChatSeenDeferred', 'isDuplicateIngest', 'markIngestDedup',
        'isReportLineConsumed', 'markReportLineConsumed', 'chatLineAgeSeconds',
        'deskSyncChatSeenAfterResume',
    ]))
    game = list(dict.fromkeys(GAME_FUNCS))
    cache = [f for f in CACHE_FUNCS if f not in game and f not in dedup]
    # getFilteredThreadKeys/getFilterListSig live in rules.lua
    util_lines = UTIL.read_text(encoding='utf-8').splitlines()
    cache = [f for f in cache if find_function_block(util_lines, f, 0)]

    for path, header, names in [
        (ROOT / 'lib' / 'report_desk_game_state.lua', '--[[ Модуль: пауза/AFK и состояние игры. ]]', game),
        (ROOT / 'lib' / 'report_desk_chat_dedup.lua', '--[[ Модуль: dedup чата и anti-replay. ]]', dedup),
        (ROOT / 'lib' / 'report_desk_thread_cache.lua', '--[[ Модуль: кеш тредов и фильтра списка. ]]', cache),
    ]:
        names_found = []
        lines = UTIL.read_text(encoding='utf-8').splitlines()
        from refactor_extract import find_function_block
        for n in names:
            if find_function_block(lines, n, 0):
                names_found.append(n)
        if not names_found:
            print('skip empty', path.name)
            continue
        names_found.sort(key=lambda n: find_function_block(lines, n, 0)[0])
        body = extract(UTIL, names_found, '')
        path.write_text(header + '\n\n' + body, encoding='utf-8', newline='\n')
        print('wrote', path.name, len(body.splitlines()), 'lines')
        remove_functions(UTIL, names_found)

    text = UTIL.read_text(encoding='utf-8')
    text = text.replace(
        'общие утилиты',
        'строки, цвета, звуки, шаблоны',
        1,
    )
    UTIL.write_text(text, encoding='utf-8', newline='\n')

    manifest = ROOT / 'config' / 'report_desk_bundle_manifest.lua'
    m = manifest.read_text(encoding='utf-8')
    if 'report_desk_game_state.lua' not in m:
        ins = """        'report_desk_game_state.lua',
        'report_desk_chat_dedup.lua',
        'report_desk_thread_cache.lua',
"""
        m = m.replace("        'report_desk_outbound.lua',", "        'report_desk_outbound.lua',\n" + ins)
        manifest.write_text(m, encoding='utf-8', newline='\n')
    print('util lines', len(UTIL.read_text(encoding='utf-8').splitlines()))


if __name__ == '__main__':
    main()
