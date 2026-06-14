--[[ Модуль: dedup чата и anti-replay. ]]

function pruneChatSeenDeferred()
    if type(chatSeen) ~= 'table' or type(chatSeen.deferred) ~= 'table' then return end
    local now = os.clock()
    local maxAge = (CHAT_DEFERRED_ADMIN_SEC or 4) * 4
    local n = 0
    for key, deferAt in pairs(chatSeen.deferred) do
        n = n + 1
        if not deferAt or (now - deferAt) > maxAge then
            chatSeen.deferred[key] = nil
        end
    end
    if n > 128 then
        chatSeen.deferred = {}
    end
end

function isDuplicateIngest(id, body, rawLine)
    local key = ingestDedupKey(id, body, rawLine)
    if key == '' then return false end
    local prev = RECENT.ingest[key]
    if prev and (os.clock() - prev) < INGEST_DEDUP_SEC then return true end
    return false
end

function markIngestDedup(id, body, rawLine)
    local key = ingestDedupKey(id, body, rawLine)
    if key ~= '' then
        touchTimedMap(RECENT.ingest, RECENT.ingestOrd, key)
    end
end

function normalizeChatLine(line)
    return trim(stripChatTimestamp(stripTags(line or '')))
end

function wirePlain(line)
    return normalizeChatLine(line)
end

function wireSeenKey(line)
    local plain = wirePlain(line)
    if plain == '' then return '' end
    return plain
end

function chatLineSeenKey(line)
    return wireSeenKey(line)
end

function chatLineAgeSeconds(line)
    line = line or ''
    local h, m, s = line:match('%[(%d+):(%d+):(%d+)%]')
    if not h then
        h, m, s = line:match('%[%d+%.%d+%.%d+%s+(%d+):(%d+):(%d+)%]')
    end
    if not h then return nil end
    h, m, s = tonumber(h), tonumber(m), tonumber(s)
    if not h or not m or not s then return nil end
    local now = os.date('*t')
    local msgSec = h * 3600 + m * 60 + s
    local nowSec = now.hour * 3600 + now.min * 60 + now.sec
    local diff = nowSec - msgSec
    if diff < 0 then diff = diff + 86400 end
    return diff
end

function deskSyncChatSeenAfterResume()
    if not sampGetChatString then return end
    for i = 0, 99 do
        local line = sampGetChatString(i) or ''
        if line == '' then goto cont end
        local key = chatLineSeenKey(line)
        if key == '' then goto cont end
        if isReportLineConsumed(line) then
            markChatLineSeen(key)
            goto cont
        end
        local plain = normalizeChatLine(line)
        if plain ~= '' and type(deskIngest) == 'table' and type(deskIngest.tryParseChatEvent) == 'function' then
            local ev = deskIngest.tryParseChatEvent(plain, { chatStrictReports = true })
            if ev and ev.type == 'player_report' and type(threadHasIncomingReportBody) == 'function' then
                local tk = findThreadKeyByNick(ev.nick) or nickKey(ev.nick)
                local th = threads and threads[tk]
                if th and threadHasIncomingReportBody(th, ev.text) then
                    markChatLineSeen(key)
                    markReportLineConsumed(line)
                end
            end
        end
        ::cont::
    end
end

function markChatLineSeen(key)
    if not key or key == '' then return false end
    if chatSeen.lines[key] then return false end
    chatSeen.lines[key] = true
    chatSeen.order[#chatSeen.order + 1] = key
    while #chatSeen.order > MAX_SEEN_LINES do
        local old = table.remove(chatSeen.order, 1)
        if old then chatSeen.lines[old] = nil end
    end
    return true
end

function isReportLineConsumed(rawLine)
    local key = chatLineSeenKey(rawLine or '')
    return key ~= '' and chatSeen.consumed[key] == true
end

function markReportLineConsumed(rawLine)
    local key = chatLineSeenKey(rawLine or '')
    if key == '' or chatSeen.consumed[key] then return end
    chatSeen.consumed[key] = true
    chatSeen.consumedOrder[#chatSeen.consumedOrder + 1] = key
    while #chatSeen.consumedOrder > MAX_CONSUMED_REPORT_LINES do
        local old = table.remove(chatSeen.consumedOrder, 1)
        if old then chatSeen.consumed[old] = nil end
    end
end

function seedSeenChatLines()
    chatSeen.lines = {}
    chatSeen.order = {}
    chatSeen.deferred = {}
    chatSeen.consumed = {}
    chatSeen.consumedOrder = {}
    if not sampGetChatString then
        chatLogReady = true
        return
    end
    for i = 0, 99 do
        markChatLineSeen(chatLineSeenKey(sampGetChatString(i)))
    end
    chatLogReady = true
end
