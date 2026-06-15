--[[ Модуль: anticheat /sp (трассеры, aim line, rapid fire, сбив анимации). ]]
local M = {}

local ffi = require 'ffi'
local vector = require 'vector3d'
local vkeys = require 'lib.vkeys'

local TD_ACCURACY_BASE = 1007
local AIM_LENGTH = 8.0
local AIM_TRANSITION = 0.2
local HP_BUBBLE_COLOR = -1721303041
local ANIM_GUM_EAT = 1157
local ANIM_NAME_GUM = 'gum_eat'

local WEAPON_DEAGLE = 24
local WEAPON_M4 = 31
local WEAPON_NAMES = {
    [WEAPON_DEAGLE] = 'Deagle',
    [WEAPON_M4] = 'M4',
}

-- CP1251: сообщения в SAMP-чат (файл может быть UTF-8 — только \x..)
local MSG_HIT_WALL = '%s[%d] \xEF\xEE\xEF\xE0\xEB \xE2 %s \xF1\xEA\xE2\xEE\xE7\xFC \xF2\xE5\xEA\xF1\xF2\xF3\xF0\xF3/\xEC\xE0\xF8\xE8\xED\xF3'
local MSG_SHOT_WARN = '[Warning] %s[%d] \xF1\xEB\xE8\xF8\xEA\xEE\xEC \xE1\xFB\xF1\xF2\xF0\xEE \xF1\xF2\xF0\xE5\xEB\xFF\xE5\xF2 \xF1 %s {FF0000}%0.2fs./ {00FF08}%0.2fs.'
local MSG_ACCURACY = '\xD2\xEE\xF7\xED\xEE\xF1\xF2\xFC: %d %% ( %d/%d )'
local MSG_SBIV = '\xC2\xEE\xE7\xEC\xEE\xE6\xED\xEE \xF1\xE1\xE8\xE2 \xE0\xED\xE8\xEC\xE0\xF6\xE8\xE8 %s[%d]'
local MSG_NO_ANIM = '\xCD\xE5 \xE2\xEE\xF1\xEF\xF0\xEE\xE8\xE7\xE2\xE5\xEB\xE0\xF1\xFC \xE0\xED\xE8\xEC\xE0\xF6\xE8\xFF \xE0\xEF\xF2\xE5\xF7\xEA\xE8 \xF3 \xE8\xE3\xF0\xEE\xEA\xE0: %s[%d]'

local players = {}
setmetatable(players, {
    __index = function(t, k)
        rawset(t, k, {
            shots = 0,
            hits = 0,
            accuracy = 0,
            last = 0,
            nick = M.playerNick(k),
            lines = {},
        })
        return t[k]
    end,
})

local shotWarning = {}
local sbivList = {}
local cameraData = {} -- [playerId] = { timer, new, old, front? }
local deps = {}
local sampevRef
local hookPrev = {}
local handlers = {}

local function resolveSettings(getSettingsOverride)
    local fn = getSettingsOverride or (deps.getSettings)
    if fn then
        local ok, s = pcall(fn)
        if ok and type(s) == 'table' then return s end
    end
    local g = rawget(_G, 'settings')
    if type(g) == 'table' then return g end
    return nil
end

local getBonePosition = ffi.cast('int (__thiscall*)(void*, float*, int, bool)', 0x5E4280)

-- Default Settings
function M.defaultSettings()
    return {
        tracers = true,
        tracers_all_vision = true,
        tracers_hit_sound = true,
        tracers_text3d = true,
        tracers_sound_id = 1058,
        tracers_max = 10,
        tracers_live_sec = 5,
        tracers_warn_sec = 15,
        tracers_line_border = 2.0,
        aim_line = true,
        aim_line_r = 0.55,
        aim_line_g = 0.21,
        aim_line_b = 1.0,
        aim_line_a = 1.0,
        aim_line_border = 2,
        shot_warn = true,
        shot_deagle_sec = 0.3,
        shot_m4_sec = 0.01,
        anim_cancel = true,
    }
end

