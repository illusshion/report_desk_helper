--[[ Модуль: HUD нажатых клавиш цели /sp (логика sp_plus, стиль Report Desk). ]]
local M = {}

local imgui = require 'mimgui'
local spTheme = require 'report_desk_sp_theme'
local specSession = require 'report_desk_spectate_session'

local HUD_MARGIN = 10
local CAP_ROUND = 6
local COLOR_LERP_SEC = 0.10

local keys = { onfoot = {}, vehicle = {} }
local capAnim = {}
local drag = { active = false, startX = 0, startY = 0, offX = 0, offY = 0 }
local hovered = false
local hudRect = nil
local hudLastW, hudLastH = 320, 80

local sampevRef
local hookPrevPlayerSync
local hookPrevVehicleSync

local uiText, toU32, col_accent, col_accent_dim, col_muted, col_muted2
local markDirtySettings, flushDirtyConfigNow, getSettingsFn, getSpectateTargetId, isSpectatingFn

-- Get Target Id
local function getTargetId()
    if getSpectateTargetId then
        local ok, id = pcall(getSpectateTargetId)
        if ok then return tonumber(id) or -1 end
    end
    return -1
end

-- Is Spectating
local function isSpectating()
    if isSpectatingFn then
        local ok, v = pcall(isSpectatingFn)
        if ok then return v == true end
    end
    if specSession and specSession.isSpectatingMode then
        return specSession.isSpectatingMode()
    end
    return false
end

-- Get Settings
local function getSettings()
    return getSettingsFn and getSettingsFn() or nil
end

-- Color U32
local function colorU32(col)
    if toU32 then return toU32(col) end
    if imgui.ColorConvertFloat4ToU32 then
        return imgui.ColorConvertFloat4ToU32(col)
    end
    return 0xFFFFFFFF
end

-- Bring Vec4
local function bringVec4(from, dest, startTime, duration)
    local timer = os.clock() - startTime
    if timer >= 0 and timer <= duration then
        local count = timer / (duration / 100)
        return imgui.ImVec4(
            from.x + (count * (dest.x - from.x) / 100),
            from.y + (count * (dest.y - from.y) / 100),
            from.z + (count * (dest.z - from.z) / 100),
            from.w + (count * (dest.w - from.w) / 100)
        ), true
    end
    return (timer > duration) and dest or from, false
end

-- Target Char
local function targetChar()
    local id = getTargetId()
    if id < 0 or not sampGetCharHandleBySampPlayerId then return nil end
    local ok, ped = sampGetCharHandleBySampPlayerId(id)
    if ok and ped and doesCharExist and doesCharExist(ped) then
        return ped
    end
    return nil
end

-- Player State Key
local function playerStateKey()
    local ped = targetChar()
    if not ped then return nil end
    if isCharOnFoot and isCharOnFoot(ped) then return 'onfoot' end
    if isCharInAnyCar and isCharInAnyCar(ped) then return 'vehicle' end
    return 'onfoot'
end

-- Update Onfoot Keys
local function updateOnfootKeys(playerId, data)
    if not data then return end
    if playerId ~= getTargetId() then return end
    local k = keys.onfoot
    k.W = (data.upDownKeys == 65408) or nil
    k.A = (data.leftRightKeys == 65408) or nil
    k.S = (data.upDownKeys == 128) or nil
    k.D = (data.leftRightKeys == 128) or nil
    k.Alt = (bit.band(data.keysData or 0, 1024) == 1024) or nil
    k.Shift = (bit.band(data.keysData or 0, 8) == 8) or nil
    k.Space = (bit.band(data.keysData or 0, 32) == 32) or nil
    k.F = (bit.band(data.keysData or 0, 16) == 16) or nil
    k.C = (bit.band(data.keysData or 0, 2) == 2) or nil
    k.RKM = (bit.band(data.keysData or 0, 4) == 4) or nil
    k.LKM = (bit.band(data.keysData or 0, 128) == 128) or nil
end

