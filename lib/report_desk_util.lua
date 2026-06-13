--[[ РњРѕРґСѓР»СЊ: РѕР±С‰РёРµ СѓС‚РёР»РёС‚С‹ (СЃС‚СЂРѕРєРё, РєРѕРґРёСЂРѕРІРєРё, ingest dedup, sendChat, Р·РІСѓРєРё). ]]



function trim(s)

    return (s or ''):match('^%s*(.-)%s*$') or ''

end



-- Encoding helpers: report_desk_util_encoding.lua (same core_a chunk)

-- CP1251 в†’ UTF-8 РґР»СЏ ImGui (uiText).

function uiText(s)

    return cp1251ToUtf8(s or '')

end



function deskCallHookPrev(fn, ...)

    if type(fn) ~= 'function' then return end

    local results = {pcall(fn, ...)}

    if not results[1] then

        print('[Report Desk] hook chain: ' .. tostring(results[2]))

        return

    end

    return unpack(results, 2)

end



-- РџРѕРІСЂРµР¶РґС‘РЅРЅР°СЏ РєРѕРґРёСЂРѕРІРєР° (UTF-8 replacement / В«РїС—Р…В» РїРѕСЃР»Рµ РґРІРѕР№РЅРѕР№ РєРѕРЅРІРµСЂС‚Р°С†РёРё).

function looksCorruptedConfigText(s)

    if type(s) ~= 'string' then s = tostring(s or '') end

    if s == '' then return false end

    if s:find('\239\191\189', 1, true) then return true end

    local preview = cp1251ToUtf8(s)

    if preview:find('\239\191\189', 1, true) then return true end

    if preview:find('РїС—', 1, true) then return true end

    return false

end



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



-- РќРѕСЂРјР°Р»РёР·Р°С†РёСЏ С‚РµРєСЃС‚Р° РїСЂРё Р·Р°РіСЂСѓР·РєРµ/СЃРѕС…СЂР°РЅРµРЅРёРё config.

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



-- Р§С‚РµРЅРёРµ ImGui InputText (UTF-8) в†’ CP1251 РґР»СЏ SAMP.

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



-- РЈР±РёСЂР°РµС‚ SAMP color tags {RRGGBB}.

function stripTags(s)

    return (s or ''):gsub('{[%x]+}', '')

end



-- SAMP color в†’ uint32 (РѕС‚СЂРёС†Р°С‚РµР»СЊРЅС‹Рµ int32 в†’ unsigned).

function normColor(c)

    if not c then return 0 end

    c = tonumber(c) or 0

    if c < 0 then c = c + 4294967296 end

    return c

end



-- SAMP int32 0xRRGGBBAA в†’ {RRGGBB} (GetPlayerColor >>> 8).

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



-- РљСЌС€ clist: onPlayerJoin / onSetPlayerColor / onPlayerStreamIn (РєР°Рє РІ TAB).

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



function sampSyncAllPlayerColorsAsync(onDone)

    if type(lua_thread) ~= 'table' or type(lua_thread.create) ~= 'function' then

        pcall(sampSyncAllPlayerColors)

        if onDone then pcall(onDone) end

        return

    end

    lua_thread.create(function()

        local okRun, errRun = pcall(function()

            if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return end

            if type(sampIsPlayerConnected) ~= 'function' or type(sampGetPlayerColor) ~= 'function' then return end

            local maxId = 1000

            if type(sampGetMaxPlayerId) == 'function' then

                local okM, m = pcall(sampGetMaxPlayerId)

                if okM and m then maxId = tonumber(m) or maxId end

            end

            local chunk = 50

            for startId = 0, maxId, chunk do

                local endId = math.min(startId + chunk - 1, maxId)

                for id = startId, endId do

                    if sampIsPlayerConnected(id) then

                        local ok, c = pcall(sampGetPlayerColor, id)

                        if ok and c then sampStorePlayerColor(id, c) end

                    end

                end

                wait(0)

            end

        end)

        if not okRun then

            print('[Report Desk] sampSyncAllPlayerColorsAsync: ' .. tostring(errRun))

        end

        if onDone then pcall(onDone) end

    end)

end



function isReportColor(color)

    local c = normColor(color)

    if REPORT_COLORS[c] then return true end

    if c == normColor(REPORT_COLOR) then return true end

    return false

end



function stripChatTimestamp(line)

    line = line or ''

    -- [HH:MM:SS] РІ server message / С‡Р°С‚Рµ

    line = line:gsub('^%[%d+:%d+:%d+%]%s*', '')

    -- [DD.MM.YYYY HH:MM:SS] РІ sampGetChatString (poll)

    line = line:gsub('^%[%d%d%.%d%d%.%d%d%d%d%s+%d+:%d+:%d+%]%s*', '')

    return line

