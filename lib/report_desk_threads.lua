--[[ Модуль: треды репортов, сообщения, unread. ]]
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
        if t and not t._storageKey then t._storageKey = key end
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
            _storageKey = key,
        }
        threads[key] = t
        threadOrder[#threadOrder + 1] = key
        threadCount = threadCount + 1
        registerNickIndex(key, t)
        markDirtyThreads()
        bumpThreadStructRev()
        if threadCount > DEFAULT_MAX_THREADS then
            deskCache.deferThreadPrune = true
        end
    end
    registerNickIndex(key, t)
    return key, t
end

-- Thread By Key
function getThreadByKey(key)
    if not key then return nil end
    return threads[key]
end

-- Resolve Thread Report Channel
function resolveThreadReportChannel(t)
    if not t then return nil end
    local ch = deskIngest.normalizeReportChannel(t.reportChannel)
    if ch then return ch end
    if type(t.messages) ~= 'table' then return nil end
    for i = #t.messages, 1, -1 do
        local m = t.messages[i]
        if m and m.dir == 'in' then
            local kind = m.kind
            if kind == 'player' or kind == nil then
                ch = deskIngest.extractReportChannel(m.channel)
                    or deskIngest.extractReportChannel(m.raw)
                if ch then
                    t.reportChannel = ch
                    return ch
                end
            end
        end
    end
    return nil
end

-- Selected Thread
function getSelectedThread()
    if selectedKey and threads[selectedKey] then
        return threads[selectedKey], selectedKey
    end
    selectedKey = nil
    return nil, nil
end

-- Selected Id
function getSelectedId()
    local t = getSelectedThread()
    return t and tonumber(t.id) or -1
end

-- Resolve Thread For Player Id
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
    if #matches > 1 and preferNick ~= '' then
        local want = nickKey(preferNick)
        for _, e in ipairs(matches) do
            if not e.t.stale and nickKey(e.t.nick) == want then
                return e.t, e.key
            end
        end
    end
    if selectedKey and threads[selectedKey] then
        local st = threads[selectedKey]
        if tonumber(st.id) == id and not st.stale then
            local want = preferNick ~= '' and nickKey(preferNick) or liveNk
            if want == '' or nickKey(st.nick) == want then
                return st, selectedKey
            end
        end
    end
    if #matches == 1 and not matches[1].t.stale then
        return matches[1].t, matches[1].key
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

-- Resolved Ans Id
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

-- Resolve Ans Id For Reply
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

-- Validate Reply Target
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

-- Thread
function getThread(id)
    id = tonumber(id)
    if not id then return nil end
    for _, t in pairs(threads) do
        if tonumber(t.id) == id then return t end
    end
    local key = tostring(id)
    return threads[key]
end

-- Find Thread By Player Id
function findThreadByPlayerId(id, preferNick)
    local t = resolveThreadForPlayerId(id, preferNick)
    return t
end

-- Touch Thread Order
function touchThreadOrder(key)
    for i, k in ipairs(threadOrder) do
        if k == key then
            table.remove(threadOrder, i)
            break
        end
    end
    table.insert(threadOrder, 1, key)
    bumpThreadStructRev()
end

-- Request Chat Scroll Bottom
function requestChatScrollBottom()
    if not deskInputState.chatFollowBottom then return end
    deskInputState.chatScrollUntil = os.clock() + 0.35
end

-- Request Chat Snap Bottom
function requestChatSnapBottom(key)
    if not key then return end
    deskInputState.snapPending = true
    deskInputState.snapKey = key
    deskInputState.chatFollowBottom = true
    deskInputState.hasUnseenMessages = false
    deskInputState.chatScrollUntil = os.clock() + 0.5
end

-- Request Chat Scroll For Thread
function requestChatScrollForThread(threadKey)
    if threadKey and threadKey == selectedKey then
        requestChatScrollBottom()
    end
end

-- Add Message To Key
function addMessageToKey(key, msg)
    local t = threads[key]
    if not t then return end
    if type(normalizeStoredMessage) == 'function' then
        normalizeStoredMessage(msg)
    end
    t.messages[#t.messages + 1] = msg
    trimMessages(t.messages)
    t.lastAt = msg.ts or os.time()
    if type(lastPreview) == 'function' then
        t._previewText = lastPreview(t)
    end
    markDirtyThreads()
    bumpThreadMsgRev()
    bumpThreadInFilterCache(key)
    if key == selectedKey and type(deskCache) == 'table' then
        deskCache.scenarioBtnSig = nil
        deskCache.scenarioBtnIdx = nil
    end
    if key == selectedKey then
        if deskInputState.chatFollowBottom then
            requestChatScrollForThread(key)
        else
            deskInputState.hasUnseenMessages = true
        end
    end
end

-- Add Message
function addMessage(id, msg, keyHint)
    if keyHint and threads[keyHint] then
        addMessageToKey(keyHint, msg)
        return
    end
    local t = getThread(id)
    if not t then return end
    local key = t._storageKey
    if key and threads[key] == t then
        addMessageToKey(key, msg)
        return
    end
    for k, th in pairs(threads) do
        if th == t then
            t._storageKey = k
            addMessageToKey(k, msg)
            return
        end
    end
end

-- Reset Session Unread
function resetSessionUnread()
    totalUnread = 0
    for _, t in pairs(threads) do
        t.unread = 0
    end
end

-- Rebuild Thread Order
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
    syncThreadStorageKeys()
    rebuildNickIndex()
    syncThreadCount()
    bumpThreadStructRev()
end

-- Count Threads
function countThreads()
    return threadCount
end

-- Prune Old Threads
function pruneOldThreads()
    local maxT = DEFAULT_MAX_THREADS
    local n = threadCount
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
            threadCount = n
        end
    end
    rebuildThreadOrder()
    markDirtyThreads()
end
