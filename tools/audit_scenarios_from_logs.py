#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Analyze Report Desk thread logs + SAMP chatlog vs quick scenarios."""
from __future__ import annotations

import json
import re
import sys
from collections import Counter, defaultdict
from pathlib import Path

ROOT = Path(r"c:\Program Files (x86)\Advance Games\moonloader")
CONFIG = ROOT / "config" / "admin_report_desk.lua"
USER_CFG = ROOT / "config" / "admin_report_desk_user.lua"
DEFAULT_CFG = ROOT / "config" / "admin_report_desk_user.default.lua"
CHATLOG = Path(
    r"C:\Users\Sadowski\Documents\GTA San Andreas User Files\SAMP\chatlog.txt"
)

MIN_Q_LEN = 8
REPORT_MARKERS = (
    " dm", " id", "id ", "убил", "чит", "читер", "наруш", "репорт", "hack", "cheat", "kill"
)
SKIP_REPLY = {
    "see", "gg", "спасибо", "ожидайте", "ожидайте.", "ок", "ok", "+", "0+", "-",
    "принял", "принято", "понял", "хорошо", "минуту", "сек", "ждите",
}
GENERIC_REPLIES = {
    "технич", "форум", "обратитесь", "ожидайте", "не могу", "уточн", "смотрю",
    "провер", "сейчас", "минут", "передал", "передаю",
}


def decode_lua_string(raw: str) -> str:
    raw = raw.strip()
    if not raw:
        return ""
    q = raw[0]
    if q not in "'\"":
        return raw
    out = []
    i = 1
    while i < len(raw):
        c = raw[i]
        if c == "\\" and i + 1 < len(raw):
            n = raw[i + 1]
            mapping = {"n": "\n", "r": "\r", "t": "\t", "\\": "\\", q: q}
            out.append(mapping.get(n, n))
            i += 2
            continue
        if c == q:
            break
        out.append(c)
        i += 1
    return "".join(out)


def parse_lua_file(path: Path, encoding: str) -> str:
    text = path.read_text(encoding=encoding, errors="replace")
    if not re.search(r"return\s*\{", text):
        raise ValueError(f"no return table in {path}")
    return text


def extract_threads(config_text: str) -> list[dict]:
    threads = []
    block_pat = re.compile(
        r'\["([^"]+)"\]\s*=\s*\{(.*?)\n\s*\},?\s*\n(?=\s*\["|\s*\}\s*$)',
        re.DOTALL,
    )
    msg_pat = re.compile(
        r"\{\s*dir\s*=\s*(['\"])(.*?)\1\s*,\s*text\s*=\s*(['\"])((?:\\.|(?!\3).)*)\3"
        r"(?:\s*,\s*ts\s*=\s*(\d+))?(?:\s*,\s*kind\s*=\s*(['\"])(.*?)\7)?[^}]*\}",
        re.DOTALL,
    )
    for bm in block_pat.finditer(config_text):
        key, body = bm.group(1), bm.group(2)
        nick_m = re.search(r'nick\s*=\s*"([^"]*)"', body)
        nick = nick_m.group(1) if nick_m else key
        messages = []
        for mm in msg_pat.finditer(body):
            messages.append({
                "dir": decode_lua_string(mm.group(2)),
                "text": decode_lua_string(mm.group(4)).strip(),
                "kind": (mm.group(8) or "").strip() if mm.lastindex and mm.lastindex >= 8 else "",
            })
        if messages:
            threads.append({"key": key, "nick": nick, "messages": messages})
    return threads


def norm(s: str) -> str:
    s = s.lower().strip()
    s = re.sub(r"\{[0-9a-f]+\}", "", s, flags=re.I)
    s = re.sub(r"\s+", " ", s)
    return s


def is_report(text: str) -> bool:
    low = norm(text)
    if re.search(r"\b\d+\s*dm\b", low):
        return True
    if re.search(r"\bid\s*\d+|\d+\s*id\b", low):
        return True
    if re.search(r"\b\d+\s*чит\b|\bчит\b", low):
        return True
    for m in REPORT_MARKERS:
        if m in low:
            return True
    return False


def extract_suspect_id(text: str) -> bool:
    low = norm(text)
    if re.search(r"\b\d+\s*dm\b", low):
        return True
    if re.search(r"\bid\s*\d+|\d+\s*id\b", low):
        return True
    if re.search(r"\b\d+\s*чит\b", low):
        return True
    return False


