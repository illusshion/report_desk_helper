--[[ Модуль: кастомный спидометр из server TextDraw (/sp и свой транспорт). ]]
local M = {}

local imgui = require 'mimgui'
local spTheme = require 'report_desk_sp_theme'

local VEHICLE_HUD_X_MIN_DEFAULT = 400   -- зона server TD спидометра, px (640x448)
local VEHICLE_HUD_X_MAX_DEFAULT = 480
local VEHICLE_HUD_Y_MIN_DEFAULT = 385   -- нижняя полоса HUD
local STALE_SEC = 6.0
local PANEL_BASE = 260          -- спидометр: правый нижний угол
local HUD_MARGIN = 10
local HEALTH_MAX = 1000
local FUEL_MAX = 150
local SPEED_MAX = 160             -- как CEF ProgressBar
local ANIM_METRIC = 0.38
local SPEED_VIS_TAU = 0.11
local PI = math.pi
local ARC_START = PI * 0.75     -- 135° — нижний край дуги (CEF rotate=135)
local ARC_SPAN = PI * 1.5       -- 270° видимой дуги (CEF cut=90)

local INDICATOR_ORDER = { 'E', 'S', 'M', 'L', 'B' }
local INDICATOR_HINT = {
    E = '\xE4\xE2\xE8\xE3',
    S = '\xF1\xE8\xE3\xED',
    M = 'M',
    L = '\xF1\xE2\xE5\xF2',
    B = '\xF0\xE5\xEC',
}

local DRIVE_MODES = {
    sport = true, eco = true, normal = true, comfort = true, city = true,
    ['\xF1\xEF\xEE\xF0\xF2'] = true,
}

local DOOR_WORDS = {
    open = true, opened = true, closed = true, close = true, lock = true, locked = true,
    ['\xEE\xF2\xEA\xF0'] = true,
    ['\xE7\xE0\xEA\xF0'] = true,
    ['\xE7\xE0\xEC\xEE\xEA'] = true,
}

local hud = {
    speed = nil,
    fuel = nil,
    health = nil,
    door = nil,
    driveMode = nil,
    indicators = {},
    inVehicle = false,
    lastAt = 0,
    active = false,
}

local tdMeta = {}
local posSlots = {}
local tdRolePin = {}

local uiText, toU32, col_accent, col_accent_dim, col_muted, col_muted2, col_warn, col_label
local markDirtySettings, flushDirtyConfigNow, getSettingsFn, getSpectateTargetId
local inputDeps

local drag = { active = false, startX = 0, startY = 0, offX = 0, offY = 0 }
local hovered = false
local hudRect = nil
local anim = { speedVis = 0, fuelPct = 0, hpPct = 0 }

local touchActive

-- Normalize Plain
local function normalizePlain(text)
    text = tostring(text or '')
    text = text:gsub('{[0-9A-Fa-f]+}', '')
    text = text:gsub('~[^~]*~', '')
    return text:lower():gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
end

local CANVAS_W = 640
local CANVAS_H = 448

-- Normalize Td Coord
local function normalizeTdCoord(v, axis)
    v = tonumber(v)
    if not v then return nil end
    if v > 0 and v <= 1.0 then
        if axis == 'x' then return v * CANVAS_W end
        if axis == 'y' then return v * CANVAS_H end
    end
    return v
end

-- Td Pos X
local function tdPosX(data)
    if not data or not data.position then return nil end
    return normalizeTdCoord(data.position.x or data.position[1], 'x')
end

-- Td Pos Y
local function tdPosY(data)
    if not data or not data.position then return nil end
    return normalizeTdCoord(data.position.y or data.position[2], 'y')
end

-- Role From Hud Position — фиксированные слоты ADV спидометра (640x448).
local function roleFromHudPosition(x, y)
    x = normalizeTdCoord(x, 'x')
    y = normalizeTdCoord(y, 'y')
    if not x or not y then return nil end
    local settings = getSettingsFn and getSettingsFn() or nil
    local xMin = tonumber(settings and settings.spectate_vehicle_td_x_min) or VEHICLE_HUD_X_MIN_DEFAULT
    local xMax = tonumber(settings and settings.spectate_vehicle_td_x_max) or VEHICLE_HUD_X_MAX_DEFAULT
    local yMin = vehicleHudYMin()
    if x < (xMin - 24) or x > (xMax + 40) or y < (yMin - 16) then return nil end
    local rowSplit = yMin + 14
    local col
    if x <= xMin + 28 then col = 1
    elseif x <= xMin + 54 then col = 2
    else col = 3 end
    if y < rowSplit then
        if col == 1 then return 'speed' end
        if col == 2 then return 'fuel' end
        return 'health'
    end
    if col == 1 then return 'door' end
    if col == 2 then return 'mode' end
    return 'indicators'
end

-- Parse Door Plain
local function parseDoorPlain(plain)
    if plain:find('open', 1, true) or plain:find('\xEE\xF2\xEA\xF0', 1, true) then
        return 'Open'
    end
    if plain:find('clos', 1, true) or plain:find('lock', 1, true)
            or plain:find('\xE7\xE0\xEA\xF0', 1, true) or plain:find('\xE7\xE0\xEC\xEE\xEA', 1, true) then
        return 'Closed'
    end
    return nil
end

-- Parse Mode Plain — только слово режима, не вся combined-строка TD.
local function parseModePlain(plain)
    plain = tostring(plain or '')
    if plain == '' then return nil end
    local bestWord, bestLen = nil, 0
    for word, _ in pairs(DRIVE_MODES) do
        local wlen = #word
        if wlen >= bestLen and (plain == word or plain:find(word, 1, true)) then
            bestWord = word
            bestLen = wlen
        end
    end
    if not bestWord then return nil end
    return bestWord:sub(1, 1):upper() .. bestWord:sub(2)
end

local function vehicleHudYMin()
    local settings = getSettingsFn and getSettingsFn() or nil
    return tonumber(settings and settings.spectate_vehicle_td_y_min) or VEHICLE_HUD_Y_MIN_DEFAULT
end

-- Строгая зона ingest: колонка server TD спидометра (не вся нижняя полоса экрана).
local function isStrictVehicleHudArea(x, y)
    x = normalizeTdCoord(x, 'x')
    y = normalizeTdCoord(y, 'y')
    if not y then return false end
    local settings = getSettingsFn and getSettingsFn() or nil
    local xMin = tonumber(settings and settings.spectate_vehicle_td_x_min) or VEHICLE_HUD_X_MIN_DEFAULT
    local xMax = tonumber(settings and settings.spectate_vehicle_td_x_max) or VEHICLE_HUD_X_MAX_DEFAULT
    local yMin = vehicleHudYMin()
    if y < (yMin - 16) then return false end
    if x and x >= xMin and x <= xMax then return true end
    if x and x > 0 and x <= 1.0 and x >= 0.62 and x <= 0.75 then return true end
    if x and y and x >= 300 and x <= (xMax + 40) and y >= yMin then return true end
    return false
