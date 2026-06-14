--[[ Модуль: отправка ans на сервер (wire + echo). ]]

function transmitAnsWire(ansId, body, meta)
    ansId = tonumber(ansId)
    body = normalizeOutboundBody(body)
    if not ansId or body == '' then return false end
    meta = meta or {}

    local nickHint = meta.thread and meta.thread.nick or nil
    if not ansReplyNeedsSplit(ansId, body) then
        if meta.markEcho then
            markOutboundEchoHandled(ansId, body, meta.threadKey, nickHint)
        end
        sendChat(string.format('ans %d %s', ansId, body))
        return true
    end

    local part1, part2 = splitAnsBodyHalves(body)
    if meta.markEcho then
        markOutboundEchoHandled(ansId, part1, meta.threadKey, nickHint)
        markOutboundEchoHandled(ansId, part2, meta.threadKey, nickHint)
    end
    sendChat(string.format('ans %d %s', ansId, part1))
    lua_thread.create(function()
        wait(ANS_SPLIT_DELAY_MS)
        sendChat(string.format('ans %d %s', ansId, part2))
    end)
    return true
end

function sendOutgoingAns(t, text, opts)
    opts = opts or {}
    text = trim(text)
    if not t or text == '' then return false, 'empty' end
    t, threadKey = resolveOutboundThread(t, opts.threadKey)
    if not t or not threadKey then
        return false, 'no thread'
    end
    local ansId, err = resolveAnsIdForReply(t)
    if not ansId then
        if err then say(err) end
        if opts.showSystemOnFail then
            addAutoSystemNote(t, opts.ruleName or '', err or 'fail', 'fail')
        end
        return false, err
    end
    local split = ansReplyNeedsSplit(ansId, text)
    setPendingOutbound(t, text, ansId, split)
    local sent = transmitAnsWire(ansId, text, {
        thread = t,
        threadKey = threadKey,
        markEcho = split,
    })
    if not sent then
        return false, 'chat fail'
    end
    threadApplyOutgoing(t, threadKey, text, { self = true })
    if not split and threadFindOutgoingMessage(t, text, { self = true }) then
        markOutboundEchoHandled(ansId, text, threadKey, t.nick)
    end
    if split then
        return true, '/ans ' .. ansId .. ' (2 \xF7\xE0\xF1\xF2\xE8)'
    end
    return true, '/ans ' .. ansId .. ' ' .. text
end

function tryInterceptSplitAnsCommand(command)
    if type(outbound) ~= 'table' then return false end
    command = trim(command or '')
    if command == '' then return false end
    local id, body = command:match('^/?ans%s+(%d+)%s+(.+)$')
    if not id or not body then return false end
    body = normalizeOutboundBody(body)
    local idNum = tonumber(id)
    if not idNum or not ansReplyNeedsSplit(idNum, body) then return false end

    local liveNick = liveNickForPlayerId(idNum)
    if wasOutboundEchoHandled(idNum, body, liveNick) then
        local echoTk0 = outboundEchoThreadKey(idNum, body, liveNick)
        local th0 = echoTk0 and threads[echoTk0]
        if th0 and threadFindOutgoingMessage(th0, body, { self = true }) then
            return true
        end
    end

    if outbound.pending then
        local p = outbound.pending
        if tonumber(p.id) == idNum and os.clock() - (p.at or 0) < PENDING_OUTBOUND_SEC then
            local pNk = p.nickKey or ''
            local lNk = nickKey(liveNick)
            if pNk == '' or lNk == '' or pNk == lNk then
                return true
            end
        end
    end

    refreshMyNick()
    local t, threadKey = resolveThreadForPlayerId(idNum, liveNick)
    if t and threadKey then
        if not threadFindOutgoingMessage(t, body, { self = true }) then
            threadApplyOutgoing(t, threadKey, body, { self = true })
        end
        setPendingOutbound(t, body, idNum, true)
    end
    transmitAnsWire(idNum, body, { threadKey = threadKey, markEcho = true })
    return true
end

function handleOutgoingAnsCommand(message)
    if type(outbound) ~= 'table' or type(threads) ~= 'table' then return end
    if not message then return end
    message = trim(message)
    local id, body = message:match('^/?ans%s+(%d+)%s+(.+)$')
    if not id or not body then return end
    body = normalizeOutboundBody(body)
    local idNum = tonumber(id)
    if not idNum or body == '' then return end

    local liveNick = liveNickForPlayerId(idNum)

    if outbound.pending then
        local p = outbound.pending
        if tonumber(p.id) == idNum and os.clock() - (p.at or 0) < PENDING_OUTBOUND_SEC then
            local pNk = p.nickKey or ''
            local lNk = nickKey(liveNick)
            if pNk == '' or lNk == '' or pNk == lNk then
                local tk = p.threadKey
                local th = tk and threads[tk]
                local wantBody = normalizeOutboundBody(p.body)
                if th and wantBody ~= '' and not threadFindOutgoingMessage(th, wantBody, { self = true }) then
                    threadApplyOutgoing(th, tk, wantBody, { self = true })
                end
                if th and (wantBody == '' or threadFindOutgoingMessage(th, wantBody, { self = true })) then
                    markOutboundEchoHandled(idNum, body, tk, liveNick)
                end
                if p.split and body ~= wantBody then
                    return
                end
                clearPendingOutbound()
                return
            end
        end
    end

    local echoTk = outboundEchoThreadKey(idNum, body, liveNick)
    if echoTk and threads[echoTk] then
        local th = threads[echoTk]
        if not threadFindOutgoingMessage(th, body, { self = true }) then
            threadApplyOutgoing(th, echoTk, body, { self = true })
        end
        markOutboundEchoHandled(idNum, body, echoTk, liveNick)
        clearPendingOutbound()
        return
    end

    if wasOutboundEchoHandled(idNum, body, liveNick) then
        local echoTk2 = outboundEchoThreadKey(idNum, body, liveNick)
        local th2 = echoTk2 and threads[echoTk2]
        if th2 and threadFindOutgoingMessage(th2, body, { self = true }) then
            return
        end
    end

    refreshMyNick()
    local t, key = resolveThreadForPlayerId(idNum, liveNick)
    if t and key and not threadFindOutgoingMessage(t, body, { self = true }) then
        threadApplyOutgoing(t, key, body, { self = true })
        markOutboundEchoHandled(idNum, body, key, liveNick)
    end
end
