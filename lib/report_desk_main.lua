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
        if not deskConfigReady then deskConfigReady = true end
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
        local layoutDirty = false
        for _, key in ipairs(layoutFlags) do
            if not settings[key] then
                settings[key] = true
                layoutDirty = true
            end
        end
        if layoutDirty then markDirtySettings() end
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
            deskApplyInputPolicy()
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

    sampRegisterChatCommand('reps', function()
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
    pcall(sampSyncAllPlayerColors)
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
        if type(chatSeen) == 'table' then
            chatSeen.lines = {}
            chatSeen.order = {}
            chatSeen.deferred = {}
            chatSeen.consumed = {}
            chatSeen.consumedOrder = {}
            if sampGetChatString then
                for i = 0, 99 do
                    markChatLineSeen(chatLineSeenKey(sampGetChatString(i)))
                    if i % 20 == 19 then wait(0) end
                end
            end
        end
        if sampGetChatString and type(profanityMarkLineSeen) == 'function'
                and type(chatLineSeenKey) == 'function' then
            local pollMax = CHAT_POLL_LINES_OPEN or 100
            for i = 0, pollMax - 1 do
                local line = sampGetChatString(i) or ''
                if line ~= '' then
                    profanityMarkLineSeen(chatLineSeenKey(line))
                end
                if i % 20 == 19 then wait(0) end
            end
        end
        chatLogReady = true
        pcall(getFilteredThreadKeys)
    end)

    local lastPoll = 0
    local lastApHookCheck = 0
    local pollInterval = 0.25
    local lastNickCacheTick = 0
    local lastHookCheck = 0
    local lastCheckerTickAt = 0
    local CHECKER_TICK_SP_INTERVAL = 0.5
    local deskWasSampInGame = type(deskSampInGame) == 'function' and deskSampInGame() or false

    local function resolveIngestPollInterval()
        if type(deskIsServerMsgHookActive) == 'function' and deskIsServerMsgHookActive() then
            return POLL_INTERVAL_SAFETY
        end
        return showWindow[0] and POLL_INTERVAL or POLL_INTERVAL_CLOSED
    end

    local function mainLoopWaitMs()
        if showWindow[0] then return 8 end
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
        if type(adminPunishHasPending) == 'function' and adminPunishHasPending() then return 16 end
        if type(settings) == 'table' and settings.admin_punish_enabled == true then return 16 end
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

        if type(deskSampInGame) == 'function' then
            local inGame = deskSampInGame()
            if inGame and not deskWasSampInGame then
                cheatState.hudPlaced = false
                if type(checkerState) == 'table' then
                    checkerState.hudPlaced = false
                end
            end
            deskWasSampInGame = inGame
        end

        if type(settings) == 'table' and settings.admin_punish_enabled == true then
            if type(adminPunishEnsureServerHook) == 'function'
                    and os.clock() - lastApHookCheck >= 1.0 then
                pcall(adminPunishEnsureServerHook)
                lastApHookCheck = os.clock()
            end
            if type(pollAdminPunishChat) == 'function' then
                pcall(pollAdminPunishChat)
            end
            if type(adminPunishTick) == 'function' then
                pcall(adminPunishTick)
            end
        end

        deskSampChatGuardFrame()
        deskApplyInputPolicy()
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

        if deskCache.catalogTexFlushPending then
            pcall(deskFlushCatalogTexPending)
        else
            pcall(deskTexPipeline.flushDeferred, deskTex, imgui, 8)
        end
        if deskCatalogTabActive and showWindow[0] then
            pcall(deskCatalogTexTick)
        end

        if os.clock() - lastHookCheck >= HOOK_HEALTH_CHECK_INTERVAL then
            pcall(deskEnsureAllHooks)
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
        pcall(function()
            if type(deskSpectateStats) == 'table' and deskSpectateStats.tickPendingSp then
                deskSpectateStats.tickPendingSp()
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
