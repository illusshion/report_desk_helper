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
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(14, 12))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))
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
    drawCheatCardTitle('CLICKWARP', '')
    cheatState.uiMarkerWheel[0] = settings.cheats.marker_wheel ~= false
    if deskFormCheckboxRow('\xD2\xE5\xEB\xE5\xEF\xEE\xF0\xF2 \xED\xE0 \xEA\xEE\xEB\xB8\xF1\xE8\xEA\xEE \xEC\xFB\xF8\xE8', cheatState.uiMarkerWheel, function(v)
        settings.cheats.marker_wheel = v and true or false
        if not v and cheatState.marker.active then markerSetMode(false) end
        markDirtySettings()
    end) then end
    imgui.TextColored(col_muted2, uiText('\xD1\xCA\xCC \x97 \xF0\xE5\xE6\xE8\xEC \xB7 \xCB\xCA\xCC \x97 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2 \xB7 \xCF\xCA\xCC \x97 \xEF\xEE\xF1\xE0\xE4\xEA\xE0 \xE2 \xEC\xE0\xF8\xE8\xED\xF3'))
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
    if deskFormCheckboxRow('\xCD \xED\xE0 \xE3\xEE\xEB\xEE\xE2\xE5 \xE2 \xEC\xE0\xF1\xEA\xE5 \xE8 \xCC\xC2\xC4', uiCheatMaskId, function(v)
        ensureCheatsSettings()
        settings.cheats.mask_player_id = v and true or false
        if not v and type(maskIdCleanup) == 'function' then pcall(maskIdCleanup) end
        markDirtySettings()
        flushDirtyConfigNow()
    end, 'mask_id') then end
    drawSettingsHint('\xCF\xEE\xEA\xE0\xE7\xFB\xE2\xE0\xE5\xF2 \xED\xEE\xEC\xE5\xF0 ID \xED\xE0\xE4 \xED\xE8\xEA\xEE\xEC, \xE5\xF1\xEB\xE8 \xED\xE8\xEA \xF2\xB8\xEC\xED\xFB\xE9 \xE8\xEB\xE8 \xED\xE5 \xF7\xE8\xF2\xE0\xE5\xF2\xF1\xFF')
    deskFormPanelEnd()

    imgui.PopStyleVar(2)
    imgui.Dummy(imgui.ImVec2(0, 10))
    local btnW = math.min(200, math.max(140, imgui.GetContentRegionAvail().x - 8))
    imgui.SetCursorPosX(math.max(0, (imgui.GetContentRegionAvail().x - btnW) * 0.5))
    deskFormPushBindButtonStyle()
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 8)
    if imgui.Button(uiText('\xD1\xE1\xF0\xEE\xF1 \xE1\xE8\xED\xE4\xEE\xE2') .. '##cheats_rst', imgui.ImVec2(btnW, DESK_BIND_ROW_H or DESK_FORM_ROW_H)) then
        settings.cheats = defaultCheatsSettings()
        ensureCheatsSettings()
        syncCheatsUiFromSettings()
        markDirtySettings()
        flushDirtyConfigNow()
    end
    imgui.PopStyleVar()
    deskFormPopBindButtonStyle()

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

-- /sp без UI скрипта: камерой управляет SAMP, imgui/SP-HUD мышь не трогают.
function deskSpectateCameraOwnsInput()
    if not deskSpectatingNow() then return false end
    if showWindow[0] then return false end
    return true
end

_G.deskSpectateCameraOwnsInput = deskSpectateCameraOwnsInput

function deskSpectateOverlayInputAllowed()
    if showWindow[0] then return false end
    if deskSpectateCameraOwnsInput() then return false end
    return true
end

_G.deskSpectateOverlayInputAllowed = deskSpectateOverlayInputAllowed

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
    if showWindow[0] or (type(deskAnyBindCapture) == 'function' and deskAnyBindCapture()) then
        return true
    end
    if deskSpectateCameraOwnsInput() then
        return false
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
        local sp = deskSpectateStats
        if sp.isHudDragActive and sp.isHudDragActive() then return true end
        if sp.wantsHudInput and sp.wantsHudInput() then return true end
        if sp.isKeysHudDragActive and sp.isKeysHudDragActive() then return true end
        if sp.wantsKeysHudInput and sp.wantsKeysHudInput() then return true end
        if sp.wantsSpMenuInput and sp.wantsSpMenuInput() then return true end
        if sp.wantsVehicleHudInput and sp.wantsVehicleHudInput() then return true end
    end
    if type(exactTimeWantsImguiInput) == 'function' and exactTimeWantsImguiInput() then
        return true
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
    if deskIsSpectateCameraMode(cm) then
        deskInputState.spectateWantCursorMode = cm
        return
    end
    if CMODE_DISABLED ~= nil and cm == CMODE_DISABLED then
        return
    end
end

