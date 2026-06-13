--[[ Marker wheel / TP (split from report_desk_cheats.lua, same core_a chunk). ]]
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

--[[ РЎРІРѕР±РѕРґРЅРѕРµ РјРµСЃС‚Рѕ вЂ” РєР°Рє AdminTools getCarFreeSeat. ]]
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

--[[ /guns вЂ” РЅР°Р±РѕСЂ РѕСЂСѓР¶РёСЏ РёР· AdminTools (Deagle, M4, MP5), Р±РµР· РїСЂРѕРІРµСЂРєРё admin_lvl. ]]
local DESK_GUNS_KIT = {
    { id = 24, ammo = 100 },
    { id = 31, ammo = 500 },
    { id = 29, ammo = 500 },
}

local function deskEnsureWeaponModel(weaponId)
    if not getWeapontypeModel then return false end
    local model = getWeapontypeModel(weaponId)
    if not model or model == 0 then return false end
    if hasModelLoaded(model) then return true end
    requestModel(model)
    if loadAllModelsNow then loadAllModelsNow() end
    local deadline = os.clock() + 8
    while not hasModelLoaded(model) and os.clock() < deadline do
        wait(0)
    end
    return hasModelLoaded(model)
end

local function deskGiveWeapon(weaponId, ammo)
    if not doesCharExist(PLAYER_PED) then return false end
    if not deskEnsureWeaponModel(weaponId) then return false end
    giveWeaponToChar(PLAYER_PED, weaponId, ammo)
    setCurrentCharWeapon(PLAYER_PED, weaponId)
    return true
end

function deskGiveGuns()
    if sampIsLocalPlayerSpawned and not sampIsLocalPlayerSpawned() then
        say('\xD1\xED\xE0\xF7\xE0\xEB\xE0 \xED\xF3\xE6\xED\xEE \xE1\xFB\xF2\xFC \xE2 \xE8\xE3\xF0\xE5.')
        return
    end
    if not doesCharExist(PLAYER_PED) then return end
    local run = function()
        for _, spec in ipairs(DESK_GUNS_KIT) do
            deskGiveWeapon(spec.id, spec.ammo)
        end
    end
    if lua_thread and lua_thread.create then
        lua_thread.create(run)
    else
        run()
    end
end

--[[ /acar вЂ” 1:1 AdminTools getcar: RPC enter + warp + РјР°С€РёРЅР° Рє РёРіСЂРѕРєСѓ. ]]
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

--[[ РџРѕСЃР°РґРєР° РїРѕ SAMP id + handle (AdminTools getcar / jumpIntoCar). ]]
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
    if markerFixedBindHit(MARKER_BIND_TP) then
        markerTeleportTo(pick)
        markerSetMode(false)
    elseif markerFixedBindHit(MARKER_BIND_VEH) then
        local targetCar = m.aimCar or pick.car or m.hoverCar
        if targetCar and doesVehicleExist(targetCar) then
            local myCar = isCharInAnyCar(PLAYER_PED) and storeCarCharIsInNoSave(PLAYER_PED) or nil
            if not myCar or targetCar ~= myCar then
                local ok, err = markerEnterVehicle(targetCar, pick)
                if not ok and err then
                    say(tostring(err))
                end
            end
        end
        markerSetMode(false)
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
    if uiCheatMaskId then uiCheatMaskId[0] = c.mask_player_id ~= false end
    cheatState.uiMarkerWheel[0] = c.marker_wheel ~= false
    uiCheatAbSpeed[0] = tonumber(c.ab_speed) or 1.0
    cheatsUiSynced = true
end

CHEATS_HUD_W = 54
CHEATS_HUD_H = 68
CHEATS_HUD_PAD_X = 10
CHEATS_HUD_PAD_Y = 8
CHEATS_HUD_LINE_H = 16
CHEATS_HUD_LABEL_W = 96
CHEATS_OVERLAY_PANEL_W = 188
CHEATS_AB_HUD_W = 108
CHEATS_AB_HUD_H = 28
CHEATS_AB_HUD_SIDE_PAD = 12

