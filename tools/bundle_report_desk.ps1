# Сборка одного admin_report_desk_core.lua / .luac из модулей Report Desk.

param(

    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),

    [switch]$SkipLuac

)



$ErrorActionPreference = 'Stop'

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

    return [System.IO.File]::ReadAllText($path, $Utf8NoBom)

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



function Wrap-AppChunkSafe($name, $content) {

    $open, $close = Get-LuaLongBracket $content

    $chunkTag = '@' + $name

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

        print('[Report Desk] checker disabled: ' .. tostring(errChunk))

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
    @{ Name = 'report_desk_spectate_session'; File = 'report_desk_spectate_session.lua' },
    @{ Name = 'report_desk_spectate_ans'; File = 'report_desk_spectate_ans.lua' },
    @{ Name = 'report_desk_spectate_menu'; File = 'report_desk_spectate_menu.lua' },
    @{ Name = 'report_desk_sp_ui'; File = 'report_desk_sp_ui.lua' },
    @{ Name = 'report_desk_spectate_stats'; File = 'report_desk_spectate_stats.lua' },
    @{ Name = 'report_desk_checker_parser'; File = 'report_desk_checker_parser.lua' },
    @{ Name = 'report_desk_checker_catalog'; File = 'report_desk_checker_catalog.lua' },

    @{ Name = 'report_desk_vehicles'; File = 'report_desk_vehicles.lua' },

    @{ Name = 'report_desk_profanity_words'; File = 'report_desk_profanity_words.lua' }

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

    'report_desk_hooks.lua',

    'report_desk_env_export.lua',

    'report_desk_main.lua'

)



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

$checkerPath = Join-Path $libDir 'report_desk_checker.lua'
$checkerText = Read-ModuleText $checkerPath
[void]$sb.Append((Wrap-AppChunkSafe 'report_desk_checker.lua' $checkerText))

[void]$sb.Append($footer)



$coreLua = Join-Path $reportDeskDir 'admin_report_desk_core.lua'

[System.IO.File]::WriteAllText($coreLua, $sb.ToString(), $Utf8NoBom)

Write-Host "Wrote $coreLua ($(([System.IO.FileInfo]$coreLua).Length) bytes)"



$coreLuac = Join-Path $reportDeskDir 'admin_report_desk_core.luac'

$luacCandidates = @(

    (Join-Path $MoonloaderRoot 'luac.exe'),

    (Join-Path $MoonloaderRoot 'luac51.exe'),

    'luac',

    'luac5.1'

)

$luac = $null

foreach ($c in $luacCandidates) {

    if ($c -match '\\') {

        if (Test-Path $c) { $luac = $c; break }

    } elseif (Get-Command $c -ErrorAction SilentlyContinue) {

        $luac = (Get-Command $c).Source

        break

    }

}



if ($SkipLuac) {

    Write-Warning 'SkipLuac: only .lua core produced'

} elseif ($luac) {

    & $luac -o $coreLuac $coreLua

    if (Test-Path $coreLuac) {

        Write-Host "Wrote $coreLuac"

    } else {

        Write-Warning "luac failed; ship $coreLua instead"

    }

} else {

    Write-Warning "luac not found. Install Lua 5.1 luac or copy from MoonLoader SDK."

    Write-Warning "Users can run admin_report_desk_core.lua (stub supports .lua fallback)."

}



$launcherSrc = Join-Path $PSScriptRoot 'admin_report_desk_stub.lua'
if (-not (Test-Path $launcherSrc)) {
    Write-Error "Missing tools\admin_report_desk_stub.lua (prod launcher source)"
}
Copy-Item $launcherSrc (Join-Path $distDir 'admin_report_desk.lua') -Force

$autoupdateSrc = Join-Path $libDir 'report_desk_autoupdate.lua'
if (-not (Test-Path $autoupdateSrc)) {
    $autoupdateSrc = Join-Path $MoonloaderRoot 'report_desk_autoupdate.lua'
}
if (-not (Test-Path $autoupdateSrc)) {
    Write-Error "Missing lib\report_desk_autoupdate.lua"
}
Copy-Item $autoupdateSrc $distDir -Force

$depsSrc = Join-Path $libDir 'report_desk_deps.lua'
if (-not (Test-Path $depsSrc)) {
    $depsSrc = Join-Path $MoonloaderRoot 'report_desk_deps.lua'
}
if (Test-Path $depsSrc) {
    Copy-Item $depsSrc $distDir -Force
    Write-Host "Wrote dist\report_desk_deps.lua"
}

Write-Host "Wrote dist\admin_report_desk.lua (launcher)"

Write-Host "Wrote dist\report_desk_autoupdate.lua"



Write-Host 'Done. Next: tools\build_release.ps1 -Version 3.42.1'


