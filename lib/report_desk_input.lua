--[[ Report Desk input / camera / F7 ]]
function drawCheatsTab()
    if not cheatsUiSynced then syncCheatsUiFromSettings() end
    ensureCheatsSettings()

    pushPanelStyle(col_chat_bg)
    local panelFlags = 0
    if imgui.WindowFlags and imgui.WindowFlags.AlwaysVerticalScrollbar then
        panelFlags = imgui.WindowFlags.AlwaysVerticalScrollbar
    end
    imgui.BeginChild('##cheats_panel', imgui.ImVec2(-1, -1), false, panelFlags)
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(12, 10))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 8))
    drawDeskBindCaptureBanner()

    drawCheatFeatureCard('Godmode', 'GM', 'gm', 'gm',
        cheatState.godmode, uiCheatGm, uiCheatGmStart, 'gm_on_start', cheatsApplyGodmode)

    drawCheatFeatureCard('Wallhack', 'WH', 'wh', 'wh',
        cheatState.wallhack, uiCheatWh, uiCheatWhStart, 'wh_on_start', cheatsApplyWallhack)

    deskFormPanelBegin('##ch_ab')
    drawCheatCardTitle('Airbreak', 'AB')
    local abLabel = cheatState.airbreak and '\xC2\xEA\xEB\xFE\xF7\xE5\xED' or '\xC2\xFB\xEA\xEB\xFE\xF7\xE5\xED'
    if deskFormCheckboxRow(abLabel, uiCheatAb, cheatsSetAirbreak, 'ab_en') then end
    local spdW = math.min(DESK_FORM_INPUT_W, deskFormRowAvail('\xD1\xEA\xEE\xF0\xEE\xF1\xF2\xFC', DESK_FORM_LABEL_W))
    imgui.PushItemWidth(spdW)
    deskPushFlatInputStyle()
    local abSpdChanged = false
    if imgui.InputFloat then
        abSpdChanged = imgui.InputFloat('##ab_spd', uiCheatAbSpeed, 0.01, 0.05, '%.2f')
    else
        abSpdChanged = imgui.SliderFloat('##ab_spd', uiCheatAbSpeed, 0.05, 3.0, '%.2f')
    end
    if abSpdChanged then
        settings.cheats.ab_speed = uiCheatAbSpeed[0]
        cheatState.abSpeedLive = nil
        markDirtySettings()
    end
    deskPopFlatInputStyle()
    imgui.PopItemWidth()
    if cheatState.airbreak then
        imgui.TextColored(col_muted2, uiText(
            string.format('Q \xEC\xE8\xED\xF3\xF1 / E \xEF\xEB\xFE\xF1 \xF3\xE4\xE5\xF0\xE6 \xB7 %.2f', cheatsGetAbSpeed())))
    end
    drawCheatBindRow('ab', 'ab')
    deskFormPanelEnd()

    deskFormPanelBegin('##ch_mk')
    drawCheatCardTitle('\xCC\xE0\xF0\xEA\xE5\xF0 \xE8 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2', '')
    cheatState.uiMarkerWheel[0] = settings.cheats.marker_wheel ~= false
    if deskFormCheckboxRow('\xD2\xE5\xEB\xE5\xEF\xEE\xF0\xF2 \xED\xE0 \xEA\xEE\xEB\xB8\xF1\xE8\xEA\xEE \xEC\xFB\xF8\xE8', cheatState.uiMarkerWheel, function(v)
        settings.cheats.marker_wheel = v and true or false
        if not v and cheatState.marker.active then markerSetMode(false) end
        markDirtySettings()
    end) then end
    imgui.TextColored(col_muted2, uiText('\xD1\xCA\xCC \x97 \xF0\xE5\xE6\xE8\xEC \xB7 \xCB\xCA\xCC \x97 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2 \xB7 \xCF\xCA\xCC \x97 \xEF\xEE\xF1\xE0\xE4\xEA\xE0 \xE2 \xEC\xE0\xF8\xE8\xED\xF3'))
    drawCheatBindRow('marker', 'mk', '\xD0\xE5\xE6\xE8\xEC \xEC\xE0\xF0\xEA\xE5\xF0\xE0')
    drawCheatBindRow('tp', 'tp', '\xD2\xE5\xEB\xE5\xEF\xEE\xF0\xF2 \xED\xE0 \xEC\xE5\xF2\xEA\xF3')
    drawCheatBindRow('veh', 'vb', '\xCF\xEE\xF1\xE0\xE4\xEA\xE0 \xE2 \xEC\xE0\xF8\xE8\xED\xF3')
    if cheatState.marker.active then
        local btnW = deskFormRowAvail('\xD1\xF2\xE0\xF2\xF3\xF1', DESK_FORM_LABEL_W)
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.38, 0.22, 0.10, 0.85))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.48, 0.28, 0.12, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.42, 0.24, 0.11, 1.0))
        if imgui.Button(uiText('\xC2\xFB\xEA\xEB\xFE\xF7\xE8\xF2\xFC \xEC\xE0\xF0\xEA\xE5\xF0') .. '##mk_off', imgui.ImVec2(btnW, DESK_FORM_ROW_H)) then
            markerSetMode(false)
        end
        imgui.PopStyleColor(3)
    end
    deskFormPanelEnd()

    deskFormPanelBegin('##ch_opts')
    drawCheatCardTitle('\xCE\xEF\xF6\xE8\xE8', '')
    if deskFormCheckboxRow('HUD \xE2 \xE8\xE3\xF0\xE5', uiCheatHud, function(v)
        ensureCheatsSettings()
        settings.cheats.show_hud = v and true or false
        markDirtySettings()
        flushDirtyConfigNow()
    end) then end
    deskFormPanelEnd()

    imgui.PopStyleVar(2)
    imgui.Dummy(imgui.ImVec2(0, 8))
    local btnW = math.min(150, math.max(120, (imgui.GetContentRegionAvail().x - 12) * 0.5))
    local totalW = btnW * 2 + 10
    imgui.SetCursorPosX(math.max(0, (imgui.GetContentRegionAvail().x - totalW) * 0.5))
    if imgui.Button(uiText('\xC2\xFB\xEA\xEB \xE2\xF1\xE5') .. '##cheats_off', imgui.ImVec2(btnW, DESK_FORM_ROW_H)) then
        cheatsCleanup()
    end
    imgui.SameLine()
    if imgui.Button(uiText('\xD1\xE1\xF0\xEE\xF1 \xE1\xE8\xED\xE4\xEE\xE2') .. '##cheats_rst', imgui.ImVec2(btnW, DESK_FORM_ROW_H)) then
        settings.cheats = defaultCheatsSettings()
        ensureCheatsSettings()
        syncCheatsUiFromSettings()
        markDirtySettings()
        flushDirtyConfigNow()
    end

    imgui.EndChild()
    popPanelStyle()
