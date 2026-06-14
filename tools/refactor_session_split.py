#!/usr/bin/env python3
"""Split report_desk_spectate_session.lua: menu TD block + TD router."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SESSION = ROOT / 'lib' / 'report_desk_spectate_session.lua'

MENU_BLOCK = '''--[[ Модуль: блокировка серверного SP-меню (TextDraw). ]]
local M = {}

local vehicleHud = require 'report_desk_sp_vehicle_hud'

local session
local trimFn, getSettingsFn, cbEnsureTdHooks
local blockedSpMenuTdIds = {}

local SP_MENU_MARKERS = {
    'exit', 'mute', 'slap', 'stats', 'stat', 'update', 'tow', 'tr', 'skip',
    'weap', 'skick', 'info', 'freeze', 'dgun', 'kick', 'ban', 'jail', 'warn',
    '-exit-', 'exit-',
    '\\xE2\\xFB\\F5\\EE\\E4',
    '\\xEC\\xF3\\F2',
    '\\xF1\\xEB\\xFD\\xEF',
    '\\xF1\\F2\\xE0\\xF2',
    '\\xEE\\xE1\\xED\\EE\\E2',
    '\\xE0\\xEF\\E4\\xE5\\xE9\\F2',
    '\\xED\\xE0\\xF1\\xF2\\xF0',
    '\\xEC\\xE8\\xF0',
    '\\xE7\\xE0\\xEC\\xEE\\xF0',
    '\\xEE\\xF0\\xF3\\xE6',
    '\\xE2\\xEE\\xE4',
    '\\xF1\\xED\\xFF\\xF2',
    '\\xF1\\xEB\\xFD\\xEF\\xED',
    '\\xE4\\xEE\\xF1\\xF2\\xE0',
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
    if plain:find('\\xEA\\xEC/\\xF7', 1, true) then return true end
    if plain:find('\\xF2\\xEE\\xEF\\xEB\\xE8\\xE2\\xEE', 1, true) then return true end
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
    if not M.shouldSuppressServerSpMenu() then return end
    if not samMenuColumnsMatchSp(columns) and not M.isServerSpSamMenu(title, x, y, columns) then
        return
    end
    if session and x then session.menuColumnX = tonumber(x) or session.menuColumnX end
end

return M
'''

TD_ROUTER = '''--[[ Модуль: маршрутизация TextDraw (SP-меню vs HUD транспорта). ]]
local M = {}

local vehicleHud = require 'report_desk_sp_vehicle_hud'
local menuBlock

function M.configure(cfg)
    cfg = cfg or {}
    menuBlock = cfg.menuBlock
end

local function vehicleHudPipelineActive()
    local settings = cfg and cfg.getSettings and cfg.getSettings()
    if menuBlock and not menuBlock.shouldSuppressServerSpMenu() then
        -- keep vehicle pipeline when not suppressing menu
    end
    local getSettingsFn = rawget(_G, 'settings') and function() return settings end
    settings = settings or (type(getSettings) == 'function' and getSettings() or nil)
    if not vehicleHud.isEnabled(settings) then return false end
    if vehicleHud.isLocalInVehicle and vehicleHud.isLocalInVehicle() then return true end
    if not vehicleHud.isEnabledForSpectate(settings) then return false end
    return menuBlock and menuBlock.shouldSuppressServerSpMenu() or false
end

local function suppressSpMenuActive()
    if not menuBlock then return false end
    return menuBlock.shouldSuppressServerSpMenu()
end

local function handleVehicleTextDraw(id, data, text)
    if not vehicleHudPipelineActive() then return false end
    text = text or (data and data.text) or ''
    if menuBlock and menuBlock.isServerSpMenuText and menuBlock.isServerSpMenuText(text) then
        return false
    end
    if vehicleHud.isSportModeOverlayText and vehicleHud.isSportModeOverlayText(text, id) then
        if data then pcall(vehicleHud.ingest, id, data, text)
        else pcall(vehicleHud.ingestString, id, text) end
        return false
    end
    if data then pcall(vehicleHud.ingest, id, data, text)
    elseif text ~= '' then pcall(vehicleHud.ingestString, id, text) end
    return vehicleHud.shouldBlockServerTd(id, data, text)
end

function M.tdHooksNeeded()
    if menuBlock and menuBlock.shouldSuppressServerSpMenu() then return true end
    return vehicleHudPipelineActive()
end

function M.onShowTextDraw(id, data)
    if not data then return end
    if not vehicleHudPipelineActive() and not suppressSpMenuActive() then return end
    if handleVehicleTextDraw(id, data) then return false end
    if not suppressSpMenuActive() then return end
    if menuBlock and menuBlock.isServerSpMenuTextDraw(id, data, data.text) then return false end
end

function M.onTextDrawSetString(id, text)
    id = tonumber(id)
    if not id then return end
    if not suppressSpMenuActive() and not vehicleHudPipelineActive() then return end
    if menuBlock and menuBlock.isServerSpMenuTextDraw(id, nil, text) then return false end
    if handleVehicleTextDraw(id, nil, text) then return false end
end

return M
'''


def main() -> None:
    (ROOT / 'lib' / 'report_desk_sp_menu_td_block.lua').write_text(MENU_BLOCK, encoding='utf-8', newline='\n')
    print('wrote report_desk_sp_menu_td_block.lua')


if __name__ == '__main__':
    main()
