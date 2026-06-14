--[[ SP menu hooks + RPC block (split from report_desk_hooks.lua). ]]
local spSessionMod
local function spSession()
    if not spSessionMod then
        spSessionMod = require 'report_desk_spectate_session'
    end
    return spSessionMod
end

local function spUiEnabled()
    local s = spSession()
    if s and s.getSettingsSnapshot then
        local cfg = s.getSettingsSnapshot()
        if cfg and cfg.spectate_sp_ui == false then return false end
    end
    return true
end

function shouldBlockServerSamMenu()
    if not spUiEnabled() then return false end
    if type(deskSpectatingNow) == 'function' and deskSpectatingNow() then return true end
    local s = spSession()
    if s and s.shouldSuppressServerSpMenu then
        local ok, v = pcall(s.shouldSuppressServerSpMenu)
        if ok and v then return true end
    end
    return false
end

local function captureServerMenuLayout(x, y, columns, title)
    local s = spSession()
    if s and s.captureServerMenuLayout then
        pcall(s.captureServerMenuLayout, x, y, columns, title)
    end
end

function deskAreSpMenuHooksActive()
    if not sampev then return false end
    return deskCache.spMenuShowHandler ~= nil
        and sampev.onShowMenu == deskCache.spMenuShowHandler
        and deskCache.spMenuInitHandler ~= nil
        and sampev.onInitMenu == deskCache.spMenuInitHandler
        and deskCache.spMenuHideHandler ~= nil
        and sampev.onHideMenu == deskCache.spMenuHideHandler
end

-- Блок SA-Menu (onInitMenu/onShowMenu/onHideMenu) в /sp.
function installDeskSpMenuHooks()
    if not sampev then return end
    if deskAreSpMenuHooksActive() then return end

    local prevInit = sampev.onInitMenu
    if prevInit == deskCache.spMenuInitHandler then prevInit = deskCache.hookPrevSpMenuInit end
    deskCache.hookPrevSpMenuInit = prevInit

    local prevShow = sampev.onShowMenu
    if prevShow == deskCache.spMenuShowHandler then prevShow = deskCache.hookPrevSpMenuShow end
    deskCache.hookPrevSpMenuShow = prevShow

    local prevHide = sampev.onHideMenu
    if prevHide == deskCache.spMenuHideHandler then prevHide = deskCache.hookPrevSpMenuHide end
    deskCache.hookPrevSpMenuHide = prevHide

    deskCache.spMenuInitHandler = function(menuId, menuTitle, x, y, twoColumns, columns, rows, menu)
        if shouldBlockServerSamMenu() then
            captureServerMenuLayout(x, y, columns, menuTitle)
            return false
        end
        return deskCallHookPrev(deskCache.hookPrevSpMenuInit, menuId, menuTitle, x, y, twoColumns, columns, rows, menu)
    end
    sampev.onInitMenu = deskCache.spMenuInitHandler

    deskCache.spMenuShowHandler = function(menuId)
        if shouldBlockServerSamMenu() then
            return false
        end
        return deskCallHookPrev(deskCache.hookPrevSpMenuShow, menuId)
    end
    sampev.onShowMenu = deskCache.spMenuShowHandler

    deskCache.spMenuHideHandler = function(menuId)
        if shouldBlockServerSamMenu() then
            return false
        end
        return deskCallHookPrev(deskCache.hookPrevSpMenuHide, menuId)
    end
    sampev.onHideMenu = deskCache.spMenuHideHandler
end

function deskReinstallSpMenuHooks()
    installDeskSpMenuHooks()
end

function deskSpectatePathNeedsInputHooks()
    if type(deskIsSpectating) == 'function' and deskIsSpectating() then return true end
    if type(deskSpectateStats) ~= 'table' then return false end
    if type(deskSpectateStats.hasPendingSp) == 'function' and deskSpectateStats.hasPendingSp() then
        return true
    end
    local cache = deskCache
    if cache and tonumber(cache.spWatchTargetId) and tonumber(cache.spWatchTargetId) >= 0 then
        return true
    end
    return false
end

