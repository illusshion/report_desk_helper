--[[ Модуль: auto-rules, scenarios, processChatLineIngest. ]]
function cloneBuiltinAutoRule(tpl, payload)
    local kw = {}
    for _, k in ipairs(tpl.keywords or {}) do
        kw[#kw + 1] = k
    end
    return {
        name = tpl.name,
        enabled = true,
        match = tpl.match or 'exact',
        keywords = kw,
        action = tpl.action or 'ans_text',
        payload = payload or '',
        cooldown = tonumber(tpl.cooldown) or 60,
        mode = tpl.mode or 'instant',
        priority = tonumber(tpl.priority) or 0,
        skip_if_report_id = tpl.skip_if_report_id == true,
    }
end

-- Get Active Builtin Auto Rules
function getActiveBuiltinAutoRules()
    local list = {}
    if settings.auto_time_enabled ~= false then
        list[#list + 1] = cloneBuiltinAutoRule(BUILTIN_AUTO_RULE_TIME, getTimeReplyText())
    end
    if settings.auto_gg_enabled ~= false then
        list[#list + 1] = cloneBuiltinAutoRule(BUILTIN_AUTO_RULE_GG, getGgReplyText())
    end
    return list
end

-- Get Active Auto Rules
function getActiveAutoRules()
    return getActiveBuiltinAutoRules()
end

-- Process Auto Rules
function processAutoRules(t, body)
    if not t or not body or #trim(body) < 1 then return nil end
    if settings.auto_rules_enabled == false then return nil end
    if shouldSkipAutoFire(t, body) then return nil end
    local tk = findThreadKeyByNick(t.nick) or nickKey(t.nick)
    local rule = findMatchingRule(body)
    if not rule then
        if settings.debug then
            print('[Report Desk] auto no match: "' .. normalizeMatchText(body) .. '"')
        end
        return nil
    end
    if rule.name == 'time' and settings.auto_time_enabled == false then return nil end
    if rule.name == 'GG' and settings.auto_gg_enabled == false then return nil end
    if isRuleOnCooldown(tk, rule) then
        if settings.debug then
            print('[Report Desk] auto skip cooldown: ' .. tostring(rule.name) .. ' (' .. tostring(t.nick) .. ')')
        end
        return nil
    end
    if settings.debug then
        print('[Report Desk] auto match: ' .. tostring(rule.name) .. ' body="' .. normalizeMatchText(body) .. '"')
    end
    if rule.mode == 'confirm' then
        pendingAuto[tk] = { rule = rule, body = body }
        addAutoSystemNote(t, rule.name, '\xEE\xE6\xE8\xE4\xE0\xE5\xF2 \xEF\xEE\xE4\xF2\xE2\xE5\xF0\xE6\xE4\xE5\xED\xE8\xFF')
        markAutoFired(t, body)
        return true
    end
    local ok, executed = executeRuleAction(t, rule)
    addAutoSystemNote(t, rule.name, executed)
    if ok then
        setRuleCooldown(tk, rule)
        markAutoFired(t, body)
        return true
    end
    if settings.debug then
        print('[Report Desk] auto FAIL send: ' .. tostring(executed))
    end
    return false
end

-- Clear All Pending Auto
function clearAllPendingAuto()
    for k in pairs(pendingAuto) do
        pendingAuto[k] = nil
    end
end

-- Schedule Auto Rules Retry
function scheduleAutoRulesRetry(t, body, attempt)
    attempt = tonumber(attempt) or 0
    if attempt >= AUTO_RETRY_MAX then return end
    local nick = t.nick
    local wantBody = normalizeMatchText(body)
    if wantBody == '' then wantBody = normalizeIngestBody(body) end
    lua_thread.create(function()
        wait(AUTO_RETRY_MS)
        if not deskAutoReplyAllowed() then return end
        local key = findThreadKeyByNick(nick) or nickKey(nick)
        local th = threads[key]
        if not th then return end
        local bodyNorm = normalizeMatchText(body)
        if bodyNorm == '' then bodyNorm = normalizeIngestBody(body) end
        if bodyNorm ~= wantBody then return end
        local result = processAutoRules(th, body)
        if result == false then
            scheduleAutoRulesRetry(th, body, attempt + 1)
        end
    end)
end

-- Run Auto Rules For Report
function runAutoRulesForReport(t, body, source)
    if not t or not body then return end
    if not deskAutoReplyAllowed() then return end
    local result = processAutoRules(t, body)
    if result == false and (source == 'srv' or source == 'chat') then
        scheduleAutoRulesRetry(t, body, 0)
    end
end

-- Confirm Pending Auto
function confirmPendingAuto(threadKey)
    local p = pendingAuto[threadKey]
    if not p then return end
    local t = threads[threadKey]
    if not t then
        pendingAuto[threadKey] = nil
        return
    end
    local ok, executed = executeRuleAction(t, p.rule)
    addAutoSystemNote(t, p.rule.name, executed)
    if ok then
        setRuleCooldown(threadKey, p.rule)
        if p.body then markAutoFired(t, p.body) end
    end
    pendingAuto[threadKey] = nil
end

-- Get Pending Auto For Selected
function getPendingAutoForSelected()
    if not selectedKey then return nil end
    return pendingAuto[selectedKey]
end

-- Add Thread Event Message
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

-- Find Existing Thread Key
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

-- Add Thread Event Message To Existing
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

-- Ingest Admin Action Event
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

-- Ingest Punishment Event
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
    return true
end

-- Process Chat Line Ingest
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

-- On Incoming Report
function onIncomingReport(nick, id, body, raw, isLive, source, channel)
    local key, t = resolveThread(nick, id)
    t.status = 'open'
    local reportChannel = deskIngest.extractReportChannel(channel) or deskIngest.extractReportChannel(raw)
    if reportChannel then
        t.reportChannel = reportChannel
    end
    local hadUnread = false
    if isLive then
        hadUnread = (t.unread or 0) > 0
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
    if isLive then
        local runAuto = not (settings.auto_only_unread and hadUnread)
        if runAuto and not deskAutoReplyAllowed() then runAuto = false end
        local src = source or 'live'
        local nickCopy, idCopy, bodyCopy = nick, id, body
        lua_thread.create(function()
            if settings.profanity_filter_enabled then
                pcall(checkProfanityFromPlayer, nickCopy, idCopy, bodyCopy, src)
            end
            if runAuto then
                wait(AUTO_REPLY_DELAY_MS)
                if not deskAutoReplyAllowed() then return end
                local tk = findThreadKeyByNick(nickCopy) or nickKey(nickCopy)
                local th = threads[tk]
                if th then
                    if settings.auto_rules_enabled ~= false then
                        pcall(runAutoRulesForReport, th, bodyCopy, src)
                    end
                end
            end
        end)
    end
end

-- Ingest Report
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

-- Отправка команды/сообщения на сервер.
function sendAnsToThread(t, text)
    text = trim(text)
    if text == '' then return false end
    local tk = threadStorageKey(t)
    local ok = sendOutgoingAns(t, text, { threadKey = tk })
    return ok
end

-- Default Composer Quick Buttons
function defaultComposerQuickButtons()
    return {
        { id = 'gg', label = 'GG', text = DEFAULT_GG_REPLY },
        { id = 'tech', label = '\xD2\xE5\xF5\xED\xE8\xF7\xEA\xE0', text = DEFAULT_TECH_REPLY },
    }
end

-- Normalize Composer Quick Button
function normalizeComposerQuickButton(raw, fromUtf8)
    if type(raw) ~= 'table' then return nil end
    fromUtf8 = fromUtf8 or raw._utf8
    local label = trim(normalizeStoredText(raw.label or '', fromUtf8))
    local text = trim(normalizeStoredText(raw.text or '', fromUtf8))
    if label == '' or text == '' then return nil end
    local id = trim(tostring(raw.id or ''))
    if id == '' then id = 'qb_' .. tostring(os.clock()):gsub('%.', '') end
    return { id = id, label = label, text = text }
end

-- Ensure Composer Quick Buttons
function ensureComposerQuickButtons()
    if type(settings.composer_quick_buttons) ~= 'table' or #settings.composer_quick_buttons == 0 then
        local gg = trim(settings.gg_reply or '')
        local tech = trim(settings.tech_reply or '')
        settings.composer_quick_buttons = {
            { id = 'gg', label = 'GG', text = gg ~= '' and gg or DEFAULT_GG_REPLY },
            { id = 'tech', label = '\xD2\xE5\xF5\xED\xE8\xF7\xEA\xE0', text = tech ~= '' and tech or DEFAULT_TECH_REPLY },
        }
        bumpComposerQuickGen()
        return
    end
    local out = {}
    for i, raw in ipairs(settings.composer_quick_buttons) do
        local b = normalizeComposerQuickButton(raw)
        if b then out[#out + 1] = b end
    end
    if #out == 0 then
        settings.composer_quick_buttons = defaultComposerQuickButtons()
    else
        settings.composer_quick_buttons = out
    end
    bumpComposerQuickGen()
end

-- Sync Legacy Gg Tech From Composer Buttons
function syncLegacyGgTechFromComposerButtons()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'gg' then settings.gg_reply = b.text end
        if b.id == 'tech' then settings.tech_reply = b.text end
    end
end

-- Get Time Reply Text
function getTimeReplyText()
    local text = trim(settings.time_reply or '')
    if text == '' then text = DEFAULT_TIME_REPLY end
    return text
end

-- Sync Gg Reply To Composer
function syncGgReplyToComposer(text)
    text = trim(text or '')
    if text == '' then return end
    settings.gg_reply = text
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'gg' then b.text = text end
    end
end

-- Get Gg Reply Text
function getGgReplyText()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'gg' then return b.text end
    end
    local text = trim(settings.gg_reply or '')
    if text == '' then text = DEFAULT_GG_REPLY end
    return text
end

-- Get Tech Reply Text
function getTechReplyText()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'tech' then return b.text end
    end
    local text = trim(settings.tech_reply or '')
    if text == '' then text = DEFAULT_TECH_REPLY end
    return text
end

-- Отправка команды/сообщения на сервер.
function sendReplyToSelected()
    local t, key = getSelectedThread()
    if not t then return false end
    local text = expandTemplate(readInputBuf(replyBuf), getResolvedAnsId(t))
    if text == '' then return false end
    local uiKey = (key or threadStorageKey(t) or '') .. '|' .. normalizeOutboundBody(text)
    local now = os.clock()
    if replyUi.key == uiKey and (now - replyUi.at) < 0.8 then
        return false
    end
    local ok, err = sendOutgoingAns(t, text, { threadKey = key })
    if ok then
        clearThreadRuleCooldowns(key or threadStorageKey(t))
        replyUi.key = uiKey
        replyUi.at = now
        return true
    end
    if err then say(tostring(err)) end
    return false
end

-- Отправка команды/сообщения на сервер.
function sendPresetReplyToSelected(kind, getText)
    local t, key = getSelectedThread()
    if not t then return false end
    local text = expandTemplate(getText(), getResolvedAnsId(t))
    local uiKey = (key or threadStorageKey(t) or '') .. '|' .. (kind or 'preset') .. '|' .. normalizeOutboundBody(text)
    local now = os.clock()
    if replyUi.key == uiKey and (now - replyUi.at) < 0.8 then
        return false
    end
    local ok, err = sendOutgoingAns(t, text, { threadKey = key })
    if ok then
        clearThreadRuleCooldowns(key or threadStorageKey(t))
        replyUi.key = uiKey
        replyUi.at = now
        return true
    end
    if err then say(tostring(err)) end
    return false
end

-- Отправка команды/сообщения на сервер.
function sendGgReplyToSelected()
    return sendPresetReplyToSelected('gg', getGgReplyText)
end

-- Отправка команды/сообщения на сервер.
function sendTechReplyToSelected()
    return sendPresetReplyToSelected('tech', getTechReplyText)
end

-- Run Helper Cmd
function runHelperCmd(cmd)
    local t = getSelectedThread()
    if not t then return end
    local id = getResolvedAnsId(t)
    if id < 0 then return end
    cmd = trim(cmd):gsub('^/', '')
    if cmd == '' then return end
    sendChat(cmd .. ' ' .. id)
end

-- Thread Matches Filter
function threadMatchesFilter(t)
    if filterMode[0] == 0 then
        return (t.unread or 0) > 0
    end
    return true
end

-- Thread Matches Search
function threadMatchesSearch(t, key)
    local q = trim(readInputBuf(searchBuf)):lower()
    if q == '' then return true end
    if tostring(t.id):find(q, 1, true) then return true end
    if (t.nick or ''):lower():find(q, 1, true) then return true end
    for i = #t.messages, math.max(1, #t.messages - 5), -1 do
        local m = t.messages[i]
        if m and (m.text or ''):lower():find(q, 1, true) then return true end
    end
    return false
end

-- Get Filter List Sig
function getFilterListSig()
    return tostring(filterMode[0] or 0) .. '|' .. trim(readInputBuf(searchBuf)):lower()
        .. '|' .. tostring(deskCache.threadStructRev or 0)
end

-- Get Filtered Thread Keys
function getFilteredThreadKeys()
    local sig = getFilterListSig()
    if deskCache.filterKeys and deskCache.filterSig == sig then
        return deskCache.filterKeys
    end
    local keys = {}
    for key, t in pairs(threads) do
        if t and threadMatchesFilter(t) and threadMatchesSearch(t, key) then
            keys[#keys + 1] = key
        end
    end
    table.sort(keys, threadSortBefore)
    deskCache.filterKeys = keys
    deskCache.filterSig = sig
    return keys
end

-- Last Preview
function lastPreview(t)
    local msgs = t.messages
    if not msgs or #msgs == 0 then return '' end
    local m = msgs[#msgs]
    if m.dir == 'system' then return m.note or '' end
    local k = messageKind(m)
    if k == 'action' then
        return '* ' .. (m.text or '')
    end
    if k == 'punish' then
        return '! ' .. (m.text or '')
    end
    local dir = messageDisplayDir(m)
    if dir == 'out' then
        if m.self then return '> ' .. (m.text or '') end
        if m.adminNick then return '> ' .. (m.adminNick or '?') .. ': ' .. (m.text or '') end
        return '> ' .. (m.text or '')
    end
    return '< ' .. (m.text or '')
end

-- Draw Accent Strip
function drawAccentStrip()
    local dl = imgui.GetWindowDrawList()
    local pos = imgui.GetWindowPos()
    dl:AddRectFilled(pos, imgui.ImVec2(pos.x + imgui.GetWindowWidth(), pos.y + 2), toU32(col_accent))
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Push Panel Style
function pushPanelStyle(bg)
    imgui.PushStyleColor(imgui.Col.ChildBg, bg or col_sidebar)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.18, 0.18, 0.22, 0.35))
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildRounding, 8)
    imgui.PushStyleVarFloat(imgui.StyleVar.ChildBorderSize, 0)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(PANEL_PAD, PANEL_PAD))
end

-- Pop Panel Style
function popPanelStyle()
    imgui.PopStyleVar(3)
    imgui.PopStyleColor(2)
end

-- Settings Section
function settingsSection(title)
    imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.TextColored(col_label, uiText(title))
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 8))
end

-- Settings Hint
function settingsHint(text)
    imgui.TextColored(col_muted2, uiText(text))
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Settings Block Begin
function settingsBlockBegin(id, title, hint)
    imgui.Dummy(imgui.ImVec2(0, 8))
    imgui.TextColored(col_accent, uiText(title))
    if hint and hint ~= '' then
        imgui.TextWrapped(uiText(hint))
        imgui.Dummy(imgui.ImVec2(0, 2))
    end
    imgui.Separator()
    imgui.Dummy(imgui.ImVec2(0, 6))
end

-- Settings Block End
function settingsBlockEnd()
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Settings Sub Label
function settingsSubLabel(text)
    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.TextColored(col_muted, uiText(text))
    imgui.Dummy(imgui.ImVec2(0, 2))
end

local SET_BIND_BTN_H = DESK_FORM_ROW_H

-- Desk hook/helper.
function deskPanelChildFlags()
    return 0
end