-- Update Vehicle Keys
local function updateVehicleKeys(playerId, data)
    if not data then return end
    if playerId ~= getTargetId() then return end
    local kd = data.keysData or 0
    local k = keys.vehicle
    k.W = (bit.band(kd, 8) == 8) or nil
    k.A = (data.leftRightKeys == 65408) or nil
    k.S = (bit.band(kd, 32) == 32) or nil
    k.D = (data.leftRightKeys == 128) or nil
    k.H = (bit.band(kd, 2) == 2) or nil
    k.Space = (bit.band(kd, 128) == 128) or nil
    k.Ctrl = (bit.band(kd, 1) == 1) or nil
    k.Alt = (bit.band(kd, 4) == 4) or nil
    k.Q = (bit.band(kd, 256) == 256) or nil
    k.E = (bit.band(kd, 64) == 64) or nil
    k.F = (bit.band(kd, 16) == 16) or nil
    k.Up = (data.upDownKeys == 65408) or nil
    k.Down = (data.upDownKeys == 128) or nil
end

-- Idle Cap Color
local function capIdleCol()
    return imgui.ImVec4(0.13, 0.11, 0.19, 0.72)
end

-- Pressed Cap Color
local function capPressedCol()
    if col_accent then
        return imgui.ImVec4(col_accent.x, col_accent.y, col_accent.z, 0.88)
    end
    return imgui.ImVec4(0.55, 0.38, 0.82, 0.92)
end

-- Border Cap Color
local function capBorderCol(pressed)
    if pressed then
        if col_accent then
            return imgui.ImVec4(col_accent.x, col_accent.y, col_accent.z, 0.95)
        end
        return imgui.ImVec4(0.72, 0.55, 1.0, 0.95)
    end
    if col_accent_dim then
        return imgui.ImVec4(col_accent_dim.x, col_accent_dim.y, col_accent_dim.z, 0.42)
    end
    return imgui.ImVec4(0.45, 0.32, 0.68, 0.38)
end

-- Draw Key Cap
local function drawKeyCap(label, pressed, size)
    label = tostring(label or '')
    size = size or imgui.ImVec2(30, 30)
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local idle = capIdleCol()
    local active = capPressedCol()

    local anim = capAnim[label]
    if not anim then
        anim = { status = pressed, color = pressed and active or idle, timer = nil }
        capAnim[label] = anim
    end
    if pressed ~= anim.status then
        anim.status = pressed
        anim.timer = os.clock()
    end
    if anim.timer then
        local from = pressed and idle or active
        local dest = pressed and active or idle
        anim.color = select(1, bringVec4(from, dest, anim.timer, COLOR_LERP_SEC))
    else
        anim.color = pressed and active or idle
    end

    local a = imgui.ImVec2(p.x, p.y)
    local b = imgui.ImVec2(p.x + size.x, p.y + size.y)
    imgui.Dummy(size)
    dl:AddRectFilled(a, b, colorU32(anim.color), CAP_ROUND)
    if pressed then
        dl:AddRect(a, b, colorU32(capBorderCol(true)), CAP_ROUND, 0, 1.6)
    else
        dl:AddRect(a, b, colorU32(capBorderCol(false)), CAP_ROUND, 0, 1.0)
    end
    local ts = imgui.CalcTextSize(label)
    local tx = p.x + (size.x - ts.x) * 0.5
    local ty = p.y + (size.y - ts.y) * 0.5
    local textCol = pressed and imgui.ImVec4(0.98, 0.97, 1.0, 1.0)
        or (col_muted2 or imgui.ImVec4(0.62, 0.60, 0.72, 0.92))
    dl:AddText(imgui.ImVec2(tx, ty), colorU32(textCol), label)
end

