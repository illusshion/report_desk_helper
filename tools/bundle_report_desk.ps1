# Сборка одного admin_report_desk_core.lua / .luac из модулей Report Desk.

param(

    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),

    [switch]$SkipLuac

)



$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_lib.ps1')

$Utf8NoBom = New-Object System.Text.UTF8Encoding $false



function Get-LuaLongBracket($content) {

    $level = 0

    while ($true) {

        $open = '[' + ('=' * $level) + '['

        $close = ']' + ('=' * $level) + ']'

        if ($content -notmatch [regex]::Escape($close)) {

            return $open, $close

        }

        $level++

        if ($level -gt 32) { throw 'Cannot find safe long bracket for Lua string' }

    }

}



function Read-ModuleText($path) {

    if (-not (Test-Path $path)) { throw "Missing: $path" }

    $text = [System.IO.File]::ReadAllText($path, $Utf8NoBom)
    if ($path -like '*\samp\*' -or $path -like '*\samp\events.lua') {
        $text = $text.Replace("require 'sampfuncs'", "require 'lib.sampfuncs'")
    }
    return $text

}



function Wrap-PreloadModule($name, $content) {

    $open, $close = Get-LuaLongBracket $content

    return @"

package.preload['$name'] = function()

    local fn, err = loadstring($open

$content

$close, '@$name')

    if not fn then error(err or 'bundle load failed: $name') end

    return fn()

end



"@

}



function Wrap-AppChunk($name, $content) {

    $open, $close = Get-LuaLongBracket $content

    $chunkTag = '@' + $name

    return @"

do

    local chunkFn, chunkErr = loadstring($open

$content

$close, '$chunkTag')

    if not chunkFn then error('[Report Desk] bundle chunk ${name}: ' .. tostring(chunkErr)) end

    setfenv(chunkFn, __desk_bundle_env)

    chunkFn()

end



"@

}



function Wrap-AppChunkSafe($name, $content, $failLabel) {

    $open, $close = Get-LuaLongBracket $content

    $chunkTag = '@' + $name

    if (-not $failLabel) { $failLabel = 'module disabled' }

    return @"

do

    local okChunk, errChunk = pcall(function()

        local chunkFn, chunkErr = loadstring($open

$content

$close, '$chunkTag')

        if not chunkFn then error('[Report Desk] bundle chunk ${name}: ' .. tostring(chunkErr)) end

        setfenv(chunkFn, __desk_bundle_env)

        chunkFn()

    end)

    if not okChunk then

        print('[Report Desk] ${failLabel}: ' .. tostring(errChunk))

    end

end



"@

}



function Wrap-AppChunkGroup($label, $parts) {

    $combined = ($parts -join "`n") + "`n"

    $open, $close = Get-LuaLongBracket $combined

    $chunkTag = '@' + $label

    return @"

do

    local chunkFn, chunkErr = loadstring($open

$combined

$close, '$chunkTag')

    if not chunkFn then error('[Report Desk] bundle group ${label}: ' .. tostring(chunkErr)) end

    setfenv(chunkFn, __desk_bundle_env)

    chunkFn()

end



"@

}



$libDir = Join-Path $MoonloaderRoot 'lib'

