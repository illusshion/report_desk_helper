--[[ ID над головой у игроков в маске / тёмном нике (как AdminTools). ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

local MASK_LABEL_DRAW_DIST = 300
local MASK_LABEL_COLOR = 4294967295
local MASK_ID_TICK_INTERVAL = 0.4
local maskIdLastTickAt = 0
local maskIdWasActive = false
local MASK_LABEL_Z = 0.6
local MASK_COLORS = {
    [4278190335] = true,
    [2236962] = true,
}

local function maskIdNormColor(c)
    if type(normColor) == 'function' then
        return normColor(c)
    end
    c = tonumber(c) or 0
    if c < 0 then c = c + 4294967296 end
    return c
end

local function maskIdIsMaskedColor(color)
    color = maskIdNormColor(color)
    if MASK_COLORS[color] then return true end
    if not bit then return false end
    local rr = bit.band(bit.rshift(color, 16), 0xFF)
    local gg = bit.band(bit.rshift(color, 8), 0xFF)
    local bb = bit.band(color, 0xFF)
    return rr <= 40 and gg <= 40 and bb <= 40
end

local function maskIdEnabled()
    if type(settings) ~= 'table' or type(settings.cheats) ~= 'table' then return false end
    return settings.cheats.mask_player_id ~= false
end

local function maskIdActiveSession()
    if not sessionLive then return false end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return false end
    if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then return false end
    return true
end

local function maskIdPlayerExists(id)
    id = clampSuspectPlayerId and clampSuspectPlayerId(id) or tonumber(id)
    if not id or id < 0 then return false end
    if type(sampIsPlayerConnected) ~= 'function' or not sampIsPlayerConnected(id) then return false end
    if type(sampGetCharHandleBySampPlayerId) ~= 'function' or type(doesCharExist) ~= 'function' then return false end
    local ok, handle = sampGetCharHandleBySampPlayerId(id)
    return ok and handle and doesCharExist(handle)
end

local function maskIdGetLabelInfo(id)
    if type(sampIs3dTextDefined) ~= 'function' or not sampIs3dTextDefined(id) then return nil end
    if type(sampGet3dTextInfoById) ~= 'function' then return nil end
    local ok, text, color, x, y, z, distance, los, playerId, vehicleId = pcall(sampGet3dTextInfoById, id)
    if not ok then return nil end
    return {
        text = text,
        color = color,
        distance = tonumber(distance),
        playerId = tonumber(playerId),
        vehicleId = tonumber(vehicleId),
    }
end

local function maskIdIsOurLabel(id)
    local info = maskIdGetLabelInfo(id)
    if not info then return false end
    return info.distance == MASK_LABEL_DRAW_DIST and info.playerId == id
end

local function maskIdCreate(id)
    if type(sampCreate3dTextEx) ~= 'function' then return false end
    local text = tostring(id)
    pcall(sampCreate3dTextEx, id, text, MASK_LABEL_COLOR, 0, 0, MASK_LABEL_Z,
        MASK_LABEL_DRAW_DIST, true, id, -1)
    return true
end

local function maskIdEnsure(id)
    if not maskIdPlayerExists(id) then return end
    local info = maskIdGetLabelInfo(id)
    if info then
        if info.distance == MASK_LABEL_DRAW_DIST and info.playerId == id
            and tostring(info.text or '') == tostring(id) then
            return
        end
        if info.distance == MASK_LABEL_DRAW_DIST then
            maskIdCreate(id)
        end
        return
    end
    maskIdCreate(id)
end

local function maskIdDestroy(id)
    if type(sampDestroy3dText) ~= 'function' then return end
    if maskIdIsOurLabel(id) then
        pcall(sampDestroy3dText, id)
    end
end

local function maskIdDestroyAll()
    if type(sampIs3dTextDefined) ~= 'function' or type(sampDestroy3dText) ~= 'function' then return end
    for id = 0, 1000 do
        if maskIdIsOurLabel(id) then
            pcall(sampDestroy3dText, id)
        end
    end
end

local function maskIdPlayerColor(id)
    if type(sampGetPlayerColor) ~= 'function' then return nil end
    local ok, c = pcall(sampGetPlayerColor, id)
    if ok then return c end
    return nil
end

function maskIdTick()
    local active = maskIdEnabled() and maskIdActiveSession()
    if not active then
        if maskIdWasActive then
            maskIdDestroyAll()
        end
        maskIdWasActive = false
        maskIdLastTickAt = 0
        return
    end
    maskIdWasActive = true
    if type(sampGetMaxPlayerId) ~= 'function' or type(sampIsPlayerConnected) ~= 'function' then return end

    local now = os.clock()
    if now - maskIdLastTickAt < MASK_ID_TICK_INTERVAL then return end
    maskIdLastTickAt = now

    local maxId = tonumber(sampGetMaxPlayerId(true)) or 0
    if maxId < 0 then maxId = 0 end
    if maxId > 1000 then maxId = 1000 end

    for id = 0, maxId do
        if sampIsPlayerConnected(id) and maskIdPlayerExists(id) then
            local color = maskIdPlayerColor(id)
            if color and maskIdIsMaskedColor(color) then
                maskIdEnsure(id)
            elseif maskIdIsOurLabel(id) then
                maskIdDestroy(id)
            end
        elseif maskIdIsOurLabel(id) then
            maskIdDestroy(id)
        end
    end
end

function maskIdOnPlayerQuit(playerId)
    local id = clampSuspectPlayerId and clampSuspectPlayerId(playerId) or tonumber(playerId)
    if id then maskIdDestroy(id) end
end

function maskIdCleanup()
    maskIdWasActive = false
    maskIdDestroyAll()
end
