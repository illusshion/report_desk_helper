--[[ Модуль: admin cheats (GM, WH, airbreak, marker, TP). ]]
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

-- Desk hook/helper.
function deskSyncInputFocusState()
    if not showWindow[0] then
        deskInputState.replyFocused = false
        deskInputState.keyboardStickyUntil = 0
        deskInputState.windowOpenSince = 0
        return
    end
    local io = imgui.GetIO and imgui.GetIO()
    local typing = (io and (io.WantTextInput or io.WantCaptureKeyboard))
        or (imgui.IsAnyItemActive and imgui.IsAnyItemActive())
    if typing then
        deskInputState.replyFocused = true
        deskInputState.keyboardStickyUntil = os.clock() + 0.35
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
        deskInputState.keyboardStickyUntil = os.clock() + 0.35
        deskInputState.replyFocused = true
    end
end

-- Desk hook/helper.
function deskWindowWantsKeyboard()
    if not showWindow[0] then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if deskInputState.replyFocused then return true end
    if deskInputState.keyboardStickyUntil > os.clock() then return true end
    local io = imgui.GetIO and imgui.GetIO()
    if io and (io.WantTextInput or io.WantCaptureKeyboard) then return true end
    if imgui.IsAnyItemActive and imgui.IsAnyItemActive() then return true end
    return false
end

-- Desk hook/helper.
function deskImguiTypingActive()
    if deskAnsBarBlocksSampChat() then return true end
    if not showWindow[0] then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if deskInputState.replyFocused then return true end
    if deskInputState.keyboardStickyUntil > os.clock() then return true end
    local io = imgui.GetIO and imgui.GetIO()
    if io and (io.WantTextInput or io.WantCaptureKeyboard) then return true end
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
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    local down = isVkDown(vk)
    if not down then
        deskCache.cheatBindPrev[vk] = false
        return false
    end
    if not deskCache.cheatBindPrev[vk] then
        deskCache.cheatBindPrev[vk] = true
        return true
    end
    return false
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
    local mk = tonumber(settings.cheats.marker_key1) or vkeys.VK_MBUTTON
    if mk <= 0 then mk = vkeys.VK_MBUTTON end
    return vk == mk
end

-- Cheats Process Keybinds
function cheatsProcessKeybinds()
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return end
    if deskInputState.playerSpectating and deskModifierKeysDown() then return end
    ensureCheatsSettings()
    local c = settings.cheats
    local markerToggle = isCheatBindPressed(c, 'marker')
    if markerToggle then
        if not cheatState.marker.active then
            markerToggleMode()
        else
            markerSetMode(false)
        end
    end
    if not cheatState.marker.active then
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
    if cheatState.godmode then cheatsApplyGodmode(true) end
    if cheatState.wallhack then cheatsApplyWallhack(true) end
end

-- Cheats Cleanup
function cheatsCleanup()
    markerSetMode(false)
    if cheatState.airbreak then cheatsSetAirbreak(false) end
    if cheatState.godmode then cheatsApplyGodmode(false) end
    if cheatState.wallhack then cheatsApplyWallhack(false) end
    cheatState.ntBackup = nil
end

-- Marker Remove3d
function markerRemove3d()
    local m = cheatState.marker
    if m.userMarker then
        removeUser3dMarker(m.userMarker)
        m.userMarker = nil
    end
end

-- Marker Set Cursor
function markerSetCursor(on)
    if deskSpectatingNow() then return end
    if on then
        if sampSetCursorMode and CMODE_LOCKCAM then
            sampSetCursorMode(CMODE_LOCKCAM)
        end
    else
        deskRestoreNormalGameCamera()
    end
end

