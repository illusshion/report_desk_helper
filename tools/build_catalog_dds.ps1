# Build D3D-friendly DDS thumbnails for Report Desk catalog (skins + vehicles).

# DDS = только для сетки (мелкие ячейки). Крупное превью в UI берёт PNG (без DXT-артефактов).

# Requires ImageMagick "magick" in PATH — https://imagemagick.org

param(

    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),

    [switch]$SkinsOnly,

    [switch]$VehiclesOnly,

    [switch]$Force,

    [switch]$ResizePng

)



function Test-Magick {

    if (-not (Get-Command magick -ErrorAction SilentlyContinue)) {

        Write-Error "ImageMagick 'magick' not found. Install or add to PATH."

        Write-Host "See tools\IMAGE_ASSETS.md"

        exit 1

    }

}



function Convert-DirToDds {

    param(

        [string]$Dir,

        [string]$Prefix,

        [int]$MaxW,

        [int]$MaxH,

        [switch]$AlphaPng32

    )

    if (-not (Test-Path $Dir)) {

        Write-Warning "Skip missing dir: $Dir"

        return

    }

    $files = Get-ChildItem $Dir -Filter "$Prefix*.png"

    $built = 0

    $skipped = 0

    foreach ($f in $files) {

        $dds = [System.IO.Path]::ChangeExtension($f.FullName, '.dds')

        if (-not $Force -and (Test-Path $dds) -and $dds.LastWriteTimeUtc -ge $f.LastWriteTimeUtc) {

            $skipped++

            continue

        }

        $src = $f.FullName

        if ($ResizePng -and ($Force -or $f.Length -gt 120000)) {

            $tmpPng = Join-Path $env:TEMP ("rdesk_" + $f.Name)

            if ($AlphaPng32) {

                magick $f.FullName -filter Lanczos -resize "${MaxW}x${MaxH}>" `

                    -background none -alpha set -strip PNG32:$tmpPng

            } else {

                magick $f.FullName -filter Lanczos -resize "${MaxW}x${MaxH}>" -strip PNG24:$tmpPng

            }

            if (Test-Path $tmpPng) {

                Move-Item -Force $tmpPng $f.FullName

                $src = $f.FullName

            }

        }

        $convSrc = $src

        if ($AlphaPng32) {

            $tmpConv = Join-Path $env:TEMP ("rdesk_dds_" + $f.Name)

            magick $src -background none -alpha set -strip PNG32:$tmpConv

            if (Test-Path $tmpConv) { $convSrc = $tmpConv }

        }

        magick $convSrc -filter Lanczos -alpha on -resize "${MaxW}x${MaxH}>" `

            -define dds:compression=dxt5 -define dds:mipmaps=0 `

            "dxt5:$dds"

        if ($AlphaPng32 -and $convSrc -ne $src -and (Test-Path $convSrc)) {

            Remove-Item -Force $convSrc -ErrorAction SilentlyContinue

        }

        if (Test-Path $dds) { $built++ }

    }

    Write-Host "$Dir : DDS built=$built skipped=$skipped"

}



Test-Magick

$skinsDir = Join-Path $MoonloaderRoot 'res\report_desk_skins'

$vehDir = Join-Path $MoonloaderRoot 'res\report_desk_vehicles'

$vehOvr = Join-Path $vehDir 'overrides'



if (-not $VehiclesOnly) {

    Convert-DirToDds -Dir $skinsDir -Prefix 'skin-' -MaxW 128 -MaxH 160 -AlphaPng32

}

if (-not $SkinsOnly) {

    Convert-DirToDds -Dir $vehDir -Prefix 'veh-' -MaxW 128 -MaxH 80

    if (Test-Path $vehOvr) {

        Convert-DirToDds -Dir $vehOvr -Prefix 'veh-' -MaxW 128 -MaxH 80

    }

}



Write-Host "Done. Grid uses .dds (fast); sidebar preview uses .png (quality)."

Write-Host "Re-run with -Force after updating PNG sources."

