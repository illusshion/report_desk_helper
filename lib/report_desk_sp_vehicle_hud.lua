--[[ Модуль: кастомный спидометр из server TextDraw (/sp и свой транспорт). ]]
local M = {}

local imgui = require 'mimgui'
local spTheme = require 'report_desk_sp_theme'

local VEHICLE_HUD_X_MIN_DEFAULT = 400   -- зона server TD спидометра, px (640x448)
local VEHICLE_HUD_X_MAX_DEFAULT = 480
local VEHICLE_HUD_Y_MIN_DEFAULT = 385   -- нижняя полоса HUD
local STALE_SEC = 4.0
local ARC_SEGMENTS = 40
local PANEL_BASE = 260          -- спидометр: правый нижний угол
local HUD_MARGIN = 10
local HEALTH_MAX = 1000
local FUEL_MAX = 150
local SPEED_MAX = 160             -- как CEF ProgressBar
local ANIM_METRIC = 0.38
local SPEED_VIS_TAU = 0.07
local SPEED_KMH_PER_MS = 3.6
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
    doorLocked = nil,
    driveMode = nil,
    sportActive = nil,
    engine = nil,
    indicators = {},
    inVehicle = false,
    lastAt = 0,
    active = false,
}

local ENGINE_STATE_OFF = 17

local TD_META_MAX = 256
local tdMeta = {}
local tdMetaOrder = {}
local posSlots = {}
local tdRolePin = {}

local uiText, toU32, col_accent, col_accent_dim, col_muted, col_muted2, col_warn, col_label
local markDirtySettings, flushDirtyConfigNow, getSettingsFn, getSpectateTargetId
local resolveSpectateTargetPedFn

local drag = { active = false, startX = 0, startY = 0, offX = 0, offY = 0 }
local hovered = false
local hudRect = nil
local anim = { speedVis = 0, fuelPct = 0, hpPct = 0 }
local SPORT_OVERLAY_SEC = 5.0
local sportOverlayUntil = 0
local TELEMETRY_PIN_ROLES = {
    combined = true, speed = true, fuel = true, health = true,
    door = true, mode = true, engine = true, sport_toggle = true, indicators = true,
}

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

local function vehicleHudYMin()
    local settings = getSettingsFn and getSettingsFn() or nil
    return tonumber(settings and settings.spectate_vehicle_td_y_min) or VEHICLE_HUD_Y_MIN_DEFAULT
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
        if col == 2 then return 'fuel' end
        return nil
    end
    if col == 1 then return 'door' end
    if col == 2 then return 'mode' end
    if col == 3 then return 'indicators' end
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

-- Parse Engine Plain — «engine on/off», «двиг вкл/выкл» в combined TD.
local function parseEnginePlain(plain)
    plain = tostring(plain or ''):lower()
    if plain:find('engine', 1, true) or plain:find('\xE4\xE2\xE8\xE3', 1, true) then
        if plain:find('off', 1, true) or plain:find('\xE2\xFB\xEA\xEB', 1, true)
                or plain:find('stop', 1, true) then
            return false
        end
        if plain:find('on', 1, true) or plain:find('\xE2\xEA\xEB', 1, true)
                or plain:find('start', 1, true) then
            return true
        end
        if plain:match('^engine%s*$') or plain:match('^engine%s+on')
                or plain:match('\xE4\xE2\xE8\xE3%s*$') then
            return true
        end
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

-- Зона server TD: ingest строгая, block — шире (включая строку km/h / fuel / hp).
function M.isVehicleHudArea(x, y)
    x = normalizeTdCoord(x, 'x')
    y = normalizeTdCoord(y, 'y')
    local yMin = vehicleHudYMin()
    if isStrictVehicleHudArea(x, y) then return true end
    if y and y >= (yMin - 56) then
        if not x or (x >= 280 and x <= 580) then return true end
    end
    if y and y >= (yMin - 24) then
        if not x or x <= 560 then return true end
    end
    return false
end

-- Is Vehicle Hud Area
local function isVehicleHudArea(x, y)
    return M.isVehicleHudArea(x, y)
end

