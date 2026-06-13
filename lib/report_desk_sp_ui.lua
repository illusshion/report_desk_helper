--[[ Модуль: glue session + menu для /sp UI. ]]
-- REWRITTEN: idempotent WM/input hook install (no reinstall every health-check).
local M = {}

local session = require 'report_desk_spectate_session'
local menu = require 'report_desk_spectate_menu'

local deps = {} -- install cfg from spectate_stats
local menuDepsWired = false
local clickHandler, toggleHandler
local hookPrevClick, hookPrevToggle
local wmHandlerInstalled = false
local wmDispatchCached

local function resolveDeskWmDispatch()
    if type(deskWmDispatch) == 'table' and type(deskWmDispatch.register) == 'function' then
        return deskWmDispatch
    end
    if wmDispatchCached == nil then
        local ok, wm = pcall(require, 'report_desk_wm_dispatch')
        wmDispatchCached = ok and wm or false
    end
    if wmDispatchCached ~= false then return wmDispatchCached end
    return nil
end

local WM = {
    KEYDOWN = 0x0100,
    KEYUP = 0x0101,
    SYSKEYDOWN = 0x0104,
    SYSKEYUP = 0x0105,
}

-- Get Settings
local function getSettings()
    if deps.getSettings then return deps.getSettings() end
    return nil
end

-- Spectating Now
local function spectatingNow()
    if deps.getPlayerSpectating then
        local ok, v = pcall(deps.getPlayerSpectating)
        if ok and v then return true end
    end
    return false
end

-- Публичный API модуля.
function M.uiEnabled()
    local s = getSettings()
    return not s or s.spectate_sp_ui ~= false
end

-- Публичный API модуля.
function M.shouldSuppressServerMenu()
    return session.shouldSuppressServerSpMenu and session.shouldSuppressServerSpMenu()
end

-- Публичный API модуля.
function M.shouldShowMenu()
    return menu.shouldShowMenu(getSettings())
end

-- Публичный API модуля.
function M.getTargetId()
    if deps.getTargetId then
        local ok, v = pcall(deps.getTargetId)
        if ok then
            local id = tonumber(v)
            if id and id >= 0 then return id end
        end
    end
    return session.getTargetId and session.getTargetId() or -1
end

-- Публичный API модуля.
function M.drawMenu(settings)
    if not M.shouldShowMenu() then return end
    local ok, err = pcall(menu.drawMenu, settings or getSettings())
    if not ok then
        print('[Report Desk] sp menu draw: ' .. tostring(err))
    elseif menu.flushPendingAction then
        pcall(menu.flushPendingAction)
    end
end

-- Sync Td Hooks — install only when /sp or vehicle HUD needs them.
local function syncTdHooks()
    if deps.sampev then
        pcall(session.syncTextDrawHooks, deps.sampev)
    end
end

-- Ensure Td Hooks (legacy name: sync, never blind install).
local function ensureTdHooks()
    syncTdHooks()
end

-- Ensure Spectate Player Sampev Hook
local function ensureSpectateSampevHook()
    if deps.sampev then
        pcall(session.installSampevHooks, deps.sampev)
    end
end

-- Публичный API модуля.
function M.ensureSpectateSampevHooks()
    ensureSpectateSampevHook()
end

-- Reinstall Sampev Input Hooks
local function reinstallSampevInputHooks()
    local sampev = deps.sampev
    if not sampev then return end
    if clickHandler and sampev.onSendClickTextDraw == clickHandler
            and toggleHandler and sampev.onToggleSelectTextDraw == toggleHandler then
        return
    end

    local prev = sampev.onSendClickTextDraw
    if prev == clickHandler then prev = hookPrevClick end
    hookPrevClick = prev
    clickHandler = function(textdrawId)
        if deps.isMenuShieldActive and deps.isMenuShieldActive() then return false end
        if M.shouldSuppressServerMenu() and session.shouldBlockSpMenuClick then
            local ok, block = pcall(session.shouldBlockSpMenuClick, textdrawId)
            if ok and block then return false end
        end
        if type(hookPrevClick) == 'function' then return hookPrevClick(textdrawId) end
    end
    sampev.onSendClickTextDraw = clickHandler

    prev = sampev.onToggleSelectTextDraw
    if prev == toggleHandler then prev = hookPrevToggle end
    hookPrevToggle = prev
    toggleHandler = function(state, hovercolor)
        -- SelectTextDraw не блокируем — серверу нужен для /sp; TD скрыты, клики режем отдельно.
        if type(hookPrevToggle) == 'function' then return hookPrevToggle(state, hovercolor) end
    end
    sampev.onToggleSelectTextDraw = toggleHandler
