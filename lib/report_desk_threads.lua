--[[ Report Desk thread model ]]
function resolveThread(nick, id)
    nick = trim(nick or '')
    id = tonumber(id)
    local nk = nickKey(nick)
    if nk == '' and id then nk = 'id' .. tostring(id) end
    local liveNick = id and liveNickForPlayerId(id) or ''

    local key = findThreadKeyByNick(nick)
    local t

    if not key and id then
        local matches = findThreadsByPlayerId(id)
        if #matches == 1 then
            key, t = matches[1].key, matches[1].t
        elseif #matches > 1 and nk ~= '' then
            for _, e in ipairs(matches) do
                if nickKey(e.t.nick) == nk then
                    key, t = e.key, e.t
                    break
                end
            end
        end
        if not key then
            local idKey = tostring(id)
            if threads[idKey] then key = idKey end
        end
    end

    if key and threads[key] then
        t = threads[key]
        if id and liveNick ~= '' and nickKey(liveNick) ~= nickKey(t.nick) and tonumber(t.id) == id then
            t.stale = true
            key = nil
            t = nil
        end
    end

    if t then
        if nick ~= '' then t.nick = nick end
        if id and tonumber(t.id) ~= id then
            if liveNick == '' or nickKey(liveNick) == nickKey(t.nick) then
                t.lastId = t.id
                t.id = id
                t.stale = nil
                markDirtyThreads()
            end
        elseif id and liveNick ~= '' and nickKey(liveNick) == nickKey(t.nick) then
            t.stale = nil
        end
        local wantKey = nk
        if wantKey ~= '' and key ~= wantKey then
            key = migrateThreadKey(key, wantKey)
            t = threads[key]
        end
    else
        key = nk ~= '' and nk or uniqueThreadKey('id' .. tostring(id or 0))
        t = {
            id = id or 0,
            nick = nick ~= '' and nick or ('ID:' .. tostring(id or '?')),
            lastId = id,
            status = 'open',
            pinned = false,
            unread = 0,
            lastAt = os.time(),
            messages = {},
        }
        threads[key] = t
        threadOrder[#threadOrder + 1] = key
        registerNickIndex(key, t)
        markDirtyThreads()
        pruneOldThreads()
    end
    registerNickIndex(key, t)
    return key, t
end

function getThreadByKey(key)
    if not key then return nil end
    return threads[key]
end

function getSelectedThread()
    if selectedKey and threads[selectedKey] then
        local t = threads[selectedKey]
        selectedId = tonumber(t.id) or -1
        return t, selectedKey
    end
    selectedKey = nil
    selectedId = -1
    return nil, nil
end

function resolveThreadForPlayerId(id, preferNick)
    id = tonumber(id)
    if not id then return nil, nil end
    preferNick = trim(preferNick or '')
    if preferNick == '' then
        preferNick = liveNickForPlayerId(id)
    end
    if preferNick ~= '' then
        local key, t = resolveThread(preferNick, id)
        if t and tonumber(t.id) == id and not t.stale then
            return t, key
        end
    end
    local matches = findThreadsByPlayerId(id)
    local live = liveNickForPlayerId(id)
    local liveNk = nickKey(live)
    if liveNk ~= '' then
        for _, e in ipairs(matches) do
            if not e.t.stale and nickKey(e.t.nick) == liveNk then
                return e.t, e.key
            end
        end
    end
    if selectedKey and threads[selectedKey] then
        local st = threads[selectedKey]
        if tonumber(st.id) == id and not st.stale then
            return st, selectedKey
        end
    end
    if #matches == 1 and not matches[1].t.stale then
        return matches[1].t, matches[1].key
    end
    if #matches > 1 and preferNick ~= '' then
        local want = nickKey(preferNick)
        for _, e in ipairs(matches) do
            if not e.t.stale and nickKey(e.t.nick) == want then
                return e.t, e.key
            end
        end
    end
    if #matches > 1 then
        table.sort(matches, function(a, b)
            if a.t.stale ~= b.t.stale then return not a.t.stale end
            return (a.t.lastAt or 0) > (b.t.lastAt or 0)
        end)
    end
    if #matches > 0 and not matches[1].t.stale then
        return matches[1].t, matches[1].key
    end
    local key = tostring(id)
    if threads[key] and not threads[key].stale then
        return threads[key], key
    end
    return nil, nil
end

function getResolvedAnsId(t)
    if not t then return -1 end
    local live = findPlayerIdByNick(t.nick)
    if live ~= nil then
        if t.id ~= live then
            t.lastId = t.id
            t.id = live
            markDirtyThreads()
        end
        return live
    end
    return tonumber(t.id) or -1
end

function resolveAnsIdForReply(t)
    if not t then return nil, '\xCD\xE5 \xE2\xFB\xE1\xF0\xE0\xED \xE4\xE8\xE0\xEB\xEE\xE3' end
    local rid = tonumber(t.id)
    if rid and rid >= 0 and type(sampIsPlayerConnected) == 'function' and sampIsPlayerConnected(rid) then
        local liveNick = sampGetPlayerNickname(rid) or ''
        if liveNick == '' or nickKey(liveNick) == nickKey(t.nick) then
            if t.id ~= rid then
                t.lastId = t.id
                t.id = rid
                markDirtyThreads()
            end
            return rid, nil
        end
    end
    return validateReplyTarget(t)
end

function validateReplyTarget(t)
    if not t then return nil, '\xCD\xE5 \xE2\xFB\xE1\xF0\xE0\xED \xE4\xE8\xE0\xEB\xEE\xE3' end
    local liveId = findPlayerIdByNick(t.nick)
    if liveId == nil then
        return nil, '\xC8\xE3\xF0\xEE\xEA \xED\xE5 \xE2 \xF1\xE5\xF2\xE8'
    end
    local liveNick = sampGetPlayerNickname(liveId) or ''
    if nickKey(liveNick) ~= nickKey(t.nick) then
        return nil, '\xCD\xE8\xEA \xED\xE5 \xF1\xEE\xE2\xEF\xE0\xE4\xE0\xE5\xF2'
    end
    if t.id ~= liveId then
        t.lastId = t.id
        t.id = liveId
        markDirtyThreads()
    end
    return liveId, nil
end

function getThread(id)
    id = tonumber(id)
    if not id then return nil end
    for _, t in pairs(threads) do
        if tonumber(t.id) == id then return t end
    end
    local key = tostring(id)
    return threads[key]
end

function findThreadByPlayerId(id, preferNick)
    local t = resolveThreadForPlayerId(id, preferNick)
    return t
end

function touchThreadOrder(key)
    for i, k in ipairs(threadOrder) do
        if k == key then
            table.remove(threadOrder, i)
            break
        end
    end
    table.insert(threadOrder, 1, key)
    bumpThreadListRev()
end

function requestChatScrollBottom()
    chatScrollToBottom = true
    deskInputState.chatScrollFrames = 2
end

function requestChatScrollForThread(threadKey)
    if threadKey and threadKey == selectedKey then
        requestChatScrollBottom()
    end
end

function addMessageToKey(key, msg)
    local t = threads[key]
    if not t then return end
    t.messages[#t.messages + 1] = msg
    trimMessages(t.messages)
    t.lastAt = msg.ts or os.time()
    markDirtyThreads()
    bumpThreadListRev()
    invalidateUiCaches()
end

function addMessage(id, msg)
    local t = getThread(id)
    if not t then return end
    for key, th in pairs(threads) do
        if th == t then
            addMessageToKey(key, msg)
            return
        end
    end
end

function resetSessionUnread()
    totalUnread = 0
    for _, t in pairs(threads) do
        t.unread = 0
    end
end

function rebuildThreadOrder()
    threadOrder = {}
    local list = {}
    for key, t in pairs(threads) do
        list[#list + 1] = { key = key, lastAt = t.lastAt or 0, pinned = t.pinned }
    end
    table.sort(list, function(a, b)
        if a.pinned ~= b.pinned then return a.pinned end
        return a.lastAt > b.lastAt
    end)
    for _, e in ipairs(list) do
        threadOrder[#threadOrder + 1] = e.key
    end
    rebuildNickIndex()
    bumpThreadListRev()
    invalidateUiCaches()
end

function countThreads()
    local n = 0
    for _ in pairs(threads) do n = n + 1 end
    return n
end

function pruneOldThreads()
    local maxT = math.max(50, tonumber(settings.max_threads) or DEFAULT_MAX_THREADS)
    local n = countThreads()
    if n <= maxT then return end
    local list = {}
    for key, t in pairs(threads) do
        list[#list + 1] = { key = key, lastAt = t.lastAt or 0, pinned = t.pinned == true }
    end
    table.sort(list, function(a, b) return a.lastAt < b.lastAt end)
    for _, e in ipairs(list) do
        if n <= maxT then break end
        if not e.pinned and e.key ~= selectedKey then
            clearThreadRuleCooldowns(e.key)
            pendingAuto[e.key] = nil
            threads[e.key] = nil
            n = n - 1
        end
    end
    rebuildThreadOrder()
    markDirtyThreads()
end
