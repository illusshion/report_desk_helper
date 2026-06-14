--[[ Модуль: перехват исходящего чата и команд (/ans, /sp, /st). ]]

local spSessionMod
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

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

function installDeskSendChatHook()
    if not sampev then return end
    if deskCache.sendChatHandler and sampev.onSendChat == deskCache.sendChatHandler then
        return
    end
    local prev = sampev.onSendChat
    if prev == deskCache.sendChatHandler then prev = nil end
    deskCache.hookPrevSendChat = prev
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

function installDeskSendCommandHook()
    if not sampev then return end
    if deskCache.sendCommandHandler and sampev.onSendCommand == deskCache.sendCommandHandler then
        return
    end
    local prev = sampev.onSendCommand
    if prev == deskCache.sendCommandHandler then prev = nil end
    deskCache.hookPrevSendCommand = prev
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
