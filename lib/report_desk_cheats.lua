--[[ Report Desk cheats / marker ]]
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

function cheatsInputsBlocked()
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    if sampIsDialogActive and sampIsDialogActive() then return true end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if showWindow[0] then return true end
    if deskInputState.playerSpectating and deskTextInputActive() then return true end
    return false
end

function deskSyncInputFocusState()
    if not showWindow[0] then
        deskInputState.replyFocused = false
        deskInputState.keyboardStickyUntil = 0
        deskInputState.windowOpenSince = 0
        return
    end
    local io = imgui.GetIO and imgui.GetIO()
    if io and (io.WantTextInput or io.WantCaptureKeyboard) then
        deskInputState.keyboardStickyUntil = os.clock() + 0.85
    end
end

function deskWindowWantsKeyboard()
    if not showWindow[0] then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if deskInputState.replyFocused then return true end
    if deskInputState.keyboardStickyUntil > os.clock() then return true end
    local io = imgui.GetIO and imgui.GetIO()
    if io and (io.WantTextInput or io.WantCaptureKeyboard) then return true end
    if imgui.IsAnyItemActive and imgui.IsAnyItemActive() then return true end
    if imgui.IsWindowHovered and imgui.HoveredFlags and imgui.IsWindowHovered(imgui.HoveredFlags.AnyWindow) then
        return true
    end
    return false
end

function deskImguiTypingActive()
    if not showWindow[0] then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return true end
    if deskInputState.replyFocused then return true end
    if deskInputState.keyboardStickyUntil > os.clock() then return true end
    local io = imgui.GetIO and imgui.GetIO()
    if io and (io.WantTextInput or io.WantCaptureKeyboard) then return true end
    if imgui.IsAnyItemActive and imgui.IsAnyItemActive() then return true end
    return false
end

function deskTextInputActive()
    if sampIsChatInputActive and sampIsChatInputActive() then return true end
    return deskImguiTypingActive()
end

function deskModifierKeysDown()
    if not vkeys then return false end
    return isVkDown(vkeys.VK_SHIFT) or isVkDown(vkeys.VK_MENU) or isVkDown(vkeys.VK_CONTROL)
end

function isVkDown(vk)
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    if cheat_user32 and cheat_user32.GetAsyncKeyState then
        local ok, st = pcall(cheat_user32.GetAsyncKeyState, vk)
        if ok and st then return (st % 65536) >= 32768 end
    end
    return isKeyDown and isKeyDown(vk)
end

function cheatModDown(vk)
    return isVkDown(vk)
end

function cheatModifiersMatch(c, prefix)
    if c[prefix .. '_ctrl'] and not cheatModDown(vkeys.VK_CONTROL) then return false end
    if c[prefix .. '_shift'] and not cheatModDown(vkeys.VK_SHIFT) then return false end
    if c[prefix .. '_alt'] and not cheatModDown(vkeys.VK_MENU) then return false end
    return true
end

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

function cheatsAbKeyDown(vk)
    if sampIsChatInputActive and sampIsChatInputActive() then return false end
    if sampIsDialogActive and sampIsDialogActive() then return false end
    if deskCache.hotkeyCapture or deskCache.cheatCapture then return false end
    return isVkDown(vk)
end

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

function cheatsGetAbSpeed()
    if cheatState.abSpeedLive ~= nil then
        return cheatState.abSpeedLive
    end
    ensureCheatsSettings()
    return tonumber(settings.cheats.ab_speed) or 1.0
end

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

function cheatsResetAbKeyHold()
    cheatState.abKeyHold.q.held = false
    cheatState.abKeyHold.q.nextAt = 0
    cheatState.abKeyHold.e.held = false
    cheatState.abKeyHold.e.nextAt = 0
end

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

function cheatsToggleWallhack()
    cheatsApplyWallhack(not cheatState.wallhack)
end

function cheatsToggleAirbreak()
    cheatsSetAirbreak(not cheatState.airbreak)
end

function deskHotkeyBlockedByMarkerWheel(vk)
    ensureCheatsSettings()
    if settings.cheats.marker_wheel == false then return false end
    vk = tonumber(vk) or 0
    if vk <= 0 then return false end
    local mk = tonumber(settings.cheats.marker_key1) or vkeys.VK_MBUTTON
    if mk <= 0 then mk = vkeys.VK_MBUTTON end
    return vk == mk
