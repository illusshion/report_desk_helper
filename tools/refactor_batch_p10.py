#!/usr/bin/env python3
"""Batch extract checker.lua (phase 10)."""
from __future__ import annotations

import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT / 'tools'))
from refactor_extract import extract, remove_functions, find_function_block  # noqa: E402

CHK = ROOT / 'lib' / 'report_desk_checker.lua'

CATALOG_OPS = [
    'checkerParseAdminsDialog', 'checkerLogAdmsParseFailure', 'checkerLeadersSplitCols',
    'checkerLeaderStatusOnline', 'checkerIsLeadersHeaderRow', 'checkerParseLeadersDialog',
    'checkerDialogLooksLikeLeaders', 'checkerIsLeadersDialog', 'checkerIsAdminsDialog',
    'checkerDialogLooksLikeAdmins', 'checkerIsAdminsHeaderRow', 'checkerSortCatalogAdmins',
    'checkerMergeChiefCatalog', 'checkerMergeTopAdminCatalog', 'checkerMergeAdminsIntoCatalog',
    'checkerApplyAdmsOnlineSnapshot', 'checkerApplyAdminsDialogSync', 'checkerApplyLeadersOnlineSnapshot',
    'checkerApplyLeadersSync',
]

ONLINE = [
    'checkerCopyOnlineEntry', 'checkerDedupeOnlineById', 'checkerCopyOnlineList',
    'checkerPublishHudState', 'checkerHudLists', 'checkerMarkPlayersSeenFromOnline',
    'checkerResetJoinNotifyWarmup', 'checkerTryEnableJoinNotify', 'checkerShouldNotifyJoin',
    'checkerMarkPlayerSeen', 'checkerNotifyJoinEnabled', 'checkerNotifyQuitEnabled',
    'checkerSampConnected', 'checkerSampReady', 'checkerMaxPlayerId', 'checkerBuildNickIndex',
    'checkerPruneNickIndex', 'checkerEnsureNickIndex', 'checkerIndexOnePlayer',
    'checkerCountNickIndex', 'checkerIsPauseMenuOpen', 'checkerIsSuspended',
    'checkerRebuildOnline', 'checkerRemoveOnlineById', 'checkerAddOnlineFromJoin',
    'checkerTrackedRole', 'checkerSayAdminJoin', 'checkerSayLeaderJoin',
]

LEADERS = [
    'checkerLeaderHiddenKey', 'checkerIsLeaderNickHidden', 'checkerSetLeaderNickHidden',
    'checkerNormalizeNick', 'checkerLeaderIsHidden', 'checkerLeaderShowRef',
    'checkerSetLeaderHidden', 'checkerAddFriend',
    'checkerNormalizeLeaderField', 'checkerLeaderUiText', 'checkerResolveLeaderOrgId',
    'checkerInferLeaderOrgId', 'checkerLeaderDisplayRole', 'checkerLeaderSettingsStats',
    'checkerLeaderSubline', 'checkerLeaderFactionKey', 'checkerLeaderFactionMeta',
    'checkerLeaderOrgClistColor', 'checkerLeaderFactionClistImColor', 'checkerLeaderNickColor',
    'checkerLeaderFactionColor', 'checkerBuildLeaderFactionGroups',
]


def write_mod(name: str, header: str, funcs: list[str]) -> None:
    lines = CHK.read_text(encoding='utf-8').splitlines()
    found = [f for f in funcs if find_function_block(lines, f, 0)]
    if not found:
        print('skip', name)
        return
    found.sort(key=lambda n: find_function_block(lines, n, 0)[0])
    body = extract(CHK, found, '')
    (ROOT / 'lib' / name).write_text(header + '\n\n' + body, encoding='utf-8', newline='\n')
    remove_functions(CHK, found)
    print('wrote', name, len(found), 'funcs')


def main() -> None:
    write_mod('report_desk_checker_catalog_ops.lua', '--[[ Модуль: merge /adms и /leaders в каталог. ]]', CATALOG_OPS)
    write_mod('report_desk_checker_online.lua', '--[[ Модуль: online scan, join/quit notify. ]]', ONLINE)
    write_mod('report_desk_checker_leaders.lua', '--[[ Модуль: строки фракций/leaders HUD. ]]', LEADERS)
    manifest = ROOT / 'config' / 'report_desk_bundle_manifest.lua'
    m = manifest.read_text(encoding='utf-8')
    ins = """        'report_desk_checker_catalog_ops.lua',
        'report_desk_checker_online.lua',
        'report_desk_checker_leaders.lua',
"""
    if 'report_desk_checker_catalog_ops.lua' not in m:
        m = m.replace("        'report_desk_checker.lua',", ins + "        'report_desk_checker.lua',")
        manifest.write_text(m, encoding='utf-8', newline='\n')
    print('checker lines', len(CHK.read_text(encoding='utf-8').splitlines()))


if __name__ == '__main__':
    main()
