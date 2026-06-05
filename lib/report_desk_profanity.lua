--[[ Report Desk profanity filter ]]
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

function normalizeProfanityText(s)
    s = trim(stripTags(s or ''))
    if s == '' then return '' end
    if s:find('[\208-\209][\128-\191]') then
        local ok, conv = pcall(utf8ToCp1251, s)
        if ok and conv and conv ~= '' then s = conv end
    end
    return normalizeMatchText(s)
end

function stripRoleplayBodyPrefix(body)
    body = trim(body or '')
    body = body:gsub('^%*+%s*', '')
    body = body:gsub('^/me%s+', '', 1)
    body = body:gsub('^/do%s+', '', 1)
    body = body:gsub('^/try%s+', '', 1)
    body = body:gsub('^/todo%s+', '', 1)
    return trim(body)
end

function bodyLooksLikeRoleplayCmd(body)
    body = trim(body or '')
    if body == '' then return false end
    return body:match('^%*+%s*') ~= nil
        or body:match('^/me%s') ~= nil
        or body:match('^/do%s') ~= nil
        or body:match('^/try%s') ~= nil
        or body:match('^/todo%s') ~= nil
end

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

function stripOocChatWrapper(text)
    text = trim(text or '')
    local inner = text:match('^%(%(%s*(.-)%s*%)%)$')
    if inner then return trim(inner), true end
    return text, false
end

function resolveProfanityPlayerId(nick, id)
    id = tonumber(id)
    if id and id >= 0 and id <= MAX_PLAYER_ID then return id end
    if nick and nick ~= '' then
        local live = findPlayerIdByNick(nick)
        if live ~= nil then return live end
    end
    return 0
end

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

function parseProfanityNickIdSay(text)
    if not text or text == '' then return nil end
    local nick, id, body = text:match('([%w][%w_]*)%[(%d+)%]%s*:%s*(.+)$')
    if nick and isValidPlayerNick(trim(nick)) then
        return trim(nick), tonumber(id), trim(body)
    end
    return nil
end

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

function profanitySourceFromChatKind(kind, channelTag)
    return profanitySourceFromParse(kind, channelTag)
end

function profanityMarkLineSeen(lineKey)
    lineKey = trim(tostring(lineKey or ''))
    if lineKey ~= '' then deskCache.profLineSeen[lineKey] = true end
end

function profanityIsLineSeen(lineKey)
    lineKey = trim(tostring(lineKey or ''))
    return lineKey ~= '' and deskCache.profLineSeen[lineKey] == true
end

function seedProfanitySeenForChatBuffer()
    if not sampGetChatString then return end
    for i = 0, CHAT_POLL_LINES_OPEN - 1 do
        local line = sampGetChatString(i) or ''
        if line ~= '' then
            profanityMarkLineSeen(chatLineSeenKey(line))
        end
    end
end

function checkProfanityFromChatLine(plain, lineKey)
    if not settings.profanity_filter_enabled then return end
    lineKey = trim(tostring(lineKey or ''))
    if lineKey ~= '' and profanityIsLineSeen(lineKey) then return end
    -- [PC]/[S]/[M] репорты — только onIncomingReport + findProfanityMatch
    if tryParseReport(plain) then return end
    local nick, id, body, kind, channelTag = parsePlayerChatLine(plain)
    if nick and body then
        checkProfanityFromPlayer(nick, id, body, profanitySourceFromParse(kind, channelTag), lineKey)
    end
end

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

