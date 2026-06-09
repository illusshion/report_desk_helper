--[[ Конечный автомат spawn catalog sync checker (/adms + /leaders). ]]
local M = {}

local PHASE = {
    NOT_SYNCED = 'not_synced',
    AWAITING_ADMS = 'awaiting_adms',
    AWAITING_LEADERS = 'awaiting_leaders',
    SYNCED = 'synced',
    RETRYING = 'retrying',
    FAILED = 'failed',
}

local phase = PHASE.NOT_SYNCED
local retryCount = 0
local retryAt = nil

function M.getPhase()
    return phase
end

function M.isSynced()
    return phase == PHASE.SYNCED
end

function M.isRunning()
    return phase == PHASE.AWAITING_ADMS
        or phase == PHASE.AWAITING_LEADERS
        or phase == PHASE.RETRYING
end

function M.markSynced()
    phase = PHASE.SYNCED
    retryCount = 0
    retryAt = nil
end

function M.beginAdms()
    phase = PHASE.AWAITING_ADMS
end

function M.beginLeaders()
    phase = PHASE.AWAITING_LEADERS
end

function M.scheduleRetry(at, count)
    phase = PHASE.RETRYING
    retryAt = at
    retryCount = tonumber(count) or retryCount
end

function M.markFailed()
    phase = PHASE.FAILED
end

function M.shouldRunRetry(now)
    if phase ~= PHASE.RETRYING then return false end
    return retryAt ~= nil and now >= retryAt
end

function M.getRetryCount()
    return retryCount
end

function M.reset()
    phase = PHASE.NOT_SYNCED
    retryCount = 0
    retryAt = nil
end

function M.syncFromCheckerState(st)
    if not st then return end
    if st.spawnCatalogSyncDone then
        M.markSynced()
        return
    end
    if st.spawnCatalogSyncRunning then
        if st.spawnAdmsHandled and not st.spawnLeadersHandled then
            phase = PHASE.AWAITING_LEADERS
        else
            phase = PHASE.AWAITING_ADMS
        end
        return
    end
    if st.spawnCatalogSyncAt then
        M.scheduleRetry(st.spawnCatalogSyncAt, st.spawnAdmsRetries)
        return
    end
    if phase ~= PHASE.SYNCED then
        phase = PHASE.NOT_SYNCED
    end
end

function M.applyToCheckerState(st)
    if not st then return end
    st.spawnCatalogSyncDone = phase == PHASE.SYNCED
    st.spawnCatalogSyncRunning = phase == PHASE.AWAITING_ADMS or phase == PHASE.AWAITING_LEADERS
    st.spawnCatalogSyncAt = retryAt
    st.spawnAdmsRetries = retryCount
end

return M