-- Parse Speed Plain — fallback ingest из server TD если native speed недоступен.
local function parseSpeedPlain(plain)
    plain = tostring(plain or '')
    local n = plain:match('(%d+)%s*km/h')
    if not n then n = plain:match('(%d+)%s*km') end
    if not n then n = plain:match('(%d+)%s*км/ч') end
    if not n then n = plain:match('(%d+)%s*км') end
    return tonumber(n)
end

-- Extract Speed Value — fallback TD ingest (~tag~ digits).
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

-- Looks Like Speed Text — скрытие server TD + detect combined lines.
local function looksLikeSpeedText(raw, plain)
    raw = tostring(raw or '')
    plain = tostring(plain or '')
    if plain:match('(%d+)%s*km/h') or plain:match('(%d+)%s*km') then return true end
    if plain:match('(%d+)%s*км/ч') or plain:match('(%d+)%s*км') then return true end
    if raw:find('km/h', 1, true) or raw:find('km h', 1, true) then return true end
    if raw:find('\xEA\xEC/\xF7', 1, true) or raw:find('\xEA\xEC', 1, true) then return true end
    if raw:match('~[gwybs]~%d+') then return true end
    return false
end

-- NO-API: fuel/door/mode/indicators — server TextDraw only.
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

-- SAMP {AABBGGRR} / {RRGGBB} перед буквой индикатора.
local function sampColorActive(hex)
    hex = tostring(hex or ''):gsub('[^%x]', '')
    if #hex < 6 then return true end
    if #hex > 6 then hex = hex:sub(-6) end
    local b = tonumber(hex:sub(1, 2), 16) or 0
    local g = tonumber(hex:sub(3, 4), 16) or 0
    local r = tonumber(hex:sub(5, 6), 16) or 0
    if r > 170 and g < 110 then return false end
    if g > 110 and g >= r then return true end
    if r < 90 and g < 90 and b < 90 then return false end
    return true
end

-- Цвет непосредственно перед словом в TD (~p~Sport, {hex}Engine).
local function parseWordColorActive(raw, word)
    raw = tostring(raw or '')
    word = tostring(word or '')
    if raw == '' or word == '' then return nil end
    local esc = word:gsub('(%W)', '%%%1')
    local tag = raw:match('~([a-z])~' .. esc)
    if tag then
        if tag == 'p' or tag == 'l' or tag == 'g' then return true end
        if tag == 'h' or tag == 'w' or tag == 'c' or tag == 'r' then return false end
    end
    local hex = raw:match('{(%x+)}' .. esc)
    if hex then return sampColorActive(hex) end
    return nil
end

-- Активный акцент server TD: SAMP-теги в тексте + letterColor (AABBGGRR).
local function parseTdActive(data, raw, wordHint)
    local wHi = parseWordColorActive(raw, wordHint)
    if wHi ~= nil then return wHi end
    raw = tostring(raw or '')
    if raw ~= '' then
        if raw:find('~p~', 1, true) or raw:find('~l~', 1, true) then return true end
        if raw:find('~h~', 1, true) or raw:find('~w~', 1, true) then return false end
        if raw:find('~g~', 1, true) then return true end
        for hex in raw:gmatch('{(%x+)}') do
            return sampColorActive(hex)
        end
        for tag in raw:gmatch('~([a-z])~') do
            if tag == 'p' or tag == 'l' or tag == 'g' then return true end
            if tag == 'h' or tag == 'w' or tag == 'c' or tag == 'r' then return false end
        end
    end
    local c = data and tonumber(data.letterColor)
    if not c then return nil end
    local a = bit.band(bit.rshift(c, 24), 0xFF)
    if a < 70 then return false end
    local b = bit.band(c, 0xFF)
    local g = bit.band(bit.rshift(c, 8), 0xFF)
    local r = bit.band(bit.rshift(c, 16), 0xFF)
    if r < 90 and g < 90 and b < 90 then return false end
    if math.abs(r - g) < 35 and math.abs(g - b) < 35 and r < 180 then return false end
    if r >= 140 and b >= 120 then return true end
    if r >= 100 and b >= 100 and (r + b) > (g * 2) then return true end
    if b >= 110 and r >= 70 and g <= 140 then return true end
    if g >= 120 and r <= 160 then return true end
    return nil
end

