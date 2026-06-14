--[[ Модуль: ingest репортов и poll чата. ]]

function addThreadEventMessage(targetNick, targetId, opts)
    opts = opts or {}
    local text = trim(opts.displayText or opts.text or '')
    if text == '' then return false end
    local key, t = resolveThread(targetNick, targetId)
    if not t then return false end
    addMessageToKey(key, {
        dir = 'event',
        kind = opts.kind or 'action',
        text = text,
        adminNick = opts.adminNick,
        actionTitle = opts.actionTitle,
        actionKind = opts.actionKind,
        displayText = opts.displayText or text,
        rawText = opts.rawText,
        punishReason = opts.punishReason,
        ts = os.time(),
    })
    return true
end

function findExistingThreadKey(targetNick, targetId)
    targetNick = trim(targetNick or '')
    targetId = tonumber(targetId)
    local key = targetNick ~= '' and findThreadKeyByNick(targetNick) or nil
    if key and threads[key] then return key, threads[key] end
    if targetId then
        local t, k = resolveThreadForPlayerId(targetId, targetNick)
        if t and k and threads[k] then return k, t end
    end
    return nil, nil
end

function addThreadEventMessageToExisting(targetNick, targetId, opts)
    opts = opts or {}
    local text = trim(opts.displayText or opts.text or '')
    if text == '' then return false end
    local key, t = findExistingThreadKey(targetNick, targetId)
    if not t or not key then return false end
    addMessageToKey(key, {
        dir = 'event',
        kind = opts.kind or 'action',
        text = text,
        adminNick = opts.adminNick,
        actionTitle = opts.actionTitle,
        actionKind = opts.actionKind,
        displayText = opts.displayText or text,
        rawText = opts.rawText,
        punishReason = opts.punishReason,
        ts = os.time(),
    })
    return true
end

function ingestAdminActionEvent(ev, source, isLive, rawLine)
    if not ev or ev.type ~= 'admin_action' then return false end
    local text = trim(ev.text or '')
    if text == '' then return false end
    local displayText = trim(ev.displayText or '')
    if displayText == '' then
        displayText = deskIngest.formatActionDisplay(
            ev.adminNick, ev.targetNick, ev.targetId, text,
            { title = ev.actionTitle, detail = ev.actionDetail or text, kind = ev.actionKind })
    end
    local targetNick, targetId = ev.targetNick, ev.targetId
    if targetNick and not targetId then
        targetId = findPlayerIdByNick(targetNick)
    end
    if not targetNick and targetId then
        pcall(function()
            if sampIsPlayerConnected and sampIsPlayerConnected(targetId) and sampGetPlayerNickname then
                targetNick = trim(sampGetPlayerNickname(targetId) or '')
            end
        end)
    end
    if not targetNick and not targetId then return false end

    local dedupId = targetId or 0
    if isDuplicateIngest(dedupId, 'adm|' .. text, rawLine) then return false end

    if not addThreadEventMessageToExisting(targetNick, targetId, {
        kind = 'action',
        text = text,
        displayText = displayText,
        adminNick = ev.adminNick,
        actionTitle = ev.actionTitle,
        actionKind = ev.actionKind,
        rawText = rawLine,
        isLive = isLive,
    }) then
        return false
    end
    markIngestDedup(dedupId, 'adm|' .. text, rawLine)
    markDirtyThreads()
    return true
end

function ingestPunishmentEvent(ev, source, isLive, rawLine)
    if not ev or ev.type ~= 'punishment' then return false end
    local text = trim(ev.text or '')
    if text == '' then return false end
    local targetNick = ev.targetNick
    local targetId = ev.targetId or findPlayerIdByNick(targetNick)
    if not targetNick then return false end

    local dedupId = targetId or 0
    if isDuplicateIngest(dedupId, 'pun|' .. text, rawLine) then return false end

    if not addThreadEventMessageToExisting(targetNick, targetId, {
        kind = 'punish',
        text = text,
        displayText = trim(ev.displayText or text),
        rawText = ev.rawText,
        punishReason = ev.punishReason,
        adminNick = ev.adminNick,
        isLive = isLive,
    }) then
        return false
    end
    markIngestDedup(dedupId, 'pun|' .. text, rawLine)
    if type(markDirtyThreads) == 'function' then
        markDirtyThreads()
    end
    return true
end

function processChatLineIngest(plain, color, source, isLive, rawLine, ingestMeta)
    local parseOpts = {}
    if source == 'chat' or source == 'srv' then
        parseOpts.chatStrictReports = true
    end
    local ev = deskIngest.tryParseChatEvent(plain, parseOpts)
    if not ev then return false end

    if ev.type == 'player_report' then
        if source == 'chat' and not ev.channel then
            return false
        end
        if source == 'srv' then
            local c = normColor(color)
            if not shouldIngestServerReport(c, plain) then return false end
            learnReportColor(c)
        end
        return ingestReport(color, plain, source, isLive, rawLine, ingestMeta, ev)
    end
    if ev.type == 'admin_action' then
        return ingestAdminActionEvent(ev, source, isLive, rawLine)
    end
    if ev.type == 'punishment' then
        return ingestPunishmentEvent(ev, source, isLive, rawLine)
    end
    return false
