--[[ Модуль: главный цикл MoonLoader, poll, autosave, hook health. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

-- Главный цикл MoonLoader: init, hooks, poll ingest, autosave.
function main()
    while not isSampfuncsLoaded() or not isSampLoaded() do wait(100) end
    while not isSampAvailable() do wait(100) end

    local okCfg, errCfg = pcall(loadConfig)
    if not okCfg then
        print('[Report Desk] config: ' .. tostring(errCfg))
        pcall(ensureCheatsSettings)
    end
    if type(initCmdBinds) == 'function' then
        pcall(initCmdBinds)
    end
    pcall(ensureComposerQuickButtons)
    pcall(syncLegacyGgTechFromComposerButtons)
    pcall(ensureAdminPunishSettings)
    pcall(initDeskIngest)
    if settings.spectate_sp_ui == nil then settings.spectate_sp_ui = true end
    if settings.spectate_vehicle_hud == nil then
        settings.spectate_vehicle_hud = true
        markDirtySettings()
    end
    pcall(updateMimguiGameInputPassthrough)
    if type(deskSpectateStats) ~= 'table' or type(deskSpectateStats.install) ~= 'function' then
        print('[Report Desk] spectate module unavailable — spectate HUD disabled')
    else
    local okSpInstall, errSpInstall = pcall(function()
    deskSpectateStats.install({
        trim = trim,
        stripTags = stripTags,
        sendChat = sendChat,
        sendMenuOutbound = sendMenuOutbound,
        uiText = uiText,
        toU32 = toU32,
        col_accent = col_accent,
        col_accent_dim = col_accent_dim,
        col_muted = col_muted,
        col_muted2 = col_muted2,
        col_label = col_label,
        col_warn = col_warn,
        sampIsPlayerConnected = sampIsPlayerConnected,
        sampGetPlayerNickname = sampGetPlayerNickname,
        sampGetPlayerColor = sampGetPlayerColor,
        sampGetPlayerPing = sampGetPlayerPing,
        sampGetPlayerScore = sampGetPlayerScore,
        markDirtySettings = markDirtySettings,
        flushDirtyConfigNow = flushDirtyConfigNow,
        sampev = sampev,
        getSettings = function() return settings end,
        getSpectating = function() return deskInputState.playerSpectating end,
        getShowWindow = function() return showWindow[0] end,
    })
    deskSpectateStats.installInputHooks({
        sampev = sampev,
        vkeys = vkeys,
        imgui = imgui,
        isVkDown = isVkDown,
        hotkeyCapture = function() return deskCache.hotkeyCapture end,
        cheatKeyCapture = function() return deskCache.cheatCapture end,
        getShowWindow = function() return showWindow[0] end,
        isDeskTypingActive = deskWindowWantsKeyboard,
        getPlayerSpectating = function() return deskInputState.playerSpectating end,
        setPlayerSpectating = deskSetPlayerSpectating,
        sampIsChatInputActive = sampIsChatInputActive,
        sampIsDialogActive = sampIsDialogActive,
        sendSlapPlayer = sendSlapPlayer,
        sendTrPlayer = sendTrPlayer,
        utf8ToCp1251 = utf8ToCp1251,
        readInputBuf = readInputBuf,
        onSpectatingOn = function()
            deskRememberSpectateCursorMode()
            deskReleaseImguiCapture()
            if showWindow[0] then
                deskInputState.spectateUiModeActive = true
                deskEnableUiCursorForSamp()
            else
                deskInputState.spectateUiModeActive = false
            end
            updateMimguiGameInputPassthrough()
        end,
        onSpectatingOff = function()
            deskLeaveSpectateMode()
            deskInputPolicyApply()
            if showWindow[0] then updateDeskInputCapture() end
        end,
        restoreSpectateCamera = deskRestoreSpectateCamera,
        updateInputPassthrough = updateMimguiGameInputPassthrough,
        enableSpectateCursor = deskEnableUiCursorForSamp,
        rememberSpectateCursor = deskRememberSpectateCursorMode,
        setSpectateUiMode = function(on)
            deskInputState.spectateUiModeActive = on and true or false
        end,
        getSpectateUiModeActive = function()
            return deskInputState.spectateUiModeActive == true
        end,
    })
    end)
    if not okSpInstall then
        print('[Report Desk] spectate install: ' .. tostring(errSpInstall))
    end
    end
    pcall(deskReinstallSpMenuHooks)
    pcall(installDeskSpMenuRpcBlock)
    pcall(installDeskCheckerRpcProbe)
    pcall(function()
        local specSession = package.loaded['report_desk_spectate_session']
        if specSession and specSession.syncTextDrawHooks and sampev then
            specSession.syncTextDrawHooks(sampev)
        end
    end)
    uiSound[0] = settings.sound
    uiAutoRulesEnabled[0] = settings.auto_rules_enabled ~= false
    uiAutoTimeEnabled[0] = settings.auto_time_enabled ~= false
    uiAutoGgEnabled[0] = settings.auto_gg_enabled ~= false
    setInputBuf(deskReplyBuf.watch, settings.watch_notify or 'see')
    setInputBuf(deskReplyBuf.time, getTimeReplyText())
    setInputBuf(deskReplyBuf.gg, getGgReplyText())
    setInputBuf(deskReplyBuf.tech, getTechReplyText())
    if not doesFileExist(CONFIG_PATH) then
        markDirtySettings()
        markDirtyThreads()
    end
    pcall(flushDirtyConfigNow)

    sampRegisterChatCommand('adesk', function()
        pcall(toggleWindow)
    end)
    sampRegisterChatCommand('reportdesk', function()
        pcall(toggleWindow)
    end)
    sampRegisterChatCommand('hist', function(arg)
        pcall(sendHistoryByPlayerId, arg)
    end)
    sampRegisterChatCommand('iget', function(arg)
        pcall(sendGetByPlayerId, arg)
    end)
    sampRegisterChatCommand('ilog', function(arg)
        pcall(sendLogByPlayerId, arg)
    end)
    sampRegisterChatCommand('iskill', function(arg)
        pcall(sendAskillByPlayerId, arg)
    end)
    sampRegisterChatCommand('warnlast', function(arg)
        pcall(sendWarnLast, arg)
    end)
    sampRegisterChatCommand('banlast', function(arg)
        pcall(sendBanLast, arg)
    end)
    sampRegisterChatCommand('jaillast', function(arg)
        pcall(sendJailLast, arg)
    end)
    sampRegisterChatCommand('mutelast', function(arg)
        pcall(sendMuteLast, arg)
    end)
    sampRegisterChatCommand('acar', function(arg)
        pcall(deskAcarEnter, arg)
    end)
    sampRegisterChatCommand('guns', function()
        pcall(deskGiveGuns)
    end)

    refreshMyNick()
    uiWatchAutoNotify[0] = settings.watch_auto_notify ~= false
    uiProfanityFilter[0] = settings.profanity_filter_enabled ~= false
    uiProfanitySound[0] = settings.profanity_filter_sound ~= false
    -- Anti-replay + chatLogReady до хуков: live-репорты сразу в UX, не ждём checkerInit/thread.
    pcall(seedSeenChatLines)
    pcall(installProfanityHooks)
    pcall(installDeskServerMessageHook)
    pcall(installDeskSpectateDialogHook)
    pcall(installDeskSpectateToggleHook)
    pcall(installDeskSendChatHook)
    pcall(installDeskSendCommandHook)
    pcall(installDeskPlayerQuitHook)
    pcall(installDeskPlayerJoinHook)
    pcall(installDeskPlayerStreamInHook)
    pcall(installDeskPlayerColorHook)
    pcall(installDeskGodmodeHealthHook)
    pcall(installDeskSpRefreshHooks)
    pcall(sampSyncAllPlayerColorsAsync)
    pcall(onlinePlayersRescan, true)
    pcall(deskRegisterHookEntries)
    pcall(deskFinalizeReportDeskExport)
    sessionLive = true
    lastSettingsSave = os.clock()
    lastThreadsSave = os.clock()
    lastMapPrune = os.clock()
    deskVeh.bind({
        settings = settings,
        sendChat = sendChat,
        say = say,
        markDirtySettings = markDirtySettings,
        col_accent = col_accent,
        col_accent_dim = col_accent_dim,
        col_muted = col_muted,
        col_muted2 = col_muted2,
        col_warn = col_warn,
        col_chat_bg = col_chat_bg,
        deskTex = deskTex,
    })
    pcall(ensureDeskCatalogWarmup)
    pcall(announceDeskStartup)
    if type(exactTimeInit) == 'function' then pcall(exactTimeInit) end

    lua_thread.create(function()
        pcall(checkerInit)
        wait(0)
        pcall(getFilteredThreadKeys)
    end)

    local lastPoll = 0
    local lastHookCheck = 0
    local lastCheckerTickAt = 0
    local CHECKER_TICK_SP_INTERVAL = 0.5
    local CHECKER_TICK_IDLE_INTERVAL = 0.5
    local deskWasSampInGame = type(deskSampInGame) == 'function' and deskSampInGame() or false

    local function resolveIngestPollInterval()
        if type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive() then
            return POLL_INTERVAL_SAFETY
        end
        return showWindow[0] and POLL_INTERVAL or POLL_INTERVAL_CLOSED
    end

    local function mainLoopWaitMs()
        if showWindow[0] then return 16 end
        if deskIsSpectating() then return 16 end
        if cheatState.airbreak then return 0 end
        if cheatState.marker.active then return 0 end
        if type(skinsPrewarmActive) == 'function' and skinsPrewarmActive() then return 1 end
        if deskTexPipeline.anyPending() then return 1 end
        if cheatState.hudDrag.active then return 1 end
        if checkerState and checkerState.hudDrag and checkerState.hudDrag.active then return 1 end
        if type(deskSpectateStats) == 'table'
                and deskSpectateStats.isHudDragActive
                and deskSpectateStats.isHudDragActive() then return 1 end
        if type(deskAnyBindCapture) == 'function' and deskAnyBindCapture() then return 1 end
        if type(adminPunishHasPending) == 'function' and adminPunishHasPending() then return 8 end
        if type(settings) == 'table' and settings.admin_punish_enabled == true then
            local hookOk = type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive()
            local profOk = deskCache and deskCache.profHooksInstalled == true
            if not hookOk or not profOk then
                return 25
            end
        end
        return 50
    end

    while true do
        wait(mainLoopWaitMs())


        if deskCache.uiCacheDirty then
            invalidateUiCaches()
            deskCache.uiCacheDirty = nil
        end

        if os.clock() - myNickTick >= 2.0 then
            refreshMyNick()
            myNickTick = os.clock()
        end

        if type(deskSampInGame) == 'function' then
            local inGame = deskSampInGame()
            if inGame and not deskWasSampInGame then
                cheatState.hudPlaced = false
                if type(checkerState) == 'table' then
                    checkerState.hudPlaced = false
                end
                if type(deskAdminLevelState) == 'table' then
                    deskAdminLevelState.fromLogin = false
                    deskAdminLevelState.loginLevel = nil
                end
                pcall(onlinePlayersRescan, true)
            end
            deskWasSampInGame = inGame
        end

        if type(settings) == 'table' and settings.admin_punish_enabled == true then
            if type(pollAdminPunishChat) == 'function'
                    and (type(adminPunishHooksActive) ~= 'function' or not adminPunishHooksActive()) then
                pcall(pollAdminPunishChat)
            end
            if type(adminPunishTick) == 'function' then
                pcall(adminPunishTick)
            end
        end

        if type(adminPunishFlushDeferredLogs) == 'function' then
            pcall(adminPunishFlushDeferredLogs)
        end

        if type(tempLeadershipPumpPending) == 'function' then
            pcall(tempLeadershipPumpPending)
        end
        if type(tickAutoReplyQueue) == 'function' then
            pcall(tickAutoReplyQueue)
        elseif type(tickAutoReplyWorker) == 'function' then
            pcall(tickAutoReplyWorker)
        end

        pcall(deskInputPolicyApply)
        if type(deskAnyBindCapture) == 'function' and deskAnyBindCapture() then
            pcall(deskBindCapturePollFrame)
        end
        pcall(deskTickAdminPauseState)
        if showWindow[0] then
            deskInputState.wasOpen = true
        elseif deskInputState.wasOpen then
            deskInputState.wasOpen = false
        end

        pollInterval = resolveIngestPollInterval()
        if pollInterval and os.clock() - lastPoll >= pollInterval then
            pcall(pollReportIngest)
            lastPoll = os.clock()
        end
        if type(deskSpectateStats) == 'table' and deskSpectateStats.hasOutboundPending and deskSpectateStats.hasOutboundPending() then
            pcall(deskSpectateStats.flushOutbound)
        end
        if type(remoteChatFlushSampQueue) == 'function' then
            pcall(remoteChatFlushSampQueue)
        end

        if not deskCache.catalogTexFlushPending then
            pcall(deskTexPipeline.flushDeferred, deskTex, imgui, 8)
        end
        if showWindow[0] and type(deskCatalogTabActive) == 'function' and deskCatalogTabActive() then
            pcall(deskCatalogTexTick)
        end

        if os.clock() - lastHookCheck >= HOOK_HEALTH_CHECK_INTERVAL then
            pcall(deskEnsureAllHooks)
            lastHookCheck = os.clock()
        end

        if os.clock() - lastMapPrune >= PRUNE_MAP_INTERVAL then
            pcall(pruneAllTimedMaps)
            if deskCache.deferThreadPrune then
                pcall(pruneOldThreads)
                deskCache.deferThreadPrune = nil
            end
            lastMapPrune = os.clock()
        end

        pcall(cheatsProcessKeybinds)
        pcall(cheatsMaintain)
        local nowLoop = os.clock()
        local checkerInterval = CHECKER_TICK_IDLE_INTERVAL
        if deskIsSpectating() and type(checkerIsHudVisible) == 'function' and not checkerIsHudVisible() then
            checkerInterval = CHECKER_TICK_SP_INTERVAL
        end
        if nowLoop - lastCheckerTickAt >= checkerInterval then
            pcall(checkerTick)
            lastCheckerTickAt = nowLoop
        end
        pcall(function()
            if type(deskSpectateStats) == 'table' and deskSpectateStats.tickPendingSp then
                deskSpectateStats.tickPendingSp()
            end
        end)
        pcall(function()
            local specSession = package.loaded['report_desk_spectate_session']
            if not specSession then
                local okReq, mod = pcall(require, 'report_desk_spectate_session')
                if okReq then specSession = mod end
            end
            if specSession and specSession.tickTdHooksLifecycle then
                specSession.tickTdHooksLifecycle(sampev)
            end
        end)
        pcall(cheatsTickMarker)
        pcall(maskIdTick)
        pcall(tickScheduledConfigFlush)

        local nowSave = os.clock()
        if nowSave - lastSettingsSave >= AUTOSAVE_SETTINGS_INTERVAL then
            if type(flushCheckerCatalogNow) == 'function' then
                pcall(flushCheckerCatalogNow)
            end
            if dirtySettings or dirtyThreads then
                local okSave, saved = pcall(saveConfig)
                if okSave and saved then
                    lastSettingsSave = nowSave
                    lastThreadsSave = nowSave
                elseif not okSave then
                    print('[Report Desk] autosave: ' .. tostring(saved))
                end
            else
                lastSettingsSave = nowSave
                lastThreadsSave = nowSave
            end
        elseif dirtyThreads and nowSave - lastThreadsSave >= AUTOSAVE_THREADS_INTERVAL then
            local okSave, saved = pcall(saveConfig)
            if okSave and saved then
                lastThreadsSave = nowSave
                lastSettingsSave = nowSave
            elseif not okSave then
                print('[Report Desk] autosave threads: ' .. tostring(saved))
            end
        end
    end
end

-- Cleanup при выгрузке скрипта.
function onScriptTerminate(scr)
    if scr == thisScript() then
        pcall(function()
            local specSession = package.loaded['report_desk_spectate_session']
            if specSession and specSession.isActive and specSession.isActive() then
                rawset(_G, '__desk_sp_recover', {
                    targetId = specSession.getTargetId(),
                    targetNick = specSession.getTargetNick(),
                    ts = os.time(),
                })
            end
        end)
        skinRadiusJob.cancel = true
        pcall(deskTexPipeline.shutdown, deskTex, imgui)
        pcall(deskUninstall)
        deskRestoreNormalGameCamera()
        pcall(updateMimguiGameInputPassthrough)
        pcall(cheatsCleanup)
        pcall(deskTexLoad.clearAll)
        if deskConfigReady then
            pcall(flushDirtyConfigNow)
        end
    end
end