-- Marker Set Mode
function markerSetMode(on)
    local m = cheatState.marker
    if on then
        if showWindow[0] then
            say('\xC7\xE0\xEA\xF0\xEE\xE9\xF2\xE5 Report Desk \xE4\xEB\xFF \xEC\xE0\xF0\xEA\xE5\xF0\xE0')
            return
        end
        if cheatState.airbreak then cheatsSetAirbreak(false) end
        m.active = true
        m.aimCar = nil
        m.hoverCar = nil
        m.pos = nil
        m.vehLabel = ''
        m.vehSampId = nil
        markerSetCursor(true)
    else
        m.active = false
        m.aimCar = nil
        m.hoverCar = nil
        m.pos = nil
        m.vehLabel = ''
        m.vehSampId = nil
        markerRemove3d()
        markerSetCursor(false)
    end
end

-- Marker Toggle Mode
function markerToggleMode()
    markerSetMode(not cheatState.marker.active)
end

-- Marker Find Samp Vehicle Id
function markerFindSampVehicleId(carHandle)
    if not carHandle or not doesVehicleExist(carHandle) then return nil end
    if sampGetVehicleIdByCarHandle then
        local ok, vid = sampGetVehicleIdByCarHandle(carHandle)
        if ok and vid ~= nil then
            vid = tonumber(vid)
            if vid and vid >= 0 then return vid end
        end
    end
    if not sampGetCarHandleBySampVehicleId then return nil end
    local maxId = 2000
    if sampGetMaxVehicleId then
        maxId = tonumber(sampGetMaxVehicleId(false)) or maxId
    end
    for i = 0, maxId do
        local defined = true
        if sampIsVehicleDefined then defined = sampIsVehicleDefined(i) end
        if defined then
            local ok, h = sampGetCarHandleBySampVehicleId(i)
            if ok and h == carHandle then return i end
        end
    end
    return nil
end

--[[ Свободное место — как AdminTools getCarFreeSeat. ]]
function deskGetCarFreeSeat(car)
    if doesCharExist(getDriverOfCar(car)) then
        local maxPass = getMaximumNumberOfPassengers(car)
        for seat = 0, maxPass do
            if isCarPassengerSeatFree(car, seat) then
                return seat + 1
            end
        end
        return nil
    end
    return 0
end

--[[ /acar — 1:1 AdminTools getcar: RPC enter + warp + машина к игроку. ]]
function deskAcarEnter(arg)
    if not arg or not string.match(arg, '%d') then
        say('\xC8\xF1\xEF\xEE\xEB\xFC\xE7\xF3\xE9\xF2\xE5 /acar [ID \xF2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2\xED\xEE\xE3\xEE \xF1\xF0\xE5\xE4\xF1\xF2\xE2\xE0].')
        return
    end
    local vid = tonumber(string.match(arg, '%d+'))
    if not vid then return end
    local ok, car = sampGetCarHandleBySampVehicleId(vid)
    if not ok or not car or not doesVehicleExist(car) then
        say('\xD2\xF0\xE0\xED\xF1\xEF\xEE\xF0\xF2\xED\xEE\xE3\xEE \xF1\xF0\xE5\xE4\xF1\xF2\xE2\xE0 \xF1 \xF2\xE0\xEA\xE8\xEC ID \xE2 \xE7\xEE\xED\xE5 \xEF\xF0\xEE\xF0\xE8\xF1\xEE\xE2\xEA\xE8 \xED\xE5\xF2.')
        return
    end
    if getDriverOfCar(car) ~= -1 then
        say('\xCD\xE5\xEB\xFC\xE7\xFF \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2\xE8\xF0\xEE\xE2\xE0\xF2\xFC\xF1\xFF \xE2 \xD2\xD1 \xF1 \xE8\xE3\xF0\xEE\xEA\xEE\xEC.')
        return
    end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    if sampSendEnterVehicle then sampSendEnterVehicle(vid, false) end
    warpCharIntoCar(PLAYER_PED, car)
    if restoreCameraJumpcut then pcall(restoreCameraJumpcut) end
    setCarCoordinates(car, px, py, pz)
end

