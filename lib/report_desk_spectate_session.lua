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
local menuBlock = require 'report_desk_sp_menu_td_block'
local tdRouter = require 'report_desk_sp_td_router'

function M.shouldSuppressServerSpMenu()
    return menuBlock.shouldSuppressServerSpMenu()
end

function M.isAwaitingSpectate()
    return menuBlock.isAwaitingSpectate()
end

function M.markAwaitingSpectate(on)
    menuBlock.markAwaitingSpectate(on)
end

function M.tdHooksNeeded()
    return tdRouter.tdHooksNeeded()
end

function M.shouldBlockSpMenuClick(textdrawId)
    return menuBlock.shouldBlockSpMenuClick(textdrawId)
end

function M.isServerSpMenuTextDraw(id, data, text)
    return menuBlock.isServerSpMenuTextDraw(id, data, text)
end

function M.onShowTextDraw(id, data)
    return tdRouter.onShowTextDraw(id, data)
end

function M.onTextDrawSetString(id, text)
    return tdRouter.onTextDrawSetString(id, text)
end

function M.isServerSpSamMenu(menuTitle, x, y, columns)
    return menuBlock.isServerSpSamMenu(menuTitle, x, y, columns)
end

function M.captureServerMenuLayout(x, y, columns, title)
    return menuBlock.captureServerMenuLayout(x, y, columns, title)
end

local function clearMenuColumnState()
    menuBlock.clearMenuColumnState()
end
local VEHICLE_HUD_X_MIN = 400
local VEHICLE_HUD_X_MAX = 480
local OUTBOUND_INTERVAL = 0.55          -- мин. пауза между sp/st/ans, сек
local OUTBOUND_QUEUE_MAX = 16           -- max queued commands while chat busy
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

-- Tags

local function stripTags(text)
    if stripTagsFn then return stripTagsFn(text) end
    return tostring(text or '')
end

-- Ui Enabled

local function uiEnabled()
    local s = getSettingsFn and getSettingsFn()
    return not s or s.spectate_sp_ui ~= false
end

-- Локальный флаг spectating (deskInputState). Без эвристик — иначе ложный /sp → TD hooks → лаг.

local function playerSpectatingNow()
    if deps.isPlayerSpectating then
        local ok, v = pcall(deps.isPlayerSpectating)
        if ok and v then return true end
    end
    return false
end
local recoveryScanDone = false

local function persistReloadSnapshot()
    local id = M.getTargetId()
    if id < 0 then return end
    rawset(_G, '__desk_sp_recover', {
        targetId = id,
        targetNick = M.getTargetNick(),
        ts = os.time(),
    })
end

local function recoverFromChatScan()
    if not sampGetChatString then return false end
    for i = 19, 0, -1 do
        local line = sampGetChatString(i) or ''
        if line ~= '' and line:find('[SP]', 1, true) then
            if M.parseSpLine(line) then return true end
        end
    end
    return false
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

-- Снять только TD-хуки (spectate player/vehicle hooks не трогаем).

function M.uninstallTextDrawHooks(sampev)
    if not sampev then return end
    if showTdHook and sampev.onShowTextDraw == showTdHook then
        sampev.onShowTextDraw = hookPrevShowTd
    end
    if setStrHook and sampev.onTextDrawSetString == setStrHook then
        sampev.onTextDrawSetString = hookPrevSetStr
    end
    showTdHook = nil
    setStrHook = nil
    hookPrevShowTd = nil
    hookPrevSetStr = nil
end

-- Поставить TD-хуки если нужны, снять если нет.

function M.syncTextDrawHooks(sampev)
    if not sampev then
        sampev = rawget(_G, 'sampev') or package.loaded['lib.samp.events']
    end
    if not sampev then return end
    if M.tdHooksNeeded() then
        M.installTextDrawHooks(sampev)
    elseif M.areTextDrawHooksActive(sampev) then
        M.uninstallTextDrawHooks(sampev)
    end
end
local lastTdLifecycleAt = -1
local lastLocalInVehicle = false
local lastSpectateTargetInVehicle = false
local TD_LIFECYCLE_INTERVAL = 0.35

