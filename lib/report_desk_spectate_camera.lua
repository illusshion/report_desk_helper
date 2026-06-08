--[[ Модуль: зум камеры колёсиком в /sp.
     Реализация как sp_plus: дистанция CCamera (0xB6F028), без RPC/setFixedCamera. ]]
local M = {}

local memory = require 'memory'

local WM_MOUSEWHEEL = 0x020A
local WM_MOUSEHWHEEL = 0x020E

local CAM_BASE = 0xB6F028
local OFF_ACTIVATE_A = 0x38
local OFF_ACTIVATE_B = 0x39
local OFF_DIST_FIELDS = { 0xD4, 0xD8, 0xC0, 0xC4 }

local DEFAULT_DIST = 5.0
local DEFAULT_STEP = 5.0
local MIN_DIST = 0.0
local MAX_DIST = 120.0

local cam = {
    distance = DEFAULT_DIST,
    defaultDistance = DEFAULT_DIST,
    customized = false,
}

local deps = {}

-- Wheel Enabled
local function wheelEnabled()
    if deps.getSettings then
        local s = deps.getSettings()
        if s and s.spectate_wheel_zoom == false then return false end
    end
    return true
end

-- Is Spectating
local function isSpectating()
    if deps.isSpectating then
        local ok, v = pcall(deps.isSpectating)
        return ok and v == true
    end
    return false
end

-- Wheel Blocked
local function wheelBlocked()
    if not isSpectating() then return true end
    if deps.isWheelBlocked then
        local ok, v = pcall(deps.isWheelBlocked)
        if ok and v == true then return true end
    end
    return false
end

-- Wheel Step
local function wheelStep()
    if deps.getSettings then
        local s = deps.getSettings()
        local step = s and tonumber(s.spectate_wheel_step)
        if step and step > 0 then return step end
    end
    return DEFAULT_STEP
end

-- Wheel Max Dist
local function wheelMaxDist()
    if deps.getSettings then
        local s = deps.getSettings()
        local maxD = s and tonumber(s.spectate_wheel_max)
        if maxD and maxD > MIN_DIST then return maxD end
    end
    return MAX_DIST
end

-- Set Distance Activated
local function setDistanceActivated(on)
    if not memory or not memory.setuint8 then return end
    local v = on and 1 or 0
    pcall(memory.setuint8, CAM_BASE + OFF_ACTIVATE_A, v)
    pcall(memory.setuint8, CAM_BASE + OFF_ACTIVATE_B, v)
end

-- Set Camera Distance
local function setCameraDistance(dist)
    if not memory or not memory.setfloat then return end
    local maxD = wheelMaxDist()
    dist = math.max(MIN_DIST, math.min(maxD, tonumber(dist) or DEFAULT_DIST))
    cam.distance = dist
    for i = 1, #OFF_DIST_FIELDS do
        pcall(memory.setfloat, CAM_BASE + OFF_DIST_FIELDS[i], dist, true)
    end
end

-- Apply Camera Distance
local function applyCameraDistance()
    if not cam.customized then return end
    setDistanceActivated(true)
    setCameraDistance(cam.distance)
end

-- Restore Default Camera Distance
local function restoreDefaultCameraDistance()
    cam.customized = false
    setDistanceActivated(false)
    if not memory or not memory.setfloat then return end
    for i = 1, #OFF_DIST_FIELDS do
        pcall(memory.setfloat, CAM_BASE + OFF_DIST_FIELDS[i], cam.defaultDistance, true)
    end
    cam.distance = cam.defaultDistance
end

-- Update Camera Distance
local function updateCameraDistance(delta)
    cam.customized = true
    setCameraDistance(cam.distance + (tonumber(delta) or 0))
    applyCameraDistance()
end

-- Wheel Delta
local function wheelDelta(wparam)
    local wp = tonumber(wparam) or 0
    if wp < 0 then wp = wp + 4294967296 end
    local delta = bit.rshift(wp, 16)
    if delta >= 32768 then delta = delta - 65536 end
    return delta
end

-- Публичный API модуля.
function M.onSpectateStart()
    -- Сброс wheel-zoom от прошлой сессии; activate distance только после колёсика.
    if cam.customized then
        restoreDefaultCameraDistance()
    end
end

-- Публичный API модуля.
function M.onSpectateEnd()
    restoreDefaultCameraDistance()
end

-- Публичный API модуля.
function M.onServerCameraBehind()
    -- sp_plus не трогает zoom на behind; сброс не нужен.
end

-- Публичный API модуля.
function M.maintain()
    if not cam.customized or cam.distance == cam.defaultDistance then return end
    if not wheelEnabled() or not isSpectating() then return end
    if deps.isUiBlockingCamera then
        local ok, v = pcall(deps.isUiBlockingCamera)
        if ok and v then return end
    end
    applyCameraDistance()
end

-- Публичный API модуля.
function M.handleWindowMessage(msg, wparam)
    if msg ~= WM_MOUSEWHEEL and msg ~= WM_MOUSEHWHEEL then return false end
    if not wheelEnabled() or wheelBlocked() then return false end

    local delta = wheelDelta(wparam)
    if msg == WM_MOUSEHWHEEL then
        delta = -delta
    end
    if delta == 0 then return false end

    local step = wheelStep()
    if delta > 0 then
        updateCameraDistance(step)
    else
        updateCameraDistance(-step)
    end
    return true
end

-- Публичный API модуля.
function M.install(d)
    deps = d or {}
    if not isSpectating() then
        restoreDefaultCameraDistance()
    end
end

-- Публичный API модуля.
function M.reset()
    M.onSpectateEnd()
end

return M
