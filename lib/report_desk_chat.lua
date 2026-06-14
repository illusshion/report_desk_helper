--[[ Модуль: UI чата треда, bubbles, composer. ]]
function installProfanityHooks()
    if not sampev then return end
    if deskCache.profHooksInstalled then return end
    deskCache.profHooksInstalled = true
    local prevBubble = sampev.onPlayerChatBubble
    if prevBubble == deskCache.profBubbleHandler then prevBubble = deskCache.hookPrevProfBubble end
    deskCache.hookPrevProfBubble = prevBubble
    deskCache.profBubbleHandler = function(playerId, color, distance, duration, message)
        pcall(checkProfanityFromBubble, playerId, message, color)
        return deskCallHookPrev(prevBubble, playerId, color, distance, duration, message)
    end
    sampev.onPlayerChatBubble = deskCache.profBubbleHandler
    local prevChat = sampev.onChatMessage
    if prevChat == deskCache.profChatHandler then prevChat = deskCache.hookPrevProfChat end
    deskCache.hookPrevProfChat = prevChat
    deskCache.profChatHandler = function(playerId, text)
        if type(adminPunishOnChatMessage) == 'function' then
            pcall(adminPunishOnChatMessage, playerId, text)
        end
        pcall(checkProfanityFromChatMessage, playerId, text)
        if type(prevChat) == 'function' then
            return prevChat(playerId, text)
        end
    end
    sampev.onChatMessage = deskCache.profChatHandler
end

-- Say
function say(text)
    if not isSampAvailable or not isSampAvailable() then return end
    if not sampAddChatMessage then return end
    sampAddChatMessage(MSG_PREFIX .. text, 0xE8E8E8)
end

-- Сообщение в чат при успешной загрузке скрипта.
function announceDeskStartup()
    if not isSampAvailable or not isSampAvailable() then return end
    if not sampAddChatMessage then return end
    local ver = '?.?.?'
    if thisScript and thisScript().version then
        ver = tostring(thisScript().version)
    end
    local msg = '{9E7BEF}[ReportDesk]{FFFFFF} '
        .. '\xD1\xEA\xF0\xE8\xEF\xF2 \xE7\xE0\xE3\xF0\xF3\xE6\xE5\xED. '
        .. '{B0B0B8}\xCE\xE1\xED\xEE\xE2\xEB\xE5\xED\xE8\xE9 \xED\xE5\xF2.{FFFFFF} '
        .. '\xC2\xE5\xF0\xF1\xE8\xFF {9E7BEF}' .. ver
    pcall(sampAddChatMessage, msg, 0xE8E8E8)
end

-- Format Time
function formatTime(ts)
    if not ts then return '' end
    return os.date('%H:%M:%S', ts)
end

-- Format Time Short
function formatTimeShort(ts)
    if not ts then return '' end
    return os.date('%H:%M', ts)
end

-- Format Date Separator
function formatDateSeparator(ts)
    if not ts then return '' end
    local today = os.date('%Y%m%d', os.time())
    local d = os.date('%Y%m%d', ts)
    if d == today then return uiText('\xD1\xE5\xE3\xEE\xE4\xED\xFF') end
    local yday = os.date('%Y%m%d', os.time() - 86400)
    if d == yday then return uiText('\xD2\xF7\xE5\xF0\xE0') end
    return os.date('%d.%m.%Y', ts)
end

-- Message Day Key
function messageDayKey(ts)
    if not ts then return '' end
    return os.date('%Y%m%d', ts)
end

-- Avatar Letter
function avatarLetter(nick)
    nick = trim(nick or '?')
    if nick == '' then return '?' end
    return nick:sub(1, 1)
end

