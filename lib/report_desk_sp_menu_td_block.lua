--[[ Module: block server SP menu TextDraws. ]]
local M = {}

local vehicleHud = require 'report_desk_sp_vehicle_hud'

local session
local trimFn, getSettingsFn, cbEnsureTdHooks
local blockedSpMenuTdIds = {}

local function cp1251(...)
    return string.char(...)
end

local SP_MENU_MARKERS = {
    'exit', 'mute', 'slap', 'stats', 'stat', 'update', 'tow', 'tr', 'skip',
    'weap', 'skick', 'info', 'freeze', 'dgun', 'kick', 'ban', 'jail', 'warn',
    '-exit-', 'exit-',
    cp1251(0xC2, 0xFB, 0xF5, 0xEE, 0xE4),
    cp1251(0xEC, 0xF3, 0xF2),
    cp1251(0xF1, 0xEB, 0xFD, 0xEF),
    cp1251(0xF1, 0xF2, 0xE0, 0xF2),
    cp1251(0xEE, 0xE1, 0xED, 0xEE, 0xE2),
    cp1251(0xE0, 0xEF, 0xE4, 0xE5, 0xE9, 0xF2),
    cp1251(0xED, 0xE0, 0xF1, 0xF2, 0xF0),
    cp1251(0xEC, 0xE8, 0xF0),
    cp1251(0xE7, 0xE0, 0xEC, 0xEE, 0xF0),
    cp1251(0xEE, 0xF0, 0xF3, 0xE6),
    cp1251(0xE2, 0xEE, 0xE4),
    cp1251(0xF1, 0xED, 0xFF, 0xF2),
    cp1251(0xF1, 0xEB, 0xFD, 0xEF, 0xED),
    cp1251(0xE4, 0xEE, 0xF1, 0xF2, 0xE0),
}

local SP_MENU_COLUMN_LEFT_X = 280
local SP_MENU_COLUMN_BLOCK_X = 520
local VEHICLE_HUD_X_MIN = 400
local VEHICLE_HUD_X_MAX = 480

function M.configure(cfg)
    cfg = cfg or {}
    session = cfg.session
    trimFn = cfg.trim
    getSettingsFn = cfg.getSettings
    cbEnsureTdHooks = cfg.ensureTdHooks
end

function M.getTargetId()
    if not session then return -1 end
    return tonumber(session.targetId) or -1
end

local function uiEnabled()
    local s = getSettingsFn and getSettingsFn()
    return not s or s.spectate_sp_ui ~= false
end

local function clearMenuColumnState()
    if session then session.menuColumnX = nil end
    blockedSpMenuTdIds = {}
end

M.clearMenuColumnState = clearMenuColumnState

local function normalizeMenuText(text)
    text = tostring(text or '')
    text = text:gsub('{[0-9A-Fa-f]+}', '')
    text = text:gsub('~[^~]*~', '')
    text = text:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return text:lower()
end

local function tdPosX(data)
    if not data or not data.position then return nil end
    return tonumber(data.position.x or data.position[1])
end

local function tdPosY(data)
    if not data or not data.position then return nil end
    return tonumber(data.position.y or data.position[2])
end

local function isSpMenuOverlayText(text)
    text = tostring(text or '')
    if text == '' then return false end
    return text:match('~%a~%d+__') ~= nil and text:find('__', 1, true) ~= nil
end

local function isSpMenuNumericText(text)
    text = tostring(text or '')
    if text == '' or text:match('~') then return false end
    return text:match('%d+__%d+') ~= nil
end

local function isBlankButtonText(text)
    text = tostring(text or '')
    if text == '' or text == ' ' then return true end
    return text:match('^_+$') ~= nil
end

local function isVehicleHudText(text)
    if vehicleHud.matchesServerHudText and vehicleHud.matchesServerHudText(text) then
        return true
    end
    local plain = normalizeMenuText(text)
    if plain == '' then return false end
    plain = plain:gsub('_', ' ')
    if plain:find('km/h', 1, true) or plain:find('km h', 1, true) then return true end
    if plain:find('fuel', 1, true) then return true end
    if plain:find(cp1251(0xEA, 0xEC, 0x2F, 0xF7), 1, true) then return true end
    if plain:find(cp1251(0xF2, 0xEE, 0xEF, 0xEB, 0xE8, 0xE2, 0xEE), 1, true) then return true end
    return false
end

local function isVehicleHudColumnX(x)
    x = tonumber(x)
    if not x then return false end
    if x >= VEHICLE_HUD_X_MIN and x <= VEHICLE_HUD_X_MAX then return true end
    if x > 0 and x <= 1.0 and x >= 0.62 and x <= 0.75 then return true end
    return false
end

local function isVehicleHudBottomArea(x, y)
    if isVehicleHudColumnX(x) then return true end
    return vehicleHud.isVehicleHudArea and vehicleHud.isVehicleHudArea(x, y) or false
end

local function isSpMenuColumnX(x)
    x = tonumber(x)
    if not x then return false end
    if x >= SP_MENU_COLUMN_BLOCK_X then return true end
    if x >= SP_MENU_COLUMN_LEFT_X then return true end
    if x > 0 and x <= 1.0 and x >= 0.42 then return true end
    return false
