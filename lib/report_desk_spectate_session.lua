--[[ Модуль: сессия /sp, TD hooks, outbound queue. ]]
local M = {}

--[[
  Серверное меню ADV /sp = RPC ShowTextDraw + TextDrawSetString.
  Скрытие: return false в onShowTextDraw / onTextDrawSetString (не sampTextdrawDelete).
  TD пересоздаются каждый tick сервером.
]]

local function callHookPrev(fn, ...)
    if type(fn) ~= 'function' then return end
    local results = {pcall(fn, ...)}
    if not results[1] then
        print('[Report Desk] sp hook chain: ' .. tostring(results[2]))
        return
    end
    return unpack(results, 2)
end

local SP_MENU_MARKERS = {
    'exit', 'mute', 'slap', 'stats', 'stat', 'update',
    'weap', 'skick', 'info', 'freeze',
    '-exit-', 'exit-',
    '\xE2\xFB\xF5\xEE\xE4',
    '\xEC\xF3\xF2',
    '\xF1\xEB\xFD\xEF',
    '\xF1\xF2\xE0\xF2',
    '\xEE\xE1\xED\xEE\xE2',
    '\xE0\xEF\xE4\xE5\xE9\xF2',
}

-- Координаты TD: canvas 640x448; колонка /sp ~520+, vehicle HUD ~400-480
local SP_MENU_COLUMN_LEFT_X = 280       -- левая граница колонки меню, px
local SP_MENU_COLUMN_BLOCK_X = 520      -- типичный X серверного SP-меню
local SP_MENU_COLUMN_TOLERANCE = 18     -- допуск попадания TD в колонку, px
local VEHICLE_HUD_X_MIN = 400
local VEHICLE_HUD_X_MAX = 480
local OUTBOUND_INTERVAL = 0.55          -- мин. пауза между sp/st/ans, сек

local session = {
    active = false,
    spectating = false,
    targetId = -1,
    targetNick = '',
    outbound = {},
    menuWantsCursor = false,
    menuHovered = false,
    menuColumnX = nil,
    lastOutboundAt = 0,
    lastOutboundCmd = '',
    awaitingSpectate = false,
}

local vehicleHud = require 'report_desk_sp_vehicle_hud'

local deps = {}
local trimFn, stripTagsFn, sendChatFn, getSettingsFn
local cbOnBegin, cbOnEnd, cbResetMenuState, cbResetMenuSelection, cbEnsureSampevHooks, cbEnsureTdHooks

local playerHandler, hookPrevPlayer
local showTdHook, setStrHook, hookPrevShowTd, hookPrevSetStr
local lastBeginSessionId = nil
local lastBeginSessionAt = 0
local BEGIN_SESSION_DEDUPE_SEC = 0.6

local function trim(s)
    if trimFn then return trimFn(s) end
    return tostring(s or ''):match('^%s*(.-)%s*$') or ''
end

-- Strip Tags
local function stripTags(text)
    if stripTagsFn then return stripTagsFn(text) end
    return tostring(text or '')
end

-- Ui Enabled
local function uiEnabled()
    local s = getSettingsFn and getSettingsFn()
    return not s or s.spectate_sp_ui ~= false
end

-- Локальный флаг spectating из session.
local function playerSpectatingNow()
    if deps.isPlayerSpectating then
        local ok, v = pcall(deps.isPlayerSpectating)
        if ok and v then return true end
    end
    return false
end

-- Clear Menu Column State
local function clearMenuColumnState()
    session.menuColumnX = nil
end

-- Normalize Menu Text
local function normalizeMenuText(text)
    text = tostring(text or '')
    text = text:gsub('{[0-9A-Fa-f]+}', '')
    text = text:gsub('~[^~]*~', '')
    text = text:gsub('%s+', ' '):gsub('^%s+', ''):gsub('%s+$', '')
    return text:lower()
end

-- Td Pos X
local function tdPosX(data)
    if not data or not data.position then return nil end
    return tonumber(data.position.x or data.position[1])
