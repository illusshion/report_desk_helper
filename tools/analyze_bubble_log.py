#!/usr/bin/env python3
import re
from collections import defaultdict

path = r"c:\Program Files (x86)\Advance Games\moonloader\config\remote_chat_bubble_log.txt"
text = open(path, "rb").read().decode("cp1251")
d = defaultdict(lambda: {"n": 0, "shown": 0})
for line in text.splitlines():
    bm = re.search(r"body=([^\t]*)", line)
    nm = re.search(r"note=([^\t\r]*)", line)
    if not bm:
        continue
    b = bm.group(1).strip()
    note = nm.group(1).strip() if nm else ""
    d[b]["n"] += 1
    if note == "shown":
        d[b]["shown"] += 1

out_path = path.replace(".txt", "_utf8.txt")
with open(out_path, "w", encoding="utf-8") as out:
    for b, st in sorted(d.items(), key=lambda x: -x[1]["n"]):
        if st["n"] < 2:
            continue
        hud = f" HUD={st['shown']}" if st["shown"] else ""
        out.write(f"{st['n']:4d}{hud:10s}  {b}\n")
print("written:", out_path)