-- Door TD: Open/Lock + doorLocked из текста и цвета.
local function ingestDoorStatus(raw, plain, data)
    plain = normalizePlain(raw or plain or ''):gsub('_', ' ')
    if plain == '' then return false end
    if plain:find('sport', 1, true) and plain:find('mode', 1, true) then return false end
    local door = parseDoorPlain(plain)
    if not door and (plain == 'lock' or plain == 'locked') then door = 'Closed' end
    if not door then return false end
    hud.door = door
    if door == 'Closed' then
        local hi = parseTdActive(data, raw, door)
        hud.doorLocked = hi ~= false
    else
        hud.doorLocked = false
    end
    touchActive()
    return true
end

-- Mode TD: Sport/Eco + sportActive из цвета и overlay «SPORT MODE ON».
local function ingestModeStatus(raw, plain, data, tdId)
    plain = normalizePlain(raw or plain or ''):gsub('_', ' ')
    if plain == '' then return false end
    tdId = tonumber(tdId)
    if plain:find('sport', 1, true) and plain:find('mode', 1, true) then
        sportOverlayUntil = os.clock() + SPORT_OVERLAY_SEC
        if plain:find('off', 1, true) or plain:find('\xE2\xFB\xEA\xEB', 1, true) then
            hud.sportActive = false
            sportOverlayUntil = 0
        elseif plain:find('on', 1, true) or plain:find('\xE2\xEA\xEB', 1, true) then
            hud.sportActive = true
            sportOverlayUntil = 0
        end
        touchActive()
        return true
    end
    if plain == 'on' or plain == 'off' then
        local pinned = tdId and tdRolePin[tdId] == 'sport_toggle'
        if pinned or os.clock() < sportOverlayUntil then
            hud.sportActive = plain == 'on'
            sportOverlayUntil = 0
            if tdId then tdRolePin[tdId] = 'sport_toggle' end
            touchActive()
            return true
        end
    end
    local mode = parseModePlain(plain)
    if not mode then return false end
    hud.driveMode = mode
    local low = mode:lower()
    if low == 'sport' or low == '\xF1\xEF\xEE\xF0\xF2' then
        local hi = parseTdActive(data, raw, mode)
        if hi ~= nil then hud.sportActive = hi end
    elseif low == 'eco' or low == 'normal' or low == 'comfort' or low == 'city' then
        hud.sportActive = false
    end
    touchActive()
    return true
end

-- Отдельный TD «Engine» в слоте статуса (как Open / Sport).
local function ingestEngineStatusWord(raw, plain, data)
    plain = normalizePlain(raw or plain or ''):gsub('_', ' ')
    if plain == '' then return false end
    local low = plain:lower()
    if low ~= 'engine' and not low:match('^engine%s') and not low:match('^\xE4\xE2\xE8\xE3') then
        return false
    end
    local eng = parseEnginePlain(low)
    if eng == nil then eng = parseTdActive(data, raw, 'Engine') end
    if eng == nil then return false end
    hud.engine = eng and true or false
    hud.indicators['E'] = hud.engine
    touchActive()
    return true
end

-- Native engine byte (CVehicle + 0x428); isCarEngineOn в ML часто нет.
local function readCarEngineOn(car)
    if not car or car == 0 then return nil end
    if type(isCarEngineOn) == 'function' then
        local ok, on = pcall(isCarEngineOn, car)
        if ok and on ~= nil then return on and true or false end
    end
    if type(getCarPointer) ~= 'function' or type(readMemory) ~= 'function' then
        return nil
    end
    local ptr = getCarPointer(car)
    if not ptr or ptr == 0 then return nil end
    local ok, st = pcall(readMemory, ptr + 0x428, 1, false)
    if not ok or st == nil then return nil end
    st = tonumber(st) or 0
    return st ~= ENGINE_STATE_OFF
end

-- Парсинг данных с сервера/чата.
local function parseIndicatorLetter(raw, letter)
    letter = tostring(letter or ''):lower()
    if letter == '' then return nil end
    local upper = letter:upper()
    local tag = raw:match('~([a-z])~' .. letter) or raw:match('~([a-z])~' .. upper)
    if tag then return indicatorTagActive(tag) end
    local hex = raw:match('{(%x+)}%s*' .. upper) or raw:match('{(%x+)}%s*' .. letter)
    if hex then return sampColorActive(hex) end
    if raw:find(upper, 1, true) then return true end
    return true
