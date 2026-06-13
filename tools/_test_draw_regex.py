import pathlib, re
t = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua").read_text(encoding="utf-8").replace("\r\n", "\n")
draw = t.split("drawOverlayImpl", 1)[1][:15000]
wait_msg = (
    r"\\xCE\\xE6\\xE8\\xE4\\xE0\\xED\\xE8\\xE5 /st \\xE8\\xEB\\xE8 "
    r"\\xab\\xCE\\xE1\\xED\\xEE\\xE2\\xE8\\xF2\\xFC\\xBB"
)
pat2 = (
    r"(        elseif not hasAny then\n+"
    r"\s+imgui\.TextColored\(col_muted2, uiText\('" + wait_msg + r"'\)\)\n+"
    r"\s+)(        end)"
)
m = re.search(pat2, draw)
print("match", bool(m))
if m:
    print(repr(m.group(0)[:400]))
else:
    i = draw.find("elseif not hasAny")
    print(repr(draw[i:i+350]))
