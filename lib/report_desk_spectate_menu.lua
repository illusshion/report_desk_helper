--[[ Модуль: кастомное ImGui меню действий /sp. ]]
local M = {}

pcall(function() require 'lib.moonloader' end)

local imgui = require 'mimgui'
local spTheme = require 'report_desk_sp_theme'

local SP_MENU_W = 218
local SP_BTN_H = 40
local SP_FONT_SCALE = 1.08
local SAMP_BASE_W = 640.0
local SAMP_BASE_H = 480.0

local SP_ACTIONS = {
    { key = 'exit_top', label = '\xC2\xFB\xF5\xEE\xE4', cmd = 'sp', off = true },
    { key = 'slap',     label = '\xD1\xEB\xE0\xEF\xED\xF3\xF2\xFC', cmd = 'slap' },
    { key = 'tow',      label = '\xC4\xEE\xF1\xF2\xE0\xF2\xFC \xE8\xE7 \xE2\xEE\xE4\xFB', cmd = 'tr' },
    { key = 'stats',    label = '\xD1\xF2\xE0\xF2\xE8\xF1\xF2\xE8\xEA\xE0', cmd = 'st' },
    { key = 'dgun',     label = 'DGUN', cmd = 'weap' },
    { key = 'update',   label = '\xCE\xE1\xED\xEE\xE2\xE8\xF2\xFC', cmd = 'sp', refresh = true },
    { key = 'exit_bot', label = '\xC2\xFB\xF5\xEE\xE4', cmd = 'sp', off = true },
}

local displayActions = SP_ACTIONS

-- Тихие UI-звуки (world): покупка в магазине / мягкий pickup.
local SOUND_WORLD_NAV = 1054
local SOUND_WORLD_SELECT = 1150
local SOUND_FE_NAV = 4
local SOUND_FE_SELECT = 3

local deps = {}
local KEY_DEBOUNCE_SEC = 0.14

local function trim(s)
    if deps.trim then return deps.trim(s) end
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

local DIALOG_ECHO_SUPPRESS_SEC = 0.4
local ACTIVATE_DEBOUNCE_SEC = 0.15
local dialogEchoSuppressUntil = 0
local activateDebounceUntil = 0

-- First Menu Selection
local function firstMenuSelection()
    return 1
end

local menuState = {
    placed = false,
    selected = 1,
    lastPhase = '',
    drag = { active = false, offX = 0, offY = 0, startX = 0, startY = 0 },
}
local serverLayout = nil
local keyLatchAt = {}
local NAV_VKS = nil
local pendingAction = nil
local pendingDragSave = nil
local flushScheduled = false

-- Menu Input Blocked
local function menuInputBlocked()
    if deps.isAnsBarOpen and deps.isAnsBarOpen() then return true end
    if deps.isGameTextInputActive and deps.isGameTextInputActive() then return true end
    if deps.isDeskTypingActive and deps.getShowWindow and deps.getShowWindow()
            and deps.isDeskTypingActive() then
        return true
    end
    return false
end

-- Публичный API модуля.
function M.menuCapturesKeyboard()
    if not M.shouldShowMenu() then return false end
    if menuInputBlocked() then return false end
    return true
end

-- Menu Keyboard Blocked
local function menuKeyboardBlocked()
    return not M.menuCapturesKeyboard()
end

-- Публичный API модуля.
function M.suppressDialogEcho(sec)
    dialogEchoSuppressUntil = os.clock() + (tonumber(sec) or DIALOG_ECHO_SUPPRESS_SEC)
end

-- Публичный API модуля.
function M.suppressInput(sec)
    M.suppressDialogEcho(sec)
end

-- Публичный API модуля.
function M.isDialogEchoSuppressed()
    return os.clock() < dialogEchoSuppressUntil
end

-- Публичный API модуля.
function M.isInputSuppressed()
    return M.isDialogEchoSuppressed()
end

-- Is Activate Debounced
local function isActivateDebounced()
    return os.clock() < activateDebounceUntil
end