end

function cheatsProcessKeybinds()
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

function cheatsApplyStartup()
    ensureCheatsSettings()
    local c = settings.cheats
    if c.gm_on_start then cheatsApplyGodmode(true) end
    if c.wh_on_start then cheatsApplyWallhack(true) end
    uiCheatAbSpeed[0] = tonumber(c.ab_speed) or 1.0
end

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

function cheatsCleanup()
    markerSetMode(false)
    if cheatState.airbreak then cheatsSetAirbreak(false) end
    if cheatState.godmode then cheatsApplyGodmode(false) end
    if cheatState.wallhack then cheatsApplyWallhack(false) end
    cheatState.ntBackup = nil
end

function markerRemove3d()
    local m = cheatState.marker
    if m.userMarker then
        removeUser3dMarker(m.userMarker)
        m.userMarker = nil
    end
end

function markerSetCursor(on)
    if on then
        if sampSetCursorMode and CMODE_LOCKCAM then
            sampSetCursorMode(CMODE_LOCKCAM)
        end
    elseif deskSpectatingNow() then
        deskRestoreSpectateCamera()
    else
        deskRestoreNormalGameCamera()
    end
end

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

function markerToggleMode()
    markerSetMode(not cheatState.marker.active)
end

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

--[[ Свободное место — водитель / пассажир. ]]
function deskGetCarFreeSeat(car)
    local driver = getDriverOfCar(car)
    if driver == -1 or driver == nil or not doesCharExist(driver) then
        return 0
    end
    local maxPass = getMaximumNumberOfPassengers(car)
    for seat = 0, maxPass do
        if isCarPassengerSeatFree(car, seat) then
            return seat + 1
        end
    end
    return nil
end

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

function markerWritePlacementCoords(entityPtr, x, y, z)
    return cheatsWritePlacementAt(entityPtr, x, y, z)
end

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

--[[ Посадка в ТС: только свободное место через sampSendEnterVehicle. Закрытые — /getcar на сервере (админ). ]]
local DESK_ENTER_VEH_POLL_MS = 50
local DESK_ENTER_VEH_TIMEOUT_MS = 4500
local DESK_ENTER_VEH_TP_DIST = 4.0
local DESK_ENTER_VEH_BUSY_TIMEOUT = 8.0
local deskEnterVehBusy = false
local deskEnterVehBusySince = 0

function deskEnterVehBusyClear()
    deskEnterVehBusy = false
    deskEnterVehBusySince = 0
end

function deskEnterVehBusyClaim()
    if deskEnterVehBusy then
        if deskEnterVehBusySince > 0 and os.clock() - deskEnterVehBusySince > DESK_ENTER_VEH_BUSY_TIMEOUT then
            deskEnterVehBusyClear()
        else
            return false
        end
    end
    deskEnterVehBusy = true
    deskEnterVehBusySince = os.clock()
    return true
end

function deskMyVehicleSampId()
    if not isCharInAnyCar(PLAYER_PED) then return nil, nil end
    local car = storeCarCharIsInNoSave(PLAYER_PED)
    if not car or not doesVehicleExist(car) then return nil, nil end
    local vid = markerFindSampVehicleId(car)
    return car, vid
end

function deskWaitEnterRpc(vehId, timeoutMs)
    vehId = tonumber(vehId)
    if not vehId then return false end
    local deadline = os.clock() + (tonumber(timeoutMs) or DESK_ENTER_VEH_TIMEOUT_MS) / 1000
    while os.clock() < deadline do
        local _, vid = deskMyVehicleSampId()
        if vid == vehId then
            return true
        end
        wait(DESK_ENTER_VEH_POLL_MS)
    end
    return select(2, deskMyVehicleSampId()) == vehId
end

function deskPlaceBesideCar(car)
    if not car or not doesVehicleExist(car) then return false end
    if isCharInAnyCar(PLAYER_PED) then return false end
    local cx, cy, cz = getCarCoordinates(car)
    local h = getCarHeading(car)
    local r = math.rad(h)
    local tx = cx + math.cos(r) * 2.0
    local ty = cy + math.sin(r) * 2.0
    local tz = cz + 0.45
    if getGroundZFor3dCoord then
        local gz = getGroundZFor3dCoord(tx, ty, cz + 10.0)
        if gz and gz > -100 then tz = gz + 0.45 end
    end
    setCharCoordinates(PLAYER_PED, tx, ty, tz)
    deskSafeRestoreCamera()
    return true
