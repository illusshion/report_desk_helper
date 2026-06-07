# Download GTA SA vehicle previews from GTA Fandom (GTASA-front.jpg, ~320px) -> optimized PNG
param(
    [string]$OutDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_vehicles'),
    [string]$IndexPath = '',
    [int]$FromId = 400,
    [int]$ToId = 611,
    [int]$MaxWidth = 256,
    [int]$ThumbWidth = 320,
    [switch]$Force,
    [switch]$OnlyLow
)

$ErrorActionPreference = 'Continue'
if (-not $IndexPath) { $IndexPath = Join-Path $OutDir 'vehicles_index.lua' }
$OverrideDir = Join-Path $OutDir 'overrides'
$ApiBase = 'https://gta.fandom.com/api.php'

if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }
if (-not (Test-Path $OverrideDir)) { New-Item -ItemType Directory -Force -Path $OverrideDir | Out-Null }

$ConvertPy = Join-Path $PSScriptRoot 'veh_image_convert.py'

# Display name (index) -> Fandom file base name
$WikiNameMap = @{
    'Perenniel' = 'Perennial'
    'Firetruck' = 'FireTruck'
    'Police LV' = 'Police (LVPD)'
    'Police SF' = 'Police (SFPD)'
    'Police LS' = 'Police (SAPD)'
    'Police Ranger' = 'Ranger'
    'HPV1000' = 'HPV1000'
    'FCR-900' = 'FCR-900'
    'BF Injection' = 'BF Injection'
    'Washing' = 'Sweeper'
    'Quadbike' = 'Quad'
    'Faggio' = 'Faggio (3D Universe)'
    'ZR-350' = 'ZR350'
    'Hotring Racer' = 'HotringRacer'
    'Hotring Racer 2' = 'Hotring Racer (hotrina)'
    'Hotring Racer 3' = 'Hotring Racer (hotrinb)'
    'Monster' = 'Monster (3D Universe)'
    'Monster 2' = 'Monster (monstera)'
    'Monster 3' = 'Monster (monsterb)'
    'Pizza Boy' = 'Pizza Boy (3D Universe)'
    'Berkleys RC Van' = 'Berkley''s RC Van'
    'Mr. Whoopee' = 'Mr Whoopee'
    'News Van' = 'Newsvan'
    'BF-400' = 'BF-400'
    'Mesa' = 'Mesa'
    'S.W.A.T.' = 'S.W.A.T. (vehicle)'
    'Article Trailer' = 'Trailer (1st gen)'
    'Article Trailer 2' = 'Trailer (2nd gen)'
    'Article Trailer 3' = 'Trailer (3rd gen)'
    'Topfun Van (Berkleys RC)' = 'Berkley''s RC Van'
    'Mr Whoopee' = 'Mr Whoopee'
    'Squallo' = 'Squalo'
    'SAN News Maverick' = 'Maverick'
    'Stuntplane' = 'Stunt Plane'
    'Shamal' = 'Shamal'
    'Hydra' = 'Hydra'
    'NRG-500' = 'NRG-500'
    'Police Car (LSPD)' = 'Police (SAPD)'
    'Police Car (SFPD)' = 'Police (SFPD)'
    'Police Car (LVPD)' = 'Police (LVPD)'
    'Firetruck LA' = 'Fire Truck'
    'Monster "A"' = 'Monster (monstera)'
    'Monster "B"' = 'Monster (monsterb)'
    'Petrol Trailer' = 'Tanker Trailer'
    'Nevada' = 'Nevada'
    'AT400' = 'AT-400'
    'RC Cam' = 'RC Cam'
    'Glendale Shit' = 'Glendale'
    'Sadler Shit' = 'Sadler'
}

# Exact Fandom filenames (wiki uses non-standard names)
$IdWikiFile = @{
    407 = 'FireTruck-GTASA-front.jpg'
    435 = 'ArticulatedTrailer-GTASA-artict1-front.jpg'
    444 = 'Monster-GTASA-monster-front.jpg'
    450 = 'ArticulatedTrailer-GTASA-artict2-front.jpg'
    459 = 'Berkley''sRCVan-GTASA-Rear.jpg'
    462 = 'Faggio-GTASA-singletone-front.jpg'
    477 = 'ZR350-GTASA-front.jpg'
    494 = 'HotringRacer-GTASA-hotring-front.jpg'
    500 = 'Mesa-GTASA-front.jpg'
    502 = 'HotringRacer-GTASA-hotrina-front.jpg'
    503 = 'HotringRacer-GTASA-hotrinb-front.jpg'
    513 = 'Stuntplane-GTASA-parked.jpg'
    519 = 'Shamal-GTASA-interior-front.jpg'
    520 = 'Hydra-GTASA-parked.jpg'
    521 = 'FCR-900-GTASA-variant1-front.jpg'
    522 = 'NRG-500-GTASA-variant1-front.jpg'
    523 = 'HPV-1000-GTASA-front.jpg'
    537 = 'Freight-GTASA-front.jpg'
    538 = 'BrownStreak-GTASA-front.jpg'
    544 = 'FireTruck-GTASA-front.jpg'
    553 = 'Nevada-GTASA-inflight.jpg'
    556 = 'Monster-GTASA-monstera-front.jpg'
    557 = 'Monster-GTASA-monsterb-front.jpg'
    577 = 'AT400-GTASA-parked.jpg'
    581 = 'BF-400-GTASA-variant1-front.jpg'
    591 = 'ArticulatedTrailer-GTASA-artict3-front.jpg'
    594 = 'RCCam-GTASA-wheels.jpg'
    596 = 'Police-GTASA-SAPD-Cutscene-Front.png'
    597 = 'Police-GTASA-SFPD-front.jpg'
    598 = 'Police-GTASA-LVPD-front.jpg'
    601 = 'SWAT-GTASA-front.jpg'
    606 = 'Baggage-GTASA-front.jpg'
    607 = 'Baggage-GTASA-front.jpg'
    608 = 'TugStairs-GTASA-front.jpg'
}