end

-- Ingest Indicators Raw — ~g~E~h~S и {hex}E с server TD (ADV /sp).
local function ingestIndicatorRaw(raw, plainHint)
    raw = tostring(raw or '')
    if raw == '' then return false end
    local plain = tostring(plainHint or ''):gsub('%s+', ''):lower()
    if plain == '' then
        plain = raw:gsub('{[0-9A-Fa-f]+}', ''):gsub('~[^~]*~', ''):gsub('%s+', ''):lower()
    end
    local any = false

    for tag, letter in raw:gmatch('~([a-z])~([ESMLBesmlb])') do
        local key = letter:upper()
        if INDICATOR_HINT[key] then
            if key == 'E' and M.isLocalInVehicle() then
                -- E в ESMLB — индикатор, не двигатель в своём ТС.
            else
                hud.indicators[key] = indicatorTagActive(tag) and true or false
                if key == 'E' then hud.engine = hud.indicators[key] end
            end
            any = true
        end
    end

    for hex, letter in raw:gmatch('{(%x+)}([ESMLBesmlb])') do
        local key = letter:upper()
        if INDICATOR_HINT[key] then
            if key ~= 'E' or not M.isLocalInVehicle() then
                hud.indicators[key] = sampColorActive(hex) and true or false
                if key == 'E' then hud.engine = hud.indicators[key] end
            end
            any = true
        end
    end

    if plain:match('^[esmlb]+$') then
        for i = 1, #plain do
            local ch = plain:sub(i, i):upper()
            if INDICATOR_HINT[ch] and hud.indicators[ch] == nil then
                local on = parseIndicatorLetter(raw, ch)
                hud.indicators[ch] = on ~= false
                if ch == 'E' and not M.isLocalInVehicle() then
                    hud.engine = hud.indicators[ch]
                end
                any = true
            end
        end
    elseif #plain == 1 and plain:match('^[esmlb]$') then
        local key = plain:upper()
        if INDICATOR_HINT[key] then
            hud.indicators[key] = parseIndicatorLetter(raw, key) ~= false
            if key == 'E' and not M.isLocalInVehicle() then
                hud.engine = hud.indicators[key]
            end
            any = true
        end
    end

    if any then touchActive() end
    return any
end

-- Store Indicators
local function storeIndicators(raw, plain)
    plain = plain:gsub('%s+', '')
    if plain == '' then return false end
    if ingestIndicatorRaw(raw, plain) then
        if #plain == 1 and plain:match('^[esmlb]$') then
            return true, 'ind_' .. plain:upper()
        end
        return true, 'indicators'
    end
    return false
end

-- Overlay «SPORT MODE» + отдельный TD «ON/OFF» — ingest, не скрывать.
function M.isSportModeOverlayText(text, id)
    local plain = normalizePlain(text or '')
    if plain:find('sport', 1, true) and plain:find('mode', 1, true) then return true end
    if plain == 'on' or plain == 'off' then
        id = tonumber(id)
        if id and tdRolePin[id] == 'sport_toggle' then return true end
        if os.clock() < sportOverlayUntil then return true end
    end
    return false
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
    if looksLikeSpeedText(text, plain) then return true end
    if parseFuelPlain(plain) then return true end
    for word, _ in pairs(DOOR_WORDS) do
        if plain:find(word, 1, true) then return true end
    end
    for word, _ in pairs(DRIVE_MODES) do
        if plain == word or plain:find('|%s*' .. word, 1, true)
                or plain:find('^' .. word .. '%s') then return true end
    end
    if plain == 'engine' or plain:match('^engine%s') then return true end
    local n = tonumber(plain:match('^(%d+)$'))
    if n and n >= 100 and n <= HEALTH_MAX then return true end
    if plain:match('^[esmlb ]+$') then return true end
    if text:match('~[a-z]~%d') and not text:find('__', 1, true) then return true end
    return false
end

touchActive = function()
    hud.lastAt = os.clock()
    hud.active = true
    hud.inVehicle = true
end

