--[[ Report Desk main loop + terminate ]]
if rawget(_G, '__REPORT_DESK_BUNDLE_ACTIVE') ~= true then return end

function main()
    while not isSampfuncsLoaded() or not isSampLoaded() do wait(100) end
    while not isSampAvailable() do wait(100) end

    local okCfg, errCfg = pcall(loadConfig)
    if not okCfg then
        print('[Report Desk] config: ' .. tostring(errCfg))
    end
    pcall(ensureComposerQuickButtons)
    pcall(syncLegacyGgTechFromComposerButtons)
    if settings.ingest_pc == nil then settings.ingest_pc = true end
    if settings.ingest_s == nil then settings.ingest_s = true end
    if settings.ingest_m == nil then settings.ingest_m = true end
    if settings.ingest_admin_actions == nil then settings.ingest_admin_actions = true end
    if not settings.spectate_hud_layout_v2 then
        if tonumber(settings.spectate_hud_x) == nil or tonumber(settings.spectate_hud_x) < 0 then
            settings.spectate_hud_x = 14
            settings.spectate_hud_y = 120
            markDirtySettings()
        end
        settings.spectate_hud_layout_v2 = true
        markDirtySettings()
    end
    pcall(initDeskIngest)
    updateMimguiGameInputPassthrough()
    deskSpectateStats.install({
        trim = trim,
        stripTags = stripTags,
        sendChat = sendChat,
        uiText = uiText,
        toU32 = toU32,
        col_accent = col_accent,
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
        onSpectatingOn = function()
            deskInputState.spectateUiModeActive = false
            deskRememberSpectateCursorMode()
            if showWindow[0] then
                deskEnableUiCursorForSamp()
                deskInputState.spectateUiModeActive = true
            end
            updateMimguiGameInputPassthrough()
        end,
        onSpectatingOff = function()
            deskLeaveSpectateMode()
            deskApplyInputPolicy()
            if showWindow[0] then updateDeskInputCapture() end
        end,
    })
    pcall(deskSpectateStats.ensureSpectatePlayerHook)
    uiSound[0] = settings.sound
    uiAutoOnlyUnread[0] = settings.auto_only_unread
    uiAutoRulesEnabled[0] = settings.auto_rules_enabled ~= false
    uiAutoTimeEnabled[0] = settings.auto_time_enabled ~= false
    uiAutoGgEnabled[0] = settings.auto_gg_enabled ~= false
    uiHistoryLimit[0] = settings.history_limit or 80
    uiPollChat[0] = settings.poll_chat_log ~= false
    uiPollEventsOnly[0] = settings.poll_events_only == true
    uiDebug[0] = settings.debug == true
    setInputBuf(deskReplyBuf.watch, settings.watch_notify or 'see')
    setInputBuf(deskReplyBuf.time, getTimeReplyText())
    setInputBuf(deskReplyBuf.gg, getGgReplyText())
    setInputBuf(deskReplyBuf.tech, getTechReplyText())
    if not doesFileExist(CONFIG_PATH) then saveConfig() end

    sampRegisterChatCommand('reps', function()
        pcall(toggleWindow)
    end)
    sampRegisterChatCommand('reportdesk', function()
        pcall(toggleWindow)
    end)
    sampRegisterChatCommand('repsdebug', function()
        settings.debug = not settings.debug
        uiDebug[0] = settings.debug
        say(settings.debug and 'Debug ON' or 'Debug OFF')
    end)
    sampRegisterChatCommand('hist', function(arg)
        pcall(sendHistoryByPlayerId, arg)
    end)

    pcall(checkerInit)

    seedSeenChatLines()
    refreshMyNick()
    sessionLive = true
    lastSettingsSave = os.clock()
    lastThreadsSave = os.clock()
    lastMapPrune = os.clock()
    uiMaxThreads[0] = tonumber(settings.max_threads) or DEFAULT_MAX_THREADS
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
    local lastPoll = 0
    local pollInterval = 0.25
    local lastNickCacheTick = 0
    local lastHookCheck = 0

    local function mainLoopNeedsFastTick()
        if showWindow[0] then return true end
        if deskIsSpectating() then return true end
        if deskTexPipeline.anyPending() then return true end
        if cheatState.airbreak then return true end
        if cheatState.marker.active then return true end
        if cheatState.hudDrag.active then return true end
        if checkerState and checkerState.hudDrag and checkerState.hudDrag.active then return true end
        if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
        return false
    end

    while true do
        wait(mainLoopNeedsFastTick() and 0 or 50)

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

        deskApplyInputPolicy()
        if showWindow[0] then
            deskInputState.wasOpen = true
            deskEnforceNoSampChat()
        elseif deskInputState.wasOpen then
            deskInputState.wasOpen = false
        end

        pollInterval = showWindow[0] and POLL_INTERVAL or POLL_INTERVAL_CLOSED
        if os.clock() - lastPoll >= pollInterval then
            pcall(pollReportIngest)
            lastPoll = os.clock()
        end

        if deskCache.catalogTexFlushPending then
            pcall(deskFlushCatalogTexPending)
        else
            pcall(deskTexPipeline.flushDeferred, deskTex, imgui, 8)
        end
        if deskCatalogTabActive and showWindow[0] then
            pcall(deskCatalogTexTick)
        end

        if os.clock() - lastHookCheck >= 12.0 then
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
            pcall(deskSpectateStats.ensureInputHooks)
            pcall(deskSpectateStats.ensureSpectatePlayerHook)
            lastHookCheck = os.clock()
        end

        if os.clock() - lastMapPrune >= PRUNE_MAP_INTERVAL then
            pcall(pruneAllTimedMaps)
            lastMapPrune = os.clock()
        end

        pcall(cheatsProcessKeybinds)
        pcall(cheatsMaintain)
        pcall(checkerTick)
        pcall(deskSpectateStats.pollSpectateArrowKeys)
        pcall(cheatsTickMarker)

        local nowSave = os.clock()
        if dirtySettings and nowSave - lastSettingsSave >= AUTOSAVE_SETTINGS_INTERVAL then
            pcall(saveConfig)
            lastSettingsSave = nowSave
            lastThreadsSave = nowSave
        elseif dirtyThreads and nowSave - lastThreadsSave >= AUTOSAVE_THREADS_INTERVAL then
            pcall(saveConfig)
            lastThreadsSave = nowSave
            lastSettingsSave = nowSave
        end
    end
end

function onScriptTerminate(scr)
    if scr == thisScript() then
        skinRadiusJob.cancel = true
        pcall(deskTexPipeline.shutdown, deskTex, imgui)
        pcall(deskUninstall)
        deskRestoreNormalGameCamera()
        updateMimguiGameInputPassthrough()
        pcall(cheatsCleanup)
        pcall(deskTexLoad.clearAll)
        if deskConfigReady then
            saveConfig()
        end
        local app = package.loaded['report_desk_app']
        if app and app.unload then pcall(app.unload) end
    end
end
