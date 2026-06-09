--[[ Модуль: общие утилиты (строки, кодировки, ingest dedup, sendChat, звуки). ]]

function trim(s)
    return (s or ''):match('^%s*(.-)%s*$') or ''
end

-- CP1251 → UTF-8 для ImGui (uiText).
function uiText(s)
    return cp1251ToUtf8(s or '')
end

-- CP1251 → UTF-8 для ImGui DrawList (toast profanity, auto-rules preview).
function catalogWarmupDlUtf(text)
    return uiText(text or '')
end

function cp1251ToUtf8(text)
    if not text or text == '' then return '' end
    if text:find('\239\191\189', 1, true) then return text end
    if isUtf8Text(text) then return text end
    local ok, r = pcall(function() return u8(text) end)
    if ok and r and r ~= '' and not r:find('\239\191\189', 1, true) then
        return r
    end
    return text
end

function utf8ToCp1251(text)
    if not text or text == '' then return '' end
    if not text:find('[\208-\209][\128-\191]') then return text end
    local ok, r = pcall(function() return u8:decode(text) end)
    return ok and r or text
end

function isUtf8Text(s)
    return type(s) == 'string' and s:find('[\208-\209][\128-\191]') ~= nil
end

-- Безопасный вызов предыдущего хука в цепочке SAMP (изоляция ошибок чужих скриптов).
function deskCallHookPrev(fn, ...)
    if type(fn) ~= 'function' then return end
    local results = {pcall(fn, ...)}
    if not results[1] then
        print('[Report Desk] hook chain: ' .. tostring(results[2]))
        return
    end
    return unpack(results, 2)
end

-- Повреждённая кодировка (UTF-8 replacement / «пїЅ» после двойной конвертации).
function looksCorruptedConfigText(s)
    if type(s) ~= 'string' then s = tostring(s or '') end
    if s == '' then return false end
    if s:find('\239\191\189', 1, true) then return true end
    local preview = cp1251ToUtf8(s)
    if preview:find('\239\191\189', 1, true) then return true end
    if preview:find('пї', 1, true) then return true end
    return false
end

-- Нормализация текста при загрузке/сохранении config.
function normalizeStoredText(s, fromUtf8)
    if not s or s == '' then return '' end
    if fromUtf8 or isUtf8Text(s) then return utf8ToCp1251(s) end
    return s
end

-- Восстановление текста настроек при битой кодировке в config.
function repairStoredConfigText(s, fallback)
    s = trim(s or '')
    if s == '' or looksCorruptedConfigText(s) then
        return fallback or ''
    end
    return normalizeStoredText(s, isUtf8Text(s))
end

function configStoreText(s)
    if type(s) ~= 'string' then s = tostring(s or '') end
    if s == '' then return '' end
    if looksCorruptedConfigText(s) then return '' end
    local u = cp1251ToUtf8(s)
    if looksCorruptedConfigText(u) then return s end
    return u
end

function luaQuoteUtf8(s)
    return string.format('%q', configStoreText(s or ''))
end

function rulesHasContent(list)
    if type(list) ~= 'table' then return false end
    for _, r in ipairs(list) do
        if trim(r.name or '') ~= '' then return true end
    end
    return false
end

function scenariosHasContent(list)
    if type(list) ~= 'table' then return false end
    for _, sc in ipairs(list) do
        if trim(sc.label or '') ~= ''
            or trim(sc.reply or '') ~= ''
            or #(sc.keywords or {}) > 0
            or sc.action == 'watch' then
            return true
        end
    end
    return false
end

function profanityHasContent(list)
    if type(list) ~= 'table' then return false end
    for _, w in ipairs(list) do
        if trim(w or '') ~= '' then return true end
    end
    return false
end

-- Чтение ImGui InputText (UTF-8) → CP1251 для SAMP.
function readInputBuf(buf)
    local ok, s = pcall(function()
        return ffi.string(buf):match('^[^%z]*') or ''
    end)
    s = ok and s or ''
    return utf8ToCp1251(s)
