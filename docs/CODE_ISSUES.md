# Report Desk — выявленные проблемы

Зафиксировано при аудите производительности и комментировании кода. **Исправления применены** (2026-06-06).

Приоритеты: **P0** — ломает функционал, **P1** — perf/edge cases, **P2** — code smell / техдолг.

---

## P0 — checker (2026-06-06)

### [P0] Spawn sync — race по таймеру вместо флага ✅
- **Файл:** `lib/report_desk_checker.lua`
- **Fix:** `spawnAdmsHandled` / `spawnLeadersHandled` в `onShowDialog`; `checkerWaitSpawnDialogFlow` ждёт флаги, не фиксированный sleep.

### [P0] Tick/thread — слепое закрытие любого диалога ✅
- **Fix:** удалены `checkerTryCloseActiveDialog`, `checkerSyncDialogsPending`, tick-watchdog; закрытие только через `onShowDialog` + guarded `deferBlockDialog`.

### [P0] Capture `/admins` — flush на первой нераспознанной строке ✅
- **Fix:** `missStreak` + `CHECKER_CAPTURE_MISS_FLUSH=3`; flush только после N промахов подряд.

---

## P1 — checker (2026-06-06)

### [P1] O(maxId) scan каждые 15с ✅
- **Fix:** `checkerEnsureNickIndex` — full scan только при `force` / `nickIndexNeedsFullScan` (spawn); periodic — prune + join через `checkerIndexOnePlayer`.

### [P1] Merge mode не удаляет уволенных ✅
- **Fix:** заголовок «Админы онлайн» и `/admins` chat sync → `replace` вместо `merge`.

### [P1] HUD heal attempts без cooldown после исчерпания ✅
- **Fix:** `healResetAt = now + 300` после 4 попыток; сброс счётчика по таймауту.

---

## P2 — открыто

### [P2] Тройное дублирование онлайн-данных
- `checkerOnline.*`, `onlineIndex`, `onlineNickIndex` — нужен рефакторинг «один источник истины» (отдельная задача).

### [P2] Непоследовательный SafeCall/pcall
- Постепенная замена голых `pcall` на `SafeCall` с метками.

---

## P0

_(прочие P0 spectate/vehicle — см. сессию 2026-06-06)_

---

## P1 — исправлено

### [P1] Orphan SP — возможный цикл локальной очистки ✅
- **Файл:** `lib/report_desk_spectate_stats.lua`
- **Fix:** флаг `orphanLocalCleared` — повторный orphan exit не вызывается, пока серверный SP не сбросится.

### [P1] checkerAddOnlineFromJoin — полный rebuild индекса на каждый join ✅
- **Файл:** `lib/report_desk_checker.lua`
- **Fix:** `checkerIndexOnePlayer()` — точечное обновление `onlineNickIndex` без full scan 0..maxId.

### [P1] poll ingest vs onServerMessage — race на admin reply ✅
- **Файлы:** `lib/report_desk_hooks.lua`, `lib/report_desk_ui.lua`
- **Fix:** hook проверяет `chatSeen` до ingest и помечает строку seen после успеха; poll опирается на тот же dedup.

### [P1] ADV refresh spectate — окно между toggle и [SP] ✅
- **Файл:** `lib/report_desk_spectate_stats.lua`
- **Fix:** `lastValidTargetAt` + `SPECTATE_ADV_REFRESH_GRACE_SEC` (8s) — orphan не срабатывает сразу после refresh.

---

## P2 — исправлено

### [P2] Дублирование `markTypingActive` / `sendChat` в buildSpUiDeps ✅
- **Fix:** удалены дубликаты, оставлено одно определение через `deps.markAnsTypingActive`.

### [P2] pollSpAns / pollChatKey — dead code ✅
- **Fix:** удалены `M.pollSpAns`, `M.pollAnsKey`, `M.pollChatKey`, `M.pollAltKey` (ввод ans через `onWindowMessage`).

### [P2] `checkerState.lastRescan` — мёртвое поле ✅
- **Fix:** поле удалено из `ensureCheckerState`.

### [P2] Два пути targetId ✅
- **Fix:** `getTargetId()` — session → pendingSp → state только при активном SP; `onSessionEnd` проверяет session напрямую.

### [P2] Vehicle HUD — жёсткие координаты TD ✅
- **Fix:** опциональные `spectate_vehicle_td_x_min/max/y_min` в settings (defaults без изменения поведения на ADV).

### [P2] Theme/layout константы без связи с settings migration ✅
- **Fix:** комментарий в `main()` и `config/admin_report_desk.default.lua` — при смене defaults bump `*_layout_v3`.

### [P2] Autoupdate `parseVersion` — beta.N лимит ✅
- **Fix:** beta offset ограничен 0..9999.

---

## Уже смягчено (perf, не баг)

Следующие пункты были addressed в отдельном коммите perf-оптимизации — оставлены для истории:

- Дублирующий poll ingest каждые 60ms при активном hook → замедлен fallback poll.
- Checker double rebuild 5s + 15s → только 15s.
- Spawn sync `/admins` убран из auto chain.
- HUD-heal rebuild каждые 2s → backoff 30s, max 4 tries.

---

_Последнее обновление: checker hardening (2026-06-06)._
