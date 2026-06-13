--[[ Авто /sp при смене mobility/interior цели.
     Snapshot + refreshGeneration; interiorCommitted блокирует повтор interior /sp.
     Тихий /sp без markPendingSp. ]]
local M = {}

local COOLDOWN_SEC = 3.0
local ENTRY_GRACE_SEC = 10.0
local REFRESH_IN_FLIGHT_SEC = 4.5
local AUTO_ST_SKIP_SEC = 2.5
local RPC_MOBILITY_TTL = 1.2
local SYNC_MOBILITY_TTL = 3.0
local VEHICLE_ENTER_SYNC_MAX = 1.8
local PENDING_GIVEUP_SEC = 6.0
local RPC_ORDER_SLACK = 0.05

local deps = {}

local ctx = {
    seeded = false,
    mobility = nil,
    interior = 0,
    interiorCommitted = nil,
    appliedInterior = nil,
    spectateMode = nil,
    lastRefreshAt = 0,
    autoRefreshAt = 0,
    refreshGeneration = 0,
    confirmedGeneration = 0,
    rpcMobility = nil,
    rpcMobilityAt = 0,
    lastVehicleSyncAt = 0,
    lastPlayerSyncAt = 0,
    pending = nil,
    entryConfirmedAt = 0,
    refreshInFlightUntil = 0,
}

local function getTargetId()
    if deps.getTargetId then
        return tonumber(deps.getTargetId()) or -1
    end
    return -1
end

local function autoRefreshEnabled()
    if deps.getSettings then
        local s = deps.getSettings()
        if s and s.spectate_auto_refresh == false then return false end
    end
    return true
end

local function watchingTarget()
    if deps.isSpectating and not deps.isSpectating() then return false end
    if deps.sessionActive and not deps.sessionActive() then return false end
    return getTargetId() >= 0
end

local function readLocalInterior()
    if deps.getLocalInterior then
        local ok, v = pcall(deps.getLocalInterior)
        if ok and v ~= nil then return tonumber(v) or 0 end
    end
    return nil
end

local function readTargetPed()
    if not deps.getTargetPed then return nil end
    local ok, ped = pcall(deps.getTargetPed)
    if ok and ped then return ped end
    return nil
end

local function vehicleSyncRecent(maxAge)
    maxAge = tonumber(maxAge) or VEHICLE_ENTER_SYNC_MAX
    local at = tonumber(ctx.lastVehicleSyncAt) or 0
    return at > 0 and (os.clock() - at) < maxAge
end

local function readMobility()
    local now = os.clock()
    if ctx.rpcMobility and (now - (ctx.rpcMobilityAt or 0)) < RPC_MOBILITY_TTL then
        return ctx.rpcMobility
    end
    local vAt = tonumber(ctx.lastVehicleSyncAt) or 0
    local pAt = tonumber(ctx.lastPlayerSyncAt) or 0
    if vAt > 0 and vAt >= pAt and (now - vAt) < SYNC_MOBILITY_TTL then
        return 'vehicle'
    end
    if pAt > 0 and (now - pAt) < SYNC_MOBILITY_TTL then
        return 'onfoot'
    end
    return ctx.mobility
end

local function syncSnapshotFromServerMode()
    if ctx.spectateMode == 'vehicle' then
        ctx.mobility = 'vehicle'
    elseif ctx.spectateMode == 'player' then
        ctx.mobility = 'onfoot'
    end
    if ctx.appliedInterior ~= nil then
        ctx.interior = ctx.appliedInterior
    end
end

function M.getAutoRefreshAt()
    return ctx.autoRefreshAt or 0
end

function M.shouldSkipAutoSt(id)
    id = tonumber(id)
    local at = tonumber(ctx.autoRefreshAt) or 0
    if at <= 0 or not id or id < 0 then return false end
    if os.clock() - at > AUTO_ST_SKIP_SEC then return false end
    local cur = getTargetId()
    return cur < 0 or cur == id
end

function M.resetContext()
    ctx.seeded = false
    ctx.mobility = nil
    ctx.interior = 0
    ctx.interiorCommitted = nil
    ctx.appliedInterior = nil
    ctx.spectateMode = nil
    ctx.rpcMobility = nil
    ctx.rpcMobilityAt = 0
    ctx.lastVehicleSyncAt = 0
    ctx.lastPlayerSyncAt = 0
    ctx.pending = nil
    ctx.confirmedGeneration = 0
    ctx.entryConfirmedAt = 0
    ctx.refreshInFlightUntil = 0
