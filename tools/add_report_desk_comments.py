# -*- coding: utf-8 -*-
"""Добавляет русские комментарии к функциям Report Desk (только -- строки)."""
import re
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

FILES = [
    'report_desk_bootstrap.lua',
    'report_desk_theme.lua',
    'report_desk_state.lua',
    'report_desk_env_export.lua',
    'report_desk_hooks.lua',
    'report_desk_main.lua',
    'report_desk_input.lua',
    'report_desk_actions.lua',
    'report_desk_threads.lua',
    'report_desk_config.lua',
    'report_desk_ingest.lua',
    'report_desk_ingest_runtime.lua',
    'report_desk_rules.lua',
    'report_desk_ui.lua',
    'report_desk_chat.lua',
    'report_desk_profanity.lua',
    'report_desk_profanity_words.lua',
    'report_desk_cheats.lua',
    'report_desk_skins.lua',
    'report_desk_vehicles.lua',
    'report_desk_catalog_grid.lua',
    'report_desk_tex_loader.lua',
    'report_desk_tex_pipeline.lua',
    'report_desk_texcache.lua',
    'report_desk_spectate_session.lua',
    'report_desk_spectate_stats.lua',
    'report_desk_spectate_menu.lua',
    'report_desk_sp_ui.lua',
    'report_desk_sp_vehicle_hud.lua',
    'report_desk_spectate_ans.lua',
    'report_desk_sp_theme.lua',
    'report_desk_checker.lua',
]

ENTRY = [
    os.path.join(ROOT, 'admin_report_desk.lua'),
    os.path.join(ROOT, 'report_desk_app.lua'),
    os.path.join(ROOT, 'report_desk_deps.lua'),
    os.path.join(ROOT, 'report_desk_autoupdate.lua'),
]

# Точные комментарии для известных имён.
EXACT = {
    'main': 'Главный цикл MoonLoader: init, hooks, poll ingest, autosave.',
    'onScriptTerminate': 'Cleanup при выгрузке скрипта.',
    'deskOnServerMessage': 'Центральный обработчик onServerMessage: checker, spectate, ingest, profanity.',
    'deskIsServerMsgHookActive': 'Hook onServerMessage установлен и активен.',
    'installDeskServerMessageHook': 'Устанавливает перехват onServerMessage.',
    'installDeskSpectateDialogHook': 'Перехват onShowDialog: /st stats и checker dialogs.',
    'installDeskSpectateToggleHook': 'Перехват onTogglePlayerSpectating для /sp UI.',
    'installDeskSendChatHook': 'Перехват исходящего чата (profanity, auto-rules).',
    'installDeskSendCommandHook': 'Перехват /sp и других команд из чата.',
    'installDeskPlayerQuitHook': 'Quit игрока → checker, spectate exit, thread offline.',
    'installDeskPlayerJoinHook': 'Join → checker notify/catalog.',
    'installDeskPlayerStreamInHook': 'StreamIn → checker rebuild schedule.',
    'installDeskSpMenuHooks': 'Блок SA-Menu (onInitMenu/onShowMenu/onHideMenu) в /sp.',
    'installDeskSpMenuRpcBlock': 'RPC-блок серверного меню /sp (INITMENU/SHOWMENU/HIDEMENU).',
    'deskReinstallSpMenuHooks': 'Переустановка SP menu hooks если слетели.',
    'deskUninstall': 'Снятие всех desk hooks при terminate.',
    'pollReportIngest': 'Fallback poll sampGetChatString когда hook пропустил строку.',
    'checkerTick': 'Периодика checker: rebuild online, AFK, spawn catalog sync.',
    'checkerRebuildOnline': 'Сопоставляет каталог admin/leader/friend с онлайном SAMP.',
    'checkerInit': 'Инициализация checker HUD и catalog при старте.',
    'applyModernDarkStyle': 'ImGui тёмная тема Report Desk.',
    'ensureCheatsSettings': 'Дефолты и миграция settings.cheats.',
    'M.load': 'Загружает core + checker chunks в общий env.',
    'M.unload': 'Выгрузка bundle, deskUninstall.',
}

PREFIX = [
    (r'^installDesk', 'Устанавливает SAMP hook.'),
    (r'^desk', 'Desk hook/helper.'),
    (r'^checker', 'Checker (admin HUD/catalog).'),
    (r'^drawChecker', 'Отрисовка checker UI.'),
    (r'^poll', 'Poll/опрос.'),
    (r'^send', 'Отправка команды/сообщения на сервер.'),
    (r'^parse', 'Парсинг данных с сервера/чата.'),
    (r'^onShow', 'Обработчик показа UI/диалога.'),
    (r'^onSp', 'Обработчик /sp spectate.'),
    (r'^onToggle', 'Обработчик toggle spectating.'),
    (r'^flush', 'Сброс/отправка очереди.'),
    (r'^tick', 'Периодический tick main loop.'),
    (r'^forceExit', 'Принудительный выход из spectate.'),
    (r'^requestStats', 'Запрос /st статистики игрока.'),
    (r'^M\.', 'Публичный API модуля.'),
]

SKIP_PREV = re.compile(r'^\s*--(?!\[\[)')


def comment_for(name):
    if name in EXACT:
        return EXACT[name]
    for pat, msg in PREFIX:
        if re.search(pat, name):
            return msg
    # CamelCase → слова
    w = re.sub(r'([a-z])([A-Z])', r'\1 \2', name)
    w = w.replace('_', ' ')
    return w[0].upper() + w[1:] if w else name


def process(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()

    out = []
    i = 0
    while i < len(lines):
        line = lines[i]
        m = re.match(r'^((?:local\s+)?function\s+)([\w.:]+)\s*\(', line)
        if m and i > 0:
            prev = lines[i - 1].rstrip()
            if not SKIP_PREV.match(prev) and not prev.endswith(']]'):
                indent = re.match(r'^(\s*)', line).group(1)
                fn = m.group(2)
                if fn not in ('trim', 'uiText', 'cp1251ToUtf8', 'utf8ToCp1251'):
                    c = comment_for(fn)
                    out.append(f'{indent}-- {c}\n')
        out.append(line)
        i += 1

    new = ''.join(out)
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        old = f.read()
    if new != old:
        with open(path, 'w', encoding='utf-8', newline='\n') as f:
            f.write(new)
        return True
    return False


def main():
    n = 0
    for name in FILES:
        p = os.path.join(LIB, name)
        if os.path.isfile(p) and process(p):
            n += 1
            print('updated', name)
    for p in ENTRY:
        if os.path.isfile(p) and process(p):
            n += 1
            print('updated', os.path.basename(p))
    print('done, files changed:', n)


if __name__ == '__main__':
    main()