--[[ Посадка по SAMP id + handle (AdminTools getcar / jumpIntoCar). ]]
function markerEnterVehicleById(vid, carHandle)
    vid = tonumber(vid)
    if not vid or vid < 0 then return false end
    if sampGetCarHandleBySampVehicleId then
        local ok, h = sampGetCarHandleBySampVehicleId(vid)
        if ok and h and doesVehicleExist(h) then
            carHandle = h
        end
    end
    if not carHandle or not doesVehicleExist(carHandle) then return false end
    if sampIsVehicleDefined and not sampIsVehicleDefined(vid) then return false end

    local seat = deskGetCarFreeSeat(carHandle)
    if seat == nil then return false end
    local asPassenger = (seat ~= 0)

    if sampSendEnterVehicle then
        sampSendEnterVehicle(vid, asPassenger)
    end
    if seat == 0 then
        if type(warpCharIntoCar) ~= 'function' then return false end
        warpCharIntoCar(PLAYER_PED, carHandle)
    else
        warpCharIntoCarAsPassenger(PLAYER_PED, carHandle, seat - 1)
    end
    if restoreCameraJumpcut then pcall(restoreCameraJumpcut) end
    if seat == 0 then
        local px, py, pz = getCharCoordinates(PLAYER_PED)
        setCarCoordinates(carHandle, px, py, pz)
    end
    return true
end

-- Marker Resolve Car And Vid
function markerResolveCarAndVid(carHandle)
    if not carHandle or not doesVehicleExist(carHandle) then
        return nil, nil
    end
    local vid = markerFindSampVehicleId(carHandle)
    if vid and sampGetCarHandleBySampVehicleId then
        local ok, h = sampGetCarHandleBySampVehicleId(vid)
        if ok and h and doesVehicleExist(h) then
            return h, vid
        end
    end
    return carHandle, vid
end

-- Marker Write Placement Coords
function markerWritePlacementCoords(entityPtr, x, y, z)
    return cheatsWritePlacementAt(entityPtr, x, y, z)
end

-- Marker Teleport At
function markerTeleportAt(x, y, z)
    if not doesCharExist(PLAYER_PED) then return end
    if isCharInAnyCar(PLAYER_PED) then
        local car = storeCarCharIsInNoSave(PLAYER_PED)
        if car and doesVehicleExist(car) then
            freezeCarPosition(car, false)
            setCarCollision(car, true)
            if getCarPointer then
                local carPtr = getCarPointer(car)
                if carPtr and carPtr ~= 0 and markerWritePlacementCoords(carPtr, x, y, z) then
                    deskSafeRestoreCamera()
                    return
                end
            end
            setCarCoordinates(car, x, y, z)
            deskSafeRestoreCamera()
        end
        return
    end
    local pedPtr = getCharPointer(PLAYER_PED)
    if pedPtr and markerWritePlacementCoords(pedPtr, x, y, z) then
        deskSafeRestoreCamera()
        return
    end
    setCharCoordinates(PLAYER_PED, x, y, z)
    deskSafeRestoreCamera()
end

-- Marker Enter Vehicle
function markerEnterVehicle(car, pick)
    if not car or not doesVehicleExist(car) then
        return false, '\xCD\xE5\xF2 \xEC\xE0\xF8\xE8\xED\xFB'
    end
    if deskInputState.playerSpectating then
        return false, '\xC2\xFB\xE9\xE4\xE8\xF2\xE5 \xE8\xE7 /sp'
    end
    if cheatState.airbreak then cheatsSetAirbreak(false) end
    freezeCharPosition(PLAYER_PED, false)
    setCharCollision(PLAYER_PED, true)

    local carHandle, vid = markerResolveCarAndVid(car)
    local m = cheatState.marker
    if m and m.vehSampId then
        local cachedVid = tonumber(m.vehSampId)
        if cachedVid and cachedVid >= 0 then
            vid = cachedVid
            if sampGetCarHandleBySampVehicleId then
                local ok, h = sampGetCarHandleBySampVehicleId(vid)
                if ok and h and doesVehicleExist(h) then carHandle = h end
            end
        end
    end
    if not vid then
        return false, '\xCD\xE5 \xED\xE0\xE9\xE4\xE5\xED SAMP ID \xEC\xE0\xF8\xE8\xED\xFB'
    end
    if not carHandle or not doesVehicleExist(carHandle) then
        return false, '\xCD\xE5\xF2 \xEC\xE0\xF8\xE8\xED\xFB'
    end
    if markerEnterVehicleById(vid, carHandle) then
        return true
    end
    return false, '\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xF1\xE5\xF1\xF2\xFC \xE2 \xD2\xD1 (id ' .. tostring(vid) .. ')'
