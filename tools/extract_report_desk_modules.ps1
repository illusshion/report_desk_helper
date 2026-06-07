# Extract admin_report_desk.lua into loadable module chunks (shared env via setfenv).
param(
    [string]$Root = (Split-Path $PSScriptRoot -Parent)
)

$ErrorActionPreference = 'Stop'
$Utf8NoBom = New-Object System.Text.UTF8Encoding $false
$src = Join-Path $Root 'admin_report_desk.lua'
if (-not (Test-Path $src)) { throw "Missing $src" }

$allLines = [System.Collections.Generic.List[string]]::new()
foreach ($line in [System.IO.File]::ReadAllLines($src, $Utf8NoBom)) {
    [void]$allLines.Add($line)
}

function Get-Range($start, $end) {
    $start = [Math]::Max(1, $start)
    $end = [Math]::Min($allLines.Count, $end)
    if ($end -lt $start) { return @() }
    $out = New-Object string[] ($end - $start + 1)
    for ($i = $start; $i -le $end; $i++) {
        $out[$i - $start] = $allLines[$i - 1]
    }
    return ,$out
}

function Write-Chunk($name, $start, $end, $header) {
    $body = Get-Range $start $end
    $path = Join-Path $Root $name
    $text = ($header + "`n" + ($body -join "`n") + "`n")
    [System.IO.File]::WriteAllText($path, $text, $Utf8NoBom)
    Write-Host "Wrote $name lines $start-$end ($($body.Length) lines)"
}

# Find script_name line (skip changelog header)
$scriptLine = 1
for ($i = 0; $i -lt $allLines.Count; $i++) {
    if ($allLines[$i] -match '^script_name') { $scriptLine = $i + 1; break }
}

$requiresEnd = $scriptLine + 50
for ($i = $scriptLine; $i -lt [Math]::Min($scriptLine + 80, $allLines.Count); $i++) {
    if ($allLines[$i] -match '^local new, sizeof') { $requiresEnd = $i; break }
}

Write-Chunk 'report_desk_bootstrap.lua' ($scriptLine + 6) $requiresEnd @'
--[[ Report Desk bootstrap: requires, encoding, imgui compat ]]
'@

Write-Chunk 'report_desk_mod_constants.lua' ($requiresEnd + 1) 213 @'
--[[ Report Desk constants ]]
'@

Write-Chunk 'report_desk_mod_theme.lua' 215 250 @'
--[[ Report Desk theme / ImGui style ]]
'@

Write-Chunk 'report_desk_mod_state.lua' 252 751 @'
--[[ Report Desk shared state ]]
'@

Write-Chunk 'report_desk_mod_util.lua' 753 1236 @'
--[[ Report Desk utilities ]]
'@

Write-Chunk 'report_desk_mod_profanity.lua' 1237 1868 @'
--[[ Report Desk profanity filter ]]
'@

Write-Chunk 'report_desk_mod_chat.lua' 1870 2366 @'
--[[ Report Desk chat / outbound ]]
'@

Write-Chunk 'report_desk_mod_cheats.lua' 2367 3943 @'
--[[ Report Desk cheats / marker ]]
'@

Write-Chunk 'report_desk_mod_skins.lua' 3944 4663 @'
--[[ Report Desk skins catalog ]]
'@

Write-Chunk 'report_desk_mod_input.lua' 4664 5202 @'
--[[ Report Desk input / camera / F7 ]]
'@

Write-Chunk 'report_desk_mod_actions.lua' 5203 6062 @'
--[[ Report Desk player actions / watch ]]
'@

Write-Chunk 'report_desk_mod_threads.lua' 6063 6297 @'
--[[ Report Desk thread model ]]
'@

Write-Chunk 'report_desk_mod_config.lua' 6298 6832 @'
--[[ Report Desk config load/save ]]
'@

Write-Chunk 'report_desk_mod_ingest.lua' 6833 7535 @'
--[[ Report Desk ingest runtime ]]
'@

Write-Chunk 'report_desk_mod_rules.lua' 7536 8130 @'
--[[ Report Desk auto-rules / scenarios ]]
'@

Write-Chunk 'report_desk_mod_ui.lua' 8131 10491 @'
--[[ Report Desk UI + frames + window messages ]]
'@

Write-Chunk 'report_desk_mod_hooks.lua' 10492 10642 @'
--[[ Report Desk SAMP hooks ]]
'@

Write-Chunk 'report_desk_mod_main.lua' 10643 10802 @'
--[[ Report Desk main loop + terminate ]]
'@

Write-Host 'Done.'