end

-- Wire Menu Deps
local function wireMenuDeps()
    if menuDepsWired then return end
    menuDepsWired = true
    menu.install({
        uiText = deps.uiText,
        getSettings = getSettings,
        getTargetId = deps.getTargetId or M.getTargetId,
        getConfirmedTargetId = deps.getConfirmedTargetId,
        isUiActive = deps.isUiActive,
        getOutboundId = deps.getOutboundId,
        isHandshaking = deps.isHandshaking,
        hasPendingSp = deps.hasPendingSp,
        isRefreshInFlight = deps.isRefreshInFlight,
        getTargetNick = deps.getTargetNick,
        getPlayerSpectating = deps.getPlayerSpectating,
        isSpectating = spectatingNow,
        isGameTextInputActive = deps.isGameTextInputActive,
        isDeskTypingActive = deps.isDeskTypingActive,
        getShowWindow = deps.getShowWindow,
        vkeys = deps.vkeys,
        isVkDown = deps.isVkDown,
        col_accent = deps.col_accent,
        col_accent_dim = deps.col_accent_dim,
        col_label = deps.col_label,
        col_muted2 = deps.col_muted2,
        imgui = deps.imgui,
        requestStats = function(id, opts)
            if deps.requestStats then
                return deps.requestStats(id, opts or { force = true, showDialog = true })
            end
        end,
        markPendingSt = deps.markPendingSt,
        isStatsPending = deps.isStatsPending,
        sendTrPlayer = deps.sendTrPlayer,
        sendSlapPlayer = deps.sendSlapPlayer,
        markDirtySettings = deps.markDirtySettings,
        flushDirtyConfigNow = deps.flushDirtyConfigNow,
        queueOutbound = function(cmd)
            if type(cmd) == 'string' and cmd ~= '' then
                session.queueOutbound(cmd)
            end
        end,
        sendChat = deps.sendChat,
        sendMenuOutbound = deps.sendMenuOutbound,
        onSpLocalExit = deps.onSpLocalExit,
        setMenuHovered = function(h)
            pcall(session.setMenuHovered, h)
        end,
        playFrontEndSound = deps.playFrontEndSound,
    })
end

-- Публичный API модуля.
function M.install(cfg)
    deps = cfg or deps or {}
    menuDepsWired = false
    wireMenuDeps()
    session.install({
        trim = deps.trim,
        stripTags = deps.stripTags,
        sendChat = deps.sendChat,
        getSettings = getSettings,
        isPlayerSpectating = deps.getPlayerSpectating,
        sampIsPlayerConnected = deps.sampIsPlayerConnected,
        sampGetPlayerNickname = deps.sampGetPlayerNickname,
        setPlayerSpectating = deps.setPlayerSpectating,
        resetMenuState = function()
            pcall(menu.resetMenuState)
        end,
        resetMenuSelection = function()
            pcall(menu.resetMenuSelection)
        end,
        ensureSampevHooks = function()
            if deps.sampev then
                pcall(session.installSampevHooks, deps.sampev)
                reinstallSampevInputHooks()
            end
            syncTdHooks()
        end,
        ensureTdHooks = ensureTdHooks,
        onBegin = deps.onSessionBegin,
        onEnd = deps.onSessionEnd,
    })
    if session.scheduleRecoveryScan then
        pcall(session.scheduleRecoveryScan)
    end
end

-- Публичный API модуля.
function M.setPendingTarget(id, nick)
    session.markAwaitingSpectate(true)
    if deps.setPendingTarget then
        pcall(deps.setPendingTarget, id, nick)
    end
end

-- Finish Spectate Locally
local function finishSpectateLocally(reason, opts)
    reason = reason or 'sp_ui'
    opts = opts or { sendServer = false }
    session.markAwaitingSpectate(false)
    if deps.setPlayerSpectating then pcall(deps.setPlayerSpectating, false) end
    session.setSpectating(false)
    session.endSession()
    if deps.onSpectatingOff then pcall(deps.onSpectatingOff) end