function Normalize-WikiName([string]$name) {
    $n = ($name -replace '\s+', ' ').Trim()
    if ($WikiNameMap.ContainsKey($n)) { return $WikiNameMap[$n] }
    return $n
}

function Get-WikiFileCandidates([string]$name) {
    $n = Normalize-WikiName $name
    $list = @($n)
    if ($n -match "'") {
        $list += ($n -replace "'", '')
    }
    if ($n -eq 'Firetruck') { $list += 'Fire Truck' }
    if ($n -eq 'Perennial') { $list += 'Perenniel' }
    if ($n -match ' ') {
        $list += ($n -replace ' ', '')
    }
    $seen = @{}
    $out = @()
    foreach ($x in $list) {
        if ($x -and -not $seen.ContainsKey($x)) {
            $seen[$x] = $true
            $out += $x
        }
    }
    return $out
}

function Parse-VehicleIndex([string]$path) {
    $rows = @()
    if (-not (Test-Path $path)) { return $rows }
    $raw = Get-Content $path -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($raw, '\{\s*id\s*=\s*(\d+)\s*,\s*name\s*=\s*''([^'']*)''(?:\s*,\s*category\s*=\s*''([^'']*)'')?')) {
        $rows += [pscustomobject]@{
            id = [int]$m.Groups[1].Value
            name = $m.Groups[2].Value
            category = if ($m.Groups[3].Success) { $m.Groups[3].Value } else { '' }
        }
    }
    return $rows
}

function Invoke-FandomQuery([string]$queryString) {
    $url = $ApiBase + '?' + $queryString
    try {
        return curl.exe -sL --max-time 25 $url 2>$null | ConvertFrom-Json
    } catch {
        return $null
    }
}

function Resolve-ImageUrlFromFile([string]$fileName) {
    $enc = [uri]::EscapeDataString('File:' + $fileName)
    $q = "action=query&format=json&titles=$enc&prop=imageinfo&iiprop=url&iiurlwidth=$ThumbWidth"
    $json = Invoke-FandomQuery $q
    if (-not $json -or -not $json.query -or -not $json.query.pages) { return $null }
    foreach ($p in $json.query.pages.PSObject.Properties) {
        $page = $p.Value
        if ($page.imageinfo) {
            $ii = $page.imageinfo[0]
            foreach ($u in @($ii.thumburl, $ii.url)) {
                if ($u) { return $u }
            }
        }
    }
    return $null
}

function Resolve-ImageUrl([string]$wikiBase) {
    $patterns = @(
        '{0}-GTASA-front.jpg',
        '{0}-GTASA-variant1-front.jpg',
        '{0}-GTASA-parked.jpg',
        '{0}-GTASA-ride-front.jpg',
        '{0}-GTASA-FrontQuarter.png',
        '{0}-GTASA-front.png'
    )
    foreach ($pat in $patterns) {
        $u = Resolve-ImageUrlFromFile ($pat -f $wikiBase)
        if ($u) { return $u }
    }
    return $null
}

function Save-OptimizedPng([string]$url, [string]$outPng, [int]$maxW, [string]$stagingDir) {
    $tmp = Join-Path $stagingDir ([Guid]::NewGuid().ToString('N') + '.bin')
    $stgPng = Join-Path $stagingDir ([System.IO.Path]::GetFileName($outPng))
    try {
        if (-not (Test-Path $ConvertPy)) { return $false }
        $wc = New-Object Net.WebClient
        $wc.Headers.Add('User-Agent', 'ReportDeskAssetBot/1.0')
        $wc.DownloadFile($url, $tmp)
        if (-not (Test-Path $tmp) -or (Get-Item $tmp).Length -lt 800) { return $false }
        $py = if (Get-Command py -ErrorAction SilentlyContinue) { 'py' } else { 'python' }
        & $py -3 $ConvertPy $tmp $stgPng $maxW
        if ($LASTEXITCODE -ne 0 -or -not (Test-Path $stgPng)) { return $false }
        Copy-Item -Path $stgPng -Destination $outPng -Force
        return (Test-Path $outPng) -and ((Get-Item $outPng).Length -gt 2000)
    } catch {
        return $false
    } finally {
        if (Test-Path $tmp) { Remove-Item $tmp -Force -ErrorAction SilentlyContinue }
        if (Test-Path $stgPng) { Remove-Item $stgPng -Force -ErrorAction SilentlyContinue }
    }
}

