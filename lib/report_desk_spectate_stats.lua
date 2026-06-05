--[[ Spectate /st stats: parse SP line + stat dialog, HUD overlay ]]
local M = {}

local imgui = require 'mimgui'

local SP_MSG_COLOR = 1728027135
local PENDING_ST_SEC = 12.0
local AUTO_ST_COOLDOWN = 8.0
local SPEC_STEP_COOLDOWN = 0.35
local MAX_SPEC_PLAYER_ID = 1000
local lastSpecStepAt = 0

local trim, stripTags, sendChat, uiText, toU32
local col_accent, col_muted, col_muted2, col_label, col_warn
local sampIsPlayerConnected, sampGetPlayerNickname, sampGetPlayerColor
local sampGetPlayerPing, sampGetPlayerScore
local inputDeps

local function specPlayerActive()
    return inputDeps and inputDeps.getPlayerSpectating and inputDeps.getPlayerSpectating()
end

local CACHE_MAX = 128

local state = {
    targetId = -1,
    targetNick = '',
    pendingStId = nil,
    pendingStAt = 0,
    lastAutoStAt = 0,
    cache = {},
    cacheOrder = {},
    hudDrag = { active = false, offX = 0, offY = 0 },
    hudHovered = false,
    hudPlaced = false,
    persistHudId = -1,
}

local HUD_PANEL_W = 292
local HUD_LABEL_W = 108
local HUD_PAD_X = 10

local HUD_FIELD_ORDER = {
    'ping', 'level', 'family', 'org', 'rank', 'job', 'warns', 'wanted', 'money', 'score', 'status',
}

local FIELD_LABELS = {
    level = '\xD3\xF0\xEE\xE2\xE5\xED\xFC',
    ping = 'Ping',
    family = '\xD1\xE5\xEC\xFC\xFF',
    org = '\xCE\xF0\xE3\xE0\xED\xE8\xE7\xE0\xF6\xE8\xFF',
    rank = '\xD0\xE0\xED\xE3',
    job = '\xD0\xE0\xE1\xEE\xF2\xE0',
    warns = '\xCF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4\xE5\xED\xE8\xFF',
    wanted = '\xD0\xEE\xE7\xFB\xF1\xEA',
    money = '\xCD\xE0\xEB\xE8\xF7\xED\xFB\xE5',
    score = '\xCE\xF7\xEA\xE8',
    status = '\xD1\xF2\xE0\xF2\xF3\xF1',
    exp = '\xCE\xEF\xFB\xF2',
    bank = '\xC1\xE0\xED\xEA',
    gender = '\xCF\xEE\xEB',
    phone = '\xD2\xE5\xEB\xE5\xF4\xEE\xED',
}

local function low(s)
    s = trim(s or '')
    if s == '' then return '' end
    return s:lower()
end

local function vec4(r, g, b, a)
    return imgui.ImVec4(r, g, b, a or 1.0)
end

local FACTION_NICK_COLORS = {
    {
        vec4(0.22, 0.48, 0.98),
        'мвд', 'mvd', 'lspd', 'police', 'polic', 'sfpd', 'lvpd',
        '\xEF\xEE\xEB\xE8\xF6', 'cop', 'swat', 'fbi', 'фбр',
    },
    {
        vec4(0.18, 0.82, 0.28),
        'grove', 'groves', 'groove', 'gsf',
        '\xE3\xF0\xF3\xE2', 'green street', 'grove street',
    },
    {
        vec4(0.68, 0.28, 0.92),
        'ballas', 'balla',
        '\xE1\xE0\xEB\xEB\xE0\xF1', 'balla gang',
    },
    {
        vec4(0.58, 0.38, 0.18),
        '\xEC\xE8\xED\xE8\xF1\xF2\xE5\xF0\xF1\xF2\xE2\xEE \xEE\xE1\xEE\xF0\xEE\xED',
        '\xEE\xE1\xEE\xF0\xEE\xED', 'army', 'military',
        '\xE0\xF0\xEC\xE8', 'mindef', 'defense',
    },
    {
        vec4(0.95, 0.45, 0.72),
        '\xE7\xE4\xF0\xE0\xE2', 'health', 'hospital', 'medic',
        '\xEC\xE5\xE4\xE8\xF6', 'ems', 'doctor', 'скорая',
    },
    {
        vec4(1.0, 1.0, 1.0),
        '\xE1\xE5\xE7\xF0\xE0\xE1', 'unemployed', 'citizen', 'civilian',
        '\xED\xE5 \xF0\xE0\xE1\xEE\xF2', 'no job', 'безработ',
        '\xE3\xF0\xE0\xE6\xE4', 'grazhd', 'none',
    },
    {
        vec4(0.92, 0.18, 0.18),
        'yakuza', 'якудза', 'yaku', 'jakuza',
    },
    {
        vec4(0.95, 0.82, 0.18),
        'vagos', 'вагос', 'vago',
    },
    {
        vec4(0.18, 0.78, 0.82),
        'aztecas', 'azteca', 'ацтек',
    },
    {
        vec4(0.95, 0.52, 0.12),
        'rifa', 'рифа',
    },
    {
        vec4(0.55, 0.55, 0.58),
        'lcn', 'mafia', 'мафия', 'cosa', 'triad', 'триад', 'cartel',
    },
    {
        vec4(0.92, 0.78, 0.22),
        '\xEF\xF0\xE0\xE2', 'government', 'gov', 'мэр', 'mayor',
    },
}

local function sampColorToImVec4(color)
    color = tonumber(color) or 0
    if color < 0 then color = bit.band(color, 0xFFFFFFFF) end
    if color == 0 then return nil end
    local bb = bit.band(color, 0xFF)
    local gg = bit.band(bit.rshift(color, 8), 0xFF)
    local rr = bit.band(bit.rshift(color, 16), 0xFF)
    local aa = bit.band(bit.rshift(color, 24), 0xFF)
    if aa == 0 then aa = 255 end
    return imgui.ImVec4(rr / 255, gg / 255, bb / 255, aa / 255)
end

