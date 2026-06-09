--[[ Модуль: перехват SAMP-событий (чат, диалоги, RPC меню /sp). ]]

local spSessionMod
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

-- Центральный обработчик onServerMessage: checker, spectate, ingest, profanity.
function deskOnServerMessage(color, text)
    if type(chatSeen) ~= 'table' or type(chatSeen.lines) ~= 'table' then
        print('[Report Desk] server msg: chatSeen unavailable (reload script)')
        return
    end
    if not text or text == '' then return end
    pcall(checkerOnServerMessage, color, text)
    if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onServerMessage) == 'function' then
        pcall(deskSpectateStats.onServerMessage, color, text)
    end
    if not chatLogReady then return end
    local plain = stripChatTimestamp(stripTags(text))
    if plain == '' then return end

    local ingestKey = chatLineSeenKey(text)
    if ingestKey ~= '' and chatSeen.lines[ingestKey] then
        if type(settings) == 'table' and settings.profanity_filter_enabled and not profanityIsLineSeen(ingestKey) then
            pcall(checkProfanityFromChatLine, plain, ingestKey)
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

    if type(settings) == 'table' and settings.profanity_filter_enabled then
        pcall(checkProfanityFromChatLine, plain, chatLineSeenKey(text))
    end
end

-- Hook onServerMessage установлен и активен.
function deskIsServerMsgHookActive()
    return deskCache.serverMsgHandler ~= nil
        and sampev ~= nil
        and sampev.onServerMessage == deskCache.serverMsgHandler
end

-- Перехват onShowDialog: /st stats и checker dialogs.
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

-- Устанавливает перехват onServerMessage.
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

-- Godmode: как AdminTools — только onSetPlayerHealth.
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

-- Quit игрока → checker, spectate exit, thread offline.
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

-- Join → checker notify/catalog.
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

-- StreamIn → checker rebuild schedule.
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

-- SetPlayerColor RPC → clist (TAB).
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

-- /sp auto-refresh: RPC enter/exit/interior + sync + onSpectatePlayer/Vehicle.
function installDeskSpRefreshHooks()
    if not sampev then return end
    local enterOk = deskCache.spEnterHandler and sampev.onPlayerEnterVehicle == deskCache.spEnterHandler
    local exitOk = deskCache.spExitHandler and sampev.onPlayerExitVehicle == deskCache.spExitHandler
    local interiorOk = deskCache.spInteriorHandler and sampev.onSetInterior == deskCache.spInteriorHandler
    local vehicleOk = deskCache.spVehicleSyncHandler and sampev.onVehicleSync == deskCache.spVehicleSyncHandler
    local passengerOk = deskCache.spPassengerSyncHandler and sampev.onPassengerSync == deskCache.spPassengerSyncHandler
    local playerOk = deskCache.spPlayerSyncHandler and sampev.onPlayerSync == deskCache.spPlayerSyncHandler
    if enterOk and exitOk and interiorOk and vehicleOk and passengerOk and playerOk then return end

    if not enterOk then
        local prevEnter = sampev.onPlayerEnterVehicle
        if prevEnter == deskCache.spEnterHandler then prevEnter = deskCache.hookPrevSpEnter end
        if deskCache.hookPrevSpEnter == nil then deskCache.hookPrevSpEnter = prevEnter end
        deskCache.spEnterHandler = function(playerId, vehicleId, passenger)
            if deskSpectateStats and deskSpectateStats.onSpRefreshEnterVehicle then
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
            if deskSpectateStats and deskSpectateStats.onSpRefreshExitVehicle then
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
            if deskSpectateStats and deskSpectateStats.onSpRefreshSetInterior then
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
            if deskSpectateStats and deskSpectateStats.onSpRefreshVehicleSync then
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
            if deskSpectateStats and deskSpectateStats.onSpRefreshPassengerSync then
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
            if deskSpectateStats and deskSpectateStats.onSpRefreshPlayerSync then
                pcall(deskSpectateStats.onSpRefreshPlayerSync, playerId)
            end
            return deskCallHookPrev(prevPlayer, playerId, data)
        end
        sampev.onPlayerSync = deskCache.spPlayerSyncHandler
    end