end

function setInputBuf(buf, cp1251Text)
    cp1251Text = cp1251Text or ''
    ffi.copy(buf, cp1251ToUtf8(cp1251Text))
end

function toU32(col)
    return imgui.ColorConvertFloat4ToU32(col)
end

-- Убирает SAMP color tags {RRGGBB}.
function stripTags(s)
    return (s or ''):gsub('{[%x]+}', '')
end

-- SAMP color → uint32 (отрицательные int32 → unsigned).
function normColor(c)
    if not c then return 0 end
    c = tonumber(c) or 0
    if c < 0 then c = c + 4294967296 end
    return c
end

-- SAMP int32 0xRRGGBBAA → {RRGGBB} (GetPlayerColor >>> 8).
function sampColorToChatHex(c)
    c = normColor(c)
    if c == 0 then return nil end
    if bit then
        return string.format('%06X', bit.band(bit.rshift(c, 8), 0xFFFFFF))
    end
    return string.format('%06X', math.floor(c / 256) % 0x1000000)
end

function chatHexToImVec4(hex)
    hex = tostring(hex or ''):gsub('[{}%s]', ''):upper()
    if #hex ~= 6 then return nil end
    local r = tonumber(hex:sub(1, 2), 16)
    local g = tonumber(hex:sub(3, 4), 16)
    local b = tonumber(hex:sub(5, 6), 16)
    if not r or not g or not b then return nil end
    if not imgui or not imgui.ImVec4 then return nil end
    return imgui.ImVec4(r / 255, g / 255, b / 255, 1.0)
end

function sampColorToImVec4(color)
    color = normColor(color)
    if color == 0 then return nil end
    if not imgui or not imgui.ImVec4 then return nil end
    local bb = bit.band(color, 0xFF)
    local gg = bit.band(bit.rshift(color, 8), 0xFF)
    local rr = bit.band(bit.rshift(color, 16), 0xFF)
    local aa = bit.band(bit.rshift(color, 24), 0xFF)
    if aa == 0 then aa = 255 end
    return imgui.ImVec4(rr / 255, gg / 255, bb / 255, aa / 255)
end

-- Кэш clist: onPlayerJoin / onSetPlayerColor / onPlayerStreamIn (как в TAB).
function sampStorePlayerColor(playerId, color)
    if type(deskCache) ~= 'table' then return end
    if type(deskCache.sampPlayerColors) ~= 'table' then
        deskCache.sampPlayerColors = {}
    end
    playerId = tonumber(playerId)
    if not playerId or playerId < 0 then return end
    color = normColor(color)
    if color == 0 then return end
    deskCache.sampPlayerColors[playerId] = color
end

function sampClearPlayerColor(playerId)
    if type(deskCache) ~= 'table' or type(deskCache.sampPlayerColors) ~= 'table' then return end
    playerId = tonumber(playerId)
    if playerId then deskCache.sampPlayerColors[playerId] = nil end
end