end

-- Marker Teleport To
function markerTeleportTo(pick)
    if not pick or not pick.x then return end
    if cheatState.airbreak then cheatsSetAirbreak(false) end
    local x, y, z = pick.x, pick.y, pick.z
    local carBefore = nil
    if isCharInAnyCar(PLAYER_PED) then
        carBefore = storeCarCharIsInNoSave(PLAYER_PED)
        if carBefore then
            freezeCarPosition(carBefore, false)
            setCarCollision(carBefore, true)
        end
        local wn = pick.wallNormal
        if wn then
            x = x - (wn[1] or 0) * 1.8
            y = y - (wn[2] or 0) * 1.8
        end
        local gn = pick.normal
        if gn and (gn[3] or 0) >= 0.5 then
            z = z - 0.8
        end
    else
        freezeCharPosition(PLAYER_PED, false)
        setCharCollision(PLAYER_PED, true)
    end
    markerTeleportAt(x, y, z)
end

-- Marker Resolve Vehicle Id
function markerResolveVehicleId(car)
    if not car or not doesVehicleExist(car) then return nil end
    return markerFindSampVehicleId(car)
end

-- Marker Nearest Car At
function markerNearestCarAt(x, y, z, maxDist)
    maxDist = tonumber(maxDist) or 3.2
    if not sampGetCarHandleBySampVehicleId then return nil end
    local best, bestD = nil, maxDist
    local maxId = 2000
    if sampGetMaxVehicleId then
        maxId = tonumber(sampGetMaxVehicleId(false)) or maxId
    end
    for i = 0, maxId do
        local defined = true
        if sampIsVehicleDefined then defined = sampIsVehicleDefined(i) end
        if defined then
            local ok, h = sampGetCarHandleBySampVehicleId(i)
            if ok and h and doesVehicleExist(h) then
                local vx, vy, vz = getCarCoordinates(h)
                local d = getDistanceBetweenCoords3d(x, y, z, vx, vy, vz)
                if d < bestD then
                    best = h
                    bestD = d
                end
            end
        end
    end
    return best
end

-- Marker Pick Target
function markerPickTarget(screenX, screenY)
    if not convertScreenCoordsToWorld3D or not processLineOfSight then return nil end
    local wx, wy, wz = convertScreenCoordsToWorld3D(screenX, screenY, 700.0)
    local cx, cy, cz = getActiveCameraCoordinates()
    local hit, col = processLineOfSight(
        cx, cy, cz, wx, wy, wz,
        true, true, false, true, false, false, false, false
    )
    if not hit or not col or not col.pos then return nil end
    local px, py, pz = col.pos[1], col.pos[2], col.pos[3]
    local nx, ny, nz = col.normal[1] or 0, col.normal[2] or 0, col.normal[3] or 0
    local ax, ay, az = px - nx * 0.1, py - ny * 0.1, pz - nz * 0.1
    local rayUp = (nz >= 0.5) and 1.0 or 300.0
    local hit2, col2 = processLineOfSight(
        ax, ay, az + rayUp, ax, ay, az - 0.3,
        true, true, false, true, false, false, false, false
    )
    if not hit2 or not col2 or not col2.pos then return nil end
    local gx = col2.pos[1]
    local gy = col2.pos[2]
    local gz = col2.pos[3] + 1.0
    local car = nil
    local function carFromCol(c)
        if not c or c.entityType ~= 2 or not getVehiclePointerHandle then return nil end
        local h = getVehiclePointerHandle(c.entity)
        if h and doesVehicleExist(h) then return h end
        return nil
    end
    car = carFromCol(col)
    if not car then car = carFromCol(col2) end
    if not car then
        car = markerNearestCarAt(gx, gy, gz, 3.2)
    end
    local px0, py0, pz0 = getCharCoordinates(PLAYER_PED)
    local dist = getDistanceBetweenCoords3d(px0, py0, pz0, gx, gy, gz)
    return {
        x = gx, y = gy, z = gz,
        dist = dist,
        normal = col2.normal,
        wallNormal = { nx, ny, 0 },
        car = car,
    }
