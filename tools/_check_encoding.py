import pathlib
raw = pathlib.Path(r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_spectate_stats.lua").read_bytes()
idx = raw.find(b"ST_DIALOG_TITLE_UTF8")
print("UTF8 line bytes:", raw[idx:idx+100])
idx2 = raw.find(b"low:find(")
print("find line bytes:", raw[idx2:idx2+100])
text = raw.decode("utf-8")
i = text.find("ST_DIALOG_TITLE_UTF8")
print("decoded:", repr(text[i:i+60]))
