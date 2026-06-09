# Report Desk — audit vehicle preview assets (PNG quality)
param(
    [string]$VehDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_vehicles'),
    [int]$MinBytes = 8000,
    [int]$MinWidth = 128,
    [int]$MinHeight = 80
)

$OverrideDir = Join-Path $VehDir 'overrides'
$CsvPath = Join-Path $VehDir 'vehicles_manifest.csv'
$IndexPath = Join-Path $VehDir 'vehicles_index.lua'

if (-not (Test-Path $VehDir)) {
    New-Item -ItemType Directory -Force -Path $VehDir | Out-Null
}
if (-not (Test-Path $OverrideDir)) {
    New-Item -ItemType Directory -Force -Path $OverrideDir | Out-Null
}

function Get-ImageSize($path) {
    try {
        Add-Type -AssemblyName System.Drawing -ErrorAction Stop
        $img = [System.Drawing.Image]::FromFile($path)
        $w = $img.Width
        $h = $img.Height
        $img.Dispose()
        return $w, $h
    } catch {
        return $null, $null
    }
}

function Resolve-VehFile($id) {
    $ovr = Join-Path $OverrideDir ("veh-{0}.png" -f $id)
    if (Test-Path $ovr) { return $ovr, 'override' }
    $png = Join-Path $VehDir ("veh-{0}.png" -f $id)
    if (Test-Path $png) { return $png, 'png' }
    $jpg = Join-Path $VehDir ("veh-{0}.jpg" -f $id)
    if (Test-Path $jpg) { return $jpg, 'jpg' }
    return $null, 'missing'
}

$names = @{}
if (Test-Path $IndexPath) {
    $raw = Get-Content $IndexPath -Raw -Encoding UTF8
    foreach ($m in [regex]::Matches($raw, '\{\s*id\s*=\s*(\d+)[^}]*name\s*=\s*''([^'']*)''')) {
        $names[[int]$m.Groups[1].Value] = $m.Groups[2].Value
    }
}

$rows = @()
$stats = @{ ok = 0; low = 0; missing = 0; jpg = 0 }

for ($id = 400; $id -le 611; $id++) {
    $path, $kind = Resolve-VehFile $id
    $name = if ($names.ContainsKey($id)) { $names[$id] } else { "ID $id" }
    $status = 'missing'
    $bytes = 0
    $w = 0
    $h = 0

    if ($path) {
        $fi = Get-Item $path
        $bytes = $fi.Length
        $w, $h = Get-ImageSize $path
        if ($kind -eq 'jpg' -or $bytes -lt $MinBytes) {
            $status = 'low'
            $stats.jpg++
        } elseif ($w -lt $MinWidth -or $h -lt $MinHeight) {
            $status = 'low'
        } else {
            $status = 'ok'
            $stats.ok++
        }
        if ($status -eq 'low') { $stats.low++ }
    } else {
        $stats.missing++
    }

    $rows += [pscustomobject]@{
        id = $id
        name = $name
        status = $status
        kind = $kind
        bytes = $bytes
        width = $w
        height = $h
        path = $path
    }
}

$rows | Export-Csv -Path $CsvPath -NoTypeInformation -Encoding UTF8

Write-Host "Vehicle assets audit: $VehDir"
Write-Host ("  ok={0} low={1} missing={2} (jpg/low quality={3})" -f $stats.ok, $stats.low, $stats.missing, ($stats.low))
Write-Host "  CSV: $CsvPath"
Write-Host '  Put PNG in overrides\ or veh-{id}.png (256x160 recommended)'
