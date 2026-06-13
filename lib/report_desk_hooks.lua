--[[ РњРѕРґСѓР»СЊ: РїРµСЂРµС…РІР°С‚ SAMP-СЃРѕР±С‹С‚РёР№ (С‡Р°С‚, РґРёР°Р»РѕРіРё, RPC РјРµРЅСЋ /sp). ]]
-- REWRITTEN: hot-path server message ordering, verify-only hook health-check.

local spSessionMod -- spectate session module (lazy require)
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

local vehicleHudMod
local function vehicleHud()
    if not vehicleHudMod then
        vehicleHudMod = require 'report_desk_sp_vehicle_hud'
    end
    return vehicleHudMod
end

-- REWRITTEN: early exits before ingest; dedup fast-path skips checker/stats; single profanity key.
function deskOnServerMessage(color, text)
    if not text or text == '' then return end
    if type(adminPunishOnServerMessage) == 'function' then
        pcall(adminPunishOnServerMessage, color, text)
    end
    if type(tempLeadershipOnServerMessage) == 'function' then
        pcall(tempLeadershipOnServerMessage, color, text)
    end
    if type(chatSeen) ~= 'table' or type(chatSeen.lines) ~= 'table' then
        chatSeen = { lines = {}, order = {}, deferred = {}, consumed = {}, consumedOrder = {} }
        print('[Report Desk] server msg: chatSeen reinitialized')
    end

    local ingestKey = chatLineSeenKey(text)
    local alreadySeen = ingestKey ~= '' and chatSeen.lines[ingestKey] == true

    if not alreadySeen then
        if type(checkerOnServerMessage) == 'function' then
            pcall(checkerOnServerMessage, color, text)
        end
        if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onServerMessage) == 'function' then
            pcall(deskSpectateStats.onServerMessage, color, text)
        end
    end

    local plain = stripChatTimestamp(stripTags(text))
    if plain == '' then return end

    local profanityOn = type(settings) == 'table' and settings.profanity_filter_enabled ~= false

    -- Live ingest до chatLogReady (редкий race до seedSeenChatLines); poll по-прежнему gated.
    if not chatLogReady then
        if not alreadySeen then
            if tryIngestAdminReplyLine(plain) then
                if ingestKey ~= '' then markChatLineSeen(ingestKey) end
                return
            end
            if processChatLineIngest(plain, color, 'srv', true, text, { delay = 0 }) then
                if ingestKey ~= '' then markChatLineSeen(ingestKey) end
            end
        end
        return
    end

    if alreadySeen then
        if profanityOn and ingestKey ~= '' and not profanityIsLineSeen(ingestKey) then
            pcall(checkProfanityFromChatLine, plain, ingestKey)
        end
        -- Poll мог пометить echo seen до landing в тред (stale RECENT.out dedup).
        if type(looksLikeAdminReplyLine) == 'function' and looksLikeAdminReplyLine(plain) then
            pcall(tryIngestAdminReplyLine, plain)
        end
        return
    end

    if tryIngestAdminReplyLine(plain) then
        if ingestKey ~= '' then markChatLineSeen(ingestKey) end
        return
    end

    if processChatLineIngest(plain, color, 'srv', true, text, { delay = 0 }) then
        if ingestKey ~= '' then markChatLineSeen(ingestKey) end
        return
    end

    -- Хук не съел строку, но это похоже на репорт — ускорить reconcile poll (не ждать 2 с).
    if type(tryParseReport) == 'function' and tryParseReport(plain) and type(deskCache) == 'table' then
        deskCache.ingestReconcileAt = os.clock()
    end

    if profanityOn and ingestKey ~= '' then
        pcall(checkProfanityFromChatLine, plain, ingestKey)
    end
end

-- Hook onServerMessage СѓСЃС‚Р°РЅРѕРІР»РµРЅ Рё Р°РєС‚РёРІРµРЅ.
function deskIsServerMsgHookActive()
    return deskCache.serverMsgHandler ~= nil
        and sampev ~= nil
        and sampev.onServerMessage == deskCache.serverMsgHandler
end

