--[[ РњРѕРґСѓР»СЊ: admin cheats (GM, WH, airbreak, marker, TP). ]]
function vkToLabel(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return '?' end
    if vk == vkeys.VK_XBUTTON1 then return 'M4' end
    if vk == vkeys.VK_XBUTTON2 then return 'M5' end
    if vk == vkeys.VK_LBUTTON then return 'LMB' end
    if vk == vkeys.VK_RBUTTON then return 'RMB' end
    if vk == vkeys.VK_MBUTTON then return 'MMB' end
    if vkeys.id_to_name then
        local name = vkeys.id_to_name(vk)
        if name and type(name) == 'string' then
            return name:gsub('^VK_', '')
        end
    end
    if vkeys.key_names and vkeys.key_names[vk] then
        local name = vkeys.key_names[vk]
        if type(name) == 'string' then
            return name:gsub('^VK_', '')
        end
    end
    return string.format('0x%02X', vk)
end

-- Cheats Inputs Blocked
function cheatsInputsBlocked()
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if showWindow[0] then return true end
    if deskInputState.playerSpectating and deskTextInputActive() then return true end
    return false
end

local DESK_REPLY_STICKY_SEC = 2.0

-- Desk hook/helper.
function deskSyncInputFocusState()
    if not showWindow[0] then
        deskInputState.replyFocused = false
        deskInputState.replyInputActive = false
        deskInputState.keyboardStickyUntil = 0
        deskInputState.windowOpenSince = 0
        return
    end
    if deskInputState.replyInputActive then
        deskInputState.replyFocused = true
        deskInputState.keyboardStickyUntil = os.clock() + DESK_REPLY_STICKY_SEC
        return
    end
    local io = imgui.GetIO and imgui.GetIO()
    local anyActive = imgui.IsAnyItemActive and imgui.IsAnyItemActive()
    -- /sp HUD СЂРёСЃСѓРµС‚СЃСЏ РІ С‚РѕРј Р¶Рµ РєР°РґСЂРµ вЂ” IsAnyItemActive РЅРµ СЃС‡РёС‚Р°РµРј В«РїРµС‡Р°С‚СЊСЋ РІ deskВ».
    if anyActive and deskSpectatingNow and deskSpectatingNow() and not deskInputState.replyInputActive then
        anyActive = false
    end
    local typing = (io and (io.WantTextInput or io.WantCaptureKeyboard)) or anyActive
    if typing then
        deskInputState.replyFocused = true
        deskInputState.keyboardStickyUntil = os.clock() + DESK_REPLY_STICKY_SEC
    elseif deskInputState.replyFocused and deskInputState.keyboardStickyUntil <= os.clock() then
        deskInputState.replyFocused = false
    end
end

-- Desk hook/helper.
function deskKeepInputOnActiveItem()
    local active = false
    if imgui.IsItemActive then active = imgui.IsItemActive() end
    if not active and imgui.IsItemFocused then active = imgui.IsItemFocused() end
    if active or (imgui.IsItemClicked and imgui.IsItemClicked(0)) then
        deskInputState.keyboardStickyUntil = os.clock() + DESK_REPLY_STICKY_SEC
        deskInputState.replyFocused = true
    end
end

-- Desk hook/helper.
function deskWindowWantsKeyboard()
    if not showWindow[0] then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture or deskCache.adminPunishBindCapture then
        return true
    end
    -- Вкладка «Репорты»: держим клавиатуру у imgui, иначе после SAMP-диалога клавиши
    -- съедаются WM-хуком (showWindow), а ##reply уже без фокуса.
    if deskInputState.chatTabActive and selectedKey then
        return true
    end
    return deskImguiTypingActive()
end

-- Desk hook/helper.
function deskImguiTypingActive()
    if not showWindow[0] then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if deskInputState.replyInputActive then return true end
    if deskInputState.replyFocused then return true end
    if deskInputState.keyboardStickyUntil > os.clock() then return true end
    local io = imgui.GetIO and imgui.GetIO()
    if io and io.WantTextInput then return true end
    if imgui.IsAnyItemActive and imgui.IsAnyItemActive() then return true end
    return false
end

-- Desk hook/helper.
function deskTextInputActive()
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    return deskImguiTypingActive()
end

-- Desk hook/helper.
function deskModifierKeysDown()
    if not vkeys then return false end
    return isVkDown(vkeys.VK_SHIFT) or isVkDown(vkeys.VK_MENU) or isVkDown(vkeys.VK_CONTROL)
end

-- Is Vk Down
function isVkDown(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    if cheat_user32 and cheat_user32.GetAsyncKeyState then
        local ok, st = pcall(cheat_user32.GetAsyncKeyState, vk)
        if ok and st then return (st % 65536) >= 32768 end
    end
    return isKeyDown and isKeyDown(vk)
end

-- NumLock OFF: С‚Р° Р¶Рµ С„РёР·РёС‡РµСЃРєР°СЏ РєР»Р°РІРёС€Р° numpad С€Р»С‘С‚ HOME/END/вЂ¦ РІРјРµСЃС‚Рѕ VK_NUMPAD*.
local DESK_NUMPAD_EQUIV = {
    { vkeys.VK_NUMPAD0 or 0x60, vkeys.VK_INSERT or 0x2D },
    { vkeys.VK_NUMPAD1 or 0x61, vkeys.VK_END or 0x23 },
    { vkeys.VK_NUMPAD2 or 0x62, vkeys.VK_DOWN or 0x28 },
    { vkeys.VK_NUMPAD3 or 0x63, vkeys.VK_NEXT or 0x22 },
    { vkeys.VK_NUMPAD4 or 0x64, vkeys.VK_LEFT or 0x25 },
    { vkeys.VK_NUMPAD5 or 0x65, vkeys.VK_CLEAR or 0x0C },
    { vkeys.VK_NUMPAD6 or 0x66, vkeys.VK_RIGHT or 0x27 },
    { vkeys.VK_NUMPAD7 or 0x67, vkeys.VK_HOME or 0x24 },
    { vkeys.VK_NUMPAD8 or 0x68, vkeys.VK_UP or 0x26 },
    { vkeys.VK_NUMPAD9 or 0x69, vkeys.VK_PRIOR or 0x21 },
    { vkeys.VK_DECIMAL or 0x6E, vkeys.VK_DELETE or 0x2E },
}
local DESK_VK_EQUIV = {}
for _, group in ipairs(DESK_NUMPAD_EQUIV) do
    for _, vk in ipairs(group) do
        DESK_VK_EQUIV[vk] = group
    end
end

function deskBindVkEquivList(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return {} end
    return DESK_VK_EQUIV[vk] or { vk }
end

function deskCanonicalBindVk(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return vk end
    local group = DESK_VK_EQUIV[vk]
    if group then return group[1] end
    return vk
end

function deskBindKeysOverlap(a, b)
    a, b = tonumber(a) or 0, tonumber(b) or 0
    if a <= 0 or b <= 0 then return false end
    if a == b then return true end
    local ga, gb = DESK_VK_EQUIV[a], DESK_VK_EQUIV[b]
    return ga ~= nil and ga == gb
end

function deskBindAnyVkDown(vk)
    for _, ev in ipairs(deskBindVkEquivList(vk)) do
        if isVkDown(ev) == true then return true end
    end
    return false
end

function deskBindJustPressed(vk, prev)
    vk = tonumber(vk) or 0
    if vk <= 0 or type(prev) ~= 'table' then return false end
    local down = deskBindAnyVkDown(vk)
    if not down then
        prev[vk] = false
        return false
    end
    if not prev[vk] then
        prev[vk] = true
        return true
    end
    return false
end

function deskBindSyncKeyPrev(vk, prev)
    vk = tonumber(vk) or 0
    if vk <= 0 or type(prev) ~= 'table' then return end
    prev[vk] = deskBindAnyVkDown(vk)
end

-- Cheat Mod Down
function cheatModDown(vk)
    return isVkDown(vk)
end

-- Cheat Modifiers Match
function cheatModifiersMatch(c, prefix)
    if c[prefix .. '_ctrl'] and not cheatModDown(vkeys.VK_CONTROL) then return false end
    if c[prefix .. '_shift'] and not cheatModDown(vkeys.VK_SHIFT) then return false end
    if c[prefix .. '_alt'] and not cheatModDown(vkeys.VK_MENU) then return false end
    return true
end

-- Cheat Bind Label
function cheatBindLabel(c, prefix)
    local parts = {}
    if c[prefix .. '_ctrl'] then parts[#parts + 1] = 'Ctrl' end
    if c[prefix .. '_shift'] then parts[#parts + 1] = 'Shift' end
    if c[prefix .. '_alt'] then parts[#parts + 1] = 'Alt' end
    local k1 = tonumber(c[prefix .. '_key1']) or 0
    local k2 = tonumber(c[prefix .. '_key2']) or 0
    if k1 <= 0 then return uiText('\xCD\xE5 \xE7\xE0\xE4\xE0\xED\xEE') end
    parts[#parts + 1] = vkToLabel(k1)
    local s = table.concat(parts, '+')
    if k2 > 0 then
        s = s .. ' ; ' .. vkToLabel(k2)
    end
    return uiText(s)
end

-- Is Cheat Bind Hit
function isCheatBindHit(vk)
    return deskBindJustPressed(vk, deskCache.cheatBindPrev)
end

-- Is Cheat Bind Pressed
function isCheatBindPressed(c, prefix)
    if cheatsInputsBlocked() then return false end
    if deskTextInputActive() and deskModifierKeysDown() then return false end
    if type(c) ~= 'table' then return false end
    prefix = prefix or ''
    local key1 = tonumber(c[prefix .. '_key1']) or 0
    local key2 = tonumber(c[prefix .. '_key2']) or 0
    if key1 <= 0 then return false end
    if not cheatModifiersMatch(c, prefix) then return false end
    if key2 > 0 then
        return isVkDown(key1) and isCheatBindHit(key2)
    end
    return isCheatBindHit(key1)
end

-- Cheats Read Nt Settings
function cheatsReadNtSettings()
    if not sampGetServerSettingsPtr then return nil end
    local ptr = sampGetServerSettingsPtr()
    if not ptr or ptr == 0 then return nil end
    return {
        dist = memory.getfloat(ptr + 39, true),
        walls = memory.getint8(ptr + 47, true),
        show = memory.getint8(ptr + 56, true),
    }
end

-- Cheats Apply Wallhack
function cheatsApplyWallhack(on)
    if not sampGetServerSettingsPtr then return end
    local ptr = sampGetServerSettingsPtr()
    if not ptr or ptr == 0 then return end
    if on then
        if not cheatState.ntBackup then
            cheatState.ntBackup = cheatsReadNtSettings()
        end
        memory.setfloat(ptr + 39, 1488, true)
        memory.setint8(ptr + 47, 0, true)
        memory.setint8(ptr + 56, 1, true)
        cheatState.wallhack = true
    else
        local b = cheatState.ntBackup
        if b then
            memory.setfloat(ptr + 39, b.dist, true)
            memory.setint8(ptr + 47, b.walls, true)
            memory.setint8(ptr + 56, b.show, true)
        else
            memory.setfloat(ptr + 39, 35, true)
            memory.setint8(ptr + 47, 1, true)
            memory.setint8(ptr + 56, 1, true)
        end
        cheatState.wallhack = false
    end
    if uiCheatWh then uiCheatWh[0] = cheatState.wallhack end
end

-- Cheats Apply Godmode
function cheatsApplyGodmode(on)
    cheatState.godmode = on and true or false
    if uiCheatGm then uiCheatGm[0] = cheatState.godmode end
    if not doesCharExist or not doesCharExist(PLAYER_PED) then return end
    local proofs = cheatState.godmode
    setCharProofs(PLAYER_PED, proofs, proofs, proofs, proofs, proofs)
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car then setCarProofs(car, proofs, proofs, proofs, proofs, proofs) end
    end
end

-- РљР°Рє AdminTools: РїРµСЂРІС‹Р№ SETPLAYERHEALTH РїСЂРѕРїСѓСЃРєР°РµРј, РґР°Р»СЊС€Рµ Р±Р»РѕРєРёСЂСѓРµРј HP < 5.
function cheatsOnSetPlayerHealth(health)
    if not cheatState.godmode then return end
    if not cheatState.gmHealthPrimed then
        cheatState.gmHealthPrimed = true
    elseif (tonumber(health) or 0) < 5 then
        return false
    end
end

-- Cheats Set Airbreak
function cheatsSetAirbreak(on)
    ensureCheatsSettings()
    local wasOn = cheatState.airbreak
    cheatState.airbreak = on and true or false
    if uiCheatAb then uiCheatAb[0] = cheatState.airbreak end
    if not cheatState.airbreak then
        cheatState.abSpeedLive = nil
        cheatsResetAbKeyHold()
    elseif not wasOn then
        cheatState.abSpeedLive = nil
    end
    if not doesCharExist or not doesCharExist(PLAYER_PED) then return end
    if cheatState.airbreak then
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            if car then
                freezeCarPosition(car, true)
                setCarCollision(car, false)
            end
        else
            freezeCharPosition(PLAYER_PED, true)
            setCharCollision(PLAYER_PED, false)
        end
    else
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            if car then
                freezeCarPosition(car, false)
                setCarCollision(car, true)
            end
        else
            freezeCharPosition(PLAYER_PED, false)
            setCharCollision(PLAYER_PED, true)
        end
    end
end

-- Cheats Write Placement At
function cheatsWritePlacementAt(entityPtr, x, y, z)
    if not entityPtr or entityPtr == 0 then return false end
    if not readMemory or not writeMemory or not representFloatAsInt then return false end
    local placement = readMemory(entityPtr + 20, 4, false)
    if not placement or placement == 0 then return false end
    local base = placement + 48
    writeMemory(base + 0, 4, representFloatAsInt(tonumber(x) or 0), false)
    writeMemory(base + 4, 4, representFloatAsInt(tonumber(y) or 0), false)
    writeMemory(base + 8, 4, representFloatAsInt(tonumber(z) or 0), false)
    return true
end

-- Cheats Ab Key Down
function cheatsAbKeyDown(vk)
    if sampIsChatInputActive and sampIsChatInputActive() then return false end
    if sampIsDialogActive and sampIsDialogActive() then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return false end
    return isVkDown(vk)
end

-- Cheats Camera Axes XY
function cheatsCameraAxesXY()
    local cx, cy, cz = getActiveCameraCoordinates()
    local fx, fy = 0, 1
    local rx, ry = 1, 0
    local depth = 300.0
    if convertScreenCoordsToWorld3D and getScreenResolution then
        local sw, sh = getScreenResolution()
        if sw and sw > 0 and sh and sh > 0 then
            local midX, midY = sw * 0.5, sh * 0.5
            local wx, wy = convertScreenCoordsToWorld3D(midX, midY, depth)
            local px, py = convertScreenCoordsToWorld3D(
                midX + math.min(120, sw * 0.12), midY, depth)
            if wx then
                fx, fy = wx - cx, wy - cy
                if px then
                    rx, ry = px - cx, py - cy
                end
            end
        end
    end
    local flen = math.sqrt(fx * fx + fy * fy)
    if flen < 0.001 then
        local heading = 0
        if isCharInAnyCar(PLAYER_PED) then
            local car = storeCarCharIsInNoSave(PLAYER_PED)
            if car and getCarHeading then heading = getCarHeading(car) end
        elseif getCharHeading then
            heading = getCharHeading(PLAYER_PED)
        end
        local r = math.rad(heading)
        fx, fy = -math.sin(r), math.cos(r)
        rx, ry = math.cos(r), math.sin(r)
    else
        fx, fy = fx / flen, fy / flen
    end
    local rlen = math.sqrt(rx * rx + ry * ry)
    if rlen < 0.001 then
        rx, ry = fy, -fx
    else
        rx, ry = rx / rlen, ry / rlen
        local dot = fx * rx + fy * ry
        rx = rx - fx * dot
        ry = ry - fy * dot
        rlen = math.sqrt(rx * rx + ry * ry)
        if rlen < 0.001 then
            rx, ry = fy, -fx
        else
            rx, ry = rx / rlen, ry / rlen
        end
    end
    return fx, fy, rx, ry
end

-- Cheats Sync Heading To Camera
function cheatsSyncHeadingToCamera(fx, fy)
    local h = math.deg(math.atan2(-fx, fy))
    if h < 0 then h = h + 360 end
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car and setCarHeading then setCarHeading(car, h) end
    elseif setCharHeading then
        setCharHeading(PLAYER_PED, h)
    end
end

-- Cheats Apply Placement Delta
function cheatsApplyPlacementDelta(dx, dy, dz)
    if not doesCharExist or not doesCharExist(PLAYER_PED) then return end
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if not car or not doesVehicleExist(car) then return end
        local x, y, z = getCarCoordinates(car)
        local nx, ny, nz = x + dx, y + dy, z + dz
        if getCarPointer then
            local ptr = getCarPointer(car)
            if ptr and cheatsWritePlacementAt(ptr, nx, ny, nz) then return end
        end
        setCarCoordinates(car, nx, ny, nz)
        return
    end
    local x, y, z = getCharCoordinates(PLAYER_PED)
    local nx, ny, nz = x + dx, y + dy, z + dz
    if getCharPointer then
        local ptr = getCharPointer(PLAYER_PED)
        if ptr and cheatsWritePlacementAt(ptr, nx, ny, nz) then return end
    end
    setCharCoordinates(PLAYER_PED, nx, ny, nz)
end

-- Cheats Get Ab Speed
function cheatsGetAbSpeed()
    if cheatState.abSpeedLive ~= nil then
        return cheatState.abSpeedLive
    end
    ensureCheatsSettings()
    return tonumber(settings.cheats.ab_speed) or 1.0
end

-- Cheats Ab Adjust Speed
function cheatsAbAdjustSpeed(delta)
    local spd = cheatsGetAbSpeed()
    local newSpd = math.max(0.05, math.min(3.0, spd + delta))
    if math.abs(newSpd - spd) < 0.0001 then return end
    cheatState.abSpeedLive = newSpd
    cheatState.abSpeedFlash = {
        dir = delta < 0 and -1 or 1,
        spd = newSpd,
        expires = os.clock() + AB_SPEED_FLASH_SEC,
    }
    uiCheatAbSpeed[0] = newSpd
end

-- Cheats Reset Ab Key Hold
function cheatsResetAbKeyHold()
    cheatState.abKeyHold.q.held = false
    cheatState.abKeyHold.q.nextAt = 0
    cheatState.abKeyHold.e.held = false
    cheatState.abKeyHold.e.nextAt = 0
end

-- Cheats Tick Airbreak Speed Keys
function cheatsTickAirbreakSpeedKeys()
    if not cheatState.airbreak then return end
    local now = os.clock()
    local function tickKey(vk, slot, delta)
        local st = cheatState.abKeyHold[slot]
        local down = cheatsAbKeyDown(vk)
        if not down then
            st.held = false
            st.nextAt = 0
            return
        end
        if not st.held then
            st.held = true
            st.nextAt = now + AB_SPEED_HOLD_DELAY
            cheatsAbAdjustSpeed(delta)
        elseif now >= st.nextAt then
            st.nextAt = now + AB_SPEED_HOLD_REPEAT
            cheatsAbAdjustSpeed(delta)
        end
    end
    tickKey(vkeys.VK_Q, 'q', -AB_SPEED_STEP)
    tickKey(vkeys.VK_E, 'e', AB_SPEED_STEP)
end

-- Cheats Tick Airbreak Movement
function cheatsTickAirbreakMovement()
    if not cheatState.airbreak then return end
    if not doesCharExist or not doesCharExist(PLAYER_PED) then return end
    cheatsTickAirbreakSpeedKeys()
    local spd = cheatsGetAbSpeed()
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car then
            freezeCarPosition(car, true)
            setCarCollision(car, false)
        end
    else
        freezeCharPosition(PLAYER_PED, true)
        setCharCollision(PLAYER_PED, false)
    end
    local fx, fy, rx, ry = cheatsCameraAxesXY()
    cheatsSyncHeadingToCamera(fx, fy)
    local dx, dy, dz = 0, 0, 0
    if cheatsAbKeyDown(vkeys.VK_W) then
        dx = dx + fx * spd
        dy = dy + fy * spd
    end
    if cheatsAbKeyDown(vkeys.VK_S) then
        dx = dx - fx * spd
        dy = dy - fy * spd
    end
    if cheatsAbKeyDown(vkeys.VK_D) then
        dx = dx + rx * spd
        dy = dy + ry * spd
    end
    if cheatsAbKeyDown(vkeys.VK_A) then
        dx = dx - rx * spd
        dy = dy - ry * spd
    end
    if cheatsAbKeyDown(vkeys.VK_SPACE) then
        dz = dz + spd
    end
    if cheatsAbKeyDown(vkeys.VK_SHIFT) then
        dz = dz - spd
    end
    if dx ~= 0 or dy ~= 0 or dz ~= 0 then
        cheatsApplyPlacementDelta(dx, dy, dz)
    end
end

-- Cheats Toggle Godmode
function cheatsToggleGodmode()
    cheatsApplyGodmode(not cheatState.godmode)
    if cheatState.godmode and isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car then
            setCarRoll(car, 0)
            setCarHealth(car, 1000)
            fixCar(car)
            setCarProofs(car, true, true, true, true, true)
        end
    end
end

-- Cheats Toggle Wallhack
function cheatsToggleWallhack()
    cheatsApplyWallhack(not cheatState.wallhack)
end

-- Р¤РёРєСЃРёСЂРѕРІР°РЅРЅС‹Рµ РєР»Р°РІРёС€Рё РјР°СЂРєРµСЂР° (РЅРµ РЅР°СЃС‚СЂР°РёРІР°СЋС‚СЃСЏ): РЎРљРњ / Р›РљРњ / РџРљРњ.
MARKER_BIND_TOGGLE = vkeys.VK_MBUTTON
MARKER_BIND_TP = vkeys.VK_LBUTTON
MARKER_BIND_VEH = vkeys.VK_RBUTTON

-- Global in core_a chunk: cheats_marker.lua calls this for LMB/RMB TP (Lua forward-ref).
function markerFixedBindHit(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    return isCheatBindHit(vk)
end

-- Cheats Toggle Airbreak
function cheatsToggleAirbreak()
    cheatsSetAirbreak(not cheatState.airbreak)
end

-- Desk hook/helper.
function deskHotkeyBlockedByMarkerWheel(vk)
    ensureCheatsSettings()
    if settings.cheats.marker_wheel == false then return false end
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    return vk == MARKER_BIND_TOGGLE
end

-- Cheats Process Keybinds
function cheatsProcessKeybinds()
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return end
    if deskInputState.playerSpectating and deskModifierKeysDown() then return end
    ensureCheatsSettings()
    local markerToggle = markerFixedBindHit(MARKER_BIND_TOGGLE)
    if markerToggle then
        if not cheatState.marker.active then
            markerToggleMode()
        else
            markerSetMode(false)
        end
    end
    if not cheatState.marker.active then
        local c = settings.cheats
        if isCheatBindPressed(c, 'gm') then cheatsToggleGodmode() end
        if isCheatBindPressed(c, 'wh') then cheatsToggleWallhack() end
        if isCheatBindPressed(c, 'ab') then cheatsToggleAirbreak() end
    end
end

-- Cheats Apply Startup
function cheatsApplyStartup()
    ensureCheatsSettings()
    local c = settings.cheats
    if c.gm_on_start then cheatsApplyGodmode(true) end
    if c.wh_on_start then cheatsApplyWallhack(true) end
    uiCheatAbSpeed[0] = tonumber(c.ab_speed) or 1.0
end

-- Cheats Maintain
function cheatsMaintain()
    if not sampIsLocalPlayerSpawned or not sampIsLocalPlayerSpawned() then return end
    if not doesCharExist or not doesCharExist(PLAYER_PED) then return end
    if not cheatsStartupDone then
        cheatsStartupDone = true
        cheatsApplyStartup()
    end
    if cheatState.godmode then
        cheatsApplyGodmode(true)
        local hp = tonumber(getCharHealth(PLAYER_PED)) or 100
        if hp < 80 and type(sendChat) == 'function' and type(sampGetPlayerIdByCharHandle) == 'function' then
            local now = os.clock()
            if now - (tonumber(cheatState.gmHpCmdAt) or 0) > 10 then
                local ok, myId = sampGetPlayerIdByCharHandle(PLAYER_PED)
                if ok and myId then
                    cheatState.gmHpCmdAt = now
                    sendChat(string.format('hp %d 100', myId))
                end
            end
        end
    end
    if cheatState.wallhack then cheatsApplyWallhack(true) end
end

-- Cheats Cleanup
function cheatsCleanup()
    markerSetMode(false)
    if cheatState.airbreak then cheatsSetAirbreak(false) end
    if cheatState.godmode then cheatsApplyGodmode(false) end
    if cheatState.wallhack then cheatsApplyWallhack(false) end
    if type(maskIdCleanup) == 'function' then pcall(maskIdCleanup) end
    cheatState.ntBackup = nil
end

-- Marker wheel/TP: report_desk_cheats_marker.lua

-- Draw Airbreak Hud Labels
local function drawAirbreakHudLabels(wp, spd)
    if not wp or not toU32 or not imgui.CalcTextSize then return end
    local dl = imgui.GetWindowDrawList()
    if not dl then return end

    local scale = 1.08
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(scale) end

    local spdStr = string.format('%.2f', spd)
    local qW = imgui.CalcTextSize('Q').x
    local eW = imgui.CalcTextSize('E').x
    local spdW = imgui.CalcTextSize(spdStr).x
    local lh = imgui.GetTextLineHeight and imgui.GetTextLineHeight() or 14
    local y = wp.y + (CHEATS_AB_HUD_H - lh) * 0.5

    local qCol = col_muted2
    local eCol = col_muted2
    local spdCol = col_accent
    local flash = cheatState.abSpeedFlash
    if flash and flash.expires and os.clock() < flash.expires then
        if flash.dir and flash.dir < 0 then
            qCol = col_warn
            spdCol = col_muted
        else
            eCol = col_warn
            spdCol = col_accent
        end
    else
        cheatState.abSpeedFlash = nil
    end
    if cheatsAbKeyDown(vkeys.VK_Q) then qCol = col_label end
    if cheatsAbKeyDown(vkeys.VK_E) then eCol = col_label end

    local qX = wp.x + CHEATS_AB_HUD_SIDE_PAD
    local eX = wp.x + CHEATS_AB_HUD_W - CHEATS_AB_HUD_SIDE_PAD - eW
    local spdX = wp.x + (CHEATS_AB_HUD_W - spdW) * 0.5

    dl:AddText(imgui.ImVec2(qX, y), toU32(qCol), 'Q')
    dl:AddText(imgui.ImVec2(spdX, y), toU32(spdCol), spdStr)
    dl:AddText(imgui.ImVec2(eX, y), toU32(eCol), 'E')

    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(1.0) end
end

-- Must be before drawAirbreakHudOverlay (cheats.lua loads before cheats_marker in core_a chunk).
local function cheatsOverlayTheme()
    local t = package.loaded['report_desk_sp_theme']
    if not t then
        local ok, mod = pcall(require, 'report_desk_sp_theme')
        if ok then t = mod end
    end
    if t and toU32 and t.setColorConverter then
        pcall(t.setColorConverter, toU32)
    end
    return t
end

-- Draw Airbreak Hud Overlay
function drawAirbreakHudOverlay()
    if not cheatState.airbreak then return end
    local spd = cheatsGetAbSpeed()
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    if sw < 100 then sw = 1920 end
    if sh < 100 then sh = 1080 end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoScrollbar + imgui.WindowFlags.NoInputs
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoFocusOnAppearing then
        flags = flags + imgui.WindowFlags.NoFocusOnAppearing
    end

    local spTheme = cheatsOverlayTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(CHEATS_AB_HUD_W, CHEATS_AB_HUD_H), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh - 52), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
    if spTheme then spTheme.pushHudChrome() end
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))
    if imgui.Begin('###desk_ab_hud', nil, flags) then
        if spTheme and spTheme.drawPanelFrame then spTheme.drawPanelFrame() end
        drawAirbreakHudLabels(imgui.GetWindowPos(), spd)
        imgui.End()
    end
    imgui.PopStyleVar(2)
    if spTheme then spTheme.popHudChrome() end
end

CHEAT_BIND_PREFIX = {
    gm = 'gm', wh = 'wh', ab = 'ab',
}

CHEAT_CARD_H = 142
CHEAT_CARD_H_AB = 182
CHEAT_CARD_H_MK = 168
CHEAT_CARD_H_OPTS = 72
CHEAT_BIND_LABEL_W = 120
CHEAT_BIND_BTN_H = 28
DESK_BIND_PREVIEW_W = 168
DESK_BIND_CHANGE_BTN_W = 88
DESK_BIND_ROW_H = 36
DESK_FORM_INPUT_W = 160

AB_SPEED_STEP = 0.04
AB_SPEED_FLASH_SEC = 2.0
AB_SPEED_HOLD_DELAY = 0.16
AB_SPEED_HOLD_REPEAT = 0.05

-- Cheat Clear Bind
function cheatClearBind(prefix)
    ensureCheatsSettings()
    local c = settings.cheats
    c[prefix .. '_key1'] = 0
    c[prefix .. '_key2'] = 0
    c[prefix .. '_ctrl'] = false
    c[prefix .. '_shift'] = false
    c[prefix .. '_alt'] = false
    markDirtySettings()
end

-- Cheat Bind Is Modifier
function cheatBindIsModifier(vk)
    vk = tonumber(vk) or 0
    return vk == vkeys.VK_CONTROL or vk == vkeys.VK_SHIFT or vk == vkeys.VK_MENU
        or vk == vkeys.VK_LCONTROL or vk == vkeys.VK_RCONTROL
        or vk == vkeys.VK_LSHIFT or vk == vkeys.VK_RSHIFT
        or vk == vkeys.VK_LMENU or vk == vkeys.VK_RMENU
end

-- Cheat Live Bind Preview
function cheatLiveBindPreview()
    local parts = {}
    if cheatModDown(vkeys.VK_CONTROL) then parts[#parts + 1] = 'Ctrl' end
    if cheatModDown(vkeys.VK_SHIFT) then parts[#parts + 1] = 'Shift' end
    if cheatModDown(vkeys.VK_MENU) then parts[#parts + 1] = 'Alt' end
    local capVk = tonumber(deskCache.bindCapVk) or 0
    if capVk > 0 and not cheatBindIsModifier(capVk) then
        parts[#parts + 1] = vkToLabel(capVk)
    else
        for vk in pairs(MOUSE_BIND_VKS) do
            if isVkDown(vk) then parts[#parts + 1] = vkToLabel(vk) end
        end
    end
    if #parts == 0 then
        return uiText('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 \xEA\xEB\xE0\xE2\xE8\xF8\xF3...')
    end
    return uiText(table.concat(parts, '+'))
end

-- РђРєС‚РёРІРµРЅ Р»Рё Р»СЋР±РѕР№ СЂРµР¶РёРј Р·Р°С…РІР°С‚Р° Р±РёРЅРґР° (hotkey / cheats / Р°РІС‚РѕРІС‹РґР°С‡Р°).
function deskAnyBindCapture()
    return deskCache.hotkeyCapture == true
        or deskCache.cheatCapture ~= nil
        or deskCache.adminPunishBindCapture == true
end

-- Finish Desk Bind Capture
function finishDeskBindCapture()
    deskCache.hotkeyCapture = false
    deskCache.cheatCapture = nil
    deskCache.cheatCaptureSlot = 'main'
    deskCache.bindCapVk = nil
    deskCache.bindCapIgnoreMouseUntil = 0
    deskCache.bindCapPollPrev = nil
    deskCache.bindCapKbPrev = nil
    if deskCache.adminPunishBindCapture and type(finishAdminPunishBindCapture) == 'function' then
        finishAdminPunishBindCapture()
    end
end

-- РћР±С‹С‡РЅС‹Рµ РєР»Р°РІРёС€Рё РґР»СЏ WM_KEY* (Р±РµР· РєРЅРѕРїРѕРє РјС‹С€Рё вЂ” РёС… СЃРј. deskBindMouseKeyboardVk).
function deskBindKeyboardCaptureVk(wparam)
    wparam = tonumber(wparam) or 0
    if wparam <= 0 or wparam >= 256 then return nil end
    if cheatBindIsModifier(wparam) then return nil end
    if MOUSE_BIND_VKS[wparam] then return nil end
    return wparam
end

-- M4/M5/MMB РІ SA С‡Р°СЃС‚Рѕ РїСЂРёС…РѕРґСЏС‚ С‚РѕР»СЊРєРѕ РєР°Рє WM_KEY* Р±РµР· WM_XBUTTON*.
function deskBindMouseKeyboardVk(wparam)
    wparam = tonumber(wparam) or 0
    if wparam <= 0 or wparam >= 256 then return nil end
    if cheatBindIsModifier(wparam) then return nil end
    if MOUSE_BIND_VKS[wparam] then return wparam end
    return nil
end

function deskBindCaptureKeyFromKeyboard(wparam)
    return deskBindKeyboardCaptureVk(wparam) or deskBindMouseKeyboardVk(wparam)
end

function deskBindCapResolveVk(capKey)
    capKey = tonumber(capKey) or 0
    if capKey <= 0 then return 0 end
    local capVk = tonumber(deskCache.bindCapVk) or 0
    if capVk <= 0 then
        deskCache.bindCapVk = capKey
        return capKey
    end
    return capVk
end

function deskBindCapTrySaveOnUp(capKey, saveFn, ...)
    capKey = tonumber(capKey) or 0
    if capKey <= 0 or type(saveFn) ~= 'function' then return false end
    local capVk = deskBindCapResolveVk(capKey)
    if capVk > 0 and capKey == capVk then
        return saveFn(...) and true or false
    end
    return false
end

-- Desk Bind Mouse Ui Click Vk
function deskBindMouseUiClickVk(vk)
    vk = tonumber(vk) or 0
    return vk == vkeys.VK_LBUTTON or vk == vkeys.VK_RBUTTON
end

-- Desk Bind Mouse Commits On Down
function deskBindMouseCommitsOnDown(vk)
    vk = tonumber(vk) or 0
    return vk == vkeys.VK_XBUTTON1 or vk == vkeys.VK_XBUTTON2 or vk == vkeys.VK_MBUTTON
end

-- Begin Desk Bind Capture Session
function deskBindCaptureResetPollState()
    local prev = {}
    for vk in pairs(MOUSE_BIND_VKS) do
        prev[vk] = isVkDown(vk) == true
    end
    deskCache.bindCapPollPrev = prev
end

local function deskBindCapturePollSave(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 or cheatBindIsModifier(vk) then return false end
    deskCache.bindCapVk = vk
    if deskCache.cheatCapture then
        local prefix = CHEAT_BIND_PREFIX[deskCache.cheatCapture]
        if not prefix then return false end
        return deskBindCapSaveCheat(prefix)
    end
    if deskCache.hotkeyCapture then
        return deskBindCapSaveHotkey(vk)
    end
    if deskCache.adminPunishBindCapture and type(adminPunishBindCaptureSave) == 'function' then
        return adminPunishBindCaptureSave(vk)
    end
    return false
end

-- M4/M5/MMB С‡Р°СЃС‚Рѕ РІРёРґРЅС‹ С‚РѕР»СЊРєРѕ С‡РµСЂРµР· GetAsyncKeyState; WM_* / WM_KEY* РІ SA РґРѕ Lua РЅРµ РґРѕС…РѕРґСЏС‚.
function deskBindCapturePollFrame()
    if not deskAnyBindCapture() then
        deskCache.bindCapPollPrev = nil
        deskCache.bindCapKbPrev = nil
        return
    end
    local startedAt = deskCache.cheatCapture and deskCache.cheatCaptureAt
        or deskCache.adminPunishBindCapture and deskCache.adminPunishBindCaptureAt
        or deskCache.hotkeyCaptureAt
    if os.clock() - (tonumber(startedAt) or 0) < PF.HOTKEY_CAPTURE_GRACE then return end

    local prev = deskCache.bindCapPollPrev
    if type(prev) ~= 'table' then
        deskBindCaptureResetPollState()
        prev = deskCache.bindCapPollPrev
    end

    local ignoreUntil = tonumber(deskCache.bindCapIgnoreMouseUntil) or 0
    local now = os.clock()

    for vk in pairs(MOUSE_BIND_VKS) do
        if deskBindMouseUiClickVk(vk) and now < ignoreUntil then
            prev[vk] = isVkDown(vk) == true
        else
            local down = isVkDown(vk) == true
            local was = prev[vk] == true
            if down and not was then
                deskCache.bindCapVk = vk
                if deskBindMouseCommitsOnDown(vk) then
                    if deskBindCapturePollSave(vk) then return end
                end
            elseif was and not down then
                deskBindCapturePollSave(vk)
                return
            end
            prev[vk] = down
        end
    end

    local capVk = tonumber(deskCache.bindCapVk) or 0
    if capVk > 0 and not MOUSE_BIND_VKS[capVk] and not cheatBindIsModifier(capVk) then
        local down = isVkDown(capVk) == true
        local was = prev[capVk] == true
        if was and not down then
            deskBindCapturePollSave(capVk)
            return
        end
        prev[capVk] = down
    end

    -- Р—Р°РїР°СЃРЅРѕР№ РїСѓС‚СЊ РґР»СЏ РєР»Р°РІРёР°С‚СѓСЂС‹, РµСЃР»Рё WM СЃСЉРµР»Рё chat/imgui-СЃР»РѕР№.
    local kbPrev = deskCache.bindCapKbPrev
    if type(kbPrev) ~= 'table' then
        kbPrev = {}
        deskCache.bindCapKbPrev = kbPrev
    end
    for vk = 1, 255 do
        if not cheatBindIsModifier(vk) and not MOUSE_BIND_VKS[vk] then
            local down = isVkDown(vk) == true
            local was = kbPrev[vk] == true
            if down and not was then
                deskCache.bindCapVk = vk
                if deskBindMouseCommitsOnDown(vk) then
                    if deskBindCapturePollSave(vk) then return end
                end
            elseif was and not down and tonumber(deskCache.bindCapVk) == vk then
                if deskBindCapturePollSave(vk) then return end
            end
            kbPrev[vk] = down
        end
    end
end

local function beginDeskBindCaptureSession()
    deskCache.bindCapVk = nil
    deskCache.bindCapIgnoreMouseUntil = os.clock() + 0.35
    deskBindCaptureResetPollState()
end

-- Commit Cheat Bind Capture
function commitCheatBindCapture(prefix)
    prefix = prefix or (deskCache.cheatCapture and CHEAT_BIND_PREFIX[deskCache.cheatCapture])
    if not prefix then return false end
    local mainVk = tonumber(deskCache.bindCapVk) or 0
    if mainVk <= 0 or cheatBindIsModifier(mainVk) then return false end
    ensureCheatsSettings()
    local c = settings.cheats
    if deskCache.cheatCaptureSlot == 'key2' then
        c[prefix .. '_key2'] = mainVk
    else
        c[prefix .. '_key1'] = mainVk
        c[prefix .. '_key2'] = 0
        c[prefix .. '_ctrl'] = cheatModDown(vkeys.VK_CONTROL)
        c[prefix .. '_shift'] = cheatModDown(vkeys.VK_SHIFT)
        c[prefix .. '_alt'] = cheatModDown(vkeys.VK_MENU)
    end
    markDirtySettings()
    return true
end

-- Desk Bind Cap Save Hotkey
function deskBindCapSaveHotkey(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    settings.hotkey = vk
    markDirtySettings()
    if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
    deskResetHotkeyDebounce(vk)
    deskCache.hotkeyLastToggle = os.clock()
    finishDeskBindCapture()
    return true
end

-- Desk Bind Cap Save Cheat
function deskBindCapSaveCheat(prefix)
    prefix = prefix or (deskCache.cheatCapture and CHEAT_BIND_PREFIX[deskCache.cheatCapture])
    if not prefix then return false end
    if not commitCheatBindCapture(prefix) then return false end
    if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
    deskCache.hotkeyLastToggle = os.clock()
    finishDeskBindCapture()
    return true
end

-- Begin Cheat Bind Capture
function beginCheatBindCapture(captureId, slot)
    deskCache.cheatCapture = captureId
    deskCache.cheatCaptureSlot = slot or 'main'
    deskCache.cheatCaptureAt = os.clock()
    beginDeskBindCaptureSession()
end

-- Begin Hotkey Capture
function beginHotkeyCapture()
    deskCache.hotkeyCapture = true
    deskCache.hotkeyCaptureAt = os.clock()
    beginDeskBindCaptureSession()
end

-- Cancel Desk Bind Capture
function cancelDeskBindCapture()
    finishDeskBindCapture()
end

-- Draw Desk Bind Preset Chips
function drawDeskBindPresetChips(presets, onPick, chipPrefix)
    if not presets or #presets == 0 then return end
    chipPrefix = chipPrefix or 'bp'
    for i, p in ipairs(presets) do
        if i > 1 then imgui.SameLine(0, 6) end
        local label = tostring(p[1])
        local tw = math.max(36, imgui.CalcTextSize(label).x + 14)
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6)
        deskFormPushBindButtonStyle()
        if imgui.Button(label .. '##' .. chipPrefix .. i, imgui.ImVec2(tw, DESK_FORM_ROW_H - 2)) and onPick then
            onPick(p[2])
        end
        deskFormPopBindButtonStyle()
        imgui.PopStyleVar()
    end
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Desk hook/helper.
function deskFormPushBindButtonStyle()
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.12, 0.12, 0.16, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.20, 0.18, 0.28, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
    imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(0.28, 0.24, 0.36, 0.55))
end

-- Desk hook/helper.
function deskFormPopBindButtonStyle()
    imgui.PopStyleColor(4)
end

-- Desk hook/helper.
function deskHotkeyBlockedByTyping()
    -- settings.hotkey (F7, M4, M5, вЂ¦) РІСЃРµРіРґР° РїРµСЂРµРєР»СЋС‡Р°РµС‚ РѕРєРЅРѕ, РґР°Р¶Рµ СЃ С„РѕРєСѓСЃРѕРј РІ РѕС‚РІРµС‚Рµ
    return false
end

-- Desk hook/helper.
function deskHotkeyMessageIsDown(msg, wparam, lparam, hk)
    hk = tonumber(hk) or 0
    if hk <= 0 then return false end
    -- M4/M5 Рё РґСЂ. РєРЅРѕРїРєРё РјС‹С€Рё: С‚РѕР»СЊРєРѕ WM_*BUTTONDOWN (Windows РµС‰С‘ С€Р»С‘С‚ WM_KEYDOWN СЃ С‚РµРј Р¶Рµ VK)
    if MOUSE_BIND_VKS[hk] then
        return parseMouseButtonVk(msg, wparam, lparam) == hk
    end
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        return wparam == hk
    end
    return false
end

function deskBindMessageIsDown(msg, wparam, lparam, vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    for _, ev in ipairs(deskBindVkEquivList(vk)) do
        if deskHotkeyMessageIsDown(msg, wparam, lparam, ev) then
            return true
        end
    end
    return false
end

-- Desk hook/helper.
function deskResetHotkeyDebounce(vk)
    vk = tonumber(vk) or tonumber(settings.hotkey or vkeys.VK_F7) or 0
    if vk > 0 then deskCache.hotkeyPrev[vk] = false end
end

-- Handle Desk Hotkey Message
function tryHandleDeskHotkeyMessage(msg, wparam, lparam)
    if not sessionLive then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture or deskCache.adminPunishBindCapture then return false end
    if type(adminPunishHasPending) == 'function' and adminPunishHasPending() then return false end
    if isPauseMenuActive and isPauseMenuActive() then return false end
    local hk = (type(settings) == 'table' and settings.hotkey) or vkeys.VK_F7
    hk = tonumber(hk) or 0
    if hk <= 0 then return false end

    if msg == deskCache.wm.KILLFOCUS then
        deskResetHotkeyDebounce(hk)
        return false
    end

    if msg == deskCache.wm.KEYUP or msg == deskCache.wm.SYSKEYUP then
        if wparam == hk then
            deskCache.hotkeyPrev[hk] = false
        end
        return false
    end

    local relVk = parseMouseButtonReleaseVk(msg, wparam, lparam)
    if relVk == hk then
        deskCache.hotkeyPrev[hk] = false
        return false
    end

    if not deskHotkeyMessageIsDown(msg, wparam, lparam, hk) then return false end
    if deskHotkeyBlockedByTyping() then return false end
    if os.clock() - deskCache.hotkeyLastToggle < PF.HOTKEY_TOGGLE_GRACE then return false end

    deskCache.hotkeyLastToggle = os.clock()
    deskCache.hotkeyPrev[hk] = true
    pcall(toggleWindow)
    deskResetHotkeyDebounce(hk)
    consumeWindowMessage(true, true, true)
    return true
end

-- Draw Desk Bind Field
function drawDeskBindField(opts)
    opts = opts or {}
    local capW = math.max(140, imgui.GetContentRegionAvail().x)
    local capturing = opts.capturing == true
    local idleText = opts.idleText or '\xCD\xE0\xE6\xE0\xF2\xE5 \xE4\xEB\xFF \xED\xE0\xE7\xED\xE0\xF7\xE5\xED\xE8\xFF'
    local preview = opts.previewText or ''
    local emptyMark = uiText('\xCD\xE5 \xE7\xE0\xE4\xE0\xED\xEE')
    local shown = preview
    if capturing then
        if shown == '' then shown = uiText('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 \xEA\xEB\xE0\xE2\xE8\xF8\xF3...') end
    elseif shown == '' or shown == emptyMark then
        shown = uiText(idleText)
    end
    shown = ellipsizeToWidth(shown, capW - 24)
    if capturing then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.28, 0.18, 0.44, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.34, 0.22, 0.52, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.30, 0.20, 0.48, 1.0))
        imgui.PushStyleColor(imgui.Col.Border, col_accent)
        imgui.PushStyleColor(imgui.Col.Text, col_label)
    else
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.14, 0.13, 0.20, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.22, 0.18, 0.32, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
        imgui.PushStyleColor(imgui.Col.Border, imgui.ImVec4(col_accent_dim.x, col_accent_dim.y, col_accent_dim.z, 0.55))
        imgui.PushStyleColor(imgui.Col.Text, col_label)
    end
    if imgui.StyleVar and imgui.StyleVar.FrameBorderSize then
        imgui.PushStyleVarFloat(imgui.StyleVar.FrameBorderSize, 1.0)
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 10)
    local clicked = imgui.Button(shown .. (opts.keyCapId or '##bind_field'), imgui.ImVec2(capW, DESK_BIND_ROW_H))
    imgui.PopStyleVar()
    if imgui.StyleVar and imgui.StyleVar.FrameBorderSize then
        imgui.PopStyleVar()
    end
    imgui.PopStyleColor(5)
    if clicked and opts.onCapture then opts.onCapture() end
    if opts.onClear and imgui.IsItemClicked and imgui.IsItemClicked(1) then
        opts.onClear()
    end
    if imgui.IsItemHovered() and imgui.SetTooltip then
        if capturing then
            imgui.SetTooltip(uiText('\xCE\xF2\xEF\xF3\xF1\xF2\xE8\xF2\xE5 \xEA\xEB\xE0\xE2\xE8\xF8\xF3 \xE4\xEB\xFF \xF1\xEE\xF5\xF0\xE0\xED\xE5\xED\xE8\xFF \xB7 Esc \xEE\xF2\xEC\xE5\xED\xE0 \xB7 \xCF\xCA\xCC \xF1\xE1\xF0\xEE\xF1'))
        else
            imgui.SetTooltip(uiText('\xCD\xE0\xE6\xE0\xF2\xE5 \xE4\xEB\xFF \xED\xE0\xE7\xED\xE0\xF7\xE5\xED\xE8\xFF \xB7 \xCF\xCA\xCC \xF1\xE1\xF0\xEE\xF1'))
        end
    end
end

-- Draw Desk Bind Row
function drawDeskBindRow(opts)
    opts = opts or {}
    local inline = opts.inline ~= false and opts.label and opts.label ~= ''
    if inline then
        deskFormRowLabel(opts.label)
        drawDeskBindField(opts)
    else
        if opts.label and opts.label ~= '' then
            imgui.TextColored(col_muted2, uiText(opts.label))
            imgui.Dummy(imgui.ImVec2(0, 4))
        end
        drawDeskBindField(opts)
    end
    imgui.Dummy(imgui.ImVec2(0, 4))
end

-- Draw Desk Bind Change Button
function drawDeskBindChangeButton(btnId, popupId)
    if not imgui.OpenPopup then return false end
    deskFormPushBindButtonStyle()
    local clicked = imgui.Button(
        uiText('\xC8\xE7\xEC\xE5\xED\xE8\xF2\xFC') .. btnId,
        imgui.ImVec2(DESK_BIND_CHANGE_BTN_W, DESK_FORM_ROW_H))
    deskFormPopBindButtonStyle()
    if clicked then imgui.OpenPopup(popupId) end
    return clicked
end

-- Draw Desk Bind Value Row
function drawDeskBindValueRow(previewText, capturing, btnId, _popupId, _drawPopupBody)
    drawDeskBindRow({
        previewText = previewText,
        capturing = capturing,
        keyCapId = btnId,
    })
end

-- Draw Cheat Bind Preview Text
function drawCheatBindPreviewText(text, capturing, maxW)
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    local shown = ellipsizeToWidth(uiText(text or ''), maxW or DESK_BIND_PREVIEW_W)
    imgui.TextColored(capturing and col_warn or col_muted, shown)
end

-- Desk hook/helper.
function deskFormRowLabel(label)
    if not label or label == '' then return end
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    local x = imgui.GetCursorPosX()
    local y = imgui.GetCursorPosY()
    imgui.PushTextWrapPos(x + DESK_FORM_LABEL_W - 10)
    imgui.TextColored(col_muted2, uiText(label))
    imgui.PopTextWrapPos()
    imgui.SetCursorPos(imgui.ImVec2(x + DESK_FORM_LABEL_W, y))
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
end

-- Desk hook/helper.
function deskFormCheckboxRow(label, boolRef, onChange, stableId)
    return deskFormToggleRow(label, boolRef, onChange, stableId)
end

-- Desk hook/helper.
function deskFormToggleRow(label, boolRef, onChange, stableId)
    boolRef[0] = boolRef[0] and true or false
    stableId = stableId or tostring(label)
    local tw = DESK_FORM_TOGGLE_W
    local th = DESK_FORM_TOGGLE_H
    local rowH = math.max(th, DESK_FORM_ROW_H)
    local avail = imgui.GetContentRegionAvail().x
    if avail < tw + 80 then
        deskFormRowLabel(label)
        avail = imgui.GetContentRegionAvail().x
    end
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    local y = imgui.GetCursorPosY()
    local x = imgui.GetCursorPosX()
    local dl = imgui.GetWindowDrawList()
    local changed = false
    if imgui.InvisibleButton('##tg_' .. stableId, imgui.ImVec2(tw, rowH)) then
        boolRef[0] = not boolRef[0]
        changed = true
    end
    local p0 = imgui.GetItemRectMin()
    local p1 = imgui.GetItemRectMax()
    local midY = (p0.y + p1.y) * 0.5
    local track = imgui.ImVec2(tw, th)
    local t0 = imgui.ImVec2(p0.x, midY - th * 0.5)
    local t1 = imgui.ImVec2(p0.x + tw, midY + th * 0.5)
    local on = boolRef[0]
    local bgOff = imgui.ImVec4(0.16, 0.16, 0.20, 1.0)
    local bgOn = imgui.ImVec4(0.38, 0.22, 0.58, 1.0)
    local knob = imgui.ImVec4(0.95, 0.94, 0.98, on and 1.0 or 0.82)
    if dl then
        dl:AddRectFilled(t0, t1, toU32(on and bgOn or bgOff), th * 0.5)
        local kr = th * 0.38
        local kx = on and (t1.x - kr - 3) or (t0.x + kr + 3)
        dl:AddCircleFilled(imgui.ImVec2(kx, midY), kr, toU32(knob))
    end
    imgui.SetCursorPos(imgui.ImVec2(x + tw + 10, y + (rowH - (imgui.GetTextLineHeight() or 14)) * 0.5))
    imgui.TextColored(on and col_label or col_muted2, uiText(label or ''))
    imgui.SetCursorPos(imgui.ImVec2(x, y + rowH))
    imgui.Dummy(imgui.ImVec2(avail, 0))
    if changed and onChange then onChange(boolRef[0]) end
    return changed
end

-- Draw Cheat Bind Row
function drawCheatBindRow(prefix, captureId, rowLabel)
    rowLabel = rowLabel or ''
    ensureCheatsSettings()
    local capturing = deskCache.cheatCapture == captureId
    local preview = capturing and cheatLiveBindPreview() or cheatBindLabel(settings.cheats, prefix)
    drawDeskBindRow({
        label = rowLabel,
        inline = rowLabel ~= '',
        previewText = preview,
        capturing = capturing,
        keyCapId = '##cap_' .. captureId,
        onCapture = function() beginCheatBindCapture(captureId, 'main') end,
        onClear = function() cheatClearBind(prefix) end,
    })
end

-- Draw Editor List Selectable
function drawEditorListSelectable(label, id, selected, maxW)
    maxW = maxW or (DESK_EDITOR_LIST_W - 24)
    local shown = ellipsizeToWidth(uiText(label or ''), maxW)
    return imgui.Selectable(shown .. id, selected)
end

DESK_FORM_LABEL_W = 188
DESK_FORM_ROW_H = 28
DESK_FORM_PANEL_PAD = 12
DESK_FORM_INPUT_WIDE = 420
DESK_FORM_TOGGLE_W = 42
DESK_FORM_TOGGLE_H = 22
DESK_EDITOR_LIST_W = 248

-- Desk hook/helper.
function deskFormSection(title)
    imgui.Dummy(imgui.ImVec2(0, 8))
    local dl = imgui.GetWindowDrawList()
    local p = imgui.GetCursorScreenPos()
    local w = math.max(40, imgui.GetContentRegionAvail().x)
    if dl and w > 20 then
        dl:AddRectFilled(
            imgui.ImVec2(p.x, p.y),
            imgui.ImVec2(p.x + 3, p.y + 18),
            toU32(col_accent_dim), 2)
    end
    imgui.SetCursorPosX(imgui.GetCursorPosX() + 10)
    imgui.TextColored(col_label, uiText(title or ''))
    imgui.Dummy(imgui.ImVec2(0, 8))
end

-- Desk hook/helper.
function deskFormPanelBegin(id)
    id = tostring(id or 'panel')
    deskCache.ui.panelStack[#deskCache.ui.panelStack + 1] = id
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(8, 10))
    imgui.Dummy(imgui.ImVec2(0, 4))
    imgui.Indent(6)
end

-- Desk hook/helper.
function deskFormPanelEnd()
    imgui.Unindent(6)
    imgui.PopStyleVar()
    if #deskCache.ui.panelStack > 0 then
        table.remove(deskCache.ui.panelStack)
    end
    local dl = imgui.GetWindowDrawList()
    if dl then
        local p = imgui.GetCursorScreenPos()
        local w = math.max(40, imgui.GetContentRegionAvail().x)
        dl:AddLine(
            imgui.ImVec2(p.x, p.y + 3),
            imgui.ImVec2(p.x + w, p.y + 3),
            toU32(imgui.ImVec4(col_accent_dim.x, col_accent_dim.y, col_accent_dim.z, 0.28)),
            1.0)
    end
    imgui.Dummy(imgui.ImVec2(0, 10))
end

-- Desk hook/helper.
function deskFormRowAvail(label, labelW)
    labelW = labelW or DESK_FORM_LABEL_W
    if label and label ~= '' then
        local x = imgui.GetCursorPosX()
        local y = imgui.GetCursorPosY()
        imgui.PushTextWrapPos(x + labelW - 10)
        imgui.TextColored(col_muted2, uiText(label))
        imgui.PopTextWrapPos()
        local yAfter = imgui.GetCursorPosY()
        if yAfter > y + (imgui.GetTextLineHeight() or 14) + 2 then
            imgui.SetCursorPos(imgui.ImVec2(x, yAfter))
            return math.max(72, imgui.GetContentRegionAvail().x - 4)
        end
        imgui.SetCursorPos(imgui.ImVec2(x + labelW, y))
        if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    end
    return math.max(72, imgui.GetContentRegionAvail().x - 4)
end

-- Draw Cheat Card Begin
function drawCheatCardBegin(id, h)
end

-- Draw Cheat Card End
function drawCheatCardEnd()
    imgui.Dummy(imgui.ImVec2(0, 2))
end

-- Draw Cheat Card Title
function drawCheatCardTitle(title, tag)
    local head = title or ''
    if tag and tag ~= '' then
        head = head .. '  [' .. tag .. ']'
    end
    deskFormSection(head)
end

-- Draw Cheat Feature Card
function drawCheatFeatureCard(title, tag, captureId, prefix, stateEnabled, uiEnabled, uiOnStart, onStartKey, onToggle)
    deskFormPanelBegin('##ch_' .. captureId)
    drawCheatCardTitle(title, tag)
    local enLabel = stateEnabled
        and '\xC2\xEA\xEB\xFE\xF7\xE5\xED'
        or '\xC2\xFB\xEA\xEB\xFE\xF7\xE5\xED'
    if deskFormCheckboxRow(enLabel, uiEnabled, onToggle, captureId .. '_en') then end
    if deskFormCheckboxRow('\xC7\xE0\xEF\xF3\xF1\xEA \xEF\xF0\xE8 \xF1\xF2\xE0\xF0\xF2\xE5', uiOnStart, function(v)
        ensureCheatsSettings()
        settings.cheats[onStartKey] = v and true or false
        markDirtySettings()
        flushDirtyConfigNow()
    end, captureId .. '_start') then end
    drawCheatBindRow(prefix, captureId)
    deskFormPanelEnd()
end