end

-- Перехват исходящего чата (profanity, auto-rules).
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
            noteManualStatsCommand(message)
        end)
        if not ok then
            print('[Report Desk] send chat hook: ' .. tostring(err))
        end
        if blocked then return false end
        return deskCallHookPrev(prev, message)
    end
    sampev.onSendChat = deskCache.sendChatHandler
end

-- Note Manual Stats Command — ручной /st из чата: показать server dialog, не HUD-парсинг.
local function noteManualStatsCommand(command)
    command = trim(command or '')
    local stId = command:match('^%/?st%s+(%d+)%s*$')
    if not stId then return end
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
            if deskSpectateStats and deskSpectateStats.clearSpectateTarget then
                deskSpectateStats.clearSpectateTarget(true)
            end
            deskLeaveSpectateMode()
            deskApplyInputPolicy()
        end)
    end
    return false
end

-- Перехват /sp и других команд из чата.
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
            local id, body = command:match('^%/?ans%s+(%d+)%s+(.+)$')
            if id and body then
                if tryInterceptSplitAnsCommand(command) then
                    blocked = true
                    return
                end
                handleOutgoingAnsCommand(command)
                ansHandled = true
                return
            end
            if tryInterceptSplitAnsCommand(command) then
                blocked = true
                return
            end
            handleOutgoingAnsCommand(command)
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

-- Перехват onTogglePlayerSpectating для /sp UI.
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
            if type(prev) == 'function' then
                pcall(prev, toggle)
            end
            if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onTogglePlayerSpectating) == 'function' then
                pcall(deskSpectateStats.onTogglePlayerSpectating, toggle)
            end
            return
        end
        -- ADV: ложный toggle(false) — prev hook сбрасывает spectate в игре; не вызываем его.
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
        if type(prev) == 'function' then
            pcall(prev, toggle)
        end
        if type(deskSpectateStats) == 'table' and type(deskSpectateStats.onTogglePlayerSpectating) == 'function' then
            pcall(deskSpectateStats.onTogglePlayerSpectating, toggle)
        end
    end
    sampev.onTogglePlayerSpectating = deskCache.specToggleHandler
end

-- Sp Ui Enabled
local function spUiEnabled()
    local s = spSession()
    if s and s.getSettingsSnapshot then
        local cfg = s.getSettingsSnapshot()
        if cfg and cfg.spectate_sp_ui == false then return false end
    end
    return true
end

local foreignSamMenuId = nil

-- Should Block Server Sp Sam Menu Init
local function shouldBlockServerSpSamMenuInit(menuTitle, x, y, columns, menuId)
    if not spUiEnabled() then return false end
    local s = spSession()
    if not s or not s.isServerSpSamMenu then return false end
    local ok, isSp = pcall(s.isServerSpSamMenu, menuTitle, x, y, columns)
    if not ok or not isSp then
        if menuId ~= nil then foreignSamMenuId = menuId end
        return false
    end
    foreignSamMenuId = nil
    if s.captureServerMenuLayout then
        pcall(s.captureServerMenuLayout, x, y, columns, menuTitle)
    end
    return true
end

-- Should Block Server Sp Sam Menu Show
local function shouldBlockServerSpSamMenuShow(menuId)
    if not spUiEnabled() then
        foreignSamMenuId = nil
        return false
    end
    if foreignSamMenuId ~= nil and menuId == foreignSamMenuId then return false end
    local s = spSession()
    if not s or not s.shouldSuppressServerSpMenu then
        foreignSamMenuId = nil
        return false
    end
    local ok, suppress = pcall(s.shouldSuppressServerSpMenu)
    if not ok or not suppress then
        foreignSamMenuId = nil
        return false
    end
    return true
end

-- Should Block Server Sp Sam Menu Hide
local function shouldBlockServerSpSamMenuHide(menuId)
    if foreignSamMenuId ~= nil and menuId == foreignSamMenuId then
        foreignSamMenuId = nil
        return false
    end
    return shouldBlockServerSpSamMenuShow(menuId)
