#!/usr/bin/env python3
"""Apply /sp audit fixes to Report Desk lib modules."""
from pathlib import Path

ROOT = Path(r'c:\Program Files (x86)\Advance Games\moonloader\lib')


def patch_stats(text: str) -> str:
    text = text.replace(
        "M.forceExitSpectate({ reason = 'orphan', sendServer = false })",
        "M.forceExitSpectate({ reason = 'orphan', sendServer = true })",
        1,
    )

    old_block = """function M.shouldBlockSpectateOff()
    if state.pendingSpId then return true end
    if expectSpectateOff then return false end
    if specSession.isActive and specSession.isActive() then return true end
    local outboundAt = tonumber(state.lastSpOutboundAt) or 0
    if outboundAt > 0 and (os.clock() - outboundAt) < (PENDING_SP_SEC + 2.0) then
        return true
    end
    return false
end"""

    new_block = """function M.shouldBlockSpectateOff()
    if expectSpectateOff then return false end
    if state.pendingSpId then return true end
    if specSession.isAwaitingSpectate and specSession.isAwaitingSpectate() then return true end
    local outboundAt = tonumber(state.lastSpOutboundAt) or 0
    if outboundAt > 0 and (os.clock() - outboundAt) < (PENDING_SP_SEC + 2.0) then
        return true
    end
    return false
end"""
    if old_block not in text:
        raise RuntimeError('shouldBlockSpectateOff block not found')
    text = text.replace(old_block, new_block, 1)

    text = text.replace(
        'local MAX_SPEC_PLAYER_ID = 1000\nlocal lastSpecStepAt = 0',
        'local MAX_SPEC_PLAYER_ID = 1000\n'
        'local STEP_CONNECTED_CACHE_TTL = 0.5\n'
        'local stepConnectedCache = nil\n'
        'local stepConnectedCacheAt = 0\n'
        'local lastSpecStepAt = 0',
        1,
    )

    old_find = """function M.findAdjacentSpectateId(curId, delta)
    curId = tonumber(curId)
    if curId == nil then return nil end
    delta = (tonumber(delta) or 0) >= 0 and 1 or -1
    -- AdminTools: +1/-1 with wrap 0..1000 until connected (not sampGetMaxPlayerId cap).
    local maxScan = MAX_SPEC_PLAYER_ID
    local id = curId
    for _ = 1, maxScan + 1 do
        id = id + delta
        if id > maxScan then
            id = 0
        elseif id < 0 then
            id = maxScan
        end
        if isSpectateStepCandidate(id) then
            return id
        end
    end
    return nil
end"""

    new_find = """local function invalidateStepConnectedCache()
    stepConnectedCache = nil
    stepConnectedCacheAt = 0
end

local function buildStepConnectedCache()
    local now = os.clock()
    if stepConnectedCache and (now - stepConnectedCacheAt) < STEP_CONNECTED_CACHE_TTL then
        return stepConnectedCache
    end
    local ids = {}
    local maxId = M.getMaxPlayerId()
    for i = 0, maxId do
        if isSpectateStepCandidate(i) then
            ids[#ids + 1] = i
        end
    end
    table.sort(ids)
    stepConnectedCache = ids
    stepConnectedCacheAt = now
    return ids
end

function M.findAdjacentSpectateId(curId, delta)
    curId = tonumber(curId)
    if curId == nil then return nil end
    delta = (tonumber(delta) or 0) >= 0 and 1 or -1
    local ids = buildStepConnectedCache()
    if #ids == 0 then return nil end
    if delta > 0 then
        for _, id in ipairs(ids) do
            if id > curId then return id end
        end
        return ids[1]
    end
    for i = #ids, 1, -1 do
        if ids[i] < curId then return ids[i] end
    end
    return ids[#ids]
end"""
    if old_find not in text:
        raise RuntimeError('findAdjacentSpectateId block not found')
    text = text.replace(old_find, new_find, 1)

    text = text.replace(
        '    lastSpecStepAt = now\n'
        '    state.pendingSpStepDelta = delta\n'
        '    return sendSpectateStepCommand(nextId)',
        '    lastSpecStepAt = now\n'
        '    invalidateStepConnectedCache()\n'
        '    state.pendingSpStepDelta = delta\n'
        '    return sendSpectateStepCommand(nextId)',
        1,
    )

    watch_set = (
        '    local cache = rawget(_G, \'deskCache\')\n'
        '    if type(cache) == \'table\' then\n'
        '        cache.spWatchTargetId = id\n'
        '    end'
    )
    if 'cache.spWatchTargetId = id' not in text:
        text = text.replace(
            "    state.targetId = id\n    state.targetNick = trim(nick or '')",
            "    state.targetId = id\n    state.targetNick = trim(nick or '')\n" + watch_set,
            1,
        )

    clear_watch = (
        '    local cache = rawget(_G, \'deskCache\')\n'
        '    if type(cache) == \'table\' then\n'
        '        cache.spWatchTargetId = -1\n'
        '    end'
    )
    if 'cache.spWatchTargetId = -1' not in text:
        text = text.replace(
            "    state.targetId = -1\n    state.targetNick = ''\n    state.persistHudId = -1",
            "    state.targetId = -1\n    state.targetNick = ''\n    state.persistHudId = -1\n" + clear_watch,
            1,
        )

    return text


