#!/usr/bin/env python3
import re
path = r"c:\Program Files (x86)\Advance Games\moonloader\lib\report_desk_remote_chat.lua"
raw = open(path, "rb").read()
# find first stem after JUNK_STEMS
m = re.search(rb"REMOTE_CHAT_JUNK_STEMS = \{([^}]+)\}", raw, re.S)
if m:
    block = m.group(1)
    for line in block.split(b"\n"):
        line = line.strip()
        if not line.startswith(b"'"):
            continue
        s = line.split(b"'")[1]
        print(s[:40], "-> utf8?" if s.startswith(b"\xd0") or s.startswith(b"\xd1") else "cp1251?", s[:20].hex())
