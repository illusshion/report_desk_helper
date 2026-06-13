#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Find Lua 5.1 forward-ref bugs: local called from closure defined before local decl."""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / 'lib'
MANIFEST = ROOT / 'config' / 'report_desk_bundle_manifest.lua'

LUA_KEYWORDS = {
    'and', 'break', 'do', 'else', 'elseif', 'end', 'false', 'for', 'function',
    'goto', 'if', 'in', 'local', 'nil', 'not', 'or', 'repeat', 'return',
    'then', 'true', 'until', 'while',
}
SAFE_GLOBALS = {
    'assert', 'error', 'ipairs', 'pairs', 'pcall', 'xpcall', 'print', 'require',
    'select', 'setmetatable', 'getmetatable', 'tonumber', 'tostring', 'type',
    'rawget', 'rawset', 'unpack', 'loadstring', 'load', 'next', 'table',
    'string', 'math', 'bit', 'os', 'io', 'debug', 'collectgarbage', 'package',
    '_G', '_VERSION',
}

LOCAL_DECL = re.compile(
    r'^\s*local\s+(?:function\s+)?([A-Za-z_][A-Za-z0-9_]*)\b'
)
LOCAL_FUNC = re.compile(r'^\s*local\s+function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
GLOBAL_FUNC = re.compile(r'^\s*function\s+([A-Za-z_][A-Za-z0-9_]*)\s*\(')
ASSIGN_FUNC = re.compile(
    r'^\s*(?:([A-Za-z_][A-Za-z0-9_]*)\s*\.\s*)?([A-Za-z_][A-Za-z0-9_]*)\s*=\s*function\s*\('
)
CALL = re.compile(r'(?<![.\w:])([A-Za-z_][A-Za-z0-9_]*)\s*\(')


@dataclass
class Issue:
    file: str
    line: int
    callee: str
    callee_decl: int
    func_start: int
    snippet: str
    chunk: str | None = None


def read_manifest_chunks() -> dict[str, list[str]]:
    text = MANIFEST.read_text(encoding='utf-8', errors='replace')
    out: dict[str, list[str]] = {}
    for key in ('core_a_a', 'core_a_b', 'core_a_b2', 'core_a_c', 'late'):
        m = re.search(rf"{re.escape(key)}\s*=\s*\{{([^}}]*)\}}", text, re.S)
        if not m:
            continue
        files = re.findall(r"'([^']+\.lua)'", m.group(1))
        short = key.replace('core_a_', 'core_').replace('core_a_a', 'core_a')
        out[short] = files
    return out


def strip_strings_and_comments(line: str) -> str:
    out = []
    i = 0
    n = len(line)
    while i < n:
        if line[i] == '-' and i + 1 < n and line[i + 1] == '-':
            break
        if line[i] in ('"', "'"):
            q = line[i]
            out.append(' ')
            i += 1
            while i < n:
                if line[i] == '\\' and i + 1 < n:
                    i += 2
                    continue
                if line[i] == q:
                    i += 1
                    break
                i += 1
            continue
        if line[i] == '[' and i + 1 < n and line[i + 1] == '[':
            j = line.find(']]', i + 2)
            if j < 0:
                break
            out.append(' ' * (j + 2 - i))
            i = j + 2
            continue
        out.append(line[i])
        i += 1
    return ''.join(out)


def find_function_starts(lines: list[str]) -> list[tuple[int, int | None]]:
    """Return (line_no, name|None) for each function start (1-based lines)."""
    starts: list[tuple[int, int | None]] = []
    for i, raw in enumerate(lines, 1):
        line = strip_strings_and_comments(raw)
        m = LOCAL_FUNC.match(line)
        if m:
            starts.append((i, None))  # local function — scope handled separately
            continue
        m = GLOBAL_FUNC.match(line)
        if m:
            starts.append((i, None))
            continue
        m = ASSIGN_FUNC.match(line)
        if m and m.group(1) is None:
            starts.append((i, None))
    return starts


def local_decl_lines(lines: list[str]) -> dict[str, int]:
    decl: dict[str, int] = {}
    for i, raw in enumerate(lines, 1):
        line = strip_strings_and_comments(raw)
        m = LOCAL_DECL.match(line)
        if m:
            name = m.group(1)
            if name not in decl:
                decl[name] = i
    return decl


def enclosing_func_start(line_no: int, func_starts: list[int]) -> int | None:
    candidates = [s for s in func_starts if s <= line_no]
    return candidates[-1] if candidates else None


def audit_text(label: str, text: str, file_label: str | None = None) -> list[Issue]:
    lines = text.splitlines()
    decl = local_decl_lines(lines)
    func_starts = [s for s, _ in find_function_starts(lines)]
    issues: list[Issue] = []

    for i, raw in enumerate(lines, 1):
        line = strip_strings_and_comments(raw)
        if not line.strip() or line.lstrip().startswith('--'):
            continue
        fs = enclosing_func_start(i, func_starts)
        if fs is None:
            continue
        for m in CALL.finditer(line):
            name = m.group(1)
            if name in LUA_KEYWORDS or name in SAFE_GLOBALS:
                continue
            if name not in decl:
                continue
            decl_line = decl[name]
            # Same-block `local function` is hoisted; decl before call is fine.
            if decl_line <= i:
                continue
            if decl_line > fs:
                issues.append(Issue(
                    file=file_label or label,
                    line=i,
                    callee=name,
                    callee_decl=decl_line,
                    func_start=fs,
                    snippet=raw.strip()[:100],
                    chunk=label if file_label else None,
                ))
    return issues


def audit_file(path: Path) -> list[Issue]:
    text = path.read_text(encoding='utf-8', errors='replace')
    return audit_text(path.name, text, str(path.relative_to(ROOT)))


def audit_chunk(chunk_name: str, files: list[str]) -> list[Issue]:
    parts: list[str] = []
    for rel in files:
        p = LIB / rel
        if p.is_file():
            parts.append(p.read_text(encoding='utf-8', errors='replace'))
    text = '\n'.join(parts)
    return audit_text(chunk_name, text, f'bundle:{chunk_name}')


def main() -> int:
    if sys.platform == 'win32':
        try:
            sys.stdout.reconfigure(encoding='utf-8')
        except Exception:
            pass

    all_issues: list[Issue] = []

    for path in sorted(LIB.glob('report_desk*.lua')):
        if path.name == 'report_desk_app.lua':
            continue
        all_issues.extend(audit_file(path))

    chunks = read_manifest_chunks()
    for chunk_name, files in chunks.items():
        all_issues.extend(audit_chunk(chunk_name, files))

    # Dedupe by file+line+callee
    seen = set()
    unique: list[Issue] = []
    for iss in all_issues:
        key = (iss.file, iss.line, iss.callee)
        if key in seen:
            continue
        seen.add(key)
        unique.append(iss)

    unique.sort(key=lambda x: (x.file, x.line, x.callee))

    if not unique:
        print('No forward-ref issues found.')
        return 0

    print(f'Found {len(unique)} forward-ref issue(s):\n')
    for iss in unique:
        where = iss.file
        if iss.chunk:
            where = f'{iss.file} (chunk {iss.chunk})'
        print(f'  {where}:{iss.line}')
        print(f'    call {iss.callee}() inside function@{iss.func_start}, local decl@{iss.callee_decl}')
        print(f'    {iss.snippet}')
        print()
    return 1


if __name__ == '__main__':
    raise SystemExit(main())