end

-- Блок SA-Menu (onInitMenu/onShowMenu/onHideMenu) в /sp.
function installDeskSpMenuHooks()
    if not sampev then return end
    if deskCache.spMenuShowHandler and sampev.onShowMenu == deskCache.spMenuShowHandler then
        return
    end

    local prevInit = sampev.onInitMenu
    if prevInit == deskCache.spMenuInitHandler then prevInit = deskCache.hookPrevSpMenuInit end
    deskCache.hookPrevSpMenuInit = prevInit

    local prevShow = sampev.onShowMenu
    if prevShow == deskCache.spMenuShowHandler then prevShow = deskCache.hookPrevSpMenuShow end
    deskCache.hookPrevSpMenuShow = prevShow

    local prevHide = sampev.onHideMenu
    if prevHide == deskCache.spMenuHideHandler then prevHide = deskCache.hookPrevSpMenuHide end
    deskCache.hookPrevSpMenuHide = prevHide

    deskCache.spMenuInitHandler = function(menuId, menuTitle, x, y, twoColumns, columns, rows, menu)
        if shouldBlockServerSpSamMenuInit(menuTitle, x, y, columns, menuId) then
            return false
        end
        return deskCallHookPrev(deskCache.hookPrevSpMenuInit, menuId, menuTitle, x, y, twoColumns, columns, rows, menu)
    end
    sampev.onInitMenu = deskCache.spMenuInitHandler

    deskCache.spMenuShowHandler = function(menuId)
        if shouldBlockServerSpSamMenuShow(menuId) then
            return false
        end
        return deskCallHookPrev(deskCache.hookPrevSpMenuShow, menuId)
    end
    sampev.onShowMenu = deskCache.spMenuShowHandler

    deskCache.spMenuHideHandler = function(menuId)
        if shouldBlockServerSpSamMenuHide(menuId) then
            return false
        end
        return deskCallHookPrev(deskCache.hookPrevSpMenuHide, menuId)
    end
    sampev.onHideMenu = deskCache.spMenuHideHandler
end

-- Переустановка SP menu hooks если слетели.
function deskReinstallSpMenuHooks()
    installDeskSpMenuHooks()
end

-- Health-check: переустановка SAMP hooks если слетели.
function deskEnsureAllHooks()
    if not sampev then return end
    if not deskCache.serverMsgHandler or sampev.onServerMessage ~= deskCache.serverMsgHandler then
        installDeskServerMessageHook()
    end
    if not deskCache.specDialogHandler or sampev.onShowDialog ~= deskCache.specDialogHandler then
        installDeskSpectateDialogHook()
    end
    if not deskCache.specToggleHandler or sampev.onTogglePlayerSpectating ~= deskCache.specToggleHandler then
        installDeskSpectateToggleHook()
    end
    if not deskCache.sendChatHandler or sampev.onSendChat ~= deskCache.sendChatHandler then
        installDeskSendChatHook()
    end
    if not deskCache.sendCommandHandler or sampev.onSendCommand ~= deskCache.sendCommandHandler then
        installDeskSendCommandHook()
    end
    if not deskCache.playerQuitHandler or sampev.onPlayerQuit ~= deskCache.playerQuitHandler then
        installDeskPlayerQuitHook()
    end
    if not deskCache.playerJoinHandler or sampev.onPlayerJoin ~= deskCache.playerJoinHandler then
        installDeskPlayerJoinHook()
    end
    if not deskCache.playerStreamInHandler or sampev.onPlayerStreamIn ~= deskCache.playerStreamInHandler then
        installDeskPlayerStreamInHook()
    end
    if not deskCache.playerColorHandler or sampev.onSetPlayerColor ~= deskCache.playerColorHandler then
        installDeskPlayerColorHook()
    end
    if not deskGodmodeHooksActive() then
        installDeskGodmodeHealthHook()
    end
    if not deskCache.spEnterHandler or sampev.onPlayerEnterVehicle ~= deskCache.spEnterHandler
            or not deskCache.spExitHandler or sampev.onPlayerExitVehicle ~= deskCache.spExitHandler
            or not deskCache.spInteriorHandler or sampev.onSetInterior ~= deskCache.spInteriorHandler
            or not deskCache.spVehicleSyncHandler or sampev.onVehicleSync ~= deskCache.spVehicleSyncHandler
            or not deskCache.spPassengerSyncHandler or sampev.onPassengerSync ~= deskCache.spPassengerSyncHandler
            or not deskCache.spPlayerSyncHandler or sampev.onPlayerSync ~= deskCache.spPlayerSyncHandler then
        installDeskSpRefreshHooks()
    end
    if not deskCache.profHooksInstalled
            or (deskCache.profChatHandler and sampev.onChatMessage ~= deskCache.profChatHandler)
            or (deskCache.profBubbleHandler and sampev.onPlayerChatBubble ~= deskCache.profBubbleHandler) then
        deskCache.profHooksInstalled = false
        installProfanityHooks()
    end
    if deskSpectateStats and deskSpectateStats.ensureInputHooks then
        deskSpectateStats.ensureInputHooks()
    end
    deskReinstallSpMenuHooks()
    installDeskSpMenuRpcBlock()
    installDeskCheckerRpcProbe()
    if deskWmDispatch and deskWmDispatch.ensureInstalled then
        deskWmDispatch.ensureInstalled()
    end
