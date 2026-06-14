#!/usr/bin/env python3
"""Fix report_desk_sp_menu_td_block.lua MoonLoader CP1251 escape issues."""
from pathlib import Path

PATH = Path(__file__).resolve().parents[1] / 'lib' / 'report_desk_sp_menu_td_block.lua'

MARKERS = """
local function cp1251(...)
    return string.char(...)
end

local SP_MENU_MARKERS = {
    'exit', 'mute', 'slap', 'stats', 'stat', 'update', 'tow', 'tr', 'skip',
    'weap', 'skick', 'info', 'freeze', 'dgun', 'kick', 'ban', 'jail', 'warn',
    '-exit-', 'exit-',
    cp1251(0xC2, 0xFB, 0xF5, 0xEE, 0xE4),
    cp1251(0xEC, 0xF3, 0xF2),
    cp1251(0xF1, 0xEB, 0xFD, 0xEF),
    cp1251(0xF1, 0xF2, 0xE0, 0xF2),
    cp1251(0xEE, 0xE1, 0xED, 0xEE, 0xE2),
    cp1251(0xE0, 0xEF, 0xE4, 0xE5, 0xE9, 0xF2),
    cp1251(0xED, 0xE0, 0xF1, 0xF2, 0xF0),
    cp1251(0xEC, 0xE8, 0xF0),
    cp1251(0xE7, 0xE0, 0xEC, 0xEE, 0xF0),
    cp1251(0xEE, 0xF0, 0xF3, 0xE6),
    cp1251(0xE2, 0xEE, 0xE4),
    cp1251(0xF1, 0xED, 0xFF, 0xF2),
    cp1251(0xF1, 0xEB, 0xFD, 0xEF, 0xED),
    cp1251(0xE4, 0xEE, 0xF1, 0xF2, 0xE0),
}
""".strip()

text = PATH.read_text(encoding='utf-8')
start = text.find('local SP_MENU_MARKERS')
end = text.find('local SP_MENU_COLUMN_LEFT_X')
if start < 0 or end < 0:
    raise SystemExit('markers block not found')

header_end = text.rfind('\n', 0, start)
text = text[:header_end + 1] + MARKERS + '\n\n' + text[end:]

text = text.replace(
    '--[[ Модуль: блокировка серверного SP-меню (TextDraw). ]]',
    '--[[ Module: block server SP menu TextDraws. ]]',
    1,
)

text = text.replace(
    "if plain:find('\\xEA\\xEC/\\xF7', 1, true) then return true end",
    "if plain:find(cp1251(0xEA, 0xEC, 0x2F, 0xF7), 1, true) then return true end",
    1,
)
text = text.replace(
    "if plain:find('\\xF2\\xEE\\xEF\\xEB\\xE8\\xE2\\xEE', 1, true) then return true end",
    "if plain:find(cp1251(0xF2, 0xEE, 0xEF, 0xEB, 0xE8, 0xE2, 0xEE), 1, true) then return true end",
    1,
)

PATH.write_text(text, encoding='utf-8', newline='\n')
print('patched', PATH.name)
