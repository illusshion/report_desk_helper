# -*- coding: utf-8 -*-
"""Count top-level locals in Report Desk core bundle (Lua 5.1 limit: 200 per chunk)."""
import os
import re

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LIB = os.path.join(ROOT, "lib")

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

LOCAL_RE = re.compile(
    r"^local\s+(?:function\s+(\w+)|([\w_,\s]+))", re.MULTILINE
)


def count_toplevel_locals(text):
    depth = 0
    count = 0
    names = []
    for line in text.splitlines():
        stripped = line.strip()
        if stripped.startswith("function ") or stripped.startswith("local function "):
            depth += 1
            if stripped.startswith("local function "):
                if depth == 1:
                    m = re.match(r"local function\s+(\w+)", stripped)
                    if m:
                        count += 1
                        names.append(m.group(1))
            continue
        if stripped == "end" or stripped.startswith("end "):
            if depth > 0:
                depth -= 1
            continue
        if depth == 0 and stripped.startswith("local "):
            m = LOCAL_RE.match(line)
            if m:
                if m.group(1):
                    count += 1
                    names.append(m.group(1))
                elif m.group(2):
                    parts = [p.strip() for p in m.group(2).split(",") if p.strip()]
                    count += len(parts)
                    names.extend(parts)
    return count, names


total = 0
all_names = []
for f in CORE:
    path = os.path.join(LIB, f)
    text = open(path, encoding="utf-8", errors="replace").read()
    n, names = count_toplevel_locals(text)
    print(f"{f}: {n}")
    total += n
    all_names.extend(names)

print(f"\nCORE total top-level locals: {total}")
if total > 200:
    print("EXCEEDS Lua 5.1 limit of 200!")
    print("Extra:", total - 200)

chk_path = os.path.join(LIB, "report_desk_checker.lua")
text = open(chk_path, encoding="utf-8", errors="replace").read()
n, _ = count_toplevel_locals(text)
print(f"\nchecker top-level locals: {n}")