end

local function isServerSpMenuText(text)
    local plain = normalizeMenuText(text)
    if plain == '' then return false end
    local raw = tostring(text or '')
    if isSpMenuOverlayText(raw) or isSpMenuNumericText(raw) then return true end
    for _, m in ipairs(SP_MENU_MARKERS) do
        if plain:find(m:lower(), 1, true) then return true end
    end
    return plain:find('exit', 1, true) ~= nil
end

local function isLikelyVehicleGaugeText(text, x, y)
    if not x or not y or not isVehicleHudBottomArea(x, y) then return false end
    local raw = tostring(text or '')
    if isSpMenuOverlayText(raw) or isSpMenuNumericText(raw) then return false end
    if isServerSpMenuText(text) or isBlankButtonText(text) then return false end
    if isVehicleHudText(text) then return true end
    if raw:match('~[a-z]~%d') and not raw:find('__', 1, true) then return true end
    return false
end

local function rememberMenuColumn(data)
    local x = tdPosX(data)
    if x and isSpMenuColumnX(x) and not isVehicleHudColumnX(x) then
        session.menuColumnX = x
    end
end

function M.shouldSuppressServerSpMenu()
    if not uiEnabled() then return false end
    if M.getTargetId() >= 0 then return true end
    if session and session.awaitingSpectate == true then return true end
    return false
end

function M.isAwaitingSpectate()
    return session and session.awaitingSpectate == true
end

function M.markAwaitingSpectate(on)
    if not session then return end
    session.awaitingSpectate = on and true or false
    if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
end

local function isSpMenuRowY(y)
    y = tonumber(y)
    if not y then return true end
    if y > 0 and y <= 1.0 then
        return y >= 0.10 and y <= 0.98
    end
    return y >= 50 and y <= 440
end

local function isServerSpMenuTextDrawOnly(id, data, text)
    text = text or (data and data.text) or ''
    id = tonumber(id)
    if id and blockedSpMenuTdIds[id] then return true end
    if isServerSpMenuText(text) then
        rememberMenuColumn(data)
        if id then blockedSpMenuTdIds[id] = true end
        return true
    end
    if not M.shouldSuppressServerSpMenu() then return false end
    if not data then return false end
    local x = tdPosX(data)
    local y = tdPosY(data)
    if isSpMenuOverlayText(text) or isSpMenuNumericText(text) then
        rememberMenuColumn(data)
        if id then blockedSpMenuTdIds[id] = true end
        return true
    end
    if isBlankButtonText(text) and x and isSpMenuColumnX(x)
            and not isLikelyVehicleGaugeText(text, x, y) then
        rememberMenuColumn(data)
        if id then blockedSpMenuTdIds[id] = true end
        return true
    end
    if x and isSpMenuColumnX(x) and not isVehicleHudColumnX(x) then
        rememberMenuColumn(data)
    end
    if tonumber(data.selectable) == 1 and x and isSpMenuColumnX(x) then
        if isLikelyVehicleGaugeText(text, x, y) then return false end
        if isSpMenuRowY(y) then
            if id then blockedSpMenuTdIds[id] = true end
            return true
        end
    end
    return false
end

function M.shouldBlockSpMenuClick(textdrawId)
    textdrawId = tonumber(textdrawId)
    return textdrawId ~= nil and blockedSpMenuTdIds[textdrawId] == true
end

function M.isServerSpMenuTextDraw(id, data, text)
    return isServerSpMenuTextDrawOnly(id, data, text)
end

function M.isServerSpMenuText(text)
    return isServerSpMenuText(text)
end

local function samMenuItemPlain(item)
    item = tostring(item or '')
    item = item:gsub('{[0-9A-Fa-f]+}', ''):gsub('~[^~]*~', '')
    return normalizeMenuText(item)
end

local function samMenuColumnsMatchSp(columns)
    if type(columns) ~= 'table' then return false end
    for _, col in ipairs(columns) do
        if type(col) == 'table' then
            for _, item in ipairs(col) do
                local plain = samMenuItemPlain(item)
                for _, m in ipairs(SP_MENU_MARKERS) do
                    if plain:find(m:lower(), 1, true) then return true end
                end
            end
        elseif type(col) == 'string' then
            local plain = samMenuItemPlain(col)
            for _, m in ipairs(SP_MENU_MARKERS) do
                if plain:find(m:lower(), 1, true) then return true end
            end
        end
    end
    return false
end

function M.isServerSpSamMenu(menuTitle, x, y, columns)
    local title = normalizeMenuText(menuTitle)
    for _, m in ipairs(SP_MENU_MARKERS) do
        if title:find(m:lower(), 1, true) then return true end
    end
    return samMenuColumnsMatchSp(columns)
end

function M.captureServerMenuLayout(x, y, columns, title)
    local menu = package.loaded['report_desk_spectate_menu']
    if menu and menu.applyServerLayout then
        pcall(menu.applyServerLayout, {
            x = tonumber(x),
            y = tonumber(y),
            columns = columns,
            title = title,
        })
    end
end

return M