end

-- Marker Execute Teleport
function markerExecuteTeleport(pick)
    if not pick then return end
    local m = cheatState.marker
    local targetCar = m.aimCar or pick.car or m.hoverCar
    if targetCar and doesVehicleExist(targetCar) then
        local myCar = isCharInAnyCar(PLAYER_PED) and storeCarCharIsInNoSave(PLAYER_PED) or nil
        if myCar and myCar == targetCar then
            markerSetMode(false)
            return
        end
        local ok, err = markerEnterVehicle(targetCar, pick)
        if not ok and err then
            say(tostring(err))
        end
    else
        markerTeleportTo(pick)
    end
    markerSetMode(false)
end

-- Cheats Tick Marker
function cheatsTickMarker()
    local m = cheatState.marker
    if not m.active then return end
    if showWindow[0] then
        markerSetMode(false)
        return
    end
    if sampGetCursorMode and sampGetCursorMode() == 0 then
        markerSetCursor(true)
    end
    local sx, sy = getCursorPos()
    local sw, sh = getScreenResolution()
    if not sx or not sy or sx < 0 or sy < 0 or sx >= sw or sy >= sh then return end
    local pick = markerPickTarget(sx, sy)
    if not pick then
        m.pos = nil
        m.dist = 0
        m.aimCar = nil
        m.hoverCar = nil
        m.vehLabel = ''
        m.vehSampId = nil
        markerRemove3d()
        return
    end
    m.pos = pick
    m.dist = pick.dist or 0
    m.hoverCar = pick.car
    if pick.car and getNameOfVehicleModel and getCarModel then
        m.vehLabel = getNameOfVehicleModel(getCarModel(pick.car)) or ''
        m.vehSampId = markerResolveVehicleId(pick.car)
    else
        m.vehLabel = ''
        m.vehSampId = nil
    end
    if pick.car and doesVehicleExist(pick.car) then
        local myCar = isCharInAnyCar(PLAYER_PED) and storeCarCharIsInNoSave(PLAYER_PED) or nil
        if not myCar or pick.car ~= myCar then
            m.aimCar = pick.car
        else
            m.aimCar = nil
        end
    else
        m.aimCar = nil
    end
    if createUser3dMarker then
        markerRemove3d()
        m.userMarker = createUser3dMarker(pick.x, pick.y, pick.z + 0.3, 4)
    end
    if isCheatBindPressed(settings.cheats, 'tp') then
        markerExecuteTeleport(pick)
    end
end

-- Sync Cheats Ui From Settings
function syncCheatsUiFromSettings()
    ensureCheatsSettings()
    local c = settings.cheats
    uiCheatGm[0] = cheatState.godmode and true or false
    uiCheatWh[0] = cheatState.wallhack and true or false
    uiCheatAb[0] = cheatState.airbreak and true or false
    uiCheatGmStart[0] = c.gm_on_start and true or false
    uiCheatWhStart[0] = c.wh_on_start and true or false
    uiCheatHud[0] = c.show_hud and true or false
    cheatState.uiMarkerWheel[0] = c.marker_wheel ~= false
    uiCheatAbSpeed[0] = tonumber(c.ab_speed) or 1.0
    cheatsUiSynced = true
end

