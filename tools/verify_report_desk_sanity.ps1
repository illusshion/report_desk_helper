# Post-refactor sanity checks (no MoonLoader runtime required).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lib = Join-Path $root 'lib'
$fail = 0

function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:fail++ }
function Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

# 2) spectate_stats required API (facade + ctx + pending split)
$statsFacade = Get-Content (Join-Path $lib 'report_desk_spectate_stats.lua') -Raw -Encoding Default
$statsCtx = Get-Content (Join-Path $lib 'report_desk_sp_stats_ctx.lua') -Raw -Encoding Default
$statsPending = Get-Content (Join-Path $lib 'report_desk_sp_spectate_pending.lua') -Raw -Encoding Default
$stats = $statsFacade + "`n" + $statsCtx + "`n" + $statsPending
foreach ($fn in @('requestStats', 'onServerMessage', 'parseSpServerLine', 'onShowDialog', 'parseDialogText')) {
    if ($statsCtx -notmatch "function M\.$fn") { Fail "sp_stats_ctx.lua missing M.$fn" }
    else { Ok "sp_stats_ctx M.$fn" }
}
foreach ($fn in @('markPendingSpCommand', 'cancelPendingSp', 'hasPendingSp', 'tickPendingSp')) {
    if ($statsPending -notmatch "function M\.$fn") { Fail "sp_spectate_pending.lua missing M.$fn" }
    else { Ok "sp_spectate_pending M.$fn" }
}
if ($statsCtx -match 'local function getStatsDialogApi' -or $statsCtx -match 'function M\.parseDialogText') {
    Ok 'spectate_stats dialog API wiring'
} else { Fail 'sp_stats_ctx.lua missing dialog parse API' }
if ($statsCtx -match "text == ' then") { Fail 'sp_stats_ctx.lua corrupted empty-string check (line ~1117)' }
else { Ok 'spectate_stats empty-string guard' }
if ($statsCtx -notmatch 'function M\.isHudDragActive') { Fail 'sp_stats_ctx missing M.isHudDragActive' }
else { Ok 'sp_stats_ctx M.isHudDragActive' }
if ($statsCtx -notmatch 'function M\.wantsHudInput') { Fail 'sp_stats_ctx missing M.wantsHudInput' }
else { Ok 'sp_stats_ctx M.wantsHudInput' }
if ($statsFacade -notmatch "require 'report_desk_sp_stats_ctx'") { Fail 'spectate_stats facade missing ctx require' }
else { Ok 'spectate_stats facade ctx require' }
$tdBlock = Get-Content (Join-Path $lib 'report_desk_sp_menu_td_block.lua') -Raw -Encoding Default
if ($tdBlock -notmatch 'function cp1251') { Fail 'sp_menu_td_block must use cp1251()/string.char for markers' }
else { Ok 'sp_menu_td_block cp1251 markers' }
if ($tdBlock -match "SP_MENU_MARKERS[\s\S]{0,800}\\x") { Fail 'sp_menu_td_block SP_MENU_MARKERS must not use \\x escapes' }
else { Ok 'sp_menu_td_block no hex escapes in markers' }
$luaExe = 'C:\Program Files (x86)\Lua\5.1\lua.exe'
if (Test-Path $luaExe) {
    foreach ($pair in @(
        @{ Name = 'spectate_stats'; Path = 'report_desk_spectate_stats.lua' },
        @{ Name = 'sp_stats_ctx'; Path = 'report_desk_sp_stats_ctx.lua' },
        @{ Name = 'sp_spectate_pending'; Path = 'report_desk_sp_spectate_pending.lua' },
        @{ Name = 'sp_menu_td_block'; Path = 'report_desk_sp_menu_td_block.lua' }
    )) {
        $statsPath = (Join-Path $lib $pair.Path) -replace '\\', '/'
        $luaOut = & $luaExe -e "local f=io.open('$statsPath','rb'); local s=f:read('*a'); f:close(); local fn,err=loadstring(s,'@$($pair.Name)'); if not fn then print(err) os.exit(1) end; print('OK')" 2>&1
        if ($LASTEXITCODE -ne 0 -or "$luaOut" -notmatch 'OK') { Fail "$($pair.Path) Lua syntax: $luaOut" }
        else { Ok "$($pair.Path) Lua syntax" }
    }
}