-- Touch Activate Debounce
local function touchActivateDebounce()
    activateDebounceUntil = os.clock() + ACTIVATE_DEBOUNCE_SEC
end

-- Публичный API модуля.
function M.resetMenuSelection()
    menuState.selected = firstMenuSelection()
    keyLatchAt = {}
    keyDownPrev = {}
end

-- Публичный API модуля.
function M.resetMenuState()
    menuState.placed = false
    menuState.selected = firstMenuSelection()
    menuState.lastPhase = ''
    menuState.drag.active = false
    menuState.hovered = false
    keyLatchAt = {}
    pendingAction = nil
    pendingDragSave = nil
    flushScheduled = false
end

-- Get Settings
local function getSettings()
    if deps.getSettings then
        local s = deps.getSettings()
        if s then return s end
    end
    return rawget(_G, 'settings')
end

-- Ui Enabled
local function uiEnabled(settings)
    settings = settings or getSettings()
    if not settings then return true end
    return settings.spectate_sp_ui ~= false
end

-- Get Target Id
local sessionMod
local function getSessionMod()
    if not sessionMod then
        pcall(function() sessionMod = require 'report_desk_spectate_session' end)
    end
    return sessionMod
end

local function getTargetId()
    if deps.getTargetId then
        local id = tonumber(deps.getTargetId()) or -1
        if id >= 0 then return id end
    end
    local session = getSessionMod()
    if session and session.getTargetId then
        return tonumber(session.getTargetId()) or -1
    end
    return -1
end

-- Get Target Nick
local function getTargetNick()
    if deps.getTargetNick then
        local nk = deps.getTargetNick()
        if nk and nk ~= '' then return nk end
    end
    return ''
end

-- Screen Size
local function screenSize()
    local sw, sh = 1280, 720
    if imgui.GetIO then
        local io = imgui.GetIO()
        if io and io.DisplaySize and io.DisplaySize.x > 0 then
            sw = io.DisplaySize.x
            sh = io.DisplaySize.y
        end
    end
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    return sw, sh
end

-- Samp To Screen
local function sampToScreen(x, y)
    local sw, sh = screenSize()
    return (tonumber(x) or 0) * (sw / SAMP_BASE_W), (tonumber(y) or 0) * (sh / SAMP_BASE_H)
end

-- Menu Sounds Enabled
local function menuSoundsEnabled()
    local s = getSettings()
    if not s then return false end
    local v = s.spectate_sp_menu_sound
    return v == true or v == 1
end

-- Player Sound Pos
local function playerSoundPos()
    local x, y, z = 0.0, 0.0, 0.0
    if PLAYER_PED and doesCharExist and doesCharExist(PLAYER_PED) and getCharCoordinates then
        x, y, z = getCharCoordinates(PLAYER_PED)
    end
    return x, y, z
end

-- Play World Sound
local function playWorldSound(soundId)
    soundId = tonumber(soundId)
    if not soundId or not addOneOffSound then return false end
    local x, y, z = playerSoundPos()
    addOneOffSound(x, y, z, soundId)
    return true
end

-- Play Menu Sound Kind
local function playMenuSoundKind(kind, force)
    if not force and not menuSoundsEnabled() then return end
    local worldId = SOUND_WORLD_NAV
    local feId = SOUND_FE_NAV
    if kind == 'select' then
        worldId = SOUND_WORLD_SELECT
        feId = SOUND_FE_SELECT
    end
    pcall(function()
        if playWorldSound(worldId) then return end
        if deps.playFrontEndSound then
            deps.playFrontEndSound(feId)
        elseif playSoundFrontEnd then
            playSoundFrontEnd(feId)
        end
    end)
end

-- Play Nav Sound
local function playNavSound()
    playMenuSoundKind('nav')
end

-- Play Select Sound
local function playSelectSound()
    playMenuSoundKind('select')
end

-- Публичный API модуля.
function M.previewMenuSound()
    playMenuSoundKind('nav', true)
end