end

function deskLeaveCurrentVehicleIfNeeded(targetVid)
    targetVid = tonumber(targetVid)
    local car, vid = deskMyVehicleSampId()
    if not car then return true end
    if targetVid and vid == targetVid then return true end
    local px, py, pz = getCharCoordinates(PLAYER_PED)
    if vid and sampSendExitVehicle then
        sampSendExitVehicle(vid)
        wait(200)
    end
    if isCharInAnyCar(PLAYER_PED) then
        if warpCharFromCarToCoord then
            warpCharFromCarToCoord(PLAYER_PED, px + 1.2, py + 0.6, pz + 0.2)
        else
            setCharCoordinates(PLAYER_PED, px + 1.2, py + 0.6, pz + 0.2)
        end
        wait(100)
        deskSafeRestoreCamera()
    end
    return not isCharInAnyCar(PLAYER_PED)
end

function deskEnterVehicleSamp(vehId, carHandle)
    vehId = tonumber(vehId)
    if not vehId or vehId < 0 then return false end
    if sampGetCarHandleBySampVehicleId then
        local ok, h = sampGetCarHandleBySampVehicleId(vehId)
        if ok and h and doesVehicleExist(h) then carHandle = h end
    end
    if not carHandle or not doesVehicleExist(carHandle) then return false end
    if sampIsVehicleDefined and not sampIsVehicleDefined(vehId) then return false end

    if cheatState.marker.active then
        pcall(markerSetMode, false)
    end
    pcall(function()
        if sampToggleCursor then sampToggleCursor(false) end
        if sampSetCursorMode and CMODE_DISABLED then sampSetCursorMode(CMODE_DISABLED) end
    end)

    local _, myVid = deskMyVehicleSampId()
    if myVid == vehId then return true end

    local seat = deskGetCarFreeSeat(carHandle)
    if seat == nil then return false end
    local asPassenger = (seat ~= 0)

    if cheatState.airbreak then cheatsSetAirbreak(false) end
    freezeCharPosition(PLAYER_PED, false)
    setCharCollision(PLAYER_PED, true)

    if not deskLeaveCurrentVehicleIfNeeded(vehId) then return false end

    local px, py, pz = getCharCoordinates(PLAYER_PED)
    local cx, cy, cz = getCarCoordinates(carHandle)
    if getDistanceBetweenCoords3d(px, py, pz, cx, cy, cz) > DESK_ENTER_VEH_TP_DIST then
        if not deskPlaceBesideCar(carHandle) then return false end
        wait(120)
    end

    if sampSendEnterVehicle then
        sampSendEnterVehicle(vehId, asPassenger)
    end
    if deskWaitEnterRpc(vehId, DESK_ENTER_VEH_TIMEOUT_MS) then
        deskSafeRestoreCamera()
        return true
    end
    if sampSendEnterVehicle then
        wait(200)
        sampSendEnterVehicle(vehId, asPassenger)
        if deskWaitEnterRpc(vehId, DESK_ENTER_VEH_TIMEOUT_MS) then
            deskSafeRestoreCamera()
            return true
        end
    end
    return select(2, deskMyVehicleSampId()) == vehId
end

function deskEnterVehicleAsync(vehId, carHandle, onDone)
    if not deskEnterVehBusyClaim() then
        if onDone then onDone(false, '\xCF\xEE\xF1\xE0\xE4\xEA\xE0 \xF3\xE6\xE5 \xE2\xFB\xEF\xEE\xEB\xED\xFF\xE5\xF2\xF1\xFF') end
        return false
    end
    lua_thread.create(function()
        local ok, err = false, nil
        local function finish()
            deskEnterVehBusyClear()
            if onDone then onDone(ok, err) end
        end
        local runOk, runErr = pcall(function()
            if deskInputState.playerSpectating then
                err = '\xC2\xFB\xE9\xE4\xE8\xF2\xE5 \xE8\xE7 /sp'
                return
            end
            ok = deskEnterVehicleSamp(vehId, carHandle)
            if not ok then
                err = '\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xF1\xE5\xF1\xF2\xFC \xE2 \xD2\xD1 (\xED\xE5\xF2 \xEC\xE5\xF1\xF2\xE0 \xE8\xEB\xE8 \xEC\xE0\xF8\xE8\xED\xE0 \xE7\xE0\xED\xFF\xF2\xE0)'
            end
        end)
        if not runOk then
            ok = false
            err = tostring(runErr)
        end
        finish()
    end)
    return true
