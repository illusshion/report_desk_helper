--[[ Модуль: хуки refresh SP (vehicle sync → stats/HUD). ]]
local spSessionMod -- spectate session (lazy require)
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

local vehicleHudMod
local function vehicleHud()
    if not vehicleHudMod then
        vehicleHudMod = require 'report_desk_sp_vehicle_hud'
    end
    return vehicleHudMod
end

-- Быстрый фильтр: refresh-хуки только для текущей цели spectate.
local function spRefreshWatchTargetId()
    if type(deskSpectateStats) == 'table' and deskSpectateStats.getTargetId then
        local ok, v = pcall(deskSpectateStats.getTargetId)
        if ok then
            local tid = tonumber(v)
            if tid and tid >= 0 then return tid end
        end
    end
    return -1
end

local function spRefreshTargetMatches(playerId)
    playerId = tonumber(playerId)
    if not playerId then return false end
    local tid = spRefreshWatchTargetId()
    return tid >= 0 and playerId == tid
end

local function spRefreshWatchActive()
    return spRefreshWatchTargetId() >= 0
end

function installDeskSpRefreshHooks()
    if not sampev then return end
    local enterOk = deskCache.spEnterHandler and sampev.onPlayerEnterVehicle == deskCache.spEnterHandler
    local exitOk = deskCache.spExitHandler and sampev.onPlayerExitVehicle == deskCache.spExitHandler
    local interiorOk = deskCache.spInteriorHandler and sampev.onSetInterior == deskCache.spInteriorHandler
    local vehicleOk = deskCache.spVehicleSyncHandler and sampev.onVehicleSync == deskCache.spVehicleSyncHandler
    local passengerOk = deskCache.spPassengerSyncHandler and sampev.onPassengerSync == deskCache.spPassengerSyncHandler
    local playerOk = deskCache.spPlayerSyncHandler and sampev.onPlayerSync == deskCache.spPlayerSyncHandler
    local vehParamsOk = deskCache.spVehParamsHandler
        and sampev.onSetVehicleParamsEx == deskCache.spVehParamsHandler
    local vehParamsPlayerOk = deskCache.spVehParamsPlayerHandler
        and sampev.onSetVehicleParams == deskCache.spVehParamsPlayerHandler
    if enterOk and exitOk and interiorOk and vehicleOk and passengerOk and playerOk
            and vehParamsOk and vehParamsPlayerOk then
        return
    end

    if not enterOk then
        local prevEnter = sampev.onPlayerEnterVehicle
        if prevEnter == deskCache.spEnterHandler then prevEnter = deskCache.hookPrevSpEnter end
        deskCache.hookPrevSpEnter = prevEnter
        deskCache.spEnterHandler = function(playerId, vehicleId, passenger)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshEnterVehicle then
                pcall(deskSpectateStats.onSpRefreshEnterVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevEnter, playerId, vehicleId, passenger)
        end
        sampev.onPlayerEnterVehicle = deskCache.spEnterHandler
    end

    if not exitOk then
        local prevExit = sampev.onPlayerExitVehicle
        if prevExit == deskCache.spExitHandler then prevExit = deskCache.hookPrevSpExit end
        deskCache.hookPrevSpExit = prevExit
        deskCache.spExitHandler = function(playerId, vehicleId)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshExitVehicle then
                pcall(deskSpectateStats.onSpRefreshExitVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevExit, playerId, vehicleId)
        end
        sampev.onPlayerExitVehicle = deskCache.spExitHandler
    end

    if not interiorOk then
        local prevInterior = sampev.onSetInterior
        if prevInterior == deskCache.spInteriorHandler then prevInterior = deskCache.hookPrevSpInterior end
        deskCache.hookPrevSpInterior = prevInterior
        deskCache.spInteriorHandler = function(interior)
            if spRefreshWatchActive() and deskSpectateStats and deskSpectateStats.onSpRefreshSetInterior then
                pcall(deskSpectateStats.onSpRefreshSetInterior, interior)
            end
            return deskCallHookPrev(prevInterior, interior)
        end
        sampev.onSetInterior = deskCache.spInteriorHandler
    end

    if not vehicleOk then
        local prevVehicle = sampev.onVehicleSync
        if prevVehicle == deskCache.spVehicleSyncHandler then prevVehicle = deskCache.hookPrevSpVehicleSync end
        deskCache.hookPrevSpVehicleSync = prevVehicle
        deskCache.spVehicleSyncHandler = function(playerId, vehicleId, data)
            local vh = vehicleHud()
            if vh and vh.onVehicleSync then
                pcall(vh.onVehicleSync, playerId, vehicleId, data)
            end
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshVehicleSync then
                pcall(deskSpectateStats.onSpRefreshVehicleSync, playerId)
            end
            return deskCallHookPrev(prevVehicle, playerId, vehicleId, data)
        end
        sampev.onVehicleSync = deskCache.spVehicleSyncHandler
    end

    if not passengerOk then
        local prevPassenger = sampev.onPassengerSync
        if prevPassenger == deskCache.spPassengerSyncHandler then prevPassenger = deskCache.hookPrevSpPassengerSync end
        deskCache.hookPrevSpPassengerSync = prevPassenger
        deskCache.spPassengerSyncHandler = function(playerId, vehicleId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshPassengerSync then
                pcall(deskSpectateStats.onSpRefreshPassengerSync, playerId)
            end
            return deskCallHookPrev(prevPassenger, playerId, vehicleId, data)
        end
        sampev.onPassengerSync = deskCache.spPassengerSyncHandler
    end

    if not playerOk then
        local prevPlayer = sampev.onPlayerSync
        if prevPlayer == deskCache.spPlayerSyncHandler then prevPlayer = deskCache.hookPrevSpPlayerSync end
        deskCache.hookPrevSpPlayerSync = prevPlayer
        deskCache.spPlayerSyncHandler = function(playerId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshPlayerSync then
                pcall(deskSpectateStats.onSpRefreshPlayerSync, playerId)
            end
            return deskCallHookPrev(prevPlayer, playerId, data)
        end
        sampev.onPlayerSync = deskCache.spPlayerSyncHandler
    end

    if not vehParamsOk and sampev.onSetVehicleParamsEx ~= nil then
        local prevVehParams = sampev.onSetVehicleParamsEx
        if prevVehParams == deskCache.spVehParamsHandler then prevVehParams = deskCache.hookPrevSpVehParams end
        deskCache.hookPrevSpVehParams = prevVehParams
        deskCache.spVehParamsHandler = function(vehicleId, params, doors, windows)
            local vh = vehicleHud()
            if vh and vh.onSetVehicleParamsEx then
                pcall(vh.onSetVehicleParamsEx, vehicleId, params, doors, windows)
            end
            return deskCallHookPrev(prevVehParams, vehicleId, params, doors, windows)
        end
        sampev.onSetVehicleParamsEx = deskCache.spVehParamsHandler
    end

    if not vehParamsPlayerOk and sampev.onSetVehicleParams ~= nil then
        local prev = sampev.onSetVehicleParams
        if prev == deskCache.spVehParamsPlayerHandler then prev = deskCache.hookPrevSpVehParamsPlayer end
        deskCache.hookPrevSpVehParamsPlayer = prev
        deskCache.spVehParamsPlayerHandler = function(vehicleId, objective, doorsLocked)
            local vh = vehicleHud()
            if vh and vh.onSetVehicleParams then
                pcall(vh.onSetVehicleParams, vehicleId, objective, doorsLocked)
            end
            return deskCallHookPrev(deskCache.hookPrevSpVehParamsPlayer, vehicleId, objective, doorsLocked)
        end
        sampev.onSetVehicleParams = deskCache.spVehParamsPlayerHandler
    end
end
