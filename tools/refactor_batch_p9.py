#!/usr/bin/env python3
"""Batch extract ui.lua (phase 9)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from refactor_extract import extract, remove_functions, find_function_block  # noqa: E402

UI = ROOT / 'lib' / 'report_desk_ui.lua'

SETTINGS = [
    'drawSettingsCardEnd', 'drawSettingsCardHeader', 'drawSettingsHint', 'drawSettingsSubsection',
    'drawSettingsHotkeyBind', 'deskPushFlatInputStyle', 'deskPopFlatInputStyle',
    'drawSettingsSliderInt', 'drawSettingsInputInt', 'drawDeskSearchClearRow',
    'drawAutoRepliesSettings', 'syncSettingsUiFromSettings', 'drawSettingsTab',
]

CHAT = [
    'drawAvatar', 'ellipsizeToWidth', 'drawUnreadBadge', 'drawDateSeparator', 'drawBubbleMessage',
    'chatHeaderNickColor', 'drawReportChannelChip', 'drawChatHeaderSpectateBtn', 'drawChatHeader',
    'sendComposerQuickButton', 'deskComposerQuickReplies', 'deskComposerQuickRowCount',
    'deskComposerHeight', 'composerQuickBtnWidth', 'pushComposerQuickBtnStyle', 'popComposerQuickBtnStyle',
    'drawComposerQuickRow', 'drawComposer', 'drawEmptyChatPlaceholder', 'drawThreadRow',
    'fillComposerQuickEditor', 'flushComposerQuickEditor', 'drawComposerQuickTabInner',
    'drawComposerQuickTab', 'applyChatScrollIfNeeded', 'drawChatNewMessageButton',
    'updateChatFollowBottom', 'drawChatPanel', 'drawReadAllThreadsButton', 'drawFilterChips',
    'drawThreadList',
]

FRAMES = [
    'uninstallDeskD3DHandlers', 'deskPassesGameKey', 'drawDeskSpSpectateOverlay',
    'deskCheckerHudVisible', 'deskSpSpectateOverlayVisible', 'uninstallDeskUiFrames',
    'parseMouseButtonVk', 'parseMouseButtonReleaseVk', 'applyHotkeyCapture',
]


def write_mod(name: str, header: str, funcs: list[str]) -> None:
    lines = UI.read_text(encoding='utf-8').splitlines()
    found = [f for f in funcs if find_function_block(lines, f, 0)]
    if not found:
        print('skip', name)
        return
    found.sort(key=lambda n: find_function_block(lines, n, 0)[0])
    body = extract(UI, found, '')
    (ROOT / 'lib' / name).write_text(header + '\n\n' + body, encoding='utf-8', newline='\n')
    remove_functions(UI, found)
    print('wrote', name, len(found), 'funcs')


def main() -> None:
    write_mod('report_desk_ui_settings.lua', '--[[ Модуль: вкладка настроек ImGui. ]]', SETTINGS)
    write_mod('report_desk_ui_chat.lua', '--[[ Модуль: чат, composer, список тредов. ]]', CHAT)
    write_mod('report_desk_ui_frames.lua', '--[[ Модуль: OnFrame helpers и WM capture. ]]', FRAMES)
    text = UI.read_text(encoding='utf-8')
    text = text.replace(
        '--[[ Модуль: главное окно Report Desk, чат, настройки. ]]',
        '--[[ Модуль: главное окно Report Desk (shell + OnFrame init). ]]',
        1,
    )
    UI.write_text(text, encoding='utf-8', newline='\n')
    manifest = ROOT / 'config' / 'report_desk_bundle_manifest.lua'
    m = manifest.read_text(encoding='utf-8')
    ins = """        'report_desk_ui_settings.lua',
        'report_desk_ui_chat.lua',
        'report_desk_ui_frames.lua',
"""
    if 'report_desk_ui_chat.lua' not in m:
        m = m.replace("        'report_desk_ui.lua',", ins + "        'report_desk_ui.lua',")
        manifest.write_text(m, encoding='utf-8', newline='\n')
    print('ui lines', len(text.splitlines()))


if __name__ == '__main__':
    main()