end

-- Td Pos Y
local function tdPosY(data)
    if not data or not data.position then return nil end
    return tonumber(data.position.y or data.position[2])
end

-- Is Sp Menu Overlay Text
local function isSpMenuOverlayText(text)
    text = tostring(text or '')
    if text == '' then return false end
    return text:match('~%a~%d+__') ~= nil and text:find('__', 1, true) ~= nil
end

-- Is Sp Menu Numeric Text
local function isSpMenuNumericText(text)
    text = tostring(text or '')
    if text == '' or text:match('~') then return false end
    return text:match('%d+__%d+') ~= nil
end

-- Is Blank Button Text
local function isBlankButtonText(text)
    text = tostring(text or '')
    if text == '' or text == ' ' then return true end
    return text:match('^_+$') ~= nil
end

-- Is Vehicle Hud Text
local function isVehicleHudText(text)
    if vehicleHud.matchesServerHudText and vehicleHud.matchesServerHudText(text) then
        return true
    end
    local plain = normalizeMenuText(text)
    if plain == '' then return false end
    plain = plain:gsub('_', ' ')
    if plain:find('km/h', 1, true) or plain:find('km h', 1, true) then return true end
    if plain:find('fuel', 1, true) then return true end
    if plain:find('\xEA\xEC/\xF7', 1, true) then return true end
    if plain:find('\xF2\xEE\xEF\xEB\xE8\xE2\xEE', 1, true) then return true end
    return false
end

-- Is Vehicle Hud Column X
local function isVehicleHudColumnX(x)
    x = tonumber(x)
    if not x then return false end
    if x >= VEHICLE_HUD_X_MIN and x <= VEHICLE_HUD_X_MAX then return true end
    if x > 0 and x <= 1.0 and x >= 0.62 and x <= 0.75 then return true end
    return false
end

-- Is Vehicle Hud Bottom Area — только колонка спидометра, не вся нижняя полоса.
local function isVehicleHudBottomArea(x, y)
    if isVehicleHudColumnX(x) then return true end
    if vehicleHud.isVehicleHudArea and vehicleHud.isVehicleHudArea(x, y) then
        x = tonumber(x)
        y = tonumber(y)
        if x and y and x >= VEHICLE_HUD_X_MIN - 24 and x <= VEHICLE_HUD_X_MAX + 40 then
            return true
        end
    end
    return false
end

-- Is Sp Menu Column X
local function isSpMenuColumnX(x)
    x = tonumber(x)
    if not x then return false end
    if x >= SP_MENU_COLUMN_BLOCK_X then return true end
    if x >= SP_MENU_COLUMN_LEFT_X then return true end
    if x > 0 and x <= 1.0 and x >= 0.42 then return true end
    return false
end

-- Is Server Sp Menu Text
local function isServerSpMenuText(text)
    local plain = normalizeMenuText(text)
    if plain == '' then return false end
    local raw = tostring(text or '')
    if isSpMenuOverlayText(raw) or isSpMenuNumericText(raw) then return true end
    for _, m in ipairs(SP_MENU_MARKERS) do
        if plain:find(m:lower(), 1, true) then return true end
    end
    return plain:find('exit', 1, true) ~= nil
end

-- Is Likely Vehicle Gauge Text
local function isLikelyVehicleGaugeText(text)
    if isVehicleHudText(text) then return true end
    local raw = tostring(text or '')
    if isSpMenuOverlayText(raw) or isSpMenuNumericText(raw) then return false end
    if isServerSpMenuText(text) or isBlankButtonText(text) then return false end
    if raw:match('~[a-z]~%d') and not raw:find('__', 1, true) then return true end
    return false
end

-- Remember Menu Column
local function rememberMenuColumn(data)
    local x = tdPosX(data)
    if x and isSpMenuColumnX(x) and not isVehicleHudColumnX(x) then
        session.menuColumnX = x
    end
end

