# Admin Report Desk Changelog

## 1.0.0 (Beta 1)

**Первая стабильная версия хелпера.**

- **UX:** тихие обновления — прогресс в overlay, одно сообщение в чат из changelog.
- **UX:** русский текст changelog в SAMP (CP1251 + `changelog_cp1251` в manifest).
- **Fix (критично):** после autoupdate ядро грузится в той же сессии без reload.
- **Fix (критично):** `AdminDesk.luac.pending` не применяется с reload во время работы — только на диск, новый launcher при следующем запуске игры.
- **Fix (критично):** не применять launcher pending mid-session — убран краш `ensureDirFor` / Script terminated.
- **Checker:** clist-цвета фракций, HUD руководства/админов/друзей, sync `/leaders`.
- **UI:** вкладка ТС, атомарное сохранение config, runtime-зависимости в manifest.

## 1.0.29

- **Fix (критично):** после autoupdate bootstrap больше не делает reload — сразу грузит ядро в той же сессии. Раньше reload убивал скрипт и F7 не работал.
