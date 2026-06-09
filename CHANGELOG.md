# Admin Report Desk Changelog

## 1.0 BETA (1.0.0)

**Первая стабильная публичная версия.**

- **Установка:** положи `AdminDesk.luac` в `moonloader` — остальное скачается автоматически.
- **Recovery:** если luac не грузится — замени на `AdminDesk.lua` (plaintext bootstrap из релиза).
- **Fix (критично):** безопасная замена launcher — атомарная запись + SHA256, рабочий `AdminDesk.luac` не удаляется при сбое.
- **Fix (критично):** битый `AdminDesk.luac.pending` удаляется при старте, не ломает GTA.
- **Fix:** после autoupdate ядро грузится в той же сессии без reload.
- **UX:** тихие обновления — прогресс в overlay, одно сообщение в чат из changelog.
- **UX:** русский текст changelog в SAMP (CP1251 + `changelog_cp1251` в manifest).
- **Checker:** clist-цвета фракций, HUD руководства/админов/друзей.
- **/sp:** меню, статистика, HUD клавиатуры и ТС.
- **UI:** вкладка ТС, атомарное сохранение config, runtime-зависимости в manifest.