-- Публичный API модуля.
function M.shouldSuppressServerSpMenu()
    if not uiEnabled() then return false end
    -- Подтверждённая цель: кастомное меню вместо серверного TD.
    if M.getTargetId() >= 0 then return true end
    -- Handshake: pending есть, кастомное меню показывает pending id через stats getTargetId.
    if session.awaitingSpectate == true then return true end
    -- Без цели и без pending — серверное меню не трогаем (нет «пустого» экрана).
    return false
end

-- Публичный API модуля.
function M.isAwaitingSpectate()
    return session.awaitingSpectate == true
end

-- Публичный API модуля.
function M.markAwaitingSpectate(on)
    session.awaitingSpectate = on and true or false
end

-- Custom Vehicle Hud Enabled — ingest/block server TD спидометра.
local function vehicleHudPipelineActive()
    local settings = getSettingsFn and getSettingsFn()
    if not vehicleHud.isEnabled(settings) then return false end
    if vehicleHud.isLocalInVehicle and vehicleHud.isLocalInVehicle() then return true end
    if not vehicleHud.isEnabledForSpectate(settings) then return false end
    return M.shouldSuppressServerSpMenu()
end

-- Block Vehicle Td
local function blockVehicleTd(id, data, text)
    if not vehicleHudPipelineActive() then return false end
    pcall(vehicleHud.ingest, id, data, text)
    return vehicleHud.shouldBlockServerTd(id, data, text)
end

-- Handle Vehicle Text Draw — парсинг + скрытие server спидометра (отдельно от /sp меню).
local function handleVehicleTextDraw(id, data, text)
    if not vehicleHudPipelineActive() then return false end
    text = text or (data and data.text) or ''
    if data then
        local vx, vy = tdPosX(data), tdPosY(data)
        if isVehicleHudBottomArea(vx, vy) and not isServerSpMenuText(text)
                and isVehicleHudText(text) then
            pcall(vehicleHud.ingest, id, data, text)
            return true
        end
    end
    if isLikelyVehicleGaugeText(text) then
        return blockVehicleTd(id, data, text)
    end
    return false
end

-- Is Server Sp Menu Text Draw — скрытие server /sp UI (не vehicle HUD).
local function isServerSpMenuTextDrawOnly(id, data, text)
    text = text or (data and data.text) or ''
    if isServerSpMenuText(text) then
        rememberMenuColumn(data)
        return true
    end
    if not M.shouldSuppressServerSpMenu() then return false end
    if not data then return false end

    local x = tdPosX(data)
    local y = tdPosY(data)

    if isSpMenuOverlayText(text) or isSpMenuNumericText(text) then
        rememberMenuColumn(data)
        return true
    end

    if isBlankButtonText(text) and x and isSpMenuColumnX(x) then
        rememberMenuColumn(data)
        return true
    end

    if x and isSpMenuColumnX(x) then
        rememberMenuColumn(data)
    end

    if tonumber(data.selectable) == 1 then
        if isLikelyVehicleGaugeText(text) then return false end
        if session.menuColumnX and x and math.abs(x - session.menuColumnX) <= SP_MENU_COLUMN_TOLERANCE then
            return true
        end
        if x and x >= SP_MENU_COLUMN_BLOCK_X then return true end
        if y and y >= 60 and y <= 430 and x and isSpMenuColumnX(x) then
            return true
        end
    end

    if x and isSpMenuColumnX(x) and not isVehicleHudColumnX(x) then
        return true
    end

    return false
end

-- Публичный API модуля.
function M.isServerSpMenuTextDraw(id, data, text)
    if handleVehicleTextDraw(id, data, text) then return true end
    return isServerSpMenuTextDrawOnly(id, data, text)
end

-- Публичный API модуля.
function M.onShowTextDraw(id, data)
    if handleVehicleTextDraw(id, data) then return false end
    if not M.shouldSuppressServerSpMenu() then return end
    if isServerSpMenuTextDrawOnly(id, data, data and data.text) then return false end
end

