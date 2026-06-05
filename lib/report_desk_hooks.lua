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
        local checkerHandled = false
        local okChk, chkRes = pcall(checkerOnShowDialog, dialogId, style, title, button1, button2, text)
        if not okChk then
            print('[Report Desk] checker dialog error: ' .. tostring(chkRes))
        elseif chkRes == true then
            checkerHandled = true
        end
        if checkerHandled then return false end
        if deskSpectateStats.onShowDialog(dialogId, style, title, button1, button2, text) then
            return false
        end
        if type(prev) == 'function' then
            return prev(dialogId, style, title, button1, button2, text)
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
        if deskSpectatingNow()
                and deskSpectateStats.getTargetId
                and tonumber(deskSpectateStats.getTargetId()) == playerId then
            deskSyncSpectateState(false)
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
            deskSetPlayerSpectating(true)
            deskSpectateStats.setSpectateTarget(spId, nick, settings)
        end
        return false
    end
    if command:match('^%/?sp%s*$') then
        deskSpectateStats.onSpCommandOff()
        deskSpectateStats.clearSpectateTarget(false)
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
        deskSpectateStats.onTogglePlayerSpectating(toggle)
        if type(prev) == 'function' then
            prev(toggle)
        end
    end
    sampev.onTogglePlayerSpectating = deskCache.specToggleHandler
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
    pcall(deskSpectateStats.uninstallSpectatePlayerHook)
    if type(uninstallCheckerHudFrame) == 'function' then
        pcall(uninstallCheckerHudFrame)
    end
    deskLeaveSpectateMode()
end