def patch_session(text: str) -> str:
    if 'local SUPPRESS_MENU_CACHE_TTL' not in text:
        text = text.replace(
            'local BEGIN_SESSION_DEDUPE_SEC = 0.6\n',
            'local BEGIN_SESSION_DEDUPE_SEC = 0.6\n'
            'local SUPPRESS_MENU_CACHE_TTL = 0.05\n'
            'local suppressMenuCached = false\n'
            'local suppressMenuCachedAt = 0\n'
            'local vehicleHudPipelineCached = false\n'
            'local vehicleHudPipelineCachedAt = 0\n',
            1,
        )

    insert_after = """local function clearMenuColumnState()
    session.menuColumnX = nil
end
"""
    cache_helpers = """
-- Cached shouldSuppressServerSpMenu / vehicleHudPipelineActive for TD hot path.
local function suppressSpMenuActive()
    local now = os.clock()
    if now - suppressMenuCachedAt < SUPPRESS_MENU_CACHE_TTL then
        return suppressMenuCached
    end
    suppressMenuCached = M.shouldSuppressServerSpMenu()
    suppressMenuCachedAt = now
    return suppressMenuCached
end

local function vehicleHudPipelineActiveCached()
    local now = os.clock()
    if now - vehicleHudPipelineCachedAt < SUPPRESS_MENU_CACHE_TTL then
        return vehicleHudPipelineCached
    end
    vehicleHudPipelineCached = vehicleHudPipelineActive()
    vehicleHudPipelineCachedAt = now
    return vehicleHudPipelineCached
end

local function invalidateSuppressCache()
    suppressMenuCachedAt = 0
    vehicleHudPipelineCachedAt = 0
end
"""
    if 'function suppressSpMenuActive()' not in text:
        text = text.replace(insert_after, insert_after + cache_helpers, 1)

    old_show = """function M.onShowTextDraw(id, data)
    if handleVehicleTextDraw(id, data) then return false end
    if not M.shouldSuppressServerSpMenu() then return end
    if isServerSpMenuTextDrawOnly(id, data, data and data.text) then return false end
end"""

    new_show = """function M.onShowTextDraw(id, data)
    if not data then return end
    if vehicleHudPipelineActiveCached() and handleVehicleTextDraw(id, data) then return false end
    if not suppressSpMenuActive() then return end
    local x = tdPosX(data)
    local tdText = data.text
    if x and x < SP_MENU_COLUMN_LEFT_X and not isServerSpMenuText(tdText) then return end
    if isServerSpMenuTextDrawOnly(id, data, tdText) then return false end
end"""
    if old_show in text:
        text = text.replace(old_show, new_show, 1)

    old_set = """function M.onTextDrawSetString(id, text)
    if vehicleHudPipelineActive() and vehicleHud.ingestString(id, text) then
        return false
    end
    if handleVehicleTextDraw(id, nil, text) then return false end
    if not M.shouldSuppressServerSpMenu() then return end
    if isServerSpMenuTextDrawOnly(id, nil, text) then return false end
end"""
    new_set = """function M.onTextDrawSetString(id, text)
    if vehicleHudPipelineActiveCached() and vehicleHud.ingestString(id, text) then
        return false
    end
    if vehicleHudPipelineActiveCached() and handleVehicleTextDraw(id, nil, text) then return false end
    if not suppressSpMenuActive() then return end
    if isServerSpMenuTextDrawOnly(id, nil, text) then return false end
end"""
    if old_set in text:
        text = text.replace(old_set, new_set, 1)

    for fn in ('M.markAwaitingSpectate', 'M.beginSession', 'M.endSession'):
        pass  # invalidate via markAwaitingSpectate patch below

    old_mark = """function M.markAwaitingSpectate(on)
    session.awaitingSpectate = on and true or false
end"""
    new_mark = """function M.markAwaitingSpectate(on)
    session.awaitingSpectate = on and true or false
    invalidateSuppressCache()
end"""
    if old_mark in text:
        text = text.replace(old_mark, new_mark, 1)

    text = text.replace(
        '    session.targetNick = nick\n    if changed then',
        '    session.targetNick = nick\n    invalidateSuppressCache()\n    if changed then',
        1,
    )
    text = text.replace(
        '    session.targetId = -1\n    session.targetNick = \'\'\n    session.menuWantsCursor = false',
        '    session.targetId = -1\n    session.targetNick = \'\'\n    invalidateSuppressCache()\n    session.menuWantsCursor = false',
        1,
    )

    return text


