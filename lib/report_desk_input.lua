--[[ Модуль: ввод, hotkeys, cursor policy, spectate input. ]]
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

-- Imgui Item Edited
function imguiItemEdited()
    return imgui.IsItemDeactivatedAfterEdit and imgui.IsItemDeactivatedAfterEdit()
end

-- Release Desk Input Capture
function releaseDeskInputCapture(force)
    if showWindow[0] and not force then return end
    deskWantsKeyboard = false
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(false) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

-- Clear Desk Imgui Input State
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

-- Desk hook/helper.
function deskSetPlayerSpectating(active)
    deskInputState.playerSpectating = active and true or false
    if not active then
        deskInputState.spectateWantCursorMode = nil
        deskInputState.spectateUiModeActive = false
    end
end

-- Desk hook/helper.
function deskSpectatingNow()
    return deskInputState.playerSpectating == true
end

-- Desk hook/helper.
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

-- Desk hook/helper.
function deskImguiNeedsInput()
    if showWindow[0] or deskCache.hotkeyCapture or deskCache.cheatCapture then
        return true
    end
    if cheatState.marker.active then return true end
    if not sessionLive then return false end
    if type(cheatsHudWantsInput) == 'function' and cheatsHudWantsInput() then
        return true
    end
    if type(cheatsIsHudDragActive) == 'function' and cheatsIsHudDragActive() then
        return true
    end
    if type(checkerHudWantsInput) == 'function' and checkerHudWantsInput() then
        return true
    end
    if type(checkerIsHudDragActive) == 'function' and checkerIsHudDragActive() then
        return true
    end
    if type(deskSpectateStats) == 'table' then
        local function spWants(fn)
            if type(fn) ~= 'function' then return false end
            local ok, v = pcall(fn)
            return ok and v == true
        end
        if spWants(deskSpectateStats.isHudDragActive) then return true end
        if spWants(deskSpectateStats.wantsHudInput) then return true end
        if spWants(deskSpectateStats.wantsSpMenuInput) then return true end
        if spWants(deskSpectateStats.wantsVehicleHudInput) then return true end
        if spWants(deskSpectateStats.wantsKeysHudInput) then return true end
        if spWants(deskSpectateStats.isAnsBarOpen) then
            if spWants(deskSpectateStats.isAnsLayoutSwitch) then return false end
            return true
        end
    end
    return false
end

-- Desk hook/helper.
function deskSpectateCameraMode()
    local saved = deskInputState.spectateWantCursorMode
    if saved ~= nil and deskIsSpectateCameraMode(saved) then
        return saved
    end
    if CMODE_LOCKCAM ~= nil then return CMODE_LOCKCAM end
    if CMODE_LOCKCAMANDCONTROL ~= nil then return CMODE_LOCKCAMANDCONTROL end
    if CMODE_LOCKCAM_NOCURSOR ~= nil then return CMODE_LOCKCAM_NOCURSOR end
    return saved
end

-- Desk hook/helper.
function deskIsSpectateCameraMode(cm)
    cm = tonumber(cm)
    if cm == nil then return false end
    if CMODE_LOCKCAM and cm == CMODE_LOCKCAM then return true end
    if CMODE_LOCKCAMANDCONTROL and cm == CMODE_LOCKCAMANDCONTROL then return true end
    if CMODE_LOCKCAM_NOCURSOR and cm == CMODE_LOCKCAM_NOCURSOR then return true end
    return false
end

-- Desk hook/helper.
function deskRememberSpectateCursorMode()
    if not sampGetCursorMode then return end
    local cm = sampGetCursorMode()
    if CMODE_DISABLED ~= nil and cm == CMODE_DISABLED then
        if deskIsSpectateCameraMode(deskInputState.spectateWantCursorMode) then return end
        if CMODE_LOCKCAM ~= nil then deskInputState.spectateWantCursorMode = CMODE_LOCKCAM end
        return
    end
    deskInputState.spectateWantCursorMode = cm
end

-- Desk hook/helper.
function deskSpectateHudWantsInput()
    if deskSpectateStats.isHudDragActive and deskSpectateStats.isHudDragActive() then return true end
    return false
end

-- Desk hook/helper.
function deskReleaseImguiCapture()
    deskWantsKeyboard = false
    releaseDeskInputCapture(true)
    clearDeskImguiInputState(true)
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(false) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

