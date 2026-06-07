--[[ Модуль: главный цикл MoonLoader, poll, autosave, hook health. ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

-- Главный цикл MoonLoader: init, hooks, poll ingest, autosave.
function main()
    while not isSampfuncsLoaded() or not isSampLoaded() do wait(100) end
    while not isSampAvailable() do wait(100) end

    local okCfg, errCfg = pcall(loadConfig)
    if not okCfg then
        print('[Report Desk] config: ' .. tostring(errCfg))
    end
    pcall(ensureComposerQuickButtons)
    pcall(syncLegacyGgTechFromComposerButtons)
    pcall(initDeskIngest)
    if settings.spectate_sp_ui == nil then settings.spectate_sp_ui = true end
    if settings.spectate_vehicle_hud == nil then
        settings.spectate_vehicle_hud = true
        markDirtySettings()
    end
    -- Флаги layout: только проставить, не трогать сохранённые координаты (saveConfig раньше их не писал).
    do
        local layoutFlags = {
            'spectate_hud_layout_v2',
            'spectate_sp_ui_layout_v2',
            'spectate_vehicle_hud_layout_v2',
            'spectate_vehicle_hud_layout_v3',
            'spectate_vehicle_hud_layout_v4',
            'spectate_vehicle_hud_layout_v5',
            'spectate_vehicle_hud_layout_v6',
        }
        for _, key in ipairs(layoutFlags) do
            if not settings[key] then
                settings[key] = true
                markDirtySettings()
            end
        end
    end
    pcall(initDeskIngest)
    pcall(updateMimguiGameInputPassthrough)
    if type(deskSpectateStats) ~= 'table' or type(deskSpectateStats.install) ~= 'function' then
        print('[Report Desk] spectate module unavailable — spectate HUD disabled')
    else
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
            deskInputState.spectateUiModeActive = false
            if showWindow[0] then
                deskInputState.spectateUiModeActive = true
            end
            updateMimguiGameInputPassthrough()
        end,
        onSpectatingOff = function()
            deskLeaveSpectateMode()
            deskApplyInputPolicy()
            if showWindow[0] then updateDeskInputCapture() end
        end,
        enableSpectateCursor = deskEnableUiCursorForSamp,
        rememberSpectateCursor = deskRememberSpectateCursorMode,
        setSpectateUiMode = function(on)
            deskInputState.spectateUiModeActive = on and true or false
        end,
        getSpectateUiModeActive = function()
            return deskInputState.spectateUiModeActive == true
        end,
        updateInputPassthrough = updateMimguiGameInputPassthrough,
        onAnsBarClosed = function()
            if deskSpectatingNow() and not showWindow[0] and not deskSpectateCameraBlocked() then
                deskRestoreSpectateCamera()
            end
            updateMimguiGameInputPassthrough()
        end,
        markAnsTypingActive = function()
            deskInputState.keyboardStickyUntil = os.clock() + 1.5
        end,
    })
    end
    pcall(deskReinstallSpMenuHooks)
    pcall(installDeskSpMenuRpcBlock)
    pcall(installDeskCheckerRpcProbe)
    uiSound[0] = settings.sound
    uiAutoOnlyUnread[0] = settings.auto_only_unread
    uiAutoRulesEnabled[0] = settings.auto_rules_enabled ~= false
    uiAutoTimeEnabled[0] = settings.auto_time_enabled ~= false
    uiAutoGgEnabled[0] = settings.auto_gg_enabled ~= false
    setInputBuf(deskReplyBuf.watch, settings.watch_notify or 'see')
    setInputBuf(deskReplyBuf.time, getTimeReplyText())
    setInputBuf(deskReplyBuf.gg, getGgReplyText())
    setInputBuf(deskReplyBuf.tech, getTechReplyText())
    if not doesFileExist(CONFIG_PATH) then saveConfig() end
    pcall(flushDirtyConfigNow)

    sampRegisterChatCommand('reps', function()
        pcall(toggleWindow)
    end)
    sampRegisterChatCommand('reportdesk', function()
        pcall(toggleWindow)
    end)
    sampRegisterChatCommand('hist', function(arg)
        pcall(sendHistoryByPlayerId, arg)
    end)

    pcall(checkerInit)

    seedSeenChatLines()
    pcall(seedProfanitySeenForChatBuffer)
    pcall(getFilteredThreadKeys)
    refreshMyNick()
    sessionLive = true
    lastSettingsSave = os.clock()
    lastThreadsSave = os.clock()
    lastMapPrune = os.clock()
    uiWatchAutoNotify[0] = settings.watch_auto_notify ~= false
    uiProfanityFilter[0] = settings.profanity_filter_enabled ~= false
    uiProfanitySound[0] = settings.profanity_filter_sound ~= false
    installProfanityHooks()
    installDeskServerMessageHook()
    installDeskSpectateDialogHook()
    installDeskSpectateToggleHook()
    installDeskSendChatHook()
    installDeskSendCommandHook()
    installDeskPlayerQuitHook()
    installDeskPlayerJoinHook()
    installDeskPlayerStreamInHook()
    installDeskPlayerColorHook()
    pcall(sampSyncAllPlayerColors)
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
    local lastPoll = 0
    local pollInterval = 0.25
    local lastNickCacheTick = 0
    local lastHookCheck = 0
    local lastCheckerTickAt = 0
    local CHECKER_TICK_SP_INTERVAL = 0.5

    local function resolveIngestPollInterval()
        if type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive() then
            return showWindow[0] and POLL_INTERVAL_HOOK or POLL_INTERVAL_CLOSED_HOOK
        end
        return showWindow[0] and POLL_INTERVAL or POLL_INTERVAL_CLOSED
    end

    local function mainLoopWaitMs()
        if showWindow[0] then return 8 end
        if deskIsSpectating() then return 16 end
        if deskTexPipeline.anyPending() then return 0 end
        if cheatState.airbreak then return 0 end
        if cheatState.marker.active then return 0 end
        if cheatState.hudDrag.active then return 0 end
        if checkerState and checkerState.hudDrag and checkerState.hudDrag.active then return 0 end
        if deskCache.hotkeyCapture or deskCache.cheatCapture then return 0 end
        return 50
    end

    while true do
        wait(mainLoopWaitMs())

        if os.clock() - myNickTick >= 2.0 then
            refreshMyNick()
            myNickTick = os.clock()
        end

        if os.clock() - lastNickCacheTick >= PLAYER_NICK_CACHE_INTERVAL then
            refreshPlayerNickCache(false)
            lastNickCacheTick = os.clock()
        end

        if not sessionLive then
            sessionLive = true
        end

        deskSampChatGuardFrame()
        deskApplyInputPolicy()
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
        if deskSpectateStats.hasOutboundPending and deskSpectateStats.hasOutboundPending() then
            pcall(deskSpectateStats.flushOutbound)
        end
        if type(remoteChatFlushSampQueue) == 'function' then
            pcall(remoteChatFlushSampQueue)
        end

        if deskCache.catalogTexFlushPending then
            pcall(deskFlushCatalogTexPending)
        else
            pcall(deskTexPipeline.flushDeferred, deskTex, imgui, 8)
        end
        if deskCatalogTabActive and showWindow[0] then
            pcall(deskCatalogTexTick)
        end

        if os.clock() - lastHookCheck >= HOOK_HEALTH_CHECK_INTERVAL then
            if not deskCache.serverMsgHandler or sampev.onServerMessage ~= deskCache.serverMsgHandler then
                pcall(installDeskServerMessageHook)
            end
            if not deskCache.specDialogHandler or sampev.onShowDialog ~= deskCache.specDialogHandler then
                pcall(installDeskSpectateDialogHook)
            end
            if not deskCache.specToggleHandler or sampev.onTogglePlayerSpectating ~= deskCache.specToggleHandler then
                pcall(installDeskSpectateToggleHook)
            end
            if not deskCache.sendChatHandler or sampev.onSendChat ~= deskCache.sendChatHandler then
                pcall(installDeskSendChatHook)
            end
            if not deskCache.sendCommandHandler or sampev.onSendCommand ~= deskCache.sendCommandHandler then
                pcall(installDeskSendCommandHook)
            end
            if not deskCache.playerQuitHandler or sampev.onPlayerQuit ~= deskCache.playerQuitHandler then
                pcall(installDeskPlayerQuitHook)
            end
            if not deskCache.playerJoinHandler or sampev.onPlayerJoin ~= deskCache.playerJoinHandler then
                pcall(installDeskPlayerJoinHook)
            end
            if not deskCache.playerStreamInHandler or sampev.onPlayerStreamIn ~= deskCache.playerStreamInHandler then
                pcall(installDeskPlayerStreamInHook)
            end
            if not deskCache.playerColorHandler or sampev.onSetPlayerColor ~= deskCache.playerColorHandler then
                pcall(installDeskPlayerColorHook)
            end
            if not deskCache.profHooksInstalled
                or (deskCache.profChatHandler and sampev.onChatMessage ~= deskCache.profChatHandler)
                or (deskCache.profBubbleHandler and sampev.onPlayerChatBubble ~= deskCache.profBubbleHandler) then
                deskCache.profHooksInstalled = false
                pcall(installProfanityHooks)
            end
            pcall(deskSpectateStats.ensureInputHooks)
            pcall(deskReinstallSpMenuHooks)
            pcall(installDeskSpMenuRpcBlock)
    pcall(installDeskCheckerRpcProbe)
            lastHookCheck = os.clock()
        end

        if os.clock() - lastMapPrune >= PRUNE_MAP_INTERVAL then
            pcall(pruneAllTimedMaps)
            lastMapPrune = os.clock()
        end

        pcall(cheatsProcessKeybinds)
        pcall(cheatsMaintain)
        local nowLoop = os.clock()
        local checkerInterval = (deskIsSpectating() and type(checkerIsHudVisible) == 'function'
            and not checkerIsHudVisible() and CHECKER_TICK_SP_INTERVAL) or 0
        if nowLoop - lastCheckerTickAt >= checkerInterval then
            pcall(checkerTick)
            lastCheckerTickAt = nowLoop
        end
        pcall(deskSpectateStats.tickPendingSp)
        pcall(cheatsTickMarker)
        if deskIsSpectating() and deskSpectateStats.maintainCamera then
            pcall(deskSpectateStats.maintainCamera)
        end

        local nowSave = os.clock()
        if nowSave - lastSettingsSave >= AUTOSAVE_SETTINGS_INTERVAL then
            if type(flushCheckerCatalogNow) == 'function' then
                pcall(flushCheckerCatalogNow)
            end
            if dirtySettings or dirtyThreads then
                pcall(saveConfig)
                dirtySettings = false
                dirtyThreads = false
            end
            lastSettingsSave = nowSave
            lastThreadsSave = nowSave
        elseif dirtyThreads and nowSave - lastThreadsSave >= AUTOSAVE_THREADS_INTERVAL then
            pcall(saveConfig)
            lastThreadsSave = nowSave
            lastSettingsSave = nowSave
        end
        if dirtyScenarioLearn and nowSave - lastScenarioLearnSave >= 60 then
            pcall(saveScenarioLearnData)
            lastScenarioLearnSave = nowSave
        end
    end
end

-- Cleanup при выгрузке скрипта.
function onScriptTerminate(scr)
    if scr == thisScript() then
        skinRadiusJob.cancel = true
        pcall(deskTexPipeline.shutdown, deskTex, imgui)
        pcall(deskUninstall)
        deskRestoreNormalGameCamera()
        pcall(updateMimguiGameInputPassthrough)
        pcall(cheatsCleanup)
        pcall(deskTexLoad.clearAll)
        if deskConfigReady then
            saveConfig()
            if type(saveScenarioLearnData) == 'function' then
                pcall(saveScenarioLearnData)
            end
        end
        local app = package.loaded['report_desk_app']
        if app and app.unload then pcall(app.unload) end
    end
end
