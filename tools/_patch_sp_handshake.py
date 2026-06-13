#!/usr/bin/env python3
"""Fix /sp handshake consistency: outbound queue, menu guards, refresh deps."""
import pathlib
import sys

ROOT = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader")


def read(rel):
    return (ROOT / rel).read_text(encoding="utf-8")


def write(rel, text):
    (ROOT / rel).write_text(text.replace("\n", "\r\n"), encoding="utf-8")


def patch_once(text, old, new, label):
    old_n = old.replace("\r\n", "\n")
    new_n = new.replace("\r\n", "\n")
    if old_n not in text.replace("\r\n", "\n"):
        print(f"MISSING [{label}]", file=sys.stderr)
        sys.exit(1)
    return text.replace("\r\n", "\n").replace(old_n, new_n, 1)


# --- util: mark pending when queueing sp ---
util = read("lib/report_desk_util.lua")
util = patch_once(
    util,
    """    if sampTextInputBusy() then
        if not specSessionMod then
            local okReq, mod = pcall(require, 'report_desk_spectate_session')
            specSessionMod = okReq and mod or false
        end
        if specSessionMod and specSessionMod.queueOutbound then
            pcall(specSessionMod.queueOutbound, cmdBody)
        end""",
    """    if sampTextInputBusy() then
        if not specSessionMod then
            local okReq, mod = pcall(require, 'report_desk_spectate_session')
            specSessionMod = okReq and mod or false
        end
        local spIdBusy = cmdBody:match('^sp%s+(%d+)%s*$')
        if spIdBusy and not skipPendingSp()
                and type(deskSpectateStats) == 'table'
                and deskSpectateStats.markPendingSpCommand then
            pcall(deskSpectateStats.markPendingSpCommand, tonumber(spIdBusy), '')
        end
        if specSessionMod and specSessionMod.queueOutbound then
            pcall(specSessionMod.queueOutbound, cmdBody)
        end""",
    "util queue mark",
)
write("lib/report_desk_util.lua", util)

# --- session: flush with skipSpHookLocal ---
sess = read("lib/report_desk_spectate_session.lua")
sess = patch_once(
    sess,
    """    session.lastOutboundAt = now
    session.lastOutboundCmd = cmd
    pcall(sendChatFn, cmd)
end""",
    """    session.lastOutboundAt = now
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
end""",
    "session flush",
)
write("lib/report_desk_spectate_session.lua", sess)

# --- menu: refresh fallback ---
menu = read("lib/report_desk_spectate_menu.lua")
menu = patch_once(
    menu,
    """            if deps.sendMenuOutbound then
                pcall(deps.sendMenuOutbound, cmd, { quietSp = true, skipPendingMark = true })
            elseif deps.sendChat then
                pcall(deps.sendChat, cmd)
            elseif deps.queueOutbound then
                pcall(deps.queueOutbound, cmd)
            end""",
    """            if deps.sendMenuOutbound then
                pcall(deps.sendMenuOutbound, cmd, { quietSp = true, skipPendingMark = true })
            elseif deps.sendChat then
                local cache = rawget(_G, 'deskCache')
                if type(cache) == 'table' then
                    cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
                end
                pcall(deps.sendChat, cmd)
                if type(cache) == 'table' then
                    local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
                    cache.skipSpHookLocal = n > 0 and n or nil
                end
            end""",
    "menu refresh",
)
write("lib/report_desk_spectate_menu.lua", menu)

# --- sp_refresh fallback ---
refresh = read("lib/report_desk_sp_refresh.lua")
refresh = patch_once(
    refresh,
    """    elseif deps.sendChat then
        ok = pcall(deps.sendChat, '/sp ' .. tostring(id)) ~= false
    end""",
    """    elseif deps.sendChat then
        local cache = rawget(_G, 'deskCache')
        if type(cache) == 'table' then
            cache.skipSpHookLocal = (tonumber(cache.skipSpHookLocal) or 0) + 1
        end
        ok = pcall(deps.sendChat, '/sp ' .. tostring(id)) ~= false
        if type(cache) == 'table' then
            local n = (tonumber(cache.skipSpHookLocal) or 0) - 1
            cache.skipSpHookLocal = n > 0 and n or nil
        end
    end""",
    "sp_refresh fallback",
)
write("lib/report_desk_sp_refresh.lua", refresh)

