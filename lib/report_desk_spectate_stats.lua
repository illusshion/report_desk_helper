--[[ Модуль: /st stats parse, HUD overlay, spectate health. ]]
local M = {}

local imgui = require 'mimgui'
local specSession = require 'report_desk_spectate_session'
local spUi = require 'report_desk_sp_ui'
local specMenuMod = require 'report_desk_spectate_menu'
local spTheme = require 'report_desk_sp_theme'
local vehicleHud = require 'report_desk_sp_vehicle_hud'
local keysHud = require 'report_desk_sp_keys_hud'
local specCamera = require 'report_desk_spectate_camera'
local spRefresh = require 'report_desk_sp_refresh'

local SP_MSG_COLOR = 1728027135
local PENDING_ST_SEC = 12.0
local AUTO_ST_COOLDOWN = 4.0
local SPEC_STEP_COOLDOWN = 0.45
local SPEC_STEP_AUTO_ST_DELAY = 2.5
local PENDING_SP_SEC = 6.0
local SPECTATE_FORCE_EXIT_COOLDOWN = 0.8
local SPECTATE_ORPHAN_GRACE_SEC = 3.0
local SPECTATE_TARGET_OFFLINE_GRACE_SEC = 2.5
local SPECTATE_HEALTH_INTERVAL = 0.25
local WM_ACTIVATEAPP = 0x001c
local lastForceExitAt = 0
local orphanSinceAt = nil
local orphanRecoveryTried = false
local targetOfflineSinceAt = nil
local gameAppActive = true
local MAX_SPEC_PLAYER_ID = 1000
local lastSpecStepAt = 0
local lastSpectateHealthAt = 0
local expectSpectateOff = false

local trim, stripTags, sendChat, sendMenuOutbound, uiText, toU32
local col_accent, col_accent_dim, col_muted, col_muted2, col_label, col_warn
local sampIsPlayerConnected, sampGetPlayerNickname, sampGetPlayerColor
local sampGetPlayerPing, sampGetPlayerScore
local inputDeps

-- Проверка playerSpectating из input deps.
local function specPlayerActive()
    return inputDeps and inputDeps.getPlayerSpectating and inputDeps.getPlayerSpectating()
end

local CACHE_MAX = 128

local state = {
    targetId = -1,
    targetNick = '',
    pendingStId = nil,
    pendingStAt = 0,
    stShowNative = false,
    lastAutoStAt = 0,
    lastAutoStScheduleAt = 0,
    lastSyncFromSessionAt = 0,
    cache = {},
    cacheOrder = {},
    hudDrag = { active = false, offX = 0, offY = 0 },
    hudHovered = false,
    hudPlaced = false,
    persistHudId = -1,
    pendingSpId = nil,
    pendingSpNick = '',
    pendingSpAt = 0,
    lastSpOutboundAt = 0,
}

-- ID цели на handshake /sp: pending → session → локальный state.
local function resolveSpectateHandshakeId()
    local pid = tonumber(state.pendingSpId)
    if pid and pid >= 0 then return pid end
    if specSession.isAwaitingSpectate and specSession.isAwaitingSpectate() then
        return -1
    end
    if specSession.getTargetId then
        pid = specSession.getTargetId()
        if pid and pid >= 0 then return pid end
    end
    if specPlayerActive() then
        pid = tonumber(state.targetId)
        if pid and pid >= 0 then return pid end
    end
    return -1
end

-- Nick цели на handshake /sp.
local function resolveSpectateTargetNick(pid)
    pid = tonumber(pid)
    local nick = trim(state.pendingSpNick or '')
    if nick == '' and specSession.getTargetNick then
        local sn = specSession.getTargetNick()
        if sn and sn ~= '' then nick = trim(sn) end
    end
    if nick == '' and tonumber(state.targetId) == pid and state.targetNick ~= '' then
        nick = state.targetNick
    end
    if nick == '' and sampGetPlayerNickname and sampIsPlayerConnected then
        pcall(function()
            if sampIsPlayerConnected(pid) then
                nick = trim(sampGetPlayerNickname(pid) or '')
            end
        end)
    end
    return nick
end

local HUD_PANEL_W = 268
local HUD_LABEL_W = 104
local HUD_PAD_X = 12

local STAT_STACK_FIELDS = {
    org = true,
    rank = true,
    job = true,
    family = true,
    status = true,
}

local STAT_STACK_MIN_W = 150

local function statLabelWidth(label)
    label = uiText(label or '')
    local w = imgui.CalcTextSize(label).x + 8
    local minVal = 80
    local maxLbl = HUD_PANEL_W - HUD_PAD_X * 2 - minVal
    return math.max(HUD_LABEL_W, math.min(w, maxLbl))
end

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

-- Low
local function low(s)
    s = trim(s or '')
    if s == '' then return '' end
    return s:lower()
end

-- Vec4
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

-- Samp Color To Im Vec4
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

-- Org Text For Color
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

-- Nick Color From Org Text
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

-- Is Near White Or Gray
local function isNearWhiteOrGray(c)
    if not c then return false end
    local r, g, b = c.x, c.y, c.z
    local maxc = math.max(r, g, b)
    local minc = math.min(r, g, b)
    if maxc < 0.45 then return false end
    return (maxc - minc) < 0.12
end

-- Публичный API модуля.
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

-- Публичный API модуля.
function M.isGameTextInputActive()
    if inputDeps and inputDeps.sampIsChatInputActive and inputDeps.sampIsChatInputActive() then
        return true
    end
    if inputDeps and inputDeps.sampIsDialogActive and inputDeps.sampIsDialogActive() then
        return true
    end
    return false
end

-- Публичный API модуля.
function M.frameWantsCursor()
    if M.isGameTextInputActive() then return true end
    if state.hudDrag.active then return true end
    if specPlayerActive() then return false end
    if state.hudHovered then return true end
    return false
end

-- Label Has
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

-- Classify Label
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
    if labelHas(label, '\xC4\xEE\xEB\xE6\xED\xEE\xF1\xF2', '\xE4\xEE\xEB\xE6\xED\xEE\xF1\xF2', 'dolzhnost') then
        return 'job'
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

-- Strip Dialog Markup
local function stripDialogMarkup(s)
    s = stripTags(s or '')
    s = s:gsub('{[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f]}', '')
    return trim(s)
end

-- Split Label Value
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
        local tabs = select(2, line:gsub('\t', ''))
        if tabs == 1 then
            label, value = line:match('^(.-)%s*\t%s*(.+)$')
        end
    end
    if label and value then
        return trim(label), trim(value)
    end
    return nil, nil
end

-- Store Field
local function storeField(e, key, value)
    if not e or not key or not value or value == '' then return end
    value = trim(value)
    if value == '' or value == '-' or value == '\xCD\xE5\xF2' then return end
    e.fields[key] = value
end

-- Normalize Warns Value
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