$libModules = @(

    @{ Name = 'report_desk_catalog_grid'; File = 'report_desk_catalog_grid.lua' },

    @{ Name = 'report_desk_tex_loader'; File = 'report_desk_tex_loader.lua' },

    @{ Name = 'report_desk_texcache'; File = 'report_desk_texcache.lua' },

    @{ Name = 'report_desk_tex_pipeline'; File = 'report_desk_tex_pipeline.lua' },

    @{ Name = 'report_desk_ingest'; File = 'report_desk_ingest.lua' },

    @{ Name = 'report_desk_sp_theme'; File = 'report_desk_sp_theme.lua' },
    @{ Name = 'report_desk_sp_vehicle_hud'; File = 'report_desk_sp_vehicle_hud.lua' },
    @{ Name = 'report_desk_sp_keys_hud'; File = 'report_desk_sp_keys_hud.lua' },
    @{ Name = 'report_desk_spectate_camera'; File = 'report_desk_spectate_camera.lua' },
    @{ Name = 'report_desk_spectate_session'; File = 'report_desk_spectate_session.lua' },
    @{ Name = 'report_desk_spectate_menu'; File = 'report_desk_spectate_menu.lua' },
    @{ Name = 'report_desk_sp_ui'; File = 'report_desk_sp_ui.lua' },
    @{ Name = 'report_desk_sp_refresh'; File = 'report_desk_sp_refresh.lua' },
    @{ Name = 'report_desk_spectate_stats'; File = 'report_desk_spectate_stats.lua' },
    @{ Name = 'report_desk_checker_parser'; File = 'report_desk_checker_parser.lua' },
    @{ Name = 'report_desk_checker_catalog'; File = 'report_desk_checker_catalog.lua' },
    @{ Name = 'report_desk_wm_dispatch'; File = 'report_desk_wm_dispatch.lua' },
    @{ Name = 'report_desk_spectate_fsm'; File = 'report_desk_spectate_fsm.lua' },

    @{ Name = 'report_desk_vehicles'; File = 'report_desk_vehicles.lua' },

    @{ Name = 'report_desk_profanity_words'; File = 'report_desk_profanity_words.lua' },

    @{ Name = 'lib.samp.events'; File = 'samp\events.lua' },
    @{ Name = 'samp.raknet'; File = 'samp\raknet.lua' },
    @{ Name = 'samp.synchronization'; File = 'samp\synchronization.lua' },
    @{ Name = 'samp.events.bitstream_io'; File = 'samp\events\bitstream_io.lua' },
    @{ Name = 'samp.events.core'; File = 'samp\events\core.lua' },
    @{ Name = 'samp.events.extra_types'; File = 'samp\events\extra_types.lua' },
    @{ Name = 'samp.events.handlers'; File = 'samp\events\handlers.lua' },
    @{ Name = 'samp.events.utils'; File = 'samp\events\utils.lua' },
    @{ Name = 'lib.vkeys'; File = 'vkeys.lua' },
    @{ Name = 'encoding'; File = 'encoding.lua' },
    @{ Name = 'lib.vector3d'; File = 'vector3d.lua' },
    @{ Name = 'vector3d'; File = 'vector3d.lua' }

)



$appChunks = @(

    'report_desk_bootstrap.lua',

    'report_desk_constants.lua',

    'report_desk_theme.lua',

    'report_desk_state.lua',

    'report_desk_util.lua',

    'report_desk_profanity.lua',

    'report_desk_chat.lua',

    'report_desk_cheats.lua',

    'report_desk_skins.lua',

    'report_desk_input.lua',

    'report_desk_actions.lua',

    'report_desk_threads.lua',

    'report_desk_config.lua',

    'report_desk_ingest_runtime.lua',

    'report_desk_rules.lua',

    'report_desk_ui.lua',

    'report_desk_env_export.lua',

    'report_desk_main.lua'

)

$appChunksHooks = @(
    'report_desk_hooks.lua'
)

$allBundleInputs = @(
    'report_desk_catalog_grid.lua',
    'report_desk_tex_loader.lua',
    'report_desk_texcache.lua',
    'report_desk_tex_pipeline.lua',
    'report_desk_ingest.lua',
    'report_desk_sp_theme.lua',
    'report_desk_sp_vehicle_hud.lua',
    'report_desk_sp_keys_hud.lua',
    'report_desk_spectate_camera.lua',
    'report_desk_spectate_session.lua',
    'report_desk_spectate_menu.lua',
    'report_desk_sp_ui.lua',
    'report_desk_sp_refresh.lua',
    'report_desk_spectate_stats.lua',
    'report_desk_checker_parser.lua',
    'report_desk_checker_catalog.lua',
    'report_desk_wm_dispatch.lua',
    'report_desk_spectate_fsm.lua',
    'report_desk_vehicles.lua',
    'report_desk_profanity_words.lua',
    'report_desk_remote_chat.lua',
    'report_desk_checker.lua',
    'report_desk_cmd_binds.lua'
) + $appChunks
foreach ($rel in $allBundleInputs) {
    $p = Join-Path $libDir $rel
    if (-not (Test-Path $p)) { throw "Bundle input missing: $p" }
    $len = (Get-Item $p).Length
    if ($len -lt 8) { throw "Bundle input empty or too small ($len bytes): $p" }
}
Write-Host "Bundle inputs OK ($($allBundleInputs.Count) files)"



