--[[ Модуль: pending /sp handshake. ]]
return function(ctx)
    local M = ctx.M

    function M.markPendingSpCommand(id, nick)
        local state = ctx.state
        local trim = ctx.trim
        local clearPendingSt = ctx.clearPendingSt
        local specSession = ctx.specSession
        local spUi = ctx.spUi
        local vehicleHud = ctx.vehicleHud
        local keysHud = ctx.keysHud
        local spRefresh = ctx.spRefresh
        local inputDeps = ctx.inputDeps
        local sampIsPlayerConnected = ctx.sampIsPlayerConnected
        local sampGetPlayerNickname = ctx.sampGetPlayerNickname

        id = tonumber(id)
        if not id or id < 0 then return end
        nick = trim and trim(nick or '') or tostring(nick or '')
        if nick == '' and sampIsPlayerConnected and sampGetPlayerNickname then
            pcall(function()
                if sampIsPlayerConnected(id) then
                    nick = trim and trim(sampGetPlayerNickname(id) or '') or ''
                end
            end)
        end
        state.pendingSpId = id
        state.pendingSpNick = nick
        state.pendingSpAt = os.clock()
        state.lastSpOutboundAt = state.pendingSpAt
        state.spChatRecoveryTried = false
        local cur = M.getTargetId()
        if cur ~= id then
            if cur >= 0 then clearPendingSt() end
            if vehicleHud and vehicleHud.reset then pcall(vehicleHud.reset) end
            if keysHud and keysHud.reset then pcall(keysHud.reset) end
            if spRefresh and spRefresh.resetContext then pcall(spRefresh.resetContext) end
        end
        if specSession and specSession.markAwaitingSpectate then
            pcall(specSession.markAwaitingSpectate, true)
        end
        if spUi and spUi.syncTdHooks then
            pcall(spUi.syncTdHooks)
        end
        if spUi and spUi.ensureSpectateSampevHooks then
            local sampev = inputDeps and inputDeps.sampev
            local specSessionMod = package.loaded['report_desk_spectate_session']
            local hooksOk = sampev and specSessionMod and specSessionMod.areSampevHooksActive
                and specSessionMod.areSampevHooksActive(sampev)
            if not hooksOk then
                pcall(spUi.ensureSpectateSampevHooks)
            end
        end
    end

    function M.cancelPendingSp()
        local state = ctx.state
        local specSession = ctx.specSession
        if not state.pendingSpId then return end
        state.pendingSpId = nil
        state.pendingSpNick = ''
        state.pendingSpAt = 0
        state.pendingSpStepDelta = nil
        if specSession and specSession.markAwaitingSpectate then
            pcall(specSession.markAwaitingSpectate, false)
        end
    end

    function M.hasPendingSp()
        return ctx.state.pendingSpId ~= nil
    end

    function M.tickPendingSp()
        local state = ctx.state
        local specPlayerActive = ctx.specPlayerActive
        local PENDING_SP_SEC = ctx.PENDING_SP_SEC
        local specSession = ctx.specSession

        if state.pendingSpId or specPlayerActive() then
            M.tickSpectateHealth()
        end
        local id = state.pendingSpId
        if not id then return end
        local at = tonumber(state.pendingSpAt) or 0
        local elapsed = at > 0 and (os.clock() - at) or 0
        local confirmed = specSession and specSession.isActive and specSession.isActive()
        if not confirmed and specPlayerActive() and elapsed >= 1.0 and elapsed <= PENDING_SP_SEC then
            if not state.spChatRecoveryTried then
                state.spChatRecoveryTried = true
                if specSession and specSession.tryRecoverFromChat then
                    pcall(specSession.tryRecoverFromChat)
                end
                if specSession and specSession.isActive and specSession.isActive() then
                    M.cancelPendingSp()
                    return
                end
            end
        end
        if at > 0 and elapsed > PENDING_SP_SEC then
            M.cancelPendingSp()
        end
    end
end