-- Desk hook/helper.
function deskSpectateHudWantsInput()
    if deskSpectateStats.isHudDragActive and deskSpectateStats.isHudDragActive() then return true end
    if deskSpectateStats.isKeysHudDragActive and deskSpectateStats.isKeysHudDragActive() then return true end
    if deskSpectateStats.wantsKeysHudInput and deskSpectateStats.wantsKeysHudInput() then return true end
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
    if deskSampDialogActive() then return true end
    return false
end

function deskRestoreSpectateCamera()
    deskInputState.spectateUiModeActive = false
    setDeskPlayerLock(false)
    if not deskSpectatingNow() then return end
    if sampSetCursorMode then
        local want = deskSpectateCameraMode()
        if want then pcall(sampSetCursorMode, want) end
    end
    pcall(function()
        if sampToggleCursor then sampToggleCursor(false) end
        if showCursor then showCursor(false) end
        local io = imgui and imgui.GetIO and imgui.GetIO()
        if io then io.MouseDrawCursor = false end
    end)
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

local function deskResetSpHudPointers()
    if type(deskSpectateStats) ~= 'table' then return end
    if deskSpectateStats.resetSpHudPointers then
        pcall(deskSpectateStats.resetSpHudPointers)
    elseif deskSpectateStats.resetHudDrag then
        pcall(deskSpectateStats.resetHudDrag)
    end
end

function deskEnsureCameraAfterPanelClose()
    deskClearImguiCaptureAfterPanel()
    setDeskPlayerLock(false)
    deskInputState.spectateUiModeActive = false
    deskInputState.keyboardStickyUntil = 0
    deskWantsKeyboard = false
    deskResetSpHudPointers()
    if deskSpectatingNow() then
        deskRestoreSpectateCamera()
    elseif not deskSpectateCameraBlocked() then
        deskRestoreNormalGameCamera()
    end
    if imgui and imgui.DisableInput ~= nil and deskSpectateCameraOwnsInput() then
        imgui.DisableInput = true
    end
    updateMimguiGameInputPassthrough()
end

-- mimgui HideCursor: курсор только у открытого desk / hover HUD вне /sp.
function deskMimguiHideCursor(wantsHudCursor)
    if showWindow[0] then return false end
    if wantsHudCursor and not deskSpectatingNow() then return false end
    return true
end

-- Desk hook/helper.
function deskEnableUiCursorForSamp()
    if CMODE_DISABLED == nil or not sampSetCursorMode then return end
    if sampGetCursorMode and sampGetCursorMode() == CMODE_DISABLED then return end
    pcall(sampSetCursorMode, CMODE_DISABLED)
end

-- Desk hook/helper.
function deskEnsureUiCursorForOpenPanel()
    if not showWindow[0] then return end
    if deskInputState.replyInputActive then return end
    if deskImguiTypingActive() or deskInputState.replyFocused then return end
    if deskSpectateCameraBlocked() then return end
    deskEnableUiCursorForSamp()
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
    if deskSpectatingNow() then
        deskRememberSpectateCursorMode()
        deskInputState.spectateUiModeActive = true
    end
    local winFrame = deskCache.deskWindowFrame or deskCache.mainPanelFrame
    if winFrame then
        winFrame.HideCursor = false
        winFrame.LockPlayer = false
    end
    deskEnableUiCursorForSamp()
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
    if deskSpectateStats.isKeysHudDragActive and deskSpectateStats.isKeysHudDragActive() then return true end
    if deskSpectateStats.wantsKeysHudInput and deskSpectateStats.wantsKeysHudInput() then return true end
    if type(checkerIsHudDragActive) == 'function' and checkerIsHudDragActive() then return true end
    if type(checkerHudWantsInput) == 'function' and checkerHudWantsInput() then return true end
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
function deskDeskOrAnsUiOpen()
    return showWindow[0]
end

-- Активный SAMP-диалог (кроме подавленного оверлеем /c 60).
function deskSampDialogActive()
    if type(exactTimeWantsImguiInput) == 'function' and exactTimeWantsImguiInput() then
        return false
    end
    return sampIsDialogActive and sampIsDialogActive() or false
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
        if deskDeskOrAnsUiOpen() then
            if (sampIsChatInputActive and sampIsChatInputActive()) or deskSampDialogActive() then
                hookObj(this)
            end
            return
        end
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
    if sampIsChatInputActive and sampIsChatInputActive() then return end
    if deskSampDialogActive() then return end
    pcall(deskInstallSampInputEnableHook)
    if type(sampSetChatInputEnabled) == 'function' then
        pcall(sampSetChatInputEnabled, false)
    end
end

-- Запасной слой: consumeWindowMessage для лаунчеров, которые обходят sampSetChatInputEnabled.
function deskShouldBlockSampChatKey(msg, wparam)
    if not deskDeskOrAnsUiOpen() then return false end
    if sampIsChatInputActive and sampIsChatInputActive() then return false end
    if deskSampDialogActive() and not showWindow[0] then return false end
    if not deskCache or not deskCache.wm then return false end
    if type(deskAnyBindCapture) == 'function' and deskAnyBindCapture() then return false end
    msg = tonumber(msg) or 0
    wparam = tonumber(wparam) or 0
    local vkReturn = (vkeys and vkeys.VK_RETURN) or 0x0D
    if wparam == vkReturn or wparam == 0x0D then return false end
    if deskSampTextMsgs[msg] then
        return showWindow[0] == true
    end
    local wm = deskCache.wm
    if msg == wm.KEYDOWN or msg == wm.SYSKEYDOWN or msg == wm.KEYUP or msg == wm.SYSKEYUP then
        if type(deskPassesGameKey) == 'function' and deskPassesGameKey(wparam) then return false end
        if wm.CHAT_KEYS[wparam] then return true end
        if showWindow[0] then return true end
    end
    return false
