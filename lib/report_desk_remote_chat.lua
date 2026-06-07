--[[ Модуль «Дальний чат»: bubble/me/do → SAMP-чат [Bubble]. ]]

REMOTE_CHAT_BUBBLE_LOG = false
REMOTE_CHAT_FILTER_AUTO = true

remoteChatState = type(remoteChatState) == 'table' and remoteChatState or {
    ingestWindow = { t0 = 0, n = 0 },
    colorLogFile = nil,
}

local REMOTE_CHAT_SOURCES = {
    bubble = true,
    me = true,
    do_cmd = true,
}

if type(deskCache.remoteChatDedup) ~= 'table' then
    deskCache.remoteChatDedup = {}
end
if type(deskCache.remoteChatDedupOrd) ~= 'table' then
    deskCache.remoteChatDedupOrd = {}
end
if type(deskCache.remoteChatQueue) ~= 'table' then
    deskCache.remoteChatQueue = {}
end

local RC_QUEUE_MAX = 32

function ensureRemoteChatSettings()
    if settings.remote_chat_samp_mirror == nil then settings.remote_chat_samp_mirror = true end
end

local function remoteChatNormalizeBody(body)
    body = trim(stripTags(body or ''))
    if body == '' then return '' end
    if isUtf8Text and isUtf8Text(body) then
        body = utf8ToCp1251(body) or body
    end
    return body
end

local function remoteChatNormalizeSource(source)
    source = tostring(source or '')
    if source == 'do' then return 'do_cmd' end
    return source
end

function remoteChatNormalizeBubbleColor(c)
    if type(normColor) == 'function' then
        return normColor(c)
    end
    c = tonumber(c) or 0
    if c < 0 then c = c + 4294967296 end
    return c
end

-- SetPlayerChatBubble / ChatBubble RPC: 0xRRGGBBAA (не AARRGGBB, не low24).
function remoteChatSampColorBytes(c)
    c = remoteChatNormalizeBubbleColor(c)
    if bit then
        return {
            raw = c,
            rr = bit.band(bit.rshift(c, 24), 0xFF),
            gg = bit.band(bit.rshift(c, 16), 0xFF),
            bb = bit.band(bit.rshift(c, 8), 0xFF),
            aa = bit.band(c, 0xFF),
            low24 = bit.band(c, 0xFFFFFF),
        }
    end
    return {
        raw = c,
        rr = math.floor(c / 16777216) % 256,
        gg = math.floor(c / 65536) % 256,
        bb = math.floor(c / 256) % 256,
        aa = c % 256,
        low24 = c % 16777216,
    }
end

function remoteChatSampColorToEmbedHex(c)
    local b = remoteChatSampColorBytes(c)
    if not b or b.raw == 0 then return nil end
    return string.format('%02X%02X%02X', b.rr, b.gg, b.bb)
end

local function remoteChatSampColorToEmbedHexLow24(c)
    local b = remoteChatSampColorBytes(c)
    if not b or b.raw == 0 then return nil end
    local v = b.low24
    local rr = math.floor(v / 65536) % 256
    local gg = math.floor(v / 256) % 256
    local bb = v % 256
    return string.format('%02X%02X%02X', rr, gg, bb)
end

local function remoteChatColorLogPath()
    local wd = type(getWorkingDirectory) == 'function' and getWorkingDirectory() or ''
    return wd .. '\\config\\bubble_colors_log.txt'
end

local function remoteChatEnsureColorLogFile()
    if remoteChatState.colorLogFile then return remoteChatState.colorLogFile end
    local path = remoteChatColorLogPath()
    local f, err = io.open(path, 'a')
    if not f then
        print('[Report Desk] bubble color log open failed: ' .. tostring(err))
        return nil
    end
    remoteChatState.colorLogFile = f
    return f
end

function remoteChatLogBubble()
end