function sampPlayerColorChatHex(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId < 0 then return nil end
    local colors = type(deskCache) == 'table' and deskCache.sampPlayerColors
    local c = colors and colors[playerId]
    if not c and type(sampGetPlayerColor) == 'function' and type(sampIsPlayerConnected) == 'function' then
        if sampIsPlayerConnected(playerId) then
            local ok, live = pcall(sampGetPlayerColor, playerId)
            if ok and live then
                sampStorePlayerColor(playerId, live)
                c = deskCache.sampPlayerColors[playerId]
            end
        end
    end
    if c and c ~= 0 then return sampColorToChatHex(c) end
    return nil
end

function sampSyncAllPlayerColors()
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return end
    if type(sampIsPlayerConnected) ~= 'function' or type(sampGetPlayerColor) ~= 'function' then return end
    local maxId = 1000
    if type(sampGetMaxPlayerId) == 'function' then
        local ok, m = pcall(sampGetMaxPlayerId)
        if ok and m then maxId = tonumber(m) or maxId end
    end
    for id = 0, maxId do
        if sampIsPlayerConnected(id) then
            local ok, c = pcall(sampGetPlayerColor, id)
            if ok and c then sampStorePlayerColor(id, c) end
        end
    end
end

function isReportColor(color)
    local c = normColor(color)
    if REPORT_COLORS[c] then return true end
    if c == normColor(REPORT_COLOR) then return true end
    return false
end

function stripChatTimestamp(line)
    line = line or ''
    -- [HH:MM:SS] в server message / чате
    line = line:gsub('^%[%d+:%d+:%d+%]%s*', '')
    -- [DD.MM.YYYY HH:MM:SS] в sampGetChatString (poll)
    line = line:gsub('^%[%d%d%.%d%d%.%d%d%d%d%s+%d+:%d+:%d+%]%s*', '')
    return line
end

function normalizeIngestBody(body)
    return trim(stripTags(body or '')):lower()
end

-- Типичные опечатки в репортах для fuzzy match правил.
local MATCH_TYPO_WORDS = {
    ['рабоать'] = 'работать',
    ['работаь'] = 'работать',
    ['роботать'] = 'работать',
    ['госс'] = 'гос',
    ['аатобус'] = 'автобус',
    ['аатобусником'] = 'автобусником',
    ['защитало'] = 'засчитало',
    ['дальнабой'] = 'дальнобой',
    ['далнобой'] = 'дальнобой',
    ['мехаик'] = 'механик',
    ['обьявление'] = 'объявление',
    ['скилы'] = 'скиллы',
    ['inventar'] = 'инвентарь',
}

function normalizeMatchTextTypo(s)
    s = normalizeMatchText(s)
    if s == '' then return s end
    local words = {}
    for w in s:gmatch('%S+') do
        w = w:gsub('aa', 'a'):gsub('oo', 'o'):gsub('ii', 'i'):gsub('ss', 's')
        w = MATCH_TYPO_WORDS[w] or w
        words[#words + 1] = w
    end
    return table.concat(words, ' ')
end

-- Три варианта текста для trigger match (exact / lower / typo).
function matchMessageVariants(body)
    local msg = normalizeMatchText(body)
    local msgAlt = normalizeIngestBody(body)
    local msgTypo = normalizeMatchTextTypo(body)
    return msg, msgAlt, msgTypo
end

function cancelScheduledConfigFlush()
    if type(deskCache) == 'table' then deskCache.configFlushAt = 0 end
end

function scheduleDirtyConfigFlush()
    if type(deskCache) == 'table' then
        deskCache.configFlushAt = os.clock() + 4.0
    end
end

function tickScheduledConfigFlush()
    if type(deskCache) ~= 'table' then return end
    local at = tonumber(deskCache.configFlushAt) or 0
    if at <= 0 or os.clock() < at then return end
    deskCache.configFlushAt = 0
    if type(flushDirtyConfigNow) == 'function' then
        pcall(flushDirtyConfigNow)
    end
end

function markDirtySettings()
    dirtySettings = true
    scheduleDirtyConfigFlush()
end

function markDirtyThreads()
    dirtyThreads = true
    scheduleDirtyConfigFlush()
end

function invalidateUiCaches()
    deskCache.filterKeys = nil
    deskCache.filterSig = ''
    deskCache.quickBtn = {}
    deskCache.quickBtnGen = -1
end

function invalidateFilterCache()
    deskCache.filterKeys = nil
    deskCache.filterSig = ''
end

function bumpThreadStructRev()
    deskCache.threadStructRev = (deskCache.threadStructRev or 0) + 1
    deskCache.threadRev = deskCache.threadStructRev
    invalidateFilterCache()
end

function bumpThreadMsgRev()
    deskCache.threadMsgRev = (deskCache.threadMsgRev or 0) + 1
end

function bumpThreadListRev()
    bumpThreadStructRev()
end

function syncThreadCount()
    local n = 0
    for _ in pairs(threads) do n = n + 1 end
    threadCount = n
end

function syncThreadStorageKeys()
    for key, t in pairs(threads) do
        if t then
            t._storageKey = key
            if type(lastPreview) == 'function' and not t._previewText then
                t._previewText = lastPreview(t)
            end
        end
    end
end

function threadSortBefore(a, b)
    local ta, tb = threads[a], threads[b]
    if not ta or not tb then return a < b end
    if ta.pinned ~= tb.pinned then return ta.pinned end
    return (ta.lastAt or 0) > (tb.lastAt or 0)
end

function findFilterInsertPos(keys, key)
    for i = 1, #keys do
        if threadSortBefore(key, keys[i]) then return i end
    end
    return #keys + 1
end

function bumpThreadInFilterCache(key)
    if not key or not deskCache.filterKeys then return end
    if type(getFilterListSig) ~= 'function' then return end
    if type(threadMatchesFilter) ~= 'function' or type(threadMatchesSearch) ~= 'function' then return end
    local sig = getFilterListSig()
    if deskCache.filterSig ~= sig then return end
    local t = threads[key]
    if not t then return end
    local keys = deskCache.filterKeys
    for i = #keys, 1, -1 do
        if keys[i] == key then
            table.remove(keys, i)
            break
        end
    end
    if threadMatchesFilter(t) and threadMatchesSearch(t, key) then
        table.insert(keys, findFilterInsertPos(keys, key), key)
    end
end

function invalidateEllipsizeCache()
    deskCache.ellipsize = {}
    deskCache.ellipsizeOrder = {}
end

local ELLIPSIZE_CACHE_MAX = 512

function ellipsizeCacheGet(cacheKey)
    return deskCache.ellipsize[cacheKey]
end

function ellipsizeCachePut(cacheKey, value)
    if deskCache.ellipsize[cacheKey] then return end
    deskCache.ellipsize[cacheKey] = value
    local order = deskCache.ellipsizeOrder
    order[#order + 1] = cacheKey
    while #order > ELLIPSIZE_CACHE_MAX do
        local old = table.remove(order, 1)
        if old then deskCache.ellipsize[old] = nil end
    end
end

function bumpComposerQuickGen()
    deskCache.composerQuickGen = (deskCache.composerQuickGen or 0) + 1
    deskCache.composerQuickItems = nil
end

function rebuildNickIndex()
    deskCache.nickKeys = {}
    for key, t in pairs(threads) do
        local nk = nickKey(t.nick)
        if nk ~= '' and not deskCache.nickKeys[nk] then
            deskCache.nickKeys[nk] = key
        end
    end
end

function bumpScenariosGen()
    scenariosGen = scenariosGen + 1
    deskCache.quickBtnGen = -1
    deskCache.quickBtn = {}
end

-- LRU-подобная timed map с порядком eviction.
function touchTimedMap(map, order, key)
    if not key or key == '' then return end
    local now = os.clock()
    if map[key] then
        for i, k in ipairs(order) do
            if k == key then
                table.remove(order, i)
                break
            end
        end
    end
    map[key] = now
    order[#order + 1] = key
    while #order > MAX_TIMED_MAP_ENTRIES do
        local old = table.remove(order, 1)
        if old then map[old] = nil end
    end
end

function pruneTimedMap(map, order, maxAgeSec)
    local now = os.clock()
    for i = #order, 1, -1 do
        local key = order[i]
        local ts = map[key]
        if not ts or (now - ts) > maxAgeSec then
            map[key] = nil
            table.remove(order, i)
        end
    end
    while #order > MAX_TIMED_MAP_ENTRIES do
        local old = table.remove(order, 1)
        if old then map[old] = nil end
    end
end

function pruneProfLineSeen()
    local n = 0
    for _ in pairs(deskCache.profLineSeen) do n = n + 1 end
    if n > MAX_TIMED_MAP_ENTRIES then
        deskCache.profLineSeen = {}
    end
end

-- Периодическая очистка dedup-карт (ingest, auto, outbound echo, profanity).
function pruneAllTimedMaps()
    pruneTimedMap(RECENT.ingest, RECENT.ingestOrd, TIMED_MAP_MAX_AGE)
    pruneTimedMap(RECENT.auto, RECENT.autoOrd, TIMED_MAP_MAX_AGE)
    pruneTimedMap(RECENT.out, RECENT.outOrd, TIMED_MAP_MAX_AGE)
    pruneTimedMap(RECENT.prof, RECENT.profOrd, TIMED_MAP_MAX_AGE)
    pruneProfLineSeen()
    local now = os.time()
    for k, untilTs in pairs(ruleCooldowns) do
        if not untilTs or untilTs <= now then
            ruleCooldowns[k] = nil
        end
    end
    if #deskCache.quickBtn > 256 then
        deskCache.quickBtn = {}
        deskCache.quickBtnGen = -1
    end
end

function ingestDedupKey(id, body, rawLine)
    return deskIngest.ingestDedupKey(id, body, rawLine, normalizeIngestBody)
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

function autoFireKey(t, body)
    local tk = findThreadKeyByNick(t.nick) or nickKey(t.nick)
    local norm = normalizeMatchText(body)
    if norm == '' then norm = normalizeIngestBody(body) end
    return tk .. '|' .. norm
end

function shouldSkipAutoFire(t, body)
    local key = autoFireKey(t, body)
    local prev = RECENT.auto[key]
    if prev and (os.clock() - prev) < 6.0 then return true end  -- dedup auto-rules, сек
    return false
end

function markAutoFired(t, body)
    touchTimedMap(RECENT.auto, RECENT.autoOrd, autoFireKey(t, body))
end

function normalizeChatLine(line)
    return trim(stripChatTimestamp(stripTags(line or '')))
end

--[[
    Ключ для poll-лога: без метки времени два репорта "Nick[id]: time" сливаются в один.
    Для строк с [ЧЧ:ММ:СС] добавляем метку — каждый репорт в чате уникален.
]]
function chatLineSeenKey(line)
    local plain = normalizeChatLine(line)
    if plain == '' then return '' end
    local ts = (line or ''):match('(%[%d+:%d+:%d+%])')
    if ts then return plain .. '|' .. ts end
    return plain
end

function clearThreadRuleCooldowns(threadKey)
    threadKey = tostring(threadKey or '')
    if threadKey == '' then return end
    local prefix = threadKey .. ':'
    for k, _ in pairs(ruleCooldowns) do
        if k:sub(1, #prefix) == prefix then
            ruleCooldowns[k] = nil
        end
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

-- Можно ли слать auto-reply (не пауза, SAMP доступен).
function deskAutoReplyAllowed()
    if not isSampAvailable() then return false end
    if isPauseMenuActive and isPauseMenuActive() then return false end
    if isGamePaused and isGamePaused() then return false end
    if deskAdminPlayerPaused() then return false end
    return true
end

function deskAdminPlayerPaused()
    if not isSampAvailable() then return false end
    if type(sampIsPlayerPaused) ~= 'function' or type(sampGetPlayerIdByCharHandle) ~= 'function' then
        return false
    end
    if not PLAYER_PED or type(doesCharExist) ~= 'function' or not doesCharExist(PLAYER_PED) then
        return false
    end
    local ok, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if not ok or not myId then return false end
    local ok2, paused = pcall(sampIsPlayerPaused, myId)
    return ok2 and paused == true
end

local deskAdminPauseTracked = false

function deskTickAdminPauseState()
    local paused = deskAdminPlayerPaused()
    local was = deskAdminPauseTracked
    if paused and not was then
        if type(clearAllPendingAuto) == 'function' then
            pcall(clearAllPendingAuto)
        end
    elseif was and not paused then
        pcall(seedSeenChatLines)
    end
    deskAdminPauseTracked = paused
end

-- ESC / pause menu — скрыть игровые HUD-оверлеи Report Desk.
function deskGameMenuOpen()
    if isPauseMenuActive and isPauseMenuActive() then return true end
    if isGamePaused and isGamePaused() then return true end
    return false
end

-- Локальный игрок заспawnился (не меню подключения / загрузка).
function deskSampInGame()
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return false end
    if type(sampIsLocalPlayerSpawned) == 'function' then
        local ok, spawned = pcall(sampIsLocalPlayerSpawned)
        return ok and spawned == true
    end
    if type(sampGetGamestate) == 'function' then
        local ok, gs = pcall(sampGetGamestate)
        return ok and gs == 3
    end
    return false
end

-- При старте помечает текущий буфер чата как «уже виденный» (anti-replay poll).
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

function debugLog(color, text)
    if not settings.debug then return end
    local c = normColor(color)
    say(string.format('[dbg] color=%d text=%s', c, truncate(stripTags(text or ''), 80)))
end

function normalizeForMatch(s)
    s = stripTags(s):lower()
    s = s:gsub('[%p%c]', ' ')
    s = ' ' .. s:gsub('%s+', ' ') .. ' '
    return s
end

-- Unix time в московской TZ (UTC+3).
function moscowTimestamp()
    local now = os.time()
    local utc = os.time(os.date('!*t', now))
    local localOff = os.difftime(now, utc)
    return now + 3 * 3600 - localOff
end

function moscowDateParts()
    local ts = moscowTimestamp()
    local mdate = os.date('%B', ts)
    local ddate = os.date('%w', ts)
    local day = os.date('%d', ts)
    local year = os.date('%Y', ts)
    local month = deskCache.monthRu[mdate] or mdate
    local weekday = deskCache.weekdayRu[ddate] or ddate
    local time = os.date('%H:%M', ts)
    local dateOnly = string.format('%s, %s %s %s \xE3\xEE\xE4', weekday, day, month, year)
    local datetime = string.format('%s. %s', time, dateOnly)
    return time, dateOnly, datetime
end

-- Подстановка {time}/{date}/{datetime}/{id} в шаблоны ответов.
function expandTemplate(template, playerId)
    template = tostring(template or '')
    if template:find('{time}', 1, true) or template:find('{date}', 1, true)
        or template:find('{datetime}', 1, true) then
        local time, dateOnly, datetime = moscowDateParts()
        template = template
            :gsub('{time}', time)
            :gsub('{date}', dateOnly)
            :gsub('{datetime}', datetime)
    end
    return template:gsub('{id}', tostring(playerId or ''))
end

function drawTemplateTagsHint()
    imgui.TextColored(col_muted2, uiText(
        '\xD2\xE5\xE3\xE8 \xE2 \xF2\xE5\xEA\xF1\xF2\xE5 (\xEF\xEE\xE4\xF1\xF2\xE0\xE2\xEB\xFF\xFE\xF2\xF1\xFF \xEF\xF0\xE8 \xEE\xF2\xEF\xF0\xE0\xE2\xEA\xE5):'))
    imgui.TextWrapped(uiText('{datetime} \x97 \xE4\xE0\xF2\xE0 \xE8 \xE2\xF0\xE5\xEC\xFF \xEF\xEE \xCC\xCE\xC1'))
    imgui.TextWrapped(uiText('{time} \x97 \xF2\xEE\xEB\xFC\xEA\xEE \xE2\xF0\xE5\xEC\xFF (\xCD\xD7:\xCC\xCC)'))
    imgui.TextWrapped(uiText('{date} \x97 \xF2\xEE\xEB\xFC\xEA\xEE \xE4\xE0\xF2\xE0 (\xEF\xEE-\xF0\xF3\xF1\xF1\xEA\xE8)'))
    imgui.TextWrapped(uiText('{id} \x97 ID \xE8\xE3\xF0\xEE\xEA\xE0 \xE8\xE7 \xF0\xE5\xEF\xEE\xF0\xF2\xE0'))
    imgui.TextColored(col_muted, uiText(
        '\xCF\xF0\xE8\xEC\xE5\xF0: \xD2\xEE\xF7\xED\xEE\xE5 \xE2\xF0\xE5\xEC\xFF: {datetime}'))
    imgui.Dummy(imgui.ImVec2(0, 4))
end

local TEMPLATE_PAYLOAD_HINT = '{datetime} {time} {date} {id}'

-- Экранные координаты курсора (не зависят от imgui.DisableInput).
function deskWin32MousePos()
    if type(getCursorPos) == 'function' then
        local ok, x, y = pcall(getCursorPos)
        if ok and x and y then return x, y end
    end
    return nil, nil
end

function deskPointInRect(mx, my, r)
    if not r or mx == nil or my == nil then return false end
    return mx >= r.x0 and mx < r.x1 and my >= r.y0 and my < r.y1
end

function deskPointerInRect(r)
    local mx, my = deskWin32MousePos()
    return deskPointInRect(mx, my, r)
end

-- require()-модули (/sp menu, vehicle HUD) читают из _G, не из bundle env.
_G.deskWin32MousePos = deskWin32MousePos
_G.deskPointInRect = deskPointInRect
_G.deskPointerInRect = deskPointerInRect

function sendChat(line)
    line = trim(line)
    if line == '' then return false end
    local cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line
    local spId = cmdBody:match('^sp%s+(%d+)%s*$')
    if spId and type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSpCommand then
        local skip = deskCache and tonumber(deskCache.skipSpHookLocal) and deskCache.skipSpHookLocal > 0
        if not skip then
            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spId), '')
        end
    end
    if line:sub(1, 1) ~= '/' then line = '/' .. line end
    if type(sampSendChat) ~= 'function' then return false end
    return pcall(sampSendChat, line)
end

-- Меню /sp: sampSendChat идёт через onSendCommand — skipSpHookLocal не дублирует локальный /sp.
local function sampTextInputBusy()
    return (type(sampIsChatInputActive) == 'function' and sampIsChatInputActive())
        or (type(sampIsDialogActive) == 'function' and sampIsDialogActive())
end

function sendMenuOutbound(line, opts)
    line = trim(line)
    if line == '' then return false end
    opts = type(opts) == 'table' and opts or {}
    local quietSp = opts.quietSp == true
    local skipPendingMark = opts.skipPendingMark == true or quietSp
    local cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line
    local cache = rawget(_G, 'deskCache')
    if quietSp and type(cache) == 'table' then
        cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
    end
    local function skipPendingSp()
        if skipPendingMark then return true end
        return type(cache) == 'table' and tonumber(cache.skipSpHookLocal) and cache.skipSpHookLocal > 0
    end
    if sampTextInputBusy() then
        local spId = cmdBody:match('^sp%s+(%d+)%s*$')
        if spId and not skipPendingSp() and type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSpCommand then
            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spId), '')
        end
        pcall(function()
            local specSession = require 'report_desk_spectate_session'
            if specSession and specSession.queueOutbound then
                specSession.queueOutbound(cmdBody)
            end
        end)
        if quietSp and type(cache) == 'table' then
            local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
            cache.skipSpHookLocal = n > 0 and n or nil
        end
        return true
    end
    local spId = cmdBody:match('^sp%s+(%d+)%s*$')
    if spId and not skipPendingSp() and type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSpCommand then
        pcall(deskSpectateStats.markPendingSpCommand, tonumber(spId), '')
    end
    if type(cache) == 'table' and not quietSp then
        cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
    end
    local ok = sendChat(line)
    if type(cache) == 'table' then
        local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
        cache.skipSpHookLocal = n > 0 and n or nil
    end
    return ok
end

function playDeskAlertSound()
    pcall(function()
        if PLAYER_PED and doesCharExist(PLAYER_PED) then
            local x, y, z = getCharCoordinates(PLAYER_PED)
            addOneOffSound(x, y, z, PF.SOUND)
        end
    end)
    pcall(function() playSoundFrontEnd(PF.SOUND_FE) end)
end

function playNotify()
    if not settings.sound then return end
    playDeskAlertSound()
end

function playProfanityAlertSound()
    if settings.profanity_filter_sound == false then return end
    playDeskAlertSound()
end
