# High-quality vehicle previews from https://gtaxmods.com/veh-id.html (204x125)
param(
    [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_vehicles'),
    [string]$PageUrl = 'https://gtaxmods.com/veh-id.html',
    [switch]$Force
)

$Base = 'https://gtaxmods.com'
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

Write-Host "Fetching $PageUrl ..."
$html = curl.exe -sL $PageUrl
if (-not $html) { throw 'Failed to download page' }

$imgPat = 'src="([^"]+)"[^>]*alt="Image:Vehicle_(\d+)\.jpg"'
$metaPat = 'alt="Image:Vehicle_(\d+)\.jpg"[\s\S]{0,500}?<b>ID[^<]*</b>:\s*(\d+)[\s\S]{0,120}?<b>[^<]*</b>:\s*([^<]+)<br>[\s\S]{0,80}?<b>[^<]*</b>:\s*([^<]+)<br>'

$byId = @{}
foreach ($m in [regex]::Matches($html, $imgPat)) {
    $id = [int]$m.Groups[2].Value
    if ($id -lt 400 -or $id -gt 611) { continue }
    $src = $m.Groups[1].Value
    if (-not $src.StartsWith('/')) { $src = '/' + $src }
    $byId[$id] = @{ src = $src; name = 'ID ' + $id; category = '' }
}

foreach ($m in [regex]::Matches($html, $metaPat)) {
    $id = [int]$m.Groups[1].Value
    if (-not $byId.ContainsKey($id)) { continue }
    $byId[$id].name = ($m.Groups[3].Value -replace '\s+', ' ').Trim()
    $byId[$id].category = ($m.Groups[4].Value -replace '\s+', ' ').Trim()
}

$list = $byId.GetEnumerator() | ForEach-Object {
    [pscustomobject]@{
        id = $_.Key
        name = $_.Value.name
        category = $_.Value.category
        file = 'veh-' + $_.Key + '.jpg'
        url = $Base + $_.Value.src
    }
} | Sort-Object id

Write-Host "Found $($list.Count) vehicles"

$ok = 0; $skip = 0; $fail = 0
foreach ($v in $list) {
    $out = Join-Path $OutDir $v.file
    $oldPng = Join-Path $OutDir ('veh-' + $v.id + '.png')
    if ($Force -and (Test-Path $oldPng)) { Remove-Item $oldPng -Force -ErrorAction SilentlyContinue }
    if ((Test-Path $out) -and -not $Force -and (Get-Item $out).Length -gt 1500) {
        $skip++; continue
    }
    curl.exe -sL $v.url -o $out 2>$null
    if ((Test-Path $out) -and (Get-Item $out).Length -gt 1500) { $ok++ }
    else {
        if (Test-Path $out) { Remove-Item $out -Force -ErrorAction SilentlyContinue }
        $fail++
        Write-Warning "fail veh-$($v.id)"
    }
}

$indexPath = Join-Path $OutDir 'vehicles_index.lua'
$lines = @('return {')
foreach ($v in $list) {
    $n = $v.name.Replace("'", '')
    $c = $v.category.Replace("'", '')
    $lines += ('  { id = ' + $v.id + ", name = '" + $n + "', category = '" + $c + "', file = '" + $v.file + "' },")
}
$lines += '}'
$lines | Set-Content -Path $indexPath -Encoding UTF8

Write-Host "Done. ok=$ok skip=$skip fail=$fail -> $indexPath"