-- Ensure Nav Vks
local function ensureNavVks()
    if NAV_VKS then return NAV_VKS end
    local v = deps.vkeys
    if not v then return nil end
    NAV_VKS = {
        v.VK_UP, v.VK_DOWN, v.VK_W, v.VK_S,
        v.VK_NUMPAD8, v.VK_NUMPAD2,
        v.VK_SPACE,
    }
    return NAV_VKS
end

-- Публичный API модуля.
function M.isMenuNavKey(vk)
    vk = tonumber(vk)
    if not vk then return false end
    local keys = ensureNavVks()
    if not keys then return false end
    for _, k in ipairs(keys) do
        if vk == k then return true end
    end
    return false
end

-- Публичный API модуля.
function M.isHovered()
    return menuState.hovered == true or menuState.drag.active
end

-- Публичный API модуля.
function M.clearPointerHover()
    menuState.hovered = false
end

-- Публичный API модуля.
function M.wantsInput()
    if deps.isAnsBarOpen and deps.isAnsBarOpen() then
        return menuState.drag.active == true
    end
    if type(_G.deskSpectateCameraOwnsInput) == 'function' and _G.deskSpectateCameraOwnsInput() then
        return menuState.drag.active == true
    end
    if menuState.drag.active then return true end
    if menuState.hovered then return true end
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin then return pin(menuState.menuRect) end
    return false
end

-- Публичный API модуля.
function M.applyServerLayout(layout)
    if not layout then return end
    serverLayout = layout
    displayActions = SP_ACTIONS
end

-- Публичный API модуля.
function M.clearServerLayout()
    serverLayout = nil
    displayActions = SP_ACTIONS
end

-- Push Menu Chrome
local function pushMenuChrome(col_accent, col_accent_dim)
    spTheme.pushOverlayChrome()
end

-- Pop Menu Chrome
local function popMenuChrome()
    spTheme.popOverlayChrome()
end

-- Push Btn Style
local function pushBtnStyle(selected)
    local col_accent_dim = deps.col_accent_dim
    local col_accent = deps.col_accent
    local col_label = deps.col_label
    if selected then
        imgui.PushStyleColor(imgui.Col.Button, col_accent or imgui.ImVec4(0.58, 0.40, 0.82, 0.82))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, col_accent or imgui.ImVec4(0.66, 0.48, 0.90, 0.92))
        imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim or imgui.ImVec4(0.48, 0.34, 0.68, 0.95))
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.13, 0.11, 0.18, 0.32))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.16, 0.28, 0.48))
        imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim or imgui.ImVec4(0.45, 0.32, 0.62, 0.65))
    end
    imgui.PushStyleColor(imgui.Col.Text, col_label or imgui.ImVec4(0.94, 0.94, 0.98, 1.0))
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 9)
    imgui.PushStyleVarVec2(imgui.StyleVar.FramePadding, imgui.ImVec2(10, 7))
end

-- Pop Btn Style
local function popBtnStyle()
    imgui.PopStyleVar(2)
    imgui.PopStyleColor(4)
end

local lastServerCmd = ''
local lastServerCmdAt = 0
local SERVER_CMD_DEDUPE_SEC = 0.5

-- Отправка команды/сообщения на сервер.
local function sendServerCmd(cmd)
    cmd = tostring(cmd or ''):match('^%s*(.-)%s*$') or ''
    if cmd == '' then return end
    local now = os.clock()
    local base = cmd:match('^(%S+)') or cmd
    local noDedupe = (base == 'st' or base == 'tr' or base == 'slap' or base == 'stats' or base == 'weap')
    if not noDedupe and cmd == lastServerCmd and now - lastServerCmdAt < SERVER_CMD_DEDUPE_SEC then
        return
    end
    lastServerCmd = cmd
    lastServerCmdAt = now
    if deps.sendMenuOutbound then
        pcall(deps.sendMenuOutbound, cmd)
    elseif deps.sendChat then
        pcall(deps.sendChat, cmd)
    elseif deps.queueOutbound then
        pcall(deps.queueOutbound, cmd)
    end
end