# 3) checker sync: no duplicate globals vs checker.lua
$sync = Get-Content (Join-Path $lib 'report_desk_checker_sync.lua') -Raw -Encoding Default
$chk = Get-Content (Join-Path $lib 'report_desk_checker.lua') -Raw -Encoding Default
$syncFns = [regex]::Matches($sync, '(?m)^function (checker\w+|flushChecker\w+)') | ForEach-Object { $_.Groups[1].Value }
foreach ($name in ($syncFns | Select-Object -Unique)) {
    if ($chk -match "(?m)^function $name") { Fail "duplicate function $name in checker.lua and checker_sync.lua" }
}
if ($fail -eq 0) { Ok 'checker sync no duplicate exports in checker.lua' }

# 4) hooks RPC pass-through
$hooks = Get-Content (Join-Path $lib 'report_desk_hooks_sp_menu.lua') -Raw -Encoding Default
if ($hooks -match 'shouldBlockServerSamMenu' -and $hooks -match '2147483647' -and $hooks -match 'return false') {
    Ok 'SP menu RPC block (ae992ea style)'
} elseif ($hooks -match 'elseif rpcId == RPC_HIDE_MENU[\s\S]{0,200}return true') {
    Ok 'SP menu RPC SHOW/HIDE pass-through'
} else {
    Fail 'SP menu RPC handler missing shouldBlockServerSamMenu + max priority'
}

# 5) manifest late includes sync
$manifest = Get-Content (Join-Path $root 'config\report_desk_bundle_manifest.lua') -Raw -Encoding Default
if ($manifest -notmatch 'report_desk_checker_sync\.lua') { Fail 'manifest late missing checker_sync' }
else { Ok 'manifest checker_sync' }
if ($manifest -match "late\s*=\s*\{[^}]*'report_desk_checker\.lua'[^}]*'report_desk_checker_sync\.lua'") {
    Ok 'manifest late order checker before sync'
} else { Fail 'manifest late: checker.lua must load before checker_sync (local forward-ref)' }
if ($manifest -match "late\s*=\s*\{[^}]*'report_desk_checker_sync\.lua'[^}]*'report_desk_checker_hud\.lua'") {
    Ok 'manifest late order sync before hud'
} else { Fail 'manifest late: checker_sync must load before checker_hud' }
if ($sync -match '(?m)^local function ensureSyncSession') { Fail 'checker_sync ensureSyncSession must be global (checker.lua calls it)' }
else { Ok 'checker_sync ensureSyncSession global' }
if ($sync -match '(?m)^local function sortAdminsOnline') { Fail 'checker_sync sortAdminsOnline must be global (checker.lua calls it)' }
else { Ok 'checker_sync sortAdminsOnline global' }

# 6) checker sync critical exports
foreach ($fn in @('checkerOnShowDialog', 'checkerIsAdmsSyncWindow', 'checkerSanitizeSyncSession', 'flushCheckerCatalogNow')) {
    if ($sync -notmatch "function $fn") { Fail "checker_sync.lua missing $fn" }
    else { Ok "checker_sync $fn" }
}

# 7) checker init sync session key (Lua forward-ref: nil key -> table index is nil)
$chkInit = Get-Content (Join-Path $lib 'report_desk_checker.lua') -Raw -Encoding Default
if ($chkInit -match 'rawset\(_G,\s*SYNC_SESSION_KEY') { Fail 'checkerInit must not use SYNC_SESSION_KEY global (use CHECKER_SYNC_SESSION_KEY literal)' }
elseif ($chkInit -match 'CHECKER_SYNC_SESSION_KEY\s*=\s*''__desk_checkerSyncSession''' -and $chkInit -match 'rawset\(_G,\s*CHECKER_SYNC_SESSION_KEY') {
    Ok 'checkerInit sync session key'
} else { Fail 'checkerInit missing CHECKER_SYNC_SESSION_KEY' }

# 8) skins tex release + catalog tick in ImGui frame
$skins = Get-Content (Join-Path $lib 'report_desk_skins.lua') -Raw -Encoding Default
if ($skins -match '(?m)^local function skinTexRelease') { Fail 'skinTexRelease must be global (initDeskCatalogWarmup registerNs)' }
elseif ($skins -match '(?m)^function skinTexRelease') { Ok 'skins skinTexRelease global' }
else { Fail 'skins missing skinTexRelease' }
$ui = Get-Content (Join-Path $lib 'report_desk_ui.lua') -Raw -Encoding Default
if ($ui -notmatch 'deskCatalogTabActive\(\)' -or $ui -notmatch 'pcall\(deskCatalogTexTick\)') {
    Fail 'ui.lua must run deskCatalogTexTick from OnFrame when catalog tab active'
} else { Ok 'ui catalog tex OnFrame tick' }

