# Admin Report Desk Changelog

## 1.0 BETA hotfix (1.0.2)

**Fix: GTA не запускается после обновления**

- **Fix (критично):** битый `AdminDesk.luac.pending` больше не затирает рабочий launcher при старте.
- **Fix:** проверка bytecode перед применением/записью launcher pending.
- **Fix:** launcher pending применяется только после успешной установки, не в начале `main()`.
- **Recovery:** если luac не грузится — используй `AdminDesk.lua` (plaintext bootstrap).

## 1.0 BETA (1.0.1)

**Первая более менее рабочая версия**

- **Fix:** HUD загрузки обновления корректно скрывается после установки (`report_desk_update_overlay.lua` в релизе + `hideUpdateOverlay`).
- **Fix:** перетаскивание HUD клавиатуры в `/sp` как у чекера (imgui drag + сохранение позиции).
- **Fix:** цвета ников в bubble-чате (clist / live color).
- **Checker:** HUD админов/лидеров/друзей, clist-цвета фракций.
- **/sp:** меню, статистика, HUD клавиатуры и ТС.
- **UX:** тихие обновления, прогресс в overlay снизу экрана.

## 1.0.0 (Beta 1)

**Первая стабильная версия хелпера.**

- **UX:** тихие обновления — прогресс в overlay, одно сообщение в чат из changelog.
- **UX:** русский текст changelog в SAMP (CP1251 + `changelog_cp1251` в manifest).
- **Fix (критично):** после autoupdate ядро грузится в той же сессии без reload.
- **Fix (критично):** `AdminDesk.luac.pending` не применяется с reload во время работы — только на диск, новый launcher при следующем запуске игры.
- **Fix (критично):** не применять launcher pending mid-session — убран краш `ensureDirFor` / Script terminated.
- **Checker:** clist-цвета фракций, HUD руководства/админов/друзей, sync `/leaders`.
- **UI:** вкладка ТС, атомарное сохранение config, runtime-зависимости в manifest.
