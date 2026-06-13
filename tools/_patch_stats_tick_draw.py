#!/usr/bin/env python3
import pathlib
import re

path = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua")
text = path.read_text(encoding="utf-8").replace("\r\n", "\n")

if "if M.hasPendingSp() and sessionConfirmed then" not in text:
    pat = (
        r"    if M\.hasPendingSp\(\) then\n+"
        r"\s+orphanSinceAt = nil\n+"
        r"\s+orphanRecoveryTried = false\n+"
        r"\s+targetOfflineSinceAt = nil\n+"
        r"\s+return\n+"
        r"\s+end\n+"
        r"\s+local stRetryId = M\.getTargetId\(\)"
    )
    repl = (
        "    local sessionConfirmed = specSession.isActive and specSession.isActive()\n\n"
        "    if M.hasPendingSp() and not sessionConfirmed then\n\n"
        "        orphanSinceAt = nil\n\n"
        "        orphanRecoveryTried = false\n\n"
        "        targetOfflineSinceAt = nil\n\n"
        "        return\n\n"
        "    end\n\n"
        "    if M.hasPendingSp() and sessionConfirmed then\n\n"
        "        M.cancelPendingSp()\n\n"
        "    end\n\n"
        "    local stRetryId = M.getTargetId()"
    )
    text, n = re.subn(pat, repl, text, count=1)
    if n != 1:
        raise SystemExit(f"tick patch failed: {n}")

text = text.replace(
    "    if stRetryId >= 0 and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then",
    "    if stRetryId >= 0 and sessionConfirmed and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then",
    1,
)

if "sessionConfirmedForHud" not in text:
    text = text.replace(
        "function M.drawOverlayImpl(settings)",
        (
            "local function sessionConfirmedForHud(id)\n"
            "    id = tonumber(id)\n"
            "    if not id or id < 0 then return false end\n"
            "    if specSession.isActive and specSession.isActive()\n"
            "            and specSession.getTargetId and specSession.getTargetId() == id then\n"
            "        return true\n"
            "    end\n"
            "    return specPlayerActive() and M.getTargetId() == id\n"
            "end\n\n"
            "function M.drawOverlayImpl(settings)"
        ),
        1,
    )

draw_tail = text.split("drawOverlayImpl", 1)[1]
if "scheduleAutoStats(id, true)" not in draw_tail[:12000]:
    wait_msg = (
        r"\\xCE\\xE6\\xE8\\xE4\\xE0\\xED\\xE8\\xE5 /st \\xE8\\xEB\\xE8 "
        r"\\xab\\xCE\\xE1\\xED\\xEE\\xE2\\xE8\\xF2\\xFC\\xBB"
    )
    pat2 = (
        r"(        elseif not hasAny then\n+"
        r"\s+imgui\.TextColored\(col_muted2, uiText\('" + wait_msg + r"'\)\)\n+"
        r"\s+)(        end)"
    )
    repl2 = (
        r"\1            if id == M.getTargetId() and sessionConfirmedForHud(id)\n"
        r"                    and not pendingSt and not M.hasPendingSt() then\n"
        r"                local stGap = os.clock() - (state.lastAutoStAt or 0)\n"
        r"                if stGap >= 2.0 and stGap <= 60.0 then\n"
        r"                    state.lastAutoStAt = os.clock()\n"
        r"                    scheduleAutoStats(id, true)\n"
        r"                end\n"
        r"            end\n\n"
        r"\2"
    )
    text, n2 = re.subn(pat2, repl2, text, count=1)
    if n2 != 1:
        raise SystemExit(f"draw retry failed: {n2}")

path.write_text(text.replace("\n", "\r\n"), encoding="utf-8")
print("OK tick + draw")
