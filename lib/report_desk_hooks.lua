--[[ Модуль: перехват SAMP-событий (чат, диалоги, RPC меню /sp). ]]
-- hot-path server message ordering, verify-only hook health-check.

--  early exits before ingest; dedup fast-path skips checker/stats; single profanity key.
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
    deskCache.hookPrevServerMsg = prev
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
    pcall(onlinePlayersOnQuit, playerId)
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
    pcall(function()
        local ok, mod = pcall(require, 'report_desk_sp_anticheat')
        if ok and mod.onPlayerQuit then mod.onPlayerQuit(playerId) end
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

-- Godmode: как AdminTools — onSetPlayerHealth + onSetVehicleHealth, setCarProofs каждый тик.
function installDeskGodmodeHealthHook()
    if not sampev then return end
    if deskCache.gmHealthHandler and sampev.onSetPlayerHealth == deskCache.gmHealthHandler then
        return
    end
    local prev = sampev.onSetPlayerHealth
    if prev == deskCache.gmHealthHandler then prev = nil end
    deskCache.hookPrevSetPlayerHealth = prev
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

function installDeskGodmodeVehicleHealthHook()
    if not sampev then return end
    if deskCache.gmVehHealthHandler and sampev.onSetVehicleHealth == deskCache.gmVehHealthHandler then
        return
    end
    local prev = sampev.onSetVehicleHealth
    if prev == deskCache.gmVehHealthHandler then prev = nil end
    deskCache.hookPrevSetVehicleHealth = prev
    deskCache.gmVehHealthHandler = function(vehicleId, health)
        local block
        local okGm, errGm = pcall(function()
            block = cheatsOnSetVehicleHealth(vehicleId, health)
        end)
        if not okGm then
            print('[Report Desk] godmode veh hook: ' .. tostring(errGm))
        end
        if block == false then return false end
        return deskCallHookPrev(deskCache.hookPrevSetVehicleHealth, vehicleId, health)
    end
    sampev.onSetVehicleHealth = deskCache.gmVehHealthHandler
end

function installDeskGodmodeHooks()
    installDeskGodmodeHealthHook()
    installDeskGodmodeVehicleHealthHook()
end

function deskGodmodeHooksActive()
    if not sampev then return false end
    return deskCache.gmHealthHandler and sampev.onSetPlayerHealth == deskCache.gmHealthHandler
        and deskCache.gmVehHealthHandler and sampev.onSetVehicleHealth == deskCache.gmVehHealthHandler
end

-- Quit РёРіСЂРѕРєР° в†’ checker, spectate exit, thread offline.
function installDeskPlayerQuitHook()
    if not sampev then return end
    if deskCache.playerQuitHandler and sampev.onPlayerQuit == deskCache.playerQuitHandler then
        return
    end
    local prev = sampev.onPlayerQuit
    if prev == deskCache.playerQuitHandler then prev = nil end
    deskCache.hookPrevPlayerQuit = prev
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
    pcall(onlinePlayersOnJoin, playerId, nickname)
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
    deskCache.hookPrevPlayerJoin = prev
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
    deskCache.hookPrevPlayerStreamIn = prev
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
    deskCache.hookPrevPlayerColor = prev
    deskCache.playerColorHandler = function(playerId, color)
        if type(sampStorePlayerColor) == 'function' then
            pcall(sampStorePlayerColor, playerId, color)
        end
        return deskCallHookPrev(prev, playerId, color)
    end
    sampev.onSetPlayerColor = deskCache.playerColorHandler
end

-- /sp auto-refresh: installDeskSpRefreshHooks в report_desk_hooks_sp_refresh.lua.
-- Перехват onTogglePlayerSpectating для /sp UI.
function installDeskSpectateToggleHook()
    if not sampev then return end
    if deskCache.specToggleHandler and sampev.onTogglePlayerSpectating == deskCache.specToggleHandler then
        return
    end
    local prev = sampev.onTogglePlayerSpectating
    if prev == deskCache.specToggleHandler then prev = nil end
    deskCache.hookPrevSpecToggle = prev
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
    if deskCache.spVehParamsPlayerHandler and sampev.onSetVehicleParams == deskCache.spVehParamsPlayerHandler then
        sampev.onSetVehicleParams = deskCache.hookPrevSpVehParamsPlayer
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
    if deskCache.gmVehHealthHandler and sampev.onSetVehicleHealth == deskCache.gmVehHealthHandler then
        sampev.onSetVehicleHealth = deskCache.hookPrevSetVehicleHealth
    end
    deskCache.gmHealthHandler = nil
    deskCache.gmVehHealthHandler = nil
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