$StagingDir = Join-Path $env:TEMP 'report_desk_veh_dl'
if (-not (Test-Path $StagingDir)) { New-Item -ItemType Directory -Force -Path $StagingDir | Out-Null }

$vehicles = Parse-VehicleIndex $IndexPath | Where-Object { $_.id -ge $FromId -and $_.id -le $ToId } | Sort-Object id
if ($OnlyLow) {
    $vehicles = $vehicles | Where-Object {
        $png = Join-Path $OutDir ('veh-' + $_.id + '.png')
        -not ((Test-Path $png) -and (Get-Item $png).Length -gt 8000)
    }
}
Write-Host "Vehicles to process: $($vehicles.Count)"
Write-Host "Staging: $StagingDir -> $OutDir"

$ok = 0; $skip = 0; $fail = 0
$allRows = Parse-VehicleIndex $IndexPath
if ($allRows.Count -lt 50) {
    Write-Warning "Index has only $($allRows.Count) entries; run download_gtax_vehicles.ps1 first."
    exit 1
}
$rowById = @{}
foreach ($r in $allRows) { $rowById[$r.id] = $r }
$indexUpdates = @{}
$urlCache = @{}

foreach ($v in $vehicles) {
    $outPng = Join-Path $OutDir ("veh-{0}.png" -f $v.id)
    $oldJpg = Join-Path $OutDir ("veh-{0}.jpg" -f $v.id)
    $fileName = 'veh-' + $v.id + '.png'

    if ((Test-Path $outPng) -and -not $Force -and (Get-Item $outPng).Length -gt 8000) {
        $skip++
        $indexUpdates[$v.id] = [pscustomobject]@{ file = $fileName; low = $false }
        continue
    }

    $url = $null
    if ($IdWikiFile.ContainsKey($v.id)) {
        Start-Sleep -Milliseconds 120
        $url = Resolve-ImageUrlFromFile $IdWikiFile[$v.id]
    }
    foreach ($cand in (Get-WikiFileCandidates $v.name)) {
        if ($url) { break }
        $key = $cand.ToLower()
        if ($urlCache.ContainsKey($key)) {
            $url = $urlCache[$key]
            if ($url) { break }
            continue
        }
        Start-Sleep -Milliseconds 120
        $url = Resolve-ImageUrl $cand
        $urlCache[$key] = $url
        if ($url) { break }
    }

    if (-not $url) {
        $fail++
        Write-Warning "No GTASA image: veh-$($v.id) $($v.name)"
        if (Test-Path $oldJpg) {
            $indexUpdates[$v.id] = [pscustomobject]@{ file = ('veh-' + $v.id + '.jpg'); low = $true }
        } else {
            $indexUpdates[$v.id] = [pscustomobject]@{ file = $fileName; low = $true }
        }
        continue
    }

    if (Save-OptimizedPng $url $outPng $MaxWidth $StagingDir) {
        $ok++
        if (Test-Path $oldJpg) { Remove-Item $oldJpg -Force -ErrorAction SilentlyContinue }
        $indexUpdates[$v.id] = [pscustomobject]@{ file = $fileName; low = $false }
        Write-Host "OK veh-$($v.id) $($v.name)"
    } else {
        $fail++
        Write-Warning "Download fail: veh-$($v.id)"
        $indexUpdates[$v.id] = [pscustomobject]@{ file = $fileName; low = $true }
    }
}

if ($indexUpdates.Count -gt 0) {
    $lines = @('return {')
    foreach ($r in ($allRows | Sort-Object id)) {
        $fileName = 'veh-' + $r.id + '.png'
        $low = $true
        if ($indexUpdates.ContainsKey($r.id)) {
            $fileName = $indexUpdates[$r.id].file
            $low = $indexUpdates[$r.id].low
        } elseif (Test-Path (Join-Path $OutDir $fileName)) {
            $low = $false
            if ((Get-Item (Join-Path $OutDir $fileName)).Length -gt 8000) { $low = $false }
        } elseif (Test-Path (Join-Path $OutDir ('veh-' + $r.id + '.jpg'))) {
            $fileName = 'veh-' + $r.id + '.jpg'
        }
        $n = $r.name.Replace("'", '')
        $c = $r.category.Replace("'", '')
        $line = "  { id = $($r.id), name = '$n', category = '$c', file = '$fileName'"
        if ($low) { $line += ', lowQuality = true' }
        $line += ' },'
        $lines += $line
    }
    $lines += '}'
    $lines | Set-Content -Path $IndexPath -Encoding UTF8
}

Write-Host "Done. ok=$ok skip=$skip fail=$fail index=$IndexPath"
