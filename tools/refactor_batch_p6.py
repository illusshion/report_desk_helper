#!/usr/bin/env python3
"""Batch extract rules.lua into focused modules (phase 6)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from refactor_extract import find_function_block, extract  # noqa: E402

RULES = ROOT / 'lib' / 'report_desk_rules.lua'

AUTO_FUNCS = [
    'tickAutoReplyQueue', 'threadHasIncomingReportBody', 'enqueueAutoReplyJob',
    'cloneBuiltinAutoRule', 'getActiveBuiltinAutoRules', 'processAutoRules',
    'clearPendingAutoConfirm', 'clearAutoReplyQueue', 'clearAllPendingAuto',
    'scheduleAutoRulesRetry', 'runAutoRulesForReport', 'confirmPendingAuto',
    'getPendingAutoForSelected',
]

INGEST_FUNCS = [
    'addThreadEventMessage', 'findExistingThreadKey', 'addThreadEventMessageToExisting',
    'ingestAdminActionEvent', 'ingestPunishmentEvent', 'processChatLineIngest',
    'onIncomingReport', 'ingestReport', 'pollReportIngest',
]

COMPOSER_FUNCS = [
    'sendAnsToThread', 'defaultComposerQuickButtons', 'normalizeComposerQuickButton',
    'ensureComposerQuickButtons', 'syncLegacyGgTechFromComposerButtons',
    'getTimeReplyText', 'syncGgReplyToComposer', 'getGgReplyText', 'getTechReplyText',
    'sendReplyToSelected', 'sendPresetReplyToSelected', 'sendGgReplyToSelected',
    'sendTechReplyToSelected', 'runHelperCmd',
]

UI_FUNCS = [
    'drawAccentStrip', 'pushPanelStyle', 'popPanelStyle', 'settingsSection',
    'settingsHint', 'settingsBlockBegin', 'settingsBlockEnd', 'settingsSubLabel',
    'deskPanelChildFlags',
]


def write_module(path: Path, header: str, names: list[str], prefix: str = '') -> None:
    body = extract(RULES, names, '')
    content = header + '\n\n' + (prefix + '\n\n' if prefix else '') + body
    path.write_text(content, encoding='utf-8', newline='\n')
    print('wrote', path.name, len(content.splitlines()), 'lines')


def remove_funcs(names: list[str]) -> None:
    from refactor_extract import remove_functions
    remove_functions(RULES, names)


def main() -> None:
    prefix = '''local autoReplyQueue = {}
local autoReplyHead = 1
local autoReplyTail = 0
local AUTO_REPLY_QUEUE_MAX = 48

local function autoReplyQueueLen()
    return autoReplyTail - autoReplyHead + 1
end

local function autoReplyDefaultDelaySec()
    return (tonumber(AUTO_REPLY_DELAY_MS) or 250) / 1000
end

local function autoReplySrcAllowsRetry(src)
    return src == 'srv' or src == 'chat' or src == 'retry'
end

local function dispatchAutoReplyJob(job)
    if not job then return end
    if settings.profanity_filter_enabled then
        pcall(checkProfanityFromPlayer, job.nick, job.id, job.body, job.src)
    end
    local tk = findThreadKeyByNick(job.nick) or nickKey(job.nick)
    local th = threads[tk]
    if not th then
        if (job.attempt or 0) < 2 then
            enqueueAutoReplyJob(job.nick, job.id, job.body, job.src, {
                attempt = (job.attempt or 0) + 1,
                delaySec = 0.15,
            })
        end
        return
    end
    local result = processAutoRules(th, job.body)
    if result == false and autoReplySrcAllowsRetry(job.src) then
        scheduleAutoRulesRetry(th, job.body, job.attempt or 0)
    end
end
'''
    write_module(
        ROOT / 'lib' / 'report_desk_auto_rules.lua',
        '--[[ Модуль: автоответы (очередь, time/GG, retry). ]]',
        AUTO_FUNCS,
        prefix,
    )
    write_module(
        ROOT / 'lib' / 'report_desk_ingest_threads.lua',
        '--[[ Модуль: ingest репортов и poll чата. ]]',
        INGEST_FUNCS,
    )
    write_module(
        ROOT / 'lib' / 'report_desk_composer_replies.lua',
        '--[[ Модуль: быстрые ответы и composer (GG/tech/time). ]]',
        COMPOSER_FUNCS,
    )
    write_module(
        ROOT / 'lib' / 'report_desk_ui_settings_widgets.lua',
        '--[[ Модуль: общие виджеты настроек ImGui. ]]',
        UI_FUNCS,
    )
    remove_funcs(AUTO_FUNCS + INGEST_FUNCS + COMPOSER_FUNCS + UI_FUNCS)
    # update rules header
    text = RULES.read_text(encoding='utf-8')
    text = text.replace(
        '--[[ Модуль: auto-rules, scenarios, processChatLineIngest. ]]',
        '--[[ Модуль: фильтр тредов и preview (auto/ingest вынесены). ]]',
        1,
    )
    RULES.write_text(text, encoding='utf-8', newline='\n')
    print('cleaned rules.lua', len(text.splitlines()), 'lines')

    manifest = ROOT / 'config' / 'report_desk_bundle_manifest.lua'
    m = manifest.read_text(encoding='utf-8')
    insert = """        'report_desk_auto_rules.lua',
        'report_desk_ingest_threads.lua',
        'report_desk_composer_replies.lua',
        'report_desk_ui_settings_widgets.lua',
"""
    if 'report_desk_auto_rules.lua' not in m:
        m = m.replace("        'report_desk_rules.lua',", insert + "        'report_desk_rules.lua',")
        manifest.write_text(m, encoding='utf-8', newline='\n')
        print('updated manifest')


if __name__ == '__main__':
    main()
