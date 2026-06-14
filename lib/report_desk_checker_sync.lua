--[[ Модуль: checker /adms + /leaders sync (late chunk, after checker.lua). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

function checkerIsTableDialogStyle(style)
    style = tonumber(style) or -1
    return style == 2 or style == 4 or style == 5
end

local SYNC_SESSION_KEY = '__desk_checkerSyncSession' -- keep in sync with CHECKER_SYNC_SESSION_KEY in checker.lua
local CHECKER_SYNC_RESTORE_MAX_SEC = 90.0

local function checkerGetServerKey()
    if type(sampGetCurrentServerAddress) == 'function' then
        return sampGetCurrentServerAddress() or ''
    end
    if type(sampGetServerSettingsPtr) == 'function' then
        local ptr = sampGetServerSettingsPtr()
        if ptr and ptr ~= 0 then return tostring(ptr) end
    end
    return ''
end

local function checkerAdmsFlowIsOutbound()
    return checkerState.admsFlow == 'outbound'
end

local function checkerAdmsFlowIsActive(now)
    now = now or os.clock()
    return checkerState.admsFlow ~= nil and now < (checkerState.admsFlowUntil or 0)
end

local function checkerSyncServerKeyMismatch()
    local key = checkerState.syncServerKey
    if not key or key == '' then return false end
    return checkerGetServerKey() ~= key
end

-- Global in late chunk: checker.lua defines callers before this file loads (Lua forward-ref).
function ensureSyncSession()
    if type(checkerState.syncSession) ~= 'table' then
        checkerState.syncSession = {}
    end
    local s = checkerState.syncSession
    if s.admsUntil == nil then s.admsUntil = 0 end
    if s.leadersUntil == nil then s.leadersUntil = 0 end
    if s.spawnAdmsRetries == nil then s.spawnAdmsRetries = 0 end
    if s.lastAdmsResync == nil then s.lastAdmsResync = os.clock() end
    return s
end

local function checkerMarkSyncAdmsSession(untilAt)
    local s = ensureSyncSession()
    s.admsUntil = untilAt
    checkerPersistSyncSession()
end

function checkerBeginAdmsFlow(untilAt)
    checkerState.admsFlow = 'outbound'
    checkerState.admsFlowUntil = untilAt
    checkerState.syncServerKey = checkerGetServerKey()
    checkerMarkSyncAdmsSession(untilAt)
end

function checkerClearAdmsFlow()
    checkerState.admsFlow = nil
    checkerState.admsFlowUntil = 0
    checkerState.syncServerKey = ''
    checkerClearSyncAdms()
end

-- После /reload os.clock() сбрасывается — не восстанавливать «вечный» sync из _G.
function checkerSanitizeSyncSession()
    local s = ensureSyncSession()
    local now = os.clock()
    local function clampUntil(field)
        local v = tonumber(s[field]) or 0
        if v > now and (v - now) > CHECKER_SYNC_RESTORE_MAX_SEC then
            s[field] = 0
        end
    end
    clampUntil('admsUntil')
    clampUntil('leadersUntil')
    if (tonumber(s.admsUntil) or 0) <= now then
        if (checkerState.admsFlowUntil or 0) <= now
                or (checkerState.admsFlowUntil or 0) - now > CHECKER_SYNC_RESTORE_MAX_SEC then
            checkerState.admsFlow = nil
            checkerState.admsFlowUntil = 0
        end
    end
    if (tonumber(s.leadersUntil) or 0) <= now then
        if (checkerState.leadersFlowUntil or 0) <= now
                or (checkerState.leadersFlowUntil or 0) - now > CHECKER_SYNC_RESTORE_MAX_SEC then
            checkerState.leadersFlowUntil = 0
        end
    end
end

-- Checker (admin HUD/catalog).
function checkerPersistSyncSession()
    local s = ensureSyncSession()
    rawset(_G, SYNC_SESSION_KEY, {
        admsUntil = s.admsUntil,
        leadersUntil = s.leadersUntil,
        spawnAdmsRetries = s.spawnAdmsRetries,
    })
end

-- Checker (admin HUD/catalog).
function checkerRestoreSyncSession()
    local g = rawget(_G, SYNC_SESSION_KEY)
    if type(g) ~= 'table' then return end
    local s = ensureSyncSession()
    local now = os.clock()

    local function restoreUntil(field, applyFn)
        local untilAt = tonumber(g[field])
        if not untilAt or untilAt <= now then return end
        if untilAt - now > CHECKER_SYNC_RESTORE_MAX_SEC then return end
        s[field] = untilAt
        if type(applyFn) == 'function' then applyFn(untilAt) end
    end

    restoreUntil('admsUntil', function(untilAt)
        checkerState.admsFlow = 'outbound'
        checkerState.admsFlowUntil = untilAt
    end)
    restoreUntil('leadersUntil', function(untilAt)
        checkerState.leadersFlowUntil = untilAt
    end)
    s.spawnAdmsRetries = tonumber(g.spawnAdmsRetries) or s.spawnAdmsRetries
    checkerSanitizeSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerSyncAdmsActive(now)
    now = now or os.clock()
    local s = ensureSyncSession()
    return now < (s.admsUntil or 0) or checkerAdmsFlowIsActive(now)
end

-- Checker (admin HUD/catalog).
function checkerSyncLeadersActive(now)
    now = now or os.clock()
    local s = ensureSyncSession()
    return now < (s.leadersUntil or 0) or (checkerState.leadersFlowUntil or 0) > now
end

-- Checker (admin HUD/catalog).
function checkerMarkSyncAdms(untilAt)
    checkerMarkSyncAdmsSession(untilAt)
end

-- Checker (admin HUD/catalog).
function checkerMarkSyncLeaders(untilAt)
    local s = ensureSyncSession()
    s.leadersUntil = untilAt
    checkerState.leadersFlowUntil = untilAt
    checkerPersistSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerClearSyncAdms()
    local s = ensureSyncSession()
    s.admsUntil = 0
    checkerPersistSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerClearSyncLeaders()
    local s = ensureSyncSession()
    s.leadersUntil = 0
    checkerState.leadersFlowUntil = 0
    checkerState.leadersSyncOutbound = false
    if not checkerAdmsFlowIsOutbound() then
        checkerState.syncServerKey = ''
    end
    checkerPersistSyncSession()
end

-- Checker (admin HUD/catalog).
function checkerClearPendingSyncDialogs()
    checkerClearAdmsFlow()
    checkerClearSyncLeaders()
end

-- Checker (admin HUD/catalog).
function checkerScheduleSpawnAdmsRetry()
    local s = ensureSyncSession()
    if #checkerCatalog.admins > 0 then
        if checkerState.spawnLeadersHandled then
            checkerState.spawnCatalogSyncDone = true
        else
            checkerState.spawnLeadersDueAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        end
        return
    end
    if s.spawnAdmsRetries >= CHECKER_SPAWN_ADMS_MAX_RETRIES then
        if #checkerCatalog.admins == 0 then
            print('[Report Desk] checker: /adms sync failed — catalog empty, retrying automatically')
        else
            print('[Report Desk] checker: /adms sync failed after retries — using persisted catalog')
        end
        return
    end
    s.spawnAdmsRetries = s.spawnAdmsRetries + 1
    checkerState.spawnCatalogSyncDone = false
    checkerState.spawnAdmsHandled = false
    checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC * s.spawnAdmsRetries
    checkerPersistSyncSession()
    checkerLog(string.format('spawn /adms retry %d/%d', s.spawnAdmsRetries, CHECKER_SPAWN_ADMS_MAX_RETRIES))
end

-- Закрыть sync-диалог сразу после parse в onShowDialog. Без sampSendDialogResponse — иначе краш.
function checkerCloseSyncDialog(dialogId, button1, button2)
    dialogId = tonumber(dialogId)
    if not dialogId then return end
    local btn = checkerResolveCloseButton(button1, button2)
    if type(sampCloseCurrentDialogWithButton) == 'function' then
        pcall(sampCloseCurrentDialogWithButton, btn)
    end
end

local function checkerCloseSyncDialogRetry(dialogId, button1, button2)
    checkerCloseSyncDialog(dialogId, button1, button2)
    if not lua_thread or not lua_thread.create then return end
    local closeId, b1, b2 = dialogId, button1, button2
    lua_thread.create(function()
        wait(120)
        if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then
            checkerCloseSyncDialog(closeId, b1, b2)
        end
    end)
end

-- Checker (admin HUD/catalog).
function checkerClearSyncFlowFlags()
    checkerState.leadersFlowUntil = 0
end

-- На reload сбрасываем флаги sync; не закрываем чужой диалог вслепую (как /st watchdog).
function checkerDismissStaleSyncDialog()
    if not checkerAdmsFlowIsOutbound() and not checkerState.leadersSyncOutbound then
        checkerClearPendingSyncDialogs()
        return
    end
    checkerClearPendingSyncDialogs()
    checkerClearAdmsFlow()
    checkerClearSyncLeaders()
end

-- Закрытие sync-диалога перед unload/reload (checkerState при reload сбрасывается).
function checkerDismissOpenSyncDialogOnUnload()
    checkerDismissStaleSyncDialog()
end

-- Игнорировать echo /admins в чат (диалог — единственный источник при автосинхе).
function checkerIsAdmsChatMuted(now)
    now = now or os.clock()
    if checkerAdmsFlowIsActive(now) then return true end
    if now < (checkerState.admsChatMuteUntil or 0) then return true end
    return false
end

-- /admins в чат: только актуализировать уровень админа, который уже есть в каталоге.
-- Запасной путь без API: secondary chat echo; /adms dialog is primary catalog source.
function checkerRefreshAdminLevelFromChat(plain)
    if checkerState.admsDialogSyncedAt
        and checkerState.admsDialogSyncedAt > 0
        and (os.clock() - checkerState.admsDialogSyncedAt) < CHECKER_ADMS_DIALOG_CHAT_GUARD_SEC then
        return false
    end
    if Parser.isAdminsListNoise(plain) then return false end
    local nick, level = Parser.parseAdminLine(plain)
    if nick and not level then
        local chief = checkerResolveChief(nick)
        level = chief and chief.level or nil
    end
    if not nick or not level then return false end
    ensureCheckerCatalog()
    local ex = Catalog.getAdmin(nick)
    if not ex then return false end
    level = checkerEffectiveAdminLevel(nick, level)
    if not checkerIsValidAdminLevel(level) then return false end
    local old = math.floor(tonumber(ex.level) or 0)
    if old == level then return false end
    if not checkerShouldApplyAdminLevelUpdate(old, level) then return false end
    ex.level = level
    checkerSortCatalogAdmins(checkerCatalog.admins)
    checkerMarkCatalogDirty()
    checkerScheduleRebuild()
    if type(deskTryUpdateLocalAdminLevelFromNick) == 'function' then
        SafeCall('deskTryUpdateLocalAdminLevelFromNick', deskTryUpdateLocalAdminLevelFromNick, nick, level, 'chat')
    end
    return true
end

-- Checker (admin HUD/catalog).
-- Запасной путь без API: /adms and /leaders data only in dialog text.
function checkerOnShowDialog(dialogId, style, title, button1, button2, text)
    local titleMatch = checkerIsAdminsDialog(title)
    local isAdminsDlg = titleMatch
        or (checkerAdmsFlowIsOutbound() and checkerDialogLooksLikeAdmins(text, style))
    local leadersTitleMatch = checkerIsLeadersDialog(title)
    local isLeadersDlg = leadersTitleMatch
        or (checkerState.leadersSyncOutbound and checkerDialogLooksLikeLeaders(text, style))

    if isAdminsDlg and checkerAdmsFlowIsOutbound() then
        if checkerSyncServerKeyMismatch() then return false end
        local list = checkerParseAdminsDialog(text, style)
        if #list > 0 then
            SafeCall('checkerApplyAdminsDialogSync', checkerApplyAdminsDialogSync, list)
            if checkerState.spawnCatalogSyncRunning then
                checkerState.spawnAdmsHandled = true
                ensureSyncSession().spawnAdmsRetries = 0
                checkerPersistSyncSession()
            end
        else
            checkerLogAdmsParseFailure(title, style, text)
            if checkerState.spawnCatalogSyncRunning then
                checkerState.spawnAdmsHandled = false
                checkerScheduleSpawnAdmsRetry()
            end
        end
        checkerClearAdmsFlow()
        checkerCloseSyncDialogRetry(dialogId, button1, button2)
        return true
    end

    if isLeadersDlg then
        local applied = false
        if checkerIsTableDialogStyle(style) then
            local _, rows = checkerParseLeadersDialog(text, style)
            if #rows > 0 then
                applied = SafeCall('checkerApplyLeadersSync', checkerApplyLeadersSync, rows) == true
            elseif checkerState.leadersSyncOutbound then
                checkerLog('sync /leaders dialog parse failed (0 rows)')
            end
        end
        if checkerState.leadersSyncOutbound then
            if checkerSyncServerKeyMismatch() then return false end
            if checkerState.spawnCatalogSyncRunning and applied then
                checkerState.spawnLeadersHandled = true
            end
            checkerClearSyncLeaders()
            checkerCloseSyncDialogRetry(dialogId, button1, button2)
            return true
        end
        return false
    end

    return false
end

-- Checker (admin HUD/catalog).
function checkerIsSyncBlocked()
    if checkerIsSuspended() then return true end
    if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then return true end
    if type(showWindow) == 'table' and showWindow[0] then return true end
    return false
end

-- Spawn catalog sync: не ждём произвольный диалог игрока — только pause и окно /adesk.
function checkerIsSpawnCatalogSyncBlocked()
    if checkerIsSuspended() then return true end
    if type(showWindow) == 'table' and showWindow[0] then return true end
    return false
end

-- Checker (admin HUD/catalog).
function checkerWaitSpawnDialogFlow(isAdmins, maxSec)
    maxSec = tonumber(maxSec) or CHECKER_SPAWN_DIALOG_WAIT_SEC
    local t0 = os.clock()
    while os.clock() - t0 < maxSec do
        if isAdmins then
            if checkerState.spawnAdmsHandled then return true end
        elseif checkerState.spawnLeadersHandled then
            return true
        end
        local now = os.clock()
        if isAdmins then
            if not checkerAdmsFlowIsActive(now) then
                return true
            end
        elseif (checkerState.leadersFlowUntil or 0) <= now then
            return true
        end
        wait(100)
    end
    return false
end

-- Checker (admin HUD/catalog).
function checkerTrySendSyncChat(cmd, forSpawn)
    if type(sendChat) ~= 'function' then return false end
    local now = os.clock()
    local last = tonumber(checkerState.lastSyncChatAt) or 0
    if now - last < CHECKER_SYNC_CHAT_MIN_INTERVAL then
        if forSpawn then
            local waitSec = CHECKER_SYNC_CHAT_MIN_INTERVAL - (now - last) + 0.25
            checkerState.spawnCatalogSyncAt = now + waitSec
        end
        checkerLog('sync chat rate-limited: ' .. tostring(cmd))
        return false
    end
    checkerState.lastSyncChatAt = now
    return SafeCall('sendChat', sendChat, cmd) == true
end

-- Checker (admin HUD/catalog).
function checkerRequestAdmsSync(forSpawn, forManual)
    if not checkerSampReady() then return false end
    if forSpawn then
        if checkerIsSpawnCatalogSyncBlocked() then return false end
    elseif forManual then
        if checkerIsManualSyncBlocked() then return false end
    elseif checkerIsSyncBlocked() then
        return false
    end
    local now = os.clock()
    local flowT = forSpawn and CHECKER_SPAWN_DIALOG_WAIT_SEC or CHECKER_ADMINS_FLOW_T
    checkerState.pendingAdminMode = 'replace'
    checkerBeginAdmsFlow(now + flowT)
    local ok = checkerTrySendSyncChat('/adms', forSpawn)
    if not ok then checkerClearAdmsFlow() end
    return ok
end

-- Checker (admin HUD/catalog).
function checkerIsManualSyncBlocked()
    if checkerIsSuspended() then return true end
    if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then return true end
    return false
end

-- Leaders-only sync: не блокируем из-за открытого /adesk (нужен каталог на вкладке Чекер).
function checkerIsLeadersOnlySyncBlocked()
    if checkerIsSuspended() then return true end
    if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then return true end
    return false
end

-- Checker (admin HUD/catalog).
function checkerRequestLeadersSync(forSpawn, forManual)
    if not checkerSampReady() then return false end
    if forSpawn then
        if checkerIsSpawnCatalogSyncBlocked() then return false end
    elseif forManual or #(checkerCatalog.admins or {}) > 0 then
        if checkerIsLeadersOnlySyncBlocked() then return false end
    elseif checkerIsSyncBlocked() then
        return false
    end
    local flowT = forSpawn and CHECKER_SPAWN_DIALOG_WAIT_SEC or CHECKER_LEADERS_FLOW_T
    local now = os.clock()
    checkerState.leadersSyncOutbound = true
    if checkerState.syncServerKey == '' then
        checkerState.syncServerKey = checkerGetServerKey()
    end
    checkerMarkSyncLeaders(now + flowT)
    local ok = checkerTrySendSyncChat('/leaders', forSpawn)
    if ok then
        checkerLog(forSpawn and 'spawn sync: sent /leaders' or 'sync chat: /leaders')
    else
        checkerState.leadersSyncOutbound = false
    end
    return ok
end

-- Checker (admin HUD/catalog).
function checkerDeferSyncAfterResume()
    pcall(onlinePlayersRescan, true)
    checkerScheduleRebuild()
end

-- Checker (admin HUD/catalog).
function checkerStartSpawnCatalogSyncThread()
    if checkerState.spawnCatalogSyncRunning then return end
    if not lua_thread or not lua_thread.create then
        checkerState.spawnCatalogSyncRunning = true
        if checkerRequestAdmsSync(true) then
            checkerState.spawnLeadersDueAt = os.clock() + CHECKER_SPAWN_SYNC_LEADERS_WAIT_MS / 1000
        else
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        end
        checkerState.spawnCatalogSyncRunning = false
        return
    end
    checkerState.spawnCatalogSyncRunning = true
    checkerState.spawnAdmsHandled = false
    checkerState.spawnLeadersHandled = false
    lua_thread.create(function()
        local function waitUntilReady(maxSec)
            maxSec = tonumber(maxSec) or 8.0
            local t0 = os.clock()
            while os.clock() - t0 < maxSec do
                if checkerSampReady() and not checkerIsSpawnCatalogSyncBlocked() then
                    return true
                end
                wait(200)
            end
            return checkerSampReady() and not checkerIsSpawnCatalogSyncBlocked()
        end

        if not waitUntilReady(8.0) then
            checkerState.spawnCatalogSyncRunning = false
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            return
        end

        if checkerRequestAdmsSync(true) then
            checkerWaitSpawnDialogFlow(true, CHECKER_SPAWN_DIALOG_WAIT_SEC)
            wait(CHECKER_SPAWN_SYNC_LEADERS_WAIT_MS)
        end

        if checkerSampReady() and not checkerIsSpawnCatalogSyncBlocked() then
            if checkerRequestLeadersSync(true) then
                checkerWaitSpawnDialogFlow(false, CHECKER_SPAWN_DIALOG_WAIT_SEC)
            end
        end

        local admsHandled = checkerState.spawnAdmsHandled
        local leadersHandled = checkerState.spawnLeadersHandled
        checkerState.spawnCatalogSyncRunning = false
        checkerClearAdmsFlow()
        checkerClearSyncFlowFlags()
        local admsOk = admsHandled or #checkerCatalog.admins > 0
        local leadersOk = leadersHandled
        if admsOk and leadersOk then
            checkerState.spawnAdmsHandled = true
            checkerState.spawnLeadersHandled = true
            checkerState.spawnCatalogSyncDone = true
            ensureSyncSession().spawnAdmsRetries = 0
            checkerPersistSyncSession()
            checkerLog('spawn catalog sync: /adms + /leaders ok')
        elseif not admsOk then
            checkerState.spawnAdmsHandled = false
            checkerState.spawnLeadersHandled = false
            checkerScheduleSpawnAdmsRetry()
            checkerLog('spawn catalog sync: /adms pending retry')
        else
            checkerState.spawnAdmsHandled = true
            checkerState.spawnLeadersHandled = false
            checkerState.spawnLeadersDueAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            checkerLog('spawn catalog sync: /leaders pending retry')
        end
    end)
end

-- Checker (admin HUD/catalog).
function checkerScheduleSpawnCatalogSync(delaySec)
    if settings.checker_auto_sync == false then return end
    if checkerState.spawnCatalogSyncDone then return end
    delaySec = tonumber(delaySec) or CHECKER_SPAWN_SYNC_DELAY
    checkerState.spawnCatalogSyncAt = os.clock() + delaySec
end

-- Возобновить spawn catalog sync после закрытия /adesk.
function checkerOnDeskWindowClosed()
    if settings.checker_auto_sync == false then return end
    if checkerState.spawnCatalogSyncDone then return end
    if checkerState.spawnCatalogSyncRunning then return end
    if checkerState.spawnAdmsHandled and checkerState.spawnLeadersHandled then return end
    local s = ensureSyncSession()
    if s.spawnAdmsRetries >= CHECKER_SPAWN_ADMS_MAX_RETRIES then
        s.spawnAdmsRetries = 0
        checkerPersistSyncSession()
    end
    checkerScheduleSpawnCatalogSync(1.5)
end

-- Checker (admin HUD/catalog).
function checkerTrySpawnCatalogSync()
    if not checkerState.initComplete then return end
    if settings.checker_auto_sync == false then return end
    if checkerState.spawnCatalogSyncDone then return end
    if checkerState.spawnCatalogSyncRunning then return end
    local leadersDue = tonumber(checkerState.spawnLeadersDueAt)
    if leadersDue and os.clock() >= leadersDue then
        checkerState.spawnLeadersDueAt = nil
        if checkerState.spawnLeadersHandled then
            checkerState.spawnCatalogSyncDone = true
            return
        end
        if not checkerSampReady() or checkerIsLeadersOnlySyncBlocked() then
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
            return
        end
        if checkerRequestLeadersSync(true) then
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_DIALOG_WAIT_SEC
        else
            checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        end
        return
    end
    local at = checkerState.spawnCatalogSyncAt
    if not at or os.clock() < at then return end
    if not checkerSampReady() or checkerIsSpawnCatalogSyncBlocked() then
        checkerState.spawnCatalogSyncAt = os.clock() + CHECKER_SPAWN_SYNC_RETRY_SEC
        return
    end
    checkerState.spawnCatalogSyncAt = nil
    if #(checkerCatalog.admins or {}) > 0 then
        checkerState.spawnAdmsHandled = true
        if checkerState.spawnLeadersHandled then
            checkerState.spawnCatalogSyncDone = true
            return
        end
        checkerState.spawnLeadersDueAt = os.clock()
        checkerTrySpawnCatalogSync()
        return
    end
    checkerStartSpawnCatalogSyncThread()
end

-- Checker (admin HUD/catalog).
function checkerManualSync()
    if not checkerIsSpawned() then
        if type(say) == 'function' then
            say('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE0\xF6\xE8\xFF \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xE0: \xE4\xEE\xE6\xE4\xE8\xF2\xE5\xF1\xFC \xF1\xEF\xE0\xE2\xED\xE0')
        end
        return
    end
    if checkerIsManualSyncBlocked() then
        if type(say) == 'function' then
            say('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE0\xF8\xE8\xFF \xED\xE5\xE4\xEE\xF1\xF2\xF3\xEF\xED\xE0: \xE7\xE0\xEA\xF0\xEE\xE9\xF2\xE5 \xE4\xE8\xE0\xEB\xEE\xE3')
        end
        return
    end
    if checkerState.spawnCatalogSyncRunning then
        if type(say) == 'function' then
            say('\xD1\xE8\xED\xF5\xF0\xEE\xED\xE8\xE7\xE0\xF6\xE8\xFF \xF3\xE6\xE5 \xE2\xFB\xEF\xEE\xEB\xED\xFF\xE5\xF2\xF1\xFF...')
        end
        return
    end
    checkerRequestAdmsSync(false, true)
    if type(lua_thread) == 'table' and type(lua_thread.create) == 'function' then
        lua_thread.create(function()
            wait(2500)
            if not checkerIsManualSyncBlocked() then
                checkerRequestLeadersSync(false, true)
            end
        end)
    else
        checkerRequestLeadersSync(false, true)
    end
    if type(say) == 'function' then
        say('\xC7\xE0\xEF\xF0\xEE\xF8\xE5\xED /adms \xE8 /leaders.')
    end
end

-- Checker (admin HUD/catalog).
function checkerAdminLevelLabel(level)
    level = math.floor(tonumber(level) or 0)
    if checkerIsChiefLevel(level) then
        return CHECKER_CHIEF_TAG[level] or ''
    end
    if checkerIsSpecialLevel(level) then
        return 'S' .. tostring(checkerSpecialLevelNum(level))
    end
    local titles = settings.checker_level_titles
    if type(titles) == 'table' then
        local custom = titles[level] or titles[tostring(level)]
        if custom and trim(tostring(custom)) ~= '' then
            return trim(tostring(custom))
        end
    end
    if level > 0 then
        return string.format('\xD3\xF0\xEE\xE2\xE5\xED\xFC %i', level)
    end
    return '\xC1\xE5\xE7 \xF3\xF0\xEE\xE2\xED\xFF'
end

-- Checker (admin HUD/catalog).
function checkerPlayJoinAlert()
    if settings.checker_notify_sound == false then return end
    if type(playDeskAlertSound) == 'function' then
        SafeCall('playDeskAlertSound', playDeskAlertSound)
    end
end

-- Checker (admin HUD/catalog).
function checkerOnSendCommand(command)
    local cmd = trim(command or ''):match('^/?(%S+)')
    if not cmd then return end
    local lc = cmd:lower()
    if lc == 'leaders' then
        if checkerState.leadersSyncOutbound then return end
        checkerClearSyncLeaders()
    elseif lc == 'adms' or lc == 'admins' then
        if checkerAdmsFlowIsOutbound() then return end
        checkerClearAdmsFlow()
    end
end

-- Dev RPC probe: активно ли окно ожидания /adms (lib/report_desk_hooks.lua).
function checkerIsAdmsSyncWindow()
    return checkerSyncAdmsActive(os.clock())
end

-- Checker (admin HUD/catalog).
function checkerMarkCatalogDirty()
    Catalog.rebuildIndex()
    bumpCatalogRev()
    CheckerCatalogStore.markDirty()
    checkerScheduleRebuild()
end

-- Checker (admin HUD/catalog).
function checkerBuildCatalogSnapshot()
    ensureCheckerCatalog()
    ensureCheckerSettings()
    local hiddenKeys = {}
    for key in pairs(settings.checker_leader_hidden or {}) do
        if key ~= '' then hiddenKeys[#hiddenKeys + 1] = key end
    end
    table.sort(hiddenKeys)
    local leaders = {}
    for _, e in ipairs(checkerCatalog.leaders or {}) do
        if type(e) == 'table' and trim(e.nick or '') ~= '' then
            leaders[#leaders + 1] = {
                nick = trim(e.nick),
                org = math.floor(tonumber(e.org) or 0),
                org_name = checkerNormalizeLeaderField(trim(e.org_name or '')),
                role = checkerNormalizeLeaderField(trim(e.role or '')),
                hidden = e.hidden == true and true or nil,
            }
        end
    end
    return {
        admins = checkerCatalog.admins,
        leaders = leaders,
        friends = checkerCatalog.friends,
        hidden_nicks = hiddenKeys,
    }
end

-- Checker (admin HUD/catalog).
function checkerApplyCatalogSnapshot(c)
    if type(c) ~= 'table' then return false end
    ensureCheckerCatalog()
    local changed = false
    if type(c.admins) == 'table' and #c.admins > 0 then
        local list = {}
        for _, raw in ipairs(c.admins) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                list[#list + 1] = {
                    nick = trim(raw.nick),
                    level = checkerEffectiveAdminLevel(trim(raw.nick), raw.level),
                }
            end
        end
        if #list > 0 then
            checkerCatalog.admins = list
            changed = true
        end
    end
    if type(c.hidden_nicks) == 'table' then
        for _, nick in ipairs(c.hidden_nicks) do
            if type(nick) == 'string' and trim(nick) ~= '' then
                checkerSetLeaderNickHidden(nick, true)
                changed = true
            end
        end
        for key, val in pairs(c.hidden_nicks) do
            if val == true and type(key) == 'string' and trim(key) ~= '' then
                checkerSetLeaderNickHidden(key, true)
                changed = true
            end
        end
    end
    if type(c.leaders) == 'table' and #c.leaders > 0 then
        local list = {}
        for _, raw in ipairs(c.leaders) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                local nick = trim(raw.nick)
                if raw.hidden == true then checkerSetLeaderNickHidden(nick, true) end
                local rawOrg = trim(raw.org_name or '')
                local rawRole = trim(raw.role or '')
                local org_name = checkerNormalizeLeaderField(rawOrg)
                local role = checkerNormalizeLeaderField(rawRole)
                if rawOrg ~= org_name or rawRole ~= role then
                    checkerMarkCatalogDirty()
                end
                list[#list + 1] = {
                    nick = nick,
                    org = math.floor(tonumber(raw.org) or 0),
                    org_name = org_name,
                    role = role,
                    hidden = checkerIsLeaderNickHidden(nick) and true or nil,
                }
                local e = list[#list]
                e.org = checkerResolveLeaderOrgId(e)
            end
        end
        if #list > 0 then
            checkerCatalog.leaders = list
            changed = true
        end
    end
    if type(c.friends) == 'table' and #c.friends > 0 then
        local list = {}
        for _, raw in ipairs(c.friends) do
            if type(raw) == 'table' and trim(raw.nick or '') ~= '' then
                list[#list + 1] = { nick = trim(raw.nick) }
            end
        end
        if #list > 0 then
            checkerCatalog.friends = list
            changed = true
        end
    end
    if changed then
        checkerState.leaderShowUi = {}
        checkerState.leaderGroupShowUi = {}
        Catalog.rebuildIndex()
        bumpCatalogRev()
    end
    if checkerEnsureChiefCatalog() then
        changed = true
    end
    if checkerEnsureTopAdminCatalog() then
        changed = true
    end
    checkerSanitizeAdminCatalog()
    return changed
end

-- Checker (admin HUD/catalog).
function checkerSaveCatalogStorage()
    return CheckerCatalogStore.save(checkerBuildCatalogSnapshot())
end

-- Checker (admin HUD/catalog).
function flushCheckerCatalogNow()
    if CheckerCatalogStore.isDirty() then
        checkerSaveCatalogStorage()
    end
end

-- Checker (admin HUD/catalog).
function checkerLoadCatalogStorage()
    local data = CheckerCatalogStore.load()
    if not data then return false end
    checkerApplyCatalogSnapshot(data)
    return true
end

-- Checker (admin HUD/catalog): одноразовый перенос из admin_report_desk_user.lua.
function checkerMigrateLegacyCatalog(legacyChecker)
    if CheckerCatalogStore.exists() then return false end
    if type(legacyChecker) ~= 'table' then return false end
    if not checkerApplyCatalogSnapshot(legacyChecker) then return false end
    if checkerSaveCatalogStorage() then
        print('[Report Desk] checker catalog: migrated to config/report_desk_checker_catalog.lua')
        return true
    end
    return false
end

-- Sort Admins Online (global: called from checker.lua above this file in late chunk).
function sortAdminsOnline(list)
    local executive, regular, special = checkerSplitAdminLists(list)
    local n = 0
    for _, e in ipairs(executive) do
        n = n + 1
        list[n] = e
    end
    for _, e in ipairs(regular) do
        n = n + 1
        list[n] = e
    end
    for _, e in ipairs(special) do
        n = n + 1
        list[n] = e
    end
    for i = n + 1, #list do
        list[i] = nil
    end
end