# 9) cheats chunk order + marker bind helper
$cheats = Get-Content (Join-Path $lib 'report_desk_cheats.lua') -Raw -Encoding Default
$marker = Get-Content (Join-Path $lib 'report_desk_cheats_marker.lua') -Raw -Encoding Default
if ($manifest -match "core_a_a\s*=\s*\{[^}]*'report_desk_cheats\.lua'[^}]*'report_desk_cheats_marker\.lua'") {
    Ok 'manifest core_a cheats before cheats_marker'
} else { Fail 'manifest: report_desk_cheats.lua must load before cheats_marker' }
if ($cheats -match '(?m)^local function markerFixedBindHit') { Fail 'markerFixedBindHit must be global (cheats_marker calls it)' }
else { Ok 'cheats markerFixedBindHit global' }
if ($marker -notmatch 'markerFixedBindHit\(MARKER_BIND_TP\)') { Fail 'cheats_marker missing LMB TP bind' }
else { Ok 'cheats_marker LMB TP bind' }

# 9) encoding helpers not lost after util_encoding split
$util = Get-Content (Join-Path $lib 'report_desk_util.lua') -Raw -Encoding Default
foreach ($fn in @('normalizeStoredText', 'repairStoredConfigText', 'configStoreText')) {
    if ($util -notmatch "function $fn") { Fail "util.lua missing $fn (encoding split regression)" }
    else { Ok "util $fn" }
}
$enc = Get-Content (Join-Path $lib 'report_desk_util_encoding.lua') -Raw -Encoding Default
if ($enc -notmatch 'function ensureWireCp1251') { Fail 'util_encoding.lua missing ensureWireCp1251' }
else { Ok 'util_encoding ensureWireCp1251' }

# 11) chat dedup prune covers deferred + remoteChatDedup
$dedup = Get-Content (Join-Path $lib 'report_desk_chat_dedup.lua') -Raw -Encoding Default
if ($dedup -notmatch 'function pruneChatSeenDeferred') { Fail 'chat_dedup.lua missing pruneChatSeenDeferred' }
else { Ok 'chat_dedup pruneChatSeenDeferred' }
$gameState = Get-Content (Join-Path $lib 'report_desk_game_state.lua') -Raw -Encoding Default
if ($gameState -notmatch 'function deskAutoReplyAllowed' -or $gameState -notmatch 'local function deskPauseBlocksAutoReply') {
    Fail 'game_state.lua must own pause gate (deskPauseBlocksAutoReply)'
} else { Ok 'game_state pause gate self-contained' }
if ($util -match 'deskPauseBlocksAutoReply|deskAdminPauseTracked') {
    Fail 'util.lua must not define pause state (moved to game_state)'
} else { Ok 'util no pause leak' }
if ($util -notmatch 'remoteChatDedup') { Fail 'pruneAllTimedMaps missing remoteChatDedup prune' }
else { Ok 'util remoteChatDedup prune' }
if ($util -notmatch 'intentResolveOrder = \{\}') { Fail 'intentResolve prune must clear intentResolveOrder' }
else { Ok 'util intentResolveOrder prune' }

# 11) hooks health-check guards
if ($hooks -notmatch 'checkerRpcProbeRegistered') { Fail 'hooks_sp_menu missing checker RPC probe guard' }
else { Ok 'hooks checkerRpcProbe guard' }
if ($hooks -notmatch 'function deskAreSpMenuHooksActive') { Fail 'hooks_sp_menu missing deskAreSpMenuHooksActive' }
else { Ok 'hooks deskAreSpMenuHooksActive' }