function deskRegisterHookEntries()
    if not HookRegistry or HookRegistry._registered then return end
    local entries = {
        { id = 'serverMsg', event = 'onServerMessage',
          checker = function() return deskCache.serverMsgHandler and sampev.onServerMessage == deskCache.serverMsgHandler end,
          installer = installDeskServerMessageHook },
        { id = 'specDialog', event = 'onShowDialog',
          checker = function() return deskCache.specDialogHandler and sampev.onShowDialog == deskCache.specDialogHandler end,
          installer = installDeskSpectateDialogHook },
        { id = 'specToggle', event = 'onTogglePlayerSpectating',
          checker = function() return deskCache.specToggleHandler and sampev.onTogglePlayerSpectating == deskCache.specToggleHandler end,
          installer = installDeskSpectateToggleHook },
        { id = 'sendChat', event = 'onSendChat',
          checker = function() return deskCache.sendChatHandler and sampev.onSendChat == deskCache.sendChatHandler end,
          installer = installDeskSendChatHook },
        { id = 'sendCommand', event = 'onSendCommand',
          checker = function() return deskCache.sendCommandHandler and sampev.onSendCommand == deskCache.sendCommandHandler end,
          installer = installDeskSendCommandHook },
        { id = 'playerQuit', event = 'onPlayerQuit',
          checker = function() return deskCache.playerQuitHandler and sampev.onPlayerQuit == deskCache.playerQuitHandler end,
          installer = installDeskPlayerQuitHook },
        { id = 'playerJoin', event = 'onPlayerJoin',
          checker = function() return deskCache.playerJoinHandler and sampev.onPlayerJoin == deskCache.playerJoinHandler end,
          installer = installDeskPlayerJoinHook },
        { id = 'playerStreamIn', event = 'onPlayerStreamIn',
          checker = function() return deskCache.playerStreamInHandler and sampev.onPlayerStreamIn == deskCache.playerStreamInHandler end,
          installer = installDeskPlayerStreamInHook },
        { id = 'playerColor', event = 'onSetPlayerColor',
          checker = function() return deskCache.playerColorHandler and sampev.onSetPlayerColor == deskCache.playerColorHandler end,
          installer = installDeskPlayerColorHook },
        { id = 'godmode', event = 'onSetPlayerHealth',
          checker = deskGodmodeHooksActive,
          installer = installDeskGodmodeHealthHook },
        { id = 'spRefresh', event = 'onPlayerSync',
          checker = function()
              return deskCache.spPlayerSyncHandler and sampev.onPlayerSync == deskCache.spPlayerSyncHandler
          end,
          installer = installDeskSpRefreshHooks },
        { id = 'profanity', event = 'onChatMessage',
          checker = function()
              return deskCache.profHooksInstalled
                  and (not deskCache.profChatHandler or sampev.onChatMessage == deskCache.profChatHandler)
                  and (not deskCache.profBubbleHandler or sampev.onPlayerChatBubble == deskCache.profBubbleHandler)
          end,
          installer = function()
              deskCache.profHooksInstalled = false
              installProfanityHooks()
          end },
        { id = 'spMenu', event = 'onShowMenu',
          checker = deskAreSpMenuHooksActive,
          installer = installDeskSpMenuHooks },
    }
    for _, e in ipairs(entries) do
        HookRegistry.register(e.id, e.event, e.checker, e.installer)
    end
    HookRegistry._registered = true
end

function deskEnsureAllHooks()
    if not sampev then return end
    deskRegisterHookEntries()
    if HookRegistry and HookRegistry.ensureAll then
        HookRegistry.ensureAll()
    else
        installDeskSpMenuRpcBlock()
        installDeskCheckerRpcProbe()
    end
    if deskSpectateStats and deskSpectateStats.ensureInputHooks
            and type(deskSpectatePathNeedsInputHooks) == 'function'
            and deskSpectatePathNeedsInputHooks() then
        deskSpectateStats.ensureInputHooks()
    end
    if deskWmDispatch and deskWmDispatch.ensureInstalled then
        deskWmDispatch.ensureInstalled()
    end
end

function deskFinalizeReportDeskExport()
    if type(getfenv) ~= 'function' then return end
    local env = getfenv(1)
    if HookRegistry then
        env.HookRegistry = HookRegistry
        _G.ReportDesk = _G.ReportDesk or {}
        _G.ReportDesk.HookRegistry = HookRegistry
    end
    if deskRegisterHookEntries then env.deskRegisterHookEntries = deskRegisterHookEntries end
end

local function resetRpcBitstream(bs)
    if raknetBitStreamResetReadPointer then
        raknetBitStreamResetReadPointer(bs)
    end
end

