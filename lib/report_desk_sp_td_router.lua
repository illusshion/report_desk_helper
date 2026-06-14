--[[ Модуль: маршрутизация TextDraw — SP-меню vs HUD транспорта. ]]
local M = {}

local vehicleHud = require 'report_desk_sp_vehicle_hud'

local menuBlock
local getSettingsFn

function M.configure(cfg)
    cfg = cfg or {}
    menuBlock = cfg.menuBlock
    getSettingsFn = cfg.getSettings
end

local function vehicleHudPipelineActive()
    local settings = getSettingsFn and getSettingsFn()
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
    if menuBlock and menuBlock.isServerSpMenuText(text) then return false end
    if vehicleHud.isSportModeOverlayText and vehicleHud.isSportModeOverlayText(text, id) then
        if data then pcall(vehicleHud.ingest, id, data, text)
        else pcall(vehicleHud.ingestString, id, text) end
        return false
    end
    if data then
        pcall(vehicleHud.ingest, id, data, text)
    elseif text ~= '' then
        pcall(vehicleHud.ingestString, id, text)
    end
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