local function orgTextForColor(e)
    if not e then return '' end
    local parts = {}
    local function add(v)
        v = trim(v or '')
        if v ~= '' and v ~= '-' and v ~= '\xCD\xE5\xF2' then
            parts[#parts + 1] = v
        end
    end
    add(e.fields and e.fields.org)
    add(e.fields and e.fields.job)
    add(e.fields and e.fields.family)
    add(e.fields and e.fields.status)
    return table.concat(parts, ' ')
end

local function nickColorFromOrgText(text)
    text = low(text)
    if text == '' then return nil end
    for i = 1, #FACTION_NICK_COLORS do
        local rule = FACTION_NICK_COLORS[i]
        local col = rule[1]
        for j = 2, #rule do
            local p = rule[j]
            if text:find(p, 1, true) or text:find(low(p), 1, true) then
                return col
            end
        end
    end
    return nil
end

local function isNearWhiteOrGray(c)
    if not c then return false end
    local r, g, b = c.x, c.y, c.z
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    if maxc < 0.45 then return false end
    return (maxc - minc) < 0.12
end

function M.nickColorFor(id, e)
    local fromOrg = nickColorFromOrgText(orgTextForColor(e))
    if fromOrg then return fromOrg end
    id = tonumber(id)
    if sampIsPlayerConnected and id and sampIsPlayerConnected(id) and sampGetPlayerColor then
        local c = sampColorToImVec4(sampGetPlayerColor(id))
        if c then
            if isNearWhiteOrGray(c) then
                return vec4(1.0, 1.0, 1.0)
            end
            return c
        end
    end
    return vec4(1.0, 1.0, 1.0)
end

function M.isGameTextInputActive()
    if inputDeps and inputDeps.sampIsChatInputActive and inputDeps.sampIsChatInputActive() then
        return true
    end
    if inputDeps and inputDeps.sampIsDialogActive and inputDeps.sampIsDialogActive() then
        return true
    end
    return false
end

function M.frameWantsCursor()
    if M.isGameTextInputActive() then return true end
    if state.hudDrag.active then return true end
    if specPlayerActive() then return false end
    if state.hudHovered then return true end
    return false
end

local function labelHas(label, ...)
    label = trim(label or '')
    if label == '' then return false end
    local ll = low(label)
    for i = 1, select('#', ...) do
        local p = select(i, ...)
        if label:find(p, 1, true) or ll:find(p, 1, true) then
            return true
        end
    end
    return false
end

local function classifyLabel(label)
    label = trim(label or '')
    if label == '' then return nil end
    if labelHas(label, '\xD3\xF0\xEE\xE2\xE5\xED', '\xF3\xF0\xEE\xE2\xE5\xED', 'level', 'lvl', '\xF3\xF0\xEE\xE2') then
        return 'level'
    end
    if labelHas(label, '\xCF\xE8\xED\xE3', '\xEF\xE8\xED\xE3', 'ping') then return 'ping' end
    if labelHas(label, '\xCE\xEF\xFB\xF2', '\xEE\xEF\xFB\xF2', 'exp') then return 'exp' end
    if labelHas(label, '\xCD\xE0\xEB\xE8\xF7', '\xED\xE0\xEB\xE8\xF7', '\xE4\xE5\xED\xFC\xE3', 'cash', '\xE4\xE5\xED\xFC\xE3\xE8') then
        return 'money'
    end
    if labelHas(label, '\xC1\xE0\xED\xEA', '\xE1\xE0\xED\xEA', 'bank') then return 'bank' end
    if labelHas(label, '\xCE\xF0\xE3\xE0\xED', '\xEE\xF0\xE3\xE0\xED', '\xF4\xF0\xE0\xEA', 'faction', '\xE3\xE0\xED\xE3', '\xE1\xE0\xED\xE4\xE0') then
        return 'org'
    end
    if labelHas(label, '\xD1\xE5\xEC\xFC', '\xF1\xE5\xEC\xFC', 'family', '\xEA\xEB\xE0\xED') then
        return 'family'
    end
    if labelHas(label, '\xD0\xE0\xE1\xEE\xF2', '\xF0\xE0\xE1\xEE\xF2', 'job', '\xEF\xF0\xEE\xF4') then
        return 'job'
    end
    if labelHas(label, '\xD0\xE0\xED\xE3', '\xF0\xE0\xED\xE3', 'rank', '\xE4\xEE\xEB\xE6\xED', 'post') then
        return 'rank'
    end
    if labelHas(label, '\xCF\xEE\xEB', '\xEF\xEE\xEB', 'gender', '\xEF\xEE\xEB') then return 'gender' end
    if labelHas(label, '\xD2\xE5\xEB\xE5\xF4', '\xF2\xE5\xEB\xE5\xF4', 'phone') then return 'phone' end
    if labelHas(label, 'warn', '\xE2\xE0\xF0\xED', '\xEF\xF0\xE5\xE4', '\xEF\xF0\xE5\xE4\xF3\xEF\xF0') then
        return 'warns'
    end
    if labelHas(label, '\xCF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4', '\xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4',
        '\xCF\xF0\xE5\xE4\xF3\xEF\xF0', '\xEF\xF0\xE5\xE4\xF3\xEF\xF0', '\xCF\xF0\xE5\xE4%.',
        '\xEF\xF0\xE5\xE4%.') then
        return 'warns'
    end
    if labelHas(label, '\xF0\xEE\xE7\xFB\xF1', '\xD0\xEE\xE7\xFB\xF1', 'wanted', 'rozysk') then
        return 'wanted'
    end
    if labelHas(label, '\xD1\xF2\xE0\xF2\xF3\xF1', '\xF1\xF2\xE0\xF2\xF3\xF1', 'status', '\xF1\xEE\xF1\xF2') then
        return 'status'
    end
    if labelHas(label, 'score', '\xEE\xF7\xEA', '\xF0\xE5\xE9\xF2', 'rating') then return 'score' end
    return nil
end

local function stripDialogMarkup(s)
    s = stripTags(s or '')
    s = s:gsub('{[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]}', '')
    return trim(s)
end

local function splitLabelValue(line)
    line = stripDialogMarkup(line)
    if line == '' then return nil, nil end
    local label, value = line:match('^(.-)%s*:%s*(.+)$')
    if not label then
        label, value = line:match('^(.-)%s+%-%s+(.+)$')
    end
    if not label then
        label, value = line:match('^(.-)%s+\226%128%148%s+(.+)$')
    end
    if not label then
        label, value = line:match('^(.-)%s*\t%s*(.+)$')
    end
    if label and value then
        return trim(label), trim(value)
    end
    return nil, nil
end

local function storeField(e, key, value)
    if not e or not key or not value or value == '' then return end
    value = trim(value)
    if value == '' or value == '-' or value == '\xCD\xE5\xF2' then return end
    e.fields[key] = value
end

local function normalizeWarnsValue(value)
    value = trim(value or '')
    if value == '' then return nil end
    local a, b = value:match('(%d+)%s*/%s*(%d+)')
    if a and b then return a .. '/' .. b end
    a, b = value:match('(%d+)%s*\xE8\xE7%s*(%d+)')
    if a and b then return a .. '/' .. b end
    a = value:match('^(%d+)$')
    if a then return a end
    return value
end

local function cacheProtectId(id)
    id = tonumber(id)
    if id == nil then return false end
    if id == state.targetId or id == state.persistHudId then return true end
    return false
end

local function touchCacheId(id)
    id = tonumber(id)
    if not id then return end
    local order = state.cacheOrder
    for i, v in ipairs(order) do
        if v == id then
            table.remove(order, i)
            break
        end
    end
    order[#order + 1] = id
    while #order > CACHE_MAX do
        local old = table.remove(order, 1)
        if old ~= nil and not cacheProtectId(old) then
            state.cache[old] = nil
        end
    end
end

local function extractWarnsFromText(text, e)
    if not text or not e then return end
    local patterns = {
        '\xCF\xF0\xE5\xE4[^\n\r\xC0-\xFF]*(%d+)%s*/%s*(%d+)',
        '\xEF\xF0\xE5\xE4[^\n\r\xC0-\xFF]*(%d+)%s*/%s*(%d+)',
        '\xCF\xF0\xE5\xE4[^\n\r\xC0-\xFF]*(%d+)',
        '\xEF\xF0\xE5\xE4[^\n\r\xC0-\xFF]*(%d+)',
        '[Ww]arn[^\n\r]*(%d+)%s*/%s*(%d+)',
        '[Ww]arn[^\n\r]*(%d+)',
        '(%d+)%s*/%s*(%d+)[^\n\r]*\xEF\xF0\xE5\xE4',
        '(%d+)%s*/%s*(%d+)[^\n\r]*\xCF\xF0\xE5\xE4',
    }
    for _, pat in ipairs(patterns) do
        local a, b = text:match(pat)
        if a then
            local v = b and (a .. '/' .. b) or a
            storeField(e, 'warns', normalizeWarnsValue(v))
            return
        end
    end
end

local BULK_FIELD_PATTERNS = {
    level = {
        '\xD3\xF0\xEE\xE2\xE5\xED[%w\xC0-\xFF%-]*[%s:]+(%d+)',
        '\xF3\xF0\xEE\xE2\xE5\xED[%w\xC0-\xFF%-]*[%s:]+(%d+)',
        '[Ll]evel[%s:]+(%d+)',
        '[Ll]vl[%s:]+(%d+)',
    },
    warns = {
        '\xCF\xF0\xE5\xE4[%w\xC0-\xFF%-%.%(%)%[%]]*[%s:]+(%d+%s*/%s*%d+)',
        '\xCF\xF0\xE5\xE4[%w\xC0-\xFF%-%.%(%)%[%]]*[%s:]+(%d+)',
        '\xEF\xF0\xE5\xE4[%w\xC0-\xFF%-%.%(%)%[%]]*[%s:]+(%d+%s*/%s*%d+)',
        '\xEF\xF0\xE5\xE4[%w\xC0-\xFF%-%.%(%)%[%]]*[%s:]+(%d+)',
        '[Ww]arn[%w%-]*[%s:]+(%d+%s*/%s*%d+)',
        '[Ww]arn[%w%-]*[%s:]+(%d+)',
        '(%d+)%s*/%s*(%d+)%s*\xEF\xF0\xE5\xE4',
        '(%d+)%s*/%s*(%d+)%s*\xCF\xF0\xE5\xE4',
        '(%d+)%s*\xE8\xE7%s*(%d+)%s*\xEF\xF0\xE5\xE4',
    },
    wanted = {
        '\xD3\xF0\xEE\xE2\xE5\xED[%w\xC0-\xFF%-]*\xF0\xEE\xE7\xFB\xF1[%w\xC0-\xFF%-]*[%s:]+(%d+)',
        '\xF3\xF0\xEE\xE2\xE5\xED[%w\xC0-\xFF%-]*\xF0\xEE\xE7\xFB\xF1[%w\xC0-\xFF%-]*[%s:]+(%d+)',
        '\xD0\xEE\xE7\xFB\xF1[%w\xC0-\xFF%-]*[%s:]+(%d+)',
        '\xF0\xEE\xE7\xFB\xF1[%w\xC0-\xFF%-]*[%s:]+(%d+)',
        '[Ww]anted[%w%-]*[%s:]+(%d+)',
    },
    family = {
        '\xD1\xE5\xEC[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
        '\xF1\xE5\xEC[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
    },
    org = {
        '\xCE\xF0\xE3[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
        '\xEE\xF0\xE3[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
        '[Ff]action[%s:]+([^\r\n]+)',
    },
    rank = {
        '\xD0\xE0\xED\xE3[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
        '\xF0\xE0\xED\xE3[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
    },
    job = {
        '\xD0\xE0\xE1[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
        '\xF0\xE0\xE1[%w\xC0-\xFF%-]*[%s:]+([^\r\n]+)',
    },
    money = {
        '\xCD\xE0\xEB[%w\xC0-\xFF%-]*[%s:]+([%d%s%.]+)',
        '\xED\xE0\xEB[%w\xC0-\xFF%-]*[%s:]+([%d%s%.]+)',
    },
}

local function parseBulkFields(text, e)
    for key, patterns in pairs(BULK_FIELD_PATTERNS) do
        for _, pat in ipairs(patterns) do
            local v, v2 = text:match(pat)
            if v and trim(v) ~= '' then
                if key == 'warns' then
                    local val = v2 and (trim(v) .. '/' .. trim(v2)) or trim(v)
                    storeField(e, key, normalizeWarnsValue(val))
                else
                    storeField(e, key, trim(v))
                end
                break
            end
        end
    end
    extractWarnsFromText(text, e)
end

local function resolveDialogCloseButton(button1, button2)
    if button1 and trim(button1) ~= '' then return 1 end
    if button2 and trim(button2) ~= '' then return 0 end
    return 1
end

local function closeStatsDialogOnce(dialogId, button1, button2)
    local btn = resolveDialogCloseButton(button1, button2)
    if type(sampSendDialogResponse) == 'function' and dialogId then
        pcall(sampSendDialogResponse, dialogId, btn, 0, '')
    end
    if type(sampCloseCurrentDialogWithButton) == 'function' then
        pcall(sampCloseCurrentDialogWithButton, btn)
    end
end

local function textHasAny(s, ...)
    s = s or ''
    for i = 1, select('#', ...) do
        local p = select(i, ...)
        if p ~= '' and s:find(p, 1, true) then
            return true
        end
    end
    return false
end

local function dialogHasStatsBody(text)
    text = stripDialogMarkup(text or '')
    if text == '' then return false end
    local hits = 0
    for _, patterns in pairs(BULK_FIELD_PATTERNS) do
        for _, pat in ipairs(patterns) do
            if text:match(pat) then
                hits = hits + 1
                break
            end
        end
    end
    return hits >= 2
end

local function ensureEntry(id)
    id = tonumber(id)
    if not id or id < 0 then return nil end
    local e = state.cache[id]
    if not e then
        e = { id = id, nick = '', fields = {}, extras = {}, updatedAt = 0 }
        state.cache[id] = e
    end
    touchCacheId(id)
    return e
end

function M.getTargetId()
    return tonumber(state.targetId) or -1
end

function M.getMyPlayerId()
    if sampGetPlayerIdByCharHandle then
        local ok, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
        if ok and id then return tonumber(id) or -1 end
    end
    return -1
end

function M.getMaxPlayerId()
    local maxId = MAX_SPEC_PLAYER_ID
    if sampGetMaxPlayerId then
        local ok, n = pcall(sampGetMaxPlayerId, false)
        if ok and n then maxId = tonumber(n) or maxId end
    end
    return maxId
end

function M.isSpectateCandidate(id)
    id = tonumber(id)
    if not id or id < 0 then return false end
    if not sampIsPlayerConnected or not sampIsPlayerConnected(id) then return false end
    local me = M.getMyPlayerId()
    if me >= 0 and id == me then return false end
    return true
end

function M.findAdjacentSpectateId(curId, delta)
    curId = tonumber(curId)
    if curId == nil then return nil end
    local maxId = M.getMaxPlayerId()
    delta = (tonumber(delta) or 0) >= 0 and 1 or -1
    if delta > 0 then
        for i = curId + 1, maxId do
            if M.isSpectateCandidate(i) then return i end
        end
        for i = 0, curId - 1 do
            if M.isSpectateCandidate(i) then return i end
        end
    else
        for i = curId - 1, 0, -1 do
            if M.isSpectateCandidate(i) then return i end
        end
        for i = maxId, curId + 1, -1 do
            if M.isSpectateCandidate(i) then return i end
        end
    end
    return nil
end

function M.stepSpectate(delta)
    local now = os.clock()
    if now - lastSpecStepAt < SPEC_STEP_COOLDOWN then return true end
    lastSpecStepAt = now
    local cur = M.getTargetId()
    if cur < 0 then
        cur = M.getMyPlayerId()
        if cur < 0 then cur = 0 end
    end
    local nextId = M.findAdjacentSpectateId(cur, delta)
    if not nextId then return false end
    if sendChat then sendChat('sp ' .. tostring(nextId)) end
    return true
end

function M.hasStats(id)
    id = tonumber(id)
    if not id or id < 0 then return false end
    local e = state.cache[id]
    if not e or not e.updatedAt or e.updatedAt <= 0 then return false end
    for _, key in ipairs(HUD_FIELD_ORDER) do
        local val = e.fields[key]
        if val and val ~= '' and val ~= '-' and val ~= '\xCD\xE5\xF2' then
            return true
        end
    end
    return false
end

function M.setSpectateTarget(id, nick, settings)
    id = tonumber(id)
    if not id or id < 0 then
        state.targetId = -1
        state.targetNick = ''
        return
    end
    if state.targetId ~= id then
        state.hudPlaced = false
    end
    state.targetId = id
    state.targetNick = trim(nick or '')
    if inputDeps and inputDeps.setPlayerSpectating then
        inputDeps.setPlayerSpectating(true)
    end
    local e = ensureEntry(id)
    if e then
        if state.targetNick ~= '' then e.nick = state.targetNick end
        M.refreshLivePing(id)
    end
    local s = settings
    if not s and getSettings then s = getSettings() end
    if e and s and s.spectate_auto_st ~= false then
        e.fields.level = nil
        e.fields.warns = nil
        e.fields.wanted = nil
        e.fields.family = nil
        e.fields.org = nil
        e.fields.rank = nil
        e.fields.job = nil
        e.fields.money = nil
        M.requestStats(id, {})
    end
end

function M.persistHudEnabled(settings)
    settings = settings or (getSettings and getSettings())
    if not settings then return true end
    local v = settings.spectate_hud_persist
    if v == false or v == 0 or v == 'false' or v == '0' then return false end
    return true
end

function M.shouldPersistHud()
    return M.persistHudEnabled()
end

function M.snapshotPersistHud()
    if not M.persistHudEnabled() then return end
    local id = tonumber(state.targetId)
    if id and id >= 0 then state.persistHudId = id end
end

function M.getHudDisplayId()
    local id = tonumber(state.targetId)
    if id and id >= 0 then return id end
    id = tonumber(state.persistHudId)
    if id and id >= 0 then return id end
    return -1
end

function M.clearSpectateTarget(force)
    if not force and M.persistHudEnabled() then
        M.snapshotPersistHud()
        return
    end
    state.targetId = -1
    state.targetNick = ''
    state.persistHudId = -1
end

function M.isHudActive()
    local id = tonumber(state.targetId)
    return id and id >= 0
end

function M.shouldShowHud(settings)
    if not settings or settings.spectate_hud == false then return false end
    return M.getHudDisplayId() >= 0
end

function M.markPendingSt(id)
    id = tonumber(id)
    if not id or id < 0 then return end
    state.pendingStId = id
    state.pendingStAt = os.clock()
end

function M.refreshLivePing(id)
    id = tonumber(id)
    if not id or not sampIsPlayerConnected or not sampIsPlayerConnected(id) then return end
    local e = ensureEntry(id)
    if not e then return end
    if sampGetPlayerPing then
        local p = tonumber(sampGetPlayerPing(id))
        if p and p >= 0 then e.fields.ping = tostring(p) end
    end
    -- score из SAMP ID — не уровень; в HUD только данные /st
    local nick = sampGetPlayerNickname and sampGetPlayerNickname(id)
    if nick and trim(nick) ~= '' then e.nick = trim(nick) end
end

function M.parseSpServerLine(text)
    text = stripTags(text or '')
    local nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%]%s*|%s*PING%s+(%d+)')
    if not id then
        nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%].-(%d+)%s*$')
    end
    if not id then return false end
    id = tonumber(id)
    ping = tonumber(ping)
    local e = ensureEntry(id)
    if not e then return false end
    if nick and trim(nick) ~= '' then e.nick = trim(nick) end
    if ping then e.fields.ping = tostring(ping) end
    e.updatedAt = os.time()
    if state.targetId == id and nick then state.targetNick = e.nick end
    return true