# --- spectate_stats ---
stats = read("lib/report_desk_spectate_stats.lua")
stats = patch_once(
    stats,
    """function M.flushOutbound()

    spUi.flushOutbound()

end""",
    """function M.flushOutbound()
    spUi.flushOutbound()
end

function M.hasOutboundPending()
    return spUi.hasOutboundPending and spUi.hasOutboundPending() or false
end""",
    "stats hasOutboundPending",
)
stats = patch_once(
    stats,
    """        isStatsPending = function()
            local pid = state.pendingStId
            return pid and (os.clock() - (state.pendingStAt or 0)) < PENDING_ST_SEC
        end,
        setPlayerSpectating = deps and deps.setPlayerSpectating,""",
    """        isStatsPending = function()
            local pid = state.pendingStId
            return pid and (os.clock() - (state.pendingStAt or 0)) < PENDING_ST_SEC
        end,
        getConfirmedTargetId = function()
            return specSession.getTargetId and specSession.getTargetId() or -1
        end,
        getOutboundId = function() return state.pendingSpId end,
        hasPendingSp = M.hasPendingSp,
        isHandshaking = function()
            return M.hasPendingSp()
                or (specSession.isAwaitingSpectate and specSession.isAwaitingSpectate())
        end,
        isRefreshInFlight = spRefresh.isRefreshInFlight,
        queueOutbound = function(cmd)
            if specSession.queueOutbound then pcall(specSession.queueOutbound, cmd) end
        end,
        setPlayerSpectating = deps and deps.setPlayerSpectating,""",
    "stats buildSpUiDeps guards",
)
stats = patch_once(
    stats,
    """            if src == 'sp_line' or src == 'reload_recover' then
                syncOpts.forceAutoSt = true
            elseif spRefresh.shouldSkipAutoSt and spRefresh.shouldSkipAutoSt(id) then
                syncOpts.skipAutoSt = true
            elseif src == 'spectate_player' then
                syncOpts.forceAutoSt = true
                if lastSpecStepAt and (os.clock() - lastSpecStepAt) < SPEC_STEP_AUTO_ST_DELAY
                        and M.hasFullStats(id) then
                    syncOpts.skipAutoSt = true
                end
            end""",
    """            if spRefresh.shouldSkipAutoSt and spRefresh.shouldSkipAutoSt(id)
                    and M.hasFullStats(id) then
                syncOpts.skipAutoSt = true
            elseif src == 'sp_line' or src == 'spectate_player' or src == 'reload_recover' then
                syncOpts.forceAutoSt = true
                if src == 'spectate_player' then
                    if lastSpecStepAt and (os.clock() - lastSpecStepAt) < SPEC_STEP_AUTO_ST_DELAY
                            and M.hasFullStats(id) then
                        syncOpts.skipAutoSt = true
                    end
                end
            end""",
    "stats onSessionBegin",
)
stats = patch_once(
    stats,
    """        hasPendingSp = M.hasPendingSp,
        sendMenuOutbound = sendMenuOutbound,
        sendChat = sendChat,""",
    """        hasPendingSp = M.hasPendingSp,
        isHandshaking = function()
            return M.hasPendingSp()
                or (specSession.isAwaitingSpectate and specSession.isAwaitingSpectate())
        end,
        hasOutboundPending = function()
            return specSession.hasOutboundPending and specSession.hasOutboundPending() or false
        end,
        sendMenuOutbound = sendMenuOutbound,
        sendChat = sendChat,""",
    "stats configureSpRefresh",
)
write("lib/report_desk_spectate_stats.lua", stats)

print("Patched sp handshake (5 files)")