end

function imguiItemEdited()
    return imgui.IsItemDeactivatedAfterEdit and imgui.IsItemDeactivatedAfterEdit()
end

function releaseDeskInputCapture(force)
    if showWindow[0] and not force then return end
    deskWantsKeyboard = false
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(false) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

function clearDeskImguiInputState(force)
    if showWindow[0] and not force then return end
    pcall(function()
        local io = imgui.GetIO()
        if not io then return end
        io.WantCaptureMouse = false
        io.WantCaptureKeyboard = false
        io.WantTextInput = false
        io.MouseDrawCursor = false
        if io.MouseDown then
            for i = 0, 4 do
                io.MouseDown[i] = false
            end
        end
        if io.MouseClicked then
            for i = 0, 4 do
                io.MouseClicked[i] = false
            end
        end
        if io.MouseReleased then
            for i = 0, 4 do
                io.MouseReleased[i] = false
            end
        end
    end)
end

function deskSetPlayerSpectating(active)
    deskInputState.playerSpectating = active and true or false
    if not active then
        deskInputState.spectateWantCursorMode = nil
        deskInputState.spectateUiModeActive = false
    end
end

function deskSpectatingNow()
    return deskInputState.playerSpectating == true
end

function deskSyncSpectateState(force)
    if force == false then
        if deskSpectatingNow() then
            deskLeaveSpectateMode()
        else
            deskRestoreNormalGameCamera()
            updateMimguiGameInputPassthrough()
        end
        return false
    end
    if force == true then
        deskSetPlayerSpectating(true)
        updateMimguiGameInputPassthrough()
        return true
    end
    return deskSpectatingNow()