-- Split Tab Cols
local function splitTabCols(line)
    local cols = {}
    for col in tostring(line or ''):gmatch('[^\t]+') do
        cols[#cols + 1] = trim(col)
    end
    return cols
end

-- Line Looks Like Stats Header
local function lineLooksLikeStatsHeader(cols)
    if #cols < 2 then return false end
    for _, c in ipairs(cols) do
        if c ~= '' and not classifyLabel(c) then
            return false
        end
    end
    return true
end

-- Parse Tab Stats Block
local function parseTabStatsBlock(text, e)
    if not text or not e then return end
    local headerKeys = nil
    for line in text:gmatch('[^\r\n]+') do
        line = stripDialogMarkup(line)
        if line ~= '' and line:find('\t', 1, true) then
            local cols = splitTabCols(line)
            if lineLooksLikeStatsHeader(cols) then
                headerKeys = {}
                for _, c in ipairs(cols) do
                    headerKeys[#headerKeys + 1] = classifyLabel(c)
                end
            elseif headerKeys then
                for i, key in ipairs(headerKeys) do
                    local val = cols[i]
                    if key and val and val ~= '' then
                        if key == 'warns' then
                            storeField(e, key, normalizeWarnsValue(val))
                        else
                            storeField(e, key, val)
                        end
                    end
                end
                headerKeys = nil
            elseif #cols == 2 then
                local key = classifyLabel(cols[1])
                if key then
                    if key == 'warns' then
                        storeField(e, key, normalizeWarnsValue(cols[2]))
                    else
                        storeField(e, key, cols[2])
                    end
                end
            end
        end
    end
end

-- Extra Label Ok
local function extraLabelOk(lbl)
    lbl = trim(lbl or '')
    if lbl == '' then return false end
    if classifyLabel(lbl) then return false end
    return true
end

-- Cache Protect Id
local function cacheProtectId(id)
    id = tonumber(id)
    if id == nil then return false end
    if id == state.targetId or id == state.persistHudId then return true end
    return false
end

-- Touch Cache Id
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

-- Extract Warns From Text
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

-- Парсинг данных с сервера/чата.
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

-- Resolve Dialog Close Button
local function resolveDialogCloseButton(button1, button2)
    if button1 and trim(button1) ~= '' then return 1 end
    if button2 and trim(button2) ~= '' then return 0 end
    return 1
end

-- Close Stats Dialog Once
local function closeStatsDialogOnce(dialogId, button1, button2)
    local btn = resolveDialogCloseButton(button1, button2)
    if type(sampSendDialogResponse) == 'function' and dialogId then
        pcall(sampSendDialogResponse, dialogId, btn, 0, '')
    end
    if type(sampCloseCurrentDialogWithButton) == 'function' then
        pcall(sampCloseCurrentDialogWithButton, btn)
    end
end

-- Close Stats Dialog Once — повтор через 120/350 ms (SAMP иногда игнорирует первый ответ).
local function deferCloseStatsDialog(dialogId, button1, button2)
    closeStatsDialogOnce(dialogId, button1, button2)
    if not lua_thread or not lua_thread.create then return end
    lua_thread.create(function()
        wait(120)
        closeStatsDialogOnce(dialogId, button1, button2)
        wait(350)
        if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then
            closeStatsDialogOnce(dialogId, button1, button2)
        end
    end)
end

-- Text Has Any
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

-- Dialog Has Stats Body
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

-- Ensure Entry
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

-- Clear Pending St
local function clearPendingSt()
    state.pendingStId = nil
    state.pendingStAt = 0
    state.stShowNative = false
end

-- Reset Entry Stats
local function resetEntryStats(e)
    if not e then return end
    e.fields = {}
    e.extras = {}
    e.updatedAt = 0
end

-- Публичный API модуля.
function M.getTargetId()
    local sid = specSession.getTargetId and specSession.getTargetId() or -1
    if sid >= 0 then return sid end
    if specPlayerActive() then
        local pending = tonumber(state.pendingSpId)
        if pending and pending >= 0 then return pending end
        return -1
    end
    local tid = tonumber(state.targetId)
    if tid and tid >= 0 then return tid end
    return -1
end

-- Публичный API модуля.
function M.getMyPlayerId()
    if sampGetPlayerIdByCharHandle then
        local ok, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
        if ok and id then return tonumber(id) or -1 end
    end
    return -1
end

-- Публичный API модуля.
function M.getMaxPlayerId()
    local maxId = MAX_SPEC_PLAYER_ID
    if sampGetMaxPlayerId then
        local ok, n = pcall(sampGetMaxPlayerId, false)
        if ok and n then maxId = tonumber(n) or maxId end
    end
    return maxId
end

-- Публичный API модуля.
function M.isSpectateCandidate(id)
    id = tonumber(id)
    if not id or id < 0 then return false end
    if not sampIsPlayerConnected or not sampIsPlayerConnected(id) then return false end
    local me = M.getMyPlayerId()
    if me >= 0 and id == me then return false end
    return true
end

-- Публичный API модуля.
function M.findAdjacentSpectateId(curId, delta)
    curId = tonumber(curId)
    if curId == nil then return nil end
    local maxId = M.getMaxPlayerId()
    local me = M.getMyPlayerId()
    delta = (tonumber(delta) or 0) >= 0 and 1 or -1
    local function candidate(id)
        id = tonumber(id)
        if not id or id < 0 then return false end
        if me >= 0 and id == me then return false end
        return sampIsPlayerConnected and sampIsPlayerConnected(id)
    end
    if delta > 0 then
        for i = curId + 1, maxId do
            if candidate(i) then return i end
        end
        for i = 0, curId - 1 do
            if candidate(i) then return i end
        end
    else
        for i = curId - 1, 0, -1 do
            if candidate(i) then return i end
        end
        for i = maxId, curId + 1, -1 do
            if candidate(i) then return i end
        end
    end
    return nil
end

-- Публичный API модуля.
function M.stepSpectate(delta)
    local now = os.clock()
    if now - lastSpecStepAt < SPEC_STEP_COOLDOWN then
        return false
    end
    lastSpecStepAt = now
    local cur = M.getTargetId()
    if cur < 0 then
        cur = M.getMyPlayerId()
        if cur < 0 then cur = 0 end
    end
    local nextId = M.findAdjacentSpectateId(cur, delta)
    if not nextId then return false end
    M.markPendingSpCommand(nextId, '')
    local cmd = 'sp ' .. tostring(nextId)
    if sendMenuOutbound then
        sendMenuOutbound(cmd, { skipPendingMark = true })
    elseif sendChat then
        sendChat(cmd)
    end
    return true
end

-- Публичный API модуля.
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

-- Запрос /st после подтверждённого SP (не в том же тике, что server confirm).
local function scheduleAutoStats(id, force)
    id = tonumber(id)
    if not id or id < 0 then return end
    local now = os.clock()
    if state.pendingStId == id and (now - (state.pendingStAt or 0)) < 1.0 then
        return
    end
    if now - (state.lastAutoStScheduleAt or 0) < 0.45 then
        return
    end
    if M.getTargetId() ~= id then return end
    if specSession.isActive and not specSession.isActive() then return end
    state.lastAutoStScheduleAt = now
    M.requestStats(id, { force = force == true })
end

-- Публичный API модуля.
function M.syncFromSession(id, nick, settings, syncOpts)
    syncOpts = syncOpts or {}
    id = tonumber(id)
    if not id or id < 0 then
        state.targetId = -1
        state.targetNick = ''
        return
    end
    local nowSync = os.clock()
    if state.targetId == id and state.lastSyncFromSessionAt
            and (nowSync - state.lastSyncFromSessionAt) < 0.35 then
        return
    end
    state.lastSyncFromSessionAt = nowSync

    local prevId = state.targetId
    if prevId ~= id then
        state.hudPlaced = false
        pcall(specMenuMod.resetMenuSelection)
        clearPendingSt()
    end
    M.cancelPendingSp()
    expectSpectateOff = false
    state.targetId = id
    state.targetNick = trim(nick or '')
    pcall(spRefresh.onTargetConfirmed, id, { fullBaseline = prevId ~= id })
    if inputDeps and inputDeps.setPlayerSpectating then
        inputDeps.setPlayerSpectating(true)
    end
    if inputDeps and inputDeps.rememberSpectateCursor then
        pcall(inputDeps.rememberSpectateCursor)
    end
    if inputDeps and inputDeps.updateInputPassthrough then
        pcall(inputDeps.updateInputPassthrough)
    end
    local e = ensureEntry(id)
    if e then
        if state.targetNick ~= '' then e.nick = state.targetNick end
        if prevId ~= id then
            resetEntryStats(e)
            if state.targetNick ~= '' then e.nick = state.targetNick end
        end
        M.refreshLivePing(id)
    end
    local s = settings
    if not s and getSettings then s = getSettings() end
    if not (e and s and s.spectate_auto_st ~= false) or syncOpts.skipAutoSt then
        return
    end
    local mustForce = syncOpts.forceAutoSt == true or prevId ~= id
    if syncOpts.forceAutoSt and prevId == id then
        resetEntryStats(e)
        if state.targetNick ~= '' then e.nick = state.targetNick end
    end
    if mustForce then
        M.refreshLivePing(id)
        scheduleAutoStats(id, true)
        return
    end
    M.maybeAutoRequest(id, s, false)
end

-- Публичный API модуля.
function M.markPendingSpCommand(id, nick)
    id = tonumber(id)
    if not id or id < 0 then return end
    nick = trim(nick or '')
    if nick == '' and sampIsPlayerConnected and sampGetPlayerNickname then
        pcall(function()
            if sampIsPlayerConnected(id) then
                nick = trim(sampGetPlayerNickname(id) or '')
            end
        end)
    end
    state.pendingSpId = id
    state.pendingSpNick = nick
    state.pendingSpAt = os.clock()
    state.lastSpOutboundAt = state.pendingSpAt
    state.spChatRecoveryTried = false
    local cur = M.getTargetId()
    if cur ~= id then
        if cur >= 0 then clearPendingSt() end
        pcall(vehicleHud.reset)
        pcall(keysHud.reset)
        pcall(spRefresh.resetContext)
    end
    pcall(specSession.markAwaitingSpectate, true)
    if spUi.ensureSpectateSampevHooks then
        local sampev = inputDeps and inputDeps.sampev
        local specSessionMod = package.loaded['report_desk_spectate_session']
        local hooksOk = sampev and specSessionMod and specSessionMod.areSampevHooksActive
            and specSessionMod.areSampevHooksActive(sampev)
        if not hooksOk then
            pcall(spUi.ensureSpectateSampevHooks)
        end
    end
end

-- Публичный API модуля.
function M.cancelPendingSp()
    if not state.pendingSpId then return end
    state.pendingSpId = nil
    state.pendingSpNick = ''
    state.pendingSpAt = 0
    pcall(specSession.markAwaitingSpectate, false)
end

-- Публичный API модуля.
function M.hasPendingSp()
    return state.pendingSpId ~= nil
end

-- Plain Server Msg
local function plainServerMsg(text)
    text = stripTags(text or '')
    return text:gsub('{[0-9A-Fa-f]+}', '')
end

-- Is Sp Command Rejected
local function isSpCommandRejected(text)
    local plain = plainServerMsg(text)
    if plain == '' then return false end
    if plain:find('\xF3\xE6\xE5', 1, true) and plain:find('\xF0\xE5\xE6\xE8\xEC', 1, true) then
        return true
    end
    if plain:find('\xE0\xE2\xF2\xEE\xF0\xE8\xE7', 1, true) then return true end
    if plain:find('\xED\xE5\xEB\xFC\xE7\xFF', 1, true) and plain:find('\xF1\xEB\xE5\xE4', 1, true) then
        return true
    end
    if plain:find('spectate', 1, true) and plain:find('already', 1, true) then return true end
    if plain:find('not authorized', 1, true) or plain:find('not logged', 1, true) then
        return true
    end
    return false
end

local lastStatsWatchdogAt = 0

-- Публичный API модуля.
function M.tickStatsDialogWatchdog()
    if state.stShowNative then return end
    if not M.hasPendingSt() then return end
    local now = os.clock()
    if now - (state.pendingStAt or 0) < 0.4 then return end
    if now - lastStatsWatchdogAt < 0.5 then return end
    if type(sampIsDialogActive) ~= 'function' or not sampIsDialogActive() then return end
    lastStatsWatchdogAt = now
    closeStatsDialogOnce(nil, 'Close', '')
end

-- Публичный API модуля.
function M.tickPendingSp()
    if state.pendingSpId or specPlayerActive() then
        M.tickSpectateHealth()
    end
    if M.hasPendingSt() then
        M.tickStatsDialogWatchdog()
    end
    local id = state.pendingSpId
    if not id then return end
    local at = tonumber(state.pendingSpAt) or 0
    local elapsed = at > 0 and (os.clock() - at) or 0
    local confirmed = specSession.isActive and specSession.isActive()
    if not confirmed and specPlayerActive() and elapsed >= 1.0 and elapsed <= PENDING_SP_SEC then
        if not state.spChatRecoveryTried then
            state.spChatRecoveryTried = true
            pcall(specSession.tryRecoverFromChat)
            if specSession.isActive and specSession.isActive() then
                M.cancelPendingSp()
                return
            end
        end
    end
    if at > 0 and elapsed > PENDING_SP_SEC then
        M.cancelPendingSp()
    end
end
-- Публичный API модуля.
function M.forceExitSpectate(opts)
    opts = opts or {}
    local now = os.clock()
    if not opts.allowRepeat and now - lastForceExitAt < SPECTATE_FORCE_EXIT_COOLDOWN then
        return false
    end
    lastForceExitAt = now
    expectSpectateOff = true
    M.clearSpectateTarget(true)
    M.onSpCommandOff()
    if opts.sendServer ~= false then
        if sendMenuOutbound then
            sendMenuOutbound('sp')
        elseif sendChat then
            sendChat('sp')
        end
    end
    return true
end

-- Публичный API модуля.
-- === Spectate health: orphan/offline detection ===
function M.tickSpectateHealth()
    if specPlayerActive() and spRefresh.needsTick and spRefresh.needsTick() then
        pcall(spRefresh.tick)
    end
    local now = os.clock()
    if now - lastSpectateHealthAt < SPECTATE_HEALTH_INTERVAL then
        return
    end
    lastSpectateHealthAt = now

    if not gameAppActive then
        targetOfflineSinceAt = nil
        orphanSinceAt = nil
        orphanRecoveryTried = false
        return
    end
    if not specPlayerActive() then
        orphanSinceAt = nil
        orphanRecoveryTried = false
            targetOfflineSinceAt = nil
        return
    end
    if M.hasPendingSp() then
        orphanSinceAt = nil
        orphanRecoveryTried = false
        targetOfflineSinceAt = nil
        return
    end
    local sessionConfirmed = specSession.isActive and specSession.isActive()
    if specPlayerActive() and not sessionConfirmed then
        local outboundAt = tonumber(state.lastSpOutboundAt) or 0
        if outboundAt > 0 and (now - outboundAt) < PENDING_SP_SEC + 2.0 then
            orphanSinceAt = nil
            orphanRecoveryTried = false
            targetOfflineSinceAt = nil
            return
        end
    end
    local id = M.getTargetId()
    if id < 0 then
        targetOfflineSinceAt = nil
        orphanSinceAt = orphanSinceAt or now
        local elapsed = now - orphanSinceAt
        if elapsed >= 1.0 and not orphanRecoveryTried then
            orphanRecoveryTried = true
            if specSession.tryRecoverFromChat and specSession.tryRecoverFromChat() then
                orphanSinceAt = nil
                return
            end
        end
        if elapsed < SPECTATE_ORPHAN_GRACE_SEC then
            return
        end
        orphanSinceAt = nil
        orphanRecoveryTried = false
        -- Локальная очистка UI: сервер может быть в валидном SP refresh, sp toggle опасен.
        M.forceExitSpectate({ reason = 'orphan', sendServer = false })
        return
    end
    orphanSinceAt = nil
    orphanRecoveryTried = false
    if sessionConfirmed and id >= 0 and sampIsPlayerConnected and not sampIsPlayerConnected(id) then
        targetOfflineSinceAt = targetOfflineSinceAt or now
        if now - targetOfflineSinceAt < SPECTATE_TARGET_OFFLINE_GRACE_SEC + 1.5 then
            return
        end
        targetOfflineSinceAt = nil
        M.forceExitSpectate({ reason = 'target_offline', sendServer = true })
        return
    end
    targetOfflineSinceAt = nil
end

-- Публичный API модуля.
function M.setSpectateTarget(id, nick, settings)
    id = tonumber(id)
    if not id or id < 0 then
        state.targetId = -1
        state.targetNick = ''
        return
    end
    local prevId = state.targetId
    if prevId ~= id then
        state.hudPlaced = false
        pcall(specMenuMod.resetMenuSelection)
        clearPendingSt()
    end
    state.targetId = id
    state.targetNick = trim(nick or '')
    local e = ensureEntry(id)
    if e then
        if prevId ~= id then
            resetEntryStats(e)
        end
        if state.targetNick ~= '' then e.nick = state.targetNick end
        M.refreshLivePing(id)
    end
    if specPlayerActive and specPlayerActive() then
        pcall(specSession.setSpectating, true)
    end
end

-- Публичный API модуля.
function M.persistHudEnabled(settings)
    settings = settings or (getSettings and getSettings())
    if not settings then return true end
    local v = settings.spectate_hud_persist
    if v == false or v == 0 or v == 'false' or v == '0' then return false end
    return true
end

-- Публичный API модуля.
function M.shouldPersistHud()
    return M.persistHudEnabled()
end

-- Публичный API модуля.
function M.snapshotPersistHud()
    if not M.persistHudEnabled() then return end
    local id = tonumber(state.targetId)
    if id and id >= 0 then state.persistHudId = id end
end

-- Публичный API модуля.
function M.getHudDisplayId()
    local id = M.getTargetId()
    if id >= 0 then return id end
    if specPlayerActive() then return -1 end
    id = tonumber(state.persistHudId)
    if id and id >= 0 then return id end
    return -1
end

-- Публичный API модуля.
function M.clearSpectateTarget(force)
    if not force and M.persistHudEnabled() then
        M.snapshotPersistHud()
        return
    end
    state.targetId = -1
    state.targetNick = ''
    state.persistHudId = -1
    pcall(spRefresh.resetContext)
    M.cancelPendingSp()
    pcall(specMenuMod.resetMenuSelection)
    pcall(specCamera.onSpectateEnd)
    pcall(keysHud.reset)
end

-- Публичный API модуля.
function M.isHudActive()
    local id = tonumber(state.targetId)
    return id and id >= 0
end

-- Публичный API модуля.
function M.shouldShowHud(settings)
    if not settings or settings.spectate_hud == false then return false end
    return M.getHudDisplayId() >= 0
end

-- Публичный API модуля.
function M.hasPendingSt()
    local pid = state.pendingStId
    if not pid then
        state.stShowNative = false
        return false
    end
    if (os.clock() - (state.pendingStAt or 0)) > PENDING_ST_SEC then
        state.pendingStId = nil
        state.stShowNative = false
        return false
    end
    return true
end

-- Публичный API модуля.
function M.markPendingSt(id, opts)
    opts = opts or {}
    id = tonumber(id)
    if not id or id < 0 then return end
    state.pendingStId = id
    state.pendingStAt = os.clock()
    state.stShowNative = opts.showDialog == true
end

-- Публичный API модуля.
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

-- Публичный API модуля.
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

-- Публичный API модуля.
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
    parseTabStatsBlock(text, e)

    local pendingKey = nil
    for line in text:gmatch('[^\r\n]+') do
        if not line:find('\t', 1, true) then
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
                elseif extraLabelOk(label) then
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
    end

    parseBulkFields(text, e)
    if e.fields.level == '0' then
        e.fields.level = nil
    end
    e.updatedAt = os.time()
    M.refreshLivePing(playerId)
    return e
end

-- Публичный API модуля.
function M.requestStats(id, opts)
    opts = opts or {}
    id = tonumber(id) or M.getTargetId()
    if not id or id < 0 then return false end
    M.markPendingSt(id, { showDialog = opts.showDialog == true })
    if opts.force then
        state.lastAutoStAt = os.clock()
    end
    local cmd = 'st ' .. tostring(id)
    if sendMenuOutbound then
        pcall(sendMenuOutbound, cmd)
        return true
    end
    if not sendChat then return false end
    sendChat(cmd)
    return true
end

-- Публичный API модуля.
function M.maybeAutoRequest(id, settings, force)
    if not settings or settings.spectate_auto_st == false then return end
    id = tonumber(id) or state.targetId
    if not id or id < 0 then return end
    local now = os.clock()
    if not force and now - state.lastAutoStAt < AUTO_ST_COOLDOWN then return end
    state.lastAutoStAt = now
    M.requestStats(id, {})
end

-- Публичный API модуля.
function M.autoRequestIfEnabled(id, settings)
    if not settings or settings.spectate_auto_st == false then return end
    M.requestStats(tonumber(id), {})
end

-- Публичный API модуля.
function M.onServerMessage(color, text)
    if not text or text == '' then return false end
    if state.pendingSpId and isSpCommandRejected(text) then
        M.cancelPendingSp()
        return false
    end
    color = tonumber(color) or 0
    if color < 0 then color = color + 4294967296 end
    if color == SP_MSG_COLOR or text:find('%[SP%]', 1, true) then
        pcall(specSession.parseSpLine, text)
        return M.parseSpServerLine(text)
    end
    return false
end

-- Публичный API модуля.
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

-- Extract Dialog Player Id From Title
local function extractDialogPlayerIdFromTitle(title)
    local titlePlain = stripDialogMarkup(title or '')
    return tonumber(titlePlain:match('%[(%d+)%]'))
end

-- Extract Dialog Player Id From Body
local function extractDialogPlayerIdFromBody(text)
    local plain = stripDialogMarkup(text or '')
    return tonumber(plain:match('%[(%d+)%]'))
end

-- Dialog Looks Like Stats For Target
local function dialogLooksLikeStatsForTarget(title, text, targetId)
    if M.dialogLooksLikePlayerStats(title, text, targetId) then return true end
    local plain = stripDialogMarkup(text or '')
    if plain == '' then return false end
    return dialogHasStatsBody(plain)
end

-- Resolve Stats Dialog Owner
local function resolveStatsDialogOwner(title, text)
    local plain = stripDialogMarkup(text or '')
    if plain == '' then return nil end
    if not dialogLooksLikeStatsForTarget(title, text, nil) then
        return nil
    end

    local targetId = M.getTargetId()
    local pendingId = state.pendingStId
    local pendingFresh = pendingId and (os.clock() - (state.pendingStAt or 0)) <= PENDING_ST_SEC
    local titleId = extractDialogPlayerIdFromTitle(title)

    -- Авто /st в /sp: перехват без жёсткого совпадения titleId.
    if pendingFresh and pendingId and not state.stShowNative then
        if titleId and titleId ~= pendingId then
            local bodyId = extractDialogPlayerIdFromBody(text)
            if bodyId and bodyId ~= pendingId then
                return nil
            end
        end
        return pendingId
    end

    if titleId then
        if pendingFresh and titleId == pendingId then
            return titleId
        end
        if targetId >= 0 and titleId == targetId then
            return titleId
        end
        if pendingFresh and targetId >= 0
                and dialogLooksLikeStatsForTarget(title, text, targetId) then
            return targetId
        end
        if state.stShowNative and pendingFresh and titleId == pendingId then
            return titleId
        end
        return nil
    end

    if pendingFresh and pendingId then
        local bodyId = extractDialogPlayerIdFromBody(text)
        if bodyId and bodyId ~= pendingId then
            return nil
        end
        return pendingId
    end

    if targetId >= 0 and dialogLooksLikeStatsForTarget(title, text, targetId) then
        return targetId
    end

    return nil
end

-- Публичный API модуля.
function M.shouldInterceptStatsDialog(title, text, style)
    local ownerId = resolveStatsDialogOwner(title, text)
    if not ownerId then
        return false, nil
    end
    return true, ownerId
end

-- Show Native Stats Dialog
local function shouldShowNativeStatsDialog(pid)
    if not state.stShowNative then return false end
    pid = tonumber(pid)
    if not pid or pid < 0 then return false end
    if tonumber(state.pendingStId) ~= pid then return false end
    return (os.clock() - (state.pendingStAt or 0)) <= PENDING_ST_SEC
end

-- Публичный API модуля.
-- === Запрос /st и parse stat dialog ===
function M.onShowDialog(dialogId, style, title, button1, button2, text)
    local ok, pid = M.shouldInterceptStatsDialog(title, text, style)
    if not ok or not pid then
        return false
    end
    if shouldShowNativeStatsDialog(pid) then
        return false
    end

    local plain = stripDialogMarkup(text or '')
    M.parseDialogText(plain, pid)
    clearPendingSt()
    deferCloseStatsDialog(dialogId, button1, button2)
    return true
end

-- Публичный API модуля.
function M.getEntry(id)
    id = tonumber(id)
    if not id or id < 0 then return nil end
    M.refreshLivePing(id)
    return state.cache[id]
end

-- Публичный API модуля.
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

-- Публичный API модуля.
function M.pingColor(pingStr)
    local p = tonumber(pingStr)
    if not p then return col_muted2 end
    if p < 80 then return imgui.ImVec4(0.38, 0.88, 0.48, 1.0) end
    if p < 150 then return col_warn end
    return imgui.ImVec4(0.92, 0.38, 0.38, 1.0)
end

-- Hud Value Width
local function hudValueWidth()
    return HUD_PANEL_W - HUD_PAD_X * 2 - HUD_LABEL_W
end

-- Hud Content Width
local function hudContentWidth()
    return HUD_PANEL_W - HUD_PAD_X * 2
end

-- Wrap Words To Lines
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
    local function splitLongWord(word)
        local parts = {}
        local chunk = ''
        for i = 1, #word do
            local ch = word:sub(i, i)
            local try = chunk .. ch
            if chunk ~= '' and imgui.CalcTextSize(try).x > maxWidth then
                parts[#parts + 1] = chunk
                chunk = ch
            else
                chunk = try
            end
        end
        if chunk ~= '' then parts[#parts + 1] = chunk end
        return parts
    end
    for word in text:gmatch('%S+') do
        local wW = imgui.CalcTextSize(word).x
        if wW > maxWidth then
            flush()
            for _, part in ipairs(splitLongWord(word)) do
                lines[#lines + 1] = part
            end
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

-- Публичный API модуля.
function M.drawStatRow(label, value, valueCol, opts)
    if not value or trim(tostring(value)) == '' then return end
    opts = type(opts) == 'table' and opts or {}
    local col = valueCol or col_label
    local stack = opts.stack == true
    local maxW = stack and hudContentWidth() or hudValueWidth()
    local lines = wrapWordsToLines(value, maxW)
    if #lines == 0 then return end
    local lblCol = spTheme.labelCol and spTheme.labelCol() or col_muted2
    local labelW = statLabelWidth(label)
    imgui.AlignTextToFramePadding()
    imgui.TextColored(lblCol, uiText(label))
    if stack then
        for _, line in ipairs(lines) do
            imgui.TextColored(col, line)
        end
        return
    end
    imgui.SameLine(labelW)
    imgui.TextColored(col, lines[1])
    for i = 2, #lines do
        imgui.SetCursorPosX(labelW)
        imgui.TextColored(col, lines[i])
    end
end

-- Публичный API модуля.
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
local WARN_LEVEL_MAX = 3
local WANTED_STAR_OUTER = 5.5
local WANTED_STAR_INNER = 2.3
local WANTED_STAR_STEP = 13
local STAR_ROW_PAD = 3
local HUD_ID_COLOR = imgui.ImVec4(0.95, 0.95, 0.97, 1.0)

-- Draw Wanted Star
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

-- Normalize Wanted Level
local function normalizeWantedLevel(val)
    val = trim(val or '')
    if val == '' then return nil end
    local n = tonumber(val:match('^(%d+)'))
    if n == nil then return nil end
    return math.max(0, math.min(WANTED_LEVEL_MAX, math.floor(n + 0.5)))
end

local function parseWarnsFraction(value)
    value = trim(value or '')
    if value == '' then return nil end
    local a, b = value:match('(%d+)%s*/%s*(%d+)')
    if a and b then return tonumber(a), tonumber(b) end
    a, b = value:match('(%d+)%s*èç%s*(%d+)')
    if a and b then return tonumber(a), tonumber(b) end
    a = value:match('^(%d+)$')
    if a then return tonumber(a), WARN_LEVEL_MAX end
    return nil
end

local function warnStarColor(active)
    if not active then
        return imgui.ImVec4(0.38, 0.36, 0.42, 0.55)
    end
    return col_warn or imgui.ImVec4(1.0, 0.86, 0.18, 1.0)
end

local function drawStarRatingRow(label, current, maxSlots, colorFn)
    maxSlots = math.max(1, math.min(WANTED_LEVEL_MAX, tonumber(maxSlots) or 1))
    current = math.max(0, math.min(maxSlots, tonumber(current) or 0))
    local lblCol = spTheme.labelCol and spTheme.labelCol() or col_muted2
    local labelW = statLabelWidth(label)
    imgui.AlignTextToFramePadding()
    imgui.TextColored(lblCol, uiText(label))
    imgui.SameLine(labelW)

    local dl = imgui.GetWindowDrawList()
    local starH = WANTED_STAR_OUTER * 2 + STAR_ROW_PAD
    local lineH = math.max(imgui.GetTextLineHeight(), starH)
    local base = imgui.GetCursorScreenPos()
    local centerY = base.y + lineH * 0.5
    local startX = base.x + WANTED_STAR_OUTER

    for i = 1, maxSlots do
        local cx = startX + (i - 1) * WANTED_STAR_STEP
        local active = i <= current
        drawWantedStar(dl, cx, centerY, active, colorFn(i, active, current))
    end

    imgui.Dummy(imgui.ImVec2(maxSlots * WANTED_STAR_STEP + WANTED_STAR_OUTER, lineH))
end

-- Публичный API модуля.
function M.drawWantedRow(label, value)
    local lvl = normalizeWantedLevel(value)
    if lvl == nil then return end
    drawStarRatingRow(label, lvl, WANTED_LEVEL_MAX, function(_, active, l)
        return M.wantedColor(l, active)
    end)
end

-- Публичный API модуля.
function M.drawWarnsRow(label, value)
    local cur, max = parseWarnsFraction(value)
    if cur == nil then
        M.drawStatRow(label, value, col_warn)
        return
    end
    max = math.max(cur, math.min(WANTED_LEVEL_MAX, tonumber(max) or WARN_LEVEL_MAX))
    drawStarRatingRow(label, cur, max, function(_, active)
        return warnStarColor(active)
    end)
end

-- Should Stack Field Value
local function shouldStackFieldValue(val)
    val = uiText and uiText(val or '') or (val or '')
    if val == '' then return false end
    return imgui.CalcTextSize(val).x > STAT_STACK_MIN_W
end

-- Field Value Visible
local function fieldValueVisible(key, val)
    val = trim and trim(val or '') or (val or '')
    if val == '' or val == '-' or val == '\xCD\xE5\xF2' then
        if key == 'warns' or key == 'wanted' then
            return val ~= ''
        end
        return false
    end
    if key == 'level' and val == '0' then return false end
    return true
end

-- Field Value Color
local function fieldValueColor(key, val)
    if key == 'ping' then return M.pingColor(val) end
    if key == 'level' then return imgui.ImVec4(0.82, 0.72, 1.0, 1.0) end
    if key == 'warns' then return col_warn end
    if key == 'money' then return imgui.ImVec4(0.55, 0.92, 0.62, 1.0) end
    return col_label
end

-- Draw Stats Body
local function drawStatsBody(e)
    local hasAny = false
    for _, key in ipairs(HUD_FIELD_ORDER) do
        local val = e.fields[key]
        if fieldValueVisible(key, val) then
            hasAny = true
            local lbl = FIELD_LABELS[key] or key
            local vcol = fieldValueColor(key, val)
            if key == 'wanted' then
                M.drawWantedRow(lbl, val)
            elseif key == 'warns' then
                M.drawWarnsRow(lbl, val)
            elseif STAT_STACK_FIELDS[key] and shouldStackFieldValue(val) then
                M.drawStatRow(lbl, val, vcol, { stack = true })
            else
                M.drawStatRow(lbl, val, vcol)
            end
        end
    end
    return hasAny
end

-- Draw Hud Nick Header
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

-- Clamp Hud Pos
local function clampHudPos(hx, hy, winW, winH, sw, sh, pivotX)
    winW = math.max(HUD_PANEL_W, tonumber(winW) or HUD_PANEL_W)
    winH = math.max(48, tonumber(winH) or 120)
    -- pivotX=1: hx = screen X of right edge (after hx = sw + rawX); pivotX=0: left edge.
    if pivotX == 1 then
        hx = math.max(winW + 8, math.min(hx, sw - 8))
    else
        hx = math.max(8, math.min(hx, sw - winW - 8))
    end
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

-- Публичный API модуля.
function M.drawOverlay(settings)
    local ok, err = pcall(M.drawOverlayImpl, settings)
    if not ok then
        print('[Report Desk] spectate stats HUD: ' .. tostring(err))
    end
end

-- Публичный API модуля.
function M.drawOverlayImpl(settings)
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

    local drag = state.hudDrag
    if drag.active then
        hx = drag.offX
        hy = drag.offY
        pivotX = 0
    end

    local wantInput = M.wantsHudInput() or drag.active
    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoScrollbar
    if not wantInput and imgui.WindowFlags.NoInputs then
        flags = flags + imgui.WindowFlags.NoInputs
    end
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoSavedSettings then
        flags = flags + imgui.WindowFlags.NoSavedSettings
    end

    imgui.SetNextWindowSize(imgui.ImVec2(HUD_PANEL_W, 0), imgui.Cond.Always)
    if imgui.SetNextWindowBgAlpha then
        imgui.SetNextWindowBgAlpha(spTheme.HUD_OVERLAY_ALPHA or 0.80)
    end
    imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always, imgui.ImVec2(pivotX, 0))

    spTheme.pushHudChrome()
    if imgui.Begin('###desk_spec_stats', nil, flags) then
        spTheme.drawPanelFrame()
        if imgui.PushItemWidth then imgui.PushItemWidth(HUD_PANEL_W - HUD_PAD_X * 2) end

        local nick = e.nick
        if (not nick or nick == '') and id == M.getTargetId() and state.targetNick ~= '' then
            nick = state.targetNick
        end
        if not nick or nick == '' then nick = 'ID:' .. id end
        local nickCol = M.nickColorFor(id, e)
        spTheme.drawPlayerHeader(nick, id, nickCol, uiText, { accentCol = col_accent, scale = 1.04 })

        local pendingSt = state.pendingStId == id
            and (os.clock() - (state.pendingStAt or 0)) < PENDING_ST_SEC
        local hasAny = drawStatsBody(e)

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
                    M.drawWarnsRow(FIELD_LABELS.warns, val)
                    break
                end
            end
        end

        if not hasAny and e.extras then
            local shown = 0
            for lbl, val in pairs(e.extras) do
                if shown >= 6 then break end
                if val and val ~= '' and extraLabelOk(lbl) then
                    hasAny = true
                    shown = shown + 1
                    M.drawStatRow(lbl, val, nil, { stack = true })
                end
            end
        end

        if pendingSt and not hasAny then
            imgui.TextColored(col_muted, uiText('\xC7\xE0\xE3\xF0\xF3\xE7\xEA\xE0 \xF1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xE8...'))
        elseif not hasAny then
            imgui.TextColored(col_muted2, uiText('\xCE\xE6\xE8\xE4\xE0\xED\xE8\xE5 /st \xE8\xEB\xE8 \xAB\xCE\xE1\xED\xEE\xE2\xE8\xF2\xFC\xBB'))
        end

        if imgui.PopItemWidth then imgui.PopItemWidth() end

        M.updateHudHoverRect()
        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        imgui.InvisibleButton('##spec_stats_hud_drag', imgui.ImVec2(-1, -1))
        state.hudHovered = imgui.IsItemHovered() or imgui.IsItemActive() or drag.active
        if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
            local delta = imgui.GetMouseDragDelta(0)
            if not drag.active then
                drag.active = true
                drag.startX = wp.x
                drag.startY = wp.y
                drag.pivotX = pivotX
                drag.sw = sw
                imgui.ResetMouseDragDelta(0)
                delta = imgui.GetMouseDragDelta(0)
            end
            drag.offX = drag.startX + delta.x
            drag.offY = drag.startY + delta.y
            drag.offX, drag.offY = clampHudPos(drag.offX, drag.offY, ww, wh, sw, sh, 0)
        elseif drag.active and not imgui.IsMouseDown(0) then
            drag.active = false
            local nx, ny = clampHudPos(wp.x, wp.y, ww, wh, sw, sh, 0)
            if nx + ww > sw * 0.55 then
                settings.spectate_hud_x = math.floor(nx + ww - sw + 0.5)
            else
                settings.spectate_hud_x = math.floor(nx + 0.5)
            end
            settings.spectate_hud_y = math.floor(ny + 0.5)
            if markDirtySettings then markDirtySettings() end
            if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
        end

        imgui.End()
    end
    spTheme.popHudChrome()
end

-- Публичный API модуля.
function M.isHudHovered()
    return state.hudHovered or state.hudDrag.active
end

-- Публичный API модуля.
function M.resetHudDrag()
    state.hudDrag.active = false
    state.hudHovered = false
end

function M.resetSpHudPointers()
    M.resetHudDrag()
    if specMenuMod.clearPointerHover then pcall(specMenuMod.clearPointerHover) end
    if vehicleHud.clearPointerHover then pcall(vehicleHud.clearPointerHover) end
    if keysHud.clearPointerHover then pcall(keysHud.clearPointerHover) end
end

-- Публичный API модуля.
function M.isHudDragActive()
    return state.hudDrag.active
end

-- Публичный API модуля.
function M.wantsHudInput()
    if spUi.isAnsBarOpen and spUi.isAnsBarOpen() then
        return state.hudDrag.active == true
    end
    if type(_G.deskSpectateCameraOwnsInput) == 'function' and _G.deskSpectateCameraOwnsInput() then
        return state.hudDrag.active == true
    end
    if state.hudDrag.active then return true end
    if state.hudHovered then return true end
    local r = state.hudRect
    if not r then return false end
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin then return pin(r) end
    local ok, io = pcall(imgui.GetIO)
    if not ok or not io or not io.MousePos then return false end
    local mp = io.MousePos
    return mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1
end

-- Публичный API модуля.
function M.updateHudHoverRect()
    local p = imgui.GetWindowPos()
    local w = imgui.GetWindowWidth()
    local h = imgui.GetWindowHeight()
    state.hudRect = { x0 = p.x, y0 = p.y, x1 = p.x + w, y1 = p.y + h }
end

local markDirtySettings
local flushDirtyConfigNow
local getSettings
local wmHandlerInstalled = false
local specArrowPrev = {}

local WM = {
    KEYDOWN = 0x0100,
    KEYUP = 0x0101,
    SYSKEYDOWN = 0x0104,
    SYSKEYUP = 0x0105,
}

-- Активен ли режим spectate (SAMP flag).
local function specIsSpectating()
    return specPlayerActive()
end

-- Публичный API модуля.
function M.isSpectating()
    return specPlayerActive()
end

-- Сборка deps для sp_ui (session, menu, ans).
local function buildSpUiDeps(deps)
    return {
        sampev = deps and deps.sampev,
        trim = trim,
        stripTags = stripTags,
        readInputBuf = deps and deps.readInputBuf,
        utf8ToCp1251 = deps and deps.utf8ToCp1251,
        sendChat = sendChat,
        sendMenuOutbound = sendMenuOutbound,
        imgui = deps and deps.imgui,
        uiText = uiText,
        getSettings = getSettings,
        getTargetId = function() return M.getTargetId() end,
        getLocalTargetId = function() return state.targetId end,
        getTargetNick = function()
            local nk = specSession.getTargetNick and specSession.getTargetNick()
            if nk and nk ~= '' then return nk end
            return state.targetNick
        end,
        getPlayerSpectating = deps and deps.getPlayerSpectating,
        isGameTextInputActive = M.isGameTextInputActive,
        isDeskTypingActive = deps and deps.isDeskTypingActive,
        getShowWindow = deps and deps.getShowWindow,
        vkeys = deps and deps.vkeys,
        isVkDown = deps and deps.isVkDown,
        col_accent = col_accent,
        col_accent_dim = col_accent_dim,
        col_label = col_label,
        col_muted2 = col_muted2,
        markDirtySettings = markDirtySettings,
        flushDirtyConfigNow = flushDirtyConfigNow,
        playFrontEndSound = function(id)
            if playSoundFrontEnd then pcall(playSoundFrontEnd, tonumber(id) or 0) end
        end,
        requestStats = function(id, opts) M.requestStats(id, opts or { force = true }) end,
        markPendingSt = function(id) M.markPendingSt(id) end,
        sendTrPlayer = deps and deps.sendTrPlayer,
        sendSlapPlayer = deps and deps.sendSlapPlayer,
        isStatsPending = function()
            local pid = state.pendingStId
            return pid and (os.clock() - (state.pendingStAt or 0)) < PENDING_ST_SEC
        end,
        setPlayerSpectating = deps and deps.setPlayerSpectating,
        sampIsPlayerConnected = sampIsPlayerConnected,
        sampGetPlayerNickname = sampGetPlayerNickname,
        onSpLocalExit = function()
            expectSpectateOff = true
            M.clearSpectateTarget(true)
            M.onSpCommandOff()
        end,
        onSessionBegin = function(id, nick, meta)
            meta = meta or {}
            local syncOpts = {}
            local src = meta.source
            if spRefresh.shouldSkipAutoSt and spRefresh.shouldSkipAutoSt(id) then
                syncOpts.skipAutoSt = true
            elseif src == 'sp_line' or src == 'spectate_player' then
                syncOpts.forceAutoSt = true
                if src == 'spectate_player' then
                    if lastSpecStepAt and (os.clock() - lastSpecStepAt) < SPEC_STEP_AUTO_ST_DELAY
                            and M.hasStats(id) then
                        syncOpts.skipAutoSt = true
                    end
                end
            end
            M.syncFromSession(id, nick, getSettings and getSettings(), syncOpts)
        end,
        onSessionEnd = function()
            local sid = specSession.getTargetId and specSession.getTargetId() or -1
            if sid >= 0 then return end
            M.clearSpectateTarget(false)
        end,
        onSpectatingOn = deps and deps.onSpectatingOn,
        onSpectatingOff = deps and deps.onSpectatingOff,
        setPendingTarget = function(id, nick)
            M.markPendingSpCommand(id, nick)
        end,
        captureActive = specCaptureActive,
        consumeMenuShieldKey = M.consumeSpectateMenuKey,
        isMenuShieldActive = specMenuShieldActive,
        transmitAns = function(id, body)
            id = tonumber(id)
            body = trim and trim(body) or body
            if not id or body == '' then return end
            if transmitAnsWire then
                pcall(transmitAnsWire, id, body, {})
            elseif sendChat then
                pcall(sendChat, string.format('ans %d %s', id, body))
            end
        end,
        enableSpectateCursor = deps and deps.enableSpectateCursor,
        rememberSpectateCursor = deps and deps.rememberSpectateCursor,
        setSpectateUiMode = deps and deps.setSpectateUiMode,
        updateInputPassthrough = deps and deps.updateInputPassthrough,
        onAnsBarClosed = deps and deps.onAnsBarClosed,
        markTypingActive = function()
            if deps and deps.markAnsTypingActive then
                pcall(deps.markAnsTypingActive)
            end
        end,
    }
end

-- Блокировка клавиш меню (чат/окно desk).
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

-- Захват ввода spectate (ans/menu).
local function specCaptureActive()
    if not inputDeps then return false end
    if inputDeps.hotkeyCapture and inputDeps.hotkeyCapture() then return true end
    if inputDeps.cheatKeyCapture and inputDeps.cheatKeyCapture() then return true end
    return false
end

local specWheelIoCacheAt = 0
local specWheelIoCapture = false

local function specDeskCapturesMouse()
    if not inputDeps or not inputDeps.getShowWindow or not inputDeps.getShowWindow() then
        return false
    end
    local now = os.clock()
    if now - specWheelIoCacheAt < 0.05 then
        return specWheelIoCapture
    end
    specWheelIoCacheAt = now
    specWheelIoCapture = false
    local imguiMod = inputDeps.imgui
    if imguiMod and imguiMod.GetIO then
        local okIo, io = pcall(imguiMod.GetIO)
        if okIo and io and io.WantCaptureMouse then
            specWheelIoCapture = true
        end
    end
    return specWheelIoCapture
end

local function specWheelBlocked()
    if not specIsSpectating() then return true end
    if specCaptureActive() then return true end
    if inputDeps and inputDeps.sampIsChatInputActive and inputDeps.sampIsChatInputActive() then
        return true
    end
    if inputDeps and inputDeps.sampIsDialogActive and inputDeps.sampIsDialogActive() then
        return true
    end
    if type(_G.cheatState) == 'table' and _G.cheatState.marker and _G.cheatState.marker.active then
        return true
    end
    if type(_G.deskSpectateCameraBlocked) == 'function' and _G.deskSpectateCameraBlocked() then
        return true
    end
    if M.isHudDragActive and M.isHudDragActive() then return true end
    if specDeskCapturesMouse() then return true end
    if spUi.isAnsBarOpen and spUi.isAnsBarOpen() then return true end
    return false
end

local function specUiBlocksCameraMaintain()
    if not specIsSpectating() then return true end
    if specDeskCapturesMouse() then return true end
    if spUi.isAnsBarOpen and spUi.isAnsBarOpen() then return true end
    return false
end

local function specCameraDeps(sampevOverride)
    return {
        sampev = sampevOverride or (inputDeps and inputDeps.sampev),
        getSettings = getSettings,
        isSpectating = specIsSpectating,
        isWheelBlocked = specWheelBlocked,
        isUiBlockingCamera = specUiBlocksCameraMaintain,
    }
end

-- Spec Arrow Hit
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

-- Spec Step By Arrow
local function specStepByArrow(delta)
    if not specIsSpectating() or specMenuShieldActive() or specCaptureActive() then return false end
    return M.stepSpectate(delta)
end

-- Публичный API модуля.
function M.handleSpectateWindowMessage(msg, wparam)
    if specCaptureActive() then return false end
    if specCamera.handleWindowMessage(msg, wparam) then return true end
    if msg ~= WM.KEYDOWN and msg ~= WM.SYSKEYDOWN then return false end
    if not specIsSpectating() or specCaptureActive() then return false end
    -- Чат и серверный диалог — стрелки для игры, не для /sp и не для spectate step.
    if M.isGameTextInputActive() then return false end
    if specMenuShieldActive() then return false end
    local vkeysMod = inputDeps and inputDeps.vkeys
    local vkL = (vkeysMod and vkeysMod.VK_LEFT) or 0x25
    local vkR = (vkeysMod and vkeysMod.VK_RIGHT) or 0x27
    if wparam ~= vkL and wparam ~= vkR then return false end
    return specStepByArrow(wparam == vkR and 1 or -1)
end

function M.maintainCamera()
    pcall(specCamera.maintain)
end

-- Публичный API модуля.
function M.consumeSpectateMenuKey(msg, wparam)
    if spUi.isAnsBarOpen and spUi.isAnsBarOpen() then return false end
    if not specMenuShieldActive() then return false end
    if msg ~= WM.KEYDOWN and msg ~= WM.SYSKEYDOWN and msg ~= WM.KEYUP and msg ~= WM.SYSKEYUP then
        return false
    end
    local vkeysMod = inputDeps and inputDeps.vkeys
    if not vkeysMod then return false end
    if wparam == vkeysMod.VK_MENU or wparam == vkeysMod.VK_CONTROL then
        return true
    end
    if wparam == vkeysMod.VK_SPACE or wparam == vkeysMod.VK_TAB then return true end
    return false
end


-- Публичный API модуля.
function M.shouldBlockSpectateOff()
    if state.pendingSpId then return true end
    if expectSpectateOff then return false end
    if specSession.isActive and specSession.isActive() then return true end
    local outboundAt = tonumber(state.lastSpOutboundAt) or 0
    if outboundAt > 0 and (os.clock() - outboundAt) < (PENDING_SP_SEC + 2.0) then
        return true
    end
    return false
end

local function reassertSpectateInputState()
    if inputDeps.setPlayerSpectating then
        pcall(inputDeps.setPlayerSpectating, true)
    end
    pcall(specSession.setSpectating, true)
    if inputDeps.updateInputPassthrough then
        pcall(inputDeps.updateInputPassthrough)
    end
end

function M.onTogglePlayerSpectating(toggle)
    if not inputDeps then return end
    if toggle then
        pcall(specCamera.onSpectateStart)
        spUi.onToggleSpectating(true)
        return
    end
    if M.shouldBlockSpectateOff() then
        reassertSpectateInputState()
        return
    end
    expectSpectateOff = false
    if specPlayerActive() then return end
    pcall(specCamera.onSpectateEnd)
    spUi.onToggleSpectating(false)
end

-- Публичный API модуля.
function M.onSpCommandOff()
    expectSpectateOff = true
    M.snapshotPersistHud()
    spUi.onSpCommandOff()
end

local spOverlayFrame = nil

-- Подписка OnFrame overlay spectate HUD.
local function ensureSpSpectateFrame()
    if spOverlayFrame and spOverlayFrame.Unsubscribe then
        pcall(function() spOverlayFrame:Unsubscribe() end)
        spOverlayFrame = nil
    end
    rawset(_G, '__desk_spSpectateFrame', nil)
    local cache = rawget(_G, 'deskCache')
    if type(cache) == 'table' and cache.spSpectateFrame and cache.spSpectateFrame.Unsubscribe then
        pcall(function() cache.spSpectateFrame:Unsubscribe() end)
        cache.spSpectateFrame = nil
    end
end

-- Публичный API модуля.
function M.uninstallSpSpectateOverlayFrame()
    if spOverlayFrame and spOverlayFrame.Unsubscribe then
        pcall(function() spOverlayFrame:Unsubscribe() end)
    end
    spOverlayFrame = nil
    local cache = rawget(_G, 'deskCache')
    if type(cache) == 'table' and cache.spSpectateFrame and cache.spSpectateFrame.Unsubscribe then
        pcall(function() cache.spSpectateFrame:Unsubscribe() end)
        cache.spSpectateFrame = nil
    end
    local prev = rawget(_G, '__desk_spSpectateFrame')
    if prev and prev.Unsubscribe then
        pcall(function() prev:Unsubscribe() end)
    end
    rawset(_G, '__desk_spSpectateFrame', nil)
end

-- Публичный API модуля.

local function configureSpRefresh()
    spRefresh.configure({
        getTargetId = function() return M.getTargetId() end,
        getSettings = getSettings,
        isSpectating = specPlayerActive,
        sessionActive = function() return specSession.isActive() end,
        hasPendingSp = M.hasPendingSp,
        sendMenuOutbound = sendMenuOutbound,
        sendChat = sendChat,
        getTargetPed = function()
            local id = M.getTargetId()
            if id < 0 or not sampGetCharHandleBySampPlayerId then return nil end
            local ok, ped = sampGetCharHandleBySampPlayerId(id)
            if ok and ped and doesCharExist and doesCharExist(ped) then return ped end
            return nil
        end,
        getLocalInterior = function()
            if PLAYER_PED and getCharInterior then
                local ok, v = pcall(getCharInterior, PLAYER_PED)
                if ok and v ~= nil then return tonumber(v) or 0 end
            end
            return 0
        end,
    })
end

function M.installInputHooks(deps)
    inputDeps = deps
    flushDirtyConfigNow = deps.flushDirtyConfigNow or flushDirtyConfigNow
    local uiDeps = buildSpUiDeps(deps)
    spUi.install(uiDeps)
    spUi.installInputHooks(uiDeps)
    configureSpRefresh()
    ensureSpSpectateFrame()
    specCamera.install(specCameraDeps(deps.sampev))
    pcall(keysHud.installSampev, deps.sampev)
    if wmHandlerInstalled then
        return
    end
    wmHandlerInstalled = true

    addEventHandler('onWindowMessage', function(msg, wparam, lparam)
        if msg == WM_ACTIVATEAPP then
            gameAppActive = (tonumber(wparam) or 0) ~= 0
            if gameAppActive then
                targetOfflineSinceAt = nil
            end
            return
        end
        if specCaptureActive() then return end
        if M.handleSpectateWindowMessage(msg, wparam) then
            consumeWindowMessage(true, true, true)
        end
    end, true)
end

-- Публичный API модуля.
function M.ensureInputHooks()
    if not inputDeps or not inputDeps.sampev then return end
    spUi.ensureInputHooks()
end

-- Публичный API модуля.
function M.drawSpMenu(settings)
    if M.getTargetId() < 0 then return end
    local specActive = specPlayerActive()
    if not specActive and specSession.isActive then
        specActive = specSession.isActive()
    end
    if not specActive then return end
    settings = settings or (getSettings and getSettings())
    local ok, err = pcall(specMenuMod.drawMenu, settings, true)
    if not ok then
        print('[Report Desk] sp menu: ' .. tostring(err))
    end
end

-- Публичный API модуля.
function M.drawSpAns(settings)
    if spUi.drawAnsBar then
        pcall(spUi.drawAnsBar, settings or (getSettings and getSettings()))
    end
end

-- Публичный API модуля.
function M.drawVehicleHud(settings)
    settings = settings or (getSettings and getSettings())
    pcall(vehicleHud.draw, settings)
end

-- Публичный API модуля.
function M.shouldShowVehicleHud(settings)
    return vehicleHud.shouldShow(settings or (getSettings and getSettings()))
end

-- Публичный API модуля.
function M.drawKeysHud(settings)
    settings = settings or (getSettings and getSettings())
    pcall(keysHud.draw, settings)
end

-- Публичный API модуля.
function M.shouldShowKeysHud(settings)
    return keysHud.shouldShow(settings or (getSettings and getSettings()))
end

-- Публичный API модуля.
function M.wantsKeysHudInput()
    return keysHud.wantsInput and keysHud.wantsInput() or false
end

-- Публичный API модуля.
-- Публичный API модуля.
function M.wantsSpMenuInput()
    return specMenuMod.wantsInput and specMenuMod.wantsInput() or false
end
function M.wantsVehicleHudInput()
    return vehicleHud.wantsInput and vehicleHud.wantsInput() or false
end

-- Публичный API модуля.
function M.isAnsLayoutSwitch()
    return spUi.isAnsLayoutSwitch and spUi.isAnsLayoutSwitch() or false
end

-- Публичный API модуля.
function M.isAnsBarOpen()
    return spUi.isAnsBarOpen and spUi.isAnsBarOpen() or false
end

-- Публичный API модуля.
function M.wantsAnsInput()
    return spUi.wantsAnsInput and spUi.wantsAnsInput() or false
end

-- Публичный API модуля.
function M.notifyTargetQuit(playerId)
    playerId = tonumber(playerId)
    if not playerId or M.getTargetId() ~= playerId then return end
    M.forceExitSpectate({ reason = 'quit', sendServer = true })
end

-- Публичный API модуля.
function M.uninstallSpectatePlayerHook()
    spUi.uninstallSampevHooks()
end

-- Публичный API модуля.
function M.ensureSpectatePlayerHook()
    spUi.ensureInputHooks()
end

-- Публичный API модуля.
function M.hasOutboundPending()
    if spUi.hasOutboundPending then
        return spUi.hasOutboundPending()
    end
    return false
end

-- Публичный API модуля.
function M.flushOutbound()
    spUi.flushOutbound()
end

-- Публичный API модуля.
function M.configure(deps)
    trim = deps.trim
    stripTags = deps.stripTags
    sendChat = deps.sendChat
    sendMenuOutbound = deps.sendMenuOutbound or deps.sendChat
    uiText = deps.uiText
    toU32 = deps.toU32
    col_accent = deps.col_accent
    col_accent_dim = deps.col_accent_dim
    col_muted = deps.col_muted
    col_muted2 = deps.col_muted2
    col_label = deps.col_label
    col_warn = deps.col_warn
    if toU32 and spTheme.setColorConverter then
        pcall(spTheme.setColorConverter, toU32)
    end
    sampIsPlayerConnected = deps.sampIsPlayerConnected
    sampGetPlayerNickname = deps.sampGetPlayerNickname
    sampGetPlayerColor = deps.sampGetPlayerColor
    sampGetPlayerPing = deps.sampGetPlayerPing
    sampGetPlayerScore = deps.sampGetPlayerScore
    markDirtySettings = deps.markDirtySettings
    getSettings = deps.getSettings
end

-- Публичный API модуля.
function M.install(deps)
    M.configure(deps)
    configureSpRefresh()
    markDirtySettings = deps.markDirtySettings
    flushDirtyConfigNow = deps.flushDirtyConfigNow
    vehicleHud.configure({
        uiText = uiText,
        toU32 = toU32,
        col_accent = col_accent,
        col_accent_dim = col_accent_dim,
        col_muted = col_muted,
        col_muted2 = col_muted2,
        col_warn = col_warn,
        col_label = col_label,
        markDirtySettings = markDirtySettings,
        flushDirtyConfigNow = flushDirtyConfigNow,
        getSettings = getSettings,
        getSpectateTargetId = function() return M.getTargetId() end,
        inputDeps = deps,
    })
    keysHud.configure({
        uiText = uiText,
        toU32 = toU32,
        col_accent = col_accent,
        col_accent_dim = col_accent_dim,
        col_muted = col_muted,
        col_muted2 = col_muted2,
        markDirtySettings = markDirtySettings,
        flushDirtyConfigNow = flushDirtyConfigNow,
        getSettings = getSettings,
        getSpectateTargetId = function() return M.getTargetId() end,
        isSpectating = function()
            if inputDeps and inputDeps.getPlayerSpectating then
                return inputDeps.getPlayerSpectating() == true
            end
            return specSession.isSpectatingMode()
        end,
    })
end


function M.onSpRefreshEnterVehicle(playerId, vehicleId)
    spRefresh.onTargetEnterVehicle(playerId, vehicleId)
end

function M.onSpRefreshExitVehicle(playerId, vehicleId)
    spRefresh.onTargetExitVehicle(playerId, vehicleId)
end

function M.onSpRefreshSetInterior(interior)
    spRefresh.onLocalSetInterior(interior)
end

function M.onSpRefreshVehicleSync(playerId)
    spRefresh.onTargetVehicleSync(playerId)
end

function M.onSpRefreshPassengerSync(playerId)
    spRefresh.onTargetPassengerSync(playerId)
end

function M.onSpRefreshPlayerSync(playerId, data)
    spRefresh.onTargetPlayerSync(playerId)
end

function M.onSpRefreshSpectatePlayer(playerId)
    spRefresh.onServerSpectatePlayer(playerId)
end

function M.onSpRefreshSpectateVehicle(vehicleId)
    spRefresh.onServerSpectateVehicle(vehicleId)
    if inputDeps and inputDeps.rememberSpectateCursor then
        pcall(inputDeps.rememberSpectateCursor)
    end
end

function M.onSpRefreshStreamIn(playerId)
    spRefresh.onTargetStreamIn(playerId)
end

return M
