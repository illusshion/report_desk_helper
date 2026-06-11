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

-- Парсинг данных с сервера/чата.
function parseReportLine(text, color)
    return tryParseReport(text)
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
        threadApplyOutgoing(t, key, body, { self = true })
        markOutboundEchoHandled(targetId, body, key, targetNick)
        return true
    end

    threadApplyOutgoing(t, key, body, { self = false, adminNick = adminNick })
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

-- Match Text Padded
function matchTextPadded(s)
    s = normalizeMatchText(s)
    if s == '' then return '' end
    return ' ' .. s:gsub('%s+', ' ') .. ' '
end

-- Token Min Length
function tokenMinLength(token)
    token = normalizeMatchText(token)
    if token == '' then return MIN_CONTAINS_TRIGGER_LEN end
    if token:match('^[%a%d]+$') and #token >= 2 then return 2 end
    return MIN_CONTAINS_TRIGGER_LEN
end

-- Text Contains Token
function textContainsToken(msg, msgAlt, token, msgTypo)
    token = normalizeMatchText(token)
    if token == '' or #token < tokenMinLength(token) then return false end
    local needle = ' ' .. token .. ' '
    for _, bag in ipairs({ msg, msgAlt, msgTypo or normalizeMatchTextTypo(msg) }) do
        local mp = matchTextPadded(bag)
        if mp:find(needle, 1, true) then return true end
    end
    return false
end

