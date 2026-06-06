--[[ Report Desk SAMP hooks ]]
function deskOnServerMessage(color, text)
    if not text or text == '' then return end
    pcall(checkerOnServerMessage, color, text)
    pcall(deskSpectateStats.onServerMessage, color, text)
    local plain = stripChatTimestamp(stripTags(text))
    if plain == '' then return end

    if tryIngestAdminReplyLine(plain) then
        markChatLineSeen(chatLineSeenKey(text))
        return
    end

    if processChatLineIngest(plain, color, 'srv', true, text, { delay = 0 }) then
        markChatLineSeen(chatLineSeenKey(text))
        return
    end

    if settings.profanity_filter_enabled then
        pcall(checkProfanityFromChatLine, plain)
    end
end

function installDeskSpectateDialogHook()
    if deskCache.specDialogHandler and sampev.onShowDialog == deskCache.specDialogHandler then
        return
    end
    local prev = sampev.onShowDialog
    if prev == deskCache.specDialogHandler then prev = nil end
    if deskCache.hookPrevShowDialog == nil then deskCache.hookPrevShowDialog = prev end
    deskCache.specDialogHandler = function(dialogId, style, title, button1, button2, text)
        if deskSpectateStats.onShowDialog(dialogId, style, title, button1, button2, text) then
            return false
        end
        local checkerHandled = false
        local okChk, chkRes = pcall(checkerOnShowDialog, dialogId, style, title, button1, button2, text)
        if not okChk then
            print('[Report Desk] checker dialog error: ' .. tostring(chkRes))
        elseif chkRes == true then
            checkerHandled = true
        end
        if checkerHandled then return false end
        if type(deskCache.hookPrevShowDialog) == 'function' then
            return deskCache.hookPrevShowDialog(dialogId, style, title, button1, button2, text)
        end
    end
    sampev.onShowDialog = deskCache.specDialogHandler
end

function installDeskServerMessageHook()
    if deskCache.serverMsgHandler and sampev.onServerMessage == deskCache.serverMsgHandler then return end
    local prev = sampev.onServerMessage
    if prev == deskCache.serverMsgHandler then prev = nil end
    if deskCache.hookPrevServerMsg == nil then deskCache.hookPrevServerMsg = prev end
    deskCache.serverMsgHandler = function(color, text)
        deskOnServerMessage(color, text)
        if type(prev) == 'function' then
            return prev(color, text)
        end
    end
    sampev.onServerMessage = deskCache.serverMsgHandler
end

function deskOnPlayerQuit(playerId, reason)
    playerId = tonumber(playerId)
    if not playerId then return end
    pcall(checkerOnPlayerQuit, playerId)
    pcall(function()
        if deskSpectateStats.notifyTargetQuit then
            deskSpectateStats.notifyTargetQuit(playerId)
        end
    end)
    local quitNk = ''
    for _, t in pairs(threads) do
        if tonumber(t.id) == playerId then
            quitNk = nickKey(t.nick)
            t.offlineAt = os.time()
            t.stale = true
            t.lastId = t.id
        end
    end
    if outbound.pending and tonumber(outbound.pending.id) == playerId then
        local pNk = outbound.pending.nickKey or ''
        if quitNk == '' or pNk == '' or pNk == quitNk then
            clearPendingOutbound()
        end
    end
    markDirtyThreads()
end

function installDeskPlayerQuitHook()
    if deskCache.playerQuitHandler and sampev.onPlayerQuit == deskCache.playerQuitHandler then
        return
    end
    local prev = sampev.onPlayerQuit
    if prev == deskCache.playerQuitHandler then prev = nil end
    if deskCache.hookPrevPlayerQuit == nil then deskCache.hookPrevPlayerQuit = prev end
    deskCache.playerQuitHandler = function(playerId, reason)
        deskOnPlayerQuit(playerId, reason)
        if type(prev) == 'function' then
            return prev(playerId, reason)
        end
    end
    sampev.onPlayerQuit = deskCache.playerQuitHandler
end

function deskOnPlayerJoin(playerId, color, isNpc, nickname)
    pcall(checkerOnPlayerJoin, playerId, nickname)
end