end

-- Публичный API модуля.
function M.isVehicleHudArea(x, y)
    x = normalizeTdCoord(x, 'x')
    y = normalizeTdCoord(y, 'y')
    local settings = getSettingsFn and getSettingsFn() or nil
    local xMin = tonumber(settings and settings.spectate_vehicle_td_x_min) or VEHICLE_HUD_X_MIN_DEFAULT
    local xMax = tonumber(settings and settings.spectate_vehicle_td_x_max) or VEHICLE_HUD_X_MAX_DEFAULT
    local yMin = vehicleHudYMin()
    if isStrictVehicleHudArea(x, y) then return true end
    -- Широкая зона только для скрытия server TD, не для ingest чисел.
    if y and y >= (yMin - 24) then
        if not x or x <= 560 then return true end
    end
    return false
end

-- Is Vehicle Hud Area
local function isVehicleHudArea(x, y)
    return M.isVehicleHudArea(x, y)
end

-- Парсинг данных с сервера/чата.
local function parseSpeedPlain(plain)
    plain = tostring(plain or '')
    local n = plain:match('(%d+)%s*km/h')
    if not n then n = plain:match('(%d+)%s*km') end
    if not n then n = plain:match('(%d+)%s*км/ч') end
    if not n then n = plain:match('(%d+)%s*км') end
    return tonumber(n)
end

-- Extract Speed Value — число часто только в ~tag~ (plain после strip теряет его).
local function extractSpeedValue(raw, plain)
    raw = tostring(raw or '')
    plain = plain or normalizePlain(raw)
    plain = plain:gsub('_', ' ')
    local n = parseSpeedPlain(plain)
    if n then return n end
    for tag, num in raw:gmatch('~([a-z])~(%d+)') do
        if tag == 'g' or tag == 'w' or tag == 'y' or tag == 'b' or tag == 's' then
            n = tonumber(num)
            if n then return n end
        end
    end
    if raw:find('km', 1, true) or raw:find('\xEA\xEC', 1, true) then
        for num in raw:gmatch('(%d+)') do
            n = tonumber(num)
            if n and n <= 350 then return n end
        end
    end
    n = tonumber(plain:match('^(%d+)$'))
    if n and n <= 350 then return n end
    return nil
end

-- Looks Like Speed Text
local function looksLikeSpeedText(raw, plain)
    raw = tostring(raw or '')
    plain = tostring(plain or '')
    if parseSpeedPlain(plain) then return true end
    if raw:find('km/h', 1, true) or raw:find('km h', 1, true) then return true end
    if raw:find('\xEA\xEC/\xF7', 1, true) or raw:find('\xEA\xEC', 1, true) then return true end
    if raw:match('~[gwybs]~%d+') then return true end
    return false
end

-- Парсинг данных с сервера/чата.
local function parseFuelPlain(plain)
    local n = plain:match('fuel%s*(%d+)')
    if not n then n = plain:match('(%d+)%s*l') end
    if not n then n = plain:match('(%d+)%s*л') end
    return tonumber(n)
end

-- Indicator Tag Active
local function indicatorTagActive(tag)
    tag = tostring(tag or ''):lower()
    if tag == '' then return true end
    if tag == 'c' or tag == 'h' or tag == 'r' or tag == 'l' then return false end
    return true
end

-- Парсинг данных с сервера/чата.
local function parseIndicatorLetter(raw, letter)
    letter = tostring(letter or ''):lower()
    if letter == '' then return nil end
    local tag = raw:match('~([a-z])~' .. letter)
    if tag then return indicatorTagActive(tag) end
    tag = raw:match('~([a-z])~' .. letter:upper())
    if tag then return indicatorTagActive(tag) end
    return true
end

-- Store Indicators
local function storeIndicators(raw, plain)
    plain = plain:gsub('%s+', '')
    if plain == '' then return false end
    if #plain == 1 and plain:match('^[esmlb]$') then
        local key = plain:upper()
        hud.indicators[key] = parseIndicatorLetter(raw, key) and true or false
        touchActive()
        return true, 'ind_' .. key
    end
    if not plain:match('^[esmlb]+$') then return false end
    for i = 1, #plain do
        local ch = plain:sub(i, i):upper()
        if INDICATOR_HINT[ch] then
            hud.indicators[ch] = parseIndicatorLetter(raw, ch) and true or false
        end
    end
    touchActive()
    return true, 'indicators'
end

-- Публичный API модуля.
function M.matchesServerHudText(text)
    text = tostring(text or '')
    if text == '' then return false end
    local plain = normalizePlain(text)
    plain = plain:gsub('_', ' ')
    if plain:find('km/h', 1, true) or plain:find('km h', 1, true) then return true end
    if plain:find('\xea\xec/\xf7', 1, true) or plain:find('\xea\xec', 1, true) then return true end
    if plain:find('fuel', 1, true) or plain:find('\xf2\xee\xef\xeb', 1, true) then return true end
    if parseSpeedPlain(plain) then return true end
    if parseFuelPlain(plain) then return true end
    for word, _ in pairs(DOOR_WORDS) do
        if plain:find(word, 1, true) then return true end
    end
    for word, _ in pairs(DRIVE_MODES) do
        if plain == word then return true end
    end
    if plain:match('^[esmlb ]+$') then return true end
    if plain:match('^(%d+)$') then
        local n = tonumber(plain:match('^(%d+)$'))
        -- Только HP-диапазон; голые 0–350 (ping, fps) не считаем спидометром.
        if n and n >= 100 and n <= HEALTH_MAX then return true end
    end
    if text:match('~[a-z]~%d') and not text:find('__', 1, true) then return true end
    return false
end

-- Is Vehicle Hud Label
local function isVehicleHudLabel(text)
    return M.matchesServerHudText(text)
end

-- Is Likely Gauge Text
local function isLikelyGaugeText(text)
    return M.matchesServerHudText(text)
end