-- Run Action
local function runAction(action, targetId, source)
    if not action then return end
    targetId = tonumber(targetId)
    if action.cmd == 'st' then
        if not targetId or targetId < 0 then return end
        if deps.requestStats then
            deps.requestStats(targetId, { force = true, showDialog = true })
        else
            if deps.markPendingSt then pcall(deps.markPendingSt, targetId, { showDialog = true }) end
            sendServerCmd('st ' .. tostring(targetId))
        end
        return
    end
    if action.cmd == 'tr' then
        if not targetId or targetId < 0 then return end
        if deps.sendTrPlayer then
            pcall(deps.sendTrPlayer, targetId)
        else
            sendServerCmd('tr ' .. tostring(targetId))
        end
        return
    end
    if action.cmd == 'slap' then
        if not targetId or targetId < 0 then return end
        if deps.sendSlapPlayer then
            pcall(deps.sendSlapPlayer, targetId)
        else
            sendServerCmd('slap ' .. tostring(targetId))
        end
        return
    end
    if action.cmd == 'weap' then
        if not targetId or targetId < 0 then return end
        sendServerCmd('weap ' .. tostring(targetId))
        return
    end
    pcall(function()
        touchActivateDebounce()
        if action.off then
            if deps.onSpLocalExit then pcall(deps.onSpLocalExit) end
            sendServerCmd('sp')
            return
        end
        if action.refresh then
            if not targetId or targetId < 0 then return end
            sendServerCmd('sp ' .. tostring(targetId))
            if deps.requestStats then
                pcall(deps.requestStats, targetId, { force = true })
            end
            return
        end
        if not targetId or targetId < 0 then return end
        sendServerCmd(action.cmd .. ' ' .. tostring(targetId))
    end)
end

-- Dispatch Action
local function dispatchAction(action, targetId, source)
    if not action then return end
    source = source or 'kb'
    if isActivateDebounced() then return end
    touchActivateDebounce()
    if source == 'kb' then
        M.suppressInput(0.28)
    end
    playSelectSound()
    runAction(action, targetId, source)
end

-- Публичный API модуля.
function M.flushPendingAction()
    if not pendingAction and not pendingDragSave then return end
    if flushScheduled then return end
    if not lua_thread or not lua_thread.create then
        local drag = pendingDragSave
        pendingDragSave = nil
        if drag then
            local settings = getSettings()
            if settings then
                settings.spectate_sp_ui_custom = true
                settings.spectate_sp_ui_x = drag.x
                settings.spectate_sp_ui_y = drag.y
                if deps.markDirtySettings then pcall(deps.markDirtySettings) end
                if deps.flushDirtyConfigNow then pcall(deps.flushDirtyConfigNow) end
            end
        end
        if pendingAction then
            local pa = pendingAction
            pendingAction = nil
            runAction(pa.action, pa.targetId, pa.source)
        end
        return
    end
    flushScheduled = true
    lua_thread.create(function()
        wait(0)
        flushScheduled = false
        local drag = pendingDragSave
        pendingDragSave = nil
        if drag then
            local settings = getSettings()
            if settings then
                settings.spectate_sp_ui_custom = true
                settings.spectate_sp_ui_x = drag.x
                settings.spectate_sp_ui_y = drag.y
                if deps.markDirtySettings then pcall(deps.markDirtySettings) end
                if deps.flushDirtyConfigNow then pcall(deps.flushDirtyConfigNow) end
            end
        end
        if not pendingAction then return end
        local pa = pendingAction
        pendingAction = nil
        runAction(pa.action, pa.targetId, pa.source)
    end)
end

-- Menu Rect On Screen
local function menuRectOnScreen(hx, hy, winW, winH, sw, sh, pivotX)
    winW = math.max(SP_MENU_W, tonumber(winW) or SP_MENU_W)
    winH = math.max(80, tonumber(winH) or 200)
    local left, right
    if pivotX == 1 then
        left = hx - winW
        right = hx
    else
        left = hx
        right = hx + winW
    end
    return left >= 8 and hy >= 8 and right <= sw - 8 and hy + winH <= sh - 8
end