# 13) /st dialog: parse in onShowDialog, close once (no blind watchdog)
$stats = Get-Content (Join-Path $lib 'report_desk_sp_stats_ctx.lua') -Raw -Encoding Default
if ($stats -match 'tickStatsDialogWatchdog') { Fail 'spectate_stats: no tickStatsDialogWatchdog' }
else { Ok 'spectate_stats no dialog watchdog' }
if ($stats -match 'closeStatsDialogOnce\(nil') { Fail 'spectate_stats: no blind dialog close' }
else { Ok 'spectate_stats no blind dialog close' }
if ($stats -notmatch 'function closeStatsDialog') { Fail 'spectate_stats missing closeStatsDialog' }
else { Ok 'spectate_stats closeStatsDialog' }
if ($stats -match 'buildStepConnectedCache') { Fail 'spectate_stats: use buildNearbySpectateList (not slot-ID step)' }
else { Ok 'spectate_stats nearby step list' }
if ($stats -notmatch 'function M\.getNearbySpectateList' -or $stats -notmatch 'scanNearbyPlayersSphere') {
    Fail 'spectate_stats missing nearby spectate distance step'
} else { Ok 'spectate_stats nearby distance step' }
if ($stats -notmatch 'drawNearbySpectateRows' -or $stats -notmatch 'nearbyHudEnabled') { Fail 'spectate_stats missing nearby HUD rows' }
else { Ok 'spectate_stats nearby HUD rows' }
if ($stats -notmatch 'spectate_nearby_hud') { Fail 'spectate_stats missing spectate_nearby_hud gate' }
else { Ok 'spectate_stats nearby hud setting' }
if ($stats -notmatch 'nearbyStepAnchorId' -or $stats -notmatch 'getNearbyStepAnchorId') {
    Fail 'spectate_stats missing stable nearby step anchor'
} else { Ok 'spectate_stats stable nearby anchor' }
if ($stats -notmatch 'nearbyStepTrail' -or $stats -notmatch 'resolveNearbyStepTarget') {
    Fail 'spectate_stats missing arrow visit trail'
} else { Ok 'spectate_stats arrow visit trail' }
if ($stats -match 'findAdjacentSpectateId[\s\S]{0,400}buildNearbySpectateList\(curId\)') {
    Fail 'spectate_stats: findAdjacent must not anchor list on curId'
} else { Ok 'spectate_stats nearby list not curId-anchored' }
if ($stats -notmatch 'findAllRandomCharsInSphere' -or $stats -match 'stepNearbyScanJob') {
    Fail 'spectate_stats must use sphere scan, not slot scan job'
} else { Ok 'spectate_stats sphere nearby scan' }
if ($stats -match 'for i = 0, maxId do[\s\S]{0,500}buildNearbySpectateList') {
    Fail 'spectate_stats nearby must not full-scan slots in buildNearby'
} else { Ok 'spectate_stats no slot scan in nearby build' }
if ($stats -notmatch 'NEARBY_SPEC_MAX_RING') { Fail 'spectate_stats missing nearby ring cap' }
else { Ok 'spectate_stats nearby ring cap' }

# 14) checker sync dialog: parse in onShowDialog, close with dialogId (no blind close)
$chkSync = Get-Content (Join-Path $lib 'report_desk_checker_sync.lua') -Raw -Encoding Default
if ($chkSync -match 'checkerDeferCloseVisibleDialog|checkerCloseVisibleDialog') { Fail 'checker_sync: use checkerCloseSyncDialog' }
else { Ok 'checker_sync no legacy dialog close' }
if ($chkSync -match 'DeferCloseVisibleDialog\(nil') { Fail 'checker_sync: no blind dialog close' }
else { Ok 'checker_sync no blind dialog close' }
if ($chkSync -notmatch 'function checkerCloseSyncDialog') { Fail 'checker_sync missing checkerCloseSyncDialog' }
else { Ok 'checker_sync checkerCloseSyncDialog' }
if ($chkSync -match 'syncCloseDialogId') { Fail 'checker_sync: no syncCloseDialogId tracking' }
else { Ok 'checker_sync no syncCloseDialogId' }