-- Ensure Settings
function M.ensureSettings(getSettingsOverride)
    local settings = resolveSettings(getSettingsOverride)
    if type(settings) ~= 'table' then return end
    if type(settings.sp_anticheat) ~= 'table' then
        settings.sp_anticheat = M.defaultSettings()
    end
    local ac = settings.sp_anticheat
    local d = M.defaultSettings()
    for k, v in pairs(d) do
        if ac[k] == nil then ac[k] = v end
    end
    ac.distant_chat = nil
    ac.distant_chat_x = nil
    ac.distant_chat_y = nil
    ac.distant_chat_font = nil
    ac.distant_chat_page = nil
    ac.distant_chat_max = nil
    ac.distant_chat_hotkey = nil
end

local function acfg()
    M.ensureSettings()
    local settings = resolveSettings()
    if settings and settings.sp_anticheat then return settings.sp_anticheat end
    return M.defaultSettings()
end

-- Player Nick
function M.playerNick(id)
    id = tonumber(id)
    if id and type(sampIsPlayerConnected) == 'function' and sampIsPlayerConnected(id) then
        local ok, n = pcall(sampGetPlayerNickname, id)
        if ok and n and n ~= '' then return n end
    end
    if id and PLAYER_PED and type(sampGetPlayerIdByCharHandle) == 'function' then
        local ok, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
        if ok and myId == id and type(sampGetPlayerNickname) == 'function' then
            local ok2, n = pcall(sampGetPlayerNickname, id)
            if ok2 and n then return n end
        end
    end
    return 'player:' .. tostring(id)
end

local function localPlayerId()
    if not PLAYER_PED or type(sampGetPlayerIdByCharHandle) ~= 'function' then return -1 end
    local ok, id = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
    return ok and tonumber(id) or -1
end

local function spectateTargetId()
    if deps.getTargetId then
        local ok, id = pcall(deps.getTargetId)
        if ok then return tonumber(id) or -1 end
    end
    if type(deskSpectateStats) == 'table' and deskSpectateStats.getTargetId then
        local ok, id = pcall(deskSpectateStats.getTargetId)
        if ok then return tonumber(id) or -1 end
    end
    return -1
end

local function isSpectating()
    if deps.isSpectating then
        local ok, v = pcall(deps.isSpectating)
        if ok and v == true then return true end
    end
    if spectateTargetId() >= 0 then return true end
    local g = rawget(_G, 'deskSpectatingNow')
    if type(g) == 'function' then
        local ok, v = pcall(g)
        if ok and v == true then return true end
    end
    if type(deskSpectateStats) == 'table' and type(deskSpectateStats.isSpectating) == 'function' then
        local ok, v = pcall(deskSpectateStats.isSpectating)
        if ok and v == true then return true end
    end
    return false
end

local function copyVec(v)
    if not v then return nil end
    return vector(tonumber(v.x) or 0, tonumber(v.y) or 0, tonumber(v.z) or 0)
end

local function spectateTargetPed()
    if deps.resolveSpectateTargetPed then
        local ok, ped, id = pcall(deps.resolveSpectateTargetPed)
        if ok and ped and type(doesCharExist) == 'function' and doesCharExist(ped) then
            return ped, tonumber(id) or spectateTargetId()
        end
        if ok and id then return nil, tonumber(id) or spectateTargetId() end
    end
    local id = spectateTargetId()
    if id < 0 or type(sampGetCharHandleBySampPlayerId) ~= 'function' then return nil, id end
    local ok, ped = pcall(sampGetCharHandleBySampPlayerId, id)
    if ok and ped and type(doesCharExist) == 'function' and doesCharExist(ped) then
        return ped, id
    end
    return nil, id
end

local function aimOffsetFromSync(headPos, data)
    if not data then return nil end
    local cp = data.camPos
    if cp and (cp.x ~= 0 or cp.y ~= 0 or cp.z ~= 0) then
        return copyVec(headPos - cp)
    end
    local cf = data.camFront
    if cf then
        local fx, fy, fz = tonumber(cf.x) or 0, tonumber(cf.y) or 0, tonumber(cf.z) or 0
        local len = math.sqrt(fx * fx + fy * fy + fz * fz)
        if len > 0.001 then
            return vector(fx / len * AIM_LENGTH, fy / len * AIM_LENGTH, fz / len * AIM_LENGTH)
        end
    end
    return nil
end

local function featureActive()
    if deps.isGameMenuOpen then
        local ok, open = pcall(deps.isGameMenuOpen)
        if ok and open then return false end
    end
    if deps.isSampInGame then
        local ok, ingame = pcall(deps.isSampInGame)
        if ok and not ingame then return false end
    end
    return isSpectating()
