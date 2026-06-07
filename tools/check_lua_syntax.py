#!/usr/bin/env python3
"""Quick Lua syntax check via lupa (Lua 5.1)."""
import os
import sys

try:
    from lupa import LuaRuntime
except ImportError:
    print("install lupa: pip install lupa")
    sys.exit(1)

wd = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
files = [
    "lib/report_desk_spectate_stats.lua",
    "lib/report_desk_hooks.lua",
    "lib/report_desk_checker.lua",
    "lib/report_desk_spectate_ans.lua",
    "lib/report_desk_sp_ui.lua",
    "lib/report_desk_sp_vehicle_hud.lua",
    "lib/report_desk_bootstrap.lua",
    "lib/report_desk_ui.lua",
    "lib/report_desk_main.lua",
]

lua = LuaRuntime()
failed = False
for rel in files:
    path = os.path.join(wd, rel.replace("/", os.sep))
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        src = f.read()
    try:
        fn = lua.eval(
            "function(s, name) return load(s, name, 't') end"
        )(src, "@" + rel)
        if fn is None:
            print(rel, "FAIL: loadstring returned nil")
            failed = True
        else:
            print(rel, "OK")
    except Exception as e:
        print(rel, "FAIL:", e)
        failed = True

sys.exit(1 if failed else 0)