end

function M.parseDialogText(text, playerId)
    text = stripDialogMarkup(text or '')
    if text == '' then return nil end
    playerId = tonumber(playerId)
    if not playerId then return nil end

    local e = ensureEntry(playerId)
    if not e then return nil end

    if not e.fields then e.fields = {} end
    if not e.extras then e.extras = {} end

    parseBulkFields(text, e)

    local pendingKey = nil
    for line in text:gmatch('[^\r\n]+') do
        local label, value = splitLabelValue(line)
        if label and value then
            pendingKey = nil
            local key = classifyLabel(label)
            if key then
                if key == 'warns' then
                    storeField(e, key, normalizeWarnsValue(value))
                else
                    storeField(e, key, value)
                end
            else
                e.extras[label] = value
            end
        else
            line = stripDialogMarkup(line)
            if line ~= '' then
                local key = classifyLabel(line)
                if key then
                    pendingKey = key
                elseif pendingKey then
                    storeField(e, pendingKey, line)
                    pendingKey = nil
                end
            end
        end
    end

    parseBulkFields(text, e)
    if e.fields.level == '0' then
        e.fields.level = nil
    end
    e.updatedAt = os.time()
    M.refreshLivePing(playerId)
    return e
end

function M.requestStats(id, opts)
    opts = opts or {}
    id = tonumber(id) or state.targetId
    if not id or id < 0 then return false end
    if not sendChat then return false end
    M.markPendingSt(id)
    sendChat('st ' .. tostring(id))
    return true