end



-- Lowercase РґР»СЏ match (Lua :lower() РЅРµ С‚СЂРѕРіР°РµС‚ cp1251 РєРёСЂРёР»Р»РёС†Сѓ).

function cp1251Lower(s)

    if not s or s == '' then return '' end

    if isUtf8Text(s) then

        s = utf8ToCp1251(s)

    end

    return (s:gsub('[\192-\223]', function(c)

        return string.char(c:byte() + 32)

    end):gsub('\168', '\184'))

end



-- РЎРЅСЏС‚СЊ РѕР±С‘СЂС‚РѕС‡РЅСѓСЋ РїСѓРЅРєС‚СѓР°С†РёСЋ/РїСЂРѕР±РµР»С‹ (РЎРїР°СЃРёР±Рѕ! ), !!!, В«СЃРїР°СЃРёР±РѕВ»).

local function isMatchEdgeByte(b)

    if not b then return false end

    if b == 0x20 or (b >= 0x09 and b <= 0x0D) then return true end

    if b >= 0x21 and b <= 0x2F then return true end

    if b >= 0x3A and b <= 0x40 then return true end

    if b >= 0x5B and b <= 0x60 then return true end

    if b >= 0x7B and b <= 0x7E then return true end

    if b == 0x85 or b == 0x96 or b == 0x97 or b == 0xAB or b == 0xBB then return true end

    return false

end



function peelMatchEdges(s)

    if not s or s == '' then return '' end

    local from, to = 1, #s

    while from <= to and isMatchEdgeByte(s:byte(from)) do from = from + 1 end

    while to >= from and isMatchEdgeByte(s:byte(to)) do to = to - 1 end

    return s:sub(from, to)

end



function normalizeIngestBody(body)

    return cp1251Lower(trim(stripTags(body or '')))

end



-- РўРёРїРёС‡РЅС‹Рµ РѕРїРµС‡Р°С‚РєРё РІ СЂРµРїРѕСЂС‚Р°С… РґР»СЏ fuzzy match РїСЂР°РІРёР».