end

local function aimEndFromHeading(headPos, ped)
    if not ped or type(getCharHeading) ~= 'function' then return nil end
    local ok, heading = pcall(getCharHeading, ped)
    if not ok or not heading then return nil end
    local rad = math.rad(tonumber(heading) or 0)
    return headPos + vector(-math.sin(rad) * AIM_LENGTH, math.cos(rad) * AIM_LENGTH, 0.05)
end

local function joinArgb(a, r, g, b)
    local argb = b
    argb = bit.bor(argb, bit.lshift(g, 8))
    argb = bit.bor(argb, bit.lshift(r, 16))
    argb = bit.bor(argb, bit.lshift(a, 24))
    return argb
end

local function getBodyPartCoordinates(boneId, handle)
    if not getCharPointer or type(getCharPointer) ~= 'function' then return false end
    local ptr = getCharPointer(handle)
    if ptr == 0 then return false end
    local pos = ffi.new('float[3]')
    getBonePosition(ffi.cast('void*', ptr), pos, boneId, true)
    return true, vector(pos[0], pos[1], pos[2])
end

local function bringFloatTo(from, dest, startTime, duration)
    local timer = os.clock() - startTime
    if timer >= 0 and timer <= duration then
        local count = timer / (duration / 100)
        return from + (count * (dest - from) / 100)
    end
    return timer > duration and dest or from
end

local function notifyChat(text)
    text = tostring(text or '')
    if text == '' then return end
    if deps.ensureWireCp1251 then
        local ok, wired = pcall(deps.ensureWireCp1251, text)
        if ok and type(wired) == 'string' and wired ~= '' then text = wired end
    end
    if type(sampAddChatMessage) == 'function' then
        pcall(sampAddChatMessage, text, -1)
    end
end

local function aimLineEnabled()
    return acfg().aim_line == true
end

local function aimLineContextActive()
    return aimLineEnabled() and spectateTargetId() >= 0
end

local function drawAimLine(ac, data)
    local ped = spectateTargetPed()
    if not ped or type(doesCharExist) ~= 'function' or not doesCharExist(ped) then return end
    local result, headPos = getBodyPartCoordinates(8, ped)
    if not result then return end

    local camPos
    if data and data.front then
        local front = data.front
        local fl = front:length()
        if fl > 0.001 then
            camPos = headPos + front * (AIM_LENGTH / fl)
        end
    end
    if not camPos and data and data.new and data.old then
        local offset = data.old
        offset.x = bringFloatTo(data.old.x, data.new.x, data.timer, AIM_TRANSITION)
        offset.y = bringFloatTo(data.old.y, data.new.y, data.timer, AIM_TRANSITION)
        offset.z = bringFloatTo(data.old.z, data.new.z, data.timer, AIM_TRANSITION)
        camPos = headPos + offset
        local fullLen = (camPos - headPos):length()
        if fullLen > 0.001 then
            camPos = headPos + (camPos - headPos) * (AIM_LENGTH / fullLen)
        end
    end
    if not camPos then
        camPos = aimEndFromHeading(headPos, ped)
    end
    if not camPos then return end

    local r = math.floor((tonumber(ac.aim_line_r) or 0.55) * 255)
    local g = math.floor((tonumber(ac.aim_line_g) or 0.21) * 255)
    local b = math.floor((tonumber(ac.aim_line_b) or 1) * 255)
    local a = math.floor((tonumber(ac.aim_line_a) or 1) * 255)
    local col = joinArgb(a, r, g, b)
    local border = tonumber(ac.aim_line_border) or 2
    local hx, hy, hz = headPos:get()
    local cx, cy, cz = camPos:get()
    if type(convert3DCoordsToScreen) == 'function' and type(renderDrawLine) == 'function' then
        local pX, pY = convert3DCoordsToScreen(hx, hy, hz)
        local cX, cY = convert3DCoordsToScreen(cx, cy, cz)
        renderDrawLine(pX, pY, cX, cY, border, col)
        if type(renderDrawPolygon) == 'function' then
            renderDrawPolygon(cX, cY, 4, 4, 8, 0, 0xFFFFFFFF)
        end
    end
end