-- РџРµСЂРµС…РІР°С‚ onShowDialog: /st stats Рё checker dialogs.
function installDeskSpectateDialogHook()
    if not sampev then return end
    if deskCache.specDialogHandler and sampev.onShowDialog == deskCache.specDialogHandler then
        return
    end
    local prev = sampev.onShowDialog
    if prev == deskCache.specDialogHandler then prev = deskCache.hookPrevShowDialog end
    deskCache.hookPrevShowDialog = prev
    deskCache.specDialogHandler = function(dialogId, style, title, button1, button2, text)
        local okSp, handled = false, false
        if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onShowDialog) == 'function' then
            okSp, handled = pcall(deskSpectateStats.onShowDialog, dialogId, style, title, button1, button2, text)
        end
        if okSp and handled then
            return false
        end
        if not okSp then
            print('[Report Desk] sp dialog: ' .. tostring(handled))
        end
        if type(exactTimeOnShowDialog) == 'function' then
            local okEt, hideEt = pcall(exactTimeOnShowDialog, dialogId, style, title, button1, button2, text)
            if okEt and hideEt then
                return false
            end
            if not okEt then
                print('[Report Desk] exact time dialog: ' .. tostring(hideEt))
            end
        end
        local checkerHandled = false
        local okChk, chkRes = pcall(checkerOnShowDialog, dialogId, style, title, button1, button2, text)
        if not okChk then
            print('[Report Desk] checker dialog error: ' .. tostring(chkRes))
        elseif chkRes == true then
            checkerHandled = true
        end
        if checkerHandled then return false end
        return deskCallHookPrev(deskCache.hookPrevShowDialog, dialogId, style, title, button1, button2, text)
    end
    sampev.onShowDialog = deskCache.specDialogHandler
end

-- РЈСЃС‚Р°РЅР°РІР»РёРІР°РµС‚ РїРµСЂРµС…РІР°С‚ onServerMessage.
function installDeskServerMessageHook()
    if not sampev then return end
    if deskCache.serverMsgHandler and sampev.onServerMessage == deskCache.serverMsgHandler then return end
    local prev = sampev.onServerMessage
    if prev == deskCache.serverMsgHandler then prev = nil end
    if deskCache.hookPrevServerMsg == nil then deskCache.hookPrevServerMsg = prev end
    deskCache.serverMsgHandler = function(color, text)
        local ok, err = pcall(deskOnServerMessage, color, text)
        if not ok then
            print('[Report Desk] server msg hook: ' .. tostring(err))
        end
        return deskCallHookPrev(prev, color, text)
    end
    sampev.onServerMessage = deskCache.serverMsgHandler
end

-- Desk hook/helper.
local function deskOnPlayerQuitBody(playerId, reason)
    playerId = tonumber(playerId)
    if not playerId then return end
    pcall(checkerOnPlayerQuit, playerId)
    if type(adminPunishOnPlayerQuit) == 'function' then
        pcall(adminPunishOnPlayerQuit, playerId)
    end
    if type(maskIdOnPlayerQuit) == 'function' then
        pcall(maskIdOnPlayerQuit, playerId)
    end
    pcall(function()
        if type(deskSpectateStats) == 'table' and type(deskSpectateStats.notifyTargetQuit) == 'function' then
            deskSpectateStats.notifyTargetQuit(playerId)
        end
    end)
    local quitNk = ''
    if type(threads) == 'table' then
        for _, t in pairs(threads) do
            if t and tonumber(t.id) == playerId then
                quitNk = nickKey(t.nick)
                t.offlineAt = os.time()
                t.stale = true
                t.lastId = t.id
            end
        end
    end
    if type(outbound) == 'table' and outbound.pending
            and tonumber(outbound.pending.id) == playerId then
        local pNk = outbound.pending.nickKey or ''
        if quitNk == '' or pNk == '' or pNk == quitNk then
            clearPendingOutbound()
        end
    end
    if type(sampClearPlayerColor) == 'function' then
        pcall(sampClearPlayerColor, playerId)
    end
    if type(markDirtyThreads) == 'function' then
        markDirtyThreads()
    end
end

function deskOnPlayerQuit(playerId, reason)
    local ok, err = pcall(deskOnPlayerQuitBody, playerId, reason)
    if not ok then
        print('[Report Desk] player quit: ' .. tostring(err))
    end
end

-- Godmode: РєР°Рє AdminTools вЂ” С‚РѕР»СЊРєРѕ onSetPlayerHealth.
function installDeskGodmodeHealthHook()
    if not sampev then return end
    if deskCache.gmHealthHandler and sampev.onSetPlayerHealth == deskCache.gmHealthHandler then
        return
    end
    local prev = sampev.onSetPlayerHealth
    if prev == deskCache.gmHealthHandler then prev = nil end
    if deskCache.hookPrevSetPlayerHealth == nil then deskCache.hookPrevSetPlayerHealth = prev end
    deskCache.gmHealthHandler = function(health)
        local block
        local okGm, errGm = pcall(function()
            block = cheatsOnSetPlayerHealth(health)
        end)
        if not okGm then
            print('[Report Desk] godmode hook: ' .. tostring(errGm))
        end
        if block == false then return false end
        return deskCallHookPrev(deskCache.hookPrevSetPlayerHealth, health)
    end
    sampev.onSetPlayerHealth = deskCache.gmHealthHandler