end

-- Публичный API модуля.
function M.onToggleSpectating(toggle)
    if toggle then
        if not (session.isActive and session.isActive()) then
            pcall(menu.resetMenuState)
        end
        if deps.setPlayerSpectating then pcall(deps.setPlayerSpectating, true) end
        session.setSpectating(true)
        -- Цель и session.beginSession — только после RPC onSpectatePlayer.
        if deps.onSpectatingOn then pcall(deps.onSpectatingOn) end
        return
    end
    finishSpectateLocally('rpc_exit', { sendServer = false })
end

-- Публичный API модуля.
function M.onSpCommandOff()
    finishSpectateLocally('exit', { sendServer = false })
end

-- Публичный API модуля.
function M.parseSpLine(text)
    return session.parseSpLine(text)
end

-- Публичный API модуля.
function M.flushOutbound()
    session.flushOutbound()
end

-- Публичный API модуля.
function M.hasOutboundPending()
    return session.hasOutboundPending and session.hasOutboundPending() or false
end

-- Публичный API модуля.
function M.handleMenuKey(vk)
    if not menu.menuCapturesKeyboard() then return false end
    return menu.handleMenuKey(vk)
end

-- Uninstall Wm Handler
local function uninstallWmHandler()
    if not wmHandlerInstalled then return end
    local wm = resolveDeskWmDispatch()
    if wm and wm.unregister then
        wm.unregister('sp_ui')
    end
    wmHandlerInstalled = false
end

-- Install Wm Handler (menu keys; spectate_stats WM at priority 95 handles step/HUD keys)
local function installWmHandler()
    if wmHandlerInstalled then return end
    local wm = resolveDeskWmDispatch()
    if not wm or not wm.register then return end
    wmHandlerInstalled = true
    wm.register('sp_ui', 85, function(msg, wparam, lparam)
        if deps.captureActive and deps.captureActive() then return end
        if msg == WM.KEYDOWN or msg == WM.SYSKEYDOWN then
            if M.handleMenuKey(wparam) then
                consumeWindowMessage(true, true, true)
                return true
            end
        end
        if msg == WM.KEYUP or msg == WM.SYSKEYUP then
            local vkeys = deps.vkeys
            if vkeys and menu.menuCapturesKeyboard() then
                if wparam == vkeys.VK_UP or wparam == vkeys.VK_DOWN
                        or wparam == vkeys.VK_W or wparam == vkeys.VK_S
                        or wparam == vkeys.VK_NUMPAD8 or wparam == vkeys.VK_NUMPAD2 then
                    consumeWindowMessage(true, true, true)
                    return true
                end
            end
        end
        if deps.consumeMenuShieldKey and deps.consumeMenuShieldKey(msg, wparam) then
            consumeWindowMessage(true, true, true)
            return true
        end
    end)
end

-- Публичный API модуля.
function M.installInputHooks(cfg)
    if cfg then
        deps = cfg
        menuDepsWired = false
    end
    wireMenuDeps()
    syncTdHooks()
    ensureSpectateSampevHook()
    reinstallSampevInputHooks()
    installWmHandler()
end

-- Публичный API модуля.
function M.ensureInputHooks()
    if not deps.sampev then return end
    if not M.uiEnabled() and not spectatingNow() then return end
    syncTdHooks()
    ensureSpectateSampevHook()
    reinstallSampevInputHooks()
    installWmHandler()
end

-- Публичный API модуля.
function M.syncTdHooks()
    syncTdHooks()
end

-- Публичный API модуля.
function M.uninstallSampevHooks()
    uninstallWmHandler()
    local sampev = deps.sampev
    if not sampev then return end
    if clickHandler and sampev.onSendClickTextDraw == clickHandler then
        sampev.onSendClickTextDraw = hookPrevClick
    end
    if toggleHandler and sampev.onToggleSelectTextDraw == toggleHandler then
        sampev.onToggleSelectTextDraw = hookPrevToggle
    end
    clickHandler = nil
    toggleHandler = nil
    hookPrevClick = nil
    hookPrevToggle = nil
    pcall(session.uninstallSampevHooks, sampev)
end

return M