function logBubbleColor(playerId, message, bubbleColor)
    if REMOTE_CHAT_BUBBLE_LOG == false then return end
    playerId = tonumber(playerId) or -1
    message = tostring(message or '')
    local nick = '???'
    if type(sampGetPlayerNickname) == 'function' then
        local ok, n = pcall(sampGetPlayerNickname, playerId)
        if ok and n and n ~= '' then nick = n end
    end
    local preview = message
    if #preview > 40 then preview = preview:sub(1, 40) end
    local b = remoteChatSampColorBytes(bubbleColor)
    local embedHex = remoteChatSampColorToEmbedHex(bubbleColor) or ''
    local embedLow24 = remoteChatSampColorToEmbedHexLow24(bubbleColor) or ''
    local mlHex = ''
    if type(sampColorToChatHex) == 'function' then
        mlHex = sampColorToChatHex(bubbleColor) or ''
    end
    local msgEmbed
    if type(remoteChatExtractLeadingEmbed) == 'function' then
        msgEmbed = select(1, remoteChatExtractLeadingEmbed(message))
    end
    local clistRaw, clistEmbed = '', ''
    if type(sampPlayerColorChatHex) == 'function' and playerId >= 0 then
        clistEmbed = sampPlayerColorChatHex(playerId) or ''
        local cached = deskCache.sampPlayerColors and deskCache.sampPlayerColors[playerId]
        if cached then
            clistRaw = string.format('0x%08X', remoteChatNormalizeBubbleColor(cached))
        end
    end
    local byteLine = string.format(
        'RAW=%08X R=%02X G=%02X B=%02X A=%02X LOW24=%06X',
        b.raw, b.rr, b.gg, b.bb, b.aa, b.low24
    )
    local line = string.format(
        '[%s] %s[%d]: %s | %s | EMBED_RRGGBBAA={%s} EMBED_LOW24={%s} ML_HEX={%s} MSG_EMBED=%s | CLIST=%s {%s}\n',
        os.date('%H:%M:%S'),
        nick,
        playerId,
        preview,
        byteLine,
        embedHex,
        embedLow24,
        mlHex,
        tostring(msgEmbed or ''),
        clistRaw,
        clistEmbed
    )
    print('[BubbleColor] ' .. line:gsub('\n', ''))
    local f = remoteChatEnsureColorLogFile()
    if f then
        f:write(line)
        f:flush()
    end
end

