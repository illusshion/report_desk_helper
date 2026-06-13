# Count ^local declarations per report_desk_app.lua bundle chunk (Lua 5.1 limit: 200/chunk).
param(
    [string]$LibDir = (Join-Path $PSScriptRoot '..\lib')
)

function Read-DeskBundleManifestSection {
    param([string]$Text, [string]$Key)
    $pattern = [regex]::Escape($Key) + '\s*=\s*\{([^}]*)\}'
    $m = [regex]::Match($Text, $pattern)
    if (-not $m.Success) { throw "Bundle manifest section missing: $Key" }
    return @([regex]::Matches($m.Groups[1].Value, "'([^']+\.lua)'") | ForEach-Object { $_.Groups[1].Value })
}

$manifestPath = Join-Path (Split-Path $LibDir -Parent) 'config\report_desk_bundle_manifest.lua'
if (-not (Test-Path $manifestPath)) { throw "Missing bundle manifest: $manifestPath" }
$manifestText = Get-Content $manifestPath -Raw

$chunks = @{
    core_a  = Read-DeskBundleManifestSection $manifestText 'core_a_a'
    core_b  = Read-DeskBundleManifestSection $manifestText 'core_a_b'
    core_b2 = Read-DeskBundleManifestSection $manifestText 'core_a_b2'
    core_c  = Read-DeskBundleManifestSection $manifestText 'core_a_c'
    late    = Read-DeskBundleManifestSection $manifestText 'late'
}

$warnAt = 180
$failAt = 200
$exitCode = 0

Write-Host 'Note: each chunk is one concatenated loadstring in report_desk_app.lua (MoonLoader/LuaJIT).'
Write-Host "Nominal Lua 5.1 limit: $failAt locals/chunk; warn at $warnAt."
Write-Host ''

foreach ($chunkName in @('core_a', 'core_b', 'core_b2', 'core_c', 'late')) {
    $files = $chunks[$chunkName]
    $total = 0
    $perFile = @()
    $maxFile = 0
    $maxFileName = ''
    foreach ($rel in $files) {
        $path = Join-Path $LibDir $rel
        if (-not (Test-Path $path)) {
            Write-Warning "Missing: $path"
            continue
        }
        $n = (Select-String -Path $path -Pattern '^\s*local ' -AllMatches).Count
        $total += $n
        if ($n -gt $maxFile) { $maxFile = $n; $maxFileName = $rel }
        $perFile += "  $rel : $n"
    }
    $status = 'OK'
    if ($total -ge $failAt) { $status = 'WARN-LUA51'; $exitCode = 1 }
    elseif ($total -ge $warnAt) { $status = 'WARN' }
    Write-Host "$chunkName : $total locals (max file $maxFileName = $maxFile) [$status]"
    $perFile | ForEach-Object { Write-Host $_ }
}

exit $exitCode