-- Clamp Menu Pos
local function clampMenuPos(hx, hy, winW, winH, sw, sh, pivotX)
    winW = math.max(SP_MENU_W, tonumber(winW) or SP_MENU_W)
    winH = math.max(80, tonumber(winH) or 200)
    if pivotX == 1 then
        hx = math.max(winW + 8, math.min(hx, sw - 8))
    else
        hx = math.max(8, math.min(hx, sw - winW - 8))
    end
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

-- Resolve Menu Pos
local function resolveMenuPos(settings, estH)
    local sw, sh = screenSize()
    estH = math.max(100, tonumber(estH) or 280)
    local rightInset = 12
    local defaultY = math.floor(sh * 0.34)

    local hy = tonumber(settings.spectate_sp_ui_y)
    if hy == nil or hy < 8 or hy > sh - 60 then
        hy = defaultY
    end

    local posX, pivotX

    if settings.spectate_sp_ui_custom == true then
        local rawX = tonumber(settings.spectate_sp_ui_x)
        if rawX == nil then
            posX = sw - rightInset
            pivotX = 1
        elseif rawX <= 0 then
            posX = sw + rawX
            pivotX = 1
        elseif rawX >= sw - SP_MENU_W - 8 then
            posX = rawX
            pivotX = 0
        else
            posX = rawX
            pivotX = 0
        end
    else
        posX = sw - rightInset
        pivotX = 1
    end

    if pivotX == 1 then
        posX, hy = clampMenuPos(posX, hy, SP_MENU_W, estH, sw, sh, 1)
    else
        posX, hy = clampMenuPos(posX, hy, SP_MENU_W, estH, sw, sh, 0)
    end
    if not menuRectOnScreen(posX, hy, SP_MENU_W, estH, sw, sh, pivotX) then
        posX = sw - rightInset
        pivotX = 1
        hy = defaultY
        posX, hy = clampMenuPos(posX, hy, SP_MENU_W, estH, sw, sh, 1)
    end
    return posX, hy, pivotX, sw, sh
end