function wrapTextLinesUtf8(text, wrapW)
    text = text or ''
    if text == '' then return {}, imgui.GetTextLineHeight() end
    wrapW = math.max(48, tonumber(wrapW) or 200)
    local lineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
        or imgui.GetTextLineHeight()
    local ioScale = (imgui.GetIO and imgui.GetIO().FontGlobalScale) or 1.0
    if deskCache.wrapTextFontScale ~= ioScale then
        deskCache.wrapTextFontScale = ioScale
        deskCache.wrapTextSpaceW = nil
    end
    if not deskCache.wrapTextSpaceW then
        deskCache.wrapTextSpaceW = imgui.CalcTextSize(' ').x
    end
    local spaceW = deskCache.wrapTextSpaceW
    local lines = {}
    for paragraph in (text .. '\n'):gmatch('(.-)\n') do
        paragraph = trim(paragraph)
        if paragraph == '' then
            lines[#lines + 1] = ''
        else
            local buf, bufW = '', 0
            local function flush()
                if buf ~= '' then
                    lines[#lines + 1] = buf
                    buf, bufW = '', 0
                end
            end
            for word in paragraph:gmatch('%S+') do
                local wW = imgui.CalcTextSize(word).x
                local addW = (buf == '') and wW or (spaceW + wW)
                if buf ~= '' and (bufW + addW) > wrapW then
                    flush()
                    buf, bufW = word, wW
                elseif buf == '' then
                    buf, bufW = word, wW
                else
                    buf = buf .. ' ' .. word
                    bufW = bufW + spaceW + wW
                end
            end
            flush()
        end
    end
    if #lines == 0 then lines[1] = '' end
    return lines, lineH
end

-- Bubble Wrap Layout
function bubbleWrapLayout(m, rawLine, wrapW)
    wrapW = math.max(48, tonumber(wrapW) or 200)
    local src = rawLine or ''
    if m then
        if m._wrapSrc ~= src then
            m._wrapSrc = src
            m._cachedWrapW = nil
            m._cachedLines = nil
        end
        if m._cachedWrapW == wrapW and m._cachedLines then
            local hit = m._cachedLines
            return hit.lines, hit.lineH, hit.w, hit.h
        end
    end
    local display = cp1251ToUtf8(src)
    local lines, lineH = wrapTextLinesUtf8(display, wrapW)
    local w = 0
    for _, ln in ipairs(lines) do
        if ln ~= '' then
            local tw = imgui.CalcTextSize(ln).x
            if tw > w then w = tw end
        end
    end
    local h = math.max(lineH, #lines * lineH)
    if w < 1 then w = 40 end
    if h < lineH then h = lineH end
    if m then
        m._cachedWrapW = wrapW
        m._cachedLines = { lines = lines, lineH = lineH, w = w, h = h }
    end
    return lines, lineH, w, h
end

-- Refresh My Nick
function refreshMyNick()
    if not isSampAvailable() then return end
    local ok, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok and myId and sampIsPlayerConnected(myId) then
        myPlayerNick = trim(sampGetPlayerNickname(myId) or '')
    end
end

-- My Player Id
function getMyPlayerId()
    if not isSampAvailable() then return nil end
    local ok, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if ok and myId ~= nil then return tonumber(myId) end
    return nil
end

-- Is My Admin Reply
function isMyAdminReply(adminNick, adminId)
    refreshMyNick()
    local myId = getMyPlayerId()
    if adminId and myId and tonumber(adminId) == myId then return true end
    if adminNick and myPlayerNick ~= '' and nickKey(adminNick) == nickKey(myPlayerNick) then return true end
    return false
end

-- Normalize Outbound Body
function normalizeOutboundBody(body)
    if type(ensureWireCp1251) == 'function' then
        return ensureWireCp1251(body)
    end
    return trim(body or '')
end

-- Outbound Fingerprint
function outboundFingerprint(nick, body)
    return nickKey(nick) .. '|' .. normalizeOutboundBody(body)
end

-- Outbound Dedup Key
function outboundDedupKey(t, body, opts)
    body = normalizeOutboundBody(body)
    opts = opts or {}
    if opts.self == false and opts.adminNick and trim(opts.adminNick) ~= '' then
        return 'adm|' .. nickKey(opts.adminNick) .. '|' .. body
    end
    if opts.self ~= false then
        local pid = t and tonumber(t.id) or -1
        return 'self|' .. tostring(pid) .. '|' .. outboundFingerprint(t and t.nick or '', body)
    end
    return 'out|' .. outboundFingerprint(t and t.nick or '', body)
end

-- Resolve Outbound Thread
function resolveOutboundThread(t, threadKey)
    if not t then return nil, nil end
    if threadKey and threads[threadKey] == t then
        return t, threadKey
    end
    local sk = threadStorageKey(t)
    if sk and threads[sk] == t then
        return t, sk
    end
    return nil, nil
end

-- Очистка Pending Outbound
function clearPendingOutbound()
    outbound.pending = nil
    outbound.fromDesk = nil
end

-- Outbound Echo Nick Hint
function outboundEchoNickHint(nickHint, threadKey)
    if nickHint and nickHint ~= '' then return nickHint end
    if threadKey and threads[threadKey] then return threads[threadKey].nick end
    return ''
end

-- Outbound Echo Key
function outboundEchoKey(id, body, nickHint)
    local nk = nickKey(outboundEchoNickHint(nickHint, nil))
    return tostring(tonumber(id) or id or '') .. '|' .. nk .. '|' .. normalizeOutboundBody(body)
end

-- Mark Outbound Echo Handled
function markOutboundEchoHandled(id, body, threadKey, nickHint)
    nickHint = outboundEchoNickHint(nickHint, threadKey)
    local key = outboundEchoKey(id, body, nickHint)
    if key == '' or key:find('||', 1, true) then return end
    outbound.echo[key] = {
        at = os.clock(),
        threadKey = threadKey,
        nickKey = nickKey(nickHint),
    }
end

-- Was Outbound Echo Handled
function wasOutboundEchoHandled(id, body, nickHint)
    local key = outboundEchoKey(id, body, nickHint)
    local e = outbound.echo[key]
    if not e then return false end
    if os.clock() - (e.at or 0) > PENDING_OUTBOUND_SEC then
        outbound.echo[key] = nil
        return false
    end
    return true
end

-- Outbound Echo Thread Key
function outboundEchoThreadKey(id, body, nickHint)
    local e = outbound.echo[outboundEchoKey(id, body, nickHint)]
    if e and e.threadKey and threads[e.threadKey] then
        return e.threadKey
    end
    return nil
end

-- Set Pending Outbound
function setPendingOutbound(t, body, ansId, split)
    if not t then
        clearPendingOutbound()
        return
    end
    body = normalizeOutboundBody(body)
    local key = threadStorageKey(t)
    outbound.pending = {
        threadKey = key,
        body = body,
        id = tonumber(ansId),
        nickKey = nickKey(t.nick),
        at = os.clock(),
        split = split and true or false,
    }
    outbound.fromDesk = outboundFingerprint(t.nick, body)
end

-- Thread Storage Key
function threadStorageKey(t)
    if not t then return nil end
    local key = t._storageKey
    if key and threads[key] == t then return key end
    local nk = findThreadKeyByNick(t.nick)
    if nk and threads[nk] == t then
        t._storageKey = nk
        return nk
    end
    for k, th in pairs(threads) do
        if th == t then
            t._storageKey = k
            return k
        end
    end
    return nil
end

-- Outbound Message Author Key
function outboundMessageAuthorKey(m)
    if not m then return '' end
    if m.self == true then return 'self' end
    return 'adm:' .. nickKey(m.adminNick or '?')
end

-- Outbound Opts Author Key
function outboundOptsAuthorKey(opts)
    opts = opts or {}
    if opts.self ~= false then return 'self' end
    return 'adm:' .. nickKey(opts.adminNick or '?')
end

-- Outbound Same Author
function outboundSameAuthor(m, opts)
    return outboundMessageAuthorKey(m) == outboundOptsAuthorKey(opts)
end

-- Thread Find Outgoing Message
function threadFindOutgoingMessage(t, body, opts)
    body = normalizeOutboundBody(body)
    if body == '' or not t or not t.messages then return nil end
    local wantAuthor = outboundOptsAuthorKey(opts)
    local scanned = 0
    for i = #t.messages, 1, -1 do
        local m = t.messages[i]
        if m.dir == 'out' and normalizeOutboundBody(m.text) == body then
            if outboundSameAuthor(m, opts) then
                return m, i
            end
        end
        scanned = scanned + 1
        if scanned >= OUTBOUND_SCAN_MAX then break end
    end
    return nil
end

-- Thread Apply Outgoing
function threadApplyOutgoing(t, threadKey, body, opts)
    opts = opts or {}
    body = normalizeOutboundBody(body)
    t, threadKey = resolveOutboundThread(t, threadKey)
    if body == '' or not t or not threadKey then
        return false
    end

    local existing = threadFindOutgoingMessage(t, body, opts)
    if existing then
        if opts.self and not existing.self then
            existing.self = true
            existing.adminNick = nil
            existing.kind = 'reply_self'
            markThreadAnswered(t)
        elseif opts.self == false and opts.adminNick then
            if not existing.adminNick or existing.adminNick == '' then
                existing.adminNick = opts.adminNick
            end
            existing.kind = 'reply'
            existing.self = false
        end
        return false
    end

    local fp = outboundDedupKey(t, body, opts)
    local now = os.clock()
    if RECENT.out[fp] and (now - RECENT.out[fp]) < OUTBOUND_DEDUP_SEC then
        -- Dedup только если bubble ещё в треде; иначе stale после trim/гонки poll.
        if threadFindOutgoingMessage(t, body, opts) then
            return false
        end
    end
    touchTimedMap(RECENT.out, RECENT.outOrd, fp)

    local outMsg = {
        dir = 'out',
        kind = opts.self ~= false and 'reply_self' or 'reply',
        text = body,
        ts = os.time(),
        self = opts.self ~= false,
    }
    if opts.self == false and trim(opts.adminNick or '') ~= '' then
        outMsg.adminNick = opts.adminNick
    end
    addMessageToKey(threadKey, outMsg)
    markThreadAnswered(t)
    return true
end

-- Append Outgoing Message
function appendOutgoingMessage(t, body, opts)
    if not t then return false end
    local key = threadStorageKey(t)
    if not key or not threads[key] then return false end
    return threadApplyOutgoing(t, key, body, opts)
end

local AUTO_RULE_LABELS = {
    time = '\xC2\xF0\xE5\xEC\xFF',
    GG = 'GG',
}

-- Auto Rule Display Name
function autoRuleDisplayName(ruleName)
    ruleName = trim(ruleName or '')
    if ruleName == '' then return '?' end
    return AUTO_RULE_LABELS[ruleName] or ruleName
end

-- Human-readable auto-reply note (legacy auto: … → /ans … тоже нормализуется).
function formatAutoSystemDisplay(m)
    if type(m) ~= 'table' then return '' end
    local note = trim(m.note or '')
    if m.autoStatus and note ~= '' then return note end
    local rule, rest = note:match('^auto:%s*(.-)%s*\xE2\x86\x92%s*(.+)$')
    if rule then
        rest = trim(rest)
        if rest:match('^/ans') or rest:match('^/ ') then
            return string.format('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2 \xAB%s\xBB', autoRuleDisplayName(rule))
        end
        if rest:find('\xEE\xE6\xE8\xE4\xE0\xE5\xF2', 1, true) then
            return string.format(
                '\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2 \xAB%s\xBB \xE2\xEE\xE6\xE4\xE0\xE5\xF2 \xEF\xEE\xE4\xF2\xE2\xE5\xF0\xE6\xE4\xE5\xED\xE8\xFF',
                autoRuleDisplayName(rule))
        end
        return string.format('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2 \xAB%s\xBB \xE2\x80\x94 %s', autoRuleDisplayName(rule), rest)
    end
    return note
end

-- Format Auto System Line
function formatAutoSystemLine(ruleName, detail, status)
    local label = autoRuleDisplayName(ruleName)
    if status == 'pending' then
        return string.format(
            '\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2 \xAB%s\xBB \xE2\xEE\xE6\xE4\xE0\xE5\xF2 \xEF\xEE\xE4\xF2\xE2\xE5\xF0\xE6\xE4\xE5\xED\xE8\xFF',
            label)
    end
    if status == 'fail' then
        detail = trim(tostring(detail or ''))
        if detail == '' or detail:match('^/ans') or detail:match('^/ ') then
            detail = '\xED\xE5 \xEE\xF2\xEF\xF0\xE0\xE2\xEB\xE5\xED\xEE'
        end
        return string.format('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2 \xAB%s\xBB \xE2\x80\x94 %s', label, detail)
    end
    return string.format('\xC0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2 \xAB%s\xBB', label)
end

-- Add Auto System Note
function addAutoSystemNote(t, ruleName, detail, status)
    if not t then return end
    status = status or 'info'
    local key = findThreadKeyByNick(t.nick) or nickKey(t.nick)
    addMessageToKey(key, {
        dir = 'system',
        text = '',
        autoRule = ruleName,
        autoStatus = status,
        note = formatAutoSystemLine(ruleName, detail, status),
        ts = os.time(),
    })
end

-- Estimate Ans Chat Line Len
function estimateAnsChatLineLen(ansId, body)
    ansId = tonumber(ansId) or 0
    body = tostring(body or '')
    local adminNick, adminId = '?', 0
    pcall(function()
        if sampGetPlayerIdByCharHandle and PLAYER_PED and doesCharExist(PLAYER_PED) then
            local ok, pid = sampGetPlayerIdByCharHandle(PLAYER_PED)
            if ok and pid and sampGetPlayerNickname then
                adminId = pid
                adminNick = sampGetPlayerNickname(pid) or '?'
            end
        end
    end)
    local targetNick = '?'
    pcall(function()
        if sampIsPlayerConnected and sampIsPlayerConnected(ansId) and sampGetPlayerNickname then
            targetNick = sampGetPlayerNickname(ansId) or '?'
        end
    end)
    local prefix = string.format(
        '\xC0\xE4\xEC\xE8\xED\xE8\xF1\xF2\xF0\xE0\xF2\xEE\xF0 %s[%d] \xE4\xEB\xFF %s[%d]: ',
        adminNick, adminId, targetNick, ansId
    )
    return #prefix + #body
end

-- Split Ans Body Halves
function splitAnsBodyHalves(body)
    body = tostring(body or '')
    if body == '' then return body, '' end
    if isUtf8Text(body) then
        local chars = {}
        for ch in body:gmatch('[\1-\127\194-\244][\128-\191]*') do
            chars[#chars + 1] = ch
        end
        if #chars < 2 then return body .. '...', '' end
        local half = math.floor(#chars / 2)
        local p1, p2 = {}, {}
        for i = 1, half do p1[#p1 + 1] = chars[i] end
        for i = half + 1, #chars do p2[#p2 + 1] = chars[i] end
        return table.concat(p1) .. '...', table.concat(p2)
    end
    local half = math.floor(#body / 2)
    return body:sub(1, half) .. '...', body:sub(half + 1)
end

-- Разбиение длинного ans
function ansReplyNeedsSplit(ansId, body)
    return estimateAnsChatLineLen(ansId, body) > ANS_CHAT_LINE_MAX
end

-- Отправка ans на сервер
-- Отправка команды/сообщения на сервер.
-- Measure Bubble Text
function measureBubbleText(line, wrapInnerW, msg)
    local _, _, w, h = bubbleWrapLayout(msg, line, wrapInnerW)
    return w, h
end

-- Wrap Text Lines
function wrapTextLines(text, wrapW)
    return wrapTextLinesUtf8(cp1251ToUtf8(text or ''), wrapW)
end

-- Draw Bubble Body Text
function drawBubbleBodyText(dl, x, y, wrapW, line, fg, msg)
    local lines, lineH = bubbleWrapLayout(msg, line, wrapW)
    local cy = y
    for _, ln in ipairs(lines) do
        if ln ~= '' then
            dl:AddText(imgui.ImVec2(x, cy), toU32(fg), ln)
        end
        cy = cy + lineH
    end
    return cy - y
end

-- Finish Chat Message Row
function finishChatMessageRow(localX, localY, blockH, rowW)
    imgui.SetCursorPos(imgui.ImVec2(localX, localY))
    imgui.Dummy(imgui.ImVec2(rowW, blockH))
end

-- Seal Chat Message Row
function sealChatMessageRow(localX, localY, blockH)
    imgui.SetCursorPos(imgui.ImVec2(localX, localY + blockH))
end

-- Mark Thread Answered
function markThreadAnswered(t)
    if not t then return end
    local u = t.unread or 0
    if u <= 0 then return end
    totalUnread = math.max(0, totalUnread - u)
    t.unread = 0
    markDirtyThreads()
end
