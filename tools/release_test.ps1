# Собрать релиз и разложить в moonloader-test (соседняя папка, dev не трогается).
param(
    [string]$MoonloaderRoot = (Split-Path $PSScriptRoot -Parent),
    [string]$Version = '',
    [string]$ZipPath = '',
    [switch]$Build,
    [switch]$KeepConfig,
    [switch]$Activate
)

$ErrorActionPreference = 'Stop'
. (Join-Path $PSScriptRoot 'release_test_lib.ps1')

$p = Get-DeskMlPaths $MoonloaderRoot

if ($Build) {
    if ($Version -eq '') {
        throw 'Use -Version with -Build, e.g. -Build -Version 1.0.3'
    }
    $build = Join-Path $PSScriptRoot 'build_release.ps1'
    Write-DeskStep "Building release $Version ..."
    & $build -MoonloaderRoot $MoonloaderRoot -Version $Version
}

$zip = Resolve-DeskReleaseZip $MoonloaderRoot $ZipPath
Write-DeskStep "Extract to $($p.Test)"
Write-DeskStep "  zip: $zip"

$configBackup = $null
if ($KeepConfig -and (Test-Path (Join-Path $p.Dev 'config'))) {
    $configBackup = Join-Path $env:TEMP ("desk_cfg_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    Copy-Item (Join-Path $p.Dev 'config') $configBackup -Recurse -Force
}

Expand-DeskZipToFolder $zip $p.Test

if ($configBackup) {
    Write-DeskStep 'Restore personal config in test'
    Copy-Item $configBackup (Join-Path $p.Test 'config') -Recurse -Force
    Remove-Item $configBackup -Recurse -Force -ErrorAction SilentlyContinue
}

$core = Join-Path $p.Test 'report_desk\admin_report_desk_core.lua'
$skins = @(Get-ChildItem (Join-Path $p.Test 'res\report_desk_skins') -Filter '*.png' -ErrorAction SilentlyContinue).Count
Write-DeskOk 'moonloader-test ready.'
Write-Host "  core:  $(Test-Path $core)"
Write-Host "  skins: $skins"
Write-Host ''

if ((Get-DeskMlMode $MoonloaderRoot) -eq 'test') {
    Write-Host 'Already in test mode - restart GTA or /reload.' -ForegroundColor Yellow
} else {
    Write-Host 'Next (GTA closed):' -ForegroundColor Cyan
    Write-Host '  .\ml_mode.ps1 -Test'
}

if ($Activate) {
    Invoke-DeskActivateTest $MoonloaderRoot
}