-- Extract Tagged Numbers
local function extractTaggedNumbers(text)
    local out = {}
    for tag, num in tostring(text or ''):gmatch('~([a-z])~(%d+)') do
        out[#out + 1] = { tag = tag, value = tonumber(num) }
    end
    return out
end

-- Classify Numeric
local function classifyNumeric(text, y, pinnedRole)
    local plain = normalizePlain(text)
    local speed = parseSpeedPlain(plain)
    if not speed then speed = extractSpeedValue(text, plain) end
    if speed then return 'speed', speed end
    local fuel = parseFuelPlain(plain)
    if fuel then return 'fuel', fuel end

    local tagged = extractTaggedNumbers(text)
    if pinnedRole then
        for _, item in ipairs(tagged) do
            if item.value then return pinnedRole, item.value end
        end
        local n = tonumber(plain:match('^(%d+)$'))
        if n then return pinnedRole, n end
    end

    if #tagged == 0 then
        local n = tonumber(plain:match('^(%d+)$'))
        if not n then return nil, nil end
        if pinnedRole == 'health' or (n >= 250 and n <= HEALTH_MAX) then return 'health', n end
        if pinnedRole == 'fuel' or (n <= 100 and y and y >= vehicleHudYMin()) then return 'fuel', n end
        if n <= 350 then return 'speed', n end
        if n <= HEALTH_MAX then return 'health', n end
        return nil, nil
    end

    for _, item in ipairs(tagged) do
        local tag, n = item.tag, item.value
        if n then
            if tag == 'g' or tag == 'w' or tag == 'y' or tag == 'b' or tag == 's' then return 'speed', n end
            if tag == 'c' or tag == 'p' or tag == 'u' then
                if n >= 250 and n <= HEALTH_MAX then return 'health', n end
                return 'fuel', n
            end
            if tag == 'm' or tag == 'h' then return 'health', n end
        end
    end

    local first = tagged[1]
    if first and first.value then
        if first.value >= 250 and first.value <= HEALTH_MAX then return 'health', first.value end
        if first.value <= 100 and y and y >= vehicleHudYMin() then return 'fuel', first.value end
        return 'speed', first.value
    end
    return nil, nil
end

-- Classify Role
local function classifyRole(text, data, pinnedRole)
    local raw = tostring(text or '')
    local plain = normalizePlain(text)
    plain = plain:gsub('_', ' ')

    local speed = parseSpeedPlain(plain)
    if not speed then speed = extractSpeedValue(raw, plain) end
    if speed then return 'speed', speed end
    local fuel = parseFuelPlain(plain)
    if fuel then return 'fuel', fuel end

    if plain:find('km/h', 1, true) or plain:find('km h', 1, true)
            or plain:find('\xea\xec/\xf7', 1, true) or looksLikeSpeedText(raw, plain) then
        local n = extractSpeedValue(raw, plain)
        if n then return 'speed', n end
        return 'speed_unit', nil
    end
    if plain:find('fuel', 1, true) then return 'fuel_label', nil end

    local doorText = parseDoorPlain(plain)
    if doorText then return 'door', doorText end
    local modeText = parseModePlain(plain)
    if modeText then return 'mode', modeText end

    local indPlain = plain:gsub('%s+', '')
    local indOk, indRole = storeIndicators(raw, indPlain)
    if indOk then return indRole or 'indicators', nil end

    local y = tdPosY(data)
    local role, value = classifyNumeric(text, y, pinnedRole)
    if role then return role, value end
    if plain:match('^[%d_%.]+$') or plain == '' then return 'decor', nil end
    return 'decor', nil
end

touchActive = function()
    hud.lastAt = os.clock()
    hud.active = true
    hud.inVehicle = true
end

-- Локальный ped в транспорте (только свой игрок; для /sp — server TD).
function M.isLocalInVehicle()
    if not PLAYER_PED or type(doesCharExist) ~= 'function' or type(isCharInAnyCar) ~= 'function' then
        return false
    end
    if not doesCharExist(PLAYER_PED) then return false end
    return isCharInAnyCar(PLAYER_PED) == true
end

-- Store Field
local function storeField(role, value, textValue)
    if role == 'speed' and value ~= nil then
        hud.speed = math.max(0, math.min(999, math.floor(value + 0.5)))
        touchActive()
    elseif role == 'fuel' and value ~= nil then
        hud.fuel = math.max(0, math.floor(value + 0.5))
        touchActive()
    elseif role == 'health' and value ~= nil then
        hud.health = math.max(0, math.min(HEALTH_MAX, math.floor(value + 0.5)))
        touchActive()
    elseif role == 'door' and textValue and textValue ~= '' then
        local doorText = parseDoorPlain(normalizePlain(textValue))
        if not doorText and #normalizePlain(textValue) <= 14 then
            doorText = tostring(textValue)
        end
        if doorText then
            hud.door = tostring(doorText)
            touchActive()
        end
    elseif role == 'mode' and textValue and textValue ~= '' then
        local modeText = parseModePlain(normalizePlain(textValue))
        if modeText then
            hud.driveMode = modeText
            touchActive()
        end
    elseif role == 'speed_unit' or role == 'fuel_label' then
        touchActive()
    elseif role and role:match('^ind_') then
        touchActive()
    elseif role == 'indicators' then
        touchActive()
    end
end

-- Публичный API модуля.
function M.isEnabled(settings)
    settings = settings or (getSettingsFn and getSettingsFn())
    if not settings then return true end
    return settings.spectate_vehicle_hud ~= false
end

-- Публичный API модуля.
function M.isEnabledForSpectate(settings)
    settings = settings or (getSettingsFn and getSettingsFn())
    if not M.isEnabled(settings) then return false end
    return not settings or settings.spectate_sp_ui ~= false
end

-- Без side-effect reset (для baseline auto /sp).
function M.peekActive()
    if not hud.active or not hud.inVehicle then return false end
    if (os.clock() - (hud.lastAt or 0)) > STALE_SEC then return false end
    if hud.speed ~= nil or hud.fuel ~= nil or hud.health ~= nil then return true end
    if hud.door or hud.driveMode then return true end
    for _, key in ipairs(INDICATOR_ORDER) do
        if hud.indicators[key] ~= nil then return true end
    end
    return false
end

-- Публичный API модуля.
function M.isActive()
    if not hud.active or not hud.inVehicle then return false end
    if (os.clock() - (hud.lastAt or 0)) > STALE_SEC then
        M.reset()
        return false
    end
    if hud.speed ~= nil or hud.fuel ~= nil or hud.health ~= nil then return true end
    if hud.door or hud.driveMode then return true end
    for _, key in ipairs(INDICATOR_ORDER) do
        if hud.indicators[key] ~= nil then return true end
    end
    return false
end

-- Публичный API модуля.
function M.isDragActive()
    return drag.active == true
end

-- Публичный API модуля.
function M.clearPointerHover()
    hovered = false
end

-- Публичный API модуля.
function M.wantsInput()
    if type(_G.deskAnsBarBlocksSampChat) == 'function' and _G.deskAnsBarBlocksSampChat() then
        return drag.active == true
    end
    if type(_G.deskSpectateCameraOwnsInput) == 'function' and _G.deskSpectateCameraOwnsInput() then
        return drag.active == true
    end
    if drag.active then return true end
    if hovered then return true end
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin then return pin(hudRect) end
    return false
end

-- Slot Bucket Key
local function slotBucketKey(x, y)
    x = normalizeTdCoord(x, 'x')
    y = normalizeTdCoord(y, 'y')
    if not x or not y then return nil end
    return string.format('%d:%d', math.floor(x / 8 + 0.5), math.floor(y / 8 + 0.5))
end

-- Парсинг HP транспорта (server TD: «1000» или «| Fuel 68 | 1000»).
local function parseHealthPlain(raw, plain)
    plain = plain or normalizePlain(raw):gsub('_', ' ')
    local n = tonumber(plain:match('^(%d+)$'))
    if n and n >= 100 and n <= HEALTH_MAX then return n end
    for tag, num in tostring(raw or ''):gmatch('~([a-z])~(%d+)') do
        if tag == 'm' or tag == 'h' or tag == 'r' or tag == 'p' or tag == 'c' then
            n = tonumber(num)
            if n and n >= 100 and n <= HEALTH_MAX then return n end
        end
    end
    n = tonumber(plain:match('|[^|]*|%s*(%d+)%s*$'))
    if n and n >= 100 and n <= HEALTH_MAX then return n end
    for num in plain:gmatch('(%d+)') do
        n = tonumber(num)
        if n and n >= 250 and n <= HEALTH_MAX then return n end
    end
    return nil
end

-- Combined ADV line: «0 km/h | Fuel 68 | 1000» / «Open | Sport | ESMLB».
local function parseCombinedHudPlain(raw, plain)
    raw = tostring(raw or '')
    plain = plain or normalizePlain(raw):gsub('_', ' ')
    if plain == '' then return false end
    local hasPipe = plain:find('|', 1, true) ~= nil
    local multiField = hasPipe
        or (looksLikeSpeedText(raw, plain) and plain:find('fuel', 1, true))
        or (parseDoorPlain(plain) and parseModePlain(plain))
    if not multiField and not hasPipe then return false end

    local any = false
    local speed = extractSpeedValue(raw, plain)
    if speed ~= nil then storeField('speed', speed, nil); any = true end

    local fuel = parseFuelPlain(plain)
    if fuel == nil then fuel = tonumber(plain:match('fuel[^%d]*(%d+)')) end
    if fuel ~= nil then storeField('fuel', fuel, nil); any = true end

    local hp = parseHealthPlain(raw, plain)
    if hp ~= nil then storeField('health', hp, nil); any = true end

    local door = parseDoorPlain(plain)
    if door then storeField('door', nil, door); any = true end

    local mode = parseModePlain(plain)
    if mode then storeField('mode', nil, mode); any = true end

    local indSeg = plain:match('|[^|]*|[^|]*|%s*(.+)$')
        or plain:match('|[^|]*|%s*(.+)$')
    if indSeg then
        local ok = storeIndicators(raw, indSeg:gsub('%s+', ''))
        if ok then any = true end
    elseif plain:gsub('%s+', ''):match('^[esmlb]+$') then
        local ok = storeIndicators(raw, plain:gsub('%s+', ''))
        if ok then any = true end
    end
    return any
end

-- Infer Server Td Role
local function inferServerTdRole(text, x, y)
    local raw = tostring(text or '')
    local plain = normalizePlain(text):gsub('_', ' ')
    local n = tonumber(plain:match('^(%d+)$'))
    if n and n >= 100 and n <= HEALTH_MAX then return 'health' end
    if looksLikeSpeedText(raw, plain) then return 'speed' end
    if parseFuelPlain(plain) or plain:find('fuel', 1, true) then return 'fuel' end
    if parseDoorPlain(plain) then return 'door' end
    if parseModePlain(plain) then return 'mode' end
    local indPlain = plain:gsub('%s+', '')
    if indPlain:match('^[esmlb]+$') then return 'indicators' end
    local slotRole = roleFromHudPosition(x, y)
    if slotRole == 'speed' or slotRole == 'health' then
        n = tonumber(plain:match('^(%d+)$'))
        if n and n >= 100 and n <= HEALTH_MAX then return 'health' end
        if n and n <= 350 then return 'speed' end
    end
    return slotRole
end

-- Числовые поля спидометра — strict-слот, pin, или широкая зона при активной телеметрии.
local function vehicleTelemetryActive()
    if M.isLocalInVehicle() then return true end
    if getSpectateTargetId then
        local ok, tid = pcall(getSpectateTargetId)
        if ok and tid and tid >= 0 then return true end
    end
    return false
end

local function mayIngestNumericRole(role, inStrict, inArea, key, tdId)
    if role ~= 'speed' and role ~= 'fuel' and role ~= 'health' then return true end
    if inStrict then return true end
    if tdId and tdRolePin[tdId] then return true end
    if key and posSlots[key] then return true end
    if inArea and vehicleTelemetryActive() then return true end
    return false
end

-- Apply Server Td Field — speed/fuel/door/mode/indicators с server TD (ADV km/h).
local function applyServerTdField(text, data, tdId)
    data = data or {}
    tdId = tonumber(tdId)
    local x, y = tdPosX(data), tdPosY(data)
    local inArea = x and y and isVehicleHudArea(x, y)
    local inStrict = x and y and isStrictVehicleHudArea(x, y)
    local key = inStrict and slotBucketKey(x, y) or nil
    local raw = tostring(text or '')
    local plain = normalizePlain(raw):gsub('_', ' ')
    if parseCombinedHudPlain(raw, plain) then
        if key then posSlots[key] = 'combined' end
        if tdId then tdRolePin[tdId] = 'combined' end
        return
    end

    local role = tdId and tdRolePin[tdId] or nil
    if not role and key then role = posSlots[key] end
    if not role then role = inferServerTdRole(text, x, y) end
    if not role and M.matchesServerHudText(text) then
        role = inferServerTdRole(text, x, y)
        if not role then
            if looksLikeSpeedText(raw, plain) then role = 'speed'
            elseif parseHealthPlain(raw, plain) then role = 'health'
            elseif parseFuelPlain(plain) or plain:find('fuel', 1, true) then role = 'fuel'
            elseif parseDoorPlain(plain) then role = 'door'
            elseif parseModePlain(plain) then role = 'mode'
            elseif plain:gsub('%s+', ''):match('^[esmlb]+$') then role = 'indicators'
            end
        end
    end
    if not role then return end
    if role == 'speed_unit' or role == 'fuel_label' then
        if inStrict or inArea then touchActive() end
        return
    end
    if not mayIngestNumericRole(role, inStrict, inArea, key, tdId) then return end
    if not inArea and role ~= 'speed' and role ~= 'fuel' and role ~= 'health'
            and role ~= 'door' and role ~= 'mode' and role ~= 'indicators' then
        return
    end
    if key then posSlots[key] = role end
    if tdId then tdRolePin[tdId] = role end

    if role == 'speed' then
        local n = extractSpeedValue(raw, plain)
        if n ~= nil then storeField('speed', n, nil) end
    elseif role == 'fuel' then
        local n = parseFuelPlain(plain)
        if n == nil then
            for tag, num in raw:gmatch('~([a-z])~(%d+)') do
                if tag == 'c' or tag == 'p' or tag == 'u' then
                    n = tonumber(num)
                    break
                end
            end
        end
        if n == nil then n = tonumber(plain:match('(%d+)')) end
        if n ~= nil then storeField('fuel', n, nil) end
    elseif role == 'health' then
        local n = parseHealthPlain(raw, plain)
        if n ~= nil then storeField('health', n, nil) end
    elseif role == 'door' then
        local doorText = parseDoorPlain(plain)
        if not doorText and plain:match('^[%a]+$') then
            doorText = plain:sub(1, 1):upper() .. plain:sub(2)
        end
        if doorText then storeField('door', nil, doorText) end
    elseif role == 'mode' then
        local modeText = parseModePlain(plain)
        if modeText then storeField('mode', nil, modeText) end
    elseif role == 'indicators' then
        storeIndicators(raw, plain:gsub('%s+', ''))
    end
end

-- Публичный API модуля.
function M.shouldShow(settings)
    if not M.isEnabled(settings) then return false end
    if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then
        drag.active = false
        hovered = false
        return false
    end
    return M.isActive()
end

-- Публичный API модуля.
function M.shouldBlockServerTd(id, data, text)
    if not M.isEnabled() then return false end
    text = text or (data and data.text) or ''
    if isLikelyGaugeText(text) or isVehicleHudLabel(text) then return true end
    local x, y = tdPosX(data), tdPosY(data)
    if isVehicleHudArea(x, y) then return true end
    if y and y >= (vehicleHudYMin() - 24) then
        local plain = normalizePlain(text)
        if plain:match('^%d+$') or text:match('~[a-z]~%d') then return true end
    end
    return false
end

-- Публичный API модуля.
function M.ingest(id, data, text)
    id = tonumber(id)
    text = text or (data and data.text) or ''
    if text == '' and not data then return end
    applyServerTdField(text, data, id)
    if id then
        tdMeta[id] = {
            role = tdRolePin[id] or posSlots[slotBucketKey(tdPosX(data), tdPosY(data))] or 'decor',
            x = tdPosX(data),
            y = tdPosY(data),
            text = text,
        }
    end
end

-- Публичный API модуля.
function M.ingestString(id, text)
    id = tonumber(id)
    if not id then return false end
    text = text or ''
    local meta = tdMeta[id]
    if not meta then
        if not isLikelyGaugeText(text) and not isVehicleHudLabel(text) then
            return false
        end
        meta = { role = 'decor', x = nil, y = nil, text = text }
        tdMeta[id] = meta
    end
    local data = { position = { x = meta.x, y = meta.y }, text = text }
    M.ingest(id, data, text)
    if tdMeta[id] then return true end
    return M.shouldBlockServerTd(id, data, text)
end

-- Публичный API модуля.
function M.reset()
    hud.speed = nil
    hud.fuel = nil
    hud.health = nil
    hud.door = nil
    hud.driveMode = nil
    hud.indicators = {}
    hud.inVehicle = false
    hud.lastAt = 0
    hud.active = false
    tdMeta = {}
    posSlots = {}
    tdRolePin = {}
    drag.active = false
    hovered = false
    hudRect = nil
    anim.speedVis = 0
    anim.fuelPct = 0
    anim.hpPct = 0
end

-- Speed Color
local function speedColor(speed)
    speed = tonumber(speed) or 0
    if speed >= 140 then return col_warn or imgui.ImVec4(0.95, 0.35, 0.35, 1.0) end
    if speed >= 90 then return imgui.ImVec4(0.95, 0.78, 0.28, 1.0) end
    return col_accent or imgui.ImVec4(0.62, 0.44, 0.86, 1.0)
end

-- Metric Color — пороги HP как CEF, палитра Report Desk (яркие заливки).
local function metricColor(pct, kind, rawValue)
    if kind == 'health' then
        local hp = tonumber(rawValue)
        if hp then
            if hp <= 350 then return imgui.ImVec4(0.98, 0.42, 0.42, 1.0) end
            if hp <= 600 then return imgui.ImVec4(0.98, 0.82, 0.38, 1.0) end
            return imgui.ImVec4(0.78, 0.58, 0.98, 1.0)
        end
    end
    pct = tonumber(pct) or 0
    if pct <= 15 then return imgui.ImVec4(0.98, 0.42, 0.42, 1.0) end
    if pct <= 35 then return imgui.ImVec4(0.98, 0.82, 0.38, 1.0) end
    return imgui.ImVec4(0.58, 0.72, 0.98, 1.0)
end

-- Panel Size — ~26vh от высоты экрана.
local function panelSize(sh)
    sh = tonumber(sh) or 720
    return math.max(220, math.min(300, math.floor(PANEL_BASE * (sh / 720) + 0.5)))
end

-- Hud Layout — дуга в правом нижнем углу, слоты снизу вверх (без налезания).
local function hudLayout(panelW, panelH, wpX, wpY)
    panelW = tonumber(panelW) or PANEL_BASE
    panelH = tonumber(panelH) or panelW
    local size = math.min(panelW, panelH)
    local pad = size * 0.04
    local gaugeR = size * 0.42
    local cx = wpX + panelW - gaugeR - pad
    local cy = wpY + panelH - gaugeR - pad
    local innerR = gaugeR * 0.38
    local rowH = 22
    local statusY = wpY + panelH - pad - 10
    local fuelY = statusY - rowH - 10
    local hpY = fuelY - rowH - 4
    return {
        cx = cx, cy = cy,
        gaugeR = gaugeR, innerR = innerR,
        barW = gaugeR * 0.86,
        barH = math.max(5, size * 0.022),
        rowGap = 8,
        labelGap = 3,
        hpY = hpY,
        fuelY = fuelY,
        statusY = statusY,
    }
end

-- Color U32
local function colorU32(col)
    if toU32 then return toU32(col) end
    if imgui.ColorConvertFloat4ToU32 then
        return imgui.ColorConvertFloat4ToU32(col)
    end
    return 0xFFFFFFFF
end

-- Resolve Pos — по умолчанию правый нижний угол экрана (pivot 1,1).
local function resolvePos(settings, estH, sw, sh)
    estH = math.max(180, tonumber(estH) or PANEL_BASE)
    local rawX = tonumber(settings and settings.spectate_vehicle_hud_x)
    local rawY = tonumber(settings and settings.spectate_vehicle_hud_y)
    local custom = settings and settings.spectate_vehicle_hud_custom == true
    local pivotX, pivotY = 1, 1
    local hx = sw - HUD_MARGIN
    local hy = sh - HUD_MARGIN

    if custom then
        if rawX ~= nil then
            if rawX <= 0 then
                hx = sw + rawX
                pivotX = 1
            else
                hx = rawX
                pivotX = 0
            end
        end
        if rawY ~= nil then
            if rawY <= 0 then
                hy = sh + rawY
                pivotY = 1
            else
                hy = rawY
                pivotY = 0
            end
        end
    else
        hx = sw + (rawX or -HUD_MARGIN)
        hy = sh + (rawY or -HUD_MARGIN)
    end

    if pivotX == 1 then
        hx = math.max(estH + HUD_MARGIN, math.min(hx, sw - HUD_MARGIN))
    else
        hx = math.max(HUD_MARGIN, math.min(hx, sw - estH - HUD_MARGIN))
    end
    if pivotY == 1 then
        hy = math.max(estH + HUD_MARGIN, math.min(hy, sh - HUD_MARGIN))
    else
        hy = math.max(HUD_MARGIN, math.min(hy, sh - estH - HUD_MARGIN))
    end
    return hx, hy, pivotX, pivotY
end

-- Vec2 Xy
local function vec2xy(v)
    if not v then return 0, 0 end
    return tonumber(v.x) or tonumber(v[0]) or 0, tonumber(v.y) or tonumber(v[1]) or 0
end

-- Safe Ui Text
local function safeUiText(s)
    if uiText then return uiText(tostring(s or '')) end
    return tostring(s or '')
end

-- Lerp
local function lerp(a, b, t)
    a = tonumber(a) or 0
    b = tonumber(b) or 0
    t = tonumber(t) or 0
    return a + (b - a) * t
end

-- Update Speed Visual — сглаживание дуги (цифра остаётся мгновенной).
local function updateSpeedVisual(target)
    target = tonumber(target) or 0
    local dt = 1 / 60
    pcall(function()
        local io = imgui.GetIO()
        if io and io.DeltaTime and io.DeltaTime > 0 then
            dt = io.DeltaTime
        end
    end)
    local k = 1 - math.exp(-dt / SPEED_VIS_TAU)
    anim.speedVis = anim.speedVis + (target - anim.speedVis) * k
    if math.abs(target - anim.speedVis) < 0.35 then
        anim.speedVis = target
    end
    return anim.speedVis
end

-- Draw Radial Glow — мягкий фон как CEF hud_bg, в фиолетовых тонах.
local function drawRadialGlow(dl, cx, cy, r)
    if not dl or not dl.AddCircleFilled then return end
    local layers = {
        { mul = 1.05, a = 0.07 },
        { mul = 0.82, a = 0.10 },
        { mul = 0.58, a = 0.14 },
    }
    for _, layer in ipairs(layers) do
        local col = imgui.ImVec4(0.07, 0.06, 0.11, layer.a)
        dl:AddCircleFilled(imgui.ImVec2(cx, cy), r * layer.mul, colorU32(col))
    end
end

-- Draw Arc Stroke — дуга спидометра.
local function drawArcStroke(dl, cx, cy, r, a0, a1, col, thickness, segments)
    if not dl or not dl.PathClear or not dl.PathArcTo or not dl.PathStroke then return end
    dl:PathClear()
    dl:PathArcTo(imgui.ImVec2(cx, cy), r, a0, a1, segments or 48)
    dl:PathStroke(colorU32(col), false, thickness)
end

-- Text Size
local function textSize(text, scale)
    scale = scale or 1.0
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(scale) end
    local sz = imgui.CalcTextSize and imgui.CalcTextSize(safeUiText(text)) or imgui.ImVec2(20, 14)
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(1.0) end
    return vec2xy(sz)
end

-- Draw Dl Text
local function drawDlText(dl, x, y, text, col)
    if not dl or not dl.AddText then return 0, 0 end
    text = safeUiText(text)
    dl:AddText(imgui.ImVec2(x, y), colorU32(col), text)
    return textSize(text)
end

-- Draw Dl Text Centered
local function drawDlTextCentered(dl, cx, y, text, col)
    local tw, th = textSize(text)
    drawDlText(dl, cx - tw * 0.5, y, text, col)
    return th
end

-- Draw Speed Digit — крупная цифра по центру дуги (font scale через AddTextFontPtr).
local function drawSpeedDigitCentered(cx, cy, text, col, scale)
    scale = scale or 1.0
    text = safeUiText(text)
    local dl = imgui.GetWindowDrawList and imgui.GetWindowDrawList() or nil
    if not dl then return end
    local font = imgui.GetFont and imgui.GetFont() or nil
    local baseSize = (imgui.GetFontSize and imgui.GetFontSize()) or 13
    local fontSize = baseSize * scale
    local tw, lineH = textSize(text, scale)
    if lineH <= 0 then
        lineH = fontSize * 1.05
    end
    local y = cy - lineH * 0.5 - lineH * 0.04
    local x = cx - tw * 0.5
    if font and dl.AddTextFontPtr then
        dl:AddTextFontPtr(font, fontSize, imgui.ImVec2(x, y), colorU32(col), text)
    elseif dl.AddText then
        dl:AddText(imgui.ImVec2(x, y), colorU32(col), text)
    end
end

-- Gauge Core Center — центр тёмного диска внутри дуги (прорезь 90° снизу + оптика).
local function gaugeCoreCenter(lay)
    return lay.cx - lay.gaugeR * 0.012, lay.cy - lay.gaugeR * 0.045
end

-- Speed Text Center — чуть выше центра диска (baseline шрифта).
local function speedTextCenter(lay)
    local cx, cy = gaugeCoreCenter(lay)
    return cx, cy - lay.gaugeR * 0.012
end

-- Draw Inner Plate — диск по центру дуги, под цифру скорости.
local function drawInnerPlate(dl, lay, plateCx, plateCy)
    if not dl or not dl.AddCircleFilled then return end
    plateCx = plateCx or lay.cx
    plateCy = plateCy or lay.cy
    local col = imgui.ImVec4(0.07, 0.06, 0.11, 0.68)
    dl:AddCircleFilled(imgui.ImVec2(plateCx, plateCy), lay.innerR, colorU32(col))
    if dl.AddCircle then
        dl:AddCircle(
            imgui.ImVec2(plateCx, plateCy), lay.innerR,
            colorU32(imgui.ImVec4(0.52, 0.38, 0.78, 0.12)), 64, 1.0)
    end
end

-- Draw Metric Row — HP / Fuel: подпись + значение + яркая полоска.
local function drawMetricRow(dl, lay, y, label, value, maxVal, kind)
    maxVal = maxVal or 100
    value = tonumber(value)
    local pct = value and math.max(0, math.min(1, value / maxVal)) or 0
    if kind == 'health' then
        anim.hpPct = lerp(anim.hpPct, pct, ANIM_METRIC)
        pct = anim.hpPct
    else
        anim.fuelPct = lerp(anim.fuelPct, pct, ANIM_METRIC)
        pct = anim.fuelPct
    end

    local barW = lay.barW
    local barX = lay.cx - barW * 0.5
    local labelCol = col_muted2 or imgui.ImVec4(0.68, 0.66, 0.74, 0.92)
    local valText = value ~= nil and tostring(math.floor(value + 0.5)) or '--'
    local valCol = value and metricColor(pct * 100, kind, value) or labelCol
    local lh = imgui.GetTextLineHeight and imgui.GetTextLineHeight() or 13

    drawDlText(dl, barX, y, label, labelCol)
    local vw = textSize(valText)
    drawDlText(dl, barX + barW - vw, y, valText, valCol)

    local barY = y + lh + lay.labelGap
    local trackCol = imgui.ImVec4(1, 1, 1, 0.22)
    local trackBg = imgui.ImVec4(0.06, 0.05, 0.09, 0.65)
    dl:AddRectFilled(
        imgui.ImVec2(barX, barY),
        imgui.ImVec2(barX + barW, barY + lay.barH),
        colorU32(trackBg), 3)
    dl:AddRectFilled(
        imgui.ImVec2(barX, barY),
        imgui.ImVec2(barX + barW, barY + lay.barH),
        colorU32(trackCol), 3)
    if pct > 0.001 then
        local fillCol = metricColor(pct * 100, kind, value)
        local fillW = math.max(lay.barH + 1, barW * pct)
        dl:AddRectFilled(
            imgui.ImVec2(barX, barY),
            imgui.ImVec2(barX + fillW, barY + lay.barH),
            colorU32(fillCol), 3)
    end
    return barY + lay.barH + lay.rowGap
end

-- Door Tone
local function doorTone()
    if not hud.door or hud.door == '' then return nil, nil end
    local low = hud.door:lower()
    if low:find('open', 1, true) or low:find('\xEE\xF2\xEA\xF0', 1, true) then
        return 'Open', col_warn or imgui.ImVec4(0.95, 0.78, 0.28, 1.0)
    end
    if low:find('clos', 1, true) or low:find('lock', 1, true)
            or low:find('\xE7\xE0\xEA\xF0', 1, true) or low:find('\xE7\xE0\xEC\xEE\xEA', 1, true) then
        return 'Lock', col_accent or imgui.ImVec4(0.62, 0.44, 0.86, 1.0)
    end
    return nil, nil
end

-- Mode Tone
local function modeTone()
    if not hud.driveMode or hud.driveMode == '' then return nil, nil end
    local parsed = parseModePlain(normalizePlain(hud.driveMode))
    if parsed then
        return parsed, col_label or imgui.ImVec4(0.88, 0.86, 0.94, 0.92)
    end
    return nil, nil
end

-- Draw Status Row — одна строка текста в нижней прорези дуги.
local function drawStatusRow(dl, lay)
    local parts = {}
    local cols = {}
    local doorText, doorCol = doorTone()
    if doorText then parts[#parts + 1] = doorText; cols[#cols + 1] = doorCol end
    local modeText, modeCol = modeTone()
    if modeText then parts[#parts + 1] = modeText; cols[#cols + 1] = modeCol end
    if #parts == 0 then return end

    local sepCol = col_muted or imgui.ImVec4(0.45, 0.43, 0.50, 0.45)
    local totalW = 0
    for i, part in ipairs(parts) do
        totalW = totalW + textSize(part)
        if i < #parts then totalW = totalW + 12 end
    end

    local y = lay.statusY
    local x = lay.cx - totalW * 0.5
    for i, part in ipairs(parts) do
        drawDlText(dl, x, y, part, cols[i])
        x = x + textSize(part)
        if i < #parts then
            drawDlText(dl, x + 2, y, '\xB7', sepCol)
            x = x + 12
        end
    end
end

-- Draw Cef Style Hud — CEF: дуга + скорость сверху, HP/Fuel ниже, статус в прорези.
local function drawCefStyleHud(panelW, panelH, speed)
    panelW = math.max(220, tonumber(panelW) or PANEL_BASE)
    panelH = math.max(220, tonumber(panelH) or panelW)
    local wpX, wpY = vec2xy(imgui.GetWindowPos())
    local lay = hudLayout(panelW, panelH, wpX, wpY)
    local strokeW = math.max(3.0, math.min(panelW, panelH) / 24)
    local a0 = ARC_START
    local target = tonumber(speed) or 0
    local vis = updateSpeedVisual(target)
    local dl = imgui.GetWindowDrawList and imgui.GetWindowDrawList() or nil
    if not dl then return end

    drawRadialGlow(dl, lay.cx, lay.cy, lay.gaugeR * 1.02)

    local speedText = speed ~= nil and tostring(math.ceil(target)) or '--'
    local speedCol = speedColor(target)
    local speedScale = math.max(1.72, math.min(panelW, panelH) / 118)
    local coreCx, coreCy = gaugeCoreCenter(lay)
    local speedCx, speedCy = speedTextCenter(lay)

    drawInnerPlate(dl, lay, coreCx, coreCy)

    local trackCol = imgui.ImVec4(1, 1, 1, 0.12)
    drawArcStroke(dl, lay.cx, lay.cy, lay.gaugeR, a0, a0 + ARC_SPAN, trackCol, strokeW, 72)

    local pct = math.max(0, math.min(1, vis / SPEED_MAX))
    if pct > 0.002 then
        local fillCol = speedColor(vis)
        local aFill = a0 + ARC_SPAN * pct
        drawArcStroke(dl, lay.cx, lay.cy, lay.gaugeR, a0, aFill, fillCol, strokeW,
            math.max(10, math.floor(72 * pct)))
        local nx = lay.cx + math.cos(aFill) * lay.gaugeR
        local ny = lay.cy + math.sin(aFill) * lay.gaugeR
        dl:AddCircleFilled(imgui.ImVec2(nx, ny), strokeW * 0.44, colorU32(fillCol))
        dl:AddCircleFilled(imgui.ImVec2(nx, ny), strokeW * 0.16, colorU32(imgui.ImVec4(1, 1, 1, 0.90)))
    end

    drawSpeedDigitCentered(speedCx, speedCy, speedText, speedCol, speedScale)

    drawMetricRow(dl, lay, lay.hpY, 'HP', hud.health, HEALTH_MAX, 'health')
    drawMetricRow(dl, lay, lay.fuelY, 'Fuel', hud.fuel, FUEL_MAX, 'fuel')
    drawStatusRow(dl, lay)
end

-- Save Drag Pos
local function saveDragPos(settings, wp, ww, wh, sw, sh)
    if not settings or not wp then return end
    ww = tonumber(ww) or panelSize(sh)
    wh = tonumber(wh) or ww
    local nx, ny = vec2xy(wp)
    settings.spectate_vehicle_hud_custom = true
    if nx + ww > sw * 0.55 then
        settings.spectate_vehicle_hud_x = math.floor(nx + ww - sw + 0.5)
    else
        settings.spectate_vehicle_hud_x = math.floor(nx + 0.5)
    end
    if ny + wh > sh * 0.55 then
        settings.spectate_vehicle_hud_y = math.floor(ny + wh - sh + 0.5)
    else
        settings.spectate_vehicle_hud_y = math.floor(ny + 0.5)
    end
    if markDirtySettings then markDirtySettings() end
    if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
end

-- Публичный API модуля.
local function drawVehicleHudInner(settings)
    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end

    local panelSz = panelSize(sh)
    local hx, hy, pivotX, pivotY = resolvePos(settings, panelSz, sw, sh)
    if drag.active then
        hx = drag.offX
        hy = drag.offY
        pivotX, pivotY = 0, 0
        hx = math.max(HUD_MARGIN, math.min(hx, sw - panelSz - HUD_MARGIN))
        hy = math.max(HUD_MARGIN, math.min(hy, sh - panelSz - HUD_MARGIN))
    end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoScrollWithMouse then
        flags = flags + imgui.WindowFlags.NoScrollWithMouse
    end
    if imgui.WindowFlags.NoBackground then
        flags = flags + imgui.WindowFlags.NoBackground
    end
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end

    imgui.SetNextWindowSize(imgui.ImVec2(panelSz, panelSz), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always, imgui.ImVec2(pivotX, pivotY))

    spTheme.pushOverlayChrome(0.06)
    local stylePopN = 0
    if imgui.PushStyleVarVec2 then
        imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
        stylePopN = stylePopN + 1
        imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(2, 1))
        stylePopN = stylePopN + 1
    end
    if imgui.PushStyleVarFloat and imgui.StyleVar.ScrollbarSize then
        imgui.PushStyleVarFloat(imgui.StyleVar.ScrollbarSize, 0)
        stylePopN = stylePopN + 1
    end
    if not imgui.Begin('###desk_sp_vehicle_hud', nil, flags) then
        if stylePopN > 0 and imgui.PopStyleVar then imgui.PopStyleVar(stylePopN) end
        spTheme.popOverlayChrome()
        return
    end

    local drawOk, drawErr = pcall(function()
        if hud.driveMode and #normalizePlain(hud.driveMode) > 14 then
            hud.driveMode = parseModePlain(normalizePlain(hud.driveMode))
        end

        hovered = false
        local wpX, wpY = vec2xy(imgui.GetWindowPos())
        local ww = imgui.GetWindowWidth() or panelSz
        local wh = imgui.GetWindowHeight() or panelSz
        hudRect = { x0 = wpX, y0 = wpY, x1 = wpX + ww, y1 = wpY + wh }

        do
            local posFn = type(_G.deskWin32MousePos) == 'function' and _G.deskWin32MousePos
                or type(deskWin32MousePos) == 'function' and deskWin32MousePos
            local mx, my = posFn and posFn()
            if mx and my then
                hovered = mx >= wpX and mx < wpX + ww and my >= wpY and my < wpY + wh
            end
        end

        drawCefStyleHud(ww, wh, hud.speed)

        imgui.InvisibleButton('##veh_hud_drag', imgui.ImVec2(-1, -1))
        if imgui.IsItemHovered() or imgui.IsItemActive() then hovered = true end
        if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
            local delta = imgui.GetMouseDragDelta(0)
            local dx, dy = vec2xy(delta)
            if not drag.active then
                drag.active = true
                drag.startX = wpX
                drag.startY = wpY
                imgui.ResetMouseDragDelta(0)
                dx, dy = vec2xy(imgui.GetMouseDragDelta(0))
            end
            drag.offX = drag.startX + dx
            drag.offY = drag.startY + dy
        elseif drag.active and not imgui.IsMouseDown(0) then
            drag.active = false
            saveDragPos(settings, { x = wpX, y = wpY }, ww, wh, sw, sh)
        end
    end)

    imgui.End()
    if stylePopN > 0 and imgui.PopStyleVar then imgui.PopStyleVar(stylePopN) end
    spTheme.popOverlayChrome()
    if not drawOk and print then
        print('[report_desk_sp_vehicle_hud] draw: ' .. tostring(drawErr))
    end
end

-- Публичный API модуля.
function M.draw(settings)
    if not M.shouldShow(settings) then return end
    local ok, err = pcall(drawVehicleHudInner, settings)
    if not ok and print then
        print('[report_desk_sp_vehicle_hud] draw: ' .. tostring(err))
    end
end

-- Публичный API модуля.
function M.configure(deps)
    deps = deps or {}
    uiText = deps.uiText or function(s) return s end
    toU32 = deps.toU32
    col_accent = deps.col_accent
    col_accent_dim = deps.col_accent_dim
    col_muted = deps.col_muted
    col_muted2 = deps.col_muted2
    col_warn = deps.col_warn
    col_label = deps.col_label
    markDirtySettings = deps.markDirtySettings
    flushDirtyConfigNow = deps.flushDirtyConfigNow
    getSettingsFn = deps.getSettings
    getSpectateTargetId = deps.getSpectateTargetId
    inputDeps = deps.inputDeps
end

return M
