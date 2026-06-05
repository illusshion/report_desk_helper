--[[ Report Desk utilities ]]
function trim(s)
    return (s or ''):match('^%s*(.-)%s*$') or ''
end

function uiText(s)
    if not s or s == '' then return '' end
    if s:find('[\208-\209][\128-\191]') then return s end
    local ok, r = pcall(function() return u8(s) end)
    return ok and r or s
end

function cp1251ToUtf8(text)
    if not text or text == '' then return '' end
    if text:find('[\208-\209][\128-\191]') then return text end
    local ok, r = pcall(function() return u8(text) end)
    return ok and r or text
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

function normalizeStoredText(s, fromUtf8)
    if not s or s == '' then return '' end
    if fromUtf8 then return utf8ToCp1251(s) end
    return s
end

function configStoreText(s)
    if not s or s == '' then return '' end
    return cp1251ToUtf8(s)
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

function stripTags(s)
    return (s or ''):gsub('{[%x]+}', '')
end

function normColor(c)
    if not c then return 0 end
    c = tonumber(c) or 0
    if c < 0 then c = c + 4294967296 end
    return c
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

function matchMessageVariants(body)
    local msg = normalizeMatchText(body)
    local msgAlt = normalizeIngestBody(body)
    local msgTypo = normalizeMatchTextTypo(body)
    return msg, msgAlt, msgTypo
end

function markDirtySettings()
    dirtySettings = true
end

function markDirtyThreads()
    dirtyThreads = true
end

function invalidateUiCaches()
    deskCache.filterKeys = nil
    deskCache.filterSig = ''
    deskCache.quickBtn = {}
    deskCache.quickBtnGen = -1
end

function bumpThreadListRev()
    deskCache.threadRev = deskCache.threadRev + 1
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
    if prev and (os.clock() - prev) < 6.0 then return true end
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

function deskAutoReplyAllowed()
    if not isSampAvailable() then return false end
    if isPauseMenuActive and isPauseMenuActive() then return false end
    if isGamePaused and isGamePaused() then return false end
    return true
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

function sendChat(line)
    line = trim(line)
    if line == '' then return false end
    if line:sub(1, 1) ~= '/' then line = '/' .. line end
    if type(sampSendChat) ~= 'function' then return false end
    return pcall(sampSendChat, line)
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