function installDeskPlayerJoinHook()
    if deskCache.playerJoinHandler and sampev.onPlayerJoin == deskCache.playerJoinHandler then
        return
    end
    local prev = sampev.onPlayerJoin
    if prev == deskCache.playerJoinHandler then prev = nil end
    if deskCache.hookPrevPlayerJoin == nil then deskCache.hookPrevPlayerJoin = prev end
    deskCache.playerJoinHandler = function(playerId, color, isNpc, nickname)
        deskOnPlayerJoin(playerId, color, isNpc, nickname)
        if type(prev) == 'function' then
            return prev(playerId, color, isNpc, nickname)
        end
    end
    sampev.onPlayerJoin = deskCache.playerJoinHandler
end

function installDeskPlayerStreamInHook()
    if deskCache.playerStreamInHandler and sampev.onPlayerStreamIn == deskCache.playerStreamInHandler then
        return
    end
    local prev = sampev.onPlayerStreamIn
    if prev == deskCache.playerStreamInHandler then prev = nil end
    if deskCache.hookPrevPlayerStreamIn == nil then deskCache.hookPrevPlayerStreamIn = prev end
    deskCache.playerStreamInHandler = function(playerId, team, model, position, rotation, color, fightingStyle)
        pcall(checkerOnPlayerStreamIn, playerId)
        if type(prev) == 'function' then
            return prev(playerId, team, model, position, rotation, color, fightingStyle)
        end
    end
    sampev.onPlayerStreamIn = deskCache.playerStreamInHandler
end

function installDeskSendChatHook()
    if deskCache.sendChatHandler and sampev.onSendChat == deskCache.sendChatHandler then
        return
    end
    local prev = sampev.onSendChat
    if prev == deskCache.sendChatHandler then prev = nil end
    if deskCache.hookPrevSendChat == nil then deskCache.hookPrevSendChat = prev end
    deskCache.sendChatHandler = function(message)
        pcall(checkProfanityOutgoing, message)
        local cmd = trim(message or ''):match('^/?(%S+)')
        if cmd then
            local lc = cmd:lower()
            if lc == 'admins' or lc == 'adms' or lc == 'leaders' then
                pcall(checkerOnSendCommand, message)
            end
        end
        if tryInterceptSplitAnsCommand(message) then return false end
        handleOutgoingAnsCommand(message)
        if type(prev) == 'function' then
            return prev(message)
        end
    end
    sampev.onSendChat = deskCache.sendChatHandler
end

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
            deskSpectateStats.markPendingSpCommand(spId, nick)
        end
        return false
    end
    if command:match('^%/?sp%s*$') then
        deskSpectateStats.onSpCommandOff()
        deskSpectateStats.clearSpectateTarget(true)
        deskLeaveSpectateMode()
        deskApplyInputPolicy()
    end
    return false
end

function installDeskSendCommandHook()
    if deskCache.sendCommandHandler and sampev.onSendCommand == deskCache.sendCommandHandler then
        return
    end
    local prev = sampev.onSendCommand
    if prev == deskCache.sendCommandHandler then prev = nil end
    if deskCache.hookPrevSendCommand == nil then deskCache.hookPrevSendCommand = prev end
    deskCache.sendCommandHandler = function(command)
        command = trim(command or '')
        if command == '' then
            if type(prev) == 'function' then return prev(command) end
            return
        end
        pcall(checkerOnSendCommand, command)
        tryHandleSpSpectateCommand(command)
        local id, body = command:match('^%/?ans%s+(%d+)%s+(.+)$')
        if id and body then
            if tryInterceptSplitAnsCommand(command) then return false end
            handleOutgoingAnsCommand(command)
            return
        end
        if tryInterceptSplitAnsCommand(command) then return false end
        handleOutgoingAnsCommand(command)
        if type(prev) == 'function' then
            return prev(command)
        end
    end
    sampev.onSendCommand = deskCache.sendCommandHandler
end

function installDeskSpectateToggleHook()
    if deskCache.specToggleHandler and sampev.onTogglePlayerSpectating == deskCache.specToggleHandler then
        return
    end
    local prev = sampev.onTogglePlayerSpectating
    if prev == deskCache.specToggleHandler then prev = nil end
    if deskCache.hookPrevSpecToggle == nil then deskCache.hookPrevSpecToggle = prev end
    deskCache.specToggleHandler = function(toggle)
        local r
        if type(prev) == 'function' then
            r = prev(toggle)
        end
        pcall(deskSpectateStats.onTogglePlayerSpectating, toggle)
        return r
    end
    sampev.onTogglePlayerSpectating = deskCache.specToggleHandler
end

local spSessionMod
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

