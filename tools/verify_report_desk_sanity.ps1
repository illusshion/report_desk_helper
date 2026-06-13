# Post-refactor sanity checks (no MoonLoader runtime required).
$ErrorActionPreference = 'Stop'
$root = Split-Path $PSScriptRoot -Parent
$lib = Join-Path $root 'lib'
$fail = 0

function Fail($msg) { Write-Host "FAIL: $msg" -ForegroundColor Red; $script:fail++ }
function Ok($msg) { Write-Host "OK: $msg" -ForegroundColor Green }

# 2) spectate_stats required API
$stats = Get-Content (Join-Path $lib 'report_desk_spectate_stats.lua') -Raw -Encoding Default
foreach ($fn in @('requestStats', 'onServerMessage', 'parseSpServerLine', 'onShowDialog', 'parseDialogText')) {
    if ($stats -notmatch "function M\.$fn") { Fail "spectate_stats.lua missing M.$fn" }
    else { Ok "spectate_stats M.$fn" }
}
if ($stats -match 'local function getStatsDialogApi' -or $stats -match 'function M\.parseDialogText') {
    Ok 'spectate_stats dialog API wiring'
} else { Fail 'spectate_stats.lua missing dialog parse API' }
if ($stats -match "text == ' then") { Fail 'spectate_stats.lua corrupted empty-string check (line ~1117)' }
else { Ok 'spectate_stats empty-string guard' }
$luaExe = 'C:\Program Files (x86)\Lua\5.1\lua.exe'
if (Test-Path $luaExe) {
    $statsPath = (Join-Path $lib 'report_desk_spectate_stats.lua') -replace '\\', '/'
    $luaOut = & $luaExe -e "local f=io.open('$statsPath','rb'); local s=f:read('*a'); f:close(); local fn,err=loadstring(s,'@spectate_stats'); if not fn then print(err) os.exit(1) end; print('OK')" 2>&1
    if ($LASTEXITCODE -ne 0 -or "$luaOut" -notmatch 'OK') { Fail "spectate_stats.lua Lua syntax: $luaOut" }
    else { Ok 'spectate_stats.lua Lua syntax' }
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

# 11) util prune covers deferred + remoteChatDedup
if ($util -notmatch 'function pruneChatSeenDeferred') { Fail 'util.lua missing pruneChatSeenDeferred' }
else { Ok 'util pruneChatSeenDeferred' }
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
$stats = Get-Content (Join-Path $lib 'report_desk_spectate_stats.lua') -Raw -Encoding Default
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
if ($main -notmatch 'seedSeenChatLines' -or $main -notmatch 'installDeskServerMessageHook') {
    Fail 'main.lua missing seedSeenChatLines before server hook'
} elseif ($main -match 'seedSeenChatLines[\s\S]{0,400}installDeskServerMessageHook') {
    Ok 'main seedSeenChatLines before server hook'
} else { Fail 'main.lua: call seedSeenChatLines before installDeskServerMessageHook' }
if ($main -match 'chatSeen\.lines\s*=\s*\{\}') { Fail 'main.lua: do not reset chatSeen.lines on startup thread' }
else { Ok 'main no startup chatSeen reset' }
if ($hooksMain -notmatch 'adminPunishOnServerMessage') { Fail 'hooks missing adminPunishOnServerMessage' }
elseif ($hooksMain -match 'adminPunishOnServerMessage[\s\S]{0,2500}processChatLineIngest') {
    Ok 'hooks adminPunish before report ingest'
} else { Fail 'hooks: adminPunish must run before processChatLineIngest' }
if ($hooksMain -notmatch "processChatLineIngest\(plain, color, 'srv', true") { Fail 'hooks missing live srv ingest' }
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

Write-Host ''
if ($fail -eq 0) { Write-Host 'Sanity verify: OK' -ForegroundColor Green; exit 0 }
else { Write-Host "Sanity verify: $fail issue(s)" -ForegroundColor Red; exit 1 }