# 15) report ingest hot-path: seed before hooks, live srv ingest, no startup chatSeen reset
$main = Get-Content (Join-Path $lib 'report_desk_main.lua') -Raw -Encoding Default
$hooksMain = Get-Content (Join-Path $lib 'report_desk_hooks.lua') -Raw -Encoding Default
if ($hooksMain -match 'function spRefreshTargetMatches|function installDeskSpRefreshHooks') {
    Fail 'hooks.lua must not duplicate sp refresh (use hooks_sp_refresh.lua)'
} else { Ok 'hooks no sp refresh duplicate' }
$hooksIngest = Get-Content (Join-Path $lib 'report_desk_hooks_ingest.lua') -Raw -Encoding Default
$hooksCombined = $hooksMain + "`n" + $hooksIngest
if ($main -notmatch 'seedSeenChatLines' -or $main -notmatch 'installDeskServerMessageHook') {
    Fail 'main.lua missing seedSeenChatLines before server hook'
} elseif ($main -match 'seedSeenChatLines[\s\S]{0,400}installDeskServerMessageHook') {
    Ok 'main seedSeenChatLines before server hook'
} else { Fail 'main.lua: call seedSeenChatLines before installDeskServerMessageHook' }
if ($main -match 'chatSeen\.lines\s*=\s*\{\}') { Fail 'main.lua: do not reset chatSeen.lines on startup thread' }
else { Ok 'main no startup chatSeen reset' }
if ($hooksCombined -notmatch 'adminPunishOnServerMessage') { Fail 'hooks missing adminPunishOnServerMessage' }
elseif ($hooksCombined -match 'adminPunishOnServerMessage[\s\S]{0,2500}processChatLineIngest') {
    Ok 'hooks adminPunish before report ingest'
} else { Fail 'hooks: adminPunish must run before processChatLineIngest' }
if ($hooksCombined -notmatch "processChatLineIngest\(plain, color, 'srv', true") { Fail 'hooks missing live srv ingest' }
else { Ok 'hooks live srv ingest isLive=true' }
$actions = Get-Content (Join-Path $lib 'report_desk_actions.lua') -Raw -Encoding Default
if ($actions -notmatch 'function quickScenarioButtonCaption') { Fail 'actions missing quickScenarioButtonCaption (reply on scenario btn)' }
elseif ($actions -match 'quickScenarioDisplayLabel\(sc\.label') { Fail 'scenario buttons still use label as caption' }
else { Ok 'scenario buttons show reply text' }

if ($hooksMain -match 'function installDeskSendChatHook[\s\S]*noteManualStatsCommand[\s\S]*local function noteManualStatsCommand') {
    Fail 'hooks: noteManualStatsCommand must be declared before installDeskSendChatHook'
} else { Ok 'hooks noteManualStatsCommand before send chat hook' }

$fwdAudit = & python (Join-Path $PSScriptRoot 'audit_lua_forward_refs.py') 2>&1
if ($LASTEXITCODE -ne 0) {
    Fail "Lua forward-ref audit failed:`n$fwdAudit"
} else { Ok 'Lua forward-ref audit clean' }

# 16) admin punish: hook-first, poll only fallback, claim line key
$ap = Get-Content (Join-Path $lib 'report_desk_admin_punish.lua') -Raw -Encoding Default
if ($ap -notmatch 'function adminPunishIngestChatLine') { Fail 'admin_punish missing adminPunishIngestChatLine' }
else { Ok 'admin_punish ingest entry' }
if ($ap -notmatch 'apClaimLineKey' -or $ap -notmatch 'apMarkLineConsumed') { Fail 'admin_punish missing line claim/consume' }
else { Ok 'admin_punish line dedup' }
if ($ap -notmatch 'adminPunishHooksActive\(\) then return') { Fail 'admin_punish poll must skip when hooks active' }
else { Ok 'admin_punish poll fallback only' }
if ($ap -notmatch 'adminPunishOnChatMessage') { Fail 'admin_punish missing onChatMessage path' }
else { Ok 'admin_punish onChatMessage path' }

# 17) no UTF-8 BOM in bundle modules (breaks dev loadstring concat)
$manifestText = Get-Content (Join-Path $root 'config\report_desk_bundle_manifest.lua') -Raw -Encoding Default
$modNames = [regex]::Matches($manifestText, "'(report_desk_[^']+\.lua)'") | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
foreach ($mod in $modNames) {
    $mp = Join-Path $lib $mod
    if (-not (Test-Path $mp)) { continue }
    $bytes = [IO.File]::ReadAllBytes($mp)
    if ($bytes.Length -ge 3 -and $bytes[0] -eq 239 -and $bytes[1] -eq 187 -and $bytes[2] -eq 191) {
        Fail "UTF-8 BOM in $mod (strip before commit)"
    }
}
if ($fail -eq 0) { Ok 'no UTF-8 BOM in manifest modules' }