def patch_input(text: str) -> str:
    old = """function sendGameCmd(cmd)
    cmd = trim(cmd or '')
    local stId = cmd:match('^st%s+(%d+)$')
    if stId then
        deskSpectateStats.markPendingSt(tonumber(stId))
    end
    local spId = cmd:match('^sp%s+(%d+)%s*$')
    if spId and deskSpectateStats.markPendingSpCommand then
        deskSpectateStats.markPendingSpCommand(tonumber(spId), '')
    end
    releaseDeskInputCapture(true)
    closeDeskWindow()
    sendChat(cmd)
end"""
    new = """function sendGameCmd(cmd)
    cmd = trim(cmd or '')
    local stId = cmd:match('^st%s+(%d+)$')
    if stId then
        deskSpectateStats.markPendingSt(tonumber(stId))
    end
    releaseDeskInputCapture(true)
    closeDeskWindow()
    if sendMenuOutbound then
        sendMenuOutbound(cmd)
    else
        local spId = cmd:match('^sp%s+(%d+)%s*$')
        if spId and deskSpectateStats.markPendingSpCommand then
            deskSpectateStats.markPendingSpCommand(tonumber(spId), '')
        end
        sendChat(cmd)
    end
end"""
    if old not in text:
        raise RuntimeError('sendGameCmd block not found')
    return text.replace(old, new, 1)