local MATCH_TYPO_WORDS = {

    ['СЂР°Р±РѕР°С‚СЊ'] = 'СЂР°Р±РѕС‚Р°С‚СЊ',

    ['СЂР°Р±РѕС‚Р°СЊ'] = 'СЂР°Р±РѕС‚Р°С‚СЊ',

    ['СЂРѕР±РѕС‚Р°С‚СЊ'] = 'СЂР°Р±РѕС‚Р°С‚СЊ',

    ['РіРѕСЃСЃ'] = 'РіРѕСЃ',

    ['Р°Р°С‚РѕР±СѓСЃ'] = 'Р°РІС‚РѕР±СѓСЃ',

    ['Р°Р°С‚РѕР±СѓСЃРЅРёРєРѕРј'] = 'Р°РІС‚РѕР±СѓСЃРЅРёРєРѕРј',

    ['Р·Р°С‰РёС‚Р°Р»Рѕ'] = 'Р·Р°СЃС‡РёС‚Р°Р»Рѕ',

    ['РґР°Р»СЊРЅР°Р±РѕР№'] = 'РґР°Р»СЊРЅРѕР±РѕР№',

    ['РґР°Р»РЅРѕР±РѕР№'] = 'РґР°Р»СЊРЅРѕР±РѕР№',

    ['РјРµС…Р°РёРє'] = 'РјРµС…Р°РЅРёРє',

    ['РѕР±СЊСЏРІР»РµРЅРёРµ'] = 'РѕР±СЉСЏРІР»РµРЅРёРµ',

    ['СЃРєРёР»С‹'] = 'СЃРєРёР»Р»С‹',

    ['inventar'] = 'РёРЅРІРµРЅС‚Р°СЂСЊ',

    ['РїСЂРѕРІРµРёС‚СЊ'] = 'РїСЂРѕРІРµСЂРёС‚СЊ',

    ['РїСЂСЃРјРѕС‚СЂРµС‚СЊ'] = 'РїРѕСЃРјРѕС‚СЂРµС‚СЊ',

    ['РєР°РєРёРєРІРµСЃС‚С‹'] = 'РєР°Рє РєРІРµСЃС‚С‹',

    ['СЂРµРјРєРѕРјР»РµРєС‚'] = 'СЂРµРјРєРѕРјРїР»РµРєС‚',

    ['РіРґ'] = 'РіРґРµ',

    ['Р·РґРµР»Р°С‚СЊ'] = 'СЃРґРµР»Р°С‚СЊ',

    ['РµРєСЂР°РЅ'] = 'СЌРєСЂР°РЅ',

    ['СЂРѕР±РѕС‚Р°РµС‚'] = 'СЂР°Р±РѕС‚Р°РµС‚',

    ['РѕС‚РµР»'] = 'РѕС‚РµР»СЊ',

    ['СѓСЃС‚СЂРѕРёС‚СЃСЏ'] = 'СѓСЃС‚СЂРѕРёС‚СЊСЃСЏ',

    ['С‚СЂР°РјРІР°Р№С‡РёРє'] = 'С‚СЂР°РјРІР°Р№',

    ['РїСЃСЌ'] = 'РїСЃРµ',

    ['РёРґС‘С‚'] = 'РёРґРµС‚',

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



-- РўСЂРё РІР°СЂРёР°РЅС‚Р° С‚РµРєСЃС‚Р° РґР»СЏ trigger match (exact / lower / typo).

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

    deskCache.scenarioBtnSig = nil

    deskCache.scenarioBtnIdx = nil

    deskCache.wrapTextSpaceW = nil

    if type(deskCache.intentResolve) == 'table' then

        deskCache.intentResolve = {}

    end

end



function markUiCacheDirty()

    deskCache.uiCacheDirty = true

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

    if not key then return end

    invalidateFilterCache()

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



function bumpScenariosGen(preferLegacyScenarios)

    scenariosGen = scenariosGen + 1

    deskCache.quickBtnGen = -1

    deskCache.quickBtn = {}

    deskCache.scenarioBtnSig = nil

    deskCache.scenarioBtnIdx = nil

    if type(reloadDeskIntentsFromSources) == 'function' then

        pcall(reloadDeskIntentsFromSources, preferLegacyScenarios == true)

    end

end



-- LRU cache: РїСЂРѕРёР·РІРѕР»СЊРЅРѕРµ value, eviction РїРѕ maxEntries.

function touchLruCache(map, order, key, value, maxEntries)

    if not key or key == '' then return end

    maxEntries = tonumber(maxEntries) or MAX_TIMED_MAP_ENTRIES

    if map[key] then

        for i, k in ipairs(order) do

            if k == key then

                table.remove(order, i)

                break

            end

        end

    end

    map[key] = value

    order[#order + 1] = key

    while #order > maxEntries do

        local old = table.remove(order, 1)

        if old then map[old] = nil end

    end

end



-- LRU-РїРѕРґРѕР±РЅР°СЏ timed map СЃ РїРѕСЂСЏРґРєРѕРј eviction.

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



-- Stale deferred admin-reply keys (poll safety path; hook usually clears on success).

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



-- РџРµСЂРёРѕРґРёС‡РµСЃРєР°СЏ РѕС‡РёСЃС‚РєР° dedup-РєР°СЂС‚ (ingest, auto, outbound echo, profanity).

function pruneAllTimedMaps()

    pruneTimedMap(RECENT.ingest, RECENT.ingestOrd, TIMED_MAP_MAX_AGE)

    pruneTimedMap(RECENT.auto, RECENT.autoOrd, TIMED_MAP_MAX_AGE)

    pruneTimedMap(RECENT.out, RECENT.outOrd, TIMED_MAP_MAX_AGE)

    pruneTimedMap(RECENT.prof, RECENT.profOrd, TIMED_MAP_MAX_AGE)

    if type(deskCache.remoteChatDedup) == 'table' and type(deskCache.remoteChatDedupOrd) == 'table' then

        pruneTimedMap(deskCache.remoteChatDedup, deskCache.remoteChatDedupOrd, TIMED_MAP_MAX_AGE)

    end

    pruneProfLineSeen()

    pruneChatSeenDeferred()

    local now = os.time()

    for k, untilTs in pairs(ruleCooldowns) do

        if not untilTs or untilTs <= now then

            ruleCooldowns[k] = nil

        end

    end

    local qb = deskCache.quickBtn

    if type(qb) == 'table' then

        local qbN = 0

        for _ in pairs(qb) do qbN = qbN + 1 end

        if qbN > 256 then

            deskCache.quickBtn = {}

            deskCache.quickBtnGen = -1

        end

    end

    local ir = deskCache.intentResolve

    if type(ir) == 'table' then

        local irN = 0

        for _ in pairs(ir) do irN = irN + 1 end

        if irN > 512 then

            deskCache.intentResolve = {}

            deskCache.intentResolveOrder = {}

        end

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

    if prev and (os.clock() - prev) < 6.0 then return true end  -- dedup auto-rules, СЃРµРє

    return false

end



function markAutoFired(t, body)

    touchTimedMap(RECENT.auto, RECENT.autoOrd, autoFireKey(t, body))

end



function normalizeChatLine(line)

    return trim(stripChatTimestamp(stripTags(line or '')))

end



-- РљР»СЋС‡ poll/hook: С‚РѕР»СЊРєРѕ РЅРѕСЂРјР°Р»РёР·РѕРІР°РЅРЅС‹Р№ С‚РµРєСЃС‚ (РјРµС‚РєР° РІСЂРµРјРµРЅРё СЃРЅРёРјР°РµС‚СЃСЏ РІ normalizeChatLine).

function chatLineSeenKey(line)

    local plain = normalizeChatLine(line)

    if plain == '' then return '' end

    return plain

end



-- Р’РѕР·СЂР°СЃС‚ СЃС‚СЂРѕРєРё С‡Р°С‚Р° РїРѕ [Р§Р§:РњРњ:РЎРЎ] РёР»Рё [Р”Р”.РњРњ.Р“Р“Р“Р“ Р§Р§:РњРњ:РЎРЎ]; nil РµСЃР»Рё РјРµС‚РєРё РЅРµС‚.

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



local function deskPauseBlocksAutoReply()

    if deskAdminPlayerPaused() then return true end

    if isPauseMenuActive and isPauseMenuActive() then return true end

    if isGamePaused and isGamePaused() then return true end

    return false

end



-- РџРѕСЃР»Рµ AFK/pause: РЅРµ РїРµСЂРµРёРіСЂС‹РІР°С‚СЊ СѓР¶Рµ РѕР±СЂР°Р±РѕС‚Р°РЅРЅС‹Рµ СЃС‚СЂРѕРєРё Р±СѓС„РµСЂР° С‡Р°С‚Р°.

-- NO-API: chat buffer poll fallback for anti-replay after pause.

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



-- РњРѕР¶РЅРѕ Р»Рё СЃР»Р°С‚СЊ auto-reply (РЅРµ РїР°СѓР·Р°, SAMP РґРѕСЃС‚СѓРїРµРЅ).

function deskAutoReplyAllowed()

    if not isSampAvailable() then return false end

    if deskPauseBlocksAutoReply() then return false end

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

    local paused = deskPauseBlocksAutoReply()

    local was = deskAdminPauseTracked

    if paused and not was then

        if type(clearPendingAutoConfirm) == 'function' then

            pcall(clearPendingAutoConfirm)

        end

    elseif was and not paused then

        pcall(deskSyncChatSeenAfterResume)

    end

    deskAdminPauseTracked = paused

end



-- ESC / pause menu вЂ” СЃРєСЂС‹С‚СЊ РёРіСЂРѕРІС‹Рµ HUD-РѕРІРµСЂР»РµРё Report Desk.

function deskGameMenuOpen()

    if isPauseMenuActive and isPauseMenuActive() then return true end

    if isGamePaused and isGamePaused() then return true end

    return false

end



-- Р›РѕРєР°Р»СЊРЅС‹Р№ РёРіСЂРѕРє Р·Р°СЃРїawnРёР»СЃСЏ (РЅРµ РјРµРЅСЋ РїРѕРґРєР»СЋС‡РµРЅРёСЏ / Р·Р°РіСЂСѓР·РєР°).

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



-- РџСЂРё СЃС‚Р°СЂС‚Рµ РїРѕРјРµС‡Р°РµС‚ С‚РµРєСѓС‰РёР№ Р±СѓС„РµСЂ С‡Р°С‚Р° РєР°Рє В«СѓР¶Рµ РІРёРґРµРЅРЅС‹Р№В» (anti-replay poll).

-- NO-API: chat buffer poll at startup for anti-replay.

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



-- Unix time РІ РјРѕСЃРєРѕРІСЃРєРѕР№ TZ (UTC+3).

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



-- РџРѕРґСЃС‚Р°РЅРѕРІРєР° {time}/{date}/{datetime}/{id} РІ С€Р°Р±Р»РѕРЅС‹ РѕС‚РІРµС‚РѕРІ.

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

    template = template:gsub('{id}', tostring(playerId or ''))

    return ensureWireCp1251(template)

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



-- Р­РєСЂР°РЅРЅС‹Рµ РєРѕРѕСЂРґРёРЅР°С‚С‹ РєСѓСЂСЃРѕСЂР° (РЅРµ Р·Р°РІРёСЃСЏС‚ РѕС‚ imgui.DisableInput).

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



-- require()-РјРѕРґСѓР»Рё (/sp menu, vehicle HUD) С‡РёС‚Р°СЋС‚ РёР· _G, РЅРµ РёР· bundle env.

_G.deskWin32MousePos = deskWin32MousePos

_G.deskPointInRect = deskPointInRect

_G.deskPointerInRect = deskPointerInRect



function sendChat(line)

    line = trim(line)

    if line == '' then return false end

    local cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line

    local ansHookBump = false

    if cmdBody:match('^ans%s') then

        local ansId, ansBody = cmdBody:match('^ans%s+(%d+)%s+(.*)$')

        if ansId and ansBody and ansBody ~= '' then

            ansBody = ensureWireCp1251(ansBody)

            local prefix = line:sub(1, 1) == '/' and '/ans ' or 'ans '

            line = prefix .. ansId .. ' ' .. ansBody

            cmdBody = line:sub(1, 1) == '/' and line:sub(2) or line

        end

        if type(helpStatsRecordAns) == 'function' then

            pcall(helpStatsRecordAns)

        end

        if type(deskCache) == 'table' then

            deskCache.skipAnsStatsHook = (tonumber(deskCache.skipAnsStatsHook) or 0) + 1

            ansHookBump = true

        end

    end

    local spId = cmdBody:match('^sp%s+(%d+)%s*$')

    if spId and type(deskSpectateStats) == 'table' and deskSpectateStats.markPendingSpCommand then

        local skip = deskCache and tonumber(deskCache.skipSpHookLocal) and deskCache.skipSpHookLocal > 0

        if not skip then

            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spId), '')

        end

    end

    if line:sub(1, 1) ~= '/' then line = '/' .. line end

    local function releaseAnsHookSkip()

        if not ansHookBump or type(deskCache) ~= 'table' then return end

        local n = (tonumber(deskCache.skipAnsStatsHook) or 0) - 1

        deskCache.skipAnsStatsHook = n > 0 and n or nil

    end

    if type(sampSendChat) ~= 'function' then

        releaseAnsHookSkip()

        return false

    end

    local ok = pcall(sampSendChat, line)

    releaseAnsHookSkip()

    return ok