def is_faq_question(text: str) -> bool:
    t = text.strip()
    if len(t) < MIN_Q_LEN:
        return False
    if is_report(t):
        return False
    low = norm(t)
    if low in {"спасибо", "спс", "gg", "привет", "здравствуйте", "хай", "help"}:
        return False
    if re.fullmatch(r"\d+", t):
        return False
    if re.fullmatch(r"[\d\s\.,\-]+", t):
        return False
    return True


def is_useful_admin_reply(text: str) -> bool:
    t = text.strip()
    if not t or len(t) < 2:
        return False
    low = norm(t)
    if low in SKIP_REPLY:
        return False
    if low.startswith("/sp ") or low == "/sp":
        return False
    if re.fullmatch(r"/\w+", low):
        return True
    if low.startswith("/"):
        return True
    cmds = (
        "/gps", "/home", "/c ", "/e", "/bp", "/skill", "/news", "/join", "/price",
        "/donate", "/leave", "/lic", "/ad ", "/reset", "/i", "/f", "/fn", "/find",
        "/showall", "/warninfo", "/tasks", "/creditshelp", "/st", "/setspawn",
        "/buym", "/sellgun", "/sellsim", "/tr ", "/hist", "/mn ", "/getfuel",
        "/zamlist", "/liclist", "/unrent", "/makegun", "/fix", "/allow", "/free",
    )
    if any(x in low for x in cmds):
        return True
    if re.search(r"f2|alt\s*\+\s*enter|enter", low):
        return True
    if len(t) >= 12 and not any(g in low for g in GENERIC_REPLIES):
        return True
    if len(t) >= 6 and (t.startswith("/") or "gps" in low or "команда" in low or "нажм" in low):
        return True
    return False


def parse_string_list(raw: str) -> list[str]:
    return re.findall(r"\"((?:\\.|[^\"])*)\"", raw or "")


def parse_scenarios(path: Path) -> list[dict]:
    text = path.read_text(encoding="utf-8")
    scenarios = []
    for block in re.finditer(
        r"\{\s*label\s*=\s*\"((?:\\.|[^\"])*)\"(.*?)\n\s*\},",
        text,
        re.DOTALL,
    ):
        body = block.group(2)
        label = block.group(1)
        reply_m = re.search(r'reply\s*=\s*"((?:\\.|[^\"])*)"', body)
        kw_m = re.search(r"keywords\s*=\s*\{([^}]*)\}", body)
        neg_m = re.search(r"negative_keywords\s*=\s*\{([^}]*)\}", body)
        enabled = "enabled = false" not in body
        priority_m = re.search(r"priority\s*=\s*(\d+)", body)
        skip_m = re.search(r"skip_if_report_id\s*=\s*(true|false)", body)
        scenarios.append({
            "label": label,
            "reply": reply_m.group(1) if reply_m else "",
            "keywords": parse_string_list(kw_m.group(1) if kw_m else ""),
            "negative_keywords": parse_string_list(neg_m.group(1) if neg_m else ""),
            "enabled": enabled,
            "priority": int(priority_m.group(1)) if priority_m else 0,
            "skip_if_report_id": skip_m.group(1) != "false" if skip_m else True,
        })
    return scenarios


def tokenize_keywords(keywords: list[str]) -> list[set[str]]:
    out = []
    for kw in keywords:
        parts = re.split(r"[+\s]+", norm(kw))
        parts = [p for p in parts if len(p) >= 3]
        if parts:
            out.append(set(parts))
    return out


def keyword_phrase_match(question: str, kw: str) -> bool:
    q = norm(question)
    q_words = set(re.findall(r"[a-zA-Zа-яА-ЯёЁ0-9/]+", q))
    parts = re.split(r"[+\s]+", norm(kw))
    parts = [p for p in parts if len(p) >= 3]
    if not parts:
        return False
    req = set(parts)
    if req.issubset(q_words):
        return True
    ok = True
    for t in parts:
        if len(t) >= 5:
            if t not in q and not any(w.startswith(t) for w in q_words):
                ok = False
                break
        elif t not in q_words and t not in q:
            ok = False
            break
    return ok


def scenario_match(question: str, sc: dict) -> bool:
    for kw in sc.get("keywords") or []:
        if keyword_phrase_match(question, kw):
            return True
    return False


def scenario_negative_match(question: str, sc: dict) -> bool:
    for kw in sc.get("negative_keywords") or []:
        if keyword_phrase_match(question, kw):
            return True
    return False


def scenario_visible(question: str, sc: dict) -> bool:
    if not sc.get("enabled", True):
        return False
    if sc.get("skip_if_report_id", True) and is_report(question) and extract_suspect_id(question):
        return False
    if not scenario_match(question, sc):
        return False
    if scenario_negative_match(question, sc):
        return False
    return True