local CHEATS_HUD_W = 54
local CHEATS_HUD_H = 68
local CHEATS_HUD_PAD_X = 10
local CHEATS_HUD_PAD_Y = 8
local CHEATS_HUD_LINE_H = 16
local CHEATS_HUD_LABEL_W = 96
local CHEATS_OVERLAY_PANEL_W = 188
local CHEATS_AB_HUD_W = 108
local CHEATS_AB_HUD_H = 28
local CHEATS_AB_HUD_SIDE_PAD = 12

local CHEATS_HUD_LINES = {
    { 'WH', function() return cheatState.wallhack end },
    { 'GM', function() return cheatState.godmode end },
    { 'AB', function() return cheatState.airbreak end },
}

-- Cheats Hud Wants Input
function cheatsHudWantsInput()
    if cheatState.hudDrag and cheatState.hudDrag.active then return true end
    if cheatState.hudHovered then return true end
    if deskPointerInRect(cheatState.hudRect) then return true end
    if settings and settings.cheats and settings.cheats.show_hud ~= false then
        local hx = tonumber(settings.cheats.hud_x) or 12
        local hy = tonumber(settings.cheats.hud_y) or 80
        local est = { x0 = hx, y0 = hy, x1 = hx + CHEATS_HUD_W, y1 = hy + CHEATS_HUD_H }
        if deskPointerInRect(est) then return true end
    end
    return false
end

-- Cheats Hud Drag Active
function cheatsIsHudDragActive()
    return cheatState.hudDrag and cheatState.hudDrag.active == true
end

-- Cheats Clamp Hud Pos
local function cheatsClampHudPos(hx, hy, winW, winH)
    local sw, sh = 1280, 720
    if getScreenResolution then
        local rw, rh = getScreenResolution()
        if rw and rw > 0 then sw = rw end
        if rh and rh > 0 then sh = rh end
    end
    winW = math.max(CHEATS_HUD_W, tonumber(winW) or CHEATS_HUD_W)
    winH = math.max(CHEATS_HUD_H, tonumber(winH) or CHEATS_HUD_H)
    hx = math.max(8, math.min(hx, sw - winW - 8))
    hy = math.max(8, math.min(hy, sh - winH - 8))
    return hx, hy
end

-- Cheats Persist Hud Pos
local function cheatsPersistHudPos(hx, hy, winW, winH)
    hx, hy = cheatsClampHudPos(hx, hy, winW, winH)
    settings.cheats.hud_x = math.floor(hx + 0.5)
    settings.cheats.hud_y = math.floor(hy + 0.5)
    if markDirtySettings then markDirtySettings() end
    return hx, hy
end

-- Cheats Overlay Theme
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

-- Draw Cheats Hud Labels
local function drawCheatsHudLabels(wp)
    if not wp or not toU32 then return end
    local dl = imgui.GetWindowDrawList()
    if not dl then return end
    local scale = 1.12
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(scale) end
    for i, row in ipairs(CHEATS_HUD_LINES) do
        local on = row[2]()
        local col = on and col_accent or col_muted2
        local label = row[1]
        local y = wp.y + CHEATS_HUD_PAD_Y + (i - 1) * CHEATS_HUD_LINE_H
        dl:AddText(imgui.ImVec2(wp.x + CHEATS_HUD_PAD_X, y), toU32(col), label)
    end
    if imgui.SetWindowFontScale then imgui.SetWindowFontScale(1.0) end
end