end

function deskImguiNeedsInput()
    if showWindow[0] or deskCache.hotkeyCapture or deskCache.cheatCapture then
        return true
    end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    if cheatState.marker.active then return true end
    if deskSpectateStats.isHudDragActive and deskSpectateStats.isHudDragActive() then
        return true
    end
    return false
end

function deskSpectateCameraMode()
    if deskInputState.spectateWantCursorMode ~= nil then
        return deskInputState.spectateWantCursorMode
    end
    if CMODE_LOCKCAM ~= nil then return CMODE_LOCKCAM end
    if CMODE_LOCKCAMANDCONTROL ~= nil then return CMODE_LOCKCAMANDCONTROL end
    if CMODE_LOCKCAM_NOCURSOR ~= nil then return CMODE_LOCKCAM_NOCURSOR end
    return nil
end

function deskIsSpectateCameraMode(cm)
    cm = tonumber(cm)
    if cm == nil then return false end
    if CMODE_LOCKCAM and cm == CMODE_LOCKCAM then return true end
    if CMODE_LOCKCAMANDCONTROL and cm == CMODE_LOCKCAMANDCONTROL then return true end
    if CMODE_LOCKCAM_NOCURSOR and cm == CMODE_LOCKCAM_NOCURSOR then return true end
    return false
end

function deskRememberSpectateCursorMode()
    if not sampGetCursorMode then return end
    local cm = sampGetCursorMode()
    if deskIsSpectateCameraMode(cm) then
        deskInputState.spectateWantCursorMode = cm
    end
end

function deskSpectateHudWantsInput()
    if deskSpectateStats.isHudDragActive and deskSpectateStats.isHudDragActive() then return true end
    return false
end

function deskReleaseImguiCapture()
    deskWantsKeyboard = false
    releaseDeskInputCapture(true)
    clearDeskImguiInputState(true)
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(false) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

function deskSpectateCameraBlocked()
    if deskSpectateHudWantsInput() then return true end
    if cheatState.marker.active then return true end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    return false
end

function deskRestoreSpectateCamera()
    if deskInputState.spectateWantCursorMode == nil then
        deskRememberSpectateCursorMode()
    end
    local want = deskSpectateCameraMode()
    if want and sampSetCursorMode then
        pcall(sampSetCursorMode, want)
    end
    if sampToggleCursor then pcall(sampToggleCursor, false) end
end

function deskRestoreNormalGameCamera()
    setDeskPlayerLock(false)
    deskInputState.spectateUiModeActive = false
    pcall(function()
        if sampSetCursorMode then
            sampSetCursorMode(0)
        end
        if sampToggleCursor then sampToggleCursor(false) end
    end)
end

function deskLeaveSpectateMode()
    deskSetPlayerSpectating(false)
    deskRestoreNormalGameCamera()
    updateMimguiGameInputPassthrough()
end

function deskEnsureCameraAfterPanelClose()
    deskClearImguiCaptureAfterPanel()
    setDeskPlayerLock(false)
    deskInputState.spectateUiModeActive = false
    deskInputState.keyboardStickyUntil = 0
    deskWantsKeyboard = false
    if deskCache.mainPanelFrame then
        deskCache.mainPanelFrame.HideCursor = true
        deskCache.mainPanelFrame.LockPlayer = false
    end
    if deskSpectateCameraBlocked() then
        updateMimguiGameInputPassthrough()
        return
    end
    if deskSpectatingNow() then
        deskRestoreSpectateCamera()
    else
        deskRestoreNormalGameCamera()
    end
    updateMimguiGameInputPassthrough()
