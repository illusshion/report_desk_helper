--[[ Модуль: автоответы (очередь, time/GG, retry). ]]

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

function clearAllPendingAuto()
    clearPendingAutoConfirm()
    clearAutoReplyQueue()
end

function scheduleAutoRulesRetry(t, body, attempt)
    attempt = tonumber(attempt) or 0
    if attempt >= AUTO_RETRY_MAX then return end
    if not t or not t.nick then return end
    enqueueAutoReplyJob(t.nick, t.id, body, 'retry', {
        attempt = attempt + 1,
        delaySec = (tonumber(AUTO_RETRY_MS) or 280) / 1000,
    })
end

function runAutoRulesForReport(t, body, source)
    if not t or not body then return end
    if not deskAutoReplyAllowed() then return end
    local result = processAutoRules(t, body)
    if result == false and autoReplySrcAllowsRetry(source) then
        scheduleAutoRulesRetry(t, body, 0)
    end
    return result
end

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

function getPendingAutoForSelected()
    if not selectedKey then return nil end
    return pendingAuto[selectedKey]
end