-- Публичный API модуля.
function M.onTextDrawSetString(id, text)
    if vehicleHudPipelineActive() and vehicleHud.ingestString(id, text) then
        return false
    end
    if handleVehicleTextDraw(id, nil, text) then return false end
    if not M.shouldSuppressServerSpMenu() then return end
    if isServerSpMenuTextDrawOnly(id, nil, text) then return false end
end

-- Публичный API модуля.
function M.installTextDrawHooks(sampev)
    if not sampev then return end
    if showTdHook and sampev.onShowTextDraw == showTdHook
            and setStrHook and sampev.onTextDrawSetString == setStrHook then
        return
    end

    local prevShow = sampev.onShowTextDraw
    if prevShow == showTdHook then prevShow = hookPrevShowTd end
    hookPrevShowTd = prevShow

    showTdHook = function(id, data)
        local block = false
        local ok, err = pcall(function()
            block = M.onShowTextDraw(id, data) == false
        end)
        if not ok then
            print('[Report Desk] sp td show: ' .. tostring(err))
        elseif block then
            return false
        end
        return callHookPrev(hookPrevShowTd, id, data)
    end
    sampev.onShowTextDraw = showTdHook

    local prevSet = sampev.onTextDrawSetString
    if prevSet == setStrHook then prevSet = hookPrevSetStr end
    hookPrevSetStr = prevSet

    setStrHook = function(id, text)
        local block = false
        local ok, err = pcall(function()
            block = M.onTextDrawSetString(id, text) == false
        end)
        if not ok then
            print('[Report Desk] sp td set: ' .. tostring(err))
        elseif block then
            return false
        end
        return callHookPrev(hookPrevSetStr, id, text)
    end
    sampev.onTextDrawSetString = setStrHook
end

-- Публичный API модуля.
function M.ensureTextDrawHooks(sampev)
    M.installTextDrawHooks(sampev)
end

-- Публичный API модуля.
function M.isSpectatingMode()
    return playerSpectatingNow() or M.isActive()
end

-- Публичный API модуля.
function M.setSpectating(on)
    on = on and true or false
    session.spectating = on
    if on then
        if cbEnsureSampevHooks then pcall(cbEnsureSampevHooks) end
        if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
    else
        session.outbound = {}
        clearMenuColumnState()
        pcall(vehicleHud.reset)
        if cbResetMenuState then pcall(cbResetMenuState) end
    end
end

-- Публичный API модуля.
function M.isSpMenuVisible()
    if not uiEnabled() then return false end
    return M.getTargetId() >= 0
end

-- Публичный API модуля.
function M.shouldBlockServerSpMenu()
    return M.shouldSuppressServerSpMenu()
end

-- Публичный API модуля.
function M.getTargetId()
    return tonumber(session.targetId) or -1
end

-- Публичный API модуля.
function M.getTargetNick()
    return session.targetNick or ''
end

-- Публичный API модуля.
function M.isActive()
    return session.active == true and M.getTargetId() >= 0
end

-- Публичный API модуля.
function M.shouldShowCustomUi()
    return M.isSpMenuVisible()
end

-- Публичный API модуля.
function M.shouldBlockTdSelect()
    return M.shouldSuppressServerSpMenu()
end

-- Публичный API модуля.
function M.menuWantsCursor()
    return session.menuWantsCursor == true
end

-- Публичный API модуля.
function M.setMenuHovered(hovered)
    session.menuHovered = hovered and true or false
    session.menuWantsCursor = session.menuHovered
end