-- Локальный ped в транспорте (только свой игрок; для /sp — server TD).
function M.isLocalInVehicle()
    if not PLAYER_PED or not isCharInAnyCar then return false end
    return isCharInAnyCar(PLAYER_PED) and true or false
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
        ingestDoorStatus(textValue, normalizePlain(textValue), nil)
    elseif role == 'mode' and textValue and textValue ~= '' then
        ingestModeStatus(textValue, normalizePlain(textValue), nil)
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
    if hud.door or hud.driveMode or hud.engine ~= nil then return true end
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
    if hud.door or hud.driveMode or hud.engine ~= nil then return true end
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
    if type(_G.deskSpectateOverlayInputAllowed) == 'function' and not _G.deskSpectateOverlayInputAllowed() then
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

    if ingestDoorStatus(raw, plain, nil) then any = true end
    if ingestModeStatus(raw, plain, nil) then any = true end
    if ingestEngineStatusWord(raw, plain, nil) then any = true end

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
    if plain == 'engine' or plain:match('^engine%s') then return 'engine' end
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

local function getSpectateTargetPed()
    if resolveSpectateTargetPedFn then
        local ok, ped = pcall(resolveSpectateTargetPedFn)
        if ok and ped and ped ~= 0 then return ped end
    end
    if not getSpectateTargetId then return nil end
    local ok, tid = pcall(getSpectateTargetId)
    if not ok or not tid or tid < 0 then return nil end
    if type(sampGetCharHandleBySampPlayerId) ~= 'function' then return nil end
    local ok2, ped = sampGetCharHandleBySampPlayerId(tid)
    if ok2 and ped and ped ~= 0 and type(doesCharExist) == 'function' and doesCharExist(ped) then
        return ped
    end
    return nil
end

local function getCarFromPed(ped)
    if not ped or ped == 0 then return nil end
    if type(storeCarCharIsInNoSave) == 'function' then
        local car = storeCarCharIsInNoSave(ped)
        if car and car ~= 0 then return car end
    end
    if type(getCarCharIsUsing) == 'function' then
        local car = getCarCharIsUsing(ped, false)
        if car and car ~= 0 then return car end
    end
    return nil
end

local function isSpectateTargetInVehicle()
    if M.isLocalInVehicle() then return true end
    local ped = getSpectateTargetPed()
    if not ped then return false end
    if type(isCharInAnyCar) ~= 'function' then return false end
    local ok, inCar = pcall(isCharInAnyCar, ped)
    return ok and inCar == true
end

local function vehicleTelemetryActive()
    if M.isLocalInVehicle() then return true end
    return isSpectateTargetInVehicle()
end

local function mayIngestNumericRole(role, inStrict, inArea, key, tdId, text)
    if role ~= 'speed' and role ~= 'fuel' and role ~= 'health' then return true end
    if inStrict then return true end
    if tdId and tdRolePin[tdId] then return true end
    if key and posSlots[key] then return true end
    if inArea and vehicleTelemetryActive() then return true end
    if vehicleTelemetryActive() and text and M.matchesServerHudText(text) then return true end
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
            elseif plain == 'engine' or plain:match('^engine%s') then role = 'engine'
            elseif plain:gsub('%s+', ''):match('^[esmlb]+$') then role = 'indicators'
            end
        end
    end
    if not role then return end
    if role == 'speed_unit' or role == 'fuel_label' then
        if inStrict or inArea then touchActive() end
        return
    end
    if not mayIngestNumericRole(role, inStrict, inArea, key, tdId, text) then return end
    if not inArea and role ~= 'speed' and role ~= 'fuel' and role ~= 'health'
            and role ~= 'door' and role ~= 'mode' and role ~= 'engine' and role ~= 'indicators' then
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
        ingestDoorStatus(raw, plain, data)
    elseif role == 'mode' then
        ingestModeStatus(raw, plain, data, tdId)
    elseif role == 'engine' then
        ingestEngineStatusWord(raw, plain, data)
    elseif role == 'indicators' then
        ingestIndicatorRaw(raw, plain:gsub('%s+', ''))
    end
    if vehicleTelemetryActive() and M.matchesServerHudText(text) then
        touchActive()
    end
end