end



local specSessionMod



-- РњРµРЅСЋ /sp: sampSendChat РёРґС‘С‚ С‡РµСЂРµР· onSendCommand вЂ” skipSpHookLocal РЅРµ РґСѓР±Р»РёСЂСѓРµС‚ Р»РѕРєР°Р»СЊРЅС‹Р№ /sp.

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

    local isStCmd = cmdBody:match('^st%s+%d+') ~= nil

    if isStCmd and type(cache) == 'table' then

        cache.skipStStatsHook = (tonumber(cache.skipStStatsHook) or 0) + 1

    end

    local function skipPendingSp()

        if skipPendingMark then return true end

        return type(cache) == 'table' and tonumber(cache.skipSpHookLocal) and cache.skipSpHookLocal > 0

    end

    if sampTextInputBusy() then

        if not specSessionMod then

            local okReq, mod = pcall(require, 'report_desk_spectate_session')

            specSessionMod = okReq and mod or false

        end

        local spIdBusy = cmdBody:match('^sp%s+(%d+)%s*$')

        if spIdBusy and not skipPendingSp()

                and type(deskSpectateStats) == 'table'

                and deskSpectateStats.markPendingSpCommand then

            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spIdBusy), '')

        end

        if specSessionMod and specSessionMod.queueOutbound then

            pcall(specSessionMod.queueOutbound, cmdBody)

        end

        if type(cache) == 'table' then

            local n = (tonumber(cache.skipSpHookLocal) or 0) - 1

            cache.skipSpHookLocal = n > 0 and n or nil

            if isStCmd then

                local sn = (tonumber(cache.skipStStatsHook) or 0) - 1

                cache.skipStStatsHook = sn > 0 and sn or nil

            end

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

    local ok = false

    if type(sendChat) == 'function' then

        local callOk, sent = pcall(sendChat, line)

        ok = callOk and sent ~= false

    end

    if type(cache) == 'table' then

        local n = (tonumber(cache.skipSpHookLocal) or 0) - 1

        cache.skipSpHookLocal = n > 0 and n or nil

        if isStCmd then

            local sn = (tonumber(cache.skipStStatsHook) or 0) - 1

            cache.skipStStatsHook = sn > 0 and sn or nil

        end

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