end

local function captureBaseline()
    ctx.mobility = readMobility() or 'onfoot'
    local interior = tonumber(ctx.appliedInterior)
    if interior == nil then
        interior = readLocalInterior()
    end
    if interior ~= nil then
        ctx.interior = interior
        ctx.interiorCommitted = interior
    end
    ctx.seeded = true
end

function M.isRefreshInFlight()
    local untilAt = ctx.refreshInFlightUntil or 0
    return os.clock() < untilAt
end

function M.onTargetConfirmed(id, opts)
    opts = opts or {}
    id = tonumber(id)
    if not id or id < 0 then return end
    if opts.fullBaseline == true or not ctx.seeded then
        captureBaseline()
    else
        syncSnapshotFromServerMode()
        ctx.confirmedGeneration = ctx.refreshGeneration
    end
    ctx.rpcMobility = nil
    ctx.rpcMobilityAt = 0
    ctx.pending = nil
    ctx.entryConfirmedAt = os.clock()
    ctx.refreshInFlightUntil = 0
end

function M.onServerSpectatePlayer(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.spectateMode = 'player'
    if ctx.seeded then
        ctx.mobility = 'onfoot'
    end
    if ctx.pending and ctx.pending.mobility == 'onfoot' then
        ctx.pending = nil
    end
    ctx.refreshInFlightUntil = 0
end

function M.onServerSpectateVehicle(vehicleId)
    vehicleId = tonumber(vehicleId)
    if not vehicleId or vehicleId < 0 then return end
    ctx.spectateMode = 'vehicle'
    if ctx.seeded then
        ctx.mobility = 'vehicle'
    end
    ctx.pending = nil
    ctx.refreshInFlightUntil = 0
end

local function markAutoRefreshSent()
    local now = os.clock()
    ctx.autoRefreshAt = now
    ctx.refreshGeneration = (tonumber(ctx.refreshGeneration) or 0) + 1
    local cache = rawget(_G, 'deskCache')
    if type(cache) == 'table' then
        cache.spAutoRefreshAt = now
    end
end

local function sendSpRefresh(id)
    id = tonumber(id)
    if not id or id < 0 then return false end
    local cmd = 'sp ' .. tostring(id)
    local ok = false
    if deps.sendMenuOutbound then
        ok = pcall(deps.sendMenuOutbound, cmd, { quietSp = true }) ~= false
    elseif deps.sendChat then
        local cache = rawget(_G, 'deskCache')
        if type(cache) == 'table' then
            cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
        end
        ok = pcall(deps.sendChat, '/sp ' .. tostring(id)) ~= false
        if type(cache) == 'table' then
            local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
            cache.skipSpHookLocal = n > 0 and n or nil
        end
    end
    if ok then
        markAutoRefreshSent()
        ctx.refreshInFlightUntil = os.clock() + REFRESH_IN_FLIGHT_SEC
    end
    return ok
end

local function serverModeMatches(mobility)
    if mobility == 'vehicle' then return ctx.spectateMode == 'vehicle' end
    if mobility == 'onfoot' then return ctx.spectateMode == 'player' end
    return false
end

local function tryRefresh(reason)
    local id = getTargetId()
    if not id or id < 0 then return false end
    if not autoRefreshEnabled() then return false end
    if not watchingTarget() then return false end
    if deps.hasPendingSp and deps.hasPendingSp() then return false end
    if deps.isHandshaking and deps.isHandshaking() then return false end
    if deps.hasOutboundPending and deps.hasOutboundPending() then return false end
    if not ctx.seeded then return false end
    if not ctx.spectateMode then return false end
    local now = os.clock()
    if ctx.entryConfirmedAt and (now - ctx.entryConfirmedAt) < ENTRY_GRACE_SEC then return false end
    if M.isRefreshInFlight() then return false end
    if now - (ctx.lastRefreshAt or 0) < COOLDOWN_SEC then return false end
    if not sendSpRefresh(id) then return false end
    ctx.lastRefreshAt = now
    ctx.rpcMobility = nil
    ctx.rpcMobilityAt = 0
    return true
end

local function commitSnapshot(mobility, interior)
    if mobility then ctx.mobility = mobility end
    if interior ~= nil then
        ctx.interior = interior
        ctx.appliedInterior = interior
        ctx.interiorCommitted = interior
    end
end

local function applyChange(mobility, interior, reason)
    if not ctx.seeded then
        commitSnapshot(mobility, interior)
        return true
    end

    local mobChanged = mobility and ctx.mobility and mobility ~= ctx.mobility
    local intChanged = interior ~= nil and ctx.interior ~= interior
    if not mobChanged and not intChanged then return true end

    if mobChanged and serverModeMatches(mobility) then
        commitSnapshot(mobility, nil)
        mobChanged = false
    end
    if not mobChanged and not intChanged then return true end

    if tryRefresh(reason) then
        commitSnapshot(mobility, interior)
        return true
    end
    return false
end

local function schedulePending(mobility, interior, reason, delay)
    local now = os.clock()
    if ctx.pending and ctx.pending.reason == reason
            and ctx.pending.mobility == mobility
            and ctx.pending.interior == interior then
        return
    end
    ctx.pending = {
        mobility = mobility,
        interior = interior,
        reason = reason or 'pending',
        at = now + (tonumber(delay) or 0),
        createdAt = now,
    }
end

local function vehicleEnterReady()
    if vehicleSyncRecent(VEHICLE_ENTER_SYNC_MAX) then return true end
    local ped = readTargetPed()
    if ped and isCharInAnyCar and isCharInAnyCar(ped) then return true end
    return false
end

local function giveUpPending(p)
    ctx.pending = nil
end

local function flushPending()
    local p = ctx.pending
    if not p then return end
    if os.clock() < (p.at or 0) then return end
    if not watchingTarget() or not ctx.seeded then
        ctx.pending = nil
        return
    end
    if p.createdAt and (os.clock() - p.createdAt) >= PENDING_GIVEUP_SEC then
        giveUpPending(p)
        return
    end
    if p.mobility == 'vehicle' and not vehicleEnterReady() then
        return
    end
    if applyChange(p.mobility, p.interior, p.reason) then
        ctx.pending = nil
        return
    end
    p.at = os.clock() + COOLDOWN_SEC
end

function M.onTargetEnterVehicle(playerId, vehicleId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    local now = os.clock()
    ctx.rpcMobility = 'vehicle'
    ctx.rpcMobilityAt = now
    if not ctx.seeded then
        ctx.mobility = 'vehicle'
        return
    end
    if ctx.mobility == 'vehicle' and ctx.spectateMode == 'vehicle' then return end
    schedulePending('vehicle', nil, 'rpc_enter_vehicle', RPC_ORDER_SLACK)
    flushPending()
end

function M.onTargetExitVehicle(playerId, vehicleId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    local now = os.clock()
    ctx.rpcMobility = 'onfoot'
    ctx.rpcMobilityAt = now
    ctx.lastPlayerSyncAt = now
    ctx.lastVehicleSyncAt = 0
    if not ctx.seeded then
        ctx.mobility = 'onfoot'
        return
    end
    if ctx.mobility == 'onfoot' and ctx.spectateMode == 'player' then return end
    schedulePending('onfoot', nil, 'rpc_exit_vehicle', RPC_ORDER_SLACK)
    flushPending()
end

function M.onLocalSetInterior(interior)
    interior = tonumber(interior)
    if interior == nil then return end
    ctx.appliedInterior = interior
    if not ctx.seeded then
        ctx.interior = interior
        ctx.interiorCommitted = interior
        return
    end
    if ctx.interiorCommitted == interior then
        ctx.interior = interior
        return
    end
    if ctx.interior == interior then return end
    if ctx.pending and ctx.pending.mobility then return end
    schedulePending(nil, interior, 'rpc_set_interior', RPC_ORDER_SLACK)
    flushPending()
end

function M.onTargetVehicleSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastVehicleSyncAt = os.clock()
    if ctx.pending then flushPending() end
end

function M.onTargetPassengerSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastVehicleSyncAt = os.clock()
    if ctx.pending then flushPending() end
end

function M.onTargetPlayerSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastPlayerSyncAt = os.clock()
    if ctx.pending and ctx.pending.mobility == 'onfoot' then
        flushPending()
    end
end

function M.onTargetStreamIn(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    if ctx.pending and ctx.pending.mobility == 'vehicle' then
        flushPending()
    end
end

function M.needsTick()
    if not watchingTarget() then return false end
    local p = ctx.pending
    if not p then return false end
    return os.clock() >= (p.at or 0)
end

function M.tick()
    if not M.needsTick() then return end
    flushPending()
end

function M.configure(cfg)
    deps = cfg or deps or {}
end

return M