function M.isSpectateTargetInVehicle()
    return isSpectateTargetInVehicle()
end

-- Сброс HUD при выходе цели из ТС (/sp). Вызывать из tick/draw, не из shouldShow.
function M.syncSpectateVehiclePresence()
    if M.isLocalInVehicle() then return end
    local ok, inVeh = pcall(isSpectateTargetInVehicle)
    if not ok or inVeh then return end
    if hud.active or hud.inVehicle then
        M.reset()
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
    if M.isLocalInVehicle() then return true end
    local ok, inVeh = pcall(isSpectateTargetInVehicle)
    if not ok or not inVeh then return false end
    if M.peekActive() then return true end
    return M.isActive()
end

-- Публичный API модуля.
function M.shouldBlockServerTd(id, data, text)
    if not M.isEnabled() then return false end
    if M.isSportModeOverlayText(text, id) then return false end
    id = tonumber(id)
    if id and tdRolePin[id] then return true end
    local x, y = tdPosX(data), tdPosY(data)
    if (not x or not y) and id and tdMeta[id] then
        x, y = tdMeta[id].x, tdMeta[id].y
    end
    if isVehicleHudArea(x, y) then return true end
    text = text or (data and data.text) or ''
    if text ~= '' and vehicleTelemetryActive() and M.matchesServerHudText(text) then
        return true
    end
    return false
end

-- Evict oldest tdMeta entries when cache grows too large.
local function touchTdMeta(id, entry)
    if not id then return end
    for i, k in ipairs(tdMetaOrder) do
        if k == id then
            table.remove(tdMetaOrder, i)
            break
        end
    end
    tdMeta[id] = entry
    tdMetaOrder[#tdMetaOrder + 1] = id
    while #tdMetaOrder > TD_META_MAX do
        local old = table.remove(tdMetaOrder, 1)
        if old then
            tdMeta[old] = nil
            tdRolePin[old] = nil
        end
    end
end

-- Публичный API модуля.
function M.ingest(id, data, text)
    id = tonumber(id)
    text = text or (data and data.text) or ''
    if text == '' and not data then return end
    applyServerTdField(text, data, id)
    if id then
        touchTdMeta(id, {
            role = tdRolePin[id] or posSlots[slotBucketKey(tdPosX(data), tdPosY(data))] or 'decor',
            x = tdPosX(data),
            y = tdPosY(data),
            text = text,
            letterColor = data and data.letterColor,
        })
    end
end

-- Публичный API модуля.
function M.ingestString(id, text)
    id = tonumber(id)
    if not id then return false end
    text = text or ''
    local meta = tdMeta[id]
    local pinned = tdRolePin[id]
    if not meta then
        if not pinned and not M.matchesServerHudText(text) then return false end
        meta = { role = pinned or 'decor', x = nil, y = nil, text = text, letterColor = nil }
    else
        meta.text = text
    end
    touchTdMeta(id, {
        role = pinned or meta.role or 'decor',
        x = meta.x,
        y = meta.y,
        text = text,
        letterColor = meta.letterColor,
    })
    local data = {
        position = { x = meta.x, y = meta.y },
        text = text,
        letterColor = meta.letterColor,
    }
    M.ingest(id, data, text)
    return M.shouldBlockServerTd(id, data, text)
end

-- Публичный API модуля.
function M.reset()
    hud.speed = nil
    hud.fuel = nil
    hud.health = nil
    hud.door = nil
    hud.doorLocked = nil
    hud.driveMode = nil
    hud.sportActive = nil
    hud.engine = nil
    hud.indicators = {}
    hud.inVehicle = false
    hud.lastAt = 0
    hud.active = false
    sportOverlayUntil = 0
    tdMeta = {}
    tdMetaOrder = {}
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
            colorU32(imgui.ImVec4(0.52, 0.38, 0.78, 0.12)), 36, 1.0)
    end
end

-- Draw Metric Row — HP / Fuel: подпись + значение + яркая полоска.
local function drawMetricRow(dl, lay, y, label, value, maxVal, kind)
    maxVal = tonumber(maxVal) or 100
    if maxVal <= 0 then maxVal = 100 end
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

