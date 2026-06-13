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

    'exit', 'mute', 'slap', 'stats', 'stat', 'update', 'tow', 'tr', 'skip',

    'weap', 'skick', 'info', 'freeze', 'dgun', 'kick', 'ban', 'jail', 'warn',

    '-exit-', 'exit-',

    '\xE2\xFB\xF5\xEE\xE4', -- выход

    '\xEC\xF3\xF2',         -- mut

    '\xF1\xEB\xFD\xEF',     -- slap

    '\xF1\xF2\xE0\xF2',     -- stat

    '\xEE\xE1\xED\xEE\xE2', -- update

    '\xE0\xEF\xE4\xE5\xE9\xF2', -- update

    '\xED\xE0\xF1\xF2\xF0', -- настр (настройки)

    '\xEC\xE8\xF0',         -- мир

    '\xE7\xE0\xEC\xEE\xF0', -- замор (заморозить)

    '\xEE\xF0\xF3\xE6',     -- оруж

    '\xE2\xEE\xE4',         -- вод (из воды)

    '\xF1\xED\xFF\xF2',     -- снят

    '\xF1\xEB\xFD\xEF\xED', -- slapped

    '\xE4\xEE\xF1\xF2\xE0', -- доста

}



-- Координаты TD: canvas 640x448; колонка /sp ~520+, vehicle HUD ~400-480

local SP_MENU_COLUMN_LEFT_X = 280       -- левая граница колонки меню, px

local SP_MENU_COLUMN_BLOCK_X = 520      -- типичный X серверного SP-меню

local SP_MENU_COLUMN_TOLERANCE = 18     -- допуск попадания TD в колонку, px

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



local blockedSpMenuTdIds = {}



-- Clear Menu Column State

local function clearMenuColumnState()

    session.menuColumnX = nil

    blockedSpMenuTdIds = {}

end



-- Cached shouldSuppressServerSpMenu for TD hot path (vehicle HUD — отдельно, без кеша).

local function suppressSpMenuActive()

    if not uiEnabled() then return false end

    return M.shouldSuppressServerSpMenu()

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



-- Is Vehicle Hud Bottom Area — зона server TD спидометра.

local function isVehicleHudBottomArea(x, y)

    if isVehicleHudColumnX(x) then return true end

    return vehicleHud.isVehicleHudArea and vehicleHud.isVehicleHudArea(x, y) or false

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



-- Is Likely Vehicle Gauge Text — только TD в колонке server спидометра.

local function isLikelyVehicleGaugeText(text, x, y)

    if not x or not y or not isVehicleHudBottomArea(x, y) then return false end

    local raw = tostring(text or '')

    if isSpMenuOverlayText(raw) or isSpMenuNumericText(raw) then return false end

    if isServerSpMenuText(text) or isBlankButtonText(text) then return false end

    if isVehicleHudText(text) then return true end

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

    if M.getTargetId() >= 0 then return true end

    if session.awaitingSpectate == true then return true end

    return false

end



-- Публичный API модуля.

function M.isAwaitingSpectate()

    return session.awaitingSpectate == true

end



-- Публичный API модуля.

function M.markAwaitingSpectate(on)

    session.awaitingSpectate = on and true or false

    if cbEnsureTdHooks then pcall(cbEnsureTdHooks) end

end



-- Custom Vehicle Hud Enabled — ingest/block server TD спидометра.

local function vehicleHudPipelineActive()

    local settings = getSettingsFn and getSettingsFn()

    if not vehicleHud.isEnabled(settings) then return false end

    if vehicleHud.isLocalInVehicle and vehicleHud.isLocalInVehicle() then return true end

    if not vehicleHud.isEnabledForSpectate(settings) then return false end

    return M.shouldSuppressServerSpMenu()

end



-- Нужны ли TD-хуки: скрытие server /sp меню или кастомный спидометр в машине.

