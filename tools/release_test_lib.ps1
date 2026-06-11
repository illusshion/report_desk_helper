# Общие функции: тест релиза в соседней moonloader-test (dev-папка не трогается).
$ErrorActionPreference = 'Stop'

function Get-DeskGtaRoot([string]$MoonloaderRoot) {
    return Split-Path $MoonloaderRoot -Parent
}

function Get-DeskMlPaths([string]$MoonloaderRoot) {
    $gta = Get-DeskGtaRoot $MoonloaderRoot
    @{
        Gta        = $gta
        Dev        = Join-Path $gta 'moonloader'
        DevParked  = Join-Path $gta 'moonloader-dev'
        Test       = Join-Path $gta 'moonloader-test'
        Marker     = Join-Path $gta 'moonloader-test\.release_test_mode'
    }
}

function Test-DeskPathJunction([string]$Path) {
    if (-not (Test-Path $Path)) { return $false }
    try {
        $item = Get-Item -LiteralPath $Path -Force
        return ($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0
    } catch {
        return $false
    }
}

function Get-DeskMlMode([string]$MoonloaderRoot) {
    $p = Get-DeskMlPaths $MoonloaderRoot
    if (Test-Path $p.DevParked) { return 'test' }
    if (Test-DeskPathJunction $p.Dev) { return 'test' }
    if (Test-Path $p.Marker) { return 'test' }
    return 'dev'
}

function Assert-DeskGtaClosed {
    $proc = Get-Process -Name 'gta_sa' -ErrorAction SilentlyContinue
    if ($proc) {
        throw 'Close GTA SA before switching mode.'
    }
}

function Write-DeskStep([string]$Text) {
    Write-Host $Text -ForegroundColor Cyan
}

function Write-DeskOk([string]$Text) {
    Write-Host $Text -ForegroundColor Green
}

function Expand-DeskZipToFolder([string]$ZipPath, [string]$DestRoot) {
    if (Test-Path $DestRoot) {
        Remove-Item $DestRoot -Recurse -Force
    }
    New-Item -ItemType Directory -Force -Path $DestRoot | Out-Null
    $stage = Join-Path $env:TEMP ("desk_release_test_" + (Get-Date -Format 'yyyyMMdd_HHmmss'))
    if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
    Expand-Archive -Path $ZipPath -DestinationPath $stage -Force
    Get-ChildItem $stage | ForEach-Object {
        if ($_.PSIsContainer) {
            & robocopy $_.FullName (Join-Path $DestRoot $_.Name) /E /IS /IT /NFL /NDL /NJH /NJS /nc /ns /np | Out-Null
            if ($LASTEXITCODE -ge 8) { throw "robocopy failed: $($_.FullName)" }
        } else {
            Copy-Item $_.FullName (Join-Path $DestRoot $_.Name) -Force
        }
    }
    Remove-Item $stage -Recurse -Force -ErrorAction SilentlyContinue
    Set-Content -Path (Join-Path $DestRoot '.release_test_mode') -Value (Get-Date -Format 'o') -Encoding UTF8
}

function Resolve-DeskReleaseZip([string]$MoonloaderRoot, [string]$ZipPath) {
    if ($ZipPath -ne '' -and (Test-Path $ZipPath)) {
        return (Resolve-Path $ZipPath).Path
    }
    $local = Join-Path $MoonloaderRoot 'dist\report_desk_helper_main.zip'
    if (Test-Path $local) {
        return (Resolve-Path $local).Path
    }
    throw 'No zip. Run .\release_test.ps1 -Build -Version 1.0.3'
}

function Invoke-DeskActivateTest([string]$MoonloaderRoot) {
    Assert-DeskGtaClosed
    $p = Get-DeskMlPaths $MoonloaderRoot
    if ((Get-DeskMlMode $MoonloaderRoot) -eq 'test') {
        Write-DeskOk 'Already in TEST mode (moonloader -> moonloader-test).'
        return
    }
    if (-not (Test-Path (Join-Path $p.Test 'admin_report_desk.lua'))) {
        throw 'moonloader-test missing. Run .\release_test.ps1 first.'
    }
    if (-not (Test-Path $p.Dev)) {
        throw 'moonloader (dev) folder missing.'
    }
    Write-DeskStep 'Park dev: moonloader -> moonloader-dev'
    Rename-Item -LiteralPath $p.Dev -NewName 'moonloader-dev'
    Write-DeskStep 'Junction: moonloader -> moonloader-test'
    $null = cmd /c "mklink /J `"$($p.Dev)`" `"$($p.Test)`""
    if ($LASTEXITCODE -ne 0) {
        if (-not (Test-Path $p.Dev) -and (Test-Path $p.DevParked)) {
            Rename-Item -LiteralPath $p.DevParked -NewName 'moonloader'
        }
        throw 'mklink failed (junction rights in GTA folder?).'
    }
    Write-DeskOk 'TEST MODE: GTA loads moonloader-test. Dev is in moonloader-dev.'
    Write-Host 'Back to dev: .\ml_mode.ps1 -Dev' -ForegroundColor Yellow
}

function Invoke-DeskActivateDev([string]$MoonloaderRoot) {
    Assert-DeskGtaClosed
    $p = Get-DeskMlPaths $MoonloaderRoot
    if ((Get-DeskMlMode $MoonloaderRoot) -ne 'test') {
        Write-DeskOk 'Already in DEV mode.'
        return
    }
    if (Test-DeskPathJunction $p.Dev) {
        Write-DeskStep 'Remove junction moonloader'
        $null = cmd /c "rmdir `"$($p.Dev)`""
        if ($LASTEXITCODE -ne 0) {
            throw 'Failed to remove moonloader junction.'
        }
    } elseif (Test-Path $p.Dev) {
        Remove-Item $p.Dev -Recurse -Force
    }
    if (-not (Test-Path $p.DevParked)) {
        throw 'moonloader-dev missing. Restore dev from git.'
    }
    Write-DeskStep 'Restore dev: moonloader-dev -> moonloader'
    Rename-Item -LiteralPath $p.DevParked -NewName 'moonloader'
    Write-DeskOk 'DEV MODE: normal development restored.'
}

function Show-DeskMlStatus([string]$MoonloaderRoot) {
    $p = Get-DeskMlPaths $MoonloaderRoot
    $mode = Get-DeskMlMode $MoonloaderRoot
    $libCount = 0
    $devRoot = if ($mode -eq 'test') { $p.DevParked } else { $p.Dev }
    if (Test-Path $devRoot) {
        $libCount = @(Get-ChildItem (Join-Path $devRoot 'lib') -Filter 'report_desk_*.lua' -ErrorAction SilentlyContinue).Count
    }
    $testReady = Test-Path (Join-Path $p.Test 'admin_report_desk.lua')

    Write-Host 'Report Desk - GTA / moonloader mode' -ForegroundColor Cyan
    Write-Host "  mode:        $mode"
    Write-Host "  GTA:         $($p.Gta)"
    Write-Host "  dev modules: $libCount in $(if ($mode -eq 'test') { 'moonloader-dev' } else { 'moonloader' })"
    Write-Host "  test ready:  $(if ($testReady) { 'yes' } else { 'no' }) ($($p.Test))"
    if ($mode -eq 'test') {
        Write-Host ''
        Write-Host '  GTA sees RELEASE from moonloader-test.' -ForegroundColor Yellow
        Write-Host '  Dev code is in moonloader-dev (untouched).' -ForegroundColor Yellow
    }
    Write-Host ''
    Write-Host 'Commands:' -ForegroundColor Cyan
    Write-Host '  .\release_test.ps1 -Build -Version 1.0.3'
    Write-Host '  .\ml_mode.ps1 -Test'
    Write-Host '  .\ml_mode.ps1 -Dev'
}