CHEATS_HUD_LINES = {
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
local function cheatsPersistHudPos(hx, hy, winW, winH, flushNow)
    hx, hy = cheatsClampHudPos(hx, hy, winW, winH)
    local nx = math.floor(hx + 0.5)
    local ny = math.floor(hy + 0.5)
    local ox = math.floor(tonumber(settings.cheats.hud_x) or 12)
    local oy = math.floor(tonumber(settings.cheats.hud_y) or 80)
    cheatState.hudPlaced = true
    if nx == ox and ny == oy then
        return hx, hy
    end
    settings.cheats.hud_x = nx
    settings.cheats.hud_y = ny
    if markDirtySettings then markDirtySettings() end
    if flushNow and flushDirtyConfigNow then pcall(flushDirtyConfigNow) end
    return hx, hy
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
        hx, hy = cheatsPersistHudPos(hx, hy, CHEATS_HUD_W, CHEATS_HUD_H, true)
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
            cheatsPersistHudPos(wp.x, wp.y, ww, wh, true)
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

    local offsetX, offsetY = 16, 18
    local estW, estH = 168, 72
    local pivotX, pivotY = 0.0, 0.0
    local posX, posY = sx + offsetX, sy + offsetY
    if posX + estW > sw - 8 then
        posX = sx - offsetX
        pivotX = 1.0
    end
    if posY + estH > sh - 8 then
        posY = sy - offsetY
        pivotY = 1.0
    end
    posX = math.max(4, math.min(posX, sw - 4))
    posY = math.max(4, math.min(posY, sh - 4))

    local spTheme = cheatsOverlayTheme()
    local labelW = (spTheme and spTheme.HUD_LABEL_W) or CHEATS_HUD_LABEL_W
    imgui.SetNextWindowPos(imgui.ImVec2(posX, posY), imgui.Cond.Always, imgui.ImVec2(pivotX, pivotY))
    if spTheme then spTheme.pushHudChrome() end
    if imgui.Begin('###desk_marker_hud', nil, flags) then
        if spTheme and spTheme.drawPanelFrame then spTheme.drawPanelFrame() end
        if spTheme then
            spTheme.drawPanelTitle('\xCC\xE0\xF0\xEA\xE5\xF0', nil, col_accent, col_muted, uiText)
        else
            imgui.TextColored(col_accent, uiText('\xCC\xE0\xF0\xEA\xE5\xF0'))
        end
        local distM = tonumber(m.dist) or 0
        if spTheme then
            spTheme.drawStatRow(1, '\xD0\xE0\xF1\xF1\xF2\xEE\xFF\xED\xE8\xE5', string.format('%.0f \xEC', distM), col_label,
                labelW, uiText)
            if m.hoverCar and m.vehLabel ~= '' then
                spTheme.drawStatRow(2, '\xCC\xE0\xF8\xE8\xED\xE0', m.vehLabel, col_accent, labelW, uiText)
                if m.aimCar then
                    imgui.TextColored(col_muted, uiText(
                        '\xCB\xCA\xCC \x97 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2 \xB7 \xCF\xCA\xCC \x97 \xEF\xEE\xF1\xE0\xE4\xEA\xE0'))
                else
                    imgui.TextColored(col_muted, uiText('\xCD\xE0\xE2\xE5\xE4\xE8\xF2\xE5 \xED\xE0 \xEC\xE0\xF8\xE8\xED\xF3'))
                end
            else
                imgui.TextColored(col_muted, uiText('\xCB\xCA\xCC \x97 \xF2\xE5\xEB\xE5\xEF\xEE\xF0\xF2'))
            end
            imgui.TextColored(col_muted2, uiText('\xD1\xCA\xCC \x97 \xE2\xFB\xF5\xEE\xE4'))
        end
        imgui.End()
    end
    if spTheme then spTheme.popHudChrome() end
end