function cloneProfanityWords(src, fromUtf8)
    local out = {}
    for i, w in ipairs(src or {}) do
        local part = trim(normalizeStoredText(w, fromUtf8))
        if part ~= '' then out[#out + 1] = part end
    end
    return out
end

function profanityPreviewText(text, maxLen)
    text = trim(stripTags(text or ''))
    maxLen = maxLen or PF.BODY_PREVIEW
    if #text <= maxLen then return text end
    return text:sub(1, maxLen - 3) .. '...'
end

function pruneProfanityToasts()
    local now = os.clock()
    local out = {}
    for _, t in ipairs(deskCache.profToasts) do
        if t.expires and t.expires > now then
            out[#out + 1] = t
        end
    end
    deskCache.profToasts = out
end

function profanityToastOrg(id)
    if not deskSpectateStats.getEntry then return '' end
    local e = deskSpectateStats.getEntry(tonumber(id) or -1)
    if not e or not e.fields then return '' end
    local org = trim(e.fields.org or '')
    if org == '' or org == '-' or org == '\xCD\xE5\xF2' then return '' end
    return org
end

function profanityToastNickColor(id)
    id = tonumber(id) or -1
    if id >= 0 and deskSpectateStats.getEntry and deskSpectateStats.nickColorFor then
        local e = deskSpectateStats.getEntry(id)
        if e then
            return deskSpectateStats.nickColorFor(id, e)
        end
        if isSampAvailable() and sampIsPlayerConnected(id) then
            return deskSpectateStats.nickColorFor(id, { fields = {} })
        end
    end
    return col_label
end

function profanityChannelMeta(source, body, channelTag)
    source = tostring(source or '')
    body = trim(body or '')
    channelTag = trim(tostring(channelTag or ''))
    if channelTag == '' then
        local fromSrc = source:match('^ch_(.+)$')
        if fromSrc then channelTag = fromSrc end
    end
    if source == 'bubble' or source == 'me' then
        return '/me', imgui.ImVec4(0.68, 0.54, 0.82, 1.0)
    end
    if source == 'do' then
        return '/do', imgui.ImVec4(0.62, 0.52, 0.78, 1.0)
    end
    if source == 'chat_out' then
        return '\xC2\xFB', col_muted2
    end
    if source == 'live' or source == 'report' then
        return '\xD0\xE5\xEF\xEE\xF0\xF2', col_accent
    end
    if channelTag ~= '' then
        return profanityChannelLabel(channelTag), imgui.ImVec4(0.92, 0.62, 0.38, 1.0)
    end
    return '\xD7\xE0\xF2', imgui.ImVec4(0.48, 0.62, 0.92, 1.0)
end

function profanitySourceLabel(source, body, channelTag)
    local label = profanityChannelMeta(source, body, channelTag)
    return label
end

function profanityColAlpha(col, alpha)
    alpha = alpha or 1
    if not col then return imgui.ImVec4(1, 1, 1, alpha) end
    return imgui.ImVec4(col.x, col.y, col.z, (col.w or 1) * alpha)
end

function profanityDlText(dl, x, y, col, text, alpha)
    if not dl or not text or text == '' then return end
    local str = catalogWarmupDlUtf(text)
    dl:AddText(imgui.ImVec2(x, y), toU32(profanityColAlpha(col, alpha)), str)
end

function profanityDrawChannelPill(dl, x, y, label, col, alpha)
    label = label or ''
    local str = catalogWarmupDlUtf(label)
    if str == '' then return 0, 0 end
    local ts = imgui.CalcTextSize(str)
    local pw, ph = ts.x + 14, ts.y + 6
    local bg = profanityColAlpha(col, 0.18 * (alpha or 1))
    local br = profanityColAlpha(col, 0.45 * (alpha or 1))
    dl:AddRectFilled(imgui.ImVec2(x, y), imgui.ImVec2(x + pw, y + ph), toU32(bg), 7)
    dl:AddRect(imgui.ImVec2(x, y), imgui.ImVec2(x + pw, y + ph), toU32(br), 7, 0, 1)
    profanityDlText(dl, x + 7, y + 3, col, label, alpha)
    return pw, ph
end

function pushProfanityToast(nick, id, body, source)
    pruneProfanityToasts()
    body = trim(stripTags(body or ''))
    local chTag = tostring(source or ''):match('^ch_(.+)$')
    local channelLabel, channelCol = profanityChannelMeta(source, body, chTag)
    local entry = {
        nick = nick or '?',
        id = tonumber(id) or 0,
        body = body,
        source = source,
        channel = channelLabel,
        channelCol = channelCol,
        org = profanityToastOrg(id),
        nickCol = profanityToastNickColor(id),
        expires = os.clock() + PF.TOAST_TTL,
    }
    deskCache.profToasts[#deskCache.profToasts + 1] = entry
    while #deskCache.profToasts > PF.TOAST_MAX do
        table.remove(deskCache.profToasts, 1)
    end
end

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

function shouldSkipProfanityPlayer(nick)
    nick = trim(nick or '')
    return nick == ''
end

function isDuplicateProfanityAlert(nick, body)
    local key = nickKey(nick) .. '|' .. normalizeMatchText(body)
    if key == '|' then return false end
    local prev = RECENT.prof[key]
    if prev and (os.clock() - prev) < PF.DEDUP_SEC then return true end
    return false
end

function markProfanityAlertSeen(nick, body)
    local key = nickKey(nick) .. '|' .. normalizeMatchText(body)
    if key ~= '|' then
        touchTimedMap(RECENT.prof, RECENT.profOrd, key)
    end
end

function notifyProfanityOnce(nick, id, body, source, lineKey)
    if not settings.profanity_filter_enabled then return false end
    if shouldSkipProfanityPlayer(nick) then return false end
    body = trim(stripTags(body or ''))
    if body == '' then return false end
    lineKey = trim(tostring(lineKey or ''))
    if lineKey ~= '' and profanityIsLineSeen(lineKey) then return false end
    if isDuplicateProfanityAlert(nick, body) then return false end
    markProfanityAlertSeen(nick, body)
    if lineKey ~= '' then profanityMarkLineSeen(lineKey) end

    id = tonumber(id) or 0
    pushProfanityToast(nick, id, body, source)
    playProfanityAlertSound()

    if settings.profanity_filter_chat then
        local preview = profanityPreviewText(body, 96)
        local channel = profanitySourceLabel(source, body, source:match('^ch_(.+)$'))
        local line = string.format(
            '%s%s[%d] (%s): %s',
            PROFANITY_MSG_PREFIX, nick, id, channel, preview
        )
        sampAddChatMessage(line, PF.ALERT_COLOR)
    end
    if settings.debug then
        print('[Report Desk] profanity: ' .. nick .. ' msg="' .. profanityPreviewText(body, 48) .. '"')
    end
    return true
end

function notifyProfanityDetected(nick, id, body, source)
    notifyProfanityOnce(nick, id, body, source, nil)
end

function profanityClampWrapLines(text, wrapW, maxLines)
    text = trim(stripTags(text or ''))
    maxLines = math.max(1, tonumber(maxLines) or PF.TOAST_BODY_MAX_LINES)
    wrapW = math.max(48, tonumber(wrapW) or 200)
    if text == '' then return {}, imgui.GetTextLineHeight(), 0 end
    local lines, lineH = wrapTextLines(text, wrapW)
    if #lines <= maxLines then return lines, lineH, #lines end
    local kept = {}
    for i = 1, maxLines - 1 do
        kept[i] = lines[i]
    end
    local rest = {}
    for i = maxLines, #lines do
        if lines[i] ~= '' then rest[#rest + 1] = lines[i] end
    end
    kept[maxLines] = ellipsizeToWidth(table.concat(rest, ' '), wrapW)
    return kept, lineH, maxLines
end

function layoutProfanityToast(t, cardW)
    local padX = PF.TOAST_PAD_X
    local padY = PF.TOAST_PAD_Y
    local innerW = math.max(120, cardW - padX * 2)
    local lineH = (imgui.GetTextLineHeightWithSpacing and imgui.GetTextLineHeightWithSpacing())
        or imgui.GetTextLineHeight()

    local channel = t.channel or profanitySourceLabel(t.source, t.body, t.source and t.source:match('^ch_(.+)$'))
    local nickLine = (t.nick or '?') .. '[' .. tostring(t.id or 0) .. ']'
    local chW = imgui.CalcTextSize(catalogWarmupDlUtf(channel)).x
    local nickW = imgui.CalcTextSize(catalogWarmupDlUtf(nickLine)).x
    local headerGap = 7
    local headerRows = 1
    local nickEll = nickLine
    if chW + headerGap + nickW > innerW then
        if chW + headerGap + 40 > innerW then
            headerRows = 2
        else
            nickEll = ellipsizeToWidth(nickLine, innerW - chW - headerGap)
        end
    end

    local bodyText = trim(stripTags(t.body or ''))
    local bodyLines, bodyLineH, bodyLineCount = profanityClampWrapLines(bodyText, innerW, PF.TOAST_BODY_MAX_LINES)
    bodyLineH = bodyLineH or lineH
    bodyLineCount = bodyLineCount or #bodyLines
    local bodyH = bodyLineCount > 0 and (bodyLineCount * bodyLineH) or 0

    local cardH = padY * 2 + headerRows * lineH
    if bodyH > 0 then
        cardH = cardH + PF.TOAST_HEADER_GAP + bodyH
    end
    cardH = math.max(cardH, padY * 2 + lineH + 4)

    return {
        padX = padX,
        padY = padY,
        innerW = innerW,
        lineH = lineH,
        bodyLineH = bodyLineH,
        cardH = cardH,
        channel = channel,
        chCol = t.channelCol or col_muted2,
        nickLine = nickLine,
        nickEll = nickEll,
        nickCol = t.nickCol or profanityToastNickColor(t.id),
        headerRows = headerRows,
        headerGap = headerGap,
        bodyLines = bodyLines,
        bodyText = bodyText,
    }
end

function drawProfanityToastCard(dl, x0, y0, cardW, t, alpha)
    if not dl or not t then return 0 end
    alpha = alpha or 1
    local lay = layoutProfanityToast(t, cardW)
    local cardH = lay.cardH
    local bMin = imgui.ImVec2(x0, y0)
    local bMax = imgui.ImVec2(x0 + cardW, y0 + cardH)
    dl:AddRectFilled(bMin, bMax, toU32(imgui.ImVec4(0.05, 0.05, 0.08, 0.94 * alpha)), 6)
    dl:AddRect(bMin, bMax, toU32(imgui.ImVec4(0.42, 0.32, 0.58, 0.72 * alpha)), 6, 0, 1.0)

    local x = x0 + lay.padX
    local y = y0 + lay.padY

    profanityDlText(dl, x, y, lay.chCol, lay.channel, alpha * 0.9)
    if lay.headerRows >= 2 then
        y = y + lay.lineH
        profanityDlText(dl, x, y, lay.nickCol, lay.nickLine, alpha * 0.92)
    else
        local nx = x + imgui.CalcTextSize(catalogWarmupDlUtf(lay.channel)).x + lay.headerGap
        profanityDlText(dl, nx, y, lay.nickCol, lay.nickEll, alpha * 0.92)
    end

    if lay.bodyText ~= '' and lay.bodyLines and #lay.bodyLines > 0 then
        y = y + lay.lineH + PF.TOAST_HEADER_GAP
        local cy = y
        for _, ln in ipairs(lay.bodyLines) do
            if ln ~= '' then
                profanityDlText(dl, x, cy, col_muted, ln, alpha * 0.82)
            end
            cy = cy + lay.bodyLineH
        end
    end

    return cardH
end

function drawProfanityToastsOverlay()
    if not settings.profanity_filter_enabled then return end
    pruneProfanityToasts()
    if #deskCache.profToasts == 0 then return end

    local dl = imgui.GetForegroundDrawList and imgui.GetForegroundDrawList()
    if not dl then return end

    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    if sw < 100 then sw = 1920 end
    if sh < 100 then sh = 1080 end

    local cardW = PF.TOAST_CARD_W
    local x0 = (sw - cardW) * 0.5
    local y0 = PF.TOAST_TOP_PAD
    local maxShow = math.min(#deskCache.profToasts, PF.TOAST_MAX_SHOW)
    local startIdx = math.max(1, #deskCache.profToasts - maxShow + 1)

    for i = #deskCache.profToasts, startIdx, -1 do
        local t = deskCache.profToasts[i]
        local remain = (t.expires or 0) - os.clock()
        local alpha = 1.0
        if remain < 1.0 then
            alpha = math.max(0, remain / 1.0)
        end
        if alpha > 0.02 then
            local cardH = drawProfanityToastCard(dl, x0, y0, cardW, t, alpha)
            y0 = y0 + cardH + PF.TOAST_GAP
        end
    end
end

function checkProfanityFromPlayer(nick, id, body, source, lineKey)
    if not settings.profanity_filter_enabled then return end
    if findProfanityMatch(body) then
        notifyProfanityOnce(nick, id, body, source, lineKey)
    end
end

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
    checkProfanityFromPlayer(nick, playerId, body, source)
end

function checkProfanityFromBubble(playerId, message)
    if not isSampAvailable() then return end
    playerId = tonumber(playerId)
    if playerId == nil or playerId < 0 then return end
    if not sampIsPlayerConnected(playerId) then return end
    local nick = trim(sampGetPlayerNickname(playerId) or '')
    if nick == '' then return end
    local body = trim(message or '')
    local source = 'bubble'
    if body:match('^/do%s') then
        source = 'do'
        body = stripRoleplayBodyPrefix(body)
    else
        body = stripRoleplayBodyPrefix(body)
    end
    if body == '' then return end
    checkProfanityFromPlayer(nick, playerId, body, source)
end
