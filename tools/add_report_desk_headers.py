# -*- coding: utf-8 -*-
"""Добавляет file-header и комментарии к local CONST в Report Desk."""
import re
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, 'lib')

HEADERS = {
    'report_desk_bootstrap.lua': 'Модуль: bootstrap — require зависимостей, imgui compat, encoding CP1251.',
    'report_desk_env_export.lua': 'Модуль: публикация locals в env для late chunk (checker).',
    'report_desk_theme.lua': 'Модуль: ImGui цвета, размеры UI чата/composer, applyModernDarkStyle.',
    'report_desk_state.lua': 'Модуль: settings, deskCache, threads state, builtin auto-rules.',
    'report_desk_hooks.lua': 'Модуль: перехват SAMP-событий (чат, диалоги, RPC меню /sp).',
    'report_desk_main.lua': 'Модуль: главный цикл MoonLoader, poll, autosave, hook health.',
    'report_desk_input.lua': 'Модуль: ввод, hotkeys, cursor policy, spectate input.',
    'report_desk_actions.lua': 'Модуль: действия admin (ans, sp, history, nick cache).',
    'report_desk_threads.lua': 'Модуль: треды репортов, сообщения, unread.',
    'report_desk_config.lua': 'Модуль: load/save config Lua files.',
    'report_desk_ingest.lua': 'Модуль: парс репортов [PC]/[S]/[M] и chat events.',
    'report_desk_ingest_runtime.lua': 'Модуль: runtime ingest, admin reply, auto-rules UI.',
    'report_desk_rules.lua': 'Модуль: auto-rules, scenarios, processChatLineIngest.',
    'report_desk_ui.lua': 'Модуль: ImGui окно Report Desk (список, чат, настройки).',
    'report_desk_chat.lua': 'Модуль: UI чата треда, bubbles, composer.',
    'report_desk_profanity.lua': 'Модуль: фильтр мата, toast, hooks.',
    'report_desk_profanity_words.lua': 'Модуль: словарь мата (данные).',
    'report_desk_cheats.lua': 'Модуль: admin cheats (GM, WH, airbreak, marker, TP).',
    'report_desk_skins.lua': 'Модуль: выдача скинов, каталог превью.',
    'report_desk_vehicles.lua': 'Модуль: спавн транспорта, каталог.',
    'report_desk_catalog_grid.lua': 'Модуль: сетка каталога skin/veh.',
    'report_desk_tex_loader.lua': 'Модуль: загрузка PNG с диска.',
    'report_desk_tex_pipeline.lua': 'Модуль: async IO + budgeted GPU upload текстур.',
    'report_desk_texcache.lua': 'Модуль: GPU кэш ImGui текстур.',
    'report_desk_spectate_session.lua': 'Модуль: сессия /sp, TD hooks, outbound queue.',
    'report_desk_spectate_stats.lua': 'Модуль: /st stats parse, HUD overlay, spectate health.',
    'report_desk_spectate_menu.lua': 'Модуль: кастомное ImGui меню действий /sp.',
    'report_desk_sp_ui.lua': 'Модуль: glue session + menu + ans для /sp UI.',
    'report_desk_sp_vehicle_hud.lua': 'Модуль: кастомный спидометр из server TextDraw.',
    'report_desk_spectate_ans.lua': 'Модуль: быстрый /ans bar в spectate (клавиша C).',
    'report_desk_sp_theme.lua': 'Модуль: общий ImGui chrome для /sp HUD/checker.',
    'report_desk_checker.lua': 'Модуль: checker HUD — online admins/leaders/friends + catalog.',
}

CONST_HINTS = {
    'LIST_W': 'ширина sidebar списка тредов, px',
    'THREAD_ROW_H': 'высота строки треда, px',
    'CHAT_GROUP_MAX_SEC': 'группировка bubble по времени, сек',
    'CHAT_DEFERRED_ADMIN_SEC': 'ожидание полной admin reply строки, сек',
    'OUTBOUND_DEDUP_SEC': 'dedup echo исходящих ans, сек',
    'PENDING_OUTBOUND_SEC': 'ожидание echo pending ans, сек',
    'WATCH_ANS_DELAY_MS': 'задержка watch auto-notify, мс',
    'PLAYER_NICK_CACHE_INTERVAL': 'интервал кэша nick→id, сек',
    'AUTO_RETRY_MS': 'retry auto-reply, мс',
    'SKIN_RADIUS_MAX_TARGETS': 'макс. игроков skin radius',
    'SKIN_APPLY_COOLDOWN_SEC': 'cooldown выдачи скинов, сек',
}


def set_header(path, header_text):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        content = f.read()
    new_header = f'--[[ {header_text} ]]\n'
    if content.startswith('--[['):
        # replace first line block first line only
        content = re.sub(r'^--\[\[[^\]]*\]\]\s*\n', new_header, content, count=1)
    else:
        content = new_header + content
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(content)


def annotate_consts(path):
    with open(path, 'r', encoding='utf-8', errors='replace') as f:
        lines = f.readlines()
    out = []
    for line in lines:
        m = re.match(r'^(\s*)(local\s+)?([A-Z][A-Z0-9_]*)\s*=\s*(.+)$', line.rstrip())
        if m and m.group(3) in CONST_HINTS and (not out or '--' not in out[-1]):
            hint = CONST_HINTS[m.group(3)]
            out.append(f"{m.group(1)}{m.group(2) or ''}{m.group(3)} = {m.group(4).split('--')[0].rstrip()}  -- {hint}\n")
            continue
        out.append(line)
    new = ''.join(out)
    with open(path, 'w', encoding='utf-8', newline='\n') as f:
        f.write(new)


def main():
    for name, hdr in HEADERS.items():
        p = os.path.join(LIB, name)
        if os.path.isfile(p):
            set_header(p, hdr)
            if name == 'report_desk_theme.lua' or name == 'report_desk_state.lua':
                annotate_consts(p)
            print('header', name)


if __name__ == '__main__':
    main()
