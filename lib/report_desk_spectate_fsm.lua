--[[ Конечный автомат жизненного цикла /sp (упрощает набор флагов spectate). ]]
local M = {}

local PHASE = {
    IDLE = 'idle',
    PENDING_SP = 'pending_sp',
    ACTIVE = 'active',
    PENDING_ST = 'pending_st',
    RECOVERING = 'recovering',
}

local phase = PHASE.IDLE
local deadlines = {}

function M.getPhase()
    return phase
end

function M.isIdle()
    return phase == PHASE.IDLE
end

function M.locksSpectateOff()
    return phase == PHASE.PENDING_SP
        or phase == PHASE.ACTIVE
        or phase == PHASE.PENDING_ST
        or phase == PHASE.RECOVERING
end

function M.onPendingSp()
    phase = PHASE.PENDING_SP
end

function M.onSpectateActive()
    if phase == PHASE.PENDING_SP or phase == PHASE.RECOVERING then
        phase = PHASE.ACTIVE
    end
end

function M.onPendingSt()
    phase = PHASE.PENDING_ST
end

function M.onRecovering()
    phase = PHASE.RECOVERING
end

function M.onSpectateOff()
    if phase == PHASE.PENDING_ST then
        return
    end
    phase = PHASE.IDLE
end

function M.onStComplete()
    if phase == PHASE.PENDING_ST then
        phase = PHASE.ACTIVE
    end
end

function M.reset()
    phase = PHASE.IDLE
    deadlines = {}
end

function M.armDeadline(key, at)
    deadlines[tostring(key or '')] = tonumber(at)
end

function M.deadlineDue(key, now)
    local at = deadlines[tostring(key or '')]
    return at ~= nil and now >= at
end

function M.clearDeadline(key)
    deadlines[tostring(key or '')] = nil
end

return M