-- Цвет статуса: фиолетовый = активно, приглушённый = выкл.
local function statusItemCol(active)
    if active then
        return col_accent or imgui.ImVec4(0.72, 0.52, 0.98, 1.0)
    end
    return col_muted2 or imgui.ImVec4(0.50, 0.48, 0.56, 0.55)
end

-- Пересборка pinned TD + native чтение цели /sp.
local function getLocalCar()
    if not PLAYER_PED or not isCharInAnyCar or not isCharInAnyCar(PLAYER_PED) then
        return nil
    end
    return getCarFromPed(PLAYER_PED)
end

local function speedKmhFromVelocityMs(vx, vy, vz)
    local sp = math.sqrt(vx * vx + vy * vy + vz * vz) * SPEED_KMH_PER_MS
    return math.max(0, math.floor(sp + 0.5))
end

local function hasPinnedSpeedTd()
    for id, role in pairs(tdRolePin) do
        if role == 'speed' or role == 'combined' then return true end
    end
    return false
end

local function readCarSpeed(car)
    if not car or car == 0 then return nil end
    if type(getCarSpeed) == 'function' then
        local ok, sp = pcall(getCarSpeed, car)
        if ok and sp ~= nil then
            return math.max(0, math.floor((tonumber(sp) or 0) + 0.5))
        end
    end
    if type(getCarPointer) == 'function' and type(readMemory) == 'function'
            and type(representIntAsFloat) == 'function' then
        local ptr = getCarPointer(car)
        if ptr and ptr ~= 0 then
            local okx, vx = pcall(readMemory, ptr + 0x44, 4, false)
            local oky, vy = pcall(readMemory, ptr + 0x48, 4, false)
            local okz, vz = pcall(readMemory, ptr + 0x4C, 4, false)
            if okx and oky and okz then
                return speedKmhFromVelocityMs(
                    representIntAsFloat(vx),
                    representIntAsFloat(vy),
                    representIntAsFloat(vz))
            end
        end
    end
    return nil
end

local function readLocalVehicleSpeed()
    if not M.isLocalInVehicle() then return nil end
    return readCarSpeed(getLocalCar())
end

local function syncSpeedFromMoveSpeed(moveSpeed)
    if not moveSpeed then return nil end
    local vx = tonumber(moveSpeed.x or moveSpeed[1]) or 0
    local vy = tonumber(moveSpeed.y or moveSpeed[2]) or 0
    local vz = tonumber(moveSpeed.z or moveSpeed[3]) or 0
    return speedKmhFromVelocityMs(vx, vy, vz)
end

local function refreshAllPinnedTdFromMeta()
    for _, id in ipairs(tdMetaOrder) do
        local role = tdRolePin[id]
        if not role or not TELEMETRY_PIN_ROLES[role] then goto cont end
        local meta = tdMeta[id]
        if not meta or not meta.text or meta.text == '' then goto cont end
        local data = {
            letterColor = meta.letterColor,
            position = { x = meta.x, y = meta.y },
            text = meta.text,
        }
        applyServerTdField(meta.text, data, id)
        ::cont::
    end
end

local function refreshSpectateVehicleState()
    if M.isLocalInVehicle() then return end
    if not isSpectateTargetInVehicle() then return end
    touchActive()
    local ped = getSpectateTargetPed()
    if not ped then return end
    local car = getCarFromPed(ped)
    if not car or car == 0 then return end
    local on = readCarEngineOn(car)
    if on ~= nil then
        hud.engine = on
        hud.indicators['E'] = on
    end
end

local function refreshLocalVehicleState()
    if not M.isLocalInVehicle() then return end
    touchActive()
    local car = getLocalCar()
    if car and car ~= 0 then
        local on = readCarEngineOn(car)
        if on ~= nil then
            hud.engine = on
            hud.indicators['E'] = on
        end
    end
    if not hasPinnedSpeedTd() then
        local sp = readLocalVehicleSpeed()
        if sp ~= nil then hud.speed = sp end
    end
end

