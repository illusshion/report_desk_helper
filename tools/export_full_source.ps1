# Собирает все исходники Report Desk в один .lua для аудита (не для запуска в игре).
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$OutFile = (Join-Path $PSScriptRoot 'report_desk_FULL_SOURCE_FOR_AUDIT.lua')
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$libDir = Join-Path $MoonloaderRoot 'lib'
$configDir = Join-Path $MoonloaderRoot 'config'

function Read-ManifestFiles([string]$Key) {
    $manifestPath = Join-Path $configDir 'report_desk_bundle_manifest.lua'
    $text = [System.IO.File]::ReadAllText($manifestPath, $Utf8NoBom)
    $pattern = [regex]::Escape($Key) + '\s*=\s*\{([^}]*)\}'
    $m = [regex]::Match($text, $pattern)
    if (-not $m.Success) { throw "manifest section missing: $Key" }
    return @([regex]::Matches($m.Groups[1].Value, "'([^']+\.lua)'") | ForEach-Object { $_.Groups[1].Value })
}

$ordered = [System.Collections.Generic.List[string]]::new()
$seen = @{}

function Add-File([string]$RelPath) {
    if ($seen.ContainsKey($RelPath)) { return }
    $seen[$RelPath] = $true
    $ordered.Add($RelPath) | Out-Null
}

# Entry + loader
Add-File 'admin_report_desk.lua'
Add-File 'lib/report_desk_app.lua'

# Config (data + defaults)
foreach ($f in @(
    'config/report_desk_bundle_manifest.lua',
    'config/admin_report_desk.default.lua',
    'config/admin_report_desk_user.default.lua',
    'config/report_desk_intents.lua',
    'config/intent_trigger_extensions.lua',
    'config/intent_stem_blocklist.lua',
    'config/faction_clist_capture.lua'
)) { Add-File $f }

# lib: manifest chunks
foreach ($key in @('core_a_a', 'core_a_b', 'core_a_b2', 'core_a_c', 'late', 'remote_chat')) {
    foreach ($name in (Read-ManifestFiles $key)) {
        Add-File ("lib/$name")
    }
}

# lib: bundle extras (spectate, checker parser, assets, release helpers)
foreach ($name in @(
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
    'report_desk_vehicles.lua',
    'report_desk_profanity_words.lua',
    'report_desk_autoupdate.lua',
    'report_desk_deps.lua',
    'report_desk_fs.lua',
    'report_desk_sha256.lua',
    'report_desk_zip.lua',
    'report_desk_update_overlay.lua'
)) { Add-File ("lib/$name") }

$sb = New-Object System.Text.StringBuilder
$null = $sb.AppendLine('--[[ REPORT DESK — consolidated source for external audit / bug review')
$null = $sb.AppendLine('-- NOT RUNNABLE: concatenation of project Lua files with section markers.')
$null = $sb.AppendLine('-- Regenerate: tools\export_full_source.ps1')
$null = $sb.AppendLine(('-- Generated: {0}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss')))
$null = $sb.AppendLine('-- MoonLoader project: Report Desk (admin_report_desk)')
$null = $sb.AppendLine('--]]')
$null = $sb.AppendLine('')

$totalLines = 0
$fileCount = 0
$missing = @()

foreach ($rel in $ordered) {
    $path = Join-Path $MoonloaderRoot ($rel -replace '/', '\')
    if (-not (Test-Path $path)) {
        $missing += $rel
        continue
    }
    $content = [System.IO.File]::ReadAllText($path, $Utf8NoBom)
    if ($content.StartsWith([char]0xFEFF)) { $content = $content.Substring(1) }
    $lineCount = ($content -split "`n").Count
    $totalLines += $lineCount
    $fileCount++

    $null = $sb.AppendLine('')
    $null = $sb.AppendLine(('--' + ('=' * 78)))
    $null = $sb.AppendLine(('-- BEGIN FILE: {0} ({1} lines)' -f $rel, $lineCount))
    $null = $sb.AppendLine(('--' + ('=' * 78)))
    $null = $sb.AppendLine($content.TrimEnd())
    $null = $sb.AppendLine(('-- END FILE: ' + $rel))
}

if ($missing.Count -gt 0) {
    Write-Warning ('Skipped missing: ' + ($missing -join ', '))
}

[System.IO.File]::WriteAllText($OutFile, $sb.ToString(), $Utf8NoBom)
$bytes = (Get-Item $OutFile).Length
Write-Host "Wrote $OutFile"
Write-Host "  Files: $fileCount"
Write-Host "  Lines: ~$totalLines"
Write-Host "  Size:  $([math]::Round($bytes / 1MB, 2)) MB ($bytes bytes)"