-- Key Debounced
local function keyDebounced(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    local now = os.clock()
    local last = keyLatchAt[vk]
    if last and now - last < KEY_DEBOUNCE_SEC then return false end
    keyLatchAt[vk] = now
    return true
end

-- Is Activate Key
local function isActivateKey(vk, vkeys)
    return vk == vkeys.VK_SPACE
end

-- Move Selection
local function moveSelection(delta)
    local actions = displayActions or SP_ACTIONS
    local n = #actions
    if n <= 0 then return false end
    local prev = menuState.selected or 1
    menuState.selected = math.max(1, math.min(n, prev + delta))
    if menuState.selected ~= prev then
        playNavSound()
        return true
    end
    return false
end

-- Публичный API модуля.
function M.handleMenuKey(vk)
    if not M.menuCapturesKeyboard() then return false end
    local vkeys = deps.vkeys
    if not vkeys then return false end
    vk = tonumber(vk)
    if not vk then return false end

    menuState.selected = menuState.selected or 1

    if vk == vkeys.VK_UP or vk == vkeys.VK_W or vk == vkeys.VK_NUMPAD8 then
        moveSelection(-1)
        return true
    end
    if vk == vkeys.VK_DOWN or vk == vkeys.VK_S or vk == vkeys.VK_NUMPAD2 then
        moveSelection(1)
        return true
    end
    if isActivateKey(vk, vkeys) then
        if M.isDialogEchoSuppressed() then return false end
        if isActivateDebounced() then return false end
        dispatchAction(displayActions[menuState.selected], getTargetId(), 'kb')
        return true
    end
    return false
end

-- Header Color U32
local function headerColorU32(col)
    if imgui.ColorConvertFloat4ToU32 then
        return imgui.ColorConvertFloat4ToU32(col)
    end
    return 0xFFFFFFFF
end

-- Draw Shadow Text
local function drawShadowText(dl, x, y, text, col, shadowCol)
    if not dl or not text or text == '' then return end
    shadowCol = shadowCol or imgui.ImVec4(0.0, 0.0, 0.0, 0.92)
    dl:AddText(imgui.ImVec2(x + 1, y + 1), headerColorU32(shadowCol), text)
    dl:AddText(imgui.ImVec2(x, y), headerColorU32(col), text)
end

local MENU_HEADER_NICK = imgui.ImVec4(1.0, 1.0, 1.0, 1.0)
local MENU_HEADER_ID = imgui.ImVec4(0.93, 0.95, 1.0, 1.0)
local MENU_HEADER_SHADOW = imgui.ImVec4(0.0, 0.0, 0.0, 0.94)
local MENU_HEADER_BG = imgui.ImVec4(0.0, 0.0, 0.0, 0.62)

-- Draw Menu Header
local function drawMenuHeader(nick, targetId, uiTextFn, baseFontScale)
    baseFontScale = tonumber(baseFontScale) or SP_FONT_SCALE
    local col_accent = deps.col_accent or imgui.ImVec4(0.62, 0.44, 0.86, 1.0)
    local startY = imgui.GetCursorPosY()
    spTheme.drawPlayerHeader(
        nick,
        targetId >= 0 and targetId or nil,
        imgui.ImVec4(0.98, 0.98, 1.0, 1.0),
        uiTextFn,
        { accentCol = col_accent, scale = baseFontScale * 1.08 })
    local endY = imgui.GetCursorPosY()
    return math.max(22, endY - startY)
end

-- Публичный API модуля.
function M.drawMenu(settings, force)
    settings = settings or getSettings() or {}
    if not displayActions then displayActions = SP_ACTIONS end
    if not force and not M.shouldShowMenu(settings) then
        menuState.menuRect = nil
        keyLatchAt = {}
        if deps.setMenuHovered then pcall(deps.setMenuHovered, false) end
        return
    end

    local targetId = getTargetId()
    local uiTextFn = deps.uiText or function(s) return s end
    local col_muted2 = deps.col_muted2 or imgui.ImVec4(0.55, 0.55, 0.62, 0.85)
    local col_label = deps.col_label or imgui.ImVec4(0.95, 0.95, 0.98, 1.0)
    local col_accent = deps.col_accent or imgui.ImVec4(0.62, 0.44, 0.86, 1.0)
    local col_accent_dim = deps.col_accent_dim or imgui.ImVec4(0.45, 0.32, 0.62, 0.9)

    local estH = 50 + #displayActions * (SP_BTN_H + 5)
    local posX, hy, pivotX, sw, sh = resolveMenuPos(settings, estH)
    if menuState.drag.active then
        posX = menuState.drag.offX
        hy = menuState.drag.offY
        pivotX = 0
        posX = math.max(8, math.min(posX, sw - SP_MENU_W - 8))
        hy = math.max(8, math.min(hy, sh - estH - 8))
    end

    local wantInput = M.wantsInput()
    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoNav then
        flags = flags + imgui.WindowFlags.NoNav
    end
    if imgui.WindowFlags.NoCollapse then
        flags = flags + imgui.WindowFlags.NoCollapse
    end
    if not wantInput and imgui.WindowFlags.NoInputs then
        flags = flags + imgui.WindowFlags.NoInputs
    end

    imgui.SetNextWindowBgAlpha(spTheme.HUD_OVERLAY_ALPHA or 0.80)
    imgui.SetNextWindowSize(imgui.ImVec2(SP_MENU_W, 0), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(posX, hy), imgui.Cond.Always, imgui.ImVec2(pivotX, 0))
    menuState.placed = true

    local chromePushed = false
    local began = false
    local fontScaled = false
    local ok, err = pcall(function()
        pushMenuChrome(col_accent, col_accent_dim)
        chromePushed = true
        began = imgui.Begin('###desk_sp_menu_v398', nil, flags)
        if not began then return end
        spTheme.drawPanelFrame()

        if imgui.SetWindowFontScale then
            imgui.SetWindowFontScale(SP_FONT_SCALE)
            fontScaled = true
        end

        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        menuState.menuRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }
        menuState.hovered = false

        if not (deps.isAnsBarOpen and deps.isAnsBarOpen())
                and not (type(_G.deskSpectateCameraOwnsInput) == 'function' and _G.deskSpectateCameraOwnsInput()) then
            local posFn = type(_G.deskWin32MousePos) == 'function' and _G.deskWin32MousePos
                or type(deskWin32MousePos) == 'function' and deskWin32MousePos
            local mx, my = posFn and posFn()
            if mx and wp and ww and wh then
                menuState.hovered = mx >= wp.x and mx < wp.x + ww
                    and my >= wp.y and my < wp.y + wh
            end
        end
        if deps.setMenuHovered then pcall(deps.setMenuHovered, menuState.hovered or menuState.drag.active) end

        local headerY = imgui.GetCursorPosY()
        local nick = getTargetNick()
        local headerH = drawMenuHeader(nick, targetId, uiTextFn, SP_FONT_SCALE)
        headerH = math.max(20, headerH)
        imgui.SetCursorPos(imgui.ImVec2(0, headerY))
        imgui.InvisibleButton('##sp_menu_drag', imgui.ImVec2(-1, headerH))
        if imgui.IsItemHovered() or imgui.IsItemActive() then
            menuState.hovered = true
        end
        if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
            local delta = imgui.GetMouseDragDelta(0)
            if not menuState.drag.active then
                menuState.drag.active = true
                menuState.drag.startX = wp.x
                menuState.drag.startY = wp.y
                serverLayout = nil
                imgui.ResetMouseDragDelta(0)
                delta = imgui.GetMouseDragDelta(0)
            end
            menuState.drag.offX = menuState.drag.startX + delta.x
            menuState.drag.offY = menuState.drag.startY + delta.y
        elseif menuState.drag.active and not imgui.IsMouseDown(0) then
            menuState.drag.active = false
            pendingDragSave = {
                x = math.floor(menuState.drag.offX + 0.5),
                y = math.floor(menuState.drag.offY + 0.5),
            }
        end
        imgui.Dummy(imgui.ImVec2(0, 4))

        menuState.selected = menuState.selected or 1
        if menuState.selected < 1 then menuState.selected = 1 end
        if menuState.selected > #displayActions then menuState.selected = #displayActions end

        for i, action in ipairs(displayActions) do
            pushBtnStyle(i == menuState.selected)
            local clicked = imgui.Button(uiTextFn(action.label), imgui.ImVec2(-1, SP_BTN_H))
            popBtnStyle()
            if clicked and not M.isInputSuppressed() then
                menuState.selected = i
                dispatchAction(action, targetId, 'mouse')
            end
        end
    end)

    if not ok and err then
        print('[Report Desk] sp menu body: ' .. tostring(err))
    end

    if fontScaled and imgui.SetWindowFontScale then
        pcall(imgui.SetWindowFontScale, 1.0)
    end
    if began then
        pcall(imgui.End)
    else
        if not menuState._beginFailLogged then
            menuState._beginFailLogged = true
            print(string.format('[Report Desk] sp menu Begin failed pos=%.0f,%.0f pivot=%d screen=%.0fx%.0f',
                posX, hy, pivotX, sw, sh))
        end
        menuState.placed = false
        if settings.spectate_sp_ui_custom == true then
            settings.spectate_sp_ui_custom = false
            settings.spectate_sp_ui_x = -28
            settings.spectate_sp_ui_y = 0
            if deps.markDirtySettings then pcall(deps.markDirtySettings) end
        end
        if deps.setMenuHovered then pcall(deps.setMenuHovered, false) end
    end
    if menuState._beginFailLogged and began then
        menuState._beginFailLogged = false
    end
    if chromePushed then
        pcall(popMenuChrome)
    end
end

-- Публичный API модуля.
function M.shouldShowMenu(settings)
    if not uiEnabled(settings) then return false end
    return getTargetId() >= 0
end

-- Публичный API модуля.
function M.install(installDeps)
    if type(installDeps) == 'table' then
        for k, v in pairs(installDeps) do
            deps[k] = v
        end
    end
end

return M