-- Desk hook/helper.
function deskSpectateCameraBlocked()
    if deskSpectateHudWantsInput() then return true end
    if cheatState.marker.active then return true end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    return false
end

-- Desk hook/helper.
function deskRestoreSpectateCamera()
    deskInputState.spectateUiModeActive = false
    setDeskPlayerLock(false)
    if not deskSpectatingNow() then return end
    -- В /sp SAMP сам держит LOCKCAM для камеры наблюдателя. Не трогаем режим на open;
    -- на close — только если мы (или чат) его сбили с spectate-режима.
    if sampGetCursorMode and sampSetCursorMode then
        local cm = sampGetCursorMode()
        if not deskIsSpectateCameraMode(cm) then
            local want = deskSpectateCameraMode()
            if want then pcall(sampSetCursorMode, want) end
        end
    end
    if sampToggleCursor then pcall(sampToggleCursor, false) end
end

-- Desk hook/helper.
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

-- Desk hook/helper.
function deskLeaveSpectateMode()
    deskSetPlayerSpectating(false)
    deskRestoreNormalGameCamera()
    updateMimguiGameInputPassthrough()
end

-- Desk hook/helper.
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
    if deskSpectatingNow() then
        deskRestoreSpectateCamera()
        if type(deskSpectateStats) == 'table' and deskSpectateStats.maintainCamera then
            pcall(deskSpectateStats.maintainCamera)
        end
    elseif not deskSpectateCameraBlocked() then
        deskRestoreNormalGameCamera()
    end
    updateMimguiGameInputPassthrough()
end

-- Desk hook/helper.
function deskEnableUiCursorForSamp()
    -- В /sp камера наблюдателя = SAMP LOCKCAM; mimgui рисует курсор через HideCursor.
    if deskSpectatingNow() then return end
    if CMODE_DISABLED == nil or not sampSetCursorMode then return end
    if sampGetCursorMode and sampGetCursorMode() == CMODE_DISABLED then return end
    pcall(sampSetCursorMode, CMODE_DISABLED)
end

-- Desk hook/helper.
function deskEnsureUiCursorForOpenPanel()
    if deskSpectatingNow() then return end
    if not showWindow[0] then return end
    if deskImguiTypingActive() or deskInputState.replyFocused then return end
    if deskSpectateCameraBlocked() then return end
    if not sampGetCursorMode or CMODE_DISABLED == nil then return end
    if deskIsSpectateCameraMode(sampGetCursorMode()) then
        deskEnableUiCursorForSamp()
    end
end

-- Desk hook/helper.
function deskClearImguiCaptureAfterPanel()
    deskWantsKeyboard = false
    releaseDeskInputCapture(true)
    clearDeskImguiInputState(true)
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(false) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(false) end
end

-- Desk hook/helper.
function deskOnPanelOpened()
    if deskCache.mainPanelFrame then
        deskCache.mainPanelFrame.HideCursor = false
        deskCache.mainPanelFrame.LockPlayer = false
    end
    if deskSpectatingNow() then
        deskInputState.spectateUiModeActive = true
    end
    updateMimguiGameInputPassthrough()
end

-- Desk hook/helper.
function deskOnPanelClosed()
    deskEnsureCameraAfterPanelClose()
end

-- Desk hook/helper.
function deskSteadyPanelHidden()
    setDeskPlayerLock(false)
    updateMimguiGameInputPassthrough()
end

-- Desk hook/helper.
function deskGameCursorActive()
    if showWindow[0] or deskSpectatingNow() then return false end
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    if sampGetCursorMode and sampGetCursorMode() ~= 0 then return true end
    if deskSpectateStats.isHudDragActive and deskSpectateStats.isHudDragActive() then return true end
    if deskSpectateStats.isHudHovered and deskSpectateStats.isHudHovered() then return true end
    if deskSpectateStats.wantsHudInput and deskSpectateStats.wantsHudInput() then return true end
    if type(checkerIsHudDragActive) == 'function' and checkerIsHudDragActive() then return true end
    if type(checkerHudWantsInput) == 'function' and checkerHudWantsInput() then return true end
    if deskSpectateStats.wantsAnsInput and deskSpectateStats.wantsAnsInput() then return true end
    return false
end

-- Reset Desk Mouse State
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
    if type(checkerState) == 'table' then
        if checkerState.hudDrag then checkerState.hudDrag.active = false end
        checkerState.hudHovered = false
    end
end

