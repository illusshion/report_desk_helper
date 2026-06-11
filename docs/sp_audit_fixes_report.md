# Отчёт: исправления системы `/sp` (Report Desk)

Краткий список того, что изменено, и какие симптомы это могло вызывать.

---

## P0 — Orphan exit без `/sp` на сервер

**Файл:** `lib/report_desk_spectate_stats.lua` — `tickSpectateHealth`

**Было:** при «orphan» (режим spectate включён, но цель не подтверждена > 3 сек) клиент выходил локально с `sendServer = false`.

**Стало:** `forceExitSpectate({ sendServer = true })` — на сервер уходит `/sp` (выход).

**Баг:** клиент думал, что вышел из spectate, сервер — что админ всё ещё следит. Возможны ghost-spectate, странное поведение команд, рассинхрон UI и серверного состояния.

---

## P1 — TextDraw hooks: постоянная нагрузка CPU

**Файл:** `lib/report_desk_spectate_session.lua` — `onShowTextDraw`, `onTextDrawSetString`

**Было:** на каждый TD серверного `/sp` (пересоздаются каждый tick) — полный парсинг позиции/текста без раннего выхода.

**Стало:**
- кеш `shouldSuppressServerSpMenu` / `vehicleHudPipelineActive` на 50 ms;
- ранний выход, если TD слева от колонки меню и текст не похож на SP;
- инвалидация кеша при смене session/awaiting.

**Баг:** микрофризы и просадка FPS в spectate, особенно при активном серверном SP-меню. Чем дольше spectate — тем заметнее.

**Hotfix:** ingest спидометра нельзя гейтить через `vehicleHudPipelineActiveCached()` — кеш пропускал TD. Ingest снова всегда через `handleVehicleTextDraw`; кеш только для suppress SP-menu.

---

## Hotfix — автовыдача: задержка ingest

**Файлы:** `lib/report_desk_admin_punish.lua`, `lib/report_desk_main.lua`

**Было:**
- poll смотрел только строку 0 чата, если hook «активен» — запрос `/a` терялся при новых сообщениях;
- фильтр по color отбрасывал валидные строки в hook;
- poll ждал `chatLogReady` и опрашивал раз в 80 ms;
- offline снимал pending мгновенно при одном `sampIsPlayerConnected=false`.

**Стало:**
- poll всегда сканирует 24 последние строки;
- color-check убран — достаточно `]: /` + parse;
- poll + tick каждый цикл main loop (16 ms в /sp);
- offline cancel только после 2 s grace.

**Баг:** overlay появлялся через секунды или не появлялся; confirm сбрасывался «игрок вышел» на flicker.

---

## P1 — Тройной `markPendingSpCommand` с кнопки «Следить»

**Файл:** `lib/report_desk_input.lua` — `sendGameCmd`

**Было:** `markPendingSpCommand` → `sendChat` → `onSendCommand` hook — до 3 вызовов на один `/sp`.

**Стало:** маршрут через `sendMenuOutbound(cmd)` с `skipSpHookLocal` (один mark).

**Баг:** сброс таймера pending `/sp`, лишние проверки hooks, ощущение «залипания» входа в spectate с кнопки Report Desk, race с auto `/st`.

---

## P1 — Microfreeze на стрелках Left/Right

**Файл:** `lib/report_desk_spectate_stats.lua` — `findAdjacentSpectateId`

**Было:** до 1001 синхронных вызовов `sampIsPlayerConnected` в WM-handler на каждое нажатие.

**Стало:** кеш отсортированного списка онлайн-ID (TTL 0.5 s, cap `getMaxPlayerId()`), O(n) один раз, затем поиск соседа по списку.

**Баг:** короткий freeze при переключении игрока стрелками на сервере с редкими ID / многими пустыми слотами.

---

## P1 — Блокировка `toggle(false)` на всю сессию

**Файл:** `lib/report_desk_spectate_stats.lua` — `shouldBlockSpectateOff`

**Было:** блок при любой активной session (`specSession.isActive()`).

**Стало:** блок только на handshake — `pendingSpId`, `awaitingSpectate`, окно 8 сек после исходящего `/sp`.

**Баг:** сервер не мог корректно вывести из spectate (кик, принудительный off) — клиент игнорировал RPC и держал локальный spectate. Застревание в режиме, конфликт с сервером.

---

## P1 — Auto `/sp` refresh: лишняя нагрузка и гонки

**Файлы:** `lib/report_desk_sp_refresh.lua`, `lib/report_desk_hooks.lua`, `lib/report_desk_spectate_stats.lua`

**Было:**
- refresh каждые 2 s при смене mobility/interior;
- sync-хуки вызывались для **всех** игроков;
- `isCharInAnyCar` на sync path;
- vehicle/passenger sync всегда вызывали `flushPending`.

**Стало:**
- cooldown 3 s;
- skip refresh если outbound queue не пуст (`hasOutboundPending`);
- sync-хуки только если `playerId == deskCache.spWatchTargetId`;
- убран native `isCharInAnyCar` из hot path;
- `flushPending` на vehicle sync только при наличии pending.

**Баг:** лишние `/sp` на сервер при движении цели → рывки камеры, повторный handshake, гонки с ручным `/sp` и auto `/st`, нагрузка на sync-хуках при большом онлайне.

---

## P1 — RPC menu handler на каждый RPC

**Файл:** `lib/report_desk_hooks.lua` — `installDeskSpMenuRpcBlock`

**Было:** early return без значения (`nil`) на non-menu RPC.

**Стало:** явный `return true` — handler не «глотает» RPC, быстрее уходит из цепочки.

**Баг:** лишний overhead на global RPC path (минор, но на busy сервере суммируется).

---

## Связка `spWatchTargetId`

**Файлы:** `lib/report_desk_spectate_session.lua`, `lib/report_desk_spectate_stats.lua`

При `beginSession` / `syncFromSession` / `endSession` обновляется `deskCache.spWatchTargetId` — быстрый фильтр в sync-хуках без лишних вызовов `getTargetId()`.

---

## Что сознательно не менялось

- Исходящий `/sp` по-прежнему **не блокируется** — сервер получает команду.
- Подавление серверного TD/SA-Menu UI (кастомное меню) — by design.
- Outbound queue 0.55 s и блок при открытом chat/dialog — без изменений (отдельная тема).

---

## Изменённые файлы

| Файл | Суть |
|------|------|
| `lib/report_desk_spectate_stats.lua` | orphan exit, block-off scope, arrow cache, watch target id |
| `lib/report_desk_spectate_session.lua` | TD perf cache, watch target id |
| `lib/report_desk_input.lua` | sendGameCmd → sendMenuOutbound |
| `lib/report_desk_hooks.lua` | sp refresh target filter, RPC early exit |
| `lib/report_desk_sp_refresh.lua` | cooldown, guards, меньше flush на sync |

Вспомогательный скрипт патча: `tools/apply_sp_audit_fixes.py`
