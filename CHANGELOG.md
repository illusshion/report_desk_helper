# Admin Report Desk Changelog

## 1 Beta.1.8

**Стабильный релиз: spectate bundle, обновления, Edge UI.**

- Релизный bundle: все spectate-модули в preload (`sp_state`, `sp_hooks`, `sp_spectate_health`).
- Autoupdate: единая политика `startupSync` — core/updater блокирующе, assets в фоне в игре.
- Bootstrap упрощён: без reload-loop, launcher через `.pending` + reload, repair через `/deskrepair`.
- Edge UI, журнал наказаний без крашей при массовых `/kick`/`/mute` во время `/sp`.
- Release verify: SHA256 + обязательные preload в CI.

## 1 Beta.1.7

**Edge UI redesign + стабильность наказаний и spectate.**

- Новый интерфейс `/adesk`: боковая rail-навигация, иконки вкладок, логотип Advance (assets `res/report_desk_ui`).
- Журнал наказаний: запись вынесена из хука чата в главный цикл — фикс крашей при массовых `/kick` / `/mute` во время `/sp`.
- Справка: полный журнал наказаний по датам, поиск по нику, улучшенная вёрстка таблиц.
- Autoupdate: assets zip теперь включает UI-иконки (обновление превью скинов/ТС + edge UI).

## 1 Beta.1.6

**Spectate anticheat (/sp) + вкладка «Античит» в /adesk.**

- Трассеры выстрелов, звук попадания, 3D-текст точности, предупреждение wallshot.
- Линия направления взгляда цели (aim sync + fallback по heading).
- Rapid fire warning (Deagle / M4), детект сбивa анимации аптечки.
- Настройки в `/adesk` → «Античит»; уведомления в чат в CP1251 (без иероглифов).

## 1 Beta.1.5

**Hotfix: лаги при обновлении + GM на транспорте.**

- In-game restart: скачивание обновления в фоне, скрипт сразу стартует с локальной версии; после загрузки — авто-перезагрузка.
- mimgui: один набор MoonLoader-хендлеров на всю сессию (больше не дублируются при F4).
- Сброс imgui/renderer при выгрузке скрипта; отложенная распаковка assets (+4 с после старта).
- Обновление mimgui/runtime теперь тоже требует чистой перезагрузки скрипта.
- GM на машине: `setCarProofs` каждый кадр (как AdminTools), хук `onSetVehicleHealth`, восстановление HP < 950.

## 1 Beta.1.4

**Hotfix: checker `/adms` при входе на сервер (релизный путь).**

- При `checker_auto_sync` всегда гоняем `/adms` + `/leaders` на сессию, даже если каталог уже в storage.
- Сброс spawn-sync при реконнекте и позднем старте bootstrap (не пропускаем синк из-за старого `spawnedAt`).
- Убран обход «каталог не пустой → не шлём `/adms`».

## 1 Beta.1.3

**Hotfix: сценарии «собесы» / анонсы /news.**

- Убран устаревший fallback-сценарий «Собеседование» с ответом «Набор фракций: /help или F1» из ядра.
- Миграция pack v3: удаляет старый «Собеседование» из user config, подтягивает «Анонсы /news».
- Intent `faq.gameplay.join_news`: stem + триггер «собесы»; сужены патчи `faq.gameplay.join` (убран широкий `join`, «посмотреть+набор»).
- Autoupdate: `report_desk_intents.lua`, extensions и default user pack теперь обновляются по SHA256 вместе с core.

## 1 Beta.1.2

**Hotfix: FPS при открытом окне /adesk (релизный путь).**

- Main loop: убран `wait(16)` на каждом кадре при открытом окне (теперь ~33 ms на вкладке «Репорты», 8 ms только на «Скины»/«ТС»).
- Текстуры каталога: один `deskCatalogTexTick` через `imgui.OnFrame` (убраны дубли из main loop и drawSkinsTab).
- Prewarm скинов: только при первом входе во вкладку «Скины» (24 превью, budget 6/кадр), не сразу после скачивания assets.
- Fallback poll чата при открытом окне: 40 строк вместо 100.

## 1 Beta.1.1

**Hotfix: принудительная переустановка runtime/mimgui/iconv при чужих или устаревших lib.**

- Autoupdate: проверка полного набора `lib/samp/*`, SHA256 `report_desk_runtime_libs.zip` и patched `mimgui` (`deskPassesGameKey`), не только «файл существует».
- Исправлено: админы с vanilla mimgui / чужим SAMP.Lua / старым iconv больше не остаются на несовместимых библиотеках — краши в рандомное время.
- `/deskupdate` и `/deskrepair` показывают отдельно статус runtime libs и patched mimgui.

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
- GM на транспорте: `setCarProofs` каждый кадр, хук `onSetVehicleHealth`, восстановление HP < 950.
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