function M.tdHooksNeeded()

    if M.shouldSuppressServerSpMenu() then return true end

    return vehicleHudPipelineActive()

end



-- Handle Vehicle Text Draw — ingest + скрытие server спидометра.

local function handleVehicleTextDraw(id, data, text)

    if not vehicleHudPipelineActive() then return false end

    text = text or (data and data.text) or ''

    if isServerSpMenuText(text) then return false end

    if vehicleHud.isSportModeOverlayText and vehicleHud.isSportModeOverlayText(text, id) then

        if data then pcall(vehicleHud.ingest, id, data, text)

        else pcall(vehicleHud.ingestString, id, text) end

        return false

    end

    if data then

        pcall(vehicleHud.ingest, id, data, text)

    elseif text ~= '' then

        pcall(vehicleHud.ingestString, id, text)

    end

    return vehicleHud.shouldBlockServerTd(id, data, text)

end



-- Is Sp Menu Row Y — px (640x448) или normalized 0..1.

local function isSpMenuRowY(y)

    y = tonumber(y)

    if not y then return true end

    if y > 0 and y <= 1.0 then

        return y >= 0.10 and y <= 0.98

    end

    return y >= 50 and y <= 440

end



-- Is Server Sp Menu Text Draw — скрытие server /sp UI (не vehicle HUD).

local function isServerSpMenuTextDrawOnly(id, data, text)

    text = text or (data and data.text) or ''

    id = tonumber(id)

    if id and blockedSpMenuTdIds[id] then return true end

    if isServerSpMenuText(text) then

        rememberMenuColumn(data)

        if id then blockedSpMenuTdIds[id] = true end

        return true

    end

    if not M.shouldSuppressServerSpMenu() then return false end

    if not data then return false end



    local x = tdPosX(data)

    local y = tdPosY(data)



    if isSpMenuOverlayText(text) or isSpMenuNumericText(text) then

        rememberMenuColumn(data)

        if id then blockedSpMenuTdIds[id] = true end

        return true

    end



    if isBlankButtonText(text) and x and isSpMenuColumnX(x)

            and not isLikelyVehicleGaugeText(text, x, y) then

        rememberMenuColumn(data)

        if id then blockedSpMenuTdIds[id] = true end

        return true

    end



    if x and isSpMenuColumnX(x) and not isVehicleHudColumnX(x) then

        rememberMenuColumn(data)

    end



    if tonumber(data.selectable) == 1 and x and isSpMenuColumnX(x) then

        if isLikelyVehicleGaugeText(text, x, y) then return false end

        if isSpMenuRowY(y) then

            if id then blockedSpMenuTdIds[id] = true end

            return true

        end

    end



    return false

end



-- Публичный API модуля.

function M.shouldBlockSpMenuClick(textdrawId)

    textdrawId = tonumber(textdrawId)

    return textdrawId ~= nil and blockedSpMenuTdIds[textdrawId] == true

end



-- Публичный API модуля.

function M.isServerSpMenuTextDraw(id, data, text)

    return isServerSpMenuTextDrawOnly(id, data, text)

end



-- Публичный API модуля.

function M.onShowTextDraw(id, data)

    if not data then return end

    if not vehicleHudPipelineActive() and not suppressSpMenuActive() then return end

    if handleVehicleTextDraw(id, data) then return false end

    if not suppressSpMenuActive() then return end

    if isServerSpMenuTextDrawOnly(id, data, data.text) then return false end

end



-- Публичный API модуля.

function M.onTextDrawSetString(id, text)

    id = tonumber(id)

    if not id then return end

    if not vehicleHudPipelineActive() and not suppressSpMenuActive() then return end

    if blockedSpMenuTdIds[id] then return false end

    if handleVehicleTextDraw(id, nil, text) then return false end

    if not suppressSpMenuActive() then return end

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



-- NO-API: chat recovery только при подтверждённом spectate-флаге.

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