-- Words Share Stem
function wordsShareStem(word, token, minStem)
    minStem = minStem or 6
    word = normalizeMatchText(word)
    token = normalizeMatchText(token)
    if word == '' or token == '' then return false end
    if word == token then return true end
    local maxStem = math.min(#word, #token)
    if maxStem < minStem then return false end
    for n = maxStem, minStem, -1 do
        if word:sub(1, n) == token:sub(1, n) then return true end
    end
    return false
end

--[[
    contains: короткие слова (3–4) — только целое слово; длиннее — целое слово, префикс или общий stem
    (собеседований → собеседование, дальнобойщиком → дальнобойщик).
]]
function textMatchesContainsToken(msg, msgAlt, token, msgTypo)
    token = normalizeMatchText(token)
    if token == '' or #token < tokenMinLength(token) then return false end
    msgTypo = msgTypo or normalizeMatchTextTypo(msg)
    if textContainsToken(msg, msgAlt, token, msgTypo) then return true end
    if #token < 5 then return false end
    local seen = {}
    local bags = {}
    for _, bag in ipairs({ msg, msgAlt, msgTypo }) do
        local n = normalizeMatchText(bag)
        if n ~= '' and not seen[n] then
            seen[n] = true
            bags[#bags + 1] = n
        end
    end
    local minStem = (#token >= 8) and 6 or 5
    for _, bag in ipairs(bags) do
        for w in bag:gmatch('%S+') do
            if #w >= #token and w:sub(1, #token) == token then
                return true
            end
            if #token >= minStem and wordsShareStem(w, token, minStem) then
                return true
            end
        end
    end
    return false
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
    local rules = getActiveAutoRules()
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

-- Keyword Dedupe Key
function keywordDedupeKey(part)
    local norm = normalizeMatchText(part)
    if norm ~= '' then return norm end
    return (part or ''):lower()
end

-- Keywords To Multiline
function keywordsToMultiline(kw)
    local parts = {}
    for _, k in ipairs(kw or {}) do
        local p = trim(k)
        if p ~= '' then parts[#parts + 1] = p end
    end
    return table.concat(parts, '\n')
end

-- Парсинг данных с сервера/чата.
function parseKeywordList(line)
    local kw = {}
    local seen = {}
    line = tostring(line or ''):gsub('[\r\n;|]+', ',')
    for part in (line .. ','):gmatch('([^,]+),') do
        part = trim(part)
        if part ~= '' then
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                kw[#kw + 1] = part
            end
        end
    end
    return kw
end

-- Сброс/отправка очереди.
function flushRuleKeywordsPreview()
    if selectedRuleIdx < 1 or selectedRuleIdx > #rules then return end
    local r = rules[selectedRuleIdx]
    if not r then return end
    local kw = {}
    for _, k in ipairs(ruleKwEdit) do
        local part = trim(k)
        if part ~= '' then kw[#kw + 1] = part end
    end
    r.keywords = kw
    markDirtySettings()
end

-- Сброс/отправка очереди.
function flushRuleEditorToRule()
    if selectedRuleIdx < 1 or selectedRuleIdx > #rules then return end
    local r = rules[selectedRuleIdx]
    if not r then return end
    local name = readInputBuf(editRuleName)
    if name ~= '' then r.name = name end
    r.payload = readInputBuf(editRulePayload)
    r.enabled = editRuleEnabled[0]
    r.cooldown = math.max(5, tonumber(r.cooldown) or 60)
    r.match = 'exact'
    r.mode = 'instant'
    r.priority = 0
    r.skip_if_report_id = false
    local kw = {}
    for _, k in ipairs(ruleKwEdit) do
        local part = trim(k)
        if part ~= '' then kw[#kw + 1] = part end
    end
    r.keywords = kw
    markDirtySettings()
end

-- Remove Rule Keyword At
function removeRuleKeywordAt(idx)
    if not ruleKwEdit[idx] then return end
    table.remove(ruleKwEdit, idx)
    markRuleEditorDirty()
    flushRuleEditorToRule()
end

-- Sync Rule Kw Edit From Rule
function syncRuleKwEditFromRule(r)
    ruleKwEdit = {}
    if not r then
        setInputBuf(ruleKwBulk, '')
        setInputBuf(ruleKwNew, '')
        return
    end
    local seen = {}
    local lines = {}
    for _, k in ipairs(r.keywords or {}) do
        local part = trim(k)
        if part ~= '' then
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                ruleKwEdit[#ruleKwEdit + 1] = part
                lines[#lines + 1] = part
            end
        end
    end
    setInputBuf(ruleKwBulk, table.concat(lines, '\n'))
    setInputBuf(ruleKwNew, '')
end

-- Sync Rule Keywords From Bulk Buf
function syncRuleKeywordsFromBulkBuf()
    local block = readInputBuf(ruleKwBulk)
    ruleKwEdit = {}
    if block == '' then
        markRuleEditorDirty()
        return
    end
    local seen = {}
    for line in block:gmatch('[^\r\n]+') do
        for _, part in ipairs(parseKeywordList(line)) do
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                ruleKwEdit[#ruleKwEdit + 1] = part
            end
        end
    end
    markRuleEditorDirty()
end

-- Add Keywords To Rule Edit
function addKeywordsToRuleEdit(words)
    local seen = {}
    for _, ex in ipairs(ruleKwEdit) do
        seen[keywordDedupeKey(ex)] = true
    end
    local added = 0
    for _, w in ipairs(words) do
        local part = trim(w)
        if part ~= '' then
            local key = keywordDedupeKey(part)
            if key ~= '' and not seen[key] then
                seen[key] = true
                ruleKwEdit[#ruleKwEdit + 1] = part
                added = added + 1
            end
        end
    end
    if added > 0 then
        markRuleEditorDirty()
        flushRuleEditorToRule()
    end
    return added
end

-- Try Add Keyword From Input
function tryAddKeywordFromInput()
    local line = trim(readInputBuf(ruleKwNew))
    if line == '' then return 0 end
    local words
    if line:find('[,;]') then
        words = parseKeywordList(line)
    else
        words = { line }
    end
    local n = addKeywordsToRuleEdit(words)
    setInputBuf(ruleKwNew, '')
    return n
end

-- Draw Keyword Chip
function drawKeywordChip(i, kw, onRemove, prefix)
    prefix = tostring(prefix or 'kw')
    local shown = ellipsizeToWidth(catalogWarmupDlUtf(kw), 150)
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.22, 0.16, 0.32, 0.95))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.32, 0.22, 0.46, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(8, 4))
    if imgui.SmallButton then
        imgui.SmallButton(shown .. '##' .. prefix .. '_c_' .. i)
    else
        imgui.Button(shown .. '##' .. prefix .. '_c_' .. i)
    end
    imgui.PopStyleVar()
    imgui.PopStyleColor(3)
    imgui.SameLine(0, 4)
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.40, 0.14, 0.18, 0.92))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.55, 0.20, 0.26, 1.0))
    local removed = false
    if imgui.SmallButton then
        removed = imgui.SmallButton('×##' .. prefix .. '_x_' .. i)
    else
        removed = imgui.Button('×##' .. prefix .. '_x_' .. i, imgui.ImVec2(22, 22))
    end
    imgui.PopStyleColor(2)
    if removed and onRemove then onRemove(i) end
    imgui.SameLine(0, 6)
end

-- Draw Keywords Flow List
function drawKeywordsFlowList(editList, onRemove, prefix)
    local x0 = imgui.GetCursorPosX()
    local avail = imgui.GetContentRegionAvail().x
    if #editList == 0 then
        imgui.TextColored(col_muted, uiText('\xD1\xE5\xF2 \xF1\xEB\xEE\xE2 \x97 \xE4\xEE\xE1\xE0\xE2\xFC\xF2\xE5 \xED\xE8\xE6\xE5'))
        return
    end
    for i, kw in ipairs(editList) do
        local cx = imgui.GetCursorPosX()
        if cx > x0 + 12 and cx + 72 > x0 + avail then
            imgui.Dummy(imgui.ImVec2(0, 2))
        end
        drawKeywordChip(i, kw, onRemove, prefix)
    end
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Draw Keywords Editor
function drawKeywordsEditor(prefix, editList, newBuf, newBufSize, bulkBuf, bulkBufSize, onAddInput, onAddBulk)
    prefix = tostring(prefix or 'kw')
    editList = editList or {}
    imgui.TextColored(col_muted2, uiText('\xD2\xF0\xE8\xE3\xE3\xE5\xF0\xFB'))
    imgui.SameLine(0, 8)
    imgui.TextColored(col_muted, string.format('(%d)', #editList))

    imgui.BeginChild('##kw_cloud_' .. prefix, imgui.ImVec2(-1, 128), true)
    drawKeywordsFlowList(editList, function(idx)
        if prefix == 'rule' then
            removeRuleKeywordAt(idx)
        else
            removeScenarioKeywordAt(idx)
        end
    end, prefix)
    imgui.EndChild()

    local addW = 86
    imgui.PushItemWidth(math.max(80, imgui.GetContentRegionAvail().x - addW - 8))
    local hint = uiText('\xF1\xEB\xEE\xE2\xEE \xE8\xEB\xE8 a, b, c')
    if imgui.InputTextWithHint then
        imgui.InputTextWithHint('##kw_new_' .. prefix, hint, newBuf, newBufSize)
    else
        imgui.InputText('##kw_new_' .. prefix, newBuf, newBufSize)
    end
    imgui.PopItemWidth()
    imgui.SameLine(0, 8)
    if imgui.Button(uiText('\xC4\xEE\xE1\xE0\xE2\xE8\xF2\xFC') .. '##kw_add_' .. prefix, imgui.ImVec2(addW, DESK_FORM_ROW_H)) then
        if onAddInput then onAddInput() end
    end

    local bulkKey = 'bulk_' .. prefix
    local bulkOpen = deskCache.ui.kwBulkOpen[bulkKey] == true
    local treeOpen = false
    if imgui.TreeNodeEx then
        local flags = 0
        if bulkOpen and imgui.TreeNodeFlags and imgui.TreeNodeFlags.DefaultOpen then
            flags = imgui.TreeNodeFlags.DefaultOpen
        end
        treeOpen = imgui.TreeNodeEx(uiText('\xC2\xF1\xF2\xE0\xE2\xE8\xF2\xFC \xF1\xEF\xE8\xF1\xEA\xEE\xEC') .. '##kw_tree_' .. prefix, flags)
    else
        treeOpen = imgui.TreeNode(uiText('\xC2\xF1\xF2\xE0\xE2\xE8\xF2\xFC \xF1\xEF\xE8\xF1\xEA\xEE\xEC') .. '##kw_tree_' .. prefix)
    end
    deskCache.ui.kwBulkOpen[bulkKey] = treeOpen and true or false
    if treeOpen then
        imgui.PushItemWidth(-1)
        imgui.InputTextMultiline('##kw_bulk_' .. prefix, bulkBuf, bulkBufSize, imgui.ImVec2(-1, 68))
        imgui.PopItemWidth()
        if imgui.Button(uiText('\xC8\xEC\xEF\xEE\xF0\xF2\xE8\xF0\xEE\xE2\xE0\xF2\xFC \xE2 \xF1\xEF\xE8\xF1\xEE\xEA') .. '##kw_imp_' .. prefix, imgui.ImVec2(-1, DESK_FORM_ROW_H)) then
            if onAddBulk then
                local n = onAddBulk() or 0
                if n > 0 then setInputBuf(bulkBuf, '') end
            end
        end
        imgui.TreePop()
    end
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Draw Rules Edit Panel
function drawRulesEditPanel()
    imgui.TextColored(col_muted2, uiText('\xCD\xE0\xE7\xE2\xE0\xED\xE8\xE5'))
    imgui.PushItemWidth(-1)
    imgui.InputText('##rule_name', editRuleName, sizeof(editRuleName))
    if imguiItemEdited() then flushRuleEditorToRule() end
    imgui.PopItemWidth()

    imgui.TextColored(col_muted2, uiText('\xD2\xF0\xE8\xE3\xE3\xE5\xF0\xFB (\xEF\xEE \xF1\xF2\xF0\xEE\xEA\xE5, + \xE4\xEB\xFF \xE2\xF1\xE5\xF5 \xF1\xEB\xEE\xE2)'))
    imgui.TextColored(col_muted, string.format('(%d)', #ruleKwEdit))
    imgui.PushItemWidth(-1)
    if imgui.InputTextMultiline('##rule_kw_bulk', ruleKwBulk, sizeof(ruleKwBulk), imgui.ImVec2(-1, 120)) then
        syncRuleKeywordsFromBulkBuf()
        flushRuleEditorToRule()
    end
    if imguiItemEdited() then
        syncRuleKeywordsFromBulkBuf()
        flushRuleEditorToRule()
    end
    imgui.PopItemWidth()

    imgui.TextColored(col_muted2, uiText('\xCE\xF2\xE2\xE5\xF2 /ans'))
    imgui.PushItemWidth(-1)
    if imgui.InputTextMultiline('##rule_payload', editRulePayload, sizeof(editRulePayload), imgui.ImVec2(-1, 72)) then
        flushRuleEditorToRule()
    end
    if imguiItemEdited() then flushRuleEditorToRule() end
    imgui.PopItemWidth()
    drawTemplateTagsHint()
    if imgui.Button(uiText('\xC2\xF1\xF2\xE0\xE2\xE8\xF2\xFC \xEF\xF0\xE8\xEC\xE5\xF0 \xE2\xF0\xE5\xEC\xE5\xED\xE8') .. '##rule_ex_time', imgui.ImVec2(-1, 22)) then
        setInputBuf(editRulePayload, '\xD2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF: {datetime}')
        flushRuleEditorToRule()
    end
    imgui.Dummy(imgui.ImVec2(0, 4))

    if deskFormToggleRow('\xC2\xEA\xEB\xFE\xF7\xE5\xED\xEE', editRuleEnabled, function()
        flushRuleEditorToRule()
    end, 'rule_en') then end

    imgui.Dummy(imgui.ImVec2(0, 8))
    if imgui.Button(uiText('\xD3\xE4\xE0\xEB\xE8\xF2\xFC \xE0\xE2\xF2\xEE\xEE\xF2\xE2\xE5\xF2'), imgui.ImVec2(-1, 26)) then
        flushRuleEditorToRule()
        if #rules > 0 then
            table.remove(rules, selectedRuleIdx)
            selectedRuleIdx = math.min(selectedRuleIdx, #rules)
            if selectedRuleIdx < 1 then selectedRuleIdx = 1 end
            if #rules > 0 then fillRuleEditor(selectedRuleIdx) end
            markDirtySettings()
        end
    end
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
    local id = getResolvedAnsId(t)
    local payload = expandTemplate(rule.payload, id)
    if rule.action == 'chat_cmd' then
        local line = payload
        if line:sub(1, 1) == '/' then line = line:sub(2) end
        local ok = sendChat(line)
        return ok, ok and ('/ ' .. line) or 'chat fail'
    end
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