local function vehicleModelName(id)
    if type(sampGetCarHandleBySampVehicleId) ~= 'function' then return 'veh:' .. tostring(id) end
    local res, car = sampGetCarHandleBySampVehicleId(id)
    if res and type(getCarModel) == 'function' and type(getNameOfVehicleModel) == 'function' then
        return getNameOfVehicleModel(getCarModel(car))
    end
    return 'veh:' .. tostring(id)
end

local function destroyAccuracyText(id)
    id = tonumber(id)
    if not id then return end
    local drawId = TD_ACCURACY_BASE + id
    if type(sampIs3dTextDefined) == 'function' and type(sampDestroy3dText) == 'function' then
        if sampIs3dTextDefined(drawId) then pcall(sampDestroy3dText, drawId) end
    end
end

local function destroyAllAccuracyTexts()
    if type(sampGetMaxPlayerId) ~= 'function' then return end
    local ok, maxId = pcall(sampGetMaxPlayerId, false)
    maxId = ok and tonumber(maxId) or 1000
    for id = 0, maxId do destroyAccuracyText(id) end
end

local function renderLine3d(x, y, z, x2, y2, z2, width, color)
    if type(convert3DCoordsToScreen) ~= 'function' or type(renderDrawLine) ~= 'function' then return end
    local pX, pY = convert3DCoordsToScreen(x, y, z)
    local pX2, pY2 = convert3DCoordsToScreen(x2, y2, z2)
    if type(isPointOnScreen) == 'function' then
        if not isPointOnScreen(x, y, z, 1) or not isPointOnScreen(x2, y2, z2, 1) then return end
    end
    renderDrawLine(pX, pY, pX2, pY2, width, color)
end

local function shouldShowTracersFor(id)
    local ac = acfg()
    if not ac.tracers then return false end
    if not featureActive() then return false end
    local target = spectateTargetId()
    if id == target then return true end
    if ac.tracers_all_vision then return true end
    if deps.isVkDown and deps.isVkDown(vkeys.VK_MENU) then return true end
    if type(isKeyDown) == 'function' and isKeyDown(vkeys.VK_MENU) then return true end
    return false
end