end

function onIncomingReport(nick, id, body, raw, isLive, source, channel)
    local key, t = resolveThread(nick, id)
    t.status = 'open'
    local reportChannel = deskIngest.extractReportChannel(channel) or deskIngest.extractReportChannel(raw)
    if reportChannel then
        t.reportChannel = reportChannel
    end
    local maxAge = tonumber(AUTO_REPLY_MAX_AGE_SEC) or 90
    local age = type(chatLineAgeSeconds) == 'function' and chatLineAgeSeconds(raw) or nil
    local fresh = age == nil or age <= maxAge
    if isLive and fresh then
        t.unread = (t.unread or 0) + 1
        totalUnread = totalUnread + 1
        local reportHasProfanity = settings.profanity_filter_enabled and findProfanityMatch(body)
        if settings.sound and not showWindow[0] and not reportHasProfanity then
            playNotify()
        end
    end
    addMessageToKey(key, {
        dir = 'in', kind = 'player', text = body, ts = os.time(), raw = raw,
        channel = channel,
    })
    markDirtyThreads()
    if isLive and fresh and settings.auto_rules_enabled ~= false then
        enqueueAutoReplyJob(nick, id, body, source or 'live')
    end
end

function ingestReport(color, text, source, isLive, rawLine, ingestMeta, ev)
    local nick, id, body, channel
    if ev and ev.type == 'player_report' then
        nick, id, body, channel = ev.nick, ev.id, ev.text, ev.channel
    else
        nick, id, body = tryParseReport(text)
    end
    if not nick then return false end
    if isReportLineConsumed(rawLine or text) then
        local seenKey = chatLineSeenKey(rawLine or text)
        if seenKey ~= '' then markChatLineSeen(seenKey) end
        return false
    end
    local seenKey = chatLineSeenKey(rawLine or text)
    if isDuplicateIngest(id, body, rawLine) then
        if seenKey ~= '' then markChatLineSeen(seenKey) end
        return false
    end
    local tk = findThreadKeyByNick(nick) or nickKey(nick)
    local th = threads[tk]
    if th and threadHasIncomingReportBody(th, body) then
        if seenKey ~= '' then markChatLineSeen(seenKey) end
        markReportLineConsumed(rawLine or text)
        return false
    end
    if settings.debug and ingestMeta then
        local delayMs = math.floor((ingestMeta.delay or 0) * 1000 + 0.5)
        say(string.format('[dbg] ingest %s delay_ms=%d %s[%d]',
            tostring(source or '?'), delayMs, nick, id))
    else
        debugLog(color, string.format('[%s] %s', source or '?', text))
    end
    onIncomingReport(nick, id, body, rawLine or text, isLive, source, channel)
    markIngestDedup(id, body, rawLine)
    markReportLineConsumed(rawLine or text)
    if seenKey ~= '' then markChatLineSeen(seenKey) end
    return true
end

function pollReportIngest()
    if not sampGetChatString then return end
    if not chatLogReady then return end
    local hookActive = type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive()
    local maxLines
    if hookActive then
        maxLines = CHAT_POLL_SAFETY_LINES
    else
        maxLines = showWindow[0] and CHAT_POLL_LINES_OPEN or CHAT_POLL_LINES_CLOSED
    end
    local maxLine = maxLines - 1
    for i = 0, maxLine do
        local line = sampGetChatString(i) or ''
        if line == '' then goto continue end
        local plain = normalizeChatLine(line)
        local key = chatLineSeenKey(line)
        if key == '' then goto continue end
        if chatSeen.lines[key] then goto continue end
        if tryIngestAdminReplyLine(plain) then
            markChatLineSeen(key)
            chatSeen.deferred[key] = nil
            goto continue
        end
        if looksLikeAdminReplyLine(plain) then
            local deferAt = chatSeen.deferred[key]
            if not deferAt then
                chatSeen.deferred[key] = os.clock()
                goto continue
            end
            if os.clock() - deferAt < CHAT_DEFERRED_ADMIN_SEC then
                goto continue
            end
            chatSeen.deferred[key] = nil
            if tryIngestAdminReplyLine(plain) then
                markChatLineSeen(key)
                goto continue
            end
            goto continue
        end
        if settings.profanity_filter_enabled then
            pcall(checkProfanityFromChatLine, plain, key)
        end
        local source = hookActive and 'srv' or 'chat'
        if processChatLineIngest(plain, 0, source, false, line, { delay = 0 }) then
            markChatLineSeen(key)
            chatSeen.deferred[key] = nil
        elseif not tryParseReport(plain)
                and not (type(lineLooksLikeAdminPunishRequest) == 'function'
                    and lineLooksLikeAdminPunishRequest(plain, 0)) then
            markChatLineSeen(key)
        end
        ::continue::
    end
end