local function spUiEnabled()
    local s = spSession()
    if s and s.getSettingsSnapshot then
        local cfg = s.getSettingsSnapshot()
        if cfg and cfg.spectate_sp_ui == false then return false end
    end
    return true
end

function shouldBlockServerSamMenu()
    if not spUiEnabled() then return false end
    if type(deskSpectatingNow) == 'function' and deskSpectatingNow() then return true end
    local s = spSession()
    if s and s.shouldSuppressServerSpMenu then
        local ok, v = pcall(s.shouldSuppressServerSpMenu)
        if ok and v then return true end
    end
    return false
end

local function captureServerMenuLayout(x, y, columns, title)
    local s = spSession()
    if s and s.captureServerMenuLayout then
        pcall(s.captureServerMenuLayout, x, y, columns, title)
    end
end

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
        if shouldBlockServerSamMenu() then
            captureServerMenuLayout(x, y, columns, menuTitle)
            return false
        end
        if type(deskCache.hookPrevSpMenuInit) == 'function' then
            return deskCache.hookPrevSpMenuInit(menuId, menuTitle, x, y, twoColumns, columns, rows, menu)
        end
    end
    sampev.onInitMenu = deskCache.spMenuInitHandler

    deskCache.spMenuShowHandler = function(menuId)
        if shouldBlockServerSamMenu() then
            return false
        end
        if type(deskCache.hookPrevSpMenuShow) == 'function' then
            return deskCache.hookPrevSpMenuShow(menuId)
        end
    end
    sampev.onShowMenu = deskCache.spMenuShowHandler

    deskCache.spMenuHideHandler = function(menuId)
        if shouldBlockServerSamMenu() then
            return false
        end
        if type(deskCache.hookPrevSpMenuHide) == 'function' then
            return deskCache.hookPrevSpMenuHide(menuId)
        end
    end
    sampev.onHideMenu = deskCache.spMenuHideHandler
end

function deskReinstallSpMenuHooks()
    installDeskSpMenuHooks()
end

function deskAreSpMenuHooksActive()
    return deskCache.spMenuShowHandler ~= nil
        and sampev.onShowMenu == deskCache.spMenuShowHandler
        and deskCache.spMenuInitHandler ~= nil
        and sampev.onInitMenu == deskCache.spMenuInitHandler
        and deskCache.spMenuHideHandler ~= nil
        and sampev.onHideMenu == deskCache.spMenuHideHandler
end

local function resetRpcBitstream(bs)
    if raknetBitStreamResetReadPointer then
        raknetBitStreamResetReadPointer(bs)
    end
end

function installDeskSpMenuRpcBlock()
    if deskCache.spMenuRpcRegistered then return end
    local ok, raknet = pcall(require, 'samp.raknet')
    if not ok or not raknet or not raknet.RPC then return end
    local okH, menuHandler = pcall(require, 'samp.events.handlers')
    if not okH or not menuHandler then return end

    local RPC_INIT_MENU = raknet.RPC.INITMENU
    local RPC_SHOW_MENU = raknet.RPC.SHOWMENU
    local RPC_HIDE_MENU = raknet.RPC.HIDEMENU

    addEventHandler('onReceiveRpc', function(rpcId, bs)
        if rpcId ~= RPC_INIT_MENU and rpcId ~= RPC_SHOW_MENU and rpcId ~= RPC_HIDE_MENU then
            return
        end
        if not shouldBlockServerSamMenu() then return end
        if rpcId == RPC_INIT_MENU then
            local readOk, packed = pcall(menuHandler.on_init_menu_reader, bs)
            resetRpcBitstream(bs)
            if readOk and packed then
                captureServerMenuLayout(packed[3], packed[4], packed[6], packed[2])
            end
        else
            resetRpcBitstream(bs)
        end
        return false
    end, 2147483647)
    deskCache.spMenuRpcRegistered = true
end

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

function deskUninstall()
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
    deskCache.profBubbleHandler = nil
    deskCache.profChatHandler = nil
    deskCache.profHooksInstalled = false
    deskCache.profLineSeen = {}
    deskCache.profToasts = {}
    uninstallDeskSpMenuHooks()
    pcall(deskSpectateStats.uninstallSpectatePlayerHook)
    if deskSpectateStats.uninstallSpSpectateOverlayFrame then
        pcall(deskSpectateStats.uninstallSpSpectateOverlayFrame)
    end
    if type(uninstallCheckerHudFrame) == 'function' then
        pcall(uninstallCheckerHudFrame)
    end
    deskLeaveSpectateMode()
end