def reply_similarity(a: str, b: str) -> float:
    a, b = norm(a), norm(b)
    if not a or not b:
        return 0.0
    if a == b:
        return 1.0
    if a in b or b in a:
        return 0.85
    ta, tb = set(re.findall(r"\w+", a)), set(re.findall(r"\w+", b))
    if not ta or not tb:
        return 0.0
    return len(ta & tb) / len(ta | tb)


def extract_qa_pairs(threads: list[dict]) -> list[dict]:
    pairs = []
    for th in threads:
        msgs = th["messages"]
        pending_q = None
        for m in msgs:
            kind = m.get("kind") or ""
            if m["dir"] == "in" and kind in ("", "player"):
                if is_faq_question(m["text"]):
                    pending_q = m["text"].strip()
                else:
                    pending_q = None
            elif m["dir"] == "out" and kind in ("reply", "reply_self", "") and pending_q:
                ans = m["text"].strip()
                if is_useful_admin_reply(ans):
                    pairs.append({
                        "question": pending_q,
                        "answer": ans,
                        "nick": th["nick"],
                    })
                    pending_q = None
                elif norm(ans) in SKIP_REPLY:
                    pending_q = None
    return pairs


def parse_chatlog_pc(path: Path) -> list[str]:
    if not path.exists():
        return []
    lines = []
    pat = re.compile(r"\[PC\]\s+[^:]+:\s*(?:\{[0-9A-Fa-f]+\})?(.*)$", re.I)
    for raw in path.read_text(encoding="utf-8", errors="replace").splitlines():
        m = pat.search(raw)
        if m:
            text = m.group(1).strip()
            if text:
                lines.append(text)
    return lines


def suggest_keywords_from_questions(questions: list[str], limit: int = 12) -> list[str]:
    """Build +phrase keywords from real player questions."""
    phrases: Counter[str] = Counter()
    stop = {
        "как", "где", "что", "это", "или", "можно", "надо", "нужно", "пожалуйста",
        "help", "помогите", "здравствуйте", "привет", "очень", "меня", "мне",
        "если", "когда", "почему", "какой", "какая", "какие", "есть", "тут",
        "для", "про", "ещё", "еще", "тоже", "только", "чтобы", "чтоб", "что",
    }
    for q in questions:
        words = re.findall(r"[a-zA-Zа-яА-ЯёЁ0-9/]+", norm(q))
        words = [w for w in words if len(w) >= 3 and w not in stop]
        if len(words) >= 2:
            phrases["+".join(words[:3])] += 1
        if len(words) >= 3:
            phrases["+".join(words[:4])] += 1
        for w in words:
            if len(w) >= 5:
                phrases[w] += 1
    return [p for p, _ in phrases.most_common(limit)]