$distDir = Join-Path $MoonloaderRoot 'dist'

$reportDeskDir = Join-Path $distDir 'report_desk'

New-Item -ItemType Directory -Force -Path $reportDeskDir | Out-Null



$header = @'

--[[ Admin Report Desk — bundled core (do not edit; rebuild with tools\bundle_report_desk.ps1) ]]

-- @bundled true

_G.__REPORT_DESK_BUNDLE_ACTIVE = true

local __desk_bundle_env = setmetatable({}, { __index = _G })



'@



$footer = @'

function main()

    if type(__desk_bundle_env.main) == 'function' then

        return __desk_bundle_env.main()

    end

end



function onScriptTerminate(scr)

    if scr == thisScript() and type(__desk_bundle_env.onScriptTerminate) == 'function' then

        return __desk_bundle_env.onScriptTerminate(scr)

    end

end



'@



$sb = New-Object System.Text.StringBuilder

[void]$sb.Append($header)



foreach ($m in $libModules) {

    $path = Join-Path $libDir $m.File

    $text = Read-ModuleText $path

    [void]$sb.Append((Wrap-PreloadModule $m.Name $text))

}



[void]$sb.Append("`n")

$appParts = New-Object System.Collections.Generic.List[string]
foreach ($chunk in $appChunks) {
    $path = Join-Path $libDir $chunk
    [void]$appParts.Add((Read-ModuleText $path))
}
[void]$sb.Append((Wrap-AppChunkGroup 'report_desk_app_core' $appParts.ToArray()))

$hooksParts = New-Object System.Collections.Generic.List[string]
foreach ($chunk in $appChunksHooks) {
    $path = Join-Path $libDir $chunk
    [void]$hooksParts.Add((Read-ModuleText $path))
}
[void]$sb.Append((Wrap-AppChunkGroup 'report_desk_app_hooks' $hooksParts.ToArray()))

$remoteChatPath = Join-Path $libDir 'report_desk_remote_chat.lua'
$remoteChatText = Read-ModuleText $remoteChatPath
[void]$sb.Append((Wrap-AppChunkSafe 'report_desk_remote_chat.lua' $remoteChatText 'remote chat disabled'))

$checkerPath = Join-Path $libDir 'report_desk_checker.lua'
$checkerText = Read-ModuleText $checkerPath
[void]$sb.Append((Wrap-AppChunkSafe 'report_desk_checker.lua' $checkerText 'checker disabled'))

$cmdBindsPath = Join-Path $libDir 'report_desk_cmd_binds.lua'
$cmdBindsText = Read-ModuleText $cmdBindsPath
[void]$sb.Append((Wrap-AppChunkSafe 'report_desk_cmd_binds.lua' $cmdBindsText 'cmd binds disabled'))

$userDefaultPath = Join-Path $MoonloaderRoot 'config\admin_report_desk_user.default.lua'
$userDefaultText = Read-ModuleText $userDefaultPath
[void]$sb.Append((Wrap-PreloadModule 'report_desk_user_defaults' $userDefaultText))

[void]$sb.Append($footer)



$coreLua = Join-Path $reportDeskDir 'AdminDeskCore.lua'
$legacyCoreLua = Join-Path $reportDeskDir 'admin_report_desk_core.lua'

[System.IO.File]::WriteAllText($coreLua, $sb.ToString(), $Utf8NoBom)

Write-Host "Wrote $coreLua ($(([System.IO.FileInfo]$coreLua).Length) bytes)"

$coreText = [System.IO.File]::ReadAllText($coreLua, $Utf8NoBom)
$mustHave = @(
    'expectSpectateOff',
    'isAwaitingSpectate',
    'function remoteChatFlushSampQueue',
    'report_desk_spectate_camera',
    'report_desk_sp_keys_hud',
    'report_desk_sp_refresh',
    "package.preload['report_desk_user_defaults'] = function",
    'migrateScenariosPackIfNeeded',
    'SCENARIOS_PACK_VERSION',
    "package.preload['lib.samp.events']",
    "package.preload['encoding']",
    'report_desk_wm_dispatch',
    'report_desk_spectate_fsm'
)
$missing = @($mustHave | Where-Object { $coreText -notmatch [regex]::Escape($_) })
if ($missing.Count -gt 0) {
    throw "Bundle verification failed - missing in core: $($missing -join ', ')"
}
Write-Host 'Bundle verification OK'