end

function M.maybeAutoRequest(id, settings, force)
    if not settings or settings.spectate_auto_st == false then return end
    id = tonumber(id) or state.targetId
    if not id or id < 0 then return end
    local now = os.clock()
    if not force and now - state.lastAutoStAt < AUTO_ST_COOLDOWN then return end
    state.lastAutoStAt = now
    M.requestStats(id, {})
end

function M.autoRequestIfEnabled(id, settings)
    if not settings or settings.spectate_auto_st == false then return end
    M.requestStats(tonumber(id), {})
end

function M.onServerMessage(color, text)
    if not text or text == '' then return false end
    color = tonumber(color) or 0
    if color < 0 then color = color + 4294967296 end
    if color == SP_MSG_COLOR or text:find('%[SP%]', 1, true) then
        return M.parseSpServerLine(text)
    end
    return false
end

function M.dialogLooksLikePlayerStats(title, text, expectId)
    local titlePlain = stripDialogMarkup(title or '')
    local plain = stripDialogMarkup(text or '')
    if plain == '' then return false end
    if expectId then
        local idTag = '%[' .. tostring(expectId) .. '%]'
        if titlePlain:find(idTag, 1, true) or plain:find(idTag, 1, true) then
            return true
        end
    end
    if textHasAny(plain,
            '\xD3\xF0\xEE\xE2\xE5\xED', '\xF3\xF0\xEE\xE2\xE5\xED', 'level', 'Level', 'LEVEL')
        and textHasAny(plain,
            '\xCF\xE8\xED\xE3', '\xEF\xE8\xED\xE3', 'ping', 'Ping', 'PING') then
        return true
    end
    if textHasAny(plain,
            '\xD1\xE5\xEC\xFC', '\xF1\xE5\xEC\xFC', 'family', 'Family',
            '\xCE\xF0\xE3\xE0\xED', '\xEE\xF0\xE3\xE0\xED', 'faction', 'Faction',
            '\xD0\xE0\xED\xE3', '\xF0\xE0\xED\xE3', 'rank', 'Rank',
            '\xD0\xE0\xE1\xEE\xF2', '\xF0\xE0\xE1\xEE\xF2', 'job', 'Job') then
        return true
    end
    if textHasAny(plain,
            '\xCF\xF0\xE5\xE4', '\xEF\xF0\xE5\xE4', '\xCF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4',
            '\xEF\xF0\xE5\xE4\xF3\xEF\xF0\xE5\xE6\xE4', 'warn', 'Warn', 'WARN') then
        return true
    end
    if textHasAny(plain,
            '\xCD\xE0\xEB\xE8\xF7', '\xED\xE0\xEB\xE8\xF7', 'cash', 'Cash',
            '\xD0\xEE\xE7\xFB\xF1', '\xF0\xEE\xE7\xFB\xF1', 'wanted', 'Wanted') then
        return true
    end
    if textHasAny(titlePlain,
            '\xD1\xF2\xE0\xF2', '\xF1\xF2\xE0\xF2', '\xC8\xED\xF4\xEE\xF0\xEC', '\xE8\xED\xF4\xEE\xF0\xEC',
            'stat', 'Stat', 'info', 'Info')
        and (plain:find(':', 1, true) or plain:find('\n', 1, true)) then
        return true
    end
    return dialogHasStatsBody(plain)
