--[[ Модуль: входящие SAMP-сообщения и ingest. ]]

function deskOnServerMessage(color, text)
    if not text or text == '' then return end
    if type(deskOnLoginAdminLevelMessage) == 'function' then
        pcall(deskOnLoginAdminLevelMessage, color, text)
    end
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

    local plain = wirePlain(text)
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

    if profanityOn and ingestKey ~= '' then
        pcall(checkProfanityFromChatLine, plain, ingestKey)
    end
end