end

function deskEnableUiCursorForSamp()
    if CMODE_DISABLED == nil or not sampSetCursorMode then return end
    if sampGetCursorMode and sampGetCursorMode() == CMODE_DISABLED then return end
    pcall(sampSetCursorMode, CMODE_DISABLED)
end

function deskEnsureUiCursorForOpenPanel()
    if not showWindow[0] or not deskSpectatingNow() then return end
    if deskSpectateCameraBlocked() then return end
    if not sampGetCursorMode or CMODE_DISABLED == nil then return end
    if deskIsSpectateCameraMode(sampGetCursorMode()) then
        deskEnableUiCursorForSamp()
    end
end

function deskClearImguiCaptureAfterPanel()
    deskWantsKeyboard = false
    releaseDeskInputCapture(true)
    clearDeskImguiInputState(true)
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(false) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

function deskOnPanelOpened()
    if deskCache.mainPanelFrame then
        deskCache.mainPanelFrame.HideCursor = false
        deskCache.mainPanelFrame.LockPlayer = false
    end
    if deskSpectatingNow() then
        deskRememberSpectateCursorMode()
        deskEnableUiCursorForSamp()
        deskInputState.spectateUiModeActive = true
    end
    updateMimguiGameInputPassthrough()
end

function deskOnPanelClosed()
    deskEnsureCameraAfterPanelClose()
end

function deskSteadyPanelHidden()
    setDeskPlayerLock(false)
    updateMimguiGameInputPassthrough()
end

function deskGameCursorActive()
    if showWindow[0] or deskSpectatingNow() then return false end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    if sampGetCursorMode and sampGetCursorMode() ~= 0 then return true end
    if deskSpectateStats.isHudDragActive and deskSpectateStats.isHudDragActive() then return true end
    if deskSpectateStats.isHudHovered and deskSpectateStats.isHudHovered() then return true end
    if deskSpectateStats.wantsHudInput and deskSpectateStats.wantsHudInput() then return true end
    return false
end

function resetDeskMouseState()
    if showWindow[0] then return end
    deskApplyInputPolicy()
    if deskSpectatingNow() then return end
    if deskGameCursorActive() then return end
    pcall(function()
        if sampToggleCursor then sampToggleCursor(false) end
    end)
    pcall(function()
        if showCursor then showCursor(false) end
    end)
    cheatState.hudDrag.active = false
    cheatState.hudHovered = false
    if deskSpectateStats and deskSpectateStats.resetHudDrag then
        pcall(deskSpectateStats.resetHudDrag)
    end
end

function ensureDeskNotBlockingGame()
    deskApplyInputPolicy()
end

function deskApplyInputPolicy()
    local panelOpen = showWindow[0] and true or false
    local wasOpen = deskInputState.panelOpenPrev and true or false

    if panelOpen and not wasOpen then
        deskOnPanelOpened()
    elseif not panelOpen and wasOpen then
        deskOnPanelClosed()
    elseif panelOpen then
        if deskOpenLocksPlayer() then
            setDeskPlayerLock(true)
        else
            setDeskPlayerLock(false)
        end
        updateMimguiGameInputPassthrough()
    else
        deskSteadyPanelHidden()
    end

    deskInputState.panelOpenPrev = panelOpen
end

function deskEnforceNoSampChat()
    if not showWindow[0] then return end
    if type(sampSetChatInputEnabled) == 'function' then
        pcall(sampSetChatInputEnabled, false)
    end
end

function deskWarmupMutesGameInput()
    return false
end

function applyDeskWarmupInputPolicy()
    updateMimguiGameInputPassthrough()
end

function updateMimguiGameInputPassthrough()
    if imgui.DisableInput == nil then return end
    imgui.DisableInput = not deskImguiNeedsInput()
end

function deskIsSpectating()
    return deskInputState.playerSpectating == true