end

-- Desk hook/helper.
function deskAreSpMenuHooksActive()
    return deskCache.spMenuShowHandler ~= nil
        and sampev.onShowMenu == deskCache.spMenuShowHandler
        and deskCache.spMenuInitHandler ~= nil
        and sampev.onInitMenu == deskCache.spMenuInitHandler
        and deskCache.spMenuHideHandler ~= nil
        and sampev.onHideMenu == deskCache.spMenuHideHandler
end

-- Reset Rpc Bitstream
local function resetRpcBitstream(bs)
    if raknetBitStreamResetReadPointer then
        raknetBitStreamResetReadPointer(bs)
    end
end

-- RPC-блок серверного меню /sp (INITMENU/SHOWMENU/HIDEMENU).
function installDeskSpMenuRpcBlock()
    if deskCache.spMenuRpcRegistered then return end
    local ok, raknet = pcall(require, 'samp.raknet')
    if not ok or not raknet or not raknet.RPC then return end
    local okH, menuHandler = pcall(require, 'samp.events.handlers')
    if not okH or not menuHandler then return end

    local RPC_INIT_MENU = raknet.RPC.INITMENU
    local RPC_SHOW_MENU = raknet.RPC.SHOWMENU
    local RPC_HIDE_MENU = raknet.RPC.HIDEMENU

    local okBs, bsIo = pcall(require, 'samp.events.bitstream_io')
    if not okBs then bsIo = nil end

    local handler = function(rpcId, bs)
        if rpcId ~= RPC_INIT_MENU and rpcId ~= RPC_SHOW_MENU and rpcId ~= RPC_HIDE_MENU then
            return
        end
        if rpcId == RPC_INIT_MENU then
            local readOk, packed = pcall(menuHandler.on_init_menu_reader, bs)
            resetRpcBitstream(bs)
            if readOk and packed then
                if shouldBlockServerSpSamMenuInit(packed[2], packed[3], packed[4], packed[6], packed[1]) then
                    return false
                end
            end
            return
        end
        local menuId = nil
        if bsIo and bsIo.int8 and bsIo.int8.read then
            local okId, id = pcall(bsIo.int8.read, bs)
            if okId then menuId = id end
        end
        resetRpcBitstream(bs)
        if rpcId == RPC_SHOW_MENU then
            if shouldBlockServerSpSamMenuShow(menuId) then return false end
        elseif rpcId == RPC_HIDE_MENU then
            if shouldBlockServerSpSamMenuHide(menuId) then return false end
        end
    end
    deskCache.spMenuRpcHandler = handler
    addEventHandler('onReceiveRpc', handler, 2147483647)
    deskCache.spMenuRpcRegistered = true