-- Публичный API модуля.
function M.parseSpLine(text)
    text = stripTags(text or '')
    if text == '' or not text:find('[SP]', 1, true) then return false end
    local nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%]%s*|%s*PING%s+(%d+)')
    if not id then
        nick, id, ping = text:match('%[SP%]%s*(.-)%[(%d+)%].-(%d+)%s*$')
    end
    if not id then
        nick, id = text:match('%[SP%]%s*(.-)%[(%d+)%]')
    end
    if not id then return false end
    id = tonumber(id)
    if not id or id < 0 then return false end
    if nick then nick = trim(nick) end
    M.setSpectating(true)
    if deps.setPlayerSpectating then pcall(deps.setPlayerSpectating, true) end
    -- RPC onSpectatePlayer уже подтвердил сессию — [SP] только дополняет nick.
    if M.isActive() and M.getTargetId() == id then
        if nick ~= '' then session.targetNick = nick end
        return true
    end
    return M.beginSession(id, nick, {
        source = 'sp_line',
        ping = ping and tonumber(ping) or nil,
        forceSync = true,
    })
end

-- Server-confirmed spectate target (authoritative).
local function isServerConfirmedSource(src)
    return src == 'sp_line' or src == 'spectate_player'
end

-- Публичный API модуля.
function M.beginSession(id, nick, opts)
    id = tonumber(id)
    if not id or id < 0 then return false end
    opts = opts or {}
    nick = trim(nick or '')
    local changed = session.targetId ~= id
    local forceSync = opts.forceSync == true or isServerConfirmedSource(opts.source)
    local now = os.clock()
    if not changed and id == lastBeginSessionId
            and (now - lastBeginSessionAt) < BEGIN_SESSION_DEDUPE_SEC then
        session.active = true
        session.spectating = true
        session.awaitingSpectate = false
        session.targetId = id
        if nick ~= '' then session.targetNick = nick end
        return true
    end
    lastBeginSessionId = id
    lastBeginSessionAt = now
    session.active = true
    session.spectating = true
    session.awaitingSpectate = false
    session.targetId = id
    session.targetNick = nick
    if changed then
        pcall(vehicleHud.reset)
        if cbResetMenuSelection then pcall(cbResetMenuSelection)
        elseif cbResetMenuState then pcall(cbResetMenuState) end
    end
    if cbEnsureSampevHooks then pcall(cbEnsureSampevHooks) end
    if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
    if changed or forceSync then
        if cbOnBegin then pcall(cbOnBegin, id, nick, opts) end
    end
    return true
end

-- Публичный API модуля.
function M.endSession()
    session.active = false
    session.spectating = false
    session.awaitingSpectate = false
    session.targetId = -1
    session.targetNick = ''
    session.menuWantsCursor = false
    session.menuHovered = false
    session.outbound = {}
    clearMenuColumnState()
    vehicleHud.reset()
    if cbResetMenuSelection then pcall(cbResetMenuSelection) end
    if cbOnEnd then pcall(cbOnEnd) end
end

-- Outbound Base
local function outboundBase(cmd)
    cmd = trim(cmd or '')
    if cmd == '' then return nil end
    return cmd:match('^(%S+)') or cmd
end

