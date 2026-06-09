# Admin Report Desk Changelog

## 1.0 BETA (1.0.0)

**Первая публичная версия Report Desk для MoonLoader (AdminDesk.luac).**

### Установка

- Положи `AdminDesk.luac` в `moonloader` — ядро, библиотеки и превью скачаются автоматически.
- Команды: `/reps`, `/deskupdate`, `/deskrepair`.
- Autoupdate: manifest v3 + SHA256, атомарная установка, overlay прогресса на русском.

### /reps — репорты и автоответы

- Окно репортов v3, ingest чата, автоответы (time/GG/tech), profanity filter.
- Сценарии, cmd_binds, debounce autosave (~4 сек после изменений).
- `/guns` — Deagle (100), M4 (500), MP5 (500).

### /sp — spectate

- Кастомное SP-меню, vehicle/keys HUD, auto `/st`, блок серверного SA-Menu.
- Дефолтные позиции HUD как в dev-раскладке.

### Checker

- HUD админов/лидеров, sync `/adms` + `/leaders`, уведомления join/quit.
- Spawn-catalog sync без спама при reload.

### GodMode / cheats

- GodMode 1:1 как AdminTools (`setCharProofs`, `onSetPlayerHealth`, auto `/hp`).
- Airbreak, wallhack HUD, каталог скинов/транспорта с prewarm превью.

### Стабильность (важно для админов)

- Reload/autoupdate: снятие `onReceiveRpc`, `imgui.OnFrame`, D3D handlers при unload.
- Autosave/config: `saveConfig` в `pcall`, защита от non-string в сообщениях threads.
- SAMP-хуки: изоляция ошибок в цепочке (`deskCallHookPrev`), spectate TextDraw в `pcall`.
- `deskUninstall`: guards на `sampev` / `deskSpectateStats`.

### Совместимость MoonLoader 0.26+

- LuaJIT bytecode с `-bg` (debug info).
- `require 'lib.sampfuncs'` после загрузки SAMP.
- Fallback `AdminDesk.lua` (plaintext) в релизе, если luac не грузится.