-- Draw Cheats Hud Overlay
function drawCheatsHudOverlay()
    ensureCheatsSettings()
    if settings.cheats.show_hud == false then return end
    if type(deskSampInGame) == 'function' and not deskSampInGame() then return end
    if type(deskGameMenuOpen) == 'function' and deskGameMenuOpen() then
        cheatState.hudDrag.active = false
        return
    end

    local spTheme = cheatsOverlayTheme()
    local drag = cheatState.hudDrag
    local rawHx = tonumber(settings.cheats.hud_x) or 12
    local rawHy = tonumber(settings.cheats.hud_y) or 80
    local hx, hy = cheatsClampHudPos(rawHx, rawHy, CHEATS_HUD_W, CHEATS_HUD_H)
    if not drag.active and not cheatState.hudPlaced
            and (math.floor(hx + 0.5) ~= math.floor(rawHx + 0.5) or math.floor(hy + 0.5) ~= math.floor(rawHy + 0.5)) then
        hx, hy = cheatsPersistHudPos(hx, hy, CHEATS_HUD_W, CHEATS_HUD_H)
    end
    if drag.active then
        hx = drag.offX
        hy = drag.offY
    end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.NoNav
        + imgui.WindowFlags.NoScrollbar
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoSavedSettings then
        flags = flags + imgui.WindowFlags.NoSavedSettings
    end

    imgui.SetNextWindowSize(imgui.ImVec2(CHEATS_HUD_W, CHEATS_HUD_H), imgui.Cond.Always)
    if imgui.SetNextWindowBgAlpha then
        imgui.SetNextWindowBgAlpha(spTheme and spTheme.HUD_OVERLAY_ALPHA or 0.80)
    end
    imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)

    if spTheme then spTheme.pushHudChrome() end
    imgui.PushStyleVarVec2(imgui.StyleVar.WindowPadding, imgui.ImVec2(0, 0))
    imgui.PushStyleVarVec2(imgui.StyleVar.ItemSpacing, imgui.ImVec2(0, 0))
    if imgui.Begin('###desk_cheats_hud', nil, flags) then
        cheatState.hudHovered = false
        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        cheatState.hudRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }

        imgui.SetCursorPos(imgui.ImVec2(0, 0))
        imgui.InvisibleButton('##cheats_hud_drag', imgui.ImVec2(-1, -1))
        if imgui.IsItemHovered() or imgui.IsItemActive() or drag.active then
            cheatState.hudHovered = true
        end
        if not cheatState.hudHovered and deskPointerInRect then
            cheatState.hudHovered = deskPointerInRect(cheatState.hudRect) == true
        end

        if spTheme and spTheme.drawPanelFrame then spTheme.drawPanelFrame() end
        drawCheatsHudLabels(wp)

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
            drag.offX, drag.offY = cheatsClampHudPos(drag.offX, drag.offY, ww, wh)
        elseif drag.active and not imgui.IsMouseDown(0) then
            drag.active = false
            cheatsPersistHudPos(wp.x, wp.y, ww, wh)
            if flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
        end

        imgui.End()
    end
    imgui.PopStyleVar(2)
    if spTheme then spTheme.popHudChrome() end
end