def patch_hooks(text: str) -> str:
    helper = """
-- Fast filter: sp refresh hooks only for current spectate target.
local function spRefreshTargetMatches(playerId)
    local cache = deskCache
    if type(cache) ~= 'table' then return false end
    local tid = tonumber(cache.spWatchTargetId)
    return tid ~= nil and tid >= 0 and playerId == tid
end
"""
    if 'function spRefreshTargetMatches' not in text:
        anchor = '-- /sp auto-refresh: RPC enter/exit/interior + sync + onSpectatePlayer/Vehicle.'
        text = text.replace(anchor, helper + anchor, 1)

    replacements = [
        (
            """        deskCache.spEnterHandler = function(playerId, vehicleId, passenger)
            if deskSpectateStats and deskSpectateStats.onSpRefreshEnterVehicle then
                pcall(deskSpectateStats.onSpRefreshEnterVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevEnter, playerId, vehicleId, passenger)
        end""",
            """        deskCache.spEnterHandler = function(playerId, vehicleId, passenger)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshEnterVehicle then
                pcall(deskSpectateStats.onSpRefreshEnterVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevEnter, playerId, vehicleId, passenger)
        end""",
        ),
        (
            """        deskCache.spExitHandler = function(playerId, vehicleId)
            if deskSpectateStats and deskSpectateStats.onSpRefreshExitVehicle then
                pcall(deskSpectateStats.onSpRefreshExitVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevExit, playerId, vehicleId)
        end""",
            """        deskCache.spExitHandler = function(playerId, vehicleId)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshExitVehicle then
                pcall(deskSpectateStats.onSpRefreshExitVehicle, playerId, vehicleId)
            end
            return deskCallHookPrev(prevExit, playerId, vehicleId)
        end""",
        ),
        (
            """        deskCache.spVehicleSyncHandler = function(playerId, vehicleId, data)
            if deskSpectateStats and deskSpectateStats.onSpRefreshVehicleSync then
                pcall(deskSpectateStats.onSpRefreshVehicleSync, playerId)
            end
            return deskCallHookPrev(prevVehicle, playerId, vehicleId, data)
        end""",
            """        deskCache.spVehicleSyncHandler = function(playerId, vehicleId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshVehicleSync then
                pcall(deskSpectateStats.onSpRefreshVehicleSync, playerId)
            end
            return deskCallHookPrev(prevVehicle, playerId, vehicleId, data)
        end""",
        ),
        (
            """        deskCache.spPassengerSyncHandler = function(playerId, vehicleId, data)
            if deskSpectateStats and deskSpectateStats.onSpRefreshPassengerSync then
                pcall(deskSpectateStats.onSpRefreshPassengerSync, playerId)
            end
            return deskCallHookPrev(prevPassenger, playerId, vehicleId, data)
        end""",
            """        deskCache.spPassengerSyncHandler = function(playerId, vehicleId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshPassengerSync then
                pcall(deskSpectateStats.onSpRefreshPassengerSync, playerId)
            end
            return deskCallHookPrev(prevPassenger, playerId, vehicleId, data)
        end""",
        ),
        (
            """        deskCache.spPlayerSyncHandler = function(playerId, data)
            if deskSpectateStats and deskSpectateStats.onSpRefreshPlayerSync then
                pcall(deskSpectateStats.onSpRefreshPlayerSync, playerId)
            end
            return deskCallHookPrev(prevPlayer, playerId, data)
        end""",
            """        deskCache.spPlayerSyncHandler = function(playerId, data)
            if spRefreshTargetMatches(playerId) and deskSpectateStats and deskSpectateStats.onSpRefreshPlayerSync then
                pcall(deskSpectateStats.onSpRefreshPlayerSync, playerId)
            end
            return deskCallHookPrev(prevPlayer, playerId, data)
        end""",
        ),
    ]
    for old, new in replacements:
        if old not in text:
            raise RuntimeError('hooks block not found')
        text = text.replace(old, new, 1)

    old_rpc = """    local handler = function(rpcId, bs)
        if rpcId ~= RPC_INIT_MENU and rpcId ~= RPC_SHOW_MENU and rpcId ~= RPC_HIDE_MENU then
            return
        end"""
    new_rpc = """    local handler = function(rpcId, bs)
        if rpcId ~= RPC_INIT_MENU and rpcId ~= RPC_SHOW_MENU and rpcId ~= RPC_HIDE_MENU then
            return true
        end"""
    if old_rpc in text:
        text = text.replace(old_rpc, new_rpc, 1)

    return text