-- В /sp — мгновенно чинит пропавшие хуки; вне /sp — редкий poll для посадки в машину.

function M.tickTdHooksLifecycle(sampev)
    if not sampev then
        sampev = rawget(_G, 'sampev') or package.loaded['lib.samp.events']
    end
    if not sampev then return end
    local localVeh = vehicleHud.isLocalInVehicle and vehicleHud.isLocalInVehicle() or false
    if localVeh ~= lastLocalInVehicle then
        lastLocalInVehicle = localVeh
        if vehicleHud.onLocalVehicleChanged then
            pcall(vehicleHud.onLocalVehicleChanged, localVeh)
        end
        if localVeh then
            M.installTextDrawHooks(sampev)
            lastTdLifecycleAt = os.clock()
            return
        end
    end
    if localVeh and not M.areTextDrawHooksActive(sampev) then
        M.installTextDrawHooks(sampev)
        return
    end
    local spPath = M.isSpectatingMode()
    if spPath and not localVeh then
        local spInVeh = false
        if vehicleHud.isSpectateTargetInVehicle then
            local ok, v = pcall(vehicleHud.isSpectateTargetInVehicle)
            spInVeh = ok and v == true
        end
        if lastSpectateTargetInVehicle and not spInVeh then
            if vehicleHud.syncSpectateVehiclePresence then
                pcall(vehicleHud.syncSpectateVehiclePresence)
            end
        end
        lastSpectateTargetInVehicle = spInVeh
    elseif not spPath then
        lastSpectateTargetInVehicle = false
    end
    if spPath then
        if M.areTextDrawHooksActive(sampev) then return end
        M.installTextDrawHooks(sampev)
        return
    end
    local now = os.clock()
    if now - lastTdLifecycleAt < TD_LIFECYCLE_INTERVAL then return end
    lastTdLifecycleAt = now
    local needed = M.tdHooksNeeded()
    local active = M.areTextDrawHooksActive(sampev)
    if needed == active then return end
    if needed then
        M.installTextDrawHooks(sampev)
    else
        M.uninstallTextDrawHooks(sampev)
    end
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
        if M.getTargetId() < 0 and session.awaitingSpectate ~= true then
            M.markAwaitingSpectate(true)
        end
        if cbEnsureSampevHooks then pcall(cbEnsureSampevHooks) end
        if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
    else
        session.outbound = {}
        clearMenuColumnState()
        pcall(vehicleHud.reset)
        if cbResetMenuState then pcall(cbResetMenuState) end
        if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
    end
end

-- Публичный API модуля.

function M.isSpMenuVisible()
    if not uiEnabled() then return false end
    return M.isActive() and M.getTargetId() >= 0
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
local SP_EXIT_CP1251 = '\xC2\xFB\xE5\xEE\xE4'

local function spChatLineIsExit(text)
    text = stripTags(text or '')
    if text == '' then return false end
    if text:find(SP_EXIT_CP1251, 1, true) then return true end
    local low = text:lower()
    if low:find('выход', 1, true) or low:find('exit', 1, true) then return true end
    return false
end

function M.parseSpLine(text)
    text = stripTags(text or '')
    if text == '' or not text:find('[SP]', 1, true) then return false end
    if spChatLineIsExit(text) then
        local _, exitId = text:match('%[SP%]%s*(.-)%[(%d+)%]')
        exitId = tonumber(exitId)
        if exitId and exitId >= 0 and session.active and session.targetId == exitId then
            M.endSession()
        end
        return false
    end
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
    nick = trim(nick or '')
    if nick == '' and deps.sampIsPlayerConnected and deps.sampIsPlayerConnected(id)
            and deps.sampGetPlayerNickname then
        nick = trim(deps.sampGetPlayerNickname(id) or '')
    end
    return M.beginSession(id, nick, {
        source = 'sp_line',
        ping = ping and tonumber(ping) or nil,
        forceSync = true,
    })
end

-- Server-confirmed spectate target (authoritative).