end

function markerEnterVehicle(car, pick)
    if not car or not doesVehicleExist(car) then
        return false, '\xCD\xE5\xF2 \xEC\xE0\xF8\xE8\xED\xFB'
    end
    local carHandle, vid = markerResolveCarAndVid(car)
    if not vid then
        return false, '\xCD\xE5 \xED\xE0\xE9\xE4\xE5\xED SAMP ID \xEC\xE0\xF8\xE8\xED\xFB'
    end
    if not carHandle then
        carHandle = car
    end
    local seat = deskGetCarFreeSeat(carHandle)
    if seat == nil then
        return false, '\xCD\xE5\xF2 \xF1\xE2\xEE\xE1\xEE\xE4\xED\xFB\xF5 \xEC\xE5\xF1\xF2'
    end
    if not deskEnterVehicleAsync(vid, carHandle, function(ok, err)
        if ok then
            say('\xCF\xEE\xF1\xE0\xE4\xEA\xE0 \xE2 \xD2\xD1 (id ' .. tostring(vid or '?') .. ')')
        elseif err then
            say(tostring(err))
        else
            say('\xCD\xE5 \xF3\xE4\xE0\xEB\xEE\xF1\xFC \xF1\xE5\xF1\xF2\xFC \xE2 \xD2\xD1')
        end
    end) then
        return false, '\xCF\xEE\xF1\xE0\xE4\xEA\xE0 \xF3\xE6\xE5 \xE2\xFB\xEF\xEE\xEB\xED\xFF\xE5\xF2\xF1\xFF'
    end
    return true
end

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

function markerResolveVehicleId(car)
    if not car or not doesVehicleExist(car) then return nil end
    return markerFindSampVehicleId(car)
end

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

function cheatsHudWantsInput()
    if cheatState.hudDrag.active then return true end
    if cheatState.hudHovered then return true end
    local r = cheatState.hudRect
    if not r then return false end
    local mp = imgui.GetIO().MousePos
    return mp.x >= r.x0 and mp.x < r.x1 and mp.y >= r.y0 and mp.y < r.y1
end

function drawCheatsHudOverlay()
    ensureCheatsSettings()
    cheatState.hudHovered = false
    if settings.cheats.show_hud == false then return end
    local hx = tonumber(settings.cheats.hud_x) or 12
    local hy = tonumber(settings.cheats.hud_y) or 80
    local wantInput = cheatsHudWantsInput()
    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoNav + imgui.WindowFlags.NoScrollbar
    if not wantInput and imgui.WindowFlags.NoInputs then
        flags = flags + imgui.WindowFlags.NoInputs
    end
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    imgui.SetNextWindowBgAlpha(0.75)
    if not cheatState.hudPlaced then
        imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)
        cheatState.hudPlaced = true
    elseif cheatState.hudDrag.active then
        imgui.SetNextWindowPos(imgui.ImVec2(hx, hy), imgui.Cond.Always)
    end
    if imgui.Begin('###desk_cheats_hud', nil, flags) then
        local wp = imgui.GetWindowPos()
        local ww = imgui.GetWindowWidth()
        local wh = imgui.GetWindowHeight()
        local mp = imgui.GetIO().MousePos
        cheatState.hudHovered = mp.x >= wp.x and mp.x < wp.x + ww and mp.y >= wp.y and mp.y < wp.y + wh
        cheatState.hudRect = { x0 = wp.x, y0 = wp.y, x1 = wp.x + ww, y1 = wp.y + wh }
        local function row(label, on)
            if on then
                imgui.TextColored(imgui.ImVec4(0.4, 0.9, 0.5, 1), uiText(label .. ': ON'))
            else
                imgui.TextColored(col_muted2, uiText(label .. ': off'))
            end
        end
        row('GM', cheatState.godmode)
        row('WH', cheatState.wallhack)
        row('AB', cheatState.airbreak)
        if cheatState.marker.active then
            imgui.TextColored(col_warn, uiText('Marker: ON'))
        end
        if cheatState.hudHovered and imgui.IsMouseDragging(0) and not imgui.IsAnyItemActive() then
            local delta = imgui.GetMouseDragDelta(0)
            if not cheatState.hudDrag.active then
                local wp = imgui.GetWindowPos()
                cheatState.hudDrag.active = true
                cheatState.hudDrag.offX = wp.x
                cheatState.hudDrag.offY = wp.y
                imgui.ResetMouseDragDelta(0)
            end
            local nx = cheatState.hudDrag.offX + delta.x
            local ny = cheatState.hudDrag.offY + delta.y
            settings.cheats.hud_x = nx
            settings.cheats.hud_y = ny
            if imgui.SetWindowPos then
                imgui.SetWindowPos(imgui.ImVec2(nx, ny))
            end
            markDirtySettings()
        elseif cheatState.hudDrag.active and not imgui.IsMouseDown(0) then
            cheatState.hudDrag.active = false
            flushDirtyConfigNow()
        end
        if cheatState.hudHovered and imgui.IsMouseReleased(0) and not imgui.IsAnyItemActive() then
            local wp = imgui.GetWindowPos()
            settings.cheats.hud_x = wp.x
            settings.cheats.hud_y = wp.y
            markDirtySettings()
            flushDirtyConfigNow()
        end
        imgui.End()
    end