$coreLuac = Join-Path $reportDeskDir 'AdminDeskCore.luac'
$legacyCoreLuac = Join-Path $reportDeskDir 'admin_report_desk_core.luac'

$luajit = Resolve-DeskLuajit $MoonloaderRoot $PSScriptRoot

if ($SkipLuac) {

    Write-Warning 'SkipLuac: only .lua core produced'

} elseif ($luajit) {

    Invoke-DeskLuajitCompile $luajit $coreLua $coreLuac

    Write-Host "Wrote $coreLuac (LuaJIT)"

} else {

    Write-Warning "LuaJIT not found. Download tools/luajit-210-compiler.zip from blast.hk/moonloader"

    Write-Warning "Users can run AdminDeskCore.lua (bootstrap supports .lua fallback)."

}

Copy-Item $coreLua $legacyCoreLua -Force
if (Test-Path $coreLuac) {
    Copy-Item $coreLuac $legacyCoreLuac -Force
}

$bootstrapSrc = Join-Path $PSScriptRoot 'admin_desk_bootstrap.lua'
if (-not (Test-Path $bootstrapSrc)) {
    Write-Error "Missing tools\admin_desk_bootstrap.lua"
}
$bootstrapLua = Join-Path $distDir 'AdminDesk.lua'
Copy-Item $bootstrapSrc $bootstrapLua -Force
$bootstrapLuac = Join-Path $distDir 'AdminDesk.luac'
if (-not $SkipLuac -and $luajit) {
    Invoke-DeskLuajitCompile $luajit $bootstrapLua $bootstrapLuac
    Write-Host "Wrote $bootstrapLuac (LuaJIT)"
} else {
    Write-Warning 'AdminDesk.luac not built (SkipLuac or no LuaJIT)'
}

$launcherSrc = Join-Path $PSScriptRoot 'admin_report_desk_stub.lua'
if (Test-Path $launcherSrc) {
    Copy-Item $launcherSrc (Join-Path $distDir 'admin_report_desk.lua') -Force
}

$autoupdateSrc = Join-Path $libDir 'report_desk_autoupdate.lua'
if (-not (Test-Path $autoupdateSrc)) {
    $autoupdateSrc = Join-Path $MoonloaderRoot 'report_desk_autoupdate.lua'
}
if (-not (Test-Path $autoupdateSrc)) {
    Write-Error "Missing lib\report_desk_autoupdate.lua"
}
Copy-Item $autoupdateSrc $distDir -Force

$overlaySrc = Join-Path $libDir 'report_desk_update_overlay.lua'
if (-not (Test-Path $overlaySrc)) {
    Write-Error "Missing lib\report_desk_update_overlay.lua"
}
Copy-Item $overlaySrc $distDir -Force
Write-Host "Wrote dist\report_desk_update_overlay.lua"

$depsSrc = Join-Path $libDir 'report_desk_deps.lua'
if (-not (Test-Path $depsSrc)) {
    $depsSrc = Join-Path $MoonloaderRoot 'report_desk_deps.lua'
}
if (Test-Path $depsSrc) {
    Copy-Item $depsSrc $distDir -Force
    Write-Host "Wrote dist\report_desk_deps.lua"
}

foreach ($aux in @('report_desk_sha256.lua', 'report_desk_zip.lua', 'report_desk_fs.lua')) {
    $auxSrc = Join-Path $libDir $aux
    if (Test-Path $auxSrc) {
        Copy-Item $auxSrc $distDir -Force
        Write-Host "Wrote dist\$aux"
    }
}

Write-Host "Wrote dist\AdminDesk.lua (bootstrap source)"
if (Test-Path (Join-Path $distDir 'admin_report_desk.lua')) {
    Write-Host "Wrote dist\admin_report_desk.lua (legacy launcher)"
}

Write-Host "Wrote dist\report_desk_autoupdate.lua"



Write-Host 'Done.'
Write-Host 'NOTE: bundle alone is NOT a full release (no version.json, no zip verify, no git sync).'
Write-Host '       Use: tools\build_release.ps1 -Version X.Y.Z'


