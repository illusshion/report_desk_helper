--[[ Модуль: runtime ingest, admin reply, auto-rules UI. ]]
function initDeskIngest()
    deskIngest.configure({
        maxPlayerId = MAX_PLAYER_ID,
        trim = trim,
        stripTags = stripTags,
        stripChatTimestamp = stripChatTimestamp,
        isExcludedChatLine = isExcludedChatLine,
        isValidPlayerNick = isValidPlayerNick,
        ingest_pc = true,
        ingest_s = true,
        ingest_m = true,
        ingest_admin_bracket = true,
    })
end

-- Try Parse Report
function tryParseReport(text)
    return deskIngest.tryParseReport(text)
end

-- Should Ingest Server Report
function shouldIngestServerReport(color, plain)
    if not tryParseReport(plain) then return false end
    if settings.ingest_srv_any_color then return true end
    local c = normColor(color)
    if isReportColor(c) or REPORT_COLORS[c] then return true end
    -- Строка как репорт (Nick[id]:) — принимаем и запоминаем цвет канала
    if c ~= 0 then learnReportColor(c) end
    return true
end

-- Learn Report Color
function learnReportColor(color)
    local c = normColor(color)
    if c and c ~= 0 and not REPORT_COLORS[c] then
        REPORT_COLORS[c] = true
        if not settings.report_colors then settings.report_colors = {} end
        local found = false
        for _, v in ipairs(settings.report_colors) do
            if normColor(v) == c then found = true break end
        end
        if not found then
            settings.report_colors[#settings.report_colors + 1] = c
            markDirtySettings()
        end
    end
end

-- Парсинг данных с сервера/чата.
-- NO-API: inbound admin reply echo; outbound /ans tracked in handleOutgoingAnsCommand.
function parseAdminReply(text)
    if not text or text == '' then return nil end
    text = trim(stripChatTimestamp(stripTags(text)))
    if text == '' or not text:find(L_ADMIN_FOR, 1, true) then return nil end

    local adminNick, adminId, targetNick, targetId, body

    adminNick, adminId, targetNick, targetId, body = text:match(
        '^' .. L_ADMIN_FOR .. ' ([%w][%w_]*)%[(%d+)%] ' .. '\xE4\xEB\xFF' .. ' ([%w][%w_]*)%[(%d+)%]:%s*(.+)$'
    )
    if not targetId then
        adminNick, targetNick, targetId, body = text:match(
            '^' .. L_ADMIN_FOR .. ' ([%w][%w_]*) ' .. '\xE4\xEB\xFF' .. ' ([%w][%w_]*)%[(%d+)%]:%s*(.+)$'
        )
        adminId = nil
    end
    if not targetId then
        adminNick, adminId, targetNick, targetId, body = text:match(
            '^' .. L_ADMIN_FOR .. ' ([%w][%w_]*)%[(%d+)%] ' .. '\xE4\xEB\xFF' .. ' ([%w][%w_]*)%[(%d+)%]%s*:%s*(.+)$'
        )
    end

    if not targetId or not isValidPlayerNick(adminNick) or not isValidPlayerNick(targetNick) then
        return nil
    end
    return trim(adminNick), tonumber(adminId), tonumber(targetId), trim(targetNick), trim(body)
end

-- Looks Like Admin Reply Line
function looksLikeAdminReplyLine(text)
    text = trim(stripChatTimestamp(stripTags(text or '')))
    if text == '' then return false end
    if not text:find('^' .. L_ADMIN_FOR, 1) then return false end
    return text:find('\xE4\xEB\xFF', 1, true) ~= nil
end

-- Try Ingest Admin Reply Line
function tryIngestAdminReplyLine(text)
    local adminNick, adminId, targetId, targetNick, body = parseAdminReply(text)
    if not adminNick or not targetId or not body then return false end
    return handleAdminReplyFromChat(adminNick, adminId, targetId, body, targetNick)
end

-- Handle Admin Reply From Chat
function handleAdminReplyFromChat(adminNick, adminId, targetId, body, targetNick)
    body = normalizeOutboundBody(body)
    if body == '' then return false end
    targetId = tonumber(targetId)

    local t, key = resolveThreadForPlayerId(targetId, targetNick)
    if not t or not key then
        return false
    end
    local echoTk = outboundEchoThreadKey(targetId, body, targetNick)
    if echoTk and threads[echoTk] then
        key = echoTk
        t = threads[echoTk]
    end
    if not t or not key then return false end

    local isSelf = isMyAdminReply(adminNick, adminId)
    if outbound.pending then
        local p = outbound.pending
        local age = os.clock() - (p.at or 0)
        if age < PENDING_OUTBOUND_SEC and tonumber(p.id) == targetId then
            local pNk = p.nickKey or ''
            local tNk = nickKey(targetNick or '')
            if pNk == '' or tNk == '' or pNk == tNk then
                if p.threadKey and threads[p.threadKey] then
                    key = p.threadKey
                    t = threads[key]
                end
            end
            if normalizeOutboundBody(p.body) == body then
                isSelf = true
            elseif p.split and body ~= p.body then
                if threadFindOutgoingMessage(t, p.body, { self = true }) then
                    return true
                end
            end
        end
    end

    if isSelf then
        if wasOutboundEchoHandled(targetId, body, targetNick)
            and threadFindOutgoingMessage(t, body, { self = true }) then
            return true
        end
        if outbound.pending and normalizeOutboundBody(outbound.pending.body) == body then
            clearPendingOutbound()
        end
        local existing = threadFindOutgoingMessage(t, body, { self = true })
        if existing then
            if not existing.self then
                existing.self = true
                existing.adminNick = nil
                existing.kind = 'reply_self'
                markThreadAnswered(t)
            end
            markOutboundEchoHandled(targetId, body, key, targetNick)
            return true
        end
        if not threadApplyOutgoing(t, key, body, { self = true })
                and not threadFindOutgoingMessage(t, body, { self = true }) then
            return false
        end
        markOutboundEchoHandled(targetId, body, key, targetNick)
        return true
    end

    if not threadApplyOutgoing(t, key, body, { self = false, adminNick = adminNick })
            and not threadFindOutgoingMessage(t, body, { self = false, adminNick = adminNick }) then
        return false
    end
    return true
end

-- Rule Cooldown Key
function ruleCooldownKey(threadKey, ruleName)
    return tostring(threadKey) .. ':' .. tostring(ruleName)
end

-- Is Rule On Cooldown
function isRuleOnCooldown(threadKey, rule)
    local key = ruleCooldownKey(threadKey, rule.name)
    local untilTs = ruleCooldowns[key]
    if not untilTs then return false end
    if os.time() >= untilTs then
        ruleCooldowns[key] = nil
        return false
    end
    return true
end

-- Set Rule Cooldown
function setRuleCooldown(threadKey, rule)
    local key = ruleCooldownKey(threadKey, rule.name)
    ruleCooldowns[key] = os.time() + (tonumber(rule.cooldown) or 120)
end

local EDGE_PUNCT = '[%s%.%!%?,:;%-]+'

-- Normalize Match Text (shared with intent engine when loaded first)
if type(normalizeMatchText) ~= 'function' then
function normalizeMatchText(s)
    s = trim(stripTags(s or ''))
    if type(isUtf8Text) == 'function' and isUtf8Text(s)
            and type(utf8ToCp1251) == 'function' then
        s = utf8ToCp1251(s)
    end
    s = s:lower():gsub('%s+', ' ')
    s = s:gsub('\xB8', '\xE5')
    s = s:gsub('^' .. EDGE_PUNCT, ''):gsub(EDGE_PUNCT .. '$', '')
    return s
end
end

-- Rule Match Mode Label
function ruleMatchModeLabel(mode)
    if mode == 'contains' then return 'contains' end
    if mode == 'all_words' then return 'all_words' end
    return 'exact'
end

-- Rule Match Mode From Int
function ruleMatchModeFromInt(v)
    v = tonumber(v) or 0
    if v == 1 then return 'contains' end
    if v == 2 then return 'all_words' end
    return 'exact'
end

-- Rule Match Mode To Int
function ruleMatchModeToInt(mode)
    if mode == 'contains' then return 1 end
    if mode == 'all_words' then return 2 end
    return 0
end

-- Split Trigger Words
function splitTriggerWords(kw)
    local parts = {}
    local seen = {}
    kw = tostring(kw or ''):gsub('+', ' ')
    for w in kw:gmatch('%S+') do
        w = normalizeMatchText(w)
        if w ~= '' and #w >= MIN_CONTAINS_TRIGGER_LEN and not seen[w] then
            seen[w] = true
            parts[#parts + 1] = w
        end
    end
    return parts
end

-- Text Has All Words
function textHasAllWords(msg, msgAlt, kw, msgTypo)
    msgTypo = msgTypo or normalizeMatchTextTypo(msg)
    kw = tostring(kw or ''):gsub('+', ' ')
    local parts = {}
    for w in kw:gmatch('%S+') do
        w = trim(w)
        if w ~= '' then parts[#parts + 1] = w end
    end
    if #parts == 0 then return false end
    local function allIn(msgA, msgB, typo)
        for _, w in ipairs(parts) do
            if not textMatchesContainsToken(msgA, msgB, w, typo) then
                return false
            end
        end
        return true
    end
    if allIn(msg, msgAlt, msgTypo) then return true end
    if msgTypo ~= msg and msgTypo ~= msgAlt then
        return allIn(msgTypo, msgTypo, msgTypo)
    end
    return false
end

-- Keyword Match Score
function keywordMatchScore(kw, msg, msgAlt, mode, msgTypo)
    local raw = trim(kw or '')
    if raw == '' then return 0 end
    mode = mode or 'contains'
    msgTypo = msgTypo or normalizeMatchTextTypo(msg)
    if raw:find('+', 1, true) then
        if not textHasAllWords(msg, msgAlt, raw, msgTypo) then return 0 end
        local score = 40
        for w in raw:gmatch('%S+') do
            score = score + #normalizeMatchText(w)
        end
        return score
    end
    if triggerMatchesKeyword(raw, msg, msgAlt, mode, msgTypo) then
        return math.max(#normalizeMatchText(raw), 3)
    end
    return 0
end

-- Trigger Matches Keyword
function triggerMatchesKeyword(kw, msg, msgAlt, mode, msgTypo)
    local raw = trim(kw or '')
    if raw == '' then return false end
    msgTypo = msgTypo or normalizeMatchTextTypo(msg)
    if raw:find('+', 1, true) then
        return textHasAllWords(msg, msgAlt, raw, msgTypo)
    end
    local k = normalizeMatchText(raw)
    local kAlt = normalizeIngestBody(raw)
    if k == '' and kAlt == '' then return false end
    mode = mode or 'exact'
    if mode == 'exact' then
        for _, bag in ipairs({ msg, msgAlt, msgTypo }) do
            if bag == k or bag == kAlt then return true end
        end
        return false
    end
    if mode == 'contains' then
        if k ~= '' and textMatchesContainsToken(msg, msgAlt, k, msgTypo) then return true end
        if kAlt ~= '' and kAlt ~= k and textMatchesContainsToken(msg, msgAlt, kAlt, msgTypo) then return true end
        return false
    end
    if mode == 'all_words' then
        return textHasAllWords(msg, msgAlt, raw, msgTypo)
    end
    return false
end

-- Get Sorted Rule Indices
function getSortedRuleIndices()
    local rules = getActiveBuiltinAutoRules()
    local idx = {}
    for i = 1, #rules do idx[i] = i end
    table.sort(idx, function(a, b)
        local pa = tonumber(rules[a].priority) or 0
        local pb = tonumber(rules[b].priority) or 0
        if pa ~= pb then return pa > pb end
        return a < b
    end)
    return idx, rules
end

-- Find Matching Rule
function findMatchingRule(body)
    local order, rules = getSortedRuleIndices()
    for _, i in ipairs(order) do
        local rule = rules[i]
        if rule.enabled and keywordMatches(rule, body) then
            if rule.skip_if_report_id ~= true or not extractReportSuspectId(body) then
                return rule
            end
        end
    end
    return nil
end

-- Keyword Matches
function keywordMatches(rule, body)
    local msg, msgAlt, msgTypo = matchMessageVariants(body)
    if msg == '' and msgAlt == '' and msgTypo == '' then return false end
    local mode = rule.match or 'exact'
    for _, kw in ipairs(rule.keywords or {}) do
        if triggerMatchesKeyword(kw, msg, msgAlt, mode, msgTypo) then
            return true
        end
    end
    return false
end

-- Execute Rule Action
function executeRuleAction(t, rule)
    if rule.action == 'chat_cmd' then
        local id, err = resolveAnsIdForReply(t)
        if not id then return false, err or 'no target' end
        local payload = expandTemplate(rule.payload, id)
        local line = payload
        if line:sub(1, 1) == '/' then line = line:sub(2) end
        local ok = sendChat(line)
        return ok, ok and ('/ ' .. line) or 'chat fail'
    end
    local id = getResolvedAnsId(t)
    local payload = expandTemplate(rule.payload, id)
    local tk = threadStorageKey(t)
    local ok, result = sendOutgoingAns(t, payload, { threadKey = tk })
    if settings.debug then
        print('[Report Desk] auto ' .. (ok and 'OK' or 'FAIL') .. ': ' .. tostring(result))
    end
    return ok, ok and result or (result or 'fail')
end

--[[
    processAutoRules: nil = нет совпадения, true = отправлено/ожидание confirm, false = совпало но ошибка
]]