end

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
    local wx, wy = sx + padX, sy + padY
    local estW, estH = 160, 72
    if wx + estW > sw - 8 then wx = sw - estW - 8 end
    if wy + estH > sh - 8 then wy = sh - estH - 8 end
    if wx < 4 then wx = 4 end
    if wy < 4 then wy = 4 end

    imgui.SetNextWindowBgAlpha(0.88)
    imgui.SetNextWindowPos(imgui.ImVec2(wx, wy), imgui.Cond.Always)
    if imgui.Begin('###desk_marker_hud', nil, flags) then
        imgui.TextColored(col_accent, uiText('\xCC\xE0\xF0\xEA\xE5\xF0'))
        local distM = tonumber(m.dist) or 0
        imgui.TextColored(col_muted2, uiText(string.format('%.0f \xEC', distM)))
        if m.hoverCar and m.vehLabel ~= '' then
            imgui.Text(uiText(m.vehLabel))
            if m.aimCar then
                imgui.TextColored(col_label, uiText('\xCB\xCA\xCC \x97 \xF1\xE5\xF1\xF2\xFC'))
            else
                imgui.TextColored(col_muted, uiText('\xCD\xE0\xE2\xE5\xE4\xE8\xF2\xE5 \xED\xE0 \xEC\xE0\xF8\xE8\xED\xF3'))
            end
        else
            imgui.TextColored(col_muted, uiText('\xCB\xCA\xCC \x97 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2'))
        end
        imgui.End()
    end
end

function drawAirbreakHudOverlay()
    if not cheatState.airbreak then return end
    local spd = cheatsGetAbSpeed()
    local io = imgui.GetIO()
    local sw, sh = io.DisplaySize.x, io.DisplaySize.y
    if sw < 100 then sw = 1920 end
    if sh < 100 then sh = 1080 end

    local flags = imgui.WindowFlags.NoDecoration + imgui.WindowFlags.AlwaysAutoResize
        + imgui.WindowFlags.NoInputs + imgui.WindowFlags.NoNav
    if imgui.WindowFlags.NoBringToFrontOnFocus then
        flags = flags + imgui.WindowFlags.NoBringToFrontOnFocus
    end
    if imgui.WindowFlags.NoFocusOnAppearing then
        flags = flags + imgui.WindowFlags.NoFocusOnAppearing
    end

    imgui.SetNextWindowBgAlpha(0.88)
    imgui.SetNextWindowPos(imgui.ImVec2(sw * 0.5, sh - 72), imgui.Cond.Always, imgui.ImVec2(0.5, 1.0))
    if imgui.Begin('###desk_ab_hud', nil, flags) then
        imgui.TextColored(col_accent, uiText('AirBreak'))
        imgui.SameLine(0, 10)
        imgui.TextColored(col_label, uiText(string.format('%.2f', spd)))
        local flash = cheatState.abSpeedFlash
        if flash and flash.expires and os.clock() < flash.expires then
            local msg
            if flash.dir and flash.dir < 0 then
                msg = string.format('\xCC\xE5\xE4\xEB\xE5\xED\xED\xE5\xE5 \x97 %.2f', flash.spd or spd)
            else
                msg = string.format('\xC1\xFB\xF1\xF2\xF0\xE5\xE5 \x97 %.2f', flash.spd or spd)
            end
            imgui.TextColored(flash.dir and flash.dir < 0 and col_muted or col_warn, uiText(msg))
        else
            cheatState.abSpeedFlash = nil
            imgui.TextColored(col_muted2, uiText('Q \xEC\xE8\xED\xF3\xF1   E \xEF\xEB\xFE\xF1'))
        end
        imgui.End()
    end
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
DESK_BIND_MENU_BTN_W = 32
DESK_FORM_INPUT_W = 160