-- Draw Marker Hud Overlay
function drawMarkerHudOverlay()
    local m = cheatState.marker
    if not m.active then return end

    local sx, sy = getCursorPos()
    local sw, sh = getScreenResolution()
    if not sx or not sy or not sw or not sh then return end
    sx, sy = tonumber(sx) or 0, tonumber(sy) or 0
    sw, sh = tonumber(sw) or 800, tonumber(sh) or 600

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoInputs + imgui.WindowFlags.NoNav
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoFocusOnAppearing then
        flags = flags + imgui.WindowFlags.NoFocusOnAppearing
    end

    local padX, padY = 14, 10
    local panelW = CHEATS_OVERLAY_PANEL_W
    local wx, wy = sx + padX, sy + padY
    if wx + panelW > sw - 8 then wx = sw - panelW - 8 end
    if wy + 120 > sh - 8 then wy = sh - 120 - 8 end
    if wx < 4 then wx = 4 end
    if wy < 4 then wy = 4 end

    local spTheme = cheatsOverlayTheme()
    imgui.SetNextWindowSize(imgui.ImVec2(panelW, 0), imgui.Cond.Always)
    imgui.SetNextWindowPos(imgui.ImVec2(wx, wy), imgui.Cond.Always)
    if spTheme then spTheme.pushHudChrome() end
    if imgui.Begin('###desk_marker_hud', nil, flags) then
        if spTheme then
            spTheme.drawPanelTitle('\xCC\xE0\xF0\xEA\xE5\xF0', nil, col_accent, col_muted, uiText)
        else
            imgui.TextColored(col_accent, uiText('\xCC\xE0\xF0\xEA\xE5\xF0'))
        end
        local distM = tonumber(m.dist) or 0
        if spTheme then
            spTheme.drawStatRow(1, '\xD0\xE0\xF1\xF1\xF2\xEE\xFF\xED\xE8\xE5', string.format('%.0f \xEC', distM), col_label,
                CHEATS_HUD_LABEL_W, uiText)
            if m.hoverCar and m.vehLabel ~= '' then
                spTheme.drawStatRow(2, '\xCC\xE0\xF8\xE8\xED\xE0', m.vehLabel, col_accent, CHEATS_HUD_LABEL_W, uiText)
                spTheme.drawStatRow(3, '', m.aimCar and '\xCB\xCA\xCC \x97 \xF1\xE5\xF1\xF2\xFC' or '\xCD\xE0\xE2\xE5\xE4\xE8\xF2\xE5 \xED\xE0 \xEC\xE0\xF8\xE8\xED\xF3',
                    m.aimCar and col_label or col_muted, CHEATS_HUD_LABEL_W, uiText)
            else
                spTheme.drawStatRow(2, '', '\xCB\xCA\xCC \x97 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2', col_muted, CHEATS_HUD_LABEL_W, uiText)
            end
        end
        imgui.End()
    end
    if spTheme then spTheme.popHudChrome() end
end

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
    gm = 'gm', wh = 'wh', ab = 'ab', mk = 'marker', tp = 'tp', vb = 'veh',
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

-- Finish Desk Bind Capture
function finishDeskBindCapture()
    deskCache.hotkeyCapture = false
    deskCache.cheatCapture = nil
    deskCache.cheatCaptureSlot = 'main'
    deskCache.bindCapVk = nil
    deskCache.bindCapIgnoreMouseUntil = 0
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
local function beginDeskBindCaptureSession()
    deskCache.bindCapVk = nil
    deskCache.bindCapIgnoreMouseUntil = os.clock() + 0.35
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
    -- settings.hotkey (F7, M4, M5, …) всегда переключает окно, даже с фокусом в ответе
    return false
end

-- Desk hook/helper.
function deskHotkeyMessageIsDown(msg, wparam, lparam, hk)
    hk = tonumber(hk) or 0
    if hk <= 0 then return false end
    -- M4/M5 и др. кнопки мыши: только WM_*BUTTONDOWN (Windows ещё шлёт WM_KEYDOWN с тем же VK)
    if MOUSE_BIND_VKS[hk] then
        return parseMouseButtonVk(msg, wparam, lparam) == hk
    end
    if msg == deskCache.wm.KEYDOWN or msg == deskCache.wm.SYSKEYDOWN then
        return wparam == hk
    end
    return false
end

-- Desk hook/helper.
function deskResetHotkeyDebounce(vk)
    vk = tonumber(vk) or tonumber(settings.hotkey or vkeys.VK_F7) or 0
    if vk > 0 then deskCache.hotkeyPrev[vk] = false end
end

-- Try Handle Desk Hotkey Message
function tryHandleDeskHotkeyMessage(msg, wparam, lparam)
    if not sessionLive then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return false end
    if isPauseMenuActive and isPauseMenuActive() then return false end
    local hk = settings.hotkey or vkeys.VK_F7
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

-- Skin Tex Release
local function skinTexRelease(tex)
    if tex and imgui.ReleaseTexture then pcall(imgui.ReleaseTexture, tex) end
end

-- Skins Release Textures
function skinsReleaseTextures()
    deskTex.releaseAll(TEX_NS_SKIN, skinTexRelease, true)
    deskTexLoad.clearNamespace(TEX_NS_SKIN)
    deskTexPipeline.requestDeferredFlush()
end