local function processBulletSync(playerId, data)
    if not data or not data.origin or not data.target then return end
    local ac = acfg()
    if not ac.tracers and not ac.tracers_hit_sound and not ac.tracers_text3d and not ac.shot_warn then
        return
    end

    playerId = tonumber(playerId) or localPlayerId()
    local last = players[playerId]
    last.nick = M.playerNick(playerId)

    local O, T = data.origin, data.target
    local target = spectateTargetId()

    if ac.tracers_hit_sound and playerId == target and data.targetType == 1 then
        if type(addOneOffSound) == 'function' then
            pcall(addOneOffSound, 0, 0, 0, tonumber(ac.tracers_sound_id) or 1058)
        end
    end

    local hitState = data.targetType == 1 and M.playerNick(data.targetId)
        or data.targetType == 2 and vehicleModelName(data.targetId)
        or 'Miss'

    last.last = os.clock()
    last.shots = last.shots + 1
    if data.targetType == 1 or data.targetType == 2 then
        last.hits = last.hits + 1
    end

    local warning = false
    if ac.tracers and data.targetType == 1 and type(isLineOfSightClear) == 'function' then
        if not isLineOfSightClear(O.x, O.y, O.z, T.x, T.y, T.z, true, false, false, false, true) then
            warning = true
            notifyChat(string.format(MSG_HIT_WALL, last.nick, playerId, hitState))
        end
    end

    local accuracy = math.floor(math.max(100 * last.hits / last.shots, 0))
    last.accuracy = accuracy

    if ac.tracers then
        local color
        if warning then
            color = 0xFFFF0000
        elseif type(sampGetPlayerColor) == 'function' then
            local ok, pc = pcall(sampGetPlayerColor, playerId)
            if ok and pc then
                color = bit.bor(bit.band(0xFFFFFF, pc), bit.lshift(0xFF, 24))
            else
                color = 0xFFFFFFFF
            end
        else
            color = 0xFFFFFFFF
        end
        local btrace = {
            from = { x = O.x, y = O.y, z = O.z },
            to = { x = T.x, y = T.y, z = T.z },
            color = color,
            expires = os.clock() + (warning and (tonumber(ac.tracers_warn_sec) or 15) or (tonumber(ac.tracers_live_sec) or 5)),
        }
        local maxN = math.max(1, tonumber(ac.tracers_max) or 10)
        while #last.lines >= maxN do table.remove(last.lines, 1) end
        last.lines[#last.lines + 1] = btrace
    end

    if ac.tracers_text3d and playerId ~= localPlayerId() then
        if type(sampCreate3dTextEx) == 'function' and type(sampGetPlayerColor) == 'function' then
            local ok, pc = pcall(sampGetPlayerColor, playerId)
            local col = ok and pc and bit.bor(bit.band(0xFFFFFF, pc), bit.lshift(0xFF, 24)) or 0xFFFFFFFF
            local text = string.format(MSG_ACCURACY, accuracy, last.hits, last.shots)
            pcall(sampCreate3dTextEx, TD_ACCURACY_BASE + playerId, text, col, 0, 0, -0.7, 20, false, playerId, -1)
        end
    end

    if ac.shot_warn and WEAPON_NAMES[data.weaponId] then
        local minSec = data.weaponId == WEAPON_DEAGLE and (tonumber(ac.shot_deagle_sec) or 0.3)
            or (tonumber(ac.shot_m4_sec) or 0.01)
        if not shotWarning[playerId] then shotWarning[playerId] = {} end
        if not shotWarning[playerId][data.weaponId] then
            shotWarning[playerId][data.weaponId] = { last_tick = 0, warning = 0, warning_tick = 0 }
        end
        local pData = shotWarning[playerId][data.weaponId]
        if os.clock() - pData.last_tick < minSec then
            pData.warning = (tonumber(pData.warning) or 0) + 1
            pData.warning_tick = os.clock()
            if pData.warning > 2 then
                local wname = WEAPON_NAMES[data.weaponId] or ('gun:' .. tostring(data.weaponId))
                local dt = os.clock() - pData.last_tick
                notifyChat(string.format(MSG_SHOT_WARN, last.nick, playerId, wname, dt, minSec))
                pData.warning = 0
            end
        end
        pData.last_tick = os.clock()
    end
end

local function trackSbiv(playerId, ped, durationSec)
    if not acfg().anim_cancel then return end
    playerId = tonumber(playerId)
    if not playerId or playerId < 0 then return end
    sbivList[playerId] = {
        time = os.clock() + (tonumber(durationSec) or 4),
        ped = ped,
        id = playerId,
        start = false,
    }
end

local function checkSbivSync(playerId, data)
    if not acfg().anim_cancel then return end
    local pData = sbivList[playerId]
    if not pData then return end
    if pData.time <= os.clock() or not pData.ped or (type(doesCharExist) == 'function' and not doesCharExist(pData.ped)) then
        sbivList[playerId] = nil
        return
    end
    if type(isCharInAnyCar) == 'function' and isCharInAnyCar(pData.ped) then
        sbivList[playerId] = nil
        return
    end
    local animId = data and data.animationId
    if animId ~= ANIM_GUM_EAT and pData.start then
        notifyChat(string.format(MSG_SBIV, M.playerNick(playerId), playerId))
        sbivList[playerId] = nil
    elseif animId ~= ANIM_GUM_EAT and not pData.start and (pData.time - os.clock() < 2.1) then
        notifyChat(string.format(MSG_NO_ANIM, M.playerNick(playerId), playerId))
        sbivList[playerId] = nil
    elseif not pData.start and animId == ANIM_GUM_EAT then
        pData.start = true
    end
end

function M.onSpectateStart()
    cameraData = {}
end

function M.onSpectateEnd()
    cameraData = {}
    destroyAllAccuracyTexts()
end

function M.onPlayerQuit(playerId)
    playerId = tonumber(playerId)
    if not playerId then return end
    destroyAccuracyText(playerId)
    players[playerId] = nil
    shotWarning[playerId] = nil
    sbivList[playerId] = nil
end

function M.resetSession()
    players = {}
    setmetatable(players, {
        __index = function(t, k)
            rawset(t, k, {
                shots = 0, hits = 0, accuracy = 0, last = 0,
                nick = M.playerNick(k), lines = {},
            })
            return t[k]
        end,
    })
    shotWarning = {}
    sbivList = {}
    cameraData = {}
    destroyAllAccuracyTexts()
end

function M.tick()
    M.ensureSettings()
    local ac = acfg()
    local now = os.clock()

    for playerId, gunData in pairs(shotWarning) do
        if playerId == localPlayerId()
                or (type(sampIsPlayerConnected) == 'function' and sampIsPlayerConnected(playerId)) then
            for _, pData in pairs(gunData or {}) do
                if now - (pData.warning_tick or 0) > 7 then pData.warning = 0 end
            end
        else
            shotWarning[playerId] = nil
        end
    end

    for id, pdata in pairs(players) do
        if type(sampIsPlayerConnected) == 'function' and not sampIsPlayerConnected(id) and id ~= localPlayerId() then
            destroyAccuracyText(id)
            players[id] = nil
        end
    end
end

function M.shouldDrawNative()
    local ac = acfg()
    if not ac then return false end
    if ac.tracers and featureActive() then return true end
    if ac.aim_line and aimLineContextActive() then return true end
    return false
end

function M.drawNative()
    if not M.shouldDrawNative() then return end
    if type(sampIsScoreboardOpen) == 'function' and sampIsScoreboardOpen() then return end
    local ac = acfg()
    local clock = os.clock()
    local target = spectateTargetId()

    if ac.tracers then
        local border = tonumber(ac.tracers_line_border) or 2
        for id, pdata in pairs(players) do
            if shouldShowTracersFor(id) and pdata.lines and #pdata.lines > 0 then
                for k = #pdata.lines, 1, -1 do
                    local btrace = pdata.lines[k]
                    if btrace and clock < btrace.expires then
                        local fx, fy, fz = btrace.from.x, btrace.from.y, btrace.from.z
                        local tx, ty, tz = btrace.to.x, btrace.to.y, btrace.to.z
                        if type(isPointOnScreen) == 'function'
                                and isPointOnScreen(fx, fy, fz) and isPointOnScreen(tx, ty, tz) then
                            local ax, ay = convert3DCoordsToScreen(fx, fy, fz)
                            local bx, by = convert3DCoordsToScreen(tx, ty, tz)
                            renderDrawLine(ax, ay, bx, by, border, btrace.color)
                            if type(renderDrawPolygon) == 'function' then
                                renderDrawPolygon(ax, ay, 4, 4, 8, 0, 0xFFFFFFFF)
                                renderDrawPolygon(bx, by, 4, 4, 8, 0, 0xFFFFFFFF)
                            end
                        end
                    else
                        table.remove(pdata.lines, k)
                    end
                end
            end
        end
    end

    if ac.aim_line and target >= 0 then
        drawAimLine(ac, cameraData[target])
        for id, _ in pairs(cameraData) do
            if tonumber(id) ~= target then cameraData[id] = nil end
        end
    end
end

function M.onText3dDisabled()
    destroyAllAccuracyTexts()
end

function M.previewHitSound()
    local ac = acfg()
    if type(addOneOffSound) == 'function' then
        pcall(addOneOffSound, 0, 0, 0, tonumber(ac.tracers_sound_id) or 1058)
    end
end

function M.configure(d)
    deps = d or {}
    if deps.getSettings == nil and type(rawget(_G, 'settings')) == 'table' then
        deps.getSettings = function() return rawget(_G, 'settings') end
    end
end

local function updateAimCameraData(playerId, data)
    playerId = tonumber(playerId)
    if not playerId or playerId < 0 or not data then return end
    if not aimLineContextActive() then return end
    if playerId ~= spectateTargetId() then return end

    local newOff
    local ped = spectateTargetPed()
    if ped then
        local result, headPos = getBodyPartCoordinates(8, ped)
        if result then
            newOff = aimOffsetFromSync(headPos, data)
        end
    end
    local front
    if data.camFront then
        local cf = data.camFront
        if (tonumber(cf.x) or 0) ~= 0 or (tonumber(cf.y) or 0) ~= 0 or (tonumber(cf.z) or 0) ~= 0 then
            front = copyVec(cf)
        end
    end
    if not newOff and not front then return end

    if not cameraData[playerId] then
        cameraData[playerId] = {
            timer = os.clock(),
            new = newOff and copyVec(newOff) or nil,
            old = newOff and copyVec(newOff) or nil,
            front = front,
        }
    else
        local slot = cameraData[playerId]
        slot.timer = os.clock()
        if newOff then
            slot.old = slot.new and copyVec(slot.new) or copyVec(newOff)
            slot.new = copyVec(newOff)
        end
        if front then slot.front = front end
    end
end

local function buildHandlers()
    handlers.onBulletSync = function(playerId, data)
        if featureActive() then pcall(processBulletSync, playerId, data) end
        if type(hookPrev.onBulletSync) == 'function' then return hookPrev.onBulletSync(playerId, data) end
    end

    handlers.onSendBulletSync = function(data)
        if featureActive() then
            local ok, myId = pcall(sampGetPlayerIdByCharHandle, PLAYER_PED)
            pcall(processBulletSync, ok and myId or localPlayerId(), data)
        end
        if type(hookPrev.onSendBulletSync) == 'function' then return hookPrev.onSendBulletSync(data) end
    end

    handlers.onAimSync = function(playerId, data)
        pcall(updateAimCameraData, playerId, data)
        if type(hookPrev.onAimSync) == 'function' then return hookPrev.onAimSync(playerId, data) end
    end

    handlers.onApplyPlayerAnimation = function(playerId, animLib, animName, frameDelta, loop, lockX, lockY, freeze, time)
        if featureActive() and animName == ANIM_NAME_GUM then
            local bool, handler = pcall(sampGetCharHandleBySampPlayerId, playerId)
            local selfId = localPlayerId()
            if playerId == selfId then bool, handler = true, PLAYER_PED end
            if bool and handler and (not isCharInAnyCar or not isCharInAnyCar(handler)) then
                trackSbiv(playerId, handler, frameDelta)
            end
        end
        if type(hookPrev.onApplyPlayerAnimation) == 'function' then
            return hookPrev.onApplyPlayerAnimation(playerId, animLib, animName, frameDelta, loop, lockX, lockY, freeze, time)
        end
    end

    handlers.onClearPlayerAnimation = function(playerId)
        sbivList[playerId] = nil
        if type(hookPrev.onClearPlayerAnimation) == 'function' then
            return hookPrev.onClearPlayerAnimation(playerId)
        end
    end

    handlers.onPlayerSync = function(playerId, data)
        if featureActive() then pcall(checkSbivSync, playerId, data) end
        if type(hookPrev.onPlayerSync) == 'function' then return hookPrev.onPlayerSync(playerId, data) end
    end

    handlers.onSendPlayerSync = function(data)
        if featureActive() then pcall(checkSbivSync, localPlayerId(), data) end
        if type(hookPrev.onSendPlayerSync) == 'function' then return hookPrev.onSendPlayerSync(data) end
    end

    handlers.onPlayerChatBubble = function(playerId, color, distance, duration, message)
        if featureActive() then
            local ac = acfg()
            if ac and ac.anim_cancel and color == HP_BUBBLE_COLOR and message and message:match('%+%d+%s+Hp') then
                local bool, handler = pcall(sampGetCharHandleBySampPlayerId, playerId)
                if bool and handler and (not isCharInAnyCar or not isCharInAnyCar(handler)) then
                    trackSbiv(playerId, handler, 4)
                end
            end
        end
        if type(hookPrev.onPlayerChatBubble) == 'function' then
            return hookPrev.onPlayerChatBubble(playerId, color, distance, duration, message)
        end
    end
end

local function ensureHandlers()
    if handlers.onAimSync then return end
    buildHandlers()
end

local function chain(name)
    if not sampevRef then return end
    local handler = handlers[name]
    if not handler then return end
    hookPrev[name] = sampevRef[name]
    if hookPrev[name] == handler then hookPrev[name] = nil end
    sampevRef[name] = handler
end

function M.installSampev(sampev)
    if not sampev or sampevRef then return end
    sampevRef = sampev
    M.ensureSettings()
    ensureHandlers()

    chain('onBulletSync')
    chain('onSendBulletSync')
    chain('onAimSync')
    chain('onApplyPlayerAnimation')
    chain('onClearPlayerAnimation')
    chain('onPlayerSync')
    chain('onSendPlayerSync')
    chain('onPlayerChatBubble')
end

function M.uninstallSampev(sampev)
    local ev = sampev or sampevRef
    if not ev then return end
    ensureHandlers()
    for name, handler in pairs(handlers) do
        if ev[name] == handler then
            ev[name] = hookPrev[name]
        end
    end
    sampevRef = nil
    hookPrev = {}
    handlers = {}
end

return M