AB_SPEED_STEP = 0.04
AB_SPEED_FLASH_SEC = 2.0
AB_SPEED_HOLD_DELAY = 0.16
AB_SPEED_HOLD_REPEAT = 0.05

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

function cheatLiveBindPreview()
    local parts = {}
    if cheatModDown(vkeys.VK_CONTROL) then parts[#parts + 1] = 'Ctrl' end
    if cheatModDown(vkeys.VK_SHIFT) then parts[#parts + 1] = 'Shift' end
    if cheatModDown(vkeys.VK_MENU) then parts[#parts + 1] = 'Alt' end
    for vk in pairs(MOUSE_BIND_VKS) do
        if isVkDown(vk) then parts[#parts + 1] = vkToLabel(vk) end
    end
    if #parts == 0 then
        return uiText('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 \xEA\xEB\xE0\xE2\xE8\xF8\xF3 \xE8\xEB\xE8 \xEC\xFB\xF8\xFC')
    end
    return uiText(table.concat(parts, '+') .. '+...')
end

function beginCheatBindCapture(captureId, slot)
    hideDeskWindowForCapture()
    deskCache.cheatCapture = captureId
    deskCache.cheatCaptureSlot = slot or 'main'
    deskCache.cheatCaptureAt = os.clock()
end

function beginHotkeyCapture()
    hideDeskWindowForCapture()
    deskCache.hotkeyCapture = true
    deskCache.hotkeyCaptureAt = os.clock()
end

function cancelDeskBindCapture()
    deskCache.hotkeyCapture = false
    deskCache.cheatCapture = nil
    deskCache.cheatCaptureSlot = 'main'
end

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

function drawDeskBindCaptureBanner()
    if not deskCache.hotkeyCapture and not deskCache.cheatCapture then return end
    local dl = imgui.GetWindowDrawList()
    if not dl then return end
    local p = imgui.GetCursorScreenPos()
    local w = imgui.GetContentRegionAvail().x
    if w < 40 then return end
    local h = 28
    dl:AddRectFilled(imgui.ImVec2(p.x, p.y), imgui.ImVec2(p.x + w, p.y + h),
        toU32(imgui.ImVec4(0.45, 0.32, 0.08, 0.92)), 6)
    profanityDlText(dl, p.x + 10, p.y + 6, col_warn,
        uiText('\xCD\xE0\xE6\xEC\xE8\xF2\xE5 \xEA\xEB\xE0\xE2\xE8\xF8\xF3 \xE8\xEB\xE8 \xEC\xFB\xF8\xFC (Esc \x97 \xEE\xF2\xEC\xE5\xED\xE0)'), 1)
    imgui.Dummy(imgui.ImVec2(0, h + 4))
end

function deskFormPushBindButtonStyle()
    imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.11, 0.11, 0.14, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.18, 0.16, 0.24, 1.0))
    imgui.PushStyleColor(imgui.Col.ButtonActive, col_accent_dim)
end

function deskFormPopBindButtonStyle()
    imgui.PopStyleColor(3)
end

function deskHotkeyBlockedByTyping()
    -- settings.hotkey (F7, M4, M5, …) всегда переключает окно, даже с фокусом в ответе
    return false
end

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

function deskResetHotkeyDebounce(vk)
    vk = tonumber(vk) or tonumber(settings.hotkey or vkeys.VK_F7) or 0
    if vk > 0 then deskCache.hotkeyPrev[vk] = false end
end

function tryHandleDeskHotkeyMessage(msg, wparam, lparam)
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

function drawDeskBindKeyCap(previewText, capturing, btnId, onClick)
    local menuW = DESK_BIND_MENU_BTN_W + 8
    local capW = math.max(72, imgui.GetContentRegionAvail().x - menuW)
    local shown = ellipsizeToWidth(uiText(previewText or ''), capW - 16)
    if capturing then
        imgui.PushStyleColor(imgui.Col.Button, imgui.ImVec4(0.45, 0.32, 0.08, 0.95))
        imgui.PushStyleColor(imgui.Col.ButtonHovered, imgui.ImVec4(0.52, 0.38, 0.10, 1.0))
        imgui.PushStyleColor(imgui.Col.ButtonActive, imgui.ImVec4(0.48, 0.34, 0.09, 1.0))
        imgui.PushStyleColor(imgui.Col.Text, col_warn)
    else
        deskFormPushBindButtonStyle()
        imgui.PushStyleColor(imgui.Col.Text, col_label)
    end
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6)
    local clicked = imgui.Button(shown .. btnId, imgui.ImVec2(capW, DESK_FORM_ROW_H))
    imgui.PopStyleVar()
    imgui.PopStyleColor(4)
    if clicked and onClick then onClick() end
end

function drawDeskBindMenuButton(popupId, drawPopupBody, btnId)
    imgui.SameLine(0, 8)
    deskFormPushBindButtonStyle()
    imgui.PushStyleVarFloat(imgui.StyleVar.FrameRounding, 6)
    if imgui.Button('...' .. btnId, imgui.ImVec2(DESK_BIND_MENU_BTN_W, DESK_FORM_ROW_H)) and imgui.OpenPopup then
        imgui.OpenPopup(popupId)
    end
    imgui.PopStyleVar()
    deskFormPopBindButtonStyle()
    if drawPopupBody and imgui.BeginPopup and imgui.BeginPopup(popupId) then
        drawPopupBody()
        imgui.EndPopup()
    end
end

function drawDeskBindRow(opts)
    opts = opts or {}
    if opts.label and opts.label ~= '' then
        deskFormRowLabel(opts.label)
    end
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    drawDeskBindKeyCap(opts.previewText, opts.capturing, opts.keyCapId or '##bind_cap', opts.onCapture)
    drawDeskBindMenuButton(opts.popupId or '##bind_popup', opts.drawPopup, opts.menuBtnId or '##bind_menu')
    if opts.presets and #opts.presets > 0 then
        imgui.Dummy(imgui.ImVec2(0, 4))
        drawDeskBindPresetChips(opts.presets, opts.onPresetPick, opts.chipPrefix or 'bp')
    end
    imgui.Dummy(imgui.ImVec2(0, 2))
end

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

function drawDeskBindValueRow(previewText, capturing, btnId, popupId, drawPopupBody)
    drawDeskBindRow({
        previewText = previewText,
        capturing = capturing,
        keyCapId = btnId,
        onCapture = nil,
        popupId = popupId,
        drawPopup = drawPopupBody,
        menuBtnId = btnId .. '_menu',
    })
end

function drawCheatBindPreviewText(text, capturing, maxW)
    if imgui.AlignTextToFramePadding then imgui.AlignTextToFramePadding() end
    local shown = ellipsizeToWidth(uiText(text or ''), maxW or DESK_BIND_PREVIEW_W)
    imgui.TextColored(capturing and col_warn or col_muted, shown)
end

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

function deskFormCheckboxRow(label, boolRef, onChange, stableId)
    return deskFormToggleRow(label, boolRef, onChange, stableId)
end

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

function drawCheatBindRow(prefix, captureId, rowLabel)
    rowLabel = rowLabel or '\xC1\xE8\xED\xE4'
    ensureCheatsSettings()
    local capturing = deskCache.cheatCapture == captureId
    local preview = capturing and cheatLiveBindPreview() or cheatBindLabel(settings.cheats, prefix)
    local popup = '##cheat_bp_' .. prefix .. '_' .. captureId
    local chipPresets = {
        { 'M4', vkeys.VK_XBUTTON1 },
        { 'M5', vkeys.VK_XBUTTON2 },
        { uiText('\xCF\xCA\xCC'), vkeys.VK_RBUTTON },
        { uiText('\xD1\xCA\xCC'), vkeys.VK_MBUTTON },
    }
    drawDeskBindRow({
        label = rowLabel,
        previewText = preview,
        capturing = capturing,
        keyCapId = '##cap_' .. captureId,
        onCapture = function() beginCheatBindCapture(captureId, 'main') end,
        popupId = popup,
        menuBtnId = '##menu_' .. captureId,
        chipPrefix = 'ch_' .. captureId,
        drawPopup = function()
            ensureCheatsSettings()
            local c = settings.cheats
            local function closePopup()
                if imgui.CloseCurrentPopup then imgui.CloseCurrentPopup() end
            end
            if imgui.Selectable(uiText('\xCD\xE0\xE7\xED\xE0\xF7\xE8\xF2\xFC \xE2\xF0\xF3\xF7\xED\xF3\xFE') .. '##ch_man_' .. captureId) then
                beginCheatBindCapture(captureId, 'main')
                closePopup()
            end
            if imgui.Selectable(uiText('\xC2\xF2\xEE\xF0\xE0\xFF \xEA\xEB\xE0\xE2\xE8\xF8\xE0') .. '##ch_k2_' .. captureId) then
                beginCheatBindCapture(captureId, 'key2')
                closePopup()
            end
            if (tonumber(c[prefix .. '_key2']) or 0) > 0
                    and imgui.Selectable(uiText('\xD3\xE1\xF0\xE0\xF2\xFC 2-\xFE \xEA\xEB\xE0\xE2\xE8\xF8\xF3') .. '##ch_clr2_' .. captureId) then
                c[prefix .. '_key2'] = 0
                markDirtySettings()
                closePopup()
            end
            if imgui.Selectable(uiText('\xD1\xE1\xF0\xEE\xF1\xE8\xF2\xFC \xE1\xE8\xED\xE4') .. '##ch_rst_' .. captureId) then
                cheatClearBind(prefix)
                closePopup()
            end
        end,
        presets = chipPresets,
        onPresetPick = function(vk)
            ensureCheatsSettings()
            local c = settings.cheats
            c[prefix .. '_key1'] = vk
            c[prefix .. '_key2'] = 0
            c[prefix .. '_ctrl'] = false
            c[prefix .. '_shift'] = false
            c[prefix .. '_alt'] = false
            markDirtySettings()
        end,
    })
end

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

function deskFormSection(title)
    imgui.Dummy(imgui.ImVec2(0, 10))
    imgui.TextColored(col_accent, uiText(title))
    imgui.Dummy(imgui.ImVec2(0, 4))
    local dl = imgui.GetWindowDrawList()
    if dl then
        local p = imgui.GetCursorScreenPos()
        local w = imgui.GetContentRegionAvail().x
        if w > 20 then
            dl:AddLine(
                imgui.ImVec2(p.x, p.y),
                imgui.ImVec2(p.x + w, p.y),
                toU32(imgui.ImVec4(col_accent_dim.x, col_accent_dim.y, col_accent_dim.z, 0.4)),
                1.0)
        end
    end
    imgui.Dummy(imgui.ImVec2(0, 8))
end

function deskFormPanelBegin(id)
    id = tostring(id or 'panel')
    deskCache.ui.panelStack[#deskCache.ui.panelStack + 1] = id
    imgui.Dummy(imgui.ImVec2(0, 6))
    imgui.Indent(8)
end

function deskFormPanelEnd()
    if #deskCache.ui.panelStack > 0 then
        table.remove(deskCache.ui.panelStack)
    end
    imgui.Unindent(8)
    local dl = imgui.GetWindowDrawList()
    if dl then
        local p = imgui.GetCursorScreenPos()
        local w = math.max(40, imgui.GetContentRegionAvail().x)
        dl:AddLine(
            imgui.ImVec2(p.x, p.y + 2),
            imgui.ImVec2(p.x + w, p.y + 2),
            toU32(imgui.ImVec4(col_accent_dim.x, col_accent_dim.y, col_accent_dim.z, 0.35)),
            1.0)
    end
    imgui.Dummy(imgui.ImVec2(0, 10))
end

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

function drawCheatCardBegin(id, h)
end

function drawCheatCardEnd()
    imgui.Dummy(imgui.ImVec2(0, 2))
end

function drawCheatCardTitle(title, tag)
    local head = title or ''
    if tag and tag ~= '' then
        head = head .. '  [' .. tag .. ']'
    end
    deskFormSection(head)
end

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

local function skinTexRelease(tex)
    if tex and imgui.ReleaseTexture then pcall(imgui.ReleaseTexture, tex) end
end

function skinsReleaseTextures()
    deskTex.releaseAll(TEX_NS_SKIN, skinTexRelease, true)
    deskTexLoad.clearNamespace(TEX_NS_SKIN)
    deskTexPipeline.requestDeferredFlush()
end