end

-- Снятие RPC-блока серверного меню /sp.
function uninstallDeskSpMenuRpcBlock()
    if deskCache.spMenuRpcHandler and removeEventHandler then
        pcall(removeEventHandler, 'onReceiveRpc', deskCache.spMenuRpcHandler)
    end
    deskCache.spMenuRpcHandler = nil
    deskCache.spMenuRpcRegistered = false
end

-- Dev: лог нестандартных RPC во время окна /adms (settings.checker_dev_rpc_probe).
function installDeskCheckerRpcProbe()
    if deskCache.checkerRpcProbeRegistered then return end
    local ok, raknet = pcall(require, 'samp.raknet')
    if not ok or not raknet or not raknet.RPC then return end
    local RPC = raknet.RPC
    local skip = {
        [RPC.SHOWDIALOG or 61] = true,
        [RPC.CLIENTMESSAGE or 93] = true,
        [RPC.WORLDPLAYERADD or 32] = true,
        [RPC.WORLDPLAYERREMOVE or 163] = true,
        [RPC.UPDATESCORESPINGSIPS or 155] = true,
        [RPC.SETPLAYERCOLOR or 72] = true,
    }
    local handler = function(rpcId)
        if settings.checker_dev_rpc_probe ~= true then return end
        if type(checkerIsAdmsSyncWindow) ~= 'function' or not checkerIsAdmsSyncWindow() then return end
        if skip[rpcId] then return end
        print(string.format('[Report Desk] checker rpc probe: id=%s during /adms sync', tostring(rpcId)))
    end
    deskCache.checkerRpcProbeHandler = handler
    addEventHandler('onReceiveRpc', handler)
    deskCache.checkerRpcProbeRegistered = true
end

-- Снятие dev RPC-probe checker.
function uninstallDeskCheckerRpcProbe()
    if deskCache.checkerRpcProbeHandler and removeEventHandler then
        pcall(removeEventHandler, 'onReceiveRpc', deskCache.checkerRpcProbeHandler)
    end
    deskCache.checkerRpcProbeHandler = nil
    deskCache.checkerRpcProbeRegistered = false
end

-- Uninstall Desk Sp Menu Hooks
function uninstallDeskSpMenuHooks()
    if not sampev then return end
    if deskCache.spMenuInitHandler and sampev.onInitMenu == deskCache.spMenuInitHandler then
        sampev.onInitMenu = deskCache.hookPrevSpMenuInit
    end
    if deskCache.spMenuShowHandler and sampev.onShowMenu == deskCache.spMenuShowHandler then
        sampev.onShowMenu = deskCache.hookPrevSpMenuShow
    end
    if deskCache.spMenuHideHandler and sampev.onHideMenu == deskCache.spMenuHideHandler then
        sampev.onHideMenu = deskCache.hookPrevSpMenuHide
    end
    deskCache.spMenuInitHandler = nil
    deskCache.spMenuShowHandler = nil
    deskCache.spMenuHideHandler = nil
    deskCache.hookPrevSpMenuInit = nil
    deskCache.hookPrevSpMenuShow = nil
    deskCache.hookPrevSpMenuHide = nil
end

-- Снятие всех desk hooks при terminate.
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
        if type(deskLeaveSpectateMode) == 'function' then
            pcall(deskLeaveSpectateMode)
        end
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
    if deskCache.profBubbleHandler and sampev.onPlayerChatBubble == deskCache.profBubbleHandler then
        sampev.onPlayerChatBubble = deskCache.hookPrevProfBubble
    end
    if deskCache.profChatHandler and sampev.onChatMessage == deskCache.profChatHandler then
        sampev.onChatMessage = deskCache.hookPrevProfChat
    end
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
    deskLeaveSpectateMode()
    pcall(function()
        if deskWmDispatch and deskWmDispatch.uninstall then
            deskWmDispatch.uninstall()
        end
    end)
    if type(deskUninstallSampInputEnableHook) == 'function' then
        pcall(deskUninstallSampInputEnableHook)
    end
end