def main() -> int:
    if not CONFIG.exists():
        print("Config not found:", CONFIG)
        return 1

    cfg_text = parse_lua_file(CONFIG, "cp1251")
    threads = extract_threads(cfg_text)
    pairs = extract_qa_pairs(threads)
    pc_lines = parse_chatlog_pc(CHATLOG)

    sc_path = USER_CFG if USER_CFG.exists() else DEFAULT_CFG
    all_scenarios = parse_scenarios(sc_path)
    scenarios = [s for s in all_scenarios if s.get("enabled", True)]

    matched = []
    unmatched = []
    mismatches = []

    for p in pairs:
        q = p["question"]
        hits = [s for s in scenarios if scenario_visible(q, s)]
        if not hits:
            unmatched.append(p)
            continue
        best = max(hits, key=lambda s: reply_similarity(p["answer"], s["reply"]))
        sim = reply_similarity(p["answer"], best["reply"])
        matched.append({**p, "scenario": best["label"], "scenario_reply": best["reply"], "sim": sim})
        if sim < 0.35:
            mismatches.append({**p, "scenario": best["label"], "scenario_reply": best["reply"], "sim": sim})

    un_clusters = Counter(norm(p["question"]) for p in unmatched)
    mm_by_sc = defaultdict(list)
    for m in mismatches:
        mm_by_sc[m["scenario"]].append(m)

    ans_clusters = Counter()
    ans_examples = defaultdict(list)
    for p in unmatched:
        ak = norm(p["answer"])[:100]
        ans_clusters[ak] += 1
        if len(ans_examples[ak]) < 3:
            ans_examples[ak].append(p)

    # Section 5: chatlog false positives
    fp_by_sc: dict[str, list[str]] = defaultdict(list)
    fp_report_hits: list[tuple[str, list[str]]] = []
    for text in pc_lines:
        hits = [s["label"] for s in scenarios if scenario_visible(text, s)]
        if hits:
            if is_report(text):
                fp_report_hits.append((text, hits))
            else:
                for h in hits:
                    if len(fp_by_sc[h]) < 8:
                        fp_by_sc[h].append(text)

    # Section 6: scenario -> Q&A map
    sc_qa_map: dict[str, list[dict]] = defaultdict(list)
    for p in pairs:
        for sc in all_scenarios:
            if scenario_match(p["question"], sc):
                sc_qa_map[sc["label"]].append(p)

    # Section 7: disable candidates
    disable_candidates = []
    for sc in all_scenarios:
        qa = sc_qa_map.get(sc["label"], [])
        fp = fp_by_sc.get(sc["label"], [])
        if not qa and fp:
            disable_candidates.append({
                "label": sc["label"],
                "reason": "only false positives on chatlog, no Q→A in threads",
                "fp_count": len(fp),
            })
        elif not qa and sc.get("enabled", True):
            disable_candidates.append({
                "label": sc["label"],
                "reason": "no Q→A in thread history",
                "fp_count": len(fp),
            })

    # Rebuild hints JSON
    rebuild_hints = {}
    for sc in all_scenarios:
        label = sc["label"]
        qa = sc_qa_map.get(label, [])
        ans_c = Counter(p["answer"] for p in qa).most_common(5)
        questions = [p["question"] for p in qa]
        rebuild_hints[label] = {
            "current_reply": sc["reply"],
            "top_answers": [{"text": a, "count": c} for a, c in ans_c],
            "suggested_reply": ans_c[0][0] if ans_c else sc["reply"],
            "suggested_keywords": suggest_keywords_from_questions(questions) if questions else sc["keywords"],
            "qa_count": len(qa),
            "fp_chatlog": fp_by_sc.get(label, [])[:5],
            "negative_suggestions": [],
        }
        # suggest negatives from FP that aren't reports
        for fp_text in fp_by_sc.get(label, []):
            if not is_report(fp_text):
                words = re.findall(r"[a-zA-Zа-яА-ЯёЁ0-9/]+", norm(fp_text))
                if words:
                    rebuild_hints[label]["negative_suggestions"].append("+".join(words[:2]))

    hints_path = ROOT / "tools" / "scenario_rebuild_hints.json"
    hints_path.write_text(json.dumps(rebuild_hints, ensure_ascii=False, indent=2), encoding="utf-8")

    out = ROOT / "tools" / "scenario_audit_report.txt"
    lines = []
    W = lines.append

    W("=" * 72)
    W("REPORT DESK — аудит сценариев v2 (threads + chatlog)")
    W("=" * 72)
    W(f"Файл логов: {CONFIG}")
    W(f"Chatlog:    {CHATLOG} ({'есть' if CHATLOG.exists() else 'нет'})")
    W(f"Сценарии:   {sc_path.name}")
    W(f"Тредов:     {len(threads)}")
    W(f"[PC] строк: {len(pc_lines)}")
    W(f"Пар Q→A:    {len(pairs)} (FAQ-вопрос + полезный ответ админа)")
    W(f"С матчем:   {len(matched)}")
    W(f"Без сценария: {len(unmatched)} ({len(un_clusters)} уник. вопросов)")
    W(f"Расхождение ответа: {len(mismatches)}")
    W(f"Ложн. на chatlog (не репорт): {sum(len(v) for v in fp_by_sc.values())}")
    W(f"Ложн. на chatlog (репорт/DM): {len(fp_report_hits)}")
    W("")

    W("=" * 72)
    W("1. НЕТ ПОДХОДЯЩЕГО СЦЕНАРИЯ — топ повторяющихся вопросов")
    W("=" * 72)
    for q_norm, cnt in un_clusters.most_common(40):
        sample = next(p for p in unmatched if norm(p["question"]) == q_norm)
        sample_ans = Counter(norm(p["answer"]) for p in unmatched if norm(p["question"]) == q_norm).most_common(3)
        W(f"\n[{cnt}x] {sample['question']}")
        W("  Ответы админов:")
        for a, ac in sample_ans:
            W(f"    ({ac}x) {a[:120]}")

    W("\n" + "=" * 72)
    W("2. ГРУППЫ НОВЫХ ТЕМ (похожие ответы админов, нет сценария)")
    W("=" * 72)
    for ak, cnt in ans_clusters.most_common(30):
        if cnt < 2:
            continue
        ex = ans_examples[ak][0]
        W(f"\n[{cnt}x] типичный ответ: {ex['answer'][:140]}")
        for e in ans_examples[ak][:3]:
            W(f"  Q: {e['question'][:120]}")

    W("\n" + "=" * 72)
    W("3. СЦЕНАРИЙ ЕСТЬ, НО ОТВЕТ АДМИНА ДРУГОЙ (sim < 0.35)")
    W("=" * 72)
    for sc_name in sorted(mm_by_sc, key=lambda k: -len(mm_by_sc[k])):
        items = mm_by_sc[sc_name]
        W(f"\n### {sc_name} ({len(items)} случаев)")
        rep = items[0]
        W(f"  Сценарий сейчас: {rep['scenario_reply'][:140]}")
        ans_c = Counter(norm(x["answer"]) for x in items).most_common(5)
        W("  Что отвечают админы:")
        for a, ac in ans_c:
            raw = next(x["answer"] for x in items if norm(x["answer"]) == a)
            W(f"    ({ac}x) {raw[:140]}")
        W("  Примеры вопросов:")
        for x in items[:4]:
            W(f"    - {x['question'][:120]}")

    W("\n" + "=" * 72)
    W("4. СВОДКА ПО СЦЕНАРИЯМ С РАСХОЖДЕНИЯМИ")
    W("=" * 72)
    for sc_name, items in sorted(mm_by_sc.items(), key=lambda kv: -len(kv[1])):
        W(f"  {sc_name}: {len(items)} расхождений")

    W("\n" + "=" * 72)
    W("5. ЛОЖНЫЕ СРАБАТЫВАНИЯ НА CHATLOG [PC] (не DM/чит)")
    W("=" * 72)
    for sc_name in sorted(fp_by_sc, key=lambda k: -len(fp_by_sc[k])):
        items = fp_by_sc[sc_name]
        if not items:
            continue
        W(f"\n### {sc_name} ({len(items)} примеров)")
        for t in items[:6]:
            W(f"  - {t[:120]}")

    W("\n" + "=" * 72)
    W("5b. СРАБАТЫВАНИЯ НА DM/ЧИТ/ID РЕПОРТАХ (должны быть скрыты skip_if_report_id)")
    W("=" * 72)
    for text, hits in fp_report_hits[:30]:
        W(f"  [{', '.join(hits)}] {text[:100]}")

    W("\n" + "=" * 72)
    W("6. КАРТА СЦЕНАРИЙ → Q→A (из thread history)")
    W("=" * 72)
    for sc in all_scenarios:
        label = sc["label"]
        qa = sc_qa_map.get(label, [])
        W(f"\n### {label} (Q→A: {len(qa)}, enabled={sc.get('enabled', True)})")
        W(f"  reply сейчас: {sc['reply'][:120]}")
        if qa:
            ans_c = Counter(p["answer"] for p in qa).most_common(3)
            W("  Топ ответы админов:")
            for a, c in ans_c:
                W(f"    ({c}x) {a[:120]}")
            W("  Примеры вопросов:")
            for p in qa[:4]:
                W(f"    - {p['question'][:100]}")
        else:
            W("  (нет пар Q→A в истории)")

    W("\n" + "=" * 72)
    W("7. КАНДИДАТЫ НА ОТКЛЮЧЕНИЕ")
    W("=" * 72)
    for dc in disable_candidates:
        W(f"  {dc['label']}: {dc['reason']} (FP chatlog: {dc['fp_count']})")

    W("\n" + "=" * 72)
    W("8. СПОРНЫЕ ТЕМЫ (несколько разных ответов или нет Q→A)")
    W("=" * 72)
    for label, hint in sorted(rebuild_hints.items()):
        tops = hint.get("top_answers") or []
        if len(tops) >= 2 and reply_similarity(tops[0]["text"], tops[1]["text"]) < 0.35:
            W(f"\n  {label}:")
            for t in tops[:3]:
                W(f"    ({t['count']}x) {t['text'][:100]}")
        elif hint["qa_count"] == 0 and hint.get("fp_chatlog"):
            W(f"\n  {label}: нет Q→A, но есть FP на chatlog")

    out.write_text("\n".join(lines), encoding="utf-8")
    print(f"Done. Report: {out}")
    print(f"Hints: {hints_path}")
    print(
        f"Threads={len(threads)} pairs={len(pairs)} unmatched={len(un_clusters)} "
        f"mismatches={len(mismatches)} pc_fp={sum(len(v) for v in fp_by_sc.values())}"
    )
    return 0


if __name__ == "__main__":
    sys.exit(main())