-- Draw Status Row — Lock · Sport · Engine (фиолетовый = вкл).
local function drawStatusRow(dl, lay)
    local items = {
        { 'Lock', hud.doorLocked == true },
        { 'Sport', hud.sportActive == true },
        { 'Engine', hud.engine == true },
    }
    local sepCol = col_muted or imgui.ImVec4(0.45, 0.43, 0.50, 0.40)
    local totalW = 0
    for i, item in ipairs(items) do
        totalW = totalW + textSize(item[1])
        if i < #items then totalW = totalW + 12 end
    end

    local y = lay.statusY
    local x = lay.cx - totalW * 0.5
    for i, item in ipairs(items) do
        drawDlText(dl, x, y, item[1], statusItemCol(item[2]))
        x = x + textSize(item[1])
        if i < #items then
            drawDlText(dl, x + 2, y, '\xB7', sepCol)
            x = x + 12
        end
    end
end

-- Draw Cef Style Hud — дуга + скорость сверху, HP/Fuel ниже, статус в прорези.
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
    drawArcStroke(dl, lay.cx, lay.cy, lay.gaugeR, a0, a0 + ARC_SPAN, trackCol, strokeW, ARC_SEGMENTS)

    local pct = math.max(0, math.min(1, vis / SPEED_MAX))
    if pct > 0.002 then
        local fillCol = speedColor(vis)
        local aFill = a0 + ARC_SPAN * pct
        drawArcStroke(dl, lay.cx, lay.cy, lay.gaugeR, a0, aFill, fillCol, strokeW,
            math.max(8, math.floor(ARC_SEGMENTS * pct)))
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

    local wantInput = M.wantsInput()
    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoScrollbar
    if not wantInput and imgui.WindowFlags.NoInputs then
        flags = flags + imgui.WindowFlags.NoInputs
    end
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

        if M.isLocalInVehicle() or isSpectateTargetInVehicle() then
            refreshAllPinnedTdFromMeta()
        end
        if M.isLocalInVehicle() then
            refreshLocalVehicleState()
        else
            refreshSpectateVehicleState()
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

-- SAMP vehicle sync цели /sp: скорость + HP (как native в своём ТС).
function M.onVehicleSync(playerId, vehicleId, data)
    if not M.isEnabled() or M.isLocalInVehicle() then return end
    if not getSpectateTargetId then return end
    local ok, tid = pcall(getSpectateTargetId)
    if not ok or not tid or tid < 0 or tonumber(playerId) ~= tid then return end
    if not isSpectateTargetInVehicle() then return end
    touchActive()
    data = data or {}
    local hp = tonumber(data.vehicleHealth)
    if hp then
        hud.health = math.max(0, math.min(HEALTH_MAX, math.floor(hp + 0.5)))
    end
    local sp = syncSpeedFromMoveSpeed(data.moveSpeed)
    if sp ~= nil and not hasPinnedSpeedTd() then hud.speed = sp end
end

-- SAMP RPC: engine/doors.
function M.onSetVehicleParamsEx(vehicleId, params, doors)
    if not M.isEnabled() then return end
    if not M.isLocalInVehicle() and not vehicleTelemetryActive() then return end
    if params then
        local eng = tonumber(params.engine)
        if eng ~= nil then
            hud.engine = eng ~= 0
            hud.indicators['E'] = hud.engine
            touchActive()
        end
        local dr = tonumber(params.doors)
        if dr ~= nil then
            hud.doorLocked = dr ~= 0
            touchActive()
        end
    end
    if doors then
        local driver = tonumber(doors.driver)
        if driver ~= nil then
            hud.doorLocked = driver ~= 0
            touchActive()
        end
    end
end

-- SAMP RPC: doorsLocked.
function M.onSetVehicleParams(vehicleId, objective, doorsLocked)
    if not M.isEnabled() then return end
    if not M.isLocalInVehicle() and not vehicleTelemetryActive() then return end
    if doorsLocked ~= nil then
        hud.doorLocked = doorsLocked and true or false
        touchActive()
    end
end

-- Посадка/выход из своего ТС — сброс/активация HUD.
function M.onLocalVehicleChanged(inVehicle)
    if inVehicle then
        touchActive()
        hud.inVehicle = true
    else
        M.reset()
    end
end

-- Публичный API модуля.
function M.draw(settings)
    M.syncSpectateVehiclePresence()
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
    resolveSpectateTargetPedFn = deps.resolveSpectateTargetPed
end

return M
