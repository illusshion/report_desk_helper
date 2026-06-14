# Admin Report Desk Changelog

## 1 Beta.1

**Публичный Beta-релиз Admin Report Desk.**

- Установка: положить `AdminDesk.luac` в moonloader — ядро, библиотеки и превью скачиваются автоматически.
- Команды `/adesk`, `/deskupdate`, `/deskrepair`; autoupdate по SHA256 (manifest v3).
- mimgui: patched `lib/mimgui` с `deskPassesGameKey` (F8/F12/PrtSc в игре).
- Spectate: stats split (ctx + pending), SP menu td_block CP1251, HUD input fix.
- Intent: номер телефона через `/id` (не `/number`); online players SSOT.
- Bootstrap: `pcall` вокруг загрузки ядра — ошибка core не роняет весь скрипт.

## 1 Beta

**Первый публичный релиз Admin Report Desk.**

- Установка: положить `AdminDesk.luac` в moonloader — скрипт сам скачает ядро, библиотеки и превью.
- Команда `/adesk` (алиас `/reportdesk`), `/deskupdate`, `/deskrepair`.
- Автообновление по SHA256, защита от падения при ошибке ядра, bundle из 4 chunk-групп (лимит 200 local).
- Первый запуск и обновления — дружелюбные сообщения в чат, минимальный прогресс-бар.

## 1.1.1

**Hotfix: загрузка AdminDeskCore на MoonLoader (лимит 200 local variables).**

- Bundle core разбит на core_a / core_b / core_c (как dev `report_desk_app.lua`).
- Исправлен порядок `env_export` (до admin_punish).

## 1.1.0

**Автовыдача наказаний из /a + обновления intent/autoreply.**

### Автовыдача (вкладка «Наказания»)

- Парсинг команд из admin chat: kick, jail, mute, ban, warn, skick, /tr, off*, un*.
- HUD-плашка внизу экрана: действие, игрок, команда с подписью `/ by Фамилия`.
- Подтверждение Delete / отмена End (настраиваемые бинды).
- Сверка ника на ID перед выдачей; отмена при выходе игрока или таймауте 15 с.

### Прочее

- Intent-система автоответов, mask ID, обновления checker/cheats/sp.
- Удалены dev-команды `/aptest`.

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