end

function deskSafeRestoreCamera()
    if deskSpectatingNow() then return end
    if restoreCameraJumpcut then pcall(restoreCameraJumpcut) end
end

function setDeskPlayerLock(lock)
    if lock then
        if not deskInputState.playerLocked then
            lockPlayerControl(true)
            deskInputState.playerLocked = true
        end
    elseif deskInputState.playerLocked then
        lockPlayerControl(false)
        deskInputState.playerLocked = false
    end
end

function deskOpenLocksPlayer()
    if sampIsDialogActive and sampIsDialogActive() then return false end
    return showWindow[0] and not cheatState.airbreak and not deskSpectatingNow()
end

function updateDeskInputCapture()
    if not showWindow[0] then return end
    deskSyncInputFocusState()
    if deskOpenLocksPlayer() then
        setDeskPlayerLock(true)
    else
        setDeskPlayerLock(false)
    end
    local io = imgui.GetIO and imgui.GetIO()
    local wantKb = deskImguiTypingActive()
    if io and (io.WantCaptureKeyboard or io.WantTextInput) then
        wantKb = true
    end
    local wantMouse = false
    if io and io.WantCaptureMouse then wantMouse = true end
    if imgui.IsWindowHovered and imgui.HoveredFlags and imgui.IsWindowHovered(imgui.HoveredFlags.AnyWindow) then
        wantMouse = true
    end
    deskWantsKeyboard = wantKb or wantMouse
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(wantKb) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(wantMouse) end
    deskEnsureUiCursorForOpenPanel()
end

function flushDirtyConfigNow()
    if dirtySettings or dirtyThreads then
        pcall(saveConfig)
        dirtySettings = false
        dirtyThreads = false
        lastSettingsSave = os.clock()
        lastThreadsSave = os.clock()
    end
end

function hideDeskWindowForCapture()
    if showWindow[0] then
        showWindow[0] = false
        deskInputState.replyFocused = false
        deskInputState.keyboardStickyUntil = 0
        deskInputState.windowOpenSince = 0
        deskApplyInputPolicy()
    end
end

function closeDeskWindow()
    local wasOpen = showWindow[0] or deskInputState.panelOpenPrev
    showWindow[0] = false
    if not wasOpen then return end
    deskResetHotkeyDebounce(settings.hotkey or vkeys.VK_F7)
    deskCache.hotkeyCapture = false
    deskCache.cheatCapture = nil
    deskCache.cheatCaptureSlot = 'main'
    deskInputState.replyFocused = false
    deskInputState.keyboardStickyUntil = 0
    deskInputState.windowOpenSince = 0
    deskWantsKeyboard = false
    if cheatState.marker.active then markerSetMode(false) end
    skinTabEntered = false
    skinUiTabActive = false
    if deskVeh and deskVeh.tabActive then
        deskVeh.tabActive = false
    end
    pcall(deskTexPipeline.halt, deskTex)
    deskInputState.wasOpen = false
    deskApplyInputPolicy()
    flushDirtyConfigNow()
end

function sendGameCmd(cmd)
    local stId = trim(cmd or ''):match('^st%s+(%d+)$')
    if stId then
        deskSpectateStats.markPendingSt(tonumber(stId))
    end
    releaseDeskInputCapture(true)
    sendChat(cmd)
    closeDeskWindow()
end

function getLocalAdminLevel()
    local lv = tonumber(settings.admin_level) or 3
    return math.max(1, math.min(4, math.floor(lv)))
end

function threadActionTargetId(t)
    if not t then return nil end
    if type(t.messages) == 'table' then
        for i = #t.messages, 1, -1 do
            local m = t.messages[i]
            if m and m.dir ~= 'out' and m.dir ~= 'system' and m.dir ~= 'event' then
                local body = trim(m.text or m.rawText or '')
                if body ~= '' then
                    local id = extractSuspectIdForWatch(body)
                    if id then return id end
                end
            end
        end
    end
    return clampSuspectPlayerId(t.id)
end

