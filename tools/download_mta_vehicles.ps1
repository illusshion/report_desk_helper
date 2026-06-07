# Parses MTA wiki Vehicle IDs page and downloads preview images.
param(
    [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_vehicles'),
    [string]$WikiUrl = 'https://wiki.multitheftauto.com/wiki/RU/Vehicle_IDs',
    [switch]$Force
)

$Base = 'https://wiki.multitheftauto.com'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Write-Host "Fetching wiki page..."
$html = curl.exe -sL $WikiUrl
if (-not $html) { throw "Failed to download wiki page" }

$pattern = '<tr>\s*<td>([^<]+)</td>\s*<td>(\d{3})</td>\s*<td[^>]*>.*?src="/images/([^"]+)"'
$matches = [regex]::Matches($html, $pattern, [System.Text.RegularExpressions.RegexOptions]::Singleline)

$seen = @{}
$list = @()
foreach ($m in $matches) {
    $name = ($m.Groups[1].Value -replace '\s+', ' ').Trim()
    $id = [int]$m.Groups[2].Value
    $path = $m.Groups[3].Value
    if ($id -lt 400 -or $id -gt 611) { continue }
    if ($seen.ContainsKey($id)) { continue }
    $seen[$id] = $true
    $url = $Base + '/images/' + $path.TrimStart('/')
    $file = 'veh-' + $id + '.png'
    $list += [pscustomobject]@{ id = $id; name = $name; file = $file; url = $url }
}

$list = $list | Sort-Object id
Write-Host "Found $($list.Count) vehicles"

$ok = 0; $skip = 0; $fail = 0
foreach ($v in $list) {
    $out = Join-Path $OutDir $v.file
    if ((Test-Path $out) -and -not $Force -and (Get-Item $out).Length -gt 200) {
        $skip++; continue
    }
    curl.exe -sL $v.url -o $out 2>$null
    if ((Test-Path $out) -and (Get-Item $out).Length -gt 200) { $ok++ }
    else {
        if (Test-Path $out) { Remove-Item $out -Force -ErrorAction SilentlyContinue }
        $fail++
        Write-Warning "fail veh-$($v.id) $($v.url)"
    }
}

$indexPath = Join-Path $OutDir 'vehicles_index.lua'
$lines = @('return {')
foreach ($v in $list) {
    $n = $v.name.Replace("'", '')
    $lines += ('  { id = ' + $v.id + ", name = '" + $n + "', file = '" + $v.file + "' },")
}
$lines += '}'
$lines | Set-Content -Path $indexPath -Encoding UTF8

Write-Host "Done. images ok=$ok skip=$skip fail=$fail index=$indexPath"
