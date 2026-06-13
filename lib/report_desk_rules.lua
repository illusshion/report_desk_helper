--[[ Модуль: auto-rules, scenarios, processChatLineIngest. ]]
local autoReplyQueue = {}
local autoReplyHead = 1
local autoReplyTail = 0
local AUTO_REPLY_QUEUE_MAX = 48

local function autoReplyQueueLen()
    return autoReplyTail - autoReplyHead + 1
end

local function autoReplyDefaultDelaySec()
    return (tonumber(AUTO_REPLY_DELAY_MS) or 250) / 1000
end

local function autoReplySrcAllowsRetry(src)
    return src == 'srv' or src == 'chat' or src == 'retry'
end

local function dispatchAutoReplyJob(job)
    if not job then return end
    if settings.profanity_filter_enabled then
        pcall(checkProfanityFromPlayer, job.nick, job.id, job.body, job.src)
    end
    local tk = findThreadKeyByNick(job.nick) or nickKey(job.nick)
    local th = threads[tk]
    if not th then
        if (job.attempt or 0) < 2 then
            enqueueAutoReplyJob(job.nick, job.id, job.body, job.src, {
                attempt = (job.attempt or 0) + 1,
                delaySec = 0.15,
            })
        end
        return
    end
    local result = processAutoRules(th, job.body)
    if result == false and autoReplySrcAllowsRetry(job.src) then
        scheduleAutoRulesRetry(th, job.body, job.attempt or 0)
    end
end

function tickAutoReplyQueue()
    if autoReplyQueueLen() < 1 then return end
    if not deskAutoReplyAllowed() then return end
    local now = os.clock()
    while autoReplyHead <= autoReplyTail do
        local job = autoReplyQueue[autoReplyHead]
        if not job then
            autoReplyHead = autoReplyHead + 1
        else
            local fireAt = tonumber(job.fireAt) or now
            if fireAt > now then break end
            autoReplyQueue[autoReplyHead] = nil
            autoReplyHead = autoReplyHead + 1
            pcall(dispatchAutoReplyJob, job)
        end
    end
end