end

function deskGodmodeHooksActive()
    if not sampev then return false end
    return deskCache.gmHealthHandler and sampev.onSetPlayerHealth == deskCache.gmHealthHandler
end

-- Quit РёРіСЂРѕРєР° в†’ checker, spectate exit, thread offline.
function installDeskPlayerQuitHook()
    if not sampev then return end
    if deskCache.playerQuitHandler and sampev.onPlayerQuit == deskCache.playerQuitHandler then
        return
    end
    local prev = sampev.onPlayerQuit
    if prev == deskCache.playerQuitHandler then prev = nil end
    if deskCache.hookPrevPlayerQuit == nil then deskCache.hookPrevPlayerQuit = prev end
    deskCache.playerQuitHandler = function(playerId, reason)
        deskOnPlayerQuit(playerId, reason)
        return deskCallHookPrev(prev, playerId, reason)
    end
    sampev.onPlayerQuit = deskCache.playerQuitHandler
end

-- Desk hook/helper.
function deskOnPlayerJoin(playerId, color, isNpc, nickname)
    if type(sampStorePlayerColor) == 'function' then
        pcall(sampStorePlayerColor, playerId, color)
    end
    pcall(checkerOnPlayerJoin, playerId, nickname)
end

-- Join в†’ checker notify/catalog.
function installDeskPlayerJoinHook()
    if not sampev then return end
    if deskCache.playerJoinHandler and sampev.onPlayerJoin == deskCache.playerJoinHandler then
        return
    end
    local prev = sampev.onPlayerJoin
    if prev == deskCache.playerJoinHandler then prev = nil end
    if deskCache.hookPrevPlayerJoin == nil then deskCache.hookPrevPlayerJoin = prev end
    deskCache.playerJoinHandler = function(playerId, color, isNpc, nickname)
        pcall(deskOnPlayerJoin, playerId, color, isNpc, nickname)
        return deskCallHookPrev(prev, playerId, color, isNpc, nickname)
    end
    sampev.onPlayerJoin = deskCache.playerJoinHandler
end

-- StreamIn в†’ checker rebuild schedule.
function installDeskPlayerStreamInHook()
    if not sampev then return end
    if deskCache.playerStreamInHandler and sampev.onPlayerStreamIn == deskCache.playerStreamInHandler then
        return
    end
    local prev = sampev.onPlayerStreamIn
    if prev == deskCache.playerStreamInHandler then prev = nil end
    if deskCache.hookPrevPlayerStreamIn == nil then deskCache.hookPrevPlayerStreamIn = prev end
    deskCache.playerStreamInHandler = function(playerId, team, model, position, rotation, color, fightingStyle)
        if type(sampStorePlayerColor) == 'function' then
            pcall(sampStorePlayerColor, playerId, color)
        end
        pcall(checkerOnPlayerStreamIn, playerId)
        if deskSpectateStats and deskSpectateStats.onSpRefreshStreamIn then
            pcall(deskSpectateStats.onSpRefreshStreamIn, playerId)
        end
        return deskCallHookPrev(prev, playerId, team, model, position, rotation, color, fightingStyle)
    end
    sampev.onPlayerStreamIn = deskCache.playerStreamInHandler
end

-- SetPlayerColor RPC в†’ clist (TAB).
function installDeskPlayerColorHook()
    if not sampev then return end
    if deskCache.playerColorHandler and sampev.onSetPlayerColor == deskCache.playerColorHandler then
        return
    end
    local prev = sampev.onSetPlayerColor
    if prev == deskCache.playerColorHandler then prev = nil end
    if deskCache.hookPrevPlayerColor == nil then deskCache.hookPrevPlayerColor = prev end
    deskCache.playerColorHandler = function(playerId, color)
        if type(sampStorePlayerColor) == 'function' then
            pcall(sampStorePlayerColor, playerId, color)
        end
        return deskCallHookPrev(prev, playerId, color)
    end
    sampev.onSetPlayerColor = deskCache.playerColorHandler
end


-- Fast filter: sp refresh hooks only for current spectate target.
local function spRefreshWatchTargetId()
    if type(deskSpectateStats) == 'table' and deskSpectateStats.getTargetId then
        local ok, v = pcall(deskSpectateStats.getTargetId)
        if ok then
            local tid = tonumber(v)
            if tid and tid >= 0 then return tid end
        end
    end
    return -1
end

