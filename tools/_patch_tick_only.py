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
        raise SystemExit(f"tick failed {n}")

if "sessionConfirmed and not M.hasPendingSt()" not in text:
    text = text.replace(
        "    if stRetryId >= 0 and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then",
        "    if stRetryId >= 0 and sessionConfirmed and not M.hasPendingSt() and not M.hasFullStats(stRetryId) then",
        1,
    )

path.write_text(text.replace("\n", "\r\n"), encoding="utf-8")
print("tick saved")
