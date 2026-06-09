# Admin Report Desk Changelog

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