# 18) refactor: OnlinePlayers SSOT, no HUD heal, hook registry, wireSeenKey
$online = Get-Content (Join-Path $lib 'report_desk_online_players.lua') -Raw -Encoding Default
if ($online -notmatch 'function onlinePlayersRescan' -or $online -notmatch 'function onlinePlayersOnJoin') {
    Fail 'online_players.lua missing SSOT API'
} else { Ok 'online_players SSOT API' }
if ($manifest -notmatch 'report_desk_online_players\.lua') { Fail 'manifest missing online_players' }
else { Ok 'manifest online_players' }
if ($chk -match 'function checkerBuildNickIndex' -or $chk -match 'onlineNickIndex') {
    Fail 'checker.lua must not use onlineNickIndex / checkerBuildNickIndex'
} else { Ok 'checker no duplicate nick index' }
$chkHud = Get-Content (Join-Path $lib 'report_desk_checker_hud.lua') -Raw -Encoding Default
if ($chkHud -match 'hudHealRebuild|checkerRebuildOnline, true\)') {
    Fail 'checker_hud must not heal-rebuild from draw path'
} else { Ok 'checker_hud no heal rebuild' }
$hookReg = Get-Content (Join-Path $lib 'report_desk_hook_registry.lua') -Raw -Encoding Default
if ($hookReg -notmatch 'function HookRegistry\.ensureAll') { Fail 'hook_registry missing ensureAll' }
else { Ok 'hook_registry ensureAll' }
if ($manifest -notmatch 'report_desk_hook_registry\.lua') { Fail 'manifest missing hook_registry' }
else { Ok 'manifest hook_registry' }
if ($dedup -notmatch 'function wireSeenKey') { Fail 'chat_dedup missing wireSeenKey' }
else { Ok 'chat_dedup wireSeenKey' }
if ($hooksIngest -match 'ingestReconcileAt') { Fail 'hooks_ingest must not use ingestReconcileAt' }
else { Ok 'hooks_ingest no reconcile accelerator' }
if ($main -match 'refreshPlayerNickCache\(false\)') { Fail 'main must not poll refreshPlayerNickCache' }
else { Ok 'main no nick cache polling' }

# 19) post-refactor audit fixes
if ($actions -match 'playerNickToId\[nickKey') { Fail 'findPlayerIdByNick must not use stale playerNickToId fallback' }
else { Ok 'findPlayerIdByNick SSOT only' }
if ($ui -notmatch 'findPlayerIdByNick\(t\.nick\)') { Fail 'ui thread list must use findPlayerIdByNick for live id' }
else { Ok 'ui thread liveId via SSOT' }
$chkSync = Get-Content (Join-Path $lib 'report_desk_checker_sync.lua') -Raw -Encoding Default
if ($chkSync -notmatch 'function checkerMarkCatalogDirty[\s\S]{0,200}checkerScheduleRebuild') {
    Fail 'checkerMarkCatalogDirty must schedule online rebuild'
} else { Ok 'checkerMarkCatalogDirty schedules rebuild' }
if ($chk -notmatch 'onlinePlayersOnJoin') { Fail 'checkerOnPlayerStreamIn must update OnlinePlayers' }
else { Ok 'checker stream-in updates OnlinePlayers' }
if ($hooksIngest -notmatch 'wirePlain\(text\)') { Fail 'hooks_ingest hot path must use wirePlain' }
else { Ok 'hooks_ingest wirePlain boundary' }
$hooksSpMenu = Get-Content (Join-Path $lib 'report_desk_hooks_sp_menu.lua') -Raw -Encoding Default
if ($hooksSpMenu -notmatch 'onPlayerChatBubble == deskCache\.profBubbleHandler') {
    Fail 'profanity registry must check bubble handler'
} else { Ok 'profanity registry bubble check' }
if ($hooks -match 'hookPrev\w+ == nil then deskCache\.hookPrev') {
    Fail 'hooks.lua must refresh hookPrev on reinstall (no nil guard)'
} else { Ok 'hooks hookPrev refresh' }
if ($main -notmatch 'onSpectatingOff[\s\S]{0,120}deskInputPolicyApply') {
    Fail 'spectate off must call deskInputPolicyApply'
} else { Ok 'spectate off input policy' }