function threadHasIncomingReportBody(t, body)
    if not t or not body then return false end
    local want = normalizeIngestBody(body)
    if want == '' then return false end
    local msgs = t.messages
    if type(msgs) ~= 'table' then return false end
    local from = math.max(1, #msgs - 80)
    for i = #msgs, from, -1 do
        local m = msgs[i]
        if m and m.dir == 'in' and (m.kind == 'player' or m.kind == nil) then
            local got = normalizeIngestBody(m.text or '')
            if got ~= '' and got == want then return true end
        end
    end
    return false
end

function enqueueAutoReplyJob(nick, id, body, src, opts)
    opts = opts or {}
    if autoReplyQueueLen() >= AUTO_REPLY_QUEUE_MAX then
        autoReplyQueue[autoReplyHead] = nil
        autoReplyHead = autoReplyHead + 1
    end
    local delaySec = tonumber(opts.delaySec)
    if not delaySec then delaySec = autoReplyDefaultDelaySec() end
    autoReplyTail = autoReplyTail + 1
    autoReplyQueue[autoReplyTail] = {
        nick = nick,
        id = id,
        body = body,
        src = src or 'live',
        fireAt = os.clock() + delaySec,
        attempt = tonumber(opts.attempt) or 0,
    }
end

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

-- Builtin auto-rules (time/GG) are separate from intent/quickScenarios matching (resolveMessageIntents).

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
        addAutoSystemNote(t, rule.name, nil, 'pending')
        markAutoFired(t, body)
        return true
    end
    local ok, executed = executeRuleAction(t, rule)
    if not ok then
        addAutoSystemNote(t, rule.name, executed, 'fail')
    end
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

-- Clear confirm-only pending auto (mode=confirm rules).
function clearPendingAutoConfirm()
    for k in pairs(pendingAuto) do
        pendingAuto[k] = nil
    end
end

function clearAutoReplyQueue()
    for i = autoReplyHead, autoReplyTail do
        autoReplyQueue[i] = nil
    end
    autoReplyHead = 1
    autoReplyTail = 0
end

-- Clear All Pending Auto
function clearAllPendingAuto()
    clearPendingAutoConfirm()
    clearAutoReplyQueue()
end

-- Schedule Auto Rules Retry
function scheduleAutoRulesRetry(t, body, attempt)
    attempt = tonumber(attempt) or 0
    if attempt >= AUTO_RETRY_MAX then return end
    if not t or not t.nick then return end
    enqueueAutoReplyJob(t.nick, t.id, body, 'retry', {
        attempt = attempt + 1,
        delaySec = (tonumber(AUTO_RETRY_MS) or 280) / 1000,
    })
end

-- Run Auto Rules For Report
function runAutoRulesForReport(t, body, source)
    if not t or not body then return end
    if not deskAutoReplyAllowed() then return end
    local result = processAutoRules(t, body)
    if result == false and autoReplySrcAllowsRetry(source) then
        scheduleAutoRulesRetry(t, body, 0)
    end
    return result
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
    if type(markDirtyThreads) == 'function' then
        markDirtyThreads()
    end
    return true
end

-- Process Chat Line Ingest
-- NO-API: chat ingest delegated to report_desk_ingest (server messages only).
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
    if type(ensureWireCp1251) == 'function' then
        label = ensureWireCp1251(label)
        text = ensureWireCp1251(text)
    end
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
        if type(ensureWireCp1251) == 'function' then
            gg = ensureWireCp1251(gg)
            tech = ensureWireCp1251(tech)
        end
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
    if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
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
        if b.id == 'gg' then
            local text = b.text
            if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
            return text
        end
    end
    local text = trim(settings.gg_reply or '')
    if text == '' then text = DEFAULT_GG_REPLY end
    if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
    return text
end

-- Get Tech Reply Text
function getTechReplyText()
    ensureComposerQuickButtons()
    for _, b in ipairs(settings.composer_quick_buttons) do
        if b.id == 'tech' then
            local text = b.text
            if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
            return text
        end
    end
    local text = trim(settings.tech_reply or '')
    if text == '' then text = DEFAULT_TECH_REPLY end
    if type(ensureWireCp1251) == 'function' then text = ensureWireCp1251(text) end
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
    local id, err = resolveAnsIdForReply(t)
    if not id then
        if err then say(err) end
        return
    end
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
    local rawQ = trim(readInputBuf(searchBuf))
    if rawQ == '' then return true end
    local q = type(cp1251Lower) == 'function' and cp1251Lower(rawQ) or rawQ:lower()
    if tostring(t.id):find(q, 1, true) then return true end
    local nickHay = type(cp1251Lower) == 'function' and cp1251Lower(t.nick or '') or (t.nick or ''):lower()
    if nickHay:find(q, 1, true) then return true end
    for i = #t.messages, math.max(1, #t.messages - 5), -1 do
        local m = t.messages[i]
        local hay = m and (m.text or '') or ''
        if type(cp1251Lower) == 'function' then hay = cp1251Lower(hay) else hay = hay:lower() end
        if hay:find(q, 1, true) then return true end
    end
    return false
end

-- Get Filter List Sig
function getFilterListSig()
    return tostring(filterMode[0] or 0) .. '|' .. trim(readInputBuf(searchBuf)):lower()
        .. '|' .. tostring(deskCache.threadStructRev or 0)
        .. '|' .. tostring(deskCache.threadMsgRev or 0)
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
    if m.dir == 'system' then
        if type(formatAutoSystemDisplay) == 'function' then
            return formatAutoSystemDisplay(m)
        end
        return m.note or ''
    end
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

-- Poll sampGetChatString: safety reconcile (hook активен) или полный fallback.
function pollReportIngest()
    if not sampGetChatString then return end
    if not chatLogReady then return end
    local hookActive = type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive()
    local maxLines
    if hookActive then
        if showWindow[0] then
            maxLines = CHAT_POLL_SAFETY_LINES_OPEN or CHAT_POLL_SAFETY_LINES or 32
        else
            maxLines = CHAT_POLL_SAFETY_LINES
        end
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