-- Ensure Desk Not Blocking Game
function ensureDeskNotBlockingGame()
    deskApplyInputPolicy()
end

-- Desk hook/helper.
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

    local uiOpen = deskDeskOrAnsUiOpen()
    if uiOpen and not deskInputState.deskUiOpenPrev then
        deskHoldSampChatInput()
    elseif not uiOpen and deskInputState.deskUiOpenPrev then
        deskReleaseSampChatInput()
    end
    deskInputState.deskUiOpenPrev = uiOpen
end

-- Desk hook/helper.
function deskAnsBarBlocksSampChat()
    return type(deskSpectateStats) == 'table'
        and type(deskSpectateStats.isAnsBarOpen) == 'function'
        and deskSpectateStats.isAnsBarOpen()
end

-- Desk hook/helper.
function deskDeskOrAnsUiOpen()
    return showWindow[0] or deskAnsBarBlocksSampChat()
end

-- SAMP CInput: блок Enable-хука + тихий clamp iInputEnabled (без мигания open/close).
local deskSampInputFfiReady = false
local deskSampInputEnableHook = nil
local deskSampCInputThis = nil

local deskSampTextMsgs = {
    [0x0102] = true, -- WM_CHAR
    [0x0106] = true, -- WM_SYSCHAR
    [0x0109] = true, -- WM_UNICHAR
    [0x0286] = true, -- WM_IME_CHAR
}

local function deskSpectateDeskMouseMsg(msg)
    if not showWindow[0] or not deskSpectatingNow() then return false end
    if not deskCache or not deskCache.wm then return false end
    local wm = deskCache.wm
    return msg == wm.MOUSEMOVE or msg == wm.LBUTTONDOWN or msg == wm.LBUTTONUP
        or msg == wm.RBUTTONDOWN or msg == wm.RBUTTONUP
        or msg == wm.MBUTTONDOWN or msg == wm.MBUTTONUP
        or msg == wm.MOUSEWHEEL or msg == wm.MOUSEHWHEEL
        or msg == wm.XBUTTONDOWN
end

local function deskEnsureSampInputFfi()
    if deskSampInputFfiReady then return true end
    if type(sampGetInputInfoPtr) ~= 'function' then return false end
    local ok = pcall(function()
        ffi.cdef[[
            typedef void (*stSampCmdProc)(char*);
            typedef struct {
                void* pD3DDevice;
                void* pDXUTDialog;
                void* pDXUTEditBox;
                stSampCmdProc pCMDs[144];
                char szCMDNames[144][33];
                int iCMDCount;
                int iInputEnabled;
            } stSampInputInfo;
        ]]
    end)
    if not ok then return false end
    deskSampInputFfiReady = true
    return true
end

local function deskVerifySampSig(addr, sig)
    if not memory or not memory.getuint8 then return false end
    for i, b in ipairs(sig) do
        if memory.getuint8(addr + i - 1, true) ~= b then return false end
    end
    return true
end

local function deskClampSampChatInputOff()
    if not deskEnsureSampInputFfi() then return end
    pcall(function()
        local base = sampGetInputInfoPtr()
        if not base or base == 0 then return end
        local inp = ffi.cast('stSampInputInfo*', base)
        inp.iInputEnabled = 0
    end)
end

