#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Generate human review sheet for FAQ scenario training."""
from __future__ import annotations

import csv
import re
from collections import Counter, defaultdict
from pathlib import Path

# reuse audit helpers
import sys
sys.path.insert(0, str(Path(__file__).parent))
from audit_scenarios_from_logs import (  # noqa: E402
    CHATLOG,
    CONFIG,
    USER_CFG,
    extract_qa_pairs,
    extract_threads,
    is_faq_question,
    is_report,
    norm,
    parse_chatlog_pc,
    parse_lua_file,
    parse_scenarios,
    reply_similarity,
    scenario_match,
    scenario_visible,
)

ROOT = Path(r"c:\Program Files (x86)\Advance Games\moonloader")
OUT_CSV = ROOT / "tools" / "scenario_training_review.csv"
OUT_MD = ROOT / "tools" / "scenario_training_review.md"

SKIP_QUESTION_PATTERNS = (
    "помогите", "help", "спасибо", "gg", "ожидайте", "dm", "чит", "репорт",
    "убил", "наруш", "провоцир", "жалоб", "ban", "see",
)


def is_review_worthy_question(q: str) -> bool:
    if not is_faq_question(q) and len(q.strip()) < 12:
        return False
    if is_report(q):
        return False
    low = norm(q)
    if any(p in low for p in SKIP_QUESTION_PATTERNS):
        return False
    if re.search(r"\b\d+\s*dm\b|\bid\s*\d+|\d+\s*id\b|\b\d+\s*чит\b", low):
        return False
    return True


def best_scenario(question: str, scenarios: list[dict]) -> tuple[str, str, float]:
    hits = [s for s in scenarios if scenario_visible(question, s)]
    if not hits:
        return "", "", 0.0
    # pick first by priority if we had it; fallback label sort
    sc = hits[0]
    return sc["label"], sc.get("reply", ""), 1.0


def main() -> int:
    cfg_text = parse_lua_file(CONFIG, "cp1251")
    threads = extract_threads(cfg_text)
    pairs = extract_qa_pairs(threads)
    pc_lines = parse_chatlog_pc(CHATLOG)
    scenarios = [s for s in parse_scenarios(USER_CFG) if s.get("enabled", True)]

    rows: list[dict] = []
    seen_q = set()

    def add_row(source: str, question: str, log_answer: str = "", note: str = ""):
        qn = norm(question)
        if qn in seen_q or not is_review_worthy_question(question):
            return
        seen_q.add(qn)
        label, sc_reply, _ = best_scenario(question, scenarios)
        sim = reply_similarity(log_answer, sc_reply) if log_answer and sc_reply else 0.0
        status = "OK" if label and sim >= 0.35 else ("NO_SCENARIO" if not label else "WRONG_REPLY")
        rows.append({
            "status": status,
            "source": source,
            "question": question.strip(),
            "answer_in_logs": log_answer.strip(),
            "matched_scenario": label,
            "scenario_reply_now": sc_reply,
            "your_canonical_answer": "",
            "action": "",  # keep / fix / new / skip
            "note": note,
        })

    # 1) unmatched FAQ from threads
    for p in pairs:
        q = p["question"]
        if not any(scenario_visible(q, s) for s in scenarios):
            add_row("thread", q, p["answer"], "нет сценария")

    # 2) mismatches
    for p in pairs:
        q = p["question"]
        hits = [s for s in scenarios if scenario_visible(q, s)]
        if not hits:
            continue
        best = max(hits, key=lambda s: reply_similarity(p["answer"], s["reply"]))
        sim = reply_similarity(p["answer"], best["reply"])
        if sim < 0.35:
            add_row("mismatch", q, p["answer"], f"сценарий «{best['label']}» не тот ответ")

    # 3) chatlog PC without scenario (sample unique)
    for text in pc_lines:
        if is_report(text):
            continue
        if len(text) >= 10 and not any(scenario_visible(text, s) for s in scenarios):
            add_row("chatlog", text, "", "из chatlog, сценария нет")

    # sort: mismatches first, then no scenario, then by source
    order = {"WRONG_REPLY": 0, "NO_SCENARIO": 1, "OK": 2}
    rows.sort(key=lambda r: (order.get(r["status"], 9), r["source"], norm(r["question"])))

    # cap for human review (~120 items)
    rows = rows[:120]

    # CSV for Excel / Google Sheets
    fields = [
        "status", "source", "question", "answer_in_logs",
        "matched_scenario", "scenario_reply_now",
        "your_canonical_answer", "action", "note",
    ]
    with OUT_CSV.open("w", encoding="utf-8-sig", newline="") as f:
        w = csv.DictWriter(f, fieldnames=fields)
        w.writeheader()
        w.writerows(rows)

    # Markdown companion
    lines = [
        "# FAQ-сценарии — лист для проверки",
        "",
        "Заполни колонку **your_canonical_answer** в CSV (или прямо здесь в чате блоками).",
        "",
        "**action:**",
        "- `keep` — текущий сценарий и ответ верны",
        "- `fix` — сценарий есть, но ответ/ключи поправить",
        "- `new` — нужен новый сценарий",
        "- `skip` — не FAQ (RP, жалоба, отказ)",
        "",
        f"Всего строк: **{len(rows)}** (CSV: `{OUT_CSV.name}`)",
        "",
    ]
    by_status = Counter(r["status"] for r in rows)
    lines.append(f"- WRONG_REPLY: {by_status.get('WRONG_REPLY', 0)}")
    lines.append(f"- NO_SCENARIO: {by_status.get('NO_SCENARIO', 0)}")
    lines.append("")
    for status in ("WRONG_REPLY", "NO_SCENARIO"):
        chunk = [r for r in rows if r["status"] == status]
        if not chunk:
            continue
        lines.append(f"## {status}")
        lines.append("")
        for i, r in enumerate(chunk[:40], 1):
            lines.append(f"### {i}. {r['question'][:100]}")
            lines.append(f"- Источник: `{r['source']}`")
            if r["answer_in_logs"]:
                lines.append(f"- Ответ в логах: `{r['answer_in_logs'][:120]}`")
            if r["matched_scenario"]:
                lines.append(f"- Сценарий сейчас: **{r['matched_scenario']}** → `{r['scenario_reply_now'][:100]}`")
            lines.append(f"- **Твой ответ:** …")
            lines.append(f"- **action:** …")
            lines.append("")

    OUT_MD.write_text("\n".join(lines), encoding="utf-8")
    print(f"CSV: {OUT_CSV} ({len(rows)} rows)")
    print(f"MD:  {OUT_MD}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