-- CP1251 lower (Lua string.lower не работает с кириллицей в MoonLoader).
local function remoteChatLower(s)
    s = s or ''
    local out = {}
    for i = 1, #s do
        local b = s:byte(i)
        if b >= 0xC0 and b <= 0xDF then
            out[#out + 1] = string.char(b + 0x20)
        elseif b == 0xA8 then
            out[#out + 1] = '\xB8'
        else
            out[#out + 1] = string.char(b)
        end
    end
    return table.concat(out)
end

local function remoteChatContains(body, fragment)
    if body == '' or fragment == '' then return false end
    if body:find(fragment, 1, true) then return true end
    local lowBody = remoteChatLower(body)
    if lowBody:find(fragment, 1, true) then return true end
    if lowBody:find(remoteChatLower(fragment), 1, true) then return true end
    return false
end

-- CP1251 stems (bubble text is CP1251; UTF-8 literals never matched).
local RC_PAUSE = '\xED\xE0 \xEF\xE0\xF3\xE7\xE5'
local RC_RATING = '\xF0\xE5\xE9\xF2\xE8\xED\xE3:'

local REMOTE_CHAT_JUNK_STEMS = {
    "\xee\xf2\xf0\xe5\xec\xee\xed\xf2\xe8\xf0\xee\xe2",
    "\xee\xf2\xef\xf0\xe0\xe2\xeb\xff\xe5\xf2\x20\xee\xe1\xfa\xff\xe2\xeb\xe5\xed",
    "\xee\xf2\xef\xf0\xe0\xe2\xeb\xff\xe5\xf2\x20\xf1\xee\xee\xe1\xf9\xe5\xed\xe8\xe5",
    "\xef\xf0\xe5\xe4\xeb\xe0\xe3\xe0\xe5\xf2",
    "\xef\xf0\xee\xe2\xe5\xf0\xff\xe5\xf2",
    "\xf7\xe8\xf2\xe0\xe5\xf2\x20\xe3\xe0\xe7\xe5\xf2",
    "\xf0\xe0\xf1\xef\xe8\xf1\xe0\xeb",
    "\xe2\xe5\xf0\xed\xf3\xeb\xf1\xff",
    "\xe7\xe0\xea\xf0\xfb\xe2\xe0\xe5\xf2\x20\xf8\xeb\xe0\xe3\xe1\xe0\xf3\xec",
    "\xee\xf2\xea\xf0\xfb\xe2\xe0\xe5\xf2\x20\xf8\xeb\xe0\xe3\xe1\xe0\xf3\xec",
    "\xe8\xe3\xf0\xe0\xe5\xf2\x20\xf0\xe8\xed\xe3\xf2\xee\xed",
    "\xe7\xe2\xee\xed\xe8\xf2\x20\xe2\x20\xf1\xeb\xf3\xe6\xe1\xf3",
    "\xe0\xef\xef\xe0\xf0\xe0\xf2\xf3\xf0\xe0\x20\xe2\xea\xeb\xfe\xf7",
    "\xe2\xe7\xe3\xeb\xff\xed\xf3\xeb\x20\xed\xe0\x20\xf7\xe0\xf1\xfb",
    "\xe2\xe7\xff\xeb\x20\xed\xe0\xf3\xf8\xed\xe8\xea",
    "\xed\xe0\xe4\xe5\xeb\x20\xed\xe0\xf3\xf8\xed\xe8\xea",
    "\xe2\xea\xeb\xfe\xf7\xe8\xeb\x20\xe0\xef\xef\xe0\xf0\xe0\xf2\xf3\xf0\xf3",
    "\x6e\x6f\x6e\x2d\x72\x70",
    "\xf1\xee\xee\xe1\xf9\xe5\xed\xe8\xe5\x20\xef\xee\x20\xf0\xe0\xf6\xe8\xe8",
    "\xe7\xe0\xef\xf0\xe0\xe2\xeb",
    "\x72\x65\x66\x75\x65\x6c",
    "\xed\xe0\x20\xec\xe0\xf8\xe8\xed\xfb",
    "\xed\xe0\xe6\xec\xe8\x20\x6e",
    "\x2f\x73\x74\x61\x6e\x64",
    "\xe1\xe0\xed\xea\xee\xec\xe0\xf2",
    "\xf2\xf0\xe0\xed\xe7\xe0\xea\xf6",
    "\xef\xf0\xee\xe4\xe0\xe5\xf2\x20\xe3\xe0\xe7\xe5\xf2",
    "\xef\xf0\xee\xe4\xe0\xb8\xf2\x20\xe3\xe0\xe7\xe5\xf2",
    "\xef\xf0\xee\xe4\xe0\xe5\xf2\x20\xf1\xe5\xec",
    "\xef\xf0\xee\xe4\xe0\xb8\xf2\x20\xf1\xe5\xec",
    "\xea\xf3\xef\xe8\xf2\xfc\x20\xe3\xe0\xe7\xe5\xf2",
    "\xea\xf3\xef\xe8\xf2\xfc\x20\xf8\xe0\xf3\xf0\xec",
    "\xea\xf3\xef\xe8\xf2\xfc\x20\xff\xf9\xe8\xea",
    "\xf1\xf2\xee\xe8\xf2\x20\xed\xe0",
    "\xf1\xf2\xee\xe8\xf2\x20\xf3",
    "\xf2\xee\xf7\xed\xee\xe3\xee\x20\xe2\xf0\xe5\xec\xe5\xed",
    "\xf1\xeb\xf3\xe6\xe1\xf3\x20\xf2\xee\xf7\xed",
    "\xef\xe5\xf0\xe5\xee\xe4\xe5\xe2\xe0",
    "\xf1\xe0\xe4\xe8\xf2\xf1\xff",
    "\xf1\xe0\xe4\xe8\xf2\xf1\xff\x20\xe2",
    "\xeb\xe5\xe6\xe8\xf2",
    "\xe7\xe0\xf1\xfb\xef\xe0",
    "\xf0\xfb\xe1\xe0\xf7",
    "\xee\xf5\xee\xf2",
    "\xf2\xf0\xe5\xed\xe8\xf0",
    "\xef\xeb\xe0\xe2\xe0",
    "\xf0\xe0\xe7\xe3\xee\xe2\xe0\xf0\xe8\xe2\xe0",
    RC_PAUSE,
    "\x70\x61\x75\x73\x65",
    "\x61\x66\x6b",
    "\x72\x65\x70\x61\x69\x72",
    "\x73\x6d\x73",
    "\xf0\xe0\xf6\xe8\xe8",
}

local REMOTE_CHAT_RP_KEEP = {
    "\xf1\xec\xe5\xb8\xf2\xf1\xff",
    "\xf1\xec\xe5\xe5\xf2\xf1\xff",
    "\xf3\xeb\xfb\xe1\xe0\xe5\xf2\xf1\xff",
    "\xf5\xe8\xf5\xe8\xea\xe0\xe5\xf2",
    "\xf0\xfb\xe4\xe0\xe5\xf2",
    "\xef\xeb\xe0\xf7\xe5\xf2",
    "\xef\xeb\xe0\xf7\xb8\xf2",
    "\xea\xe8\xe2\xed\xf3\xeb",
    "\xea\xe8\xe2\xed\xf3\xeb\xe0",
    "\xec\xe0\xf8\xe5\xf2",
    "\xef\xf0\xe8\xf1\xe5\xeb",
    "\xef\xeb\xfe\xed\xf3\xeb\xe0",
    "\xef\xeb\xfe\xed\xf3\xeb",
    "\xef\xf0\xe8\xf1\xe5\xe4\xe0\xe5\xf2",
    "\xee\xe1\xed\xff\xeb",
    "\xee\xe1\xed\xff\xeb\xe0",
    "\xef\xee\xe6\xe0\xeb \xef\xeb\xe5\xf7\xe0\xec\xe8",
    "\xf2\xe0\xed\xf6\xf3\xe5\xf2",
    "\xef\xee\xe4\xec\xe8\xe3\xe8\xe2\xe0\xe5\xf2",
    "\xf0\xe0\xe7\xe2\xee\xe4\xe8\xf2 \xf0\xf3\xea\xe0\xec\xe8",
    "\x73\x68\x72\x75\x67",
    "\x6c\x61\x75\x67\x68",
    "\x73\x6d\x69\x6c\x65",
}

local function remoteChatIsRpEmotion(body)
    local low = remoteChatLower(body)
    for _, keep in ipairs(REMOTE_CHAT_RP_KEEP) do
        if remoteChatContains(body, keep) then return true end
    end
    if body:find('[?!]', 1) or body:find('"', 1, true) or body:find('\xAB', 1, true) then
        return true
    end
    return false
end

function remoteChatLooksLikeAutoAction(body)
    body = remoteChatNormalizeBody(body)
    if body == '' then return true end

    local low = remoteChatLower(body)
    if remoteChatIsRpEmotion(body) then return false end

    if remoteChatContains(body, RC_PAUSE) then return true end
    if remoteChatContains(body, 'pause') or remoteChatContains(body, 'afk') then return true end
    if low == 'repair' or low == 'refuel' or low == 'hunger' or low == 'thirst' then return true end

    if low:match('^sms') or remoteChatContains(body, 'sms>>>') or remoteChatContains(body, 'sms<<<') then
        return true
    end
    if body:find('<<<', 1, true) or body:find('>>>', 1, true) then
        if remoteChatContains(body, 'sms') then return true end
    end

    if body:match('^[%+%-]%d') then return true end
    if body:match('^[%+%-]%d+[$]') then return true end
    if remoteChatContains(body, RC_RATING) and remoteChatContains(body, 'hp') then return true end
    if body:match('^%+%d+%s*[Hh][Pp]') then return true end
    if #body <= 2 and body:match('^[%+%-%?!%.]$') then return true end

    for _, stem in ipairs(REMOTE_CHAT_JUNK_STEMS) do
        if remoteChatContains(body, stem) then return true end
    end

    if body:match('^[%a_]+$') and #body <= 28 then
        if low == 'repair' or low == 'refuel' or low == 'smoke' or low == 'drink'
                or low == 'eat' or low == 'sleep' or low == 'wash' or low == 'fuel' then
            return true
        end
    end

    return false
end

local function remoteChatShouldSkipBody(body, source)
    body = remoteChatNormalizeBody(body)
    if body == '' then return true, 'empty' end
    if bodyLooksLikeSystemChat and bodyLooksLikeSystemChat(body) then return true, 'system' end
    if deskIngest and deskIngest.looksLikePlayerStatusBody then
        if deskIngest.looksLikePlayerStatusBody(body) then return true, 'status' end
    end
    if REMOTE_CHAT_FILTER_AUTO and remoteChatLooksLikeAutoAction(body) then
        return true, 'auto_action'
    end
    return false, ''
end

local function remoteChatAllowsSource(source)
    return REMOTE_CHAT_SOURCES[remoteChatNormalizeSource(source)] == true
end

local function remoteChatBodyDedupToken(body)
    body = normalizeMatchText(remoteChatNormalizeBody(body))
    if body == '' then return '' end
    if remoteChatContains(body, RC_PAUSE) or remoteChatContains(body, 'pause')
            or remoteChatContains(body, 'afk') then
        return 'status'
    end
    return body
end

local function remoteChatDedupKey(nick, id, body)
    return nickKey(nick) .. '|' .. tostring(tonumber(id) or 0) .. '|' .. remoteChatBodyDedupToken(body)
end

local function remoteChatDedupWindow(body)
    local token = remoteChatBodyDedupToken(body)
    if token == 'status' then return RC.STATUS_DEDUP_SEC or 180 end
    return RC.DEDUP_SEC or 12
end

local function remoteChatIsDup(key, body)
    if key == '' then return false end
    local prev = deskCache.remoteChatDedup[key]
    if prev and (os.clock() - prev) < remoteChatDedupWindow(body) then
        return true
    end
    return false
end

local function remoteChatMarkDup(key)
    if key == '' then return end
    deskCache.remoteChatDedup[key] = os.clock()
    if touchTimedMap then
        touchTimedMap(deskCache.remoteChatDedup, deskCache.remoteChatDedupOrd, key)
    end
end

local function remoteChatRateOk()
    local now = os.clock()
    local w = remoteChatState.ingestWindow
    if not w or now - (w.t0 or 0) > 1.0 then
        remoteChatState.ingestWindow = { t0 = now, n = 0 }
        w = remoteChatState.ingestWindow
    end
    if (w.n or 0) >= (RC.INGEST_MAX_PER_SEC or 4) then return false end
    w.n = (w.n or 0) + 1
    return true
end

function remoteChatExtractLeadingEmbed(body)
    body = tostring(body or '')
    local hex, rest = body:match('^{([0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])}(.*)$')
    if hex then
        return string.upper(hex), rest
    end
    return nil, body
end

local RC_SAMP_TAG = '{9E7BEF}[B]{FFFFFF} '
local RC_SAMP_TAG_ME = '{9E7BEF}[Me]{FFFFFF} '
local RC_SAMP_TAG_DO = '{9E7BEF}[Do]{FFFFFF} '
local RC_SAMP_NICK = 'FFFFFF'
local RC_SAMP_BODY_FALLBACK = 'E8E8E8'
local RC_SAMP_MAX = 220
local RC_SAMP_BODY_SPEECH = 'CECECE'
local RC_SAMP_BODY_DISTANT = '999999'
local RC_SAMP_BODY_ACTION = 'DD90FF'
local RC_BUBBLE_SKIP_HEX = {
    ['FF0000'] = true,
}

local function remoteChatResolveBodyHex(source, colorHex, bubbleColor)
    source = remoteChatNormalizeSource(source)
    colorHex = colorHex or remoteChatBubbleToChatHex(bubbleColor, nil) or RC_SAMP_BODY_FALLBACK
    colorHex = string.upper(colorHex)

    if source == 'me' or source == 'do_cmd' then
        return colorHex
    end

    if RC_BUBBLE_SKIP_HEX[colorHex] then
        return RC_SAMP_BODY_FALLBACK
    end
    if colorHex == RC_SAMP_BODY_DISTANT then
        return RC_SAMP_BODY_DISTANT
    end
    if colorHex == RC_SAMP_BODY_ACTION then
        return RC_SAMP_BODY_ACTION
    end
    -- ARP: RPC 00CCFF — цвет bubble над головой; в SAMP-чате речь = CECECE.
    return RC_SAMP_BODY_SPEECH
end

local function remoteChatTrimBody(body, nick, id, source)
    body = trim(body or '')
    nick = trim(nick or '')
    id = tonumber(id) or 0
    source = remoteChatNormalizeSource(source)
    local overhead = 72 + #nick + (id > 0 and 10 or 0)
    if source == 'do_cmd' then overhead = overhead + 16 end
    local maxBody = RC_SAMP_MAX - overhead
    if maxBody < 32 then maxBody = 32 end
    if #body > maxBody then
        body = body:sub(1, maxBody - 3) .. '...'
    end
    return body
end

function remoteChatBubbleToChatHex(bubbleColor, embedHex)
    if type(embedHex) == 'string' and #embedHex == 6 then
        return string.upper(embedHex)
    end
    local hex = remoteChatSampColorToEmbedHex(bubbleColor)
    if hex and hex ~= '' then return hex end
    return RC_SAMP_BODY_FALLBACK
end

local function remoteChatSampTag(source)
    source = remoteChatNormalizeSource(source)
    if source == 'me' then return RC_SAMP_TAG_ME end
    if source == 'do_cmd' then return RC_SAMP_TAG_DO end
    return RC_SAMP_TAG
end

local function remoteChatFormatNickId(clistHex, nick, id)
    clistHex = clistHex or RC_SAMP_NICK
    id = tonumber(id) or 0
    if id > 0 then
        return string.format('{%s}%s[%d]', clistHex, nick, id)
    end
    return string.format('{%s}%s', clistHex, nick)
end

function remoteChatTryAppend(nick, id, body, source, lineKey, profanity, bubbleColor, embedHex)
    if settings.remote_chat_samp_mirror == false then return false end
    if not remoteChatAllowsSource(source) then return false end
    nick = trim(nick or '')
    if not embedHex then
        embedHex, body = remoteChatExtractLeadingEmbed(body)
    end
    body = remoteChatNormalizeBody(body)
    if nick == '' or body == '' then return false end
    local skip, _ = remoteChatShouldSkipBody(body, source)
    if skip then return false end
    if not remoteChatRateOk() then return false end

    local dkey = remoteChatDedupKey(nick, id, body)
    if remoteChatIsDup(dkey, body) then return false end
    remoteChatMarkDup(dkey)

    bubbleColor = remoteChatNormalizeBubbleColor(bubbleColor)
    local colorHex = remoteChatBubbleToChatHex(bubbleColor, embedHex)
    if RC_BUBBLE_SKIP_HEX[colorHex] then return false end

    local clistHex = RC_SAMP_NICK
    local cached = deskCache.sampPlayerColors and deskCache.sampPlayerColors[tonumber(id) or -1]
    if cached and type(sampColorToChatHex) == 'function' then
        clistHex = sampColorToChatHex(cached) or clistHex
    end
    clistHex = string.upper(clistHex)

    local q = deskCache.remoteChatQueue
    if #q >= RC_QUEUE_MAX then
        table.remove(q, 1)
    end
    q[#q + 1] = {
        nick = nick,
        id = tonumber(id) or 0,
        body = body,
        source = source,
        profanity = profanity == true,
        bubbleColor = bubbleColor,
        embedHex = embedHex,
        colorHex = colorHex,
        clistHex = clistHex,
    }
    return true
end

function remoteChatFlushSampQueue()
    local q = deskCache.remoteChatQueue
    if type(q) ~= 'table' or #q == 0 then return end
    local batch = q
    deskCache.remoteChatQueue = {}
    for i = 1, #batch do
        local it = batch[i]
        if it and it.body and it.body ~= '' then
            pcall(remoteChatPrintSampLine, it.nick, it.id, it.body, it.source, it.profanity,
                it.bubbleColor, it.colorHex, it.clistHex)
        end
    end
end

function remoteChatClearQueue()
    if type(deskCache.remoteChatQueue) == 'table' then
        deskCache.remoteChatQueue = {}
    end
end

function remoteChatSetMirrorEnabled(enabled)
    ensureRemoteChatSettings()
    settings.remote_chat_samp_mirror = enabled ~= false
    if settings.remote_chat_samp_mirror == false then
        remoteChatClearQueue()
    end
end

function remoteChatPrintSampLine(nick, id, body, source, profanity, bubbleColor, colorHex, clistHex)
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return false end
    if type(sampAddChatMessage) ~= 'function' then return false end
    nick = trim(nick or '?')
    nick = nick:gsub('[{}]', '')
    id = tonumber(id) or 0
    source = remoteChatNormalizeSource(source)
    body = remoteChatTrimBody(body, nick, id, source)
    if body == '' then return false end

    clistHex = string.upper(tostring(clistHex or RC_SAMP_NICK))
    if clistHex == RC_SAMP_NICK then
        local cached = deskCache.sampPlayerColors and deskCache.sampPlayerColors[id]
        if cached and type(sampColorToChatHex) == 'function' then
            clistHex = string.upper(sampColorToChatHex(cached) or RC_SAMP_NICK)
        end
    end
    local bodyHex = remoteChatResolveBodyHex(source, colorHex, bubbleColor)
    if profanity then bodyHex = 'FF6666' end

    local tag = remoteChatSampTag(source)
    local nickPart = remoteChatFormatNickId(clistHex, nick, id)
    local line
    if source == 'do_cmd' then
        line = string.format(
            '%s{%s}%s{FFFFFF} (( %s ))',
            tag, bodyHex, body, nickPart)
    elseif source == 'me' then
        line = string.format(
            '%s%s {%s}%s',
            tag, nickPart, bodyHex, body)
    else
        line = string.format(
            '%s%s: {%s}%s',
            tag, nickPart, bodyHex, body)
    end
    local ok = pcall(sampAddChatMessage, line, -1)
    return ok == true
end
