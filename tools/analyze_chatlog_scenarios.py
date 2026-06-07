# -*- coding: utf-8 -*-
"""Analyze chatlog report questions against Report Desk scenario keywords."""
import re
import json
import sys
from collections import Counter
from pathlib import Path

MOONLOADER = Path(__file__).resolve().parent.parent
CHATLOG = Path.home() / 'Documents' / 'GTA San Andreas User Files' / 'SAMP' / 'chatlog.txt'
USER_CFG = MOONLOADER / 'config' / 'admin_report_desk_user.lua'

TYPO_WORDS = {
    'рабоать': 'работать',
    'работаь': 'работать',
    'роботать': 'работать',
    'госс': 'гос',
    'аатобус': 'автобус',
    'аатобусником': 'автобусником',
    'защитало': 'засчитало',
    'дальнабой': 'дальнобой',
    'далнобой': 'дальнобой',
    'мехаик': 'механик',
    'обьявление': 'объявление',
    'скилы': 'скиллы',
    'inventar': 'инвентарь',
}


def normalize(s):
    s = s.lower().replace('ё', 'е')
    s = re.sub(r'[^a-zа-я0-9/+ ]', ' ', s)
    return ' '.join(s.split())


def normalize_typo(s):
    s = normalize(s)
    words = []
    for w in s.split():
        w = re.sub(r'aa', 'a', w)
        w = re.sub(r'oo', 'o', w)
        w = re.sub(r'ii', 'i', w)
        w = TYPO_WORDS.get(w, w)
        words.append(w)
    return ' '.join(words)


def load_keywords():
    text = USER_CFG.read_text(encoding='utf-8')
    keywords = []
    for block in re.findall(r'keywords\s*=\s*\{([^}]+)\}', text):
        keywords.extend(re.findall(r'"([^"]+)"', block))
    return keywords


def token_match(token, msg, msg_typo):
    token = normalize(token)
    if not token:
        return False
    if '+' in token:
        parts = [normalize(p) for p in token.split('+') if normalize(p)]
        for bag in (msg, msg_typo):
            ok = True
            for p in parts:
                if len(p) >= 5:
                    if not any(w.startswith(p) for w in bag.split()):
                        ok = False
                        break
                elif p not in bag.split() and f' {p} ' not in f' {bag} ':
                    ok = False
                    break
            if ok:
                return True
        return False
    for bag in (msg, msg_typo):
        if len(token) >= 5:
            if any(w.startswith(token) for w in bag.split()):
                return True
        if f' {token} ' in f' {bag} ':
            return True
    return False


def matches_any(keywords, body):
    msg = normalize(body)
    msg_typo = normalize_typo(body)
    return any(token_match(kw, msg, msg_typo) for kw in keywords)


def main():
    chatlog = CHATLOG
    if len(sys.argv) > 1:
        chatlog = Path(sys.argv[1])
    if not chatlog.exists():
        print('chatlog not found:', chatlog)
        sys.exit(1)

    raw = chatlog.read_bytes().decode('cp1251', errors='replace')
    pat = re.compile(r'\[(?:PC|S|M)\]\s+[^:]+?\[\d+\]\s*:\s*\{[0-9A-Fa-f]+\}(.+)', re.I)
    questions = []
    for ln in raw.splitlines():
        m = pat.search(ln)
        if not m:
            continue
        body = m.group(1).strip()
        low = body.lower()
        if '?' in body or low.startswith('как ') or ' как ' in low or low.startswith('где ') or ' где ' in low:
            if not re.match(r'^\d+\s*(dm|db|rp\s)', body, re.I):
                questions.append(body)

    keywords = load_keywords()
    matched = []
    unmatched = []
    for q in questions:
        if re.search(r'\d+\s*(dm|db|id|чит|убил|наруш)', q, re.I):
            continue
        if matches_any(keywords, q):
            matched.append(q)
        else:
            unmatched.append(q)

    total = len(matched) + len(unmatched)
    pct = (100.0 * len(matched) / total) if total else 0
    print(f'Questions (how/where): {len(questions)}')
    print(f'Evaluated (no dm/id): {total}')
    print(f'Matched: {len(matched)} ({pct:.1f}%)')
    print(f'Unmatched: {len(unmatched)}')
    print('--- Top unmatched ---')
    for q in unmatched[:25]:
        print(' ', q[:100])
    out = MOONLOADER / 'tools' / '_chatlog_match_report.json'
    out.write_text(json.dumps({
        'matched_count': len(matched),
        'unmatched_count': len(unmatched),
        'coverage_pct': round(pct, 1),
        'unmatched_sample': unmatched[:50],
    }, ensure_ascii=False, indent=2), encoding='utf-8')
    print('Report:', out)


if __name__ == '__main__':
    main()
