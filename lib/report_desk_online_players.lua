--[[ Модуль: SSOT онлайн-игроков nick<->id (event-driven, без polling). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

onlinePlayersById = type(onlinePlayersById) == 'table' and onlinePlayersById or {}

function onlinePlayersClear()
    playerNickToId = {}
    onlinePlayersById = {}
    playerNickCacheAt = 0
end

function onlinePlayersOnJoin(playerId, nick)
    playerId = tonumber(playerId)
    nick = trim(nick or '')
    if not playerId or nick == '' then return false end
    local key = nickKey(nick)
    if key == '' then return false end
    local prevId = playerNickToId[key]
    if prevId and prevId ~= playerId then
        onlinePlayersById[prevId] = nil
    end
    local prevNick = onlinePlayersById[playerId]
    if prevNick and prevNick ~= key then
        playerNickToId[prevNick] = nil
    end
    playerNickToId[key] = playerId
    onlinePlayersById[playerId] = key
    return true
end

function onlinePlayersOnQuit(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    local key = onlinePlayersById[playerId]
    if key then
        if playerNickToId[key] == playerId then
            playerNickToId[key] = nil
        end
        onlinePlayersById[playerId] = nil
        return true
    end
    for nk, id in pairs(playerNickToId) do
        if id == playerId then
            playerNickToId[nk] = nil
            return true
        end
    end
    return false
end

function onlinePlayersRescan(force)
    local now = os.clock()
    if not force and playerNickCacheAt > 0
            and (now - playerNickCacheAt) < (PLAYER_NICK_CACHE_INTERVAL or 2.0) then
        return false
    end
    playerNickCacheAt = now
    playerNickToId = {}
    onlinePlayersById = {}
    if not isSampAvailable() then return true end
    local maxId = MAX_PLAYER_ID
    if sampGetMaxPlayerId then
        maxId = sampGetMaxPlayerId(false) or maxId
    end
    for i = 0, maxId do
        if sampIsPlayerConnected(i) then
            local pn = sampGetPlayerNickname(i)
            if pn then
                onlinePlayersOnJoin(i, pn)
            end
        end
    end
    if type(syncThreadIdsFromPlayerCache) == 'function' then
        syncThreadIdsFromPlayerCache()
    end
    return true
end

function onlinePlayersGetIdByNick(nick)
    local nk = nickKey(nick or '')
    if nk == '' then return nil end
    local id = playerNickToId[nk]
    if id and sampIsPlayerConnected and sampIsPlayerConnected(id) then
        return id
    end
    return nil
end

function onlinePlayersGetNickById(playerId)
    playerId = tonumber(playerId)
    if not playerId then return '' end
    local key = onlinePlayersById[playerId]
    if key and playerNickToId[key] == playerId then
        if sampIsPlayerConnected and sampIsPlayerConnected(playerId) and sampGetPlayerNickname then
            return trim(sampGetPlayerNickname(playerId) or '')
        end
    end
    if sampIsPlayerConnected and sampIsPlayerConnected(playerId) and sampGetPlayerNickname then
        return trim(sampGetPlayerNickname(playerId) or '')
    end
    return ''
end

function onlinePlayersCount()
    local n = 0
    for id, key in pairs(onlinePlayersById) do
        if key and playerNickToId[key] == id then
            if not sampIsPlayerConnected or sampIsPlayerConnected(id) then
                n = n + 1
            end
        end
    end
    return n
end
