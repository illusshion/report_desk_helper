--[[ Модуль: фильтр тредов и preview (auto/ingest вынесены). ]]
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

-- Active Builtin Auto Rules
-- Встроенные автоответы (time/GG) are separate from intent/quickScenarios matching (resolveMessageIntents).

-- Auto Rules
-- Очистка confirm-only pending auto (mode=confirm rules).
-- Очистка All Pending Auto
-- Schedule Auto Rules Retry
-- Run Auto Rules For Report
-- Confirm Pending Auto
-- Pending Auto For Selected
-- Add Thread Event Message
-- Find Existing Thread Key
-- Add Thread Event Message To Existing
-- Ingest Admin Action Event
-- Ingest Punishment Event
-- Chat Line Ingest
-- Запасной путь без API: chat ingest delegated to report_desk_ingest (server messages only).
-- On Incoming Report
-- Ingest Report
-- Отправка команды/сообщения на сервер.
-- Default Composer Quick Buttons
-- Normalize Composer Quick Button
-- Ensure Composer Quick Buttons
-- Sync Legacy Gg Tech From Composer Buttons
-- Time Reply Text
-- Sync Gg Reply To Composer
-- Gg Reply Text
-- Tech Reply Text
-- Отправка команды/сообщения на сервер.
-- Отправка команды/сообщения на сервер.
-- Отправка команды/сообщения на сервер.
-- Отправка команды/сообщения на сервер.
-- Run Helper Cmd
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

-- Filter List Sig
function getFilterListSig()
    return tostring(filterMode[0] or 0) .. '|' .. trim(readInputBuf(searchBuf)):lower()
        .. '|' .. tostring(deskCache.threadStructRev or 0)
        .. '|' .. tostring(deskCache.threadMsgRev or 0)
end

-- Filtered Thread Keys
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
-- Draw Accent Strip
-- Push Panel Style
-- Pop Panel Style
-- Settings Section
-- Settings Hint
-- Settings Block Begin
-- Settings Block End
-- Settings Sub Label
local SET_BIND_BTN_H = DESK_FORM_ROW_H

-- Desk hook/helper.
