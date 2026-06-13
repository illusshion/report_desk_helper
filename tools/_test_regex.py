import pathlib, re
t = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
pat = (
    r"    if M\.hasPendingSp\(\) then\n+"
    r"\s+orphanSinceAt = nil\n+"
    r"\s+orphanRecoveryTried = false\n+"
    r"\s+targetOfflineSinceAt = nil\n+"
    r"\s+return\n+"
    r"\s+end\n+"
    r"\s+local stRetryId = M\.getTargetId\(\)"
)
m = re.search(pat, t)
print("match", bool(m))
if m:
    print(repr(m.group(0)[:300]))