end

function M.shouldInterceptStatsDialog(title, text, style)
    local expectId = tonumber(state.targetId)
    local pid = state.pendingStId
    local pendingFresh = pid and (os.clock() - (state.pendingStAt or 0)) <= PENDING_ST_SEC
    style = tonumber(style) or -1
    if pendingFresh then
        if M.dialogLooksLikePlayerStats(title, text, pid) then
            return true, pid
        end
        if (style == 0 or style == 1) and dialogHasStatsBody(text) then
            return true, pid
        end
    end
    if expectId and expectId >= 0 and M.dialogLooksLikePlayerStats(title, text, expectId) then
        return true, expectId
    end
    return false, nil
end

function M.onShowDialog(dialogId, style, title, button1, button2, text)
    local ok, pid = M.shouldInterceptStatsDialog(title, text, style)
    if not ok or not pid then
        return false
    end

    local plain = stripDialogMarkup(text or '')
    local titlePlain = stripDialogMarkup(title or '')
    local idFromTitle = titlePlain:match('%[(%d+)%]')
    if idFromTitle then pid = tonumber(idFromTitle) end

    M.parseDialogText(plain, pid)
    state.pendingStId = nil
    closeStatsDialogOnce(dialogId, button1, button2)
    return true
end

function M.getEntry(id)
    id = tonumber(id)
    if not id or id < 0 then return nil end
    M.refreshLivePing(id)
    return state.cache[id]
end