-- RPC-блок серверного GTA-меню /sp (INITMENU/SHOWMENU/HIDEMENU).
function installDeskSpMenuRpcBlock()
    if deskCache.spMenuRpcRegistered then return end
    local ok, raknet = pcall(require, 'samp.raknet')
    if not ok or not raknet or not raknet.RPC then return end
    local okH, menuHandler = pcall(require, 'samp.events.handlers')
    if not okH or not menuHandler then return end

    local RPC_INIT_MENU = raknet.RPC.INITMENU
    local RPC_SHOW_MENU = raknet.RPC.SHOWMENU
    local RPC_HIDE_MENU = raknet.RPC.HIDEMENU

    local handler = function(rpcId, bs)
        if rpcId ~= RPC_INIT_MENU and rpcId ~= RPC_SHOW_MENU and rpcId ~= RPC_HIDE_MENU then
            return
        end
        if not shouldBlockServerSamMenu() then return end
        if rpcId == RPC_INIT_MENU then
            local readOk, packed = pcall(menuHandler.on_init_menu_reader, bs)
            resetRpcBitstream(bs)
            if readOk and packed then
                captureServerMenuLayout(packed[3], packed[4], packed[6], packed[2])
            end
        else
            resetRpcBitstream(bs)
        end
        return false
    end
    deskCache.spMenuRpcHandler = handler
    addEventHandler('onReceiveRpc', handler, 2147483647)
    deskCache.spMenuRpcRegistered = true
end

function uninstallDeskSpMenuRpcBlock()
    if deskCache.spMenuRpcHandler and removeEventHandler then
        pcall(removeEventHandler, 'onReceiveRpc', deskCache.spMenuRpcHandler)
    end
    deskCache.spMenuRpcHandler = nil
    deskCache.spMenuRpcRegistered = false
end

function installDeskCheckerRpcProbe()
    if deskCache.checkerRpcProbeRegistered then return end
    local ok, raknet = pcall(require, 'samp.raknet')
    if not ok or not raknet or not raknet.RPC then return end
    local RPC = raknet.RPC
    local skip = {
        [RPC.SHOWDIALOG or 61] = true,
        [RPC.CLIENTMESSAGE or 93] = true,
        [RPC.WORLDPLAYERADD or 32] = true,
        [RPC.WORLDPLAYERREMOVE or 163] = true,
        [RPC.UPDATESCORESPINGSIPS or 155] = true,
        [RPC.SETPLAYERCOLOR or 72] = true,
    }
    local handler = function(rpcId)
        if settings.checker_dev_rpc_probe ~= true then return true end
        if type(checkerIsAdmsSyncWindow) ~= 'function' or not checkerIsAdmsSyncWindow() then return true end
        if skip[rpcId] then return true end
        print(string.format('[Report Desk] checker rpc probe: id=%s during /adms sync', tostring(rpcId)))
        return true
    end
    deskCache.checkerRpcProbeHandler = handler
    addEventHandler('onReceiveRpc', handler)
    deskCache.checkerRpcProbeRegistered = true
end

function uninstallDeskCheckerRpcProbe()
    if deskCache.checkerRpcProbeHandler and removeEventHandler then
        pcall(removeEventHandler, 'onReceiveRpc', deskCache.checkerRpcProbeHandler)
    end
    deskCache.checkerRpcProbeHandler = nil
    deskCache.checkerRpcProbeRegistered = false
end

function uninstallDeskSpMenuHooks()
    if not sampev then return end
    if deskCache.spMenuInitHandler and sampev.onInitMenu == deskCache.spMenuInitHandler then
        sampev.onInitMenu = deskCache.hookPrevSpMenuInit
    end
    if deskCache.spMenuShowHandler and sampev.onShowMenu == deskCache.spMenuShowHandler then
        sampev.onShowMenu = deskCache.hookPrevSpMenuShow
    end
    if deskCache.spMenuHideHandler and sampev.onHideMenu == deskCache.spMenuHideHandler then
        sampev.onHideMenu = deskCache.hookPrevSpMenuHide
    end
    deskCache.spMenuInitHandler = nil
    deskCache.spMenuShowHandler = nil
    deskCache.spMenuHideHandler = nil
    deskCache.hookPrevSpMenuInit = nil
    deskCache.hookPrevSpMenuShow = nil
    deskCache.hookPrevSpMenuHide = nil
end