local function isServerConfirmedSource(src)
    return src == 'sp_line' or src == 'spectate_player' or src == 'reload_recover'
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
        if forceSync and cbOnBegin then pcall(cbOnBegin, id, nick, opts) end
        persistReloadSnapshot()
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
        clearMenuColumnState()
        pcall(vehicleHud.reset)
        if cbResetMenuSelection then pcall(cbResetMenuSelection)
        elseif cbResetMenuState then pcall(cbResetMenuState) end
    end
    if cbEnsureSampevHooks then pcall(cbEnsureSampevHooks) end
    if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
    if changed or forceSync then
        if cbOnBegin then pcall(cbOnBegin, id, nick, opts) end
    end
    persistReloadSnapshot()
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
    pcall(vehicleHud.reset)
    if cbResetMenuSelection then pcall(cbResetMenuSelection) end
    if cbOnEnd then pcall(cbOnEnd) end
    if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
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
    while #session.outbound > OUTBOUND_QUEUE_MAX do
        table.remove(session.outbound, 1)
    end
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
        print('[Report Desk] sp outbound: sendChatFn not configured, keeping queue')
        return
    end
    local now = os.clock()
    if now - session.lastOutboundAt < OUTBOUND_INTERVAL then return end
    local cmd = table.remove(session.outbound, 1)
    if not cmd or cmd == '' then return end
    session.lastOutboundAt = now
    session.lastOutboundCmd = cmd
    local cache = rawget(_G, 'deskCache')
    local spId = cmd:match('^sp%s+(%d+)%s*$')
    if spId and type(cache) == 'table' then
        cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
    end
    pcall(sendChatFn, cmd)
    if spId and type(cache) == 'table' then
        local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
        cache.skipSpHookLocal = n > 0 and n or nil
    end
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
                M.beginSession(id, nick, { source = 'spectate_player' })
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
    M.uninstallTextDrawHooks(sampev)
    if vehicleHandler and sampev.onSpectateVehicle == vehicleHandler then
        sampev.onSpectateVehicle = hookPrevVehicle
    end
    vehicleHandler = nil
    hookPrevVehicle = nil
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

-- Запасной путь без API: chat recovery только при подтверждённом spectate-флаге.

local function scanChatForSpRecovery()
    if not playerSpectatingNow() then return false end
    return recoverFromChatScan()
end

-- Публичный API модуля.

function M.tryRecoverFromChat()
    return scanChatForSpRecovery()
end

-- Восстановление /sp после /reload. Не вызывает setSpectating до успешного beginSession.

function M.tryRecoverAfterReload()
    if M.isActive() then
        persistReloadSnapshot()
        if deps.setPlayerSpectating then pcall(deps.setPlayerSpectating, true) end
        return true
    end
    if not playerSpectatingNow() then
        rawset(_G, '__desk_sp_recover', nil)
        return false
    end
    local rec = rawget(_G, '__desk_sp_recover')
    if rec and rec.targetId and rec.targetId >= 0 then
        local age = os.time() - (tonumber(rec.ts) or 0)
        if age <= 600 then
            local id = tonumber(rec.targetId)
            local nick = tostring(rec.targetNick or '')
            if id and id >= 0
                    and (not deps.sampIsPlayerConnected or deps.sampIsPlayerConnected(id)) then
                if M.beginSession(id, nick, { source = 'reload_recover' }) and M.isActive() then
                    if deps.setPlayerSpectating then pcall(deps.setPlayerSpectating, true) end
                    return true
                end
            end
        end
    end
    rawset(_G, '__desk_sp_recover', nil)
    return false
end

-- Публичный API модуля.

function M.scheduleRecoveryScan()
    if recoveryScanDone then return end
    recoveryScanDone = true
    if not lua_thread or not lua_thread.create then
        pcall(M.tryRecoverAfterReload)
        return
    end
    lua_thread.create(function()
        wait(800)
        pcall(M.tryRecoverAfterReload)
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
menuBlock.configure({
        session = session,
        trim = trimFn,
        getSettings = getSettingsFn,
        ensureTdHooks = function()
            if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end
        end,
    })
    tdRouter.configure({ menuBlock = menuBlock, getSettings = getSettingsFn })
end

-- Публичный API модуля.

function M.install(cfg)
    M.configure(cfg)
end

-- Публичный API модуля.

function M.getSettingsSnapshot()
    if getSettingsFn then return getSettingsFn() end
    return nil
end
return M