function M.formatCompact(id)
    local e = M.getEntry(id)
    if not e then return '' end
    local parts = {}
    if e.fields.level and e.fields.level ~= '' then
        parts[#parts + 1] = uiText(e.fields.level) .. ' lvl'
    end
    if e.fields.ping and e.fields.ping ~= '' then
        parts[#parts + 1] = uiText(e.fields.ping) .. ' ms'
    end
    if e.fields.family and e.fields.family ~= '' then
        parts[#parts + 1] = uiText(e.fields.family)
    end
    if e.fields.org and e.fields.org ~= '' and e.fields.org ~= '\xCD\xE5\xF2' then
        parts[#parts + 1] = uiText(e.fields.org)
    end
    if e.fields.warns and e.fields.warns ~= '' then
        parts[#parts + 1] = 'warn ' .. uiText(e.fields.warns)
    end
    if #parts == 0 and e.updatedAt and e.updatedAt > 0 then
        return uiText('\xE4\xE0\xED\xED\xFB\xE5 \xE7\xE0\xE3\xF0\xF1\xE6\xE5\xED\xFB')
    end
    if #parts == 0 then
        return uiText('\xCD\xE5\xF2 \xE4\xE0\xED\xED\xFB\xF5')
    end
    return table.concat(parts, '  ·  ')
end

function M.pingColor(pingStr)
    local p = tonumber(pingStr)
    if not p then return col_muted2 end
    if p < 80 then return imgui.ImVec4(0.38, 0.88, 0.48, 1.0) end
    if p < 150 then return col_warn end
    return imgui.ImVec4(0.92, 0.38, 0.38, 1.0)
end

local function hudValueWidth()
    return HUD_PANEL_W - HUD_PAD_X * 2 - HUD_LABEL_W
end

local function wrapWordsToLines(text, maxWidth)
    text = uiText(text or '')
    if text == '' then return {} end
    maxWidth = math.max(48, tonumber(maxWidth) or hudValueWidth())
    local spaceW = imgui.CalcTextSize(' ').x
    local lines = {}
    local buf, bufW = '', 0
    local function flush()
        if buf ~= '' then
            lines[#lines + 1] = buf
            buf, bufW = '', 0
        end
    end
    for word in text:gmatch('%S+') do
        local wW = imgui.CalcTextSize(word).x
        if wW > maxWidth then
            flush()
            lines[#lines + 1] = word
        else
            local addW = (buf == '') and wW or (spaceW + wW)
            if buf ~= '' and (bufW + addW) > maxWidth then
                flush()
                buf, bufW = word, wW
            elseif buf == '' then
                buf, bufW = word, wW
            else
                buf = buf .. ' ' .. word
                bufW = bufW + addW
            end
        end
    end
    flush()
    return lines
end

function M.drawStatRow(label, value, valueCol)
    if not value or value == '' then return end
    local lines = wrapWordsToLines(value, hudValueWidth())
    if #lines == 0 then return end
    local col = valueCol or col_label
    imgui.TextColored(col_muted2, uiText(label))
    imgui.SameLine(HUD_LABEL_W)
    imgui.TextColored(col, lines[1])
    for i = 2, #lines do
        imgui.SetCursorPosX(HUD_LABEL_W)
        imgui.TextColored(col, lines[i])
    end
end

function M.wantedColor(lvl, active)
    lvl = tonumber(lvl) or 0
    if not active then
        return imgui.ImVec4(0.38, 0.36, 0.42, 0.55)
    end
    if lvl <= 0 then return imgui.ImVec4(0.55, 0.55, 0.58, 0.7) end
    if lvl <= 2 then return imgui.ImVec4(1.0, 0.86, 0.18, 1.0) end
    if lvl <= 4 then return imgui.ImVec4(1.0, 0.58, 0.12, 1.0) end
    return imgui.ImVec4(0.95, 0.28, 0.28, 1.0)
end

local WANTED_LEVEL_MAX = 6
local WANTED_STAR_OUTER = 5.5
local WANTED_STAR_INNER = 2.3
local WANTED_STAR_STEP = 13
local HUD_ID_COLOR = imgui.ImVec4(0.95, 0.95, 0.97, 1.0)

local function drawWantedStar(dl, cx, cy, filled, col)
    if not dl or not toU32 then return end
    dl:PathClear()
    for i = 0, 4 do
        local aOut = math.rad(-90 + i * 72)
        local aIn = math.rad(-90 + i * 72 + 36)
        dl:PathLineTo(imgui.ImVec2(
            cx + math.cos(aOut) * WANTED_STAR_OUTER,
            cy + math.sin(aOut) * WANTED_STAR_OUTER))
        dl:PathLineTo(imgui.ImVec2(
            cx + math.cos(aIn) * WANTED_STAR_INNER,
            cy + math.sin(aIn) * WANTED_STAR_INNER))
    end
    local u32 = toU32(col)
    if filled then
        dl:PathFillConvex(u32)
    else
        dl:PathStroke(u32, true, 1.15)
    end
end

local function normalizeWantedLevel(val)
    val = trim(val or '')
    if val == '' then return nil end
    local n = tonumber(val:match('^(%d+)'))
    if n == nil then return nil end
    return math.max(0, math.min(WANTED_LEVEL_MAX, math.floor(n + 0.5)))
end

function M.drawWantedRow(label, value)
    local lvl = normalizeWantedLevel(value)
    if lvl == nil then return end

    imgui.TextColored(col_muted2, uiText(label))
    imgui.SameLine(HUD_LABEL_W)

    local dl = imgui.GetWindowDrawList()
    local lineH = imgui.GetTextLineHeight()
    local base = imgui.GetCursorScreenPos()
    local centerY = base.y + lineH * 0.5
    local startX = base.x + WANTED_STAR_OUTER

    for i = 1, WANTED_LEVEL_MAX do
        local cx = startX + (i - 1) * WANTED_STAR_STEP
        local active = i <= lvl
        local col = M.wantedColor(lvl, active)
        drawWantedStar(dl, cx, centerY, active, col)
    end

    imgui.Dummy(imgui.ImVec2(WANTED_LEVEL_MAX * WANTED_STAR_STEP + WANTED_STAR_OUTER, lineH))
end

local function drawHudNickHeader(nick, id, nickCol, maxW)
    local nickText = uiText(nick or '')
    local idText = uiText(' [' .. tostring(id) .. ']')
    maxW = math.max(48, tonumber(maxW) or (HUD_PANEL_W - HUD_PAD_X * 2))
    local idW = imgui.CalcTextSize(idText).x
    local nickLines = wrapWordsToLines(nickText, math.max(48, maxW - idW - 4))
    if #nickLines == 0 then nickLines = { nickText } end
    for i, ln in ipairs(nickLines) do
        if i == #nickLines then
            local lnW = imgui.CalcTextSize(ln).x
            if lnW + idW <= maxW then
                imgui.TextColored(nickCol, ln)
                imgui.SameLine(0, 0)
                imgui.TextColored(HUD_ID_COLOR, idText)
            else
                imgui.TextColored(nickCol, ln)
                imgui.TextColored(HUD_ID_COLOR, idText)
            end
        else
            imgui.TextColored(nickCol, ln)
        end
    end
end

local function clampHudPos(hx, hy, winW, winH, sw, sh, pivotX)
    winW = math.max(HUD_PANEL_W, tonumber(winW) or HUD_PANEL_W)
    winH = math.max(48, tonumber(winH) or 120)
    if pivotX == 1 then
        hx = math.max(-sw + 8, math.min(hx, -winW - 8))
    else
        hx = math.max(8, math.min(hx, sw - winW - 8))
    end
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

function M.drawOverlay(settings)
    if not settings or settings.spectate_hud == false then return end
    local id = M.getHudDisplayId()
    if id < 0 then return end

    local e = M.getEntry(id)
    if not e then return end

    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end

    local rawX = tonumber(settings.spectate_hud_x)
    local hy = tonumber(settings.spectate_hud_y) or 120
    local pivotX = 0
    local hx = rawX
    if hx == nil or hx < 0 then
        hx = sw + (hx or -16)
        pivotX = 1
    end
    hx, hy = clampHudPos(hx, hy, HUD_PANEL_W, 160, sw, sh, pivotX)

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoScrollbar
    local deskWinOpen = inputDeps and inputDeps.getShowWindow and inputDeps.getShowWindow()
    if not deskWinOpen and not state.hudDrag.active then
        if imgui.WindowFlags.NoInputs then
            flags = flags + imgui.WindowFlags.NoInputs
        end
    elseif specPlayerActive() and not M.isGameTextInputActive() and not state.hudDrag.active then
        if imgui.WindowFlags.NoInputs then
            flags = flags + imgui.WindowFlags.NoInputs
        end
    end
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end

    imgui.SetNextWindowBgAlpha(0.88)
    imgui.SetNextWindowSize(imgui.ImVec2(HUD_PANEL_W, 0), imgui.Cond.Always)
    if not state.hudPlaced then
        imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always, imgui.ImVec2(pivotX, 0))
        state.hudPlaced = true
    elseif state.hudDrag.active then
        imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always, imgui.ImVec2(pivotX, 0))
    end

    if imgui.Begin('###desk_spec_stats', nil, flags) then
        M.updateHudHoverRect()
        if imgui.PushItemWidth then imgui.PushItemWidth(HUD_PANEL_W - HUD_PAD_X * 2) end

        local nick = e.nick ~= '' and e.nick or (state.targetNick ~= '' and state.targetNick or ('ID:' .. id))
        local nickCol = M.nickColorFor(id, e)
        drawHudNickHeader(nick, id, nickCol, HUD_PANEL_W - HUD_PAD_X * 2)

        imgui.Separator()

        local pendingSt = state.pendingStId == id
            and (os.clock() - (state.pendingStAt or 0)) < PENDING_ST_SEC
        local hasAny = false
        for _, key in ipairs(HUD_FIELD_ORDER) do
            local val = e.fields[key]
            local showRow = val and val ~= '' and val ~= '-' and val ~= '\xCD\xE5\xF2'
            if showRow and key == 'level' and val == '0' then
                showRow = false
            end
            if key == 'warns' and val and val ~= '' then
                showRow = true
            end
            if key == 'wanted' and val ~= nil and val ~= '' then
                showRow = true
            end
            if showRow then
                hasAny = true
                local lbl = FIELD_LABELS[key] or key
                if key == 'ping' then
                    M.drawStatRow(lbl, val, M.pingColor(val))
                elseif key == 'level' then
                    M.drawStatRow(lbl, val, col_accent)
                elseif key == 'warns' then
                    M.drawStatRow(lbl, val, col_warn)
                elseif key == 'wanted' then
                    M.drawWantedRow(lbl, val)
                else
                    M.drawStatRow(lbl, val, nil)
                end
            end
        end

        if not e.fields.wanted or e.fields.wanted == '' then
            for lbl, val in pairs(e.extras or {}) do
                local ll = low(lbl)
                if ll:find('wanted', 1, true) or lbl:find('\xF0\xEE\xE7\xFB\xF1', 1, true)
                    or lbl:find('\xD0\xEE\xE7\xFB\xF1', 1, true) then
                    hasAny = true
                    M.drawWantedRow(FIELD_LABELS.wanted, val)
                    break
                end
            end
        end

        if not e.fields.warns or e.fields.warns == '' then
            for lbl, val in pairs(e.extras or {}) do
                local ll = low(lbl)
                if ll:find('warn', 1, true) or lbl:find('\xCF\xF0\xE5\xE4', 1, true)
                    or lbl:find('\xEF\xF0\xE5\xE4', 1, true) or lbl:find('\xE2\xE0\xF0\xED', 1, true) then
                    hasAny = true
                    M.drawStatRow(FIELD_LABELS.warns, val, col_warn)
                    break
                end
            end
        end

        if not hasAny and e.extras then
            local shown = 0
            for lbl, val in pairs(e.extras) do
                if shown >= 6 then break end
                if val and val ~= '' then
                    hasAny = true
                    shown = shown + 1
                    M.drawStatRow(lbl, val, nil)
                end
            end
        end

        if pendingSt and not hasAny then
            imgui.TextColored(col_muted, uiText('\xC7\xE0\xE3\xF0\xF3\xE7\xEA\xE0 \xF1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xE8...'))
        elseif not hasAny then
            imgui.TextColored(col_muted2, uiText('\xCE\xE6\xE8\xE4\xE0\xED\xE8\xE5 /st \xE8\xEB\xE8 \xAB\xCE\xE1\xED\xEE\xE2\xE8\xF2\xFC\xBB'))
        end

        if state.hudHovered and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
            local delta = imgui.GetMouseDragDelta(0)
            if not state.hudDrag.active then
                local wp = imgui.GetWindowPos()
                state.hudDrag.active = true
                state.hudDrag.offX = wp.x
                state.hudDrag.offY = wp.y
                imgui.ResetMouseDragDelta(0)
            end
            local nx = state.hudDrag.offX + delta.x
            if pivotX == 1 then nx = nx - sw end
            settings.spectate_hud_x = nx
            settings.spectate_hud_y = state.hudDrag.offY + delta.y
            if markDirtySettings then markDirtySettings() end
        elseif state.hudDrag.active and not imgui.IsMouseDown(0) then
            state.hudDrag.active = false
            if markDirtySettings then markDirtySettings() end
            if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
        end
        if state.hudHovered and imgui.IsMouseReleased(0) and not imgui.IsAnyItemActive() then
            local wp = imgui.GetWindowPos()
            local ww = imgui.GetWindowWidth()
            local wh = imgui.GetWindowHeight()
            local nx, ny = clampHudPos(wp.x, wp.y, ww, wh, sw, sh, pivotX)
            if pivotX == 1 then
                settings.spectate_hud_x = nx - sw
            else
                settings.spectate_hud_x = nx
            end
            settings.spectate_hud_y = ny
            if markDirtySettings then markDirtySettings() end
            if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
        end

        if imgui.PopItemWidth then imgui.PopItemWidth() end
        imgui.End()
    end
end

function M.isHudHovered()
    return state.hudHovered or state.hudDrag.active
end

function M.resetHudDrag()
    state.hudDrag.active = false
    state.hudHovered = false
end

function M.isHudDragActive()
    return state.hudDrag.active
end

function M.wantsHudInput()
    if state.hudDrag.active then return true end
    if state.hudHovered then return true end
    local r = state.hudRect
    if not r then return false end
    local mp = imgui.GetIO().MousePos
    return mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1
end

function M.updateHudHoverRect()
    local p = imgui.GetWindowPos()
    local w = imgui.GetWindowWidth()
    local h = imgui.GetWindowHeight()
    state.hudRect = { x0 = p.x, y0 = p.y, x1 = p.x + w, y1 = p.y + h }
    local mp = imgui.GetIO().MousePos
    state.hudHovered = mp.x >= p.x and mp.x < p.x + w and mp.y >= p.y and mp.y < p.y + h
end

local markDirtySettings
local flushDirtyConfigNow
local getSettings
local frameInstalled = false

local inputInstalled = false
local specToggleOffAt = 0
local specArrowPrev = {}
local specClickHandler = nil
local specToggleHandler = nil
local specSpectatePlayerHandler = nil
local hookPrevSpectatePlayer = nil

local WM = {
    KEYDOWN = 0x0100,
    KEYUP = 0x0101,
    SYSKEYDOWN = 0x0104,
    SYSKEYUP = 0x0105,
}

local function specIsSpectating()
    return specPlayerActive()
end

function M.isSpectating()
    return specPlayerActive()
end

local function specMenuShieldActive()
    if not specIsSpectating() then return false end
    if inputDeps and inputDeps.sampIsChatInputActive and inputDeps.sampIsChatInputActive() then
        return true
    end
    if inputDeps and inputDeps.getShowWindow and inputDeps.getShowWindow() then
        if inputDeps.isDeskTypingActive and inputDeps.isDeskTypingActive() then
            return true
        end
        local imguiMod = inputDeps.imgui
        if imguiMod and imguiMod.IsWindowHovered and imguiMod.HoveredFlags
            and imguiMod.IsWindowHovered(imguiMod.HoveredFlags.AnyWindow) then
            return true
        end
    end
    return false
end

local function specCaptureActive()
    if not inputDeps then return false end
    if inputDeps.hotkeyCapture and inputDeps.hotkeyCapture() then return true end
    if inputDeps.cheatKeyCapture and inputDeps.cheatKeyCapture() then return true end
    return false
end

local function specArrowHit(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 or not inputDeps or not inputDeps.isVkDown then return false end
    local down = inputDeps.isVkDown(vk)
    if not down then
        specArrowPrev[vk] = false
        return false
    end
    if not specArrowPrev[vk] then
        specArrowPrev[vk] = true
        return true
    end
    return false
end

local function specStepByArrow(delta)
    if not specIsSpectating() or specMenuShieldActive() or specCaptureActive() then return false end
    return M.stepSpectate(delta)
end

function M.handleSpectateWindowMessage(msg, wparam)
    if not specIsSpectating() or specMenuShieldActive() or specCaptureActive() then return false end
    if msg ~= WM.KEYDOWN and msg ~= WM.SYSKEYDOWN then return false end
    local vkeysMod = inputDeps and inputDeps.vkeys
    local vkL = (vkeysMod and vkeysMod.VK_LEFT) or 0x25
    local vkR = (vkeysMod and vkeysMod.VK_RIGHT) or 0x27
    if wparam ~= vkL and wparam ~= vkR then return false end
    return specStepByArrow(wparam == vkR and 1 or -1)
end

function M.consumeSpectateMenuKey(msg, wparam)
    if not specMenuShieldActive() then return false end
    if msg ~= WM.KEYDOWN and msg ~= WM.SYSKEYDOWN and msg ~= WM.KEYUP and msg ~= WM.SYSKEYUP then
        return false
    end
    local vkeysMod = inputDeps and inputDeps.vkeys
    if not vkeysMod then return false end
    if wparam == vkeysMod.VK_SHIFT or wparam == vkeysMod.VK_MENU or wparam == vkeysMod.VK_CONTROL then
        return true
    end
    if wparam == vkeysMod.VK_SPACE or wparam == vkeysMod.VK_TAB then return true end
    return false
end

function M.pollSpectateArrowKeys()
    if not specIsSpectating() or specMenuShieldActive() or specCaptureActive() then return end
    local vkeysMod = inputDeps and inputDeps.vkeys
    if not vkeysMod then return end
    if specArrowHit(vkeysMod.VK_LEFT) then
        specStepByArrow(-1)
    elseif specArrowHit(vkeysMod.VK_RIGHT) then
        specStepByArrow(1)
    end
end

function M.onTogglePlayerSpectating(toggle)
    if not inputDeps then return end
    if toggle then
        specToggleOffAt = 0
        if inputDeps.setPlayerSpectating then inputDeps.setPlayerSpectating(true) end
        if inputDeps.onSpectatingOn then inputDeps.onSpectatingOn() end
        return
    end
    if inputDeps.setPlayerSpectating then inputDeps.setPlayerSpectating(false) end
    specToggleOffAt = os.clock()
    if inputDeps.onSpectatingOff then inputDeps.onSpectatingOff() end
    local offAt = specToggleOffAt
    lua_thread.create(function()
        wait(600)
        if specToggleOffAt ~= offAt then return end
        if inputDeps.getPlayerSpectating and inputDeps.getPlayerSpectating() then return end
        M.clearSpectateTarget(false)
    end)
end

function M.onSpCommandOff()
    specToggleOffAt = 0
    M.snapshotPersistHud()
    if inputDeps and inputDeps.setPlayerSpectating then inputDeps.setPlayerSpectating(false) end
end

function M.installInputHooks(deps)
    inputDeps = deps
    if inputInstalled then return end
    inputInstalled = true

    addEventHandler('onWindowMessage', function(msg, wparam, lparam)
        if specCaptureActive() then return end
        if M.handleSpectateWindowMessage(msg, wparam) then
            consumeWindowMessage(true, true, true)
            return
        end
        if M.consumeSpectateMenuKey(msg, wparam) then
            consumeWindowMessage(true, true, true)
        end
    end, true)

    local sampev = deps.sampev
    if not sampev then return end

    local prevClick = sampev.onSendClickTextDraw
    if prevClick == specClickHandler then prevClick = nil end
    specClickHandler = function(textdrawId)
        if specMenuShieldActive() then return false end
        if type(prevClick) == 'function' then return prevClick(textdrawId) end
    end
    sampev.onSendClickTextDraw = specClickHandler

    local prevToggle = sampev.onToggleSelectTextDraw
    if prevToggle == specToggleHandler then prevToggle = nil end
    specToggleHandler = function(state, hovercolor)
        if state and specMenuShieldActive() then return false end
        if type(prevToggle) == 'function' then return prevToggle(state, hovercolor) end
    end
    sampev.onToggleSelectTextDraw = specToggleHandler
end

function M.ensureInputHooks()
    if not inputDeps or not inputDeps.sampev then return end
    local sampev = inputDeps.sampev
    if sampev.onSendClickTextDraw == specClickHandler
        and sampev.onToggleSelectTextDraw == specToggleHandler then
        return
    end
    local prevClick = sampev.onSendClickTextDraw
    if prevClick == specClickHandler then prevClick = nil end
    specClickHandler = function(textdrawId)
        if specMenuShieldActive() then return false end
        if type(prevClick) == 'function' then return prevClick(textdrawId) end
    end
    sampev.onSendClickTextDraw = specClickHandler

    local prevToggle = sampev.onToggleSelectTextDraw
    if prevToggle == specToggleHandler then prevToggle = nil end
    specToggleHandler = function(state, hovercolor)
        if state and specMenuShieldActive() then return false end
        if type(prevToggle) == 'function' then return prevToggle(state, hovercolor) end
    end
    sampev.onToggleSelectTextDraw = specToggleHandler
end

function M.getTargetId()
    return state.targetId
end

function M.notifyTargetQuit(playerId)
    playerId = tonumber(playerId)
    if not playerId or state.targetId ~= playerId then return end
    M.clearSpectateTarget(false)
end

function M.uninstallSpectatePlayerHook()
    local sampev = inputDeps and inputDeps.sampev
    if not sampev then return end
    if specSpectatePlayerHandler and sampev.onSpectatePlayer == specSpectatePlayerHandler then
        sampev.onSpectatePlayer = hookPrevSpectatePlayer
    end
    specSpectatePlayerHandler = nil
    hookPrevSpectatePlayer = nil
end

function M.ensureSpectatePlayerHook()
    if not inputDeps or not inputDeps.sampev then return end
    local sampev = inputDeps.sampev
    if specSpectatePlayerHandler and sampev.onSpectatePlayer == specSpectatePlayerHandler then
        return
    end
    local prev = sampev.onSpectatePlayer
    if prev == specSpectatePlayerHandler then prev = nil end
    if hookPrevSpectatePlayer == nil then hookPrevSpectatePlayer = prev end
    specSpectatePlayerHandler = function(id)
        id = tonumber(id)
        if not id or id < 0 then
            if type(hookPrevSpectatePlayer) == 'function' then
                return hookPrevSpectatePlayer(id)
            end
            return
        end
        local nick = ''
        pcall(function()
            if sampIsPlayerConnected and sampIsPlayerConnected(id) and sampGetPlayerNickname then
                nick = sampGetPlayerNickname(id) or ''
            end
        end)
        if inputDeps and inputDeps.setPlayerSpectating then
            inputDeps.setPlayerSpectating(true)
        end
        M.setSpectateTarget(id, nick, getSettings())
        if type(hookPrevSpectatePlayer) == 'function' then
            return hookPrevSpectatePlayer(id)
        end
    end
    sampev.onSpectatePlayer = specSpectatePlayerHandler
end

function M.configure(deps)
    trim = deps.trim
    stripTags = deps.stripTags
    sendChat = deps.sendChat
    uiText = deps.uiText
    toU32 = deps.toU32
    col_accent = deps.col_accent
    col_muted = deps.col_muted
    col_muted2 = deps.col_muted2
    col_label = deps.col_label
    col_warn = deps.col_warn
    sampIsPlayerConnected = deps.sampIsPlayerConnected
    sampGetPlayerNickname = deps.sampGetPlayerNickname
    sampGetPlayerColor = deps.sampGetPlayerColor
    sampGetPlayerPing = deps.sampGetPlayerPing
    sampGetPlayerScore = deps.sampGetPlayerScore
    markDirtySettings = deps.markDirtySettings
    getSettings = deps.getSettings
end

function M.install(deps)
    M.configure(deps)
    if frameInstalled then return end
    frameInstalled = true

    local sampev = deps.sampev
    local getSettings = deps.getSettings
    local getSpectating = deps.getSpectating
    local getShowWindow = deps.getShowWindow

    local frame = imgui.OnFrame(
        function()
            return M.shouldShowHud(getSettings())
        end,
        function(self)
            local s = getSettings()
            pcall(M.drawOverlay, s)
            if getShowWindow and getShowWindow() then
                self.HideCursor = true
            elseif specPlayerActive() then
                self.HideCursor = true
            else
                self.HideCursor = not M.frameWantsCursor()
            end
            self.LockPlayer = false
        end
    )
    frame.HideCursor = true
    frame.LockPlayer = false

    M.ensureSpectatePlayerHook()
end

return M
