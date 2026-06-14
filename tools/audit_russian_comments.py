#!/usr/bin/env python3
"""Audit English comments in report_desk_*.lua; optional auto-translate common patterns."""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
LIB = ROOT / 'lib'

# Частые замены EN → RU для секционных комментариев
REPLACEMENTS = [
    (r'^-- Get ', '-- '),
    (r'^-- Process ', '-- '),
    (r'^-- Handle ', '-- '),
    (r'^-- Try ', '-- '),
    (r'^-- Clear ', '-- Очистка '),
    (r'^-- Strip ', '-- '),
    (r'^-- NO-API:', '-- Запасной путь без API:'),
    (r'^-- REWRITTEN:', '-- '),
    (r'^-- Must be above ', '-- '),
    (r'^-- Builtin auto-rules', '-- Встроенные автоответы'),
    (r'^-- Transmit Ans Wire', '-- Отправка ans на сервер'),
    (r'^-- Ans Reply Needs Split', '-- Разбиение длинного ans'),
]

EN_PATTERN = re.compile(
    r'^--(?!\[\[)(?!.*[а-яА-ЯёЁ]).*[A-Za-z]{4,}'
)


def audit_file(path: Path) -> list[str]:
    issues = []
    for i, line in enumerate(path.read_text(encoding='utf-8', errors='replace').splitlines(), 1):
        if EN_PATTERN.match(line.strip()):
            issues.append(f'{path.name}:{i}: {line.strip()[:80]}')
    return issues


def translate_file(path: Path) -> int:
    lines = path.read_text(encoding='utf-8', errors='replace').splitlines()
    changed = 0
    out = []
    for line in lines:
        new = line
        for pat, repl in REPLACEMENTS:
            m = re.match(pat, line.strip())
            if m:
                new = re.sub(pat, repl, line)
                break
        if new != line:
            changed += 1
        out.append(new)
    if changed:
        path.write_text('\n'.join(out) + '\n', encoding='utf-8')
    return changed


def main() -> int:
    do_fix = '--fix' in sys.argv
    all_issues: list[str] = []
    fixed = 0
    for path in sorted(LIB.glob('report_desk_*.lua')):
        if do_fix:
            fixed += translate_file(path)
        all_issues.extend(audit_file(path))
    print(f'English comment lines: {len(all_issues)}')
    if do_fix:
        print(f'Auto-fixed lines: {fixed}')
    for item in all_issues[:40]:
        print(item)
    if len(all_issues) > 40:
        print(f'... and {len(all_issues) - 40} more')
    return 1 if all_issues and not do_fix else 0


if __name__ == '__main__':
    raise SystemExit(main())