# 20) final audit fixes
$chat = Get-Content (Join-Path $lib 'report_desk_chat.lua') -Raw -Encoding Default
$keysHud = Get-Content (Join-Path $lib 'report_desk_sp_keys_hud.lua') -Raw -Encoding Default
$spStats = Get-Content (Join-Path $lib 'report_desk_sp_stats_ctx.lua') -Raw -Encoding Default
if ($hooksMain -notmatch 'onSetVehicleParams == deskCache\.spVehParamsPlayerHandler') {
    Fail 'deskUninstall must restore onSetVehicleParams'
} else { Ok 'deskUninstall onSetVehicleParams restore' }
if ($chat -notmatch 'prevBubble == deskCache\.profBubbleHandler then prevBubble = deskCache\.hookPrevProfBubble') {
    Fail 'profanity install must use hookPrevProfBubble fallback'
} else { Ok 'profanity hookPrev bubble fallback' }
if ($chat -notmatch 'prevChat == deskCache\.profChatHandler then prevChat = deskCache\.hookPrevProfChat') {
    Fail 'profanity install must use hookPrevProfChat fallback'
} else { Ok 'profanity hookPrev chat fallback' }
if ($keysHud -notmatch 'function M\.uninstallSampev') { Fail 'keysHud must expose uninstallSampev' }
else { Ok 'keysHud uninstallSampev' }
if ($spStats -notmatch 'keysHud\.uninstallSampev') { Fail 'spectate uninstall must call keysHud.uninstallSampev' }
else { Ok 'spectate keysHud uninstall wired' }
if ($chkHud -notmatch 'checkerHudWantsInput[\s\S]{0,120}checkerHudVisible') {
    Fail 'checkerHudWantsInput must guard checkerHudVisible'
} else { Ok 'checkerHudWantsInput visibility guard' }
if ($ui -notmatch 'chatHeaderResolvePlayer[\s\S]{0,400}markDirtyThreads') {
    Fail 'chatHeaderResolvePlayer must markDirtyThreads on id change'
} else { Ok 'chatHeaderResolvePlayer markDirtyThreads' }
if ($chk -notmatch 's\.onlineIndex = type\(s\.onlineIndex\)') {
    Fail 'checkerState must init onlineIndex table'
} else { Ok 'checkerState onlineIndex init' }
$specSession = Get-Content (Join-Path $lib 'report_desk_spectate_session.lua') -Raw -Encoding Default
if ($specSession -match 'suppressSpMenuActive|vehicleHudPipelineActive|isServerSpMenuTextDrawOnly') {
    Fail 'spectate_session must not use stale TD block helpers'
} else { Ok 'spectate_session TD router delegation' }
if ($specSession -notmatch 'return tdRouter\.onShowTextDraw') {
    Fail 'spectate_session onShowTextDraw must delegate to tdRouter'
} else { Ok 'spectate_session onShowTextDraw delegate' }
if ($spStats -notmatch 'ctx\.specSession = specSession') {
    Fail 'sp_stats_ctx must export ctx.specSession for pending handshake'
} else { Ok 'sp_stats_ctx ctx.specSession export' }
if ($spStats -notmatch 'ctx\.spUi = spUi') { Fail 'sp_stats_ctx must export ctx.spUi' }
else { Ok 'sp_stats_ctx ctx.spUi export' }

# intent: no stale interview fallback in core state
$state = Get-Content (Join-Path $lib 'report_desk_state.lua') -Raw -Encoding Default
if ($state -match 'reply\s*=\s*''[^'']*/help[^'']*F1') {
    Fail 'report_desk_state.lua must not embed obsolete /help+F1 interview reply'
} else { Ok 'state no obsolete interview fallback' }
$intentsCfg = Get-Content (Join-Path $root 'config\report_desk_intents.lua') -Raw -Encoding UTF8
if ($intentsCfg -notmatch 'id = "faq\.gameplay\.join_news"' -or $intentsCfg -notmatch 'stem\s*=\s*true') {
    Fail 'report_desk_intents.lua join_news must have stem=true'
} else { Ok 'join_news stem enabled' }

Write-Host ''
if ($fail -eq 0) { Write-Host 'Sanity verify: OK' -ForegroundColor Green; exit 0 }
else { Write-Host "Sanity verify: $fail issue(s)" -ForegroundColor Red; exit 1 }