def patch_refresh(text: str) -> str:
    text = text.replace('local COOLDOWN_SEC = 2.0', 'local COOLDOWN_SEC = 3.0', 1)

    old_try = """local function tryRefresh(reason)
    local id = getTargetId()
    if not id or id < 0 then return false end
    if not autoRefreshEnabled() then return false end
    if not watchingTarget() then return false end
    if deps.hasPendingSp and deps.hasPendingSp() then return false end
    if not ctx.seeded then return false end
    local now = os.clock()
    if now - (ctx.lastRefreshAt or 0) < COOLDOWN_SEC then return false end
    if not sendSpRefresh(id) then return false end"""

    new_try = """local function tryRefresh(reason)
    local id = getTargetId()
    if not id or id < 0 then return false end
    if not autoRefreshEnabled() then return false end
    if not watchingTarget() then return false end
    if deps.hasPendingSp and deps.hasPendingSp() then return false end
    if deps.hasOutboundPending and deps.hasOutboundPending() then return false end
    if not ctx.seeded then return false end
    local now = os.clock()
    if now - (ctx.lastRefreshAt or 0) < COOLDOWN_SEC then return false end
    if not sendSpRefresh(id) then return false end"""
    if old_try not in text:
        raise RuntimeError('tryRefresh block not found')
    text = text.replace(old_try, new_try, 1)

    old_mob = """    local ped = readTargetPed()
    if ped then
        if isCharInAnyCar and isCharInAnyCar(ped) then return 'vehicle' end
        return 'onfoot'
    end
    return ctx.mobility"""
    new_mob = """    return ctx.mobility"""
    if old_mob in text:
        text = text.replace(old_mob, new_mob, 1)

    old_veh_sync = """function M.onTargetVehicleSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastVehicleSyncAt = os.clock()
    flushPending()
end"""
    new_veh_sync = """function M.onTargetVehicleSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastVehicleSyncAt = os.clock()
    if ctx.pending then flushPending() end
end"""
    if old_veh_sync in text:
        text = text.replace(old_veh_sync, new_veh_sync, 1)

    old_pass_sync = """function M.onTargetPassengerSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastVehicleSyncAt = os.clock()
    flushPending()
end"""
    new_pass_sync = """function M.onTargetPassengerSync(playerId)
    playerId = tonumber(playerId)
    if not playerId or playerId ~= getTargetId() then return end
    ctx.lastVehicleSyncAt = os.clock()
    if ctx.pending then flushPending() end
end"""
    if old_pass_sync in text:
        text = text.replace(old_pass_sync, new_pass_sync, 1)

    return text


def patch_refresh_deps(text: str) -> str:
    needle = '        hasPendingSp = function() return M.hasPendingSp and M.hasPendingSp() end,'
    add = (
        '        hasPendingSp = function() return M.hasPendingSp and M.hasPendingSp() end,\n'
        '        hasOutboundPending = function()\n'
        '            if specSession.hasOutboundPending then return specSession.hasOutboundPending() end\n'
        '            return false\n'
        '        end,'
    )
    if needle in text and 'hasOutboundPending = function()' not in text:
        text = text.replace(needle, add, 1)
    return text


def main():
    patches = [
        ('report_desk_spectate_stats.lua', patch_stats),
        ('report_desk_spectate_session.lua', patch_session),
        ('report_desk_input.lua', patch_input),
        ('report_desk_hooks.lua', patch_hooks),
        ('report_desk_sp_refresh.lua', patch_refresh),
    ]
    for name, fn in patches:
        path = ROOT / name
        original = path.read_text(encoding='utf-8')
        path.write_text(fn(original), encoding='utf-8')
        print(f'patched {name}')

    stats_path = ROOT / 'report_desk_spectate_stats.lua'
    stats = stats_path.read_text(encoding='utf-8')
    stats = patch_refresh_deps(stats)
    stats_path.write_text(stats, encoding='utf-8')
    print('patched report_desk_spectate_stats.lua (refresh deps)')


if __name__ == '__main__':
    main()
