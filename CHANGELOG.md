# Admin Report Desk Changelog

## 1.0.2 (dev stable)

**Fix: AdminDesk.luac не стартовал (devEntryPresent)**

- Убрана ложная проверка `lib/report_desk_app.lua` — файл есть у всех после autoupdate, luac сразу выходил из `main()`.

**Fix: сохранение настроек и позиций HUD**

- `saveConfig` больше не отменяется при ошибке user-config (сценарии).
- `report_colors` корректно восстанавливаются при загрузке.
- Debounce-flush ~4 сек после изменений (не ждать 2.5 мин autosave).
- HUD cheats/checker: сохранение только при реальном сдвиге + flush после drag.
- Закрытие /reps сбрасывает несохранённый редактор cmd_binds.

**Команда /guns**

- Выдаёт Deagle (100), M4 (500), MP5 (500) — как в AdminTools, без проверки admin_lvl.

**Fix: GodMode — 1:1 как AdminTools**

- `setCharProofs` каждый кадр.
- `onSetPlayerHealth`: первый пакет пропускаем, дальше блок HP < 5.
- Auto `/hp <id> 100` при локальном HP < 80 (раз в 10 сек).

**Первая загрузка скинов (новый админ)**

- Assets zip качается **параллельно** с core/libs (не после).
- Убрана пауза 2 сек + ожидание spawn перед download.
- После распаковки — **фоновый prewarm** 48 превью (IO сразу, GPU в OnFrame).
- Prewarm: 16 текстур/кадр пока админ в игре (до открытия /reps).
- Распаковка zip быстрее (реже yield); PNG optimize при сборке (ImageMagick).

**Оптимизация каталога (скролл)**

- Убран двойной GPU-tick; `deskTex.trim` для скинов; IO burst 3; zero-copy decode.
- Каталог: `lfs.dir` + обязательный `skins_index.lua` в assets zip.

## 1.0.1 (hotfix)

**Fix: GTA не запускается с AdminDesk.luac на чистой установке**

- **Fix (критично):** компиляция luac с `-bg` (debug info) — совместимость с MoonLoader 0.26+.
- **Fix (критично):** `require 'lib.sampfuncs'` перенесён в `main()` после загрузки SAMP/SAMPFUNCS.
- **Recovery:** `AdminDesk.lua` (plaintext) в релизе — если luac не грузится, используй его.

## 1.0 BETA (1.0.0)

**Первая стабильная публичная версия.**

- **Установка:** положи `AdminDesk.luac` в `moonloader` — остальное скачается автоматически.
- **Fix:** безопасная замена launcher — атомарная запись + SHA256.
- **Fix:** после autoupdate ядро грузится в той же сессии без reload.
- **UX:** тихие обновления, русский changelog в SAMP.
- **Checker / /sp / UI:** см. предыдущие записи 1.0.0.