end

-- Desk hook/helper.
function deskConsumeSampChatKey(msg)
    msg = tonumber(msg) or 0
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
    return false
end

-- Desk hook/helper.
function deskWarmupMutesGameInput()
    return false
end

-- Register Desk Chat Wm Handler
function registerDeskChatWmHandler()
    deskWmDispatch.register('chat', 90, function(msg, wparam, lparam)
        if deskDeskOrAnsUiOpen() and deskShouldBlockSampChatKey(msg, wparam) then
            deskConsumeSampChatKey(msg)
            return true
        end
    end)
end

-- Update Mimgui Game Input Passthrough
function updateMimguiGameInputPassthrough()
    if not imgui or imgui.DisableInput == nil then return end

    if deskSpectateCameraOwnsInput() then
        local allow = false
        if type(deskSpectateStats) == 'table' then
            local sp = deskSpectateStats
            if sp.wantsKeysHudInput and sp.wantsKeysHudInput() then allow = true end
            if sp.isKeysHudDragActive and sp.isKeysHudDragActive() then allow = true end
        end
        imgui.DisableInput = not allow
        return
    end

    local needsInput = deskImguiNeedsInput() == true
    if deskDeskOrAnsUiOpen() then
        imgui.DisableInput = not needsInput
        return
    end
    if deskSampDialogActive() then
        imgui.DisableInput = true
        return
    end
    if sampIsChatInputActive and sampIsChatInputActive() then
        imgui.DisableInput = true
        return
    end
    imgui.DisableInput = not needsInput
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
    if deskSampDialogActive() then return false end
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
    if not wantKb and io and io.WantTextInput then
        wantKb = true
    end
    if not wantKb and imgui.IsAnyItemActive and imgui.IsAnyItemActive() then
        wantKb = true
    end
    local wantMouse = showWindow[0] == true
    if not wantMouse and io and io.WantCaptureMouse then wantMouse = true end
    if not wantMouse and imgui.IsWindowHovered and imgui.HoveredFlags
            and imgui.IsWindowHovered(imgui.HoveredFlags.AnyWindow) then
        wantMouse = true
    end
    deskWantsKeyboard = wantKb or wantMouse
    if imgui.CaptureKeyboardFromApp then imgui.CaptureKeyboardFromApp(wantKb) end
    if imgui.CaptureMouseFromApp then imgui.CaptureMouseFromApp(wantMouse) end
    deskEnsureUiCursorForOpenPanel()
end

-- Сброс/отправка очереди.
function flushDirtyConfigNow()
    if type(cancelScheduledConfigFlush) == 'function' then
        cancelScheduledConfigFlush()
    end
    if type(flushCheckerCatalogNow) == 'function' then
        pcall(flushCheckerCatalogNow)
    end
    if dirtySettings or dirtyThreads then
        local okSave, saved = pcall(saveConfig)
        if okSave and saved then
            lastSettingsSave = os.clock()
            lastThreadsSave = os.clock()
        elseif not okSave then
            print('[Report Desk] save: ' .. tostring(saved))
        end
    end
end

-- Close Desk Window
function closeDeskWindow()
    local wasOpen = showWindow[0] or deskInputState.panelOpenPrev
    showWindow[0] = false
    if not wasOpen then return end
    if type(syncCmdBindEditorIfDirty) == 'function' then
        pcall(syncCmdBindEditorIfDirty)
    end
    deskResetHotkeyDebounce((type(settings) == 'table' and settings.hotkey) or vkeys.VK_F7)
    finishDeskBindCapture()
    deskInputState.replyFocused = false
    deskInputState.replyInputActive = false
    deskInputState.focusReplyNext = false
    deskInputState.focusReplyReason = nil
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
    if dirtySettings or dirtyThreads then
        flushDirtyConfigNow()
    end
end

-- Отправка команды/сообщения на сервер.
function sendGameCmd(cmd)
    cmd = trim(cmd or '')
    local stId = cmd:match('^st%s+(%d+)$')
    if stId then
        deskSpectateStats.markPendingSt(tonumber(stId))
    end
    releaseDeskInputCapture(true)
    closeDeskWindow()
    if sendMenuOutbound then
        sendMenuOutbound(cmd)
    else
        local spId = cmd:match('^sp%s+(%d+)%s*$')
        if spId and deskSpectateStats.markPendingSpCommand then
            deskSpectateStats.markPendingSpCommand(tonumber(spId), '')
        end
        sendChat(cmd)
    end
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

