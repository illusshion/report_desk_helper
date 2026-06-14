--[[ Модуль: пауза/AFK и состояние игры. ]]

local deskAdminPauseTracked = false

local function deskPauseBlocksAutoReply()
    if deskAdminPlayerPaused() then return true end
    if isPauseMenuActive and isPauseMenuActive() then return true end
    if isGamePaused and isGamePaused() then return true end
    return false
end

function deskAutoReplyAllowed()
    if not isSampAvailable() then return false end
    if deskPauseBlocksAutoReply() then return false end
    return true
end

function deskAdminPlayerPaused()
    if not isSampAvailable() then return false end
    if type(sampIsPlayerPaused) ~= 'function' or type(sampGetPlayerIdByCharHandle) ~= 'function' then
        return false
    end
    if not PLAYER_PED or type(doesCharExist) ~= 'function' or not doesCharExist(PLAYER_PED) then
        return false
    end
    local ok, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    if not ok or not myId then return false end
    local ok2, paused = pcall(sampIsPlayerPaused, myId)
    return ok2 and paused == true
end

function deskTickAdminPauseState()
    local paused = deskPauseBlocksAutoReply()
    local was = deskAdminPauseTracked
    if paused and not was then
        if type(clearPendingAutoConfirm) == 'function' then
            pcall(clearPendingAutoConfirm)
        end
    elseif was and not paused then
        pcall(deskSyncChatSeenAfterResume)
    end
    deskAdminPauseTracked = paused
end

function deskGameMenuOpen()
    if isPauseMenuActive and isPauseMenuActive() then return true end
    if isGamePaused and isGamePaused() then return true end
    return false
end

function deskSampInGame()
    if type(isSampAvailable) ~= 'function' or not isSampAvailable() then return false end
    if type(sampIsLocalPlayerSpawned) == 'function' then
        local ok, spawned = pcall(sampIsLocalPlayerSpawned)
        return ok and spawned == true
    end
    if type(sampGetGamestate) == 'function' then
        local ok, gs = pcall(sampGetGamestate)
        return ok and gs == 3
    end
    return false
end