local function spRefreshTargetMatches(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    local tid = spRefreshWatchTargetId()
    return tid >= 0 and playerId == tid
end

local function spRefreshWatchActive()
    return spRefreshWatchTargetId() >= 0
end
-- /sp auto-refresh: RPC enter/exit/interior + sync + onSpectatePlayer/Vehicle.
function installDeskSpRefreshHooks()
    if not sampev then return end
    local enterOk = deskCache.spEnterHandler and sampev.onPlayerEnterVehicle == deskCache.spEnterHandler
    local exitOk = deskCache.spExitHandler and sampev.onPlayerExitVehicle == deskCache.spExitHandler
    local interiorOk = deskCache.spInteriorHandler and sampev.onSetInterior == deskCache.spInteriorHandler
    local vehicleOk = deskCache.spVehicleSyncHandler and sampev.onVehicleSync == deskCache.spVehicleSyncHandler
    local passengerOk = deskCache.spPassengerSyncHandler and sampev.onPassengerSync == deskCache.spPassengerSyncHandler
    local playerOk = deskCache.spPlayerSyncHandler and sampev.onPlayerSync == deskCache.spPlayerSyncHandler
    local vehParamsOk = deskCache.spVehParamsHandler
        and sampev.onSetVehicleParamsEx == deskCache.spVehParamsHandler
    local vehParamsPlayerOk = deskCache.spVehParamsPlayerHandler
        and sampev.onSetVehicleParams == deskCache.spVehParamsPlayerHandler
    if enterOk and exitOk and interiorOk and vehicleOk and passengerOk and playerOk
            and vehParamsOk and vehParamsPlayerOk then
        return
    end

    if not enterOk then
        local prevEnter = sampev.onPlayerEnterVehicle
        if prevEnter == deskCache.spEnterHandler then prevEnter = deskCache.hookPrevSpEnter end
        if deskCache.hookPrevSpEnter == nil then deskCache.hookPrevSpEnter = prevEnter end
        deskCache.spEnterHandler = function(playerId, vehicleId, passenger)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshEnterVehicle then
                pcall(deskSpectateStats.onSpRefreshEnterVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevEnter, playerId, vehicleId, passenger)
        end
        sampev.onPlayerEnterVehicle = deskCache.spEnterHandler
    end

    if not exitOk then
        local prevExit = sampev.onPlayerExitVehicle
        if prevExit == deskCache.spExitHandler then prevExit = deskCache.hookPrevSpExit end
        if deskCache.hookPrevSpExit == nil then deskCache.hookPrevSpExit = prevExit end
        deskCache.spExitHandler = function(playerId, vehicleId)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshExitVehicle then
                pcall(deskSpectateStats.onSpRefreshExitVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevExit, playerId, vehicleId)
        end
        sampev.onPlayerExitVehicle = deskCache.spExitHandler
    end

    if not interiorOk then
        local prevInterior = sampev.onSetInterior
        if prevInterior == deskCache.spInteriorHandler then prevInterior = deskCache.hookPrevSpInterior end
        if deskCache.hookPrevSpInterior == nil then deskCache.hookPrevSpInterior = prevInterior end
        deskCache.spInteriorHandler = function(interior)
            if spRefreshWatchActive() and deskSpectateStats and deskSpectateStats.onSpRefreshSetInterior then
                pcall(deskSpectateStats.onSpRefreshSetInterior, interior)
            end
            return deskCallHookPrev(prevInterior, interior)
        end
        sampev.onSetInterior = deskCache.spInteriorHandler
    end

    if not vehicleOk then
        local prevVehicle = sampev.onVehicleSync
        if prevVehicle == deskCache.spVehicleSyncHandler then prevVehicle = deskCache.hookPrevSpVehicleSync end
        if deskCache.hookPrevSpVehicleSync == nil then deskCache.hookPrevSpVehicleSync = prevVehicle end
        deskCache.spVehicleSyncHandler = function(playerId, vehicleId, data)
            local vh = vehicleHud()
            if vh and vh.onVehicleSync then
                pcall(vh.onVehicleSync, playerId, vehicleId, data)
            end
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshVehicleSync then
                pcall(deskSpectateStats.onSpRefreshVehicleSync, playerId)
            end
            return deskCallHookPrev(prevVehicle, playerId, vehicleId, data)
        end
        sampev.onVehicleSync = deskCache.spVehicleSyncHandler
    end

    if not passengerOk then
        local prevPassenger = sampev.onPassengerSync
        if prevPassenger == deskCache.spPassengerSyncHandler then prevPassenger = deskCache.hookPrevSpPassengerSync end
        if deskCache.hookPrevSpPassengerSync == nil then deskCache.hookPrevSpPassengerSync = prevPassenger end
        deskCache.spPassengerSyncHandler = function(playerId, vehicleId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshPassengerSync then
                pcall(deskSpectateStats.onSpRefreshPassengerSync, playerId)
            end
            return deskCallHookPrev(prevPassenger, playerId, vehicleId, data)
        end
        sampev.onPassengerSync = deskCache.spPassengerSyncHandler
    end

    if not playerOk then
        local prevPlayer = sampev.onPlayerSync
        if prevPlayer == deskCache.spPlayerSyncHandler then prevPlayer = deskCache.hookPrevSpPlayerSync end
        if deskCache.hookPrevSpPlayerSync == nil then deskCache.hookPrevSpPlayerSync = prevPlayer end
        deskCache.spPlayerSyncHandler = function(playerId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshPlayerSync then
                pcall(deskSpectateStats.onSpRefreshPlayerSync, playerId)
            end
            return deskCallHookPrev(prevPlayer, playerId, data)
        end
        sampev.onPlayerSync = deskCache.spPlayerSyncHandler
    end

    if not vehParamsOk and sampev.onSetVehicleParamsEx ~= nil then
        local prevVehParams = sampev.onSetVehicleParamsEx
        if prevVehParams == deskCache.spVehParamsHandler then prevVehParams = deskCache.hookPrevSpVehParams end
        if deskCache.hookPrevSpVehParams == nil then deskCache.hookPrevSpVehParams = prevVehParams end
        deskCache.spVehParamsHandler = function(vehicleId, params, doors, windows)
            local vh = vehicleHud()
            if vh and vh.onSetVehicleParamsEx then
                pcall(vh.onSetVehicleParamsEx, vehicleId, params, doors, windows)
            end
            return deskCallHookPrev(prevVehParams, vehicleId, params, doors, windows)
        end
        sampev.onSetVehicleParamsEx = deskCache.spVehParamsHandler
    end

    if not vehParamsPlayerOk and sampev.onSetVehicleParams ~= nil then
        local prev = sampev.onSetVehicleParams
        if prev == deskCache.spVehParamsPlayerHandler then prev = deskCache.hookPrevSpVehParamsPlayer end
        if deskCache.hookPrevSpVehParamsPlayer == nil then deskCache.hookPrevSpVehParamsPlayer = prev end
        deskCache.spVehParamsPlayerHandler = function(vehicleId, objective, doorsLocked)
            local vh = vehicleHud()
            if vh and vh.onSetVehicleParams then
                pcall(vh.onSetVehicleParams, vehicleId, objective, doorsLocked)
            end
            return deskCallHookPrev(deskCache.hookPrevSpVehParamsPlayer, vehicleId, objective, doorsLocked)
        end
        sampev.onSetVehicleParams = deskCache.spVehParamsPlayerHandler
    end
end

-- Must be above installDeskSendChatHook (Lua 5.1: local after hook = global nil in closure).
local function noteOutgoingAnsCommand(message)
    if tonumber(deskCache.skipAnsStatsHook) and deskCache.skipAnsStatsHook > 0 then
        return
    end
    if type(exactTimeNoteOutgoingAns) == 'function' then
        pcall(exactTimeNoteOutgoingAns, message)
    end
end

local function noteManualStatsCommand(command)
    command = trim(command or '')
    local stId = command:match('^%/?st%s+(%d+)%s*$')
    if not stId then return end
    if tonumber(deskCache.skipStStatsHook) and deskCache.skipStStatsHook > 0 then
        return
    end
    if tonumber(deskCache.skipSpHookLocal) and deskCache.skipSpHookLocal > 0 then
        return
    end
    local s = spSession()
    if s and s.wasRecentOutboundCommand and s.wasRecentOutboundCommand(command) then
        return
    end
    if type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSt then
        pcall(deskSpectateStats.markPendingSt, tonumber(stId), { showDialog = true })
    end
end

local function noteUserChatCancelsPendingSt(message)
    message = trim(message or '')
    if message == '' then return end
    if message:match('^/?st%s+%d+') then return end
    if tonumber(deskCache.skipStStatsHook) and deskCache.skipStStatsHook > 0 then return end
    if type(deskSpectateStats) == 'table' and deskSpectateStats.cancelPendingSt then
        pcall(deskSpectateStats.cancelPendingSt)
    end
end

-- РџРµСЂРµС…РІР°С‚ РёСЃС…РѕРґСЏС‰РµРіРѕ С‡Р°С‚Р° (profanity, auto-rules).
function installDeskSendChatHook()
    if not sampev then return end
    if deskCache.sendChatHandler and sampev.onSendChat == deskCache.sendChatHandler then
        return
    end
    local prev = sampev.onSendChat
    if prev == deskCache.sendChatHandler then prev = nil end
    if deskCache.hookPrevSendChat == nil then deskCache.hookPrevSendChat = prev end
    deskCache.sendChatHandler = function(message)
        local blocked = false
        local ok, err = pcall(function()
            pcall(checkProfanityOutgoing, message)
            local cmd = trim(message or ''):match('^/?(%S+)')
            if cmd then
                local lc = cmd:lower()
                if lc == 'admins' or lc == 'adms' or lc == 'leaders' then
                    pcall(checkerOnSendCommand, message)
                end
            end
            if tryInterceptSplitAnsCommand(message) then
                blocked = true
                return
            end
            handleOutgoingAnsCommand(message)
            pcall(noteUserChatCancelsPendingSt, message)
            pcall(noteManualStatsCommand, message)
            if type(exactTimeNoteOutgoing) == 'function' then
                pcall(exactTimeNoteOutgoing, message)
            end
            if not blocked then
                noteOutgoingAnsCommand(message)
            end
            if type(adminPunishOutgoingLooksRelevant) == 'function'
                    and adminPunishOutgoingLooksRelevant(message)
                    and type(adminPunishNoteOutgoingMessage) == 'function' then
                pcall(adminPunishNoteOutgoingMessage, message)
            end
        end)
        if not ok then
            print('[Report Desk] send chat hook: ' .. tostring(err))
        end
        if blocked then return false end
        return deskCallHookPrev(prev, message)
    end
    sampev.onSendChat = deskCache.sendChatHandler
end

-- Try Handle Sp Spectate Command
function tryHandleSpSpectateCommand(command)
    command = trim(command or '')
    if tonumber(deskCache.skipSpHookLocal) and deskCache.skipSpHookLocal > 0 then
        return false
    end
    local spId = command:match('^%/?sp%s+(%d+)%s*$')
    if spId then
        spId = tonumber(spId)
        if spId and spId >= 0 then
            local nick = ''
            pcall(function()
                if sampIsPlayerConnected(spId) and sampGetPlayerNickname then
                    nick = sampGetPlayerNickname(spId) or ''
                end
            end)
            if deskSpectateStats and deskSpectateStats.markPendingSpCommand then
                pcall(deskSpectateStats.markPendingSpCommand, spId, nick)
            end
        end
        return false
    end
    if command:match('^%/?sp%s*$') then
        pcall(function()
            if deskSpectateStats and deskSpectateStats.onSpCommandOff then
                deskSpectateStats.onSpCommandOff()
            end
        end)
    end
    return false
end

-- РџРµСЂРµС…РІР°С‚ /sp Рё РґСЂСѓРіРёС… РєРѕРјР°РЅРґ РёР· С‡Р°С‚Р°.
function installDeskSendCommandHook()
    if not sampev then return end
    if deskCache.sendCommandHandler and sampev.onSendCommand == deskCache.sendCommandHandler then
        return
    end
    local prev = sampev.onSendCommand
    if prev == deskCache.sendCommandHandler then prev = nil end
    if deskCache.hookPrevSendCommand == nil then deskCache.hookPrevSendCommand = prev end
    deskCache.sendCommandHandler = function(command)
        command = trim(command or '')
        if command == '' then
            return deskCallHookPrev(prev, command)
        end
        local blocked = false
        local ansHandled = false
        local ok, err = pcall(function()
            pcall(checkerOnSendCommand, command)
            pcall(tryHandleSpSpectateCommand, command)
            pcall(noteManualStatsCommand, command)
            if type(exactTimeNoteOutgoing) == 'function' then
                pcall(exactTimeNoteOutgoing, command)
            end
            local id, body = command:match('^%/?ans%s+(%d+)%s+(.+)$')
            if id and body then
                if tryInterceptSplitAnsCommand(command) then
                    blocked = true
                    return
                end
                handleOutgoingAnsCommand(command)
                noteOutgoingAnsCommand(command)
                ansHandled = true
                return
            end
            if tryInterceptSplitAnsCommand(command) then
                blocked = true
                return
            end
            handleOutgoingAnsCommand(command)
            if type(adminPunishOutgoingLooksRelevant) == 'function'
                    and adminPunishOutgoingLooksRelevant(command)
                    and type(adminPunishNoteOutgoingMessage) == 'function' then
                pcall(adminPunishNoteOutgoingMessage, command)
            end
        end)
        if not ok then
            print('[Report Desk] send command hook: ' .. tostring(err))
        end
        if blocked then return false end
        if ansHandled then return end
        return deskCallHookPrev(prev, command)
    end
    sampev.onSendCommand = deskCache.sendCommandHandler
end

-- ADV: Р»РѕР¶РЅС‹Р№ toggle(false) вЂ” prev hook СЃР±СЂР°СЃС‹РІР°РµС‚ spectate; blockOff guard С‚РѕР»СЊРєРѕ РЅР° false.
-- РџРµСЂРµС…РІР°С‚ onTogglePlayerSpectating РґР»СЏ /sp UI.
function installDeskSpectateToggleHook()
    if not sampev then return end
    if deskCache.specToggleHandler and sampev.onTogglePlayerSpectating == deskCache.specToggleHandler then
        return
    end
    local prev = sampev.onTogglePlayerSpectating
    if prev == deskCache.specToggleHandler then prev = nil end
    if deskCache.hookPrevSpecToggle == nil then deskCache.hookPrevSpecToggle = prev end
    deskCache.specToggleHandler = function(toggle)
        if toggle then
            if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onTogglePlayerSpectating) == 'function' then
                pcall(deskSpectateStats.onTogglePlayerSpectating, toggle)
            end
            return deskCallHookPrev(prev, toggle)
        end
        -- ADV: Р»РѕР¶РЅС‹Р№ toggle(false) вЂ” prev hook СЃР±СЂР°СЃС‹РІР°РµС‚ spectate РІ РёРіСЂРµ; РЅРµ РІС‹Р·С‹РІР°РµРј РµРіРѕ.
        local blockOff = false
        if type(deskSpectateStats) == 'table' and type(deskSpectateStats.shouldBlockSpectateOff) == 'function' then
            local okBlock, res = pcall(deskSpectateStats.shouldBlockSpectateOff)
            blockOff = okBlock and res == true
        end
        if blockOff then
            if type(deskSpectateStats.onTogglePlayerSpectating) == 'function' then
                pcall(deskSpectateStats.onTogglePlayerSpectating, toggle)
            end
            return
        end
        if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onTogglePlayerSpectating) == 'function' then
            pcall(deskSpectateStats.onTogglePlayerSpectating, toggle)
        end
        return deskCallHookPrev(prev, toggle)
    end
    sampev.onTogglePlayerSpectating = deskCache.specToggleHandler
end

-- Sp Ui Enabled
-- SP menu hooks: report_desk_hooks_sp_menu.lua (same core_c chunk)

-- РЎРЅСЏС‚РёРµ РІСЃРµС… desk hooks РїСЂРё terminate.
-- Выгрузка spectate: единый teardown вместо только deskLeaveSpectateMode.
local function deskTeardownSpectateForUnload()
    if type(deskLeaveSpectateMode) == 'function' then
        pcall(deskLeaveSpectateMode)
    end
end

function deskUninstall()
    uninstallDeskSpMenuRpcBlock()
    uninstallDeskCheckerRpcProbe()
    if type(uninstallDeskUiFrames) == 'function' then
        pcall(uninstallDeskUiFrames)
    end
    if type(uninstallDeskD3DHandlers) == 'function' then
        pcall(uninstallDeskD3DHandlers)
    end
    if not sampev then
        uninstallDeskSpMenuHooks()
        if type(deskSpectateStats) == 'table' then
            if type(deskSpectateStats.uninstallSpectatePlayerHook) == 'function' then
                pcall(deskSpectateStats.uninstallSpectatePlayerHook)
            end
            if type(deskSpectateStats.uninstallSpSpectateOverlayFrame) == 'function' then
                pcall(deskSpectateStats.uninstallSpSpectateOverlayFrame)
            end
        end
        if type(uninstallCheckerHudFrame) == 'function' then
            pcall(uninstallCheckerHudFrame)
        end
        if type(checkerDismissOpenSyncDialogOnUnload) == 'function' then
            pcall(checkerDismissOpenSyncDialogOnUnload)
        end
        pcall(deskTeardownSpectateForUnload)
        pcall(function()
            if deskWmDispatch and deskWmDispatch.uninstall then
                deskWmDispatch.uninstall()
            end
        end)
        if type(deskUninstallSampInputEnableHook) == 'function' then
            pcall(deskUninstallSampInputEnableHook)
        end
        return
    end
    if deskCache.serverMsgHandler and sampev.onServerMessage == deskCache.serverMsgHandler then
        sampev.onServerMessage = deskCache.hookPrevServerMsg
    end
    if deskCache.specDialogHandler and sampev.onShowDialog == deskCache.specDialogHandler then
        sampev.onShowDialog = deskCache.hookPrevShowDialog
    end
    if deskCache.specToggleHandler and sampev.onTogglePlayerSpectating == deskCache.specToggleHandler then
        sampev.onTogglePlayerSpectating = deskCache.hookPrevSpecToggle
    end
    if deskCache.sendChatHandler and sampev.onSendChat == deskCache.sendChatHandler then
        sampev.onSendChat = deskCache.hookPrevSendChat
    end
    if deskCache.sendCommandHandler and sampev.onSendCommand == deskCache.sendCommandHandler then
        sampev.onSendCommand = deskCache.hookPrevSendCommand
    end
    if deskCache.playerQuitHandler and sampev.onPlayerQuit == deskCache.playerQuitHandler then
        sampev.onPlayerQuit = deskCache.hookPrevPlayerQuit
    end
    if deskCache.playerJoinHandler and sampev.onPlayerJoin == deskCache.playerJoinHandler then
        sampev.onPlayerJoin = deskCache.hookPrevPlayerJoin
    end
    if deskCache.playerStreamInHandler and sampev.onPlayerStreamIn == deskCache.playerStreamInHandler then
        sampev.onPlayerStreamIn = deskCache.hookPrevPlayerStreamIn
    end
    if deskCache.playerColorHandler and sampev.onSetPlayerColor == deskCache.playerColorHandler then
        sampev.onSetPlayerColor = deskCache.hookPrevPlayerColor
    end
    if deskCache.spEnterHandler and sampev.onPlayerEnterVehicle == deskCache.spEnterHandler then
        sampev.onPlayerEnterVehicle = deskCache.hookPrevSpEnter
    end
    if deskCache.spExitHandler and sampev.onPlayerExitVehicle == deskCache.spExitHandler then
        sampev.onPlayerExitVehicle = deskCache.hookPrevSpExit
    end
    if deskCache.spInteriorHandler and sampev.onSetInterior == deskCache.spInteriorHandler then
        sampev.onSetInterior = deskCache.hookPrevSpInterior
    end
    if deskCache.spVehicleSyncHandler and sampev.onVehicleSync == deskCache.spVehicleSyncHandler then
        sampev.onVehicleSync = deskCache.hookPrevSpVehicleSync
    end
    if deskCache.spPassengerSyncHandler and sampev.onPassengerSync == deskCache.spPassengerSyncHandler then
        sampev.onPassengerSync = deskCache.hookPrevSpPassengerSync
    end
    if deskCache.spPlayerSyncHandler and sampev.onPlayerSync == deskCache.spPlayerSyncHandler then
        sampev.onPlayerSync = deskCache.hookPrevSpPlayerSync
    end
    if deskCache.spVehParamsHandler and sampev.onSetVehicleParamsEx == deskCache.spVehParamsHandler then
        sampev.onSetVehicleParamsEx = deskCache.hookPrevSpVehParams
    end
    if deskCache.profBubbleHandler and sampev.onPlayerChatBubble == deskCache.profBubbleHandler then
        sampev.onPlayerChatBubble = deskCache.hookPrevProfBubble
    end
    if deskCache.profChatHandler and sampev.onChatMessage == deskCache.profChatHandler then
        sampev.onChatMessage = deskCache.hookPrevProfChat
    end
    if deskCache.gmHealthHandler and sampev.onSetPlayerHealth == deskCache.gmHealthHandler then
        sampev.onSetPlayerHealth = deskCache.hookPrevSetPlayerHealth
    end
    deskCache.gmHealthHandler = nil
    deskCache.serverMsgHandler = nil
    deskCache.specDialogHandler = nil
    deskCache.specToggleHandler = nil
    deskCache.sendChatHandler = nil
    deskCache.sendCommandHandler = nil
    deskCache.playerQuitHandler = nil
    deskCache.playerJoinHandler = nil
    deskCache.playerColorHandler = nil
    deskCache.profBubbleHandler = nil
    deskCache.profChatHandler = nil
    deskCache.profHooksInstalled = false
    deskCache.profLineSeen = {}
    deskCache.remoteChatDedup = {}
    deskCache.remoteChatDedupOrd = {}
    deskCache.remoteChatQueue = {}
    deskCache.sampPlayerColors = {}
    uninstallDeskSpMenuHooks()
    if type(deskSpectateStats) == 'table' then
        if type(deskSpectateStats.uninstallSpectatePlayerHook) == 'function' then
            pcall(deskSpectateStats.uninstallSpectatePlayerHook)
        end
        if type(deskSpectateStats.uninstallSpSpectateOverlayFrame) == 'function' then
            pcall(deskSpectateStats.uninstallSpSpectateOverlayFrame)
        end
    end
    if type(uninstallCheckerHudFrame) == 'function' then
        pcall(uninstallCheckerHudFrame)
    end
    if type(checkerDismissOpenSyncDialogOnUnload) == 'function' then
        pcall(checkerDismissOpenSyncDialogOnUnload)
    end
    pcall(deskTeardownSpectateForUnload)
    pcall(function()
        if deskWmDispatch and deskWmDispatch.uninstall then
            deskWmDispatch.uninstall()
        end
    end)
    if type(deskUninstallSampInputEnableHook) == 'function' then
        pcall(deskUninstallSampInputEnableHook)
    end
end
