#!/usr/bin/env python3
import os
import sys

try:
    from lupa import LuaRuntime
except ImportError:
    print("pip install lupa")
    sys.exit(1)

wd = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
lib = os.path.join(wd, "lib")

CORE = [
    "report_desk_bootstrap.lua",
    "report_desk_constants.lua",
    "report_desk_theme.lua",
    "report_desk_state.lua",
    "report_desk_util.lua",
    "report_desk_profanity.lua",
    "report_desk_chat.lua",
    "report_desk_cheats.lua",
    "report_desk_skins.lua",
    "report_desk_input.lua",
    "report_desk_actions.lua",
    "report_desk_threads.lua",
    "report_desk_config.lua",
    "report_desk_ingest_runtime.lua",
    "report_desk_rules.lua",
    "report_desk_ui.lua",
    "report_desk_hooks.lua",
    "report_desk_env_export.lua",
    "report_desk_main.lua",
]

LATE = ["report_desk_remote_chat.lua", "report_desk_checker.lua"]

lua = LuaRuntime()
check = lua.eval(
    """
function(s, name)
    local loader = loadstring or load
    local fn, err = loader(s, name)
    if fn then return true, 'OK' end
    return false, tostring(err)
end
"""
)


def read(name):
    path = os.path.join(lib, name)
    with open(path, "r", encoding="utf-8", errors="replace") as f:
        return f.read()


print("=== individual files ===")
for name in CORE + LATE:
    ok, msg = check(read(name), "@" + name)
    print(f"{'OK' if ok else 'FAIL'} {name}: {msg if not ok else ''}")

print("\n=== combined core ===")
core_src = "\n".join(read(n) for n in CORE)
ok, msg = check(core_src, "@core")
print("core:", "OK" if ok else msg)

print("\n=== combined late ===")
late_src = "\n".join(read(n) for n in LATE)
ok, msg = check(late_src, "@late")
print("late:", "OK" if ok else msg)