local function deskFindInputEnableAddr()
    if not getModuleHandle then return nil end
    local ok, base = pcall(getModuleHandle, 'samp.dll')
    if not ok or not base or base == 0 then return nil end
    local sig = { 0x83, 0xEC, 0x10, 0x56, 0x8B }
    local hits = {}
    for addr = base + 0x64000, base + 0x69000 do
        if deskVerifySampSig(addr, sig) then
            hits[#hits + 1] = addr
        end
    end
    if #hits == 1 then return hits[1] end
    if #hits > 1 then
        local prefer = base + 0x657E0
        for _, addr in ipairs(hits) do
            if addr == prefer then return addr end
        end
        return hits[1]
    end
    local fallback = base + 0x657E0
    if deskVerifySampSig(fallback, sig) then return fallback end
    return nil
end

local function deskInstallThiscallHook5(callback, addr)
    local okCdef = pcall(function()
        ffi.cdef[[
            int VirtualProtect(void* lpAddress, unsigned long dwSize, unsigned long flNewProtect, unsigned long* lpflOldProtect);
        ]]
    end)
    if not okCdef then return nil end
    local size = 5
    local voidAddr = ffi.cast('void*', addr)
    local oldProt = ffi.new('unsigned long[1]')
    local orgBytes = ffi.new('uint8_t[?]', size)
    ffi.copy(orgBytes, voidAddr, size)
    local detourAddr = tonumber(ffi.cast('intptr_t', ffi.cast('void*', ffi.cast('void(__thiscall*)(void*)', callback))))
    local hookBytes = ffi.new('uint8_t[?]', size, 0x90)
    hookBytes[0] = 0xE9
    ffi.cast('uint32_t*', hookBytes + 1)[0] = detourAddr - addr - 5
    local hookObj = { active = false, voidAddr = voidAddr, size = size, orgBytes = orgBytes, hookBytes = hookBytes, oldProt = oldProt, addr = addr }
    local castOrig = ffi.cast('void(__thiscall *)(void*)', addr)
    function hookObj.set(on)
        hookObj.active = on and true or false
        ffi.C.VirtualProtect(voidAddr, size, 0x40, oldProt)
        ffi.copy(voidAddr, on and hookBytes or orgBytes, size)
        ffi.C.VirtualProtect(voidAddr, size, oldProt[0], oldProt)
    end
    function hookObj.stop() hookObj.set(false) end
    function hookObj.start() hookObj.set(true) end
    setmetatable(hookObj, {
        __call = function(_, this)
            hookObj.stop()
            castOrig(this)
            hookObj.start()
        end,
    })
    hookObj.start()
    return hookObj
end

local function deskInstallSampInputEnableHook()
    if deskSampInputEnableHook then return true end
    if not isSampAvailable or not isSampAvailable() then return false end
    local addr = deskFindInputEnableAddr()
    if not addr then return false end
    local hookObj
    local function detour(this)
        if this ~= nil then deskSampCInputThis = this end
        if deskDeskOrAnsUiOpen() then return end
        if type(isSampfuncsConsoleActive) == 'function' and isSampfuncsConsoleActive() then return end
        hookObj(this)
    end
    hookObj = deskInstallThiscallHook5(detour, addr)
    if not hookObj then return false end
    deskSampInputEnableHook = hookObj
    if deskCache then deskCache.sampInputEnableHook = hookObj end
    return true
end

function deskUninstallSampInputEnableHook()
    if deskSampInputEnableHook then
        pcall(function() deskSampInputEnableHook.stop() end)
        deskSampInputEnableHook = nil
    end
    if deskCache then deskCache.sampInputEnableHook = nil end
end

function deskHoldSampChatInput()
    deskInputState.sampChatHeldOff = true
    pcall(deskInstallSampInputEnableHook)
    if type(sampSetChatInputEnabled) == 'function' then
        pcall(sampSetChatInputEnabled, false)
    end
    deskClampSampChatInputOff()
end

function deskReleaseSampChatInput()
    if not deskInputState.sampChatHeldOff then return end
    deskInputState.sampChatHeldOff = false
end

function deskCloseSampChatIfOpen()
    deskHoldSampChatInput()
end

function deskRestoreSampChatIfNeeded()
    deskReleaseSampChatInput()
end

function deskSampChatGuardFrame()
    if not deskDeskOrAnsUiOpen() then return end
    pcall(deskInstallSampInputEnableHook)
    if type(sampSetChatInputEnabled) == 'function' then
        pcall(sampSetChatInputEnabled, false)
    end
end

-- Запасной слой: consumeWindowMessage для лаунчеров, которые обходят sampSetChatInputEnabled.
function deskShouldBlockSampChatKey(msg, wparam)
    if not deskDeskOrAnsUiOpen() then return false end
    if not deskCache or not deskCache.wm then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return false end
    msg = tonumber(msg) or 0
    wparam = tonumber(wparam) or 0
    if deskSpectateDeskMouseMsg(msg) then return true end
    if deskSampTextMsgs[msg] then
        return true
    end
    local wm = deskCache.wm
    if msg == wm.KEYDOWN or msg == wm.SYSKEYDOWN or msg == wm.KEYUP or msg == wm.SYSKEYUP then
        if type(deskPassesGameKey) == 'function' and deskPassesGameKey(wparam) then return false end
        if wm.CHAT_KEYS[wparam] then return true end
        if showWindow[0] then return true end
        if deskAnsBarBlocksSampChat() then return true end
    end
    return false
end

-- Desk hook/helper.
function deskConsumeSampChatKey(msg)
    msg = tonumber(msg) or 0
    if deskSpectateDeskMouseMsg(msg) then
        consumeWindowMessage(true, false)
        return
    end
    if deskSampTextMsgs[msg] then
        consumeWindowMessage(true, false)
    else
        consumeWindowMessage(true, true)
    end
    deskClampSampChatInputOff()
end

-- Desk hook/helper.
function deskShouldBlockGameInput(msg, wparam)
    return deskShouldBlockSampChatKey(msg, wparam)
end

-- Desk hook/helper.
function deskOverlayTextInputActive()
    return deskAnsBarBlocksSampChat()
end

-- Desk hook/helper.
function deskWarmupMutesGameInput()
    return false
end

-- Apply Desk Warmup Input Policy
function applyDeskWarmupInputPolicy()
    updateMimguiGameInputPassthrough()
end

local DESK_CHAT_WM_KEY = '__rd_wm_chat__'

local function uninstallDeskChatWm()
    local prev = _G[DESK_CHAT_WM_KEY]
    if prev and removeEventHandler then
        pcall(removeEventHandler, 'onWindowMessage', prev)
    end
    _G[DESK_CHAT_WM_KEY] = nil
end

local function installDeskChatWmHandler()
    uninstallDeskChatWm()
    local handler = function(msg, wparam, lparam)
        if deskDeskOrAnsUiOpen() and deskShouldBlockSampChatKey(msg, wparam) then
            deskConsumeSampChatKey(msg)
        end
    end
    addEventHandler('onWindowMessage', handler, true)
    _G[DESK_CHAT_WM_KEY] = handler
end

installDeskChatWmHandler()

-- Update Mimgui Game Input Passthrough
function updateMimguiGameInputPassthrough()
    if not imgui or imgui.DisableInput == nil then return end
    if deskDeskOrAnsUiOpen() then
        imgui.DisableInput = not (deskImguiNeedsInput() == true)
        return
    end
    if sampIsDialogActive and sampIsDialogActive() then
        imgui.DisableInput = true
        return
    end
    if sampIsChatInputActive and sampIsChatInputActive() then
        imgui.DisableInput = true
        return
    end
    if deskSpectatingNow() and not deskImguiNeedsInput() then
        imgui.DisableInput = true
        return
    end
    imgui.DisableInput = not (deskImguiNeedsInput() == true)
end

-- Desk hook/helper.
function deskIsSpectating()
    return deskInputState.playerSpectating == true
end

-- Desk hook/helper.
function deskSafeRestoreCamera()
    if deskSpectatingNow() then return end
    if restoreCameraJumpcut then pcall(restoreCameraJumpcut) end
end

-- Set Desk Player Lock
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

-- Desk hook/helper.
function deskOpenLocksPlayer()
    if sampIsDialogActive and sampIsDialogActive() then return false end
    return showWindow[0] and not cheatState.airbreak and not deskSpectatingNow()
end

-- Update Desk Input Capture
function updateDeskInputCapture()
    if not showWindow[0] then return end
    deskSyncInputFocusState()
    if deskOpenLocksPlayer() then
        setDeskPlayerLock(true)
    else
        setDeskPlayerLock(false)
    end
    local io = imgui.GetIO and imgui.GetIO()
    local wantKb = deskWindowWantsKeyboard()
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

-- Сброс/отправка очереди.
function flushDirtyConfigNow()
    if type(flushCheckerCatalogNow) == 'function' then
        pcall(flushCheckerCatalogNow)
    end
    if dirtySettings or dirtyThreads then
        pcall(saveConfig)
        dirtySettings = false
        dirtyThreads = false
        lastSettingsSave = os.clock()
        lastThreadsSave = os.clock()
    end
end

-- Hide Desk Window For Capture
function hideDeskWindowForCapture()
    if showWindow[0] then
        showWindow[0] = false
        deskInputState.replyFocused = false
        deskInputState.keyboardStickyUntil = 0
        deskInputState.windowOpenSince = 0
        deskApplyInputPolicy()
    end
end

-- Close Desk Window
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

-- Отправка команды/сообщения на сервер.
function sendGameCmd(cmd)
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
end

-- Get Local Admin Level
function getLocalAdminLevel()
    local lv = tonumber(settings.admin_level) or 3
    return math.max(1, math.min(4, math.floor(lv)))
end

-- Thread Action Target Id
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

