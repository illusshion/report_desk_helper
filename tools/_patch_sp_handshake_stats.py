#!/usr/bin/env python3
import pathlib
import sys

path = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua")
text = path.read_text(encoding="utf-8")
orig = text

def norm(s):
    return s.replace("\r\n", "\n")

def patch(old, new, label):
    global text
    if norm(old) not in norm(text):
        print(f"MISSING [{label}]", file=sys.stderr)
        sys.exit(1)
    text = norm(text).replace(norm(old), norm(new), 1)

patch(
    """function M.flushOutbound()

    spUi.flushOutbound()

end""",
    """function M.flushOutbound()

    spUi.flushOutbound()

end



function M.hasOutboundPending()

    return spUi.hasOutboundPending and spUi.hasOutboundPending() or false

end""",
    "hasOutboundPending",
)

patch(
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
    "buildSpUiDeps",
)

patch(
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
    "onSessionBegin",
)

patch(
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
    "configureSpRefresh",
)

if norm(text) == norm(orig):
    print("No changes", file=sys.stderr)
    sys.exit(1)

path.write_text(text.replace("\n", "\r\n"), encoding="utf-8")
print("Patched spectate_stats.lua")
