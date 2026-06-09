# Optional: resize + lossless PNG optimize for report_desk_skins (offline)
# Requires: magick (ImageMagick) in PATH — https://imagemagick.org
param(
    [string]$SkinsDir = (Join-Path (Split-Path $PSScriptRoot -Parent) 'res\report_desk_skins'),
    [int]$MaxSide = 256,
    [switch]$Force
)

if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {
    Write-Error "ImageMagick 'magick' not found. Install or add to PATH."
    Write-Host "Install ImageMagick or use oxipng/pngquant manually."
    exit 1
}

if (-not (Test-Path $SkinsDir)) {
    Write-Error "Skins dir not found: $SkinsDir"
    exit 1
}

$files = Get-ChildItem $SkinsDir -Filter 'skin-*.png'
$ok = 0
$skip = 0

foreach ($f in $files) {
    $tmp = Join-Path $env:TEMP ("rdesk_" + $f.Name)
    if (-not $Force -and $f.Length -lt 90000) {
        $skip++
        continue
    }
    magick $f.FullName -resize "${MaxSide}x${MaxSide}>" -strip PNG24:$tmp
    if (Test-Path $tmp) {
        Move-Item -Force $tmp $f.FullName
        $ok++
    }
}

Write-Host "Optimized $ok files (skipped $skip under 90KB). Max side: $MaxSide px."
Write-Host "For fast catalog warmup, also run: tools\build_catalog_dds.ps1 -ResizePng"