-- Draw Onfoot Layout
local function drawOnfootLayout(stateKeys)
    imgui.BeginGroup()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 35)
    drawKeyCap('W', stateKeys.W ~= nil, imgui.ImVec2(30, 30))
    drawKeyCap('A', stateKeys.A ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('S', stateKeys.S ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('D', stateKeys.D ~= nil, imgui.ImVec2(30, 30))
    imgui.EndGroup()
    imgui.SameLine(0, 14)
    imgui.BeginGroup()
    drawKeyCap('Shift', stateKeys.Shift ~= nil, imgui.ImVec2(72, 30)); imgui.SameLine(0, 4)
    drawKeyCap('Alt', stateKeys.Alt ~= nil, imgui.ImVec2(52, 30))
    drawKeyCap('Space', stateKeys.Space ~= nil, imgui.ImVec2(128, 30))
    imgui.EndGroup()
    imgui.SameLine(0, 10)
    imgui.BeginGroup()
    drawKeyCap('C', stateKeys.C ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('F', stateKeys.F ~= nil, imgui.ImVec2(30, 30))
    drawKeyCap('RM', stateKeys.RKM ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('LM', stateKeys.LKM ~= nil, imgui.ImVec2(30, 30))
    imgui.EndGroup()
end

-- Draw Vehicle Layout
local function drawVehicleLayout(stateKeys)
    imgui.BeginGroup()
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 35)
    drawKeyCap('W', stateKeys.W ~= nil, imgui.ImVec2(30, 30))
    drawKeyCap('A', stateKeys.A ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('S', stateKeys.S ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('D', stateKeys.D ~= nil, imgui.ImVec2(30, 30))
    imgui.EndGroup()
    imgui.SameLine(0, 14)
    imgui.BeginGroup()
    drawKeyCap('Ctrl', stateKeys.Ctrl ~= nil, imgui.ImVec2(62, 30)); imgui.SameLine(0, 4)
    drawKeyCap('Alt', stateKeys.Alt ~= nil, imgui.ImVec2(62, 30))
    drawKeyCap('Space', stateKeys.Space ~= nil, imgui.ImVec2(128, 30))
    imgui.EndGroup()
    imgui.SameLine(0, 10)
    imgui.BeginGroup()
    drawKeyCap('Up', stateKeys.Up ~= nil, imgui.ImVec2(40, 30))
    drawKeyCap('Down', stateKeys.Down ~= nil, imgui.ImVec2(40, 30))
    imgui.EndGroup()
    imgui.SameLine(0, 10)
    imgui.BeginGroup()
    drawKeyCap('H', stateKeys.H ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('F', stateKeys.F ~= nil, imgui.ImVec2(30, 30))
    drawKeyCap('Q', stateKeys.Q ~= nil, imgui.ImVec2(30, 30)); imgui.SameLine(0, 4)
    drawKeyCap('E', stateKeys.E ~= nil, imgui.ImVec2(30, 30))
    imgui.EndGroup()
end

-- Screen Size
local function screenSize()
    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    return sw, sh
end

-- Default Pos
local function defaultHudPos(sw, sh, winW, winH)
    winW = math.max(200, tonumber(winW) or hudLastW or 320)
    winH = math.max(48, tonumber(winH) or hudLastH or 80)
    return math.floor(sw * 0.5 - winW * 0.5 + 0.5), math.floor(sh - winH - 100 + 0.5)
end

-- Clamp Hud Pos
local function clampHudPos(hx, hy, winW, winH)
    local sw, sh = screenSize()
    winW = math.max(200, tonumber(winW) or hudLastW or 320)
    winH = math.max(48, tonumber(winH) or hudLastH or 80)
    hx = math.max(HUD_MARGIN, math.min(hx, sw - winW - HUD_MARGIN))
    hy = math.max(HUD_MARGIN, math.min(hy, sh - winH - HUD_MARGIN))
    return hx, hy
end

-- Resolve Pos
local function resolvePos(settings, winW, winH)
    local sw, sh = screenSize()
    local rawX = settings and tonumber(settings.spectate_keys_hud_x)
    local rawY = settings and tonumber(settings.spectate_keys_hud_y)
    local custom = settings and settings.spectate_keys_hud_custom == true
    local hx, hy
    if custom and rawX ~= nil and rawY ~= nil then
        hx, hy = rawX, rawY
    else
        hx, hy = defaultHudPos(sw, sh, winW, winH)
    end
    return clampHudPos(hx, hy, winW, winH)
end

-- Persist Hud Pos
local function persistHudPos(settings, hx, hy, winW, winH)
    if not settings then return end
    hx, hy = clampHudPos(hx, hy, winW, winH)
    settings.spectate_keys_hud_custom = true
    settings.spectate_keys_hud_x = math.floor(hx + 0.5)
    settings.spectate_keys_hud_y = math.floor(hy + 0.5)
    if markDirtySettings then markDirtySettings() end
end

-- Pointer In Hud Rect
local function pointerInHudRect(r)
    if not r then return false end
    local pin = type(_G.deskPointerInRect) == 'function' and _G.deskPointerInRect
        or type(deskPointerInRect) == 'function' and deskPointerInRect
    if pin and pin(r) then return true end
    if imgui and type(imgui.GetIO) == 'function' then
        local ok, io = pcall(imgui.GetIO)
        if ok and io and io.MousePos then
            local mp = io.MousePos
            return mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1
        end
    end
    return false
end

-- Draw Inner
local function drawKeysHudInner(settings)
    local estW = hudLastW or 320
    local estH = hudLastH or 80
    local rawHx = settings and tonumber(settings.spectate_keys_hud_x)
    local rawHy = settings and tonumber(settings.spectate_keys_hud_y)
    local hx, hy = resolvePos(settings, estW, estH)
    if drag.active then
        hx, hy = drag.offX, drag.offY
    elseif rawHx ~= nil and rawHy ~= nil
            and (math.floor(hx + 0.5) ~= math.floor(rawHx + 0.5)
                or math.floor(hy + 0.5) ~= math.floor(rawHy + 0.5)) then
        persistHudPos(settings, hx, hy, estW, estH)
    end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.AlwaysAutoResize + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoSavedSettings then
        flags = flags + imgui.WindowFlags.NoSavedSettings
    end

    imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)
    spTheme.pushHudChrome()
    if not imgui.Begin('###desk_sp_keys_hud', nil, flags) then
        spTheme.popHudChrome()
        return
    end

    spTheme.drawPanelFrame()

    hovered = false
    local labelFn = uiText or function(s) return s end
    local title = labelFn('\xCA\xEB\xE0\xE2\xE8\xE0\xF2\xF3\xF0\xE0 \xE8\xE3\xF0\xEE\xEA\xE0')
    local titleCol = col_muted or spTheme.labelCol()
    local headerY = imgui.GetCursorPosY()
    local availW = imgui.GetContentRegionAvail().x
    local titleW = imgui.CalcTextSize(title).x
    if availW > titleW + 4 then
        imgui.SetCursorPosX(imgui.GetCursorPosX() + (availW - titleW) * 0.5)
    end
    imgui.TextColored(titleCol, title)
    local headerH = imgui.GetCursorPosY() - headerY
    if headerH < 18 then headerH = 18 end

    imgui.SetCursorPosY(headerY + headerH)
    spTheme.drawHeaderRule(col_accent)

    local ped = targetChar()
    if ped then
        local plState = playerStateKey() or 'onfoot'
        local stateKeys = keys[plState] or {}
        if plState == 'vehicle' then
            drawVehicleLayout(stateKeys)
        else
            drawOnfootLayout(stateKeys)
        end
    else
        imgui.TextColored(col_muted2 or spTheme.idCol(),
            labelFn('\xC8\xE3\xF0\xEE\xEA \xED\xE5 \xE2 \xE7\xEE\xED\xE5 \xF1\xF2\xF0\xE8\xEC\xE0'))
    end

    local wp = imgui.GetWindowPos()
    local ww = imgui.GetWindowWidth() or 320
    local wh = imgui.GetWindowHeight() or 80
    hudLastW = ww
    hudLastH = wh
    hudRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }

    imgui.SetCursorPos(imgui.ImVec2(0, 0))
    imgui.InvisibleButton('##keys_hud_drag', imgui.ImVec2(-1, -1))
    if imgui.IsItemHovered() or imgui.IsItemActive() or drag.active then
        hovered = true
    end
    if imgui.IsItemActive() and imgui.IsMouseDragging(0) then
        local delta = imgui.GetMouseDragDelta(0)
        if not drag.active then
            drag.active = true
            drag.startX = wp.x
            drag.startY = wp.y
            imgui.ResetMouseDragDelta(0)
            delta = imgui.GetMouseDragDelta(0)
        end
        drag.offX = drag.startX + delta.x
        drag.offY = drag.startY + delta.y
        drag.offX, drag.offY = clampHudPos(drag.offX, drag.offY, ww, wh)
    elseif drag.active and not imgui.IsMouseDown(0) then
        drag.active = false
        persistHudPos(settings, wp.x, wp.y, ww, wh)
        if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
    end

    imgui.End()
    spTheme.popHudChrome()
end

-- Публичный API модуля.
function M.isEnabled(settings)
    settings = settings or getSettings()
    if not settings then return true end
    return settings.spectate_keys_hud ~= false
end

-- Публичный API модуля.
function M.shouldShow(settings)
    if not M.isEnabled(settings) then return false end
    if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then
        drag.active = false
        hovered = false
        return false
    end
    if not isSpectating() then return false end
    return getTargetId() >= 0
end

-- Публичный API модуля.
function M.isDragActive()
    return drag.active == true
end

-- Публичный API модуля.
function M.clearPointerHover()
    hovered = false
end

-- Публичный API модуля.
function M.wantsInput()
    if drag.active then return true end
    if hovered then return true end
    if pointerInHudRect(hudRect) then return true end
    local settings = getSettings()
    if settings then
        local estW = hudLastW or 320
        local estH = hudLastH or 80
        local hx, hy = resolvePos(settings, estW, estH)
        if pointerInHudRect({ x0 = hx, y0 = hy, x1 = hx + estW, y1 = hy + estH }) then
            return true
        end
    end
    return false
end

-- Публичный API модуля.
function M.reset()
    keys.onfoot = {}
    keys.vehicle = {}
    capAnim = {}
    drag.active = false
    hovered = false
    hudRect = nil
end

-- Публичный API модуля.
function M.draw(settings)
    settings = settings or getSettings()
    if not M.shouldShow(settings) then return end
    local ok, err = pcall(drawKeysHudInner, settings)
    if not ok and print then
        print('[report_desk_sp_keys_hud] draw: ' .. tostring(err))
    end
end

-- Публичный API модуля.
function M.installSampev(sampev)
    if not sampev or sampevRef then return end
    sampevRef = sampev

    hookPrevPlayerSync = sampev.onPlayerSync
    if hookPrevPlayerSync == M._playerSyncHandler then hookPrevPlayerSync = nil end
    M._playerSyncHandler = function(playerId, data)
        if M.isEnabled() and isSpectating() then
            pcall(updateOnfootKeys, playerId, data)
        end
        if type(hookPrevPlayerSync) == 'function' then
            return hookPrevPlayerSync(playerId, data)
        end
    end
    sampev.onPlayerSync = M._playerSyncHandler

    hookPrevVehicleSync = sampev.onVehicleSync
    if hookPrevVehicleSync == M._vehicleSyncHandler then hookPrevVehicleSync = nil end
    M._vehicleSyncHandler = function(playerId, vehicleId, data)
        if M.isEnabled() and isSpectating() then
            pcall(updateVehicleKeys, playerId, data)
        end
        if type(hookPrevVehicleSync) == 'function' then
            return hookPrevVehicleSync(playerId, vehicleId, data)
        end
    end
    sampev.onVehicleSync = M._vehicleSyncHandler
end

-- Публичный API модуля.
function M.configure(deps)
    if type(deps) ~= 'table' then return end
    if deps.uiText ~= nil then uiText = deps.uiText end
    if deps.toU32 ~= nil then toU32 = deps.toU32 end
    if deps.col_accent ~= nil then col_accent = deps.col_accent end
    if deps.col_accent_dim ~= nil then col_accent_dim = deps.col_accent_dim end
    if deps.col_muted ~= nil then col_muted = deps.col_muted end
    if deps.col_muted2 ~= nil then col_muted2 = deps.col_muted2 end
    if deps.markDirtySettings ~= nil then markDirtySettings = deps.markDirtySettings end
    if deps.flushDirtyConfigNow ~= nil then flushDirtyConfigNow = deps.flushDirtyConfigNow end
    if deps.getSettings ~= nil then getSettingsFn = deps.getSettings end
    if deps.getSpectateTargetId ~= nil then getSpectateTargetId = deps.getSpectateTargetId end
    if deps.isSpectating ~= nil then isSpectatingFn = deps.isSpectating end
end

return M
