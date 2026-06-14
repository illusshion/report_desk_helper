--[[ Модуль: фильтр мата, парсинг чата, hooks. ]]
function rebuildProfanityNorm()
    deskCache.profNorm = {}
    deskCache.profSet = {}
    for _, w in ipairs(profanity_words) do
        local kw = normalizeProfanityText(w)
        if kw ~= '' and #kw >= PF.MIN_WORD_LEN and not deskCache.profSet[kw] then
            deskCache.profSet[kw] = true
            deskCache.profNorm[#deskCache.profNorm + 1] = { norm = kw }
        end
    end
end

-- Reload Profanity Words From Dict
function reloadProfanityWordsFromDict()
    package.loaded[PROFANITY_DICT_MODULE] = nil
    local ok, data = pcall(require, PROFANITY_DICT_MODULE)
    if not ok or type(data) ~= 'table' then
        print('[Report Desk] profanity dict: ' .. tostring(data))
        profanity_words = {}
    else
        profanity_words = cloneProfanityWords(data, true)
    end
    rebuildProfanityNorm()
    return #profanity_words
end

-- Normalize Profanity Text
function normalizeProfanityText(s)
    s = trim(stripTags(s or ''))
    if s == '' then return '' end
    if s:find('[\208-\209][\128-\191]') then
        local ok, conv = pcall(utf8ToCp1251, s)
        if ok and conv and conv ~= '' then s = conv end
    end
    return normalizeMatchText(s)
end

-- Roleplay Body Prefix
function stripRoleplayBodyPrefix(body)
    body = trim(body or '')
    body = body:gsub('^%*+%s*', '')
    body = body:gsub('^/me%s+', '', 1)
    body = body:gsub('^/do%s+', '', 1)
    body = body:gsub('^/try%s+', '', 1)
    body = body:gsub('^/todo%s+', '', 1)
    return trim(body)
end

-- Body Looks Like Roleplay Cmd
function bodyLooksLikeRoleplayCmd(body)
    body = trim(body or '')
    if body == '' then return false end
    return body:match('^%*+%s*') ~= nil
        or body:match('^/me%s') ~= nil
        or body:match('^/do%s') ~= nil
        or body:match('^/try%s') ~= nil
        or body:match('^/todo%s') ~= nil
end

-- Body Looks Like System Chat
function bodyLooksLikeSystemChat(body)
    body = trim(body or '')
    if body == '' then return true end
    if body:match('^[>|]') then return true end
    if body:match('^{[%x%x]+}') then return true end
    if body:match('^%d+%s*lvl') then return true end
    if body:match('^PING%s') then return true end
    if body:match('^Voice') then return true end
    return false
end

-- Ooc Chat Wrapper
function stripOocChatWrapper(text)
    text = trim(text or '')
    local inner = text:match('^%(%(%s*(.-)%s*%)%)$')
    if inner then return trim(inner), true end
    return text, false
end

-- Resolve Profanity Player Id
function resolveProfanityPlayerId(nick, id)
    id = tonumber(id)
    if id and id >= 0 and id <= MAX_PLAYER_ID then return id end
    if nick and nick ~= '' then
        local live = findPlayerIdByNick(nick)
        if live ~= nil then return live end
    end
    return 0
end

-- Classify Roleplay Body
function classifyRoleplayBody(body)
    body = trim(body or '')
    if body == '' then return 'say', body end
    if body:match('^/do%s') then
        return 'do', stripRoleplayBodyPrefix(body)
    end
    if bodyLooksLikeRoleplayCmd(body) then
        return 'me', stripRoleplayBodyPrefix(body)
    end
    return nil, body
end

-- Profanity Channel Label
function profanityChannelLabel(tag)
    tag = trim(tostring(tag or '')):upper()
    if tag == '' then return '\xD7\xE0\xF2' end
    if tag == 'J' then return '\xD0\xE0\xF6\xE8\xFF' end
    if tag == 'G' then return '\xD7\xE0\xF2' end
    if tag == 'V' then return 'VIP' end
    if tag == 'PC' then return 'PC' end
    if tag == 'S' then return 'S' end
    if tag == 'M' then return 'M' end
    return '[' .. tag .. ']'
end

-- Profanity Source From Parse
function profanitySourceFromParse(kind, channelTag)
    kind = tostring(kind or '')
    if kind == 'me' then return 'me' end
    if kind == 'do' then return 'do' end
    channelTag = trim(tostring(channelTag or ''))
    if channelTag ~= '' then
        return 'ch_' .. channelTag:upper()
    end
    return 'chat'
end

-- Парсинг данных с сервера/чата.
function parseProfanityNickIdSay(text)
    if not text or text == '' then return nil end
    local nick, id, body = text:match('([%w][%w_]*)%[(%d+)%]%s*:%s*(.+)$')
    if nick and isValidPlayerNick(trim(nick)) then
        return trim(nick), tonumber(id), trim(body)
    end
    return nil
end

-- Парсинг данных с сервера/чата.
function parseArpRoleplayLine(text)
    if not text or text == '' then return nil end
    text = trim(text)
    local body, nick, id = text:match('^%-%s*(.+)%s+%(([%w][%w_]*)%)%[(%d+)%]%s*$')
    if nick and body and isValidPlayerNick(trim(nick)) then
        return trim(nick), tonumber(id), trim(body), 'me'
    end
    body, nick, id = text:match('^%*%s*(.+)%s+%(([%w][%w_]*)%)%[(%d+)%]%s*$')
    if nick and body and isValidPlayerNick(trim(nick)) then
        return trim(nick), tonumber(id), trim(body), 'do'
    end
    return nil
end

-- Парсинг данных с сервера/чата.
function parseProfanityLineBody(text)
    if not text or text == '' then return nil end
    text = trim(text)

    local arpNick, arpId, arpBody, arpKind = parseArpRoleplayLine(text)
    if arpNick then
        return arpNick, arpId, arpBody, arpKind
    end

    local nick, id, body = parseProfanityNickIdSay(text)
    if nick then
        return nick, id, body, 'say'
    end

    nick, id, body = text:match('^([%w][%w_]*)%[(%d+)%]%s+(.+)$')
    if nick and body and isValidPlayerNick(trim(nick)) then
        nick = trim(nick)
        body = trim(body)
        if body:sub(1, 1) == ':' then
            body = trim(body:sub(2))
        end
        if body ~= '' then
            local rpKind, rpBody = classifyRoleplayBody(body)
            if rpKind then
                return nick, tonumber(id), rpBody, rpKind
            end
            return nick, tonumber(id), body, 'say'
        end
    end

    nick, body = text:match('^([%w][%w_]*)%s*:%s*(.+)$')
    if nick and body and isValidPlayerNick(trim(nick)) then
        body = trim(body)
        local rpKind, rpBody = classifyRoleplayBody(body)
        if rpKind then
            return trim(nick), findPlayerIdByNick(nick), rpBody, rpKind
        end
        return trim(nick), findPlayerIdByNick(nick), body, 'say'
    end

    return nil
end

-- Парсинг данных с сервера/чата.
function parsePlayerChatLine(text)
    if not text or text == '' then return nil end
    text = stripChatTimestamp(stripTags(text))
    if isExcludedChatLine(text) then return nil end

    text = stripOocChatWrapper(text)

    local channelTag = nil
    local tag, rest = text:match('^%[([^%]]+)%]%s*(.+)$')
    if tag and rest then
        local tagUp = trim(tag):upper()
        if tagUp == 'A' or tagUp == 'SP' then return nil end
        channelTag = tagUp
        text = trim(rest)
        if text == '' then return nil end
    end

    local nick, id, body, kind = parseProfanityLineBody(text)
    if not nick or not body or body == '' then return nil end
    id = resolveProfanityPlayerId(nick, id)
    return nick, id, body, kind, channelTag
end

-- Profanity Source From Chat Kind
function profanitySourceFromChatKind(kind, channelTag)
    return profanitySourceFromParse(kind, channelTag)
end

-- Profanity Mark Line Seen
function profanityMarkLineSeen(lineKey)
    lineKey = trim(tostring(lineKey or ''))
    if lineKey ~= '' then deskCache.profLineSeen[lineKey] = true end
end

-- Profanity Is Line Seen
function profanityIsLineSeen(lineKey)
    lineKey = trim(tostring(lineKey or ''))
    return lineKey ~= '' and deskCache.profLineSeen[lineKey] == true
end

-- Seed Profanity Seen For Chat Buffer
function seedProfanitySeenForChatBuffer()
    if not sampGetChatString then return end
    for i = 0, CHAT_POLL_LINES_OPEN - 1 do
        local line = sampGetChatString(i) or ''
        if line ~= '' then
            profanityMarkLineSeen(chatLineSeenKey(line))
        end
    end
end

-- Profanity Skip Channel Report
local function profanitySkipChannelReport(plain)
    local ev = deskIngest.tryParseChatEvent(plain, { chatStrictReports = true })
    return ev and ev.type == 'player_report'
end

-- Check Profanity From Chat Line
function checkProfanityFromChatLine(plain, lineKey)
    if not settings.profanity_filter_enabled then return end
    lineKey = trim(tostring(lineKey or ''))
    if lineKey ~= '' and profanityIsLineSeen(lineKey) then return end
    if deskIngest and deskIngest.looksLikePlayerStatusLine
            and deskIngest.looksLikePlayerStatusLine(plain) then
        if lineKey ~= '' then profanityMarkLineSeen(lineKey) end
        return
    end
    -- [PC]/[S]/[M] репорты — только onIncomingReport + findProfanityMatch
    if profanitySkipChannelReport(plain) then return end
    local nick, id, body, kind, channelTag = parsePlayerChatLine(plain)
    if nick and body then
        checkProfanityFromPlayer(nick, id, body, profanitySourceFromParse(kind, channelTag), lineKey, { logChat = false })
    end
end

-- Check Profanity Outgoing
function checkProfanityOutgoing(message)
    if not settings.profanity_filter_enabled then return end
    message = trim(message or '')
    if message == '' then return end
    if not isSampAvailable() then return end
    refreshMyNick()
    local ok, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
    if not ok or myId == nil then return end
    local nick = trim(myPlayerNick or '')
    if nick == '' then nick = trim(sampGetPlayerNickname(myId) or '') end
    if nick == '' then return end
    checkProfanityFromPlayer(nick, myId, message, 'chat_out')
end

-- Clone Profanity Words
function cloneProfanityWords(src, fromUtf8)
    local out = {}
    for i, w in ipairs(src or {}) do
        local part = trim(normalizeStoredText(w, fromUtf8))
        if part ~= '' then out[#out + 1] = part end
    end
    return out
end

-- Find Profanity Match
function findProfanityMatch(body)
    if not body or body == '' then return nil end
    local set = deskCache.profSet
    if not set or not next(set) then return nil end
    local msg = normalizeProfanityText(body)
    if msg == '' then return nil end
    if set[msg] then return true end
    for token in msg:gmatch('%S+') do
        local t = normalizeMatchText(token)
        t = t:gsub('^%*+', '')
        if t ~= '' and set[t] then return true end
    end
    return nil
end

-- Should Skip Profanity Player
function shouldSkipProfanityPlayer(nick)
    nick = trim(nick or '')
    return nick == ''
end

-- Is Duplicate Profanity Alert
function isDuplicateProfanityAlert(nick, body)
    local key = nickKey(nick) .. '|' .. normalizeMatchText(body)
    if key == '|' then return false end
    local prev = RECENT.prof[key]
    if prev and (os.clock() - prev) < PF.DEDUP_SEC then return true end
    return false
end

-- Mark Profanity Alert Seen
function markProfanityAlertSeen(nick, body)
    local key = nickKey(nick) .. '|' .. normalizeMatchText(body)
    if key ~= '|' then
        touchTimedMap(RECENT.prof, RECENT.profOrd, key)
    end
end

-- Check Profanity From Player
function checkProfanityFromPlayer(nick, id, body, source, lineKey, opts)
    opts = type(opts) == 'table' and opts or {}
    local mirrorChat = opts.logChat == true and settings.remote_chat_samp_mirror ~= false
    local profEnabled = settings.profanity_filter_enabled ~= false
    if not mirrorChat and not profEnabled then return end
    if shouldSkipProfanityPlayer(nick) then return end
    body = trim(stripTags(body or ''))
    if body == '' then return end
    if bodyLooksLikeSystemChat(body) then return end
    if deskIngest and deskIngest.looksLikePlayerStatusBody
            and deskIngest.looksLikePlayerStatusBody(body) then
        return
    end

    lineKey = trim(tostring(lineKey or ''))
    if lineKey ~= '' and profEnabled and profanityIsLineSeen(lineKey) then return end

    local hasProf = false
    if profEnabled then
        hasProf = findProfanityMatch(body) ~= nil
        if lineKey ~= '' then profanityMarkLineSeen(lineKey) end
        if hasProf and not isDuplicateProfanityAlert(nick, body) then
            markProfanityAlertSeen(nick, body)
            playProfanityAlertSound()
            if settings.profanity_filter_chat then
                local preview = body
                if #preview > 96 then preview = preview:sub(1, 93) .. '...' end
                local line = string.format(
                    '%s%s[%d]: %s',
                    PROFANITY_MSG_PREFIX, nick, tonumber(id) or 0, preview
                )
                sampAddChatMessage(line, PF.ALERT_COLOR)
            end
            if settings.debug then
                print('[Report Desk] profanity: ' .. nick .. ' msg="' .. body:sub(1, 48) .. '"')
            end
        end
    end

    if mirrorChat and type(remoteChatTryAppend) == 'function' then
        pcall(remoteChatTryAppend, nick, id, body, source, lineKey, hasProf,
            opts.bubbleColor, opts.embedHex)
    end
end

-- Check Profanity From Chat Message
function checkProfanityFromChatMessage(playerId, text)
    if not isSampAvailable() then return end
    playerId = tonumber(playerId)
    if playerId == nil or playerId < 0 then return end
    if not sampIsPlayerConnected(playerId) then return end
    local nick = trim(sampGetPlayerNickname(playerId) or '')
    if nick == '' then return end
    local body = trim(text or '')
    local source = 'chat'
    local rpKind, rpBody = classifyRoleplayBody(body)
    if rpKind then
        source = rpKind
        body = rpBody
    end
    checkProfanityFromPlayer(nick, playerId, body, source, nil, { logChat = false })
end

-- Check Profanity From Bubble
function checkProfanityFromBubble(playerId, message, bubbleColor)
    if type(logBubbleColor) == 'function' then
        pcall(logBubbleColor, playerId, message, bubbleColor)
    end
    if not isSampAvailable() then return end
    playerId = tonumber(playerId)
    if playerId == nil or playerId < 0 then return end
    if not sampIsPlayerConnected(playerId) then return end
    if type(remoteChatNormalizeBubbleColor) == 'function' then
        bubbleColor = remoteChatNormalizeBubbleColor(bubbleColor)
    elseif type(normColor) == 'function' then
        bubbleColor = normColor(bubbleColor)
    end
    local nick = trim(sampGetPlayerNickname(playerId) or '')
    if nick == '' then return end
    local raw = trim(message or '')
    local embedHex
    if type(remoteChatExtractLeadingEmbed) == 'function' then
        embedHex, raw = remoteChatExtractLeadingEmbed(raw)
    end
    local body = raw
    local source = 'bubble'
    if body:match('^/do%s') then
        source = 'do'
        body = stripRoleplayBodyPrefix(body)
    elseif body:match('^/me%s') or bodyLooksLikeRoleplayCmd(body) then
        source = 'me'
        body = stripRoleplayBodyPrefix(body)
    else
        body = stripRoleplayBodyPrefix(body)
    end
    if body == '' then return end
    if deskIngest and deskIngest.looksLikePlayerStatusBody
            and deskIngest.looksLikePlayerStatusBody(body) then
        return
    end
    if REMOTE_CHAT_FILTER_AUTO ~= false and type(remoteChatLooksLikeAutoAction) == 'function'
            and remoteChatLooksLikeAutoAction(body) then
        return
    end
    checkProfanityFromPlayer(nick, playerId, body, source, nil, {
        logChat = true,
        bubbleColor = bubbleColor,
        embedHex = embedHex,
    })
end