-- Coalesce Outbound Queue
local function coalesceOutboundQueue(cmd)
    local base = outboundBase(cmd)
    if not base then return end
    local keep = {}
    for _, queued in ipairs(session.outbound) do
        if outboundBase(queued) ~= base then
            keep[#keep + 1] = queued
        end
    end
    session.outbound = keep
end

-- Публичный API модуля.
function M.queueOutbound(cmd)
    cmd = trim(cmd or '')
    if cmd == '' then return end
    local n = #session.outbound
    if n > 0 and session.outbound[n] == cmd then return end
    coalesceOutboundQueue(cmd)
    session.outbound[#session.outbound + 1] = cmd
end

-- Публичный API модуля.
function M.hasOutboundPending()
    return #session.outbound > 0
end

-- Публичный API модуля.
function M.wasRecentOutboundCommand(cmd)
    cmd = trim(cmd or '')
    if cmd == '' then return false end
    return session.lastOutboundCmd == cmd
        and (os.clock() - (session.lastOutboundAt or 0)) < 0.65
end

-- Публичный API модуля.
function M.flushOutbound()
    if #session.outbound == 0 then return end
    if type(sampIsChatInputActive) == 'function' and sampIsChatInputActive() then return end
    if type(sampIsDialogActive) == 'function' and sampIsDialogActive() then return end
    if not sendChatFn then
        session.outbound = {}
        return
    end
    local now = os.clock()
    if now - session.lastOutboundAt < OUTBOUND_INTERVAL then return end
    local cmd = table.remove(session.outbound, 1)
    if not cmd or cmd == '' then return end
    session.lastOutboundAt = now
    session.lastOutboundCmd = cmd
    pcall(sendChatFn, cmd)
end

local vehicleHandler, hookPrevVehicle

-- Публичный API модуля.
function M.installSampevHooks(sampev)
    if not sampev then return end
    if playerHandler and sampev.onSpectatePlayer == playerHandler
            and vehicleHandler and sampev.onSpectateVehicle == vehicleHandler then
        return
    end

    local prev = sampev.onSpectatePlayer
    if prev == playerHandler then prev = hookPrevPlayer end
    hookPrevPlayer = prev
    playerHandler = function(id)
        local ok, err = pcall(function()
            id = tonumber(id)
            if id and id >= 0 then
                local nick = ''
                pcall(function()
                    if deps.sampIsPlayerConnected and deps.sampIsPlayerConnected(id)
                            and deps.sampGetPlayerNickname then
                        nick = deps.sampGetPlayerNickname(id) or ''
                    end
                end)
                M.setSpectating(true)
                if deps.setPlayerSpectating then pcall(deps.setPlayerSpectating, true) end
                M.beginSession(id, nick, { source = 'spectate_player', forceSync = true })
                pcall(function()
                    local stats = package.loaded['report_desk_spectate_stats']
                    if stats and stats.onSpRefreshSpectatePlayer then
                        stats.onSpRefreshSpectatePlayer(id)
                    end
                end)
            end
        end)
        if not ok then
            print('[Report Desk] spectate player: ' .. tostring(err))
        end
        return callHookPrev(hookPrevPlayer, id)
    end
    sampev.onSpectatePlayer = playerHandler

    local prevVeh = sampev.onSpectateVehicle
    if prevVeh == vehicleHandler then prevVeh = hookPrevVehicle end
    hookPrevVehicle = prevVeh
    vehicleHandler = function(vehicleId)
        pcall(function()
            local stats = package.loaded['report_desk_spectate_stats']
            if stats and stats.onSpRefreshSpectateVehicle then
                stats.onSpRefreshSpectateVehicle(vehicleId)
            end
        end)
        return callHookPrev(hookPrevVehicle, vehicleId)
    end
    sampev.onSpectateVehicle = vehicleHandler
end

-- Публичный API модуля.
function M.uninstallSampevHooks(sampev)
    if not sampev then return end
    if playerHandler and sampev.onSpectatePlayer == playerHandler then
        sampev.onSpectatePlayer = hookPrevPlayer
    end
    playerHandler = nil
    hookPrevPlayer = nil
end

-- Публичный API модуля.
function M.areSampevHooksActive(sampev)
    if not sampev then return false end
    return playerHandler and sampev.onSpectatePlayer == playerHandler
        and vehicleHandler and sampev.onSpectateVehicle == vehicleHandler
end

-- Публичный API модуля.
function M.areTextDrawHooksActive(sampev)
    if not sampev then return false end
    return showTdHook and sampev.onShowTextDraw == showTdHook
        and setStrHook and sampev.onTextDrawSetString == setStrHook
end

-- Публичный API модуля.
function M.debugStatus()
    local lines = {}
    lines[#lines + 1] = string.format(
        'ver 3.55 ui=%s suppress=%s spec=%s menu=%s active=%s id=%s colX=%s',
        tostring(uiEnabled()), tostring(M.shouldSuppressServerSpMenu()),
        tostring(playerSpectatingNow()), tostring(M.isSpMenuVisible()),
        tostring(M.isActive()), tostring(M.getTargetId()),
        tostring(session.menuColumnX))
    if getSettingsFn then
        pcall(function()
            local menu = package.loaded['report_desk_spectate_menu']
            if menu and menu.getDebugPos then
                lines[#lines + 1] = menu.getDebugPos(getSettingsFn())
            end
        end)
    end
    local ev = package.loaded['lib.samp.events']
    lines[#lines + 1] = string.format('tdHooks=%s showFn=%s',
        tostring(M.areTextDrawHooksActive(ev)),
        tostring(ev and ev.onShowTextDraw == showTdHook))
    return table.concat(lines, ' | ')
end

-- Scan Chat For Sp Recovery
local function scanChatForSpRecovery()
    if not playerSpectatingNow() then return false end
    if not sampGetChatString then return false end
    for i = 19, 0, -1 do
        local line = sampGetChatString(i) or ''
        if line ~= '' and line:find('[SP]', 1, true) then
            M.setSpectating(true)
            return M.parseSpLine(line)
        end
    end
    return false
end

-- Публичный API модуля.
function M.tryRecoverFromChat()
    return scanChatForSpRecovery()
end

-- Публичный API модуля.
function M.scheduleRecoveryScan()
    if not lua_thread or not lua_thread.create then return end
    lua_thread.create(function()
        wait(800)
        if not playerSpectatingNow() then return end
        M.setSpectating(true)
        if M.isActive() then return end
        pcall(scanChatForSpRecovery)
    end)
end

-- Публичный API модуля.
function M.configure(cfg)
    deps = cfg or deps or {}
    trimFn = deps.trim
    stripTagsFn = deps.stripTags
    sendChatFn = deps.sendChat
    getSettingsFn = deps.getSettings
    cbOnBegin = deps.onBegin
    cbOnEnd = deps.onEnd
    cbResetMenuState = deps.resetMenuState
    cbResetMenuSelection = deps.resetMenuSelection
    cbEnsureSampevHooks = deps.ensureSampevHooks
    cbEnsureTdHooks = deps.ensureTdHooks
end

-- Публичный API модуля.
function M.install(cfg)
    M.configure(cfg)
end

-- Sam Menu Item Plain
local function samMenuItemPlain(item)
    return normalizeMenuText(tostring(item or ''))
end

-- Sam Menu Columns Match Sp
local function samMenuColumnsMatchSp(columns)
    if type(columns) ~= 'table' then return false end
    for _, col in ipairs(columns) do
        if type(col) == 'table' then
            local colTitle = samMenuItemPlain(col.title)
            for _, m in ipairs(SP_MENU_MARKERS) do
                if colTitle:find(m:lower(), 1, true) then return true end
            end
            if type(col.text) == 'table' then
                for _, item in ipairs(col.text) do
                    local plain = samMenuItemPlain(item)
                    if plain ~= '' then
                        for _, m in ipairs(SP_MENU_MARKERS) do
                            if plain:find(m:lower(), 1, true) then return true end
                        end
                    end
                end
            end
        end
    end
    return false
end

-- Публичный API модуля.
-- SA-Menu spectate admin (Exit/Stats/…), не /gps и прочие игровые меню.
function M.isServerSpSamMenu(menuTitle, x, y, columns)
    if not M.shouldSuppressServerSpMenu() then return false end
    local title = normalizeMenuText(menuTitle or '')
    for _, m in ipairs(SP_MENU_MARKERS) do
        if title:find(m:lower(), 1, true) then return true end
    end
    if samMenuColumnsMatchSp(columns) then return true end
    return false
end

-- Публичный API модуля.
function M.captureServerMenuLayout(x, y, columns, title)
    local menu = package.loaded['report_desk_spectate_menu']
    if menu and menu.applyServerLayout then
        pcall(menu.applyServerLayout, {
            x = tonumber(x),
            y = tonumber(y),
            columns = columns,
            title = title,
        })
    end
end

-- Публичный API модуля.
function M.getSettingsSnapshot()
    if getSettingsFn then return getSettingsFn() end
    return nil
end

return M
